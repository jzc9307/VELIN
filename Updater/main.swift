import Foundation
import AppKit
import Security
import Darwin

func run(_ exe: String, _ args: [String]) throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath: exe); process.arguments = args
    process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
    try process.run(); process.waitUntilExit(); guard process.terminationStatus == 0 else { throw UpdateError.invalid("Update installation could not verify or copy the app.") }
}
func signingRequirement() throws -> String {
    var own: SecCode?, staticCode: SecStaticCode?, info: CFDictionary?
    guard SecCodeCopySelf([], &own) == errSecSuccess, let own, SecCodeCopyStaticCode(own, [], &staticCode) == errSecSuccess, let staticCode, SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess, let dict = info as? [String: Any], let certificate = (dict[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first else { throw UpdateError.invalid("The installed updater has no signing identity.") }
    return "identifier \"app.velin.assistant\" and certificate leaf = H\"" + certificateHash(certificate) + "\""
}
import CryptoKit
func certificateHash(_ certificate: SecCertificate) -> String { Insecure.SHA1.hash(data: SecCertificateCopyData(certificate) as Data).map { String(format: "%02x", $0) }.joined() }
func verifyApp(_ app: URL, manifest: UpdateManifest, requirement: String) throws {
    let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
    guard info?["CFBundleIdentifier"] as? String == "app.velin.assistant", info?["CFBundleShortVersionString"] as? String == manifest.version, info?["CFBundleVersion"] as? String == String(manifest.build) else { throw UpdateError.invalid("The downloaded app version does not match its signed release.") }
    try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R=" + requirement, app.path])
}
var safeTarget: URL?
do {
    let verificationOnly = CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--verify-only"
    guard CommandLine.arguments.count == 2 || verificationOnly else { throw UpdateError.invalid("An update plan is required.") }
    let planURL = URL(fileURLWithPath: CommandLine.arguments[verificationOnly ? 2 : 1]); let plan = try JSONDecoder().decode(UpdateInstallPlan.self, from: Data(contentsOf: planURL))
    let workspace = URL(fileURLWithPath: plan.workspace).standardizedFileURL, target = URL(fileURLWithPath: plan.target).standardizedFileURL, archive = URL(fileURLWithPath: plan.archive).standardizedFileURL
    guard target.pathExtension == "app", target.resolvingSymlinksInPath() == target, workspace.resolvingSymlinksInPath() == workspace, archive.deletingLastPathComponent() == workspace, planURL.standardizedFileURL.deletingLastPathComponent() == workspace, FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else { throw UpdateError.invalid("Move VELIN to a writable Applications folder before updating.") }
    let manifest = try UpdateManifest.verified(plan.envelope)
    guard try manifest.parsedVersion > UpdateVersion(plan.currentVersion, build: plan.currentBuild) else { throw UpdateError.invalid("An older update cannot replace this app.") }
    try manifest.verifyFile(archive, artifact: manifest.mac)
    let requirement = try signingRequirement()
    let currentInfo = try PropertyListSerialization.propertyList(from: Data(contentsOf: target.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
    guard currentInfo?["CFBundleIdentifier"] as? String == "app.velin.assistant", currentInfo?["CFBundleShortVersionString"] as? String == plan.currentVersion, currentInfo?["CFBundleVersion"] as? String == String(plan.currentBuild) else { throw UpdateError.invalid("The installed app changed; check for updates again.") }
    try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", "-R=" + requirement, target.path])
    safeTarget = target
    let unpacked = workspace.appendingPathComponent("unpacked", isDirectory: true)
    try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: false)
    try run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path])
    let candidate = unpacked.appendingPathComponent("VELIN.app"); try verifyApp(candidate, manifest: manifest, requirement: requirement)
    if verificationOnly { print("Verified signed archive, update version, target identity and candidate code signature; no app replaced."); exit(0) }
    // Prepare on the destination volume before requesting any replacement.
    let replacement = target.deletingLastPathComponent().appendingPathComponent(".VELIN-update-" + UUID().uuidString + ".noindex", isDirectory: true)
    try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    let prepared = replacement.appendingPathComponent("new-Contents"), backup = replacement.appendingPathComponent("previous-Contents")
    try run("/usr/bin/ditto", ["--noextattr", "--norsrc", candidate.appendingPathComponent("Contents").path, prepared.path])
    if let parent = NSRunningApplication(processIdentifier: plan.parentPID), parent.bundleURL?.standardizedFileURL != target { throw UpdateError.invalid("The update belongs to a different running app.") }
    let deadline = Date().addingTimeInterval(60)
    while kill(plan.parentPID, 0) == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
    guard kill(plan.parentPID, 0) != 0 else { throw UpdateError.invalid("VELIN stayed open. The existing app was preserved.") }
    try UpdateReplacement.apply(target: target, prepared: prepared, backup: backup) { try verifyApp(target, manifest: manifest, requirement: requirement) }
    try run("/usr/bin/open", [target.path])
    try "Updated to \(manifest.version). Previous app contents are retained at \(backup.path).".write(to: workspace.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
} catch {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let alert = NSAlert(); alert.messageText = "VELIN update wasn’t installed"; alert.informativeText = error.localizedDescription + " Your existing app and local data were preserved."; alert.runModal(); if let safeTarget { try? run("/usr/bin/open", [safeTarget.path]) }; exit(1)
}
