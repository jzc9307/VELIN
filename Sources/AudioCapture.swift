import AppKit
import AVFoundation
import ScreenCaptureKit
import Speech
import OSLog
import CoreAudio

protocol SpeechInput: AnyObject, Sendable {
    var partial: (String, String) -> Void { get set }
    var final: (String, String) -> Void { get set }
    var failure: (String) -> Void { get set }
    func begin() async throws
    func append(_ buffer: AVAudioPCMBuffer)
    func append(_ buffer: CMSampleBuffer)
    func rotate(after: TimeInterval)
    func stop()
}

final class SpeechChannel: SpeechInput, @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = UUID()
    private let recognizer: SFSpeechRecognizer
    let source: String
    let localOnly: Bool
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    private var text = ""
    private var running = false
    private var restart: DispatchWorkItem?
    private var startedAt = Date.distantPast
    private static let logger = Logger(subsystem: "app.velin.assistant", category: "Speech")
    static func canResumeAfterSilence(_ error: NSError, elapsed: TimeInterval) -> Bool {
        // Error numbers are domain-specific. Cancellation and recognition failure
        // are not silence, and immediately retrying them can exhaust the service.
        error.domain == "kAFAssistantErrorDomain" && error.code == 1110 && elapsed >= 2
    }
    init(source: String, locale: String, localOnly: Bool) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else { throw VelinError.message("Speech recognition is unavailable for \(locale). Choose another language or try again.") }
        guard !localOnly || recognizer.supportsOnDeviceRecognition else { throw VelinError.message("On-device speech is unavailable for \(locale). Install this language in macOS or allow Apple speech processing in Settings → Audio.") }
        self.recognizer = recognizer; self.source = source; self.localOnly = localOnly
    }
    // All begin/stop callbacks execute on main. Audio append is protected by the lock.
    func begin() {
        restart?.cancel(); restart = nil
        running = true; startedAt = Date(); generation = UUID(); let token = generation
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true; req.requiresOnDeviceRecognition = localOnly
        req.taskHint = .dictation; req.addsPunctuation = true
        lock.lock(); request = req; lock.unlock()
        text = ""
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, self.running, self.generation == token else { return }
                if let result {
                    self.text = result.bestTranscription.formattedString
                    self.partial(self.source, self.text)
                    if result.isFinal { self.rotate(after: 0.4); return }
                }
                if let error {
                    let ns = error as NSError
                    Self.logger.error("Recognition failed for \(self.source, privacy: .public): \(ns.domain, privacy: .public) / \(ns.code, privacy: .public)")
                    if Self.canResumeAfterSilence(ns, elapsed: Date().timeIntervalSince(self.startedAt)) {
                        self.rotate(after: 1)
                    } else {
                        self.stop()
                        self.failure("\(self.source) transcription stopped (\(ns.domain) \(ns.code)). Stop and start Listen to retry. If it persists, check the transcription language and macOS speech availability.")
                    }
                }
            }
        }
    }
    func append(_ buffer: AVAudioPCMBuffer) { lock.lock(); request?.append(buffer); lock.unlock() }
    func append(_ buffer: CMSampleBuffer) { lock.lock(); request?.appendAudioSampleBuffer(buffer); lock.unlock() }
    func rotate(after delay: TimeInterval = 0.4) {
        guard running, restart == nil else { return }
        stop(); running = true
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.running, self.generation == token else { return }
            self.restart = nil; self.begin()
        }
        restart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    func stop() {
        restart?.cancel(); restart = nil
        running = false; generation = UUID()
        lock.lock(); let old = request; request = nil; lock.unlock()
        old?.endAudio(); task?.cancel(); task = nil
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { final(source, text) }
        text = ""; partial(source, "")
    }
}

// The modern analyzer supports continuous local streams without repeatedly
// cancelling and recreating legacy recognition requests.
#if compiler(>=6.4)
@available(macOS 27, *)
final class StreamingSpeechChannel: SpeechInput, @unchecked Sendable {
    let source: String
    let locale: Locale
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    private let queue = DispatchQueue(label: "app.velin.assistant.speech-input")
    private var converter: AnalyzerInputConverter?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var resultsTask: Task<Void, Never>?
    private var running = false
    private var generation = UUID()
    private var text = ""
    init(source: String, locale: Locale) { self.source = source; self.locale = locale }

