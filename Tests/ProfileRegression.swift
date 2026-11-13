import AppKit
import Foundation
@main struct ProfileRegression {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("velin-profile-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SessionStore(root: root)
        var config = Configuration(); var profile = AIProfile()
        profile.provider = .gemini; profile.endpoint = Provider.gemini.endpoint; profile.model = "gemini-2.5-flash"
        config.profiles = [profile]; config.activeProfileID = profile.id
        try store.save(config, name: "settings.json")
        defer { try? SecretStore.write("", id: profile.id) }
        try SecretStore.write("fixture-original-key", id: profile.id)
        let model = AppModel(store: store)
        profile.name = "Renamed Gemini"
        try model.saveProfile(profile, key: "")
        precondition(SecretStore.read(profile.id) == "fixture-original-key", "A blank editor must preserve the existing key")
        print("PASS: blank Gemini editor preserves saved key")
        try model.saveProfile(profile, key: "fixture-replacement-key")
        precondition(SecretStore.read(profile.id) == "fixture-replacement-key")
        print("PASS: explicit replacement updates Keychain")
        let restarted = AppModel(store: store)
        precondition(restarted.config.profiles[0].name == "Renamed Gemini")
        precondition(SecretStore.contains(profile.id))
        print("PASS: profile metadata and saved-key status survive reload")
        var changed = profile; changed.provider = .claude; changed.endpoint = Provider.claude.endpoint; changed.model = Provider.claude.models[0]
        do { try model.saveProfile(changed, key: ""); preconditionFailure("Provider switch accepted previous provider key") } catch {}
        precondition(SecretStore.read(profile.id) == "fixture-replacement-key")
        print("PASS: provider change requires its own key and preserves old data on failure")
        for _ in 0..<8 { model.addProfile() }
        precondition(model.config.profiles.count == 5)
        print("PASS: six or more profiles cannot be added")
        let json = try String(contentsOf: root.appendingPathComponent("settings.json"), encoding: .utf8)
        precondition(!json.contains("fixture-replacement-key"))
        print("PASS: no key enters settings JSON")
        if CommandLine.arguments.count > 1 {
            var local = profile; local.provider = .custom; local.endpoint = CommandLine.arguments[1] + "/error"; local.model = "fixture"
            model.config.profiles[0] = local; model.config.activeProfileID = local.id
            model.ask("Synthetic failed-answer regression")
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(!model.generating && model.error != nil && !model.overlayExpanded)
            precondition(!model.session.messages.contains { $0.role == "assistant" && $0.text.isEmpty })
            print("PASS: a long error collapses an empty failed answer")
        }
        print("7 profile regression checks passed with transport fixture.")
    }
}
