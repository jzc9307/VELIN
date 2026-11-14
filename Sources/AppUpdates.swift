import AppKit
import SwiftUI
import Security

private final class UpdateHTTP: NSObject, URLSessionTaskDelegate, URLSessionDownloadDelegate, @unchecked Sendable {
    private let longDownload: Bool
    init(longDownload: Bool = false) { self.longDownload = longDownload; super.init() }
    private var download: CheckedContinuation<URL, Error>?
    private var task: URLSessionDownloadTask?
    private var destination: URL?
    private var limit: Int64 = 0
    private var exceededLimit = false
    var progress: (Double) -> Void = { _ in }
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = longDownload ? 60 : 4; configuration.timeoutIntervalForResource = longDownload ? 900 : 4
        configuration.httpCookieStorage = nil; configuration.urlCache = nil; configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()
    func small(_ url: URL) async throws -> Data {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("velin-update-metadata-" + UUID().uuidString + ".noindex", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = try await get(url, to: folder.appendingPathComponent("metadata.json"), size: 262144, metadata: true)
        let received = (try FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? NSNumber
        guard (received?.intValue ?? Int.max) <= 262144 else { throw UpdateError.invalid("The release metadata is too large.") }
        return try Data(contentsOf: file)
    }
    func get(_ url: URL, to destination: URL, size: Int64, metadata: Bool = false) async throws -> URL {
        guard UpdateNetworkPolicy.allowed(url), download == nil else { throw UpdateError.invalid("An update download is already running.") }
        self.destination = destination; limit = size; exceededLimit = false
        return try await withCheckedThrowingContinuation { continuation in
            download = continuation
            var request = URLRequest(url: url); request.timeoutInterval = longDownload ? 60 : 4; request.setValue("VELIN-Update-Check", forHTTPHeaderField: "User-Agent"); request.setValue(metadata ? "application/vnd.github+json" : "application/octet-stream", forHTTPHeaderField: "Accept")
            task = session.downloadTask(with: request); task?.resume()
        }
    }
    func cancel() { task?.cancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(request.url.map(UpdateNetworkPolicy.allowed) == true ? request : nil) }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > limit { exceededLimit = true; downloadTask.cancel(); return }
        progress(min(1, Double(totalBytesWritten) / Double(max(1, limit))))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let continuation = download else { return }; download = nil; task = nil
        do {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200, let destination else { throw UpdateError.invalid("The update download failed. Your app was preserved.") }
            try FileManager.default.moveItem(at: location, to: destination); continuation.resume(returning: destination)
        } catch { continuation.resume(throwing: error) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error, let continuation = download { download = nil; self.task = nil; continuation.resume(throwing: exceededLimit ? UpdateError.invalid("The update response exceeded its allowed size.") : error) }
    }
    func close() { session.invalidateAndCancel() }
}

@MainActor final class AppUpdates: ObservableObject {
    @Published var launching = true
    @Published var checking = false
    @Published var available: UpdateManifest?
    @Published var status = "Checking for a new version…"
    @Published var progress = 0.0
    @Published var downloading = false
    @Published var presentingDownload = false
    @Published var ready = false
    @Published var failure: String?
    @Published var installed = false
    @Published var latestPublishedVersion: String?
    @Published var latestPublishedBuild: Int?
    @Published var lastChecked: Date?
    var canRestart: () -> Bool = { true }
    var restart: () -> Void = {}
    var prepareRestart: () throws -> Void = {}
    private var envelope: Data?
    private var workspace: URL?
    private var archive: URL?
    private var checkTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var http: UpdateHTTP?
    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }
    var currentBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1 }
    var versionStatus: String {
        if checking { return "Checking for a newer release…" }
        guard let latestPublishedVersion else { return failure == nil ? "Not checked yet" : "Couldn’t confirm the latest version" }
        do {
            let current = try UpdateVersion(currentVersion, build: currentBuild)
            let published = try UpdateVersion(latestPublishedVersion, build: latestPublishedBuild ?? currentBuild)
            if current > published { return "This build is newer than the latest public release" }
            if current < published { return "A newer public release is available" }
            return latestPublishedBuild == nil ? "You have the latest published version · build unavailable" : "You’re on the latest version"
        } catch { return "Couldn’t compare release versions" }
    }
    var currentReleaseNotes: String {
        guard let url = Bundle.main.url(forResource: "ReleaseNotes", withExtension: "json"), let data = try? Data(contentsOf: url), let notes = try? JSONDecoder().decode(BundledReleaseNotes.self, from: data), notes.version == currentVersion, notes.build == currentBuild else { return "Release notes aren’t bundled with this build. View the GitHub release history for details." }
        return notes.notes
    }
    func start() { guard launching, checkTask == nil else { return }; check() }
    func check() {
        guard !checking, !downloading, !ready else { return }
        checking = true; failure = nil; available = nil; envelope = nil; latestPublishedVersion = nil; latestPublishedBuild = nil; status = "Checking GitHub Releases…"
        checkTask = Task {
            let started = Date(), client = UpdateHTTP(); defer { client.close() }
            defer { checking = false; launching = false; checkTask = nil; lastChecked = Date() }
            do { try await loadRelease(client) } catch { status = "Couldn’t check for updates"; failure = error.localizedDescription }
            let remaining = 0.55 - Date().timeIntervalSince(started)
            if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
        }
    }
    private func loadRelease(_ client: UpdateHTTP) async throws {
                struct Release: Decodable { struct Asset: Decodable { let name: String, browser_download_url: String }; let tag_name: String, draft: Bool, prerelease: Bool, assets: [Asset] }
                let data = try await client.small(URL(string: "https://api.github.com/repos/jzc9307/VELIN/releases/latest")!)
                let release = try JSONDecoder().decode(Release.self, from: data)
                guard !release.draft, !release.prerelease, release.tag_name.hasPrefix("v") else { throw UpdateError.invalid("No stable release is available.") }
                let version = String(release.tag_name.dropFirst()), releaseVersion = try UpdateVersion(version, build: Int.max), current = try UpdateVersion(currentVersion, build: currentBuild)
                latestPublishedVersion = version
                guard releaseVersion > current else { status = "You’re up to date"; available = nil; return }
                let expected = "https://github.com/jzc9307/VELIN/releases/download/\(release.tag_name)/VELIN-update.json"
                guard release.assets.contains(where: { $0.name == "VELIN-update.json" && $0.browser_download_url == expected }) else {
                    if try UpdateVersion(version, build: 1) > current { throw UpdateError.invalid("This release has no signed in-app update. Use its GitHub download instead.") }
                    status = "You’re up to date"; return
                }
                let signed = try await client.small(URL(string: expected)!), manifest = try UpdateManifest.verified(signed)
                guard manifest.version == version, release.assets.contains(where: { $0.name == manifest.mac.name && $0.browser_download_url == manifest.mac.url }) else { throw UpdateError.invalid("Release and signed update versions differ.") }
                latestPublishedBuild = manifest.build
                if try manifest.parsedVersion > current { available = manifest; envelope = signed; status = "A little more clarity is ready." }
                else { available = nil; status = "You’re up to date" }
    }
    func downloadAndRestart() {
        guard !installed, !downloading, let manifest = available, envelope != nil else { return }
        guard canRestart() else { failure = "Stop Listen/Mic, finish the answer, and send or clear your draft before restarting."; return }
        if ready { install(); return }
        presentingDownload = true; downloading = true; failure = nil; progress = 0; status = "Downloading VELIN \(manifest.version)…"
        downloadTask = Task {
            defer { downloading = false; http?.close(); http = nil; downloadTask = nil }
            do {
                let folder = SessionStore().root.appendingPathComponent("Updates", isDirectory: true).appendingPathComponent(UUID().uuidString + ".noindex", isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); workspace = folder
                let client = UpdateHTTP(longDownload: true); http = client
                client.progress = { [weak updater = self] value in updater?.progress = value }
                let file = try await client.get(URL(string: manifest.mac.url)!, to: folder.appendingPathComponent(manifest.mac.name), size: manifest.mac.size)
                try Task.checkCancellation()
                status = "Verifying your signed update…"
                try await Task.detached { try manifest.verifyFile(file, artifact: manifest.mac) }.value
                try Task.checkCancellation()
                archive = file; ready = true
                if canRestart() { install() } else { status = "Ready when you are"; failure = "Stop Listen and Mic and finish the current answer, then install and restart." }
            } catch { failure = (error is CancellationError || (error as NSError).code == NSURLErrorCancelled) ? "Download cancelled. Your app was preserved." : error.localizedDescription; status = "Your current app is ready to use"; ready = false }
        }
    }
    func cancelDownload() { http?.cancel(); downloadTask?.cancel(); presentingDownload = false }
    private func install() {
        guard !installed, canRestart(), let envelope, let workspace, let archive else { return }
        do {
            let target = Bundle.main.bundleURL.standardizedFileURL
            guard target.pathExtension == "app", FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path), !target.path.hasPrefix("/Volumes/") else { throw UpdateError.invalid("Move VELIN to a writable Applications folder before updating.") }
            let helper = target.appendingPathComponent("Contents/MacOS/VELINUpdater"), copy = workspace.appendingPathComponent("VELINUpdater")
            guard let requirement = CredentialIdentity.peerRequirement("app.velin.assistant.updater") else { throw UpdateError.invalid("The updater identity is unavailable.") }
            let verify = Process(); verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); verify.arguments = ["--verify", "--strict", "-R=" + requirement, helper.path]; verify.standardOutput = FileHandle.nullDevice; verify.standardError = FileHandle.nullDevice; try verify.run(); verify.waitUntilExit()
            guard verify.terminationStatus == 0 else { throw UpdateError.invalid("The updater signature changed. Reinstall from the verified release.") }
            if !FileManager.default.fileExists(atPath: copy.path) { try FileManager.default.copyItem(at: helper, to: copy) }
            else if try UpdateManifest.hash(copy) != UpdateManifest.hash(helper) { throw UpdateError.invalid("The staged updater changed. Download this update again.") }
            let plan = UpdateInstallPlan(target: target.path, parentPID: ProcessInfo.processInfo.processIdentifier, currentVersion: currentVersion, currentBuild: currentBuild, envelope: envelope, archive: archive.path, workspace: workspace.path)
            let planURL = workspace.appendingPathComponent("plan.json"); try JSONEncoder().encode(plan).write(to: planURL, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: planURL.path)
            try prepareRestart()
            let process = Process(); process.executableURL = copy; process.arguments = [planURL.path]; try process.run()
            installed = true; status = "Restarting into your new version…"; restart()
        } catch { failure = error.localizedDescription; status = "Couldn’t install this update" }
    }
}
