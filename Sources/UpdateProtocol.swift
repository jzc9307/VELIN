import Foundation
import CryptoKit

enum UpdateError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
struct UpdateVersion: Comparable, Equatable {
    let major: Int, minor: Int, patch: Int, build: Int
    init(_ value: String, build: Int) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) && $0.count <= 6 }), let a = Int(parts[0]), let b = Int(parts[1]), let c = Int(parts[2]), build > 0 else { throw UpdateError.invalid("The release has an invalid version.") }
        major = a; minor = b; patch = c; self.build = build
    }
    static func < (a: Self, b: Self) -> Bool { if a.major != b.major { return a.major < b.major }; if a.minor != b.minor { return a.minor < b.minor }; if a.patch != b.patch { return a.patch < b.patch }; return a.build < b.build }
}
struct BundledReleaseNotes: Codable {
    let version: String
    let build: Int
    let notes: String
}

struct UpdateArtifact: Codable {
    let name: String, url: String, sha256: String
    let size: Int64
}
struct UpdateManifest: Codable {
    let schema: Int, repository: String, version: String, build: Int, notes: String
    let mac: UpdateArtifact, windows: UpdateArtifact
    var parsedVersion: UpdateVersion { get throws { try UpdateVersion(version, build: build) } }
    func validate() throws {
        guard schema == 1, repository == "jzc9307/VELIN", notes.count <= 5000 else { throw UpdateError.invalid("This update does not belong to VELIN.") }
        _ = try parsedVersion
        for (artifact, suffix, maxSize) in [(mac, "macOS-arm64.zip", Int64(500_000_000)), (windows, "Windows-x64.exe", Int64(800_000_000))] {
            let name = "VELIN-\(version)-\(suffix)"
            guard artifact.name == name, artifact.url == "https://github.com/jzc9307/VELIN/releases/download/v\(version)/\(name)", artifact.size > 0, artifact.size <= maxSize, artifact.sha256.count == 64, artifact.sha256.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else { throw UpdateError.invalid("The signed update has an invalid download destination or file size.") }
        }
    }
    static func verified(_ envelope: Data, publicKey: String = UpdateTrust.publicKey) throws -> Self {
        struct Envelope: Decodable { let payload: String, signature: String }
        guard envelope.count <= 65536, let value = try? JSONDecoder().decode(Envelope.self, from: envelope), let payload = Data(base64Encoded: value.payload), let signature = Data(base64Encoded: value.signature), let keyData = Data(base64Encoded: publicKey), let key = try? P256.Signing.PublicKey(x963Representation: keyData), let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature), key.isValidSignature(sig, for: payload) else { throw UpdateError.invalid("Update verification failed. No files were installed.") }
        let manifest = try JSONDecoder().decode(Self.self, from: payload); try manifest.validate(); return manifest
    }
    static func hash(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func verifyFile(_ file: URL, artifact: UpdateArtifact) throws {
        let info = try FileManager.default.attributesOfItem(atPath: file.path)
        guard (info[.size] as? NSNumber)?.int64Value == artifact.size, try Self.hash(file) == artifact.sha256 else { throw UpdateError.invalid("The update download is incomplete or changed. Your app was preserved.") }
    }
}
/// Only public GitHub release requests. No account/API credentials are attached.
enum UpdateNetworkPolicy {
    static func allowed(_ url: URL) -> Bool {
        guard url.scheme == "https", url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return false }
        return ["api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com", "github-releases.githubusercontent.com"].contains(url.host?.lowercased() ?? "")
    }
}
struct UpdateInstallPlan: Codable {
    let target: String, parentPID: Int32, currentVersion: String, currentBuild: Int
    let envelope: Data, archive: String, workspace: String
}
/// Same-directory moves preserve the app bundle's outer identity. Validation
/// failure restores the exact previous Contents; backup is retained on success.
enum UpdateReplacement {
    static func apply(target: URL, prepared: URL, backup: URL, validate: () throws -> Void) throws {
        let files = FileManager.default, contents = target.appendingPathComponent("Contents")
        guard !files.fileExists(atPath: backup.path), files.fileExists(atPath: contents.path) else { throw UpdateError.invalid("The app changed while preparing its update.") }
        try files.moveItem(at: contents, to: backup)
        do { try files.moveItem(at: prepared, to: contents); try validate() }
        catch {
            let failed = backup.deletingLastPathComponent().appendingPathComponent("failed-Contents")
            if files.fileExists(atPath: contents.path) { try? files.moveItem(at: contents, to: failed) }
            try files.moveItem(at: backup, to: contents); throw error
        }
    }
}
