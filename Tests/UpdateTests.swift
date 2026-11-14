import Foundation
import CryptoKit

@main struct UpdateTests {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () throws -> Bool, _ name: String) throws { guard try condition() else { throw UpdateError.invalid(name) }; count += 1; print("PASS: " + name) }
        func rejected(_ name: String, _ action: () throws -> Void) throws { do { try action() } catch { count += 1; print("PASS: " + name); return }; throw UpdateError.invalid("Accepted " + name) }
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/update-vector.json")
        let data = try Data(contentsOf: fixture), object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let publicKey = object["publicKey"] as! String, envelope = try JSONSerialization.data(withJSONObject: object["envelope"]!)
        let release = try UpdateManifest.verified(envelope, publicKey: publicKey)
        try check(release.version == "0.2.2" && release.build == 8, "P-256 signed fixture verifies in native CryptoKit")
        try rejected("A release signed by an unknown key is rejected") { _ = try UpdateManifest.verified(envelope) }
        var forged = object["envelope"] as! [String: String]; var payload = Data(base64Encoded: forged["payload"]!)!; payload[payload.startIndex] ^= 1; forged["payload"] = payload.base64EncodedString()
        try rejected("Tampered signed metadata cannot authorize installation") { _ = try UpdateManifest.verified(JSONSerialization.data(withJSONObject: forged), publicKey: publicKey) }
        try check(UpdateVersion("0.2.10", build: 1) > UpdateVersion("0.2.9", build: 999), "Versions compare numerically rather than lexically")
        try check(UpdateVersion("0.2.1", build: 7) > UpdateVersion("0.2.1", build: 6), "Internal build revisions compare within one semantic version")
        try rejected("Pre-release or malformed tags cannot enter stable update installation") { _ = try UpdateVersion("0.2.1-beta.1", build: 7) }
        try check(!UpdateNetworkPolicy.allowed(URL(string: "https://github.com.evil.example/payload")!) && !UpdateNetworkPolicy.allowed(URL(string: "http://github.com/jzc9307/VELIN")!) && !UpdateNetworkPolicy.allowed(URL(string: "https://secret@github.com")!), "Update transport rejects lookalike hosts, plaintext and credentials")
        try check(UpdateNetworkPolicy.allowed(URL(string: "https://release-assets.githubusercontent.com/example")!), "GitHub release CDN redirects are allowed without credentials")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("velin-update-test-" + UUID().uuidString + ".noindex")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false); defer { try? FileManager.default.removeItem(at: root) }
        let artifact = root.appendingPathComponent("payload"); try Data("abc".utf8).write(to: artifact)
        let record = UpdateArtifact(name: "fixture", url: "", sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", size: 3)
        try release.verifyFile(artifact, artifact: record); count += 1; print("PASS: Artifact size and SHA-256 both match before installation")
        try Data("abcd".utf8).write(to: artifact)
        try rejected("A truncated or modified download cannot install") { try release.verifyFile(artifact, artifact: record) }
        let app = root.appendingPathComponent("VELIN.app"); try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: app.appendingPathComponent("Contents/version"))
        let candidate = root.appendingPathComponent("new"); try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: false); try Data("new".utf8).write(to: candidate.appendingPathComponent("version"))
        try rejected("Failed post-replacement validation restores the old app contents") { try UpdateReplacement.apply(target: app, prepared: candidate, backup: root.appendingPathComponent("backup")) { throw UpdateError.invalid("Synthetic validation failure") } }
        try check(String(contentsOf: app.appendingPathComponent("Contents/version"), encoding: .utf8) == "old", "Rollback restores the exact previous contents")
        let next = root.appendingPathComponent("next"); try FileManager.default.createDirectory(at: next, withIntermediateDirectories: false); try Data("new".utf8).write(to: next.appendingPathComponent("version"))
        try UpdateReplacement.apply(target: app, prepared: next, backup: root.appendingPathComponent("saved-old")) { }
        try check(String(contentsOf: app.appendingPathComponent("Contents/version"), encoding: .utf8) == "new" && String(contentsOf: root.appendingPathComponent("saved-old/version"), encoding: .utf8) == "old", "Successful replacement retains its previous version for recovery")
        print("\(count) native update verification and rollback checks passed; no installed app was changed.")
    }
}