    @MainActor func begin() async throws {
        let module = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        try await AssetInventory.reserve(locale: locale)
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await installation.downloadAndInstall()
        }
        let converter = try await AnalyzerInputConverter.converter(compatibleWith: [module])
        let analyzer = SpeechAnalyzer(modules: [module])
        let inputs = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingNewest(256))
        generation = UUID(); let token = generation
        self.analyzer = analyzer; running = true
        queue.sync { self.converter = converter; self.continuation = inputs.continuation }
        resultsTask = Task { @MainActor [weak self] in
            do {
                for try await result in module.results {
                    guard let self, self.running, self.generation == token else { return }
                    let words = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard words.rangeOfCharacter(from: .alphanumerics) != nil else { continue }
                    if result.isFinal {
                        self.text = ""; self.final(self.source, words); self.partial(self.source, "")
                    } else { self.text = words; self.partial(self.source, words) }
                }
            } catch {
                guard let self, self.running, self.generation == token else { return }
                let code = error as NSError
                self.stop()
                self.failure("\(self.source) local transcription stopped (\(code.domain) \(code.code)). Start Listen again to retry.")
            }
        }
        do { try await analyzer.start(inputSequence: inputs.stream) }
        catch { stop(); throw error }
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        // The audio-engine tap owns its buffer; preserve samples before returning.
        guard let owned = Self.copy(buffer) else { return }
        enqueue(owned)
    }
    func append(_ sample: CMSampleBuffer) {
        guard let buffer = Self.pcmBuffer(from: sample) else { return }
        enqueue(buffer)
    }
    static func pcmBuffer(from sample: CMSampleBuffer) -> AVAudioPCMBuffer? {
        let count = CMSampleBufferGetNumSamples(sample)
        guard count > 0, count <= 1_000_000,
              let description = CMSampleBufferGetFormatDescription(sample) else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        buffer.frameLength = buffer.frameCapacity
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList) == noErr else { return nil }
        return buffer
    }
    private func enqueue(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self, let converter = self.converter, let continuation = self.continuation else { return }
            do {
                for input in try converter.convert(buffer, at: nil) {
                    if case .dropped = continuation.yield(input) {
                        throw VelinError.message("Local speech could not keep up with the input.")
                    }
                }
            }
            catch {
                self.continuation = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.running else { return }
                    self.stop(); self.failure("\(self.source) audio could not be converted for local speech recognition. Check the input device and start Listen again.")
                }
            }
        }
    }
    static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard source.frameLength > 0, let output = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        output.frameLength = source.frameLength
        let from = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let to = UnsafeMutableAudioBufferListPointer(output.mutableAudioBufferList)
        guard from.count == to.count else { return nil }
        for index in from.indices {
            guard let input = from[index].mData, let destination = to[index].mData else { return nil }
            memcpy(destination, input, min(Int(from[index].mDataByteSize), Int(to[index].mDataByteSize)))
        }
        return output
    }
    func rotate(after: TimeInterval) { /* Continuous analyzer has no legacy one-minute request limit. */ }
    func stop() {
        running = false; generation = UUID()
        queue.sync { continuation?.finish(); continuation = nil; converter = nil }
        resultsTask?.cancel(); resultsTask = nil
        if !text.isEmpty { final(source, text); text = "" }
        partial(source, "")
        let old = analyzer; analyzer = nil
        if let old { Task { await old.cancelAndFinishNow() } }
    }
}

#endif

