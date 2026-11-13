import AppKit
import Foundation
import AVFoundation
@main struct ProfileRegression {
    @MainActor static func main() async throws {
        precondition(AudioCapture.normalizedLevel([Float]()) == 0 && AudioCapture.normalizedLevel([Float](repeating: 0, count: 80)) == 0)
        print("PASS: silence and empty input leave audio meters at zero")
        precondition(abs(AudioCapture.normalizedLevel([Float](repeating: 0.01, count: 80)) - 0.08) < 0.00001)
        print("PASS: audio meters use the signal RMS")
        precondition(AudioCapture.normalizedLevel([Float(100), -100]) == 1)
        print("PASS: loud input meters stay within range")
        precondition(AudioCapture.normalizedLevel([Float.nan, Float.infinity, 0]) == 0)
        print("PASS: invalid samples cannot corrupt an input meter")
        precondition(SpeechChannel.canResumeAfterSilence(NSError(domain: "kAFAssistantErrorDomain", code: 1110), elapsed: 10))
        precondition(!SpeechChannel.canResumeAfterSilence(NSError(domain: "kAFAssistantErrorDomain", code: 1110), elapsed: 0.01))
        print("PASS: silence resumes only after a real listening interval")
        for code in [203, 216, 301, 1100, 1101, 1107, 1700] {
            precondition(!SpeechChannel.canResumeAfterSilence(NSError(domain: "kAFAssistantErrorDomain", code: code), elapsed: 10))
        }
        precondition(!SpeechChannel.canResumeAfterSilence(NSError(domain: "kLSRErrorDomain", code: 1110), elapsed: 10))
        print("PASS: cancellation, service failures and unrelated domains cannot enter a recognition retry loop")
        if #available(macOS 27, *) {
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
            let original = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32)!
            original.frameLength = 32
            for channel in 0..<2 { for frame in 0..<32 { original.floatChannelData![channel][frame] = Float(channel * 32 + frame) / 100 } }
            let copied = StreamingSpeechChannel.copy(original)!
            original.floatChannelData![1][7] = -1
            precondition(copied.frameLength == 32 && copied.format == format && abs(copied.floatChannelData![1][7] - 0.39) < 0.00001)
            print("PASS: speech input owns all audio channels after a capture buffer is reused")
            var sample: CMSampleBuffer?
            var description: CMAudioFormatDescription?
            var asbd = format.streamDescription.pointee
            precondition(CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &description) == noErr)
            var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 44100), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
            precondition(CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false, makeDataReadyCallback: nil, refcon: nil, formatDescription: description, sampleCount: 32, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample) == noErr)
            precondition(CMSampleBufferSetDataBufferFromAudioBufferList(sample!, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault, flags: 0, bufferList: copied.audioBufferList) == noErr)
            let decoded = StreamingSpeechChannel.pcmBuffer(from: sample!)!
            precondition(decoded.frameLength == 32 && abs(decoded.floatChannelData![1][7] - 0.39) < 0.00001)
            print("PASS: computer sample-buffer conversion preserves frame count and separate channels")
        }
        var heard = HeardQuestionDraft()
        heard.update("What is"); heard.update("What is JSON?")
        precondition(heard.text == "What is JSON?")
        print("PASS: revised speech updates a single pending question")
        heard.finish("What is JSON?"); heard.update("Give an example")
        precondition(heard.text == "What is JSON? Give an example")
        print("PASS: finalized speech and a live continuation form one question")
        heard.consume(); heard.finish("Give an example")
        precondition(heard.text.isEmpty)
        print("PASS: finalizing an already-submitted partial cannot repeat its question")
        heard.update("Why use it?"); heard.finish("Why use it?"); heard.finish(".")
        precondition(heard.text == "Why use it?")
        print("PASS: new speech remains answerable and punctuation-only results stay out")
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
            local.endpoint = CommandLine.arguments[1] + "/packaged"
            model.config.profiles[0] = local
            model.ask("What is JSON?")
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            let reply = model.session.messages.last!
            precondition(!model.generating && reply.text == "JSON is a text format.")
            precondition(reply.quickReplies?.say == "JSON lets apps exchange data." && reply.quickReplies?.next == "Try a small JSON object." && reply.quickReplies?.more == "An object contains key-value pairs.")
            let restored = AppModel(store: store)
            precondition(restored.sessions.first?.messages.last?.quickReplies == reply.quickReplies)
            print("PASS: streamed concise reply and prepared actions persist through history reload")
            model.newSession()
            model.receiveSpeechPartial(source: "You", text: "My own voice is context.")
            precondition(model.pendingHeardQuestion.isEmpty && !model.generating && model.session.messages.isEmpty)
            print("PASS: microphone speech is context and cannot automatically trigger a provider request")
            model.receiveSpeechPartial(source: "Computer", text: "What is JSON?")
            precondition(model.pendingHeardQuestion == "What is JSON?" && !model.generating)
            model.ask()
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(model.session.messages.first?.text == "What is JSON?" && model.session.messages.first?.inputSource == "Computer" && model.session.messages.last?.text == "JSON is a text format.")
            precondition(model.pendingHeardQuestion.isEmpty)
            model.receiveSpeechFinal(source: "Computer", text: "What is JSON?")
            model.receiveSpeechPartial(source: "Computer", text: "")
            precondition(model.pendingHeardQuestion.isEmpty)
            print("PASS: empty Enter submits recognized computer speech and receives an answer without duplicate finalization")
            model.receiveSpeechFinal(source: "Computer", text: "Why use JSON?")
            model.ask("Give me a typed example instead.")
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(model.session.messages.suffix(2).first?.text == "Give me a typed example instead." && model.pendingHeardQuestion == "Why use JSON?")
            print("PASS: an explicit typed question takes precedence without consuming pending speech")
            local.endpoint = "http://invalid.example/v1"; model.config.profiles[0] = local
            model.ask()
            precondition(!model.generating && model.pendingHeardQuestion == "Why use JSON?")
            print("PASS: a request-construction failure preserves the pending spoken question")
            model.newSession()
            precondition(model.pendingHeardQuestion.isEmpty)
            print("PASS: a new session clears the previous pending spoken question")
        }
        print("25 profile regression checks passed with transport fixture.")
    }
}
