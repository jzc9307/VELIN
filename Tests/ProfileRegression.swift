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
        var modernChecks = 0
        #if compiler(>=6.4)
        if #available(macOS 27, *) {
            modernChecks = 2
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
        #endif
        let routingRoot = FileManager.default.temporaryDirectory.appendingPathComponent("velin-routing-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: routingRoot) }
        let routing = AppModel(store: SessionStore(root: routingRoot))
        routing.startingDictation = true
        routing.receiveDictationPartial("A dictated question")
        precondition(routing.prompt == "A dictated question" && routing.pendingHeardQuestion.isEmpty && routing.session.transcript.isEmpty && !routing.showLiveAudio)
        print("PASS: microphone words populate the question without Listen, raw transcript, or listening panel")
        routing.receiveSpeechPartial(source: "Computer", text: "The interviewer question")
        routing.receiveDictationFinal("A dictated question?")
        precondition(routing.prompt == "A dictated question?" && routing.pendingHeardQuestion == "The interviewer question" && routing.session.transcript.isEmpty)
        print("PASS: simultaneous computer speech and mic dictation remain separate")
        routing.startingDictation = false; routing.dictating = true; routing.recording = true
        await routing.stopListening()
        precondition(routing.dictating && routing.prompt == "A dictated question?" && !routing.showLiveAudio)
        print("PASS: stopping Listen leaves independent mic dictation and its draft active")
        routing.recording = true
        await routing.stopDictation()
        precondition(routing.recording && !routing.dictating && routing.prompt == "A dictated question?")
        routing.recording = false
        print("PASS: stopping Mic preserves computer listening and the editable question")
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
        var editable = HeardQuestionDraft()
        editable.update("What is J son?"); editable.edit("What is JSON?")
        editable.update("What is J son and why is it useful?"); editable.finish("What is J son and why is it useful?")
        precondition(editable.text == "What is JSON?" && editable.isEdited && editable.liveText.contains("useful"))
        print("PASS: manual corrections survive both live recognition revisions and finalization")
        editable.resumeLive()
        precondition(!editable.isEdited && editable.text.contains("useful"))
        editable.edit(""); editable.update("New words")
        precondition(editable.text.isEmpty && editable.isEdited)
        print("PASS: Resume live restores recognition while a deliberately cleared draft remains protected")
        editable.edit("Corrected question"); editable.consume(); editable.finish("New words")
        precondition(editable.text.isEmpty && !editable.isEdited)
        for number in 0..<400 { editable.finish("Sentence \(number) has several words.") }
        precondition(editable.text.count <= 6000 && editable.text.hasSuffix("Sentence 399 has several words."))
        print("PASS: consumed edits do not replay and long live speech keeps its newest bounded text")
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
            let cloud = SonioxSpeechChannel(source: "Computer", key: "fixture-speech-key", endpoint: URL(string: CommandLine.arguments[1].replacingOccurrences(of: "http://", with: "ws://") + "/speech-socket")!)
            var cloudFinal = "", cloudPartials: [String] = [], cloudFailure = ""
            cloud.final = { _, text in cloudFinal += text }; cloud.partial = { _, text in cloudPartials.append(text) }; cloud.failure = { cloudFailure = $0 }
            try await cloud.begin()
            let cloudBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!, frameCapacity: 4410)!
            cloudBuffer.frameLength = 4410
            for frame in 0..<4410 { cloudBuffer.floatChannelData![0][frame] = 0.03 }
            cloud.append(cloudBuffer)
            for _ in 0..<300 { if !cloudFinal.isEmpty || !cloudFailure.isEmpty { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            cloud.stop()
            precondition(cloudFinal == "你好 JSON" && cloudPartials.contains("你好 J son") && cloudPartials.contains("你好 JSON") && cloudFailure.isEmpty)
            print("PASS: real loopback WebSocket validates header auth, text config, PCM conversion and mixed partial/final speech without a cloud API")
            let hashFixture = root.appendingPathComponent("model-hash-fixture")
            try Data("abc".utf8).write(to: hashFixture)
            precondition(SpeechModels.verified(hashFixture, sha: "a9993e364706816aba3e25717850c26c9cd0d89d") && !SpeechModels.verified(hashFixture, sha: String(repeating: "0", count: 40)))
            print("PASS: speech model validation accepts matching bytes and rejects corruption")
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
            let previousCount = model.session.messages.count
            model.continueReply(messageID: reply.id, displayed: reply.quickReplies!.next)
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(model.session.messages.count == previousCount + 2 && model.session.messages[previousCount].text == "Yes, continue" && model.session.messages[previousCount - 1].id == reply.id)
            print("PASS: continuation uses the selected prepared view and appends a new turn without replacing history")
            model.prompt = "Keep my unsent draft"
            model.continueReply(messageID: reply.id, displayed: reply.text)
            precondition(!model.generating && model.prompt == "Keep my unsent draft" && model.session.messages.count == previousCount + 2)
            print("PASS: continuation preserves unsent drafts and does not start a provider request")
            model.prompt = ""
            model.newSession()
            model.receiveSpeechPartial(source: "You", text: "My own voice is context.")
            precondition(model.pendingHeardQuestion.isEmpty && !model.generating && model.session.messages.isEmpty && model.partials["You"] == nil)
            print("PASS: meeting callbacks ignore microphone words and cannot automatically trigger a provider request")
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
            model.recording = true
            await model.stopListening()
            precondition(!model.showLiveAudio && model.pendingHeardQuestion == "Why use JSON?")
            print("PASS: stopping Listen hides audio status while retaining the unanswered question")
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
            local.endpoint = CommandLine.arguments[1] + "/packaged"; model.config.profiles[0] = local
            model.receiveSpeechPartial(source: "Computer", text: "What is J son?")
            model.heardQuestion.edit("What is JSON?")
            model.receiveSpeechFinal(source: "Computer", text: "What is J son?")
            model.ask()
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(model.session.messages.first?.text == "What is JSON?" && model.pendingHeardQuestion.isEmpty)
            precondition(model.session.transcript.last?.text == "What is J son?")
            print("PASS: Enter submits the corrected spoken question while preserving the source transcript")
            model.newSession(); model.receiveSpeechFinal(source: "Computer", text: "Unrelated old speech")
            let focusBefore = model.promptFocusToken
            model.attachScreenshot(Data("synthetic screenshot fixture".utf8))
            precondition(model.session.messages.isEmpty && !model.generating && model.pendingImage != nil && model.promptFocusToken > focusBefore)
            print("PASS: attaching a screenshot requests input focus without starting generation")
            model.ask()
            for _ in 0..<300 { if !model.generating { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            precondition(model.session.messages.first?.text == "Help me understand this screenshot." && model.session.messages.first?.attachment == true)
            precondition(model.session.messages.first?.inputSource == nil && model.pendingHeardQuestion == "Unrelated old speech")
            print("PASS: a screenshot without typed text takes priority over unrelated pending speech")
        }
        try model.prepareForUpdate()
        let savedSessions = try store.load([Session].self, name: "sessions.json", fallback: [])
        let savedConfig = try store.load(Configuration.self, name: "settings.json", fallback: Configuration())
        precondition(savedSessions.contains(where: { $0.id == model.session.id }) && savedConfig.activeProfileID == model.config.activeProfileID)
        print("PASS: updater flush preserves the current session and configuration before restarting")
        print("\(39 + modernChecks) profile regression checks passed with transport fixture.")
    }
}