final class AudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var stream: SCStream?
    private var microphone: (any SpeechInput)?
    private var computer: (any SpeechInput)?
    private var rotateTimer: Timer?
    private var microphoneTapInstalled = false
    private let setupQueue = DispatchQueue(label: "app.velin.assistant.audio-setup", qos: .userInitiated)
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    var level: (Double) -> Void = { _ in }
    var computerLevel: (Double) -> Void = { _ in }
    var microphoneName: (String) -> Void = { _ in }
    var sourceState: (String, String) -> Void = { _, _ in }
    var warning: (String) -> Void = { _ in }
    private var receivedInputs = Set<String>()
    private var captureGeneration = UUID()
    private var inputWarnings: [String: String] = [:]

    @MainActor func start(config: Configuration) async throws {
        guard config.microphone || config.systemAudio else { throw VelinError.message("Enable microphone or computer audio in Audio settings.") }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw VelinError.message("Allow Speech Recognition in Setup before listening.") }
        captureGeneration = UUID(); receivedInputs = []; inputWarnings = [:]; warning(""); level(0); computerLevel(0)
        var issues: [String] = []
        sourceState("You", config.microphone ? "Starting…" : "Off")
        sourceState("Computer", config.systemAudio ? "Starting…" : "Off")
        if config.microphone {
            do { try await startMicrophone(config); sourceState("You", "Listening") }
            catch { stopMicrophone(); sourceState("You", "Unavailable"); issues.append("Microphone: " + error.localizedDescription) }
        }
        if config.systemAudio {
            do { try await startComputer(config); sourceState("Computer", "Listening") }
            catch {
                let failedStream = stream; stream = nil
                computer?.stop(); computer = nil
                if let failedStream { try? await failedStream.stopCapture() }
                sourceState("Computer", "Unavailable"); issues.append("Computer audio: " + error.localizedDescription)
            }
        }
        guard microphone != nil || computer != nil else { throw VelinError.message(issues.joined(separator: " ")) }
        for (index, issue) in issues.enumerated() { inputWarnings["startup\(index)"] = issue }
        warning(inputWarnings.sorted { $0.key < $1.key }.map(\.value).joined(separator: " "))
        rotateTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in self?.microphone?.rotate(after: 0.4); self?.computer?.rotate(after: 0.4) }
    }
    @MainActor private func startMicrophone(_ config: Configuration) async throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw VelinError.message("Allow Microphone in Audio & Permissions.") }
        let channel = try await channel("You", config); microphone = channel; try await channel.begin()
        let token = captureGeneration
        let prepared: (AVAudioEngine, String) = try await withCheckedThrowingContinuation { continuation in
            setupQueue.async { [weak self, weak channel] in
                let engine = AVAudioEngine()
                let input = engine.inputNode, format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else {
                    continuation.resume(throwing: VelinError.message("No microphone is available. Check the macOS default input device.")); return
                }
                let name = Self.inputDeviceName(input)
                input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, weak channel] buffer, _ in
                    channel?.append(buffer)
                    var value: Double = 0
                    if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                        value = Self.normalizedLevel(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
                    }
                    DispatchQueue.main.async { guard let self, self.captureGeneration == token, self.microphone != nil else { return }; self.markReceived("You"); self.level(value) }
                }
                do {
                    engine.prepare(); try engine.start()
                    continuation.resume(returning: (engine, name))
                } catch {
                    engine.stop(); input.removeTap(onBus: 0)
                    continuation.resume(throwing: error)
                }
            }
        }
        guard captureGeneration == token else {
            prepared.0.stop(); prepared.0.inputNode.removeTap(onBus: 0)
            throw CancellationError()
        }
        self.engine = prepared.0; microphoneTapInstalled = true; microphoneName(prepared.1)
    }
    @MainActor private func startComputer(_ config: Configuration) async throws {
        guard CGPreflightScreenCaptureAccess() else { throw VelinError.message("Allow Screen & System Audio Recording in Audio & Permissions, then reopen VELIN if macOS asks.") }
        let channel = try await channel("Computer", config); computer = channel; try await channel.begin()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw VelinError.message("No display is available for system audio.") }
        let filter = SCContentFilter(display: display, excludingApplications: content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }, exceptingWindows: [])
        let cfg = SCStreamConfiguration(); cfg.width = 2; cfg.height = 2
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        cfg.capturesAudio = true; cfg.excludesCurrentProcessAudio = true; cfg.sampleRate = 16000; cfg.channelCount = 1
        let stream = SCStream(filter: filter, configuration: cfg, delegate: self); self.stream = stream
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
        try await stream.startCapture()
    }
    private static func inputDeviceName(_ input: AVAudioInputNode) -> String {
        guard let unit = input.audioUnit else { return "macOS default input" }
        var device = AudioDeviceID(0), size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, &size) == noErr else { return "macOS default input" }
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?; size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr, let name else { return "macOS default input" }
        let value = name.takeRetainedValue() as String
        return value.hasPrefix("CADefaultDeviceAggregate-") ? "macOS default input" : value
    }
    private func stopMicrophone() {
        engine?.stop()
        if microphoneTapInstalled { engine?.inputNode.removeTap(onBus: 0); microphoneTapInstalled = false }
        engine = nil; microphone?.stop(); microphone = nil; level(0)
    }
    private func markReceived(_ source: String) {
        if receivedInputs.insert(source).inserted { sourceState(source, "Audio received") }
    }
    static func normalizedLevel<C: Collection>(_ samples: C) -> Double where C.Element == Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Double = 0
        for sample in samples { if sample.isFinite { sum += Double(sample) * Double(sample) } }
        return min(1, sqrt(sum / Double(samples.count)) * 8)
    }
    private func computerSignalLevel(_ buffer: CMSampleBuffer) -> Double {
        guard let description = CMSampleBufferGetFormatDescription(buffer),
              let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32,
              let block = CMSampleBufferGetDataBuffer(buffer) else { return 0 }
        let length = CMBlockBufferGetDataLength(block)
        guard length > 0, length <= 1_000_000, length % MemoryLayout<Float>.size == 0 else { return 0 }
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { bytes in CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!) }
        guard status == kCMBlockBufferNoErr else { return 0 }
        // Copy bytes through loadUnaligned: Data doesn't promise Float alignment.
        return data.withUnsafeBytes { bytes in
            var values: [Float] = []; values.reserveCapacity(length / 4)
            for offset in stride(from: 0, to: length, by: 4) { values.append(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self)) }
            return Self.normalizedLevel(values)
        }
    }
    @MainActor private func channel(_ source: String, _ config: Configuration) async throws -> any SpeechInput {
        let channel: any SpeechInput
        #if compiler(>=6.4)
        if #available(macOS 27, *), SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: config.language)) {
            sourceState(source, "Preparing local speech…")
            channel = StreamingSpeechChannel(source: source, locale: locale)
        } else {
            channel = try SpeechChannel(source: source, locale: config.language, localOnly: config.localSpeechOnly)
        }
        #else
        channel = try SpeechChannel(source: source, locale: config.language, localOnly: config.localSpeechOnly)
        #endif
        channel.partial = partial; channel.final = final
        channel.failure = { [weak self] message in
            guard let self else { return }
            self.sourceState(source, "Recognition error")
            self.inputWarnings[source] = message
            self.warning(self.inputWarnings.sorted { $0.key < $1.key }.map(\.value).joined(separator: " "))
            if source == "You" { self.stopMicrophone() }
            else {
                self.computer = nil
                let failedStream = self.stream; self.stream = nil
                if let failedStream { Task { try? await failedStream.stopCapture() } }
            }
            if self.microphone == nil && self.computer == nil { self.failure(message) }
        }
        return channel
    }
    @MainActor func stop() async {
        captureGeneration = UUID(); rotateTimer?.invalidate(); rotateTimer = nil
        stopMicrophone()
        computer?.stop(); computer = nil
        let oldStream = stream; stream = nil
        if let oldStream { try? await oldStream.stopCapture() }
        computerLevel(0); receivedInputs = []
        sourceState("You", "Stopped"); sourceState("Computer", "Stopped")
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard self.stream === stream, type == .audio, sampleBuffer.isValid else { return }
        computer?.append(sampleBuffer)
        markReceived("Computer"); computerLevel(computerSignalLevel(sampleBuffer))
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.stream === stream else { return }
            self.stream = nil; self.computer?.stop(); self.computer = nil
            self.computerLevel(0); self.sourceState("Computer", "Capture stopped")
            let message = "Computer audio stopped: " + error.localizedDescription
            if self.microphone == nil { self.failure(message) } else { self.warning(message) }
        }
    }
}

enum ScreenCapture {
    @MainActor static func screenshot() async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else { throw VelinError.message("Allow Screen & System Audio Recording in Setup to take a screenshot.") }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mainID = NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        guard let display = content.displays.first(where: { $0.displayID == mainID }) ?? content.displays.first else { throw VelinError.message("No screen is available.") }
        let filter = SCContentFilter(display: display, excludingApplications: content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }, exceptingWindows: [])
        let cfg = SCStreamConfiguration(); cfg.width = min(1600, display.width); cfg.height = max(1, Int(Double(cfg.width) * Double(display.height) / Double(display.width))); cfg.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else { throw VelinError.message("Could not encode the screenshot.") }
        return data
    }
}
