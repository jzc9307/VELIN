import AppKit
import AVFoundation
import ScreenCaptureKit
import Speech

final class SpeechChannel: @unchecked Sendable {
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
    init(source: String, locale: String, localOnly: Bool) throws {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)), recognizer.isAvailable else { throw VelinError.message("Speech recognition is unavailable for \(locale). Choose another language or try again.") }
        guard !localOnly || recognizer.supportsOnDeviceRecognition else { throw VelinError.message("On-device speech is unavailable for \(locale). Install this language in macOS or allow Apple speech processing in Settings → Audio.") }
        self.recognizer = recognizer; self.source = source; self.localOnly = localOnly
    }
    // All begin/stop callbacks execute on main. Audio append is protected by the lock.
    func begin() {
        running = true; generation = UUID(); let token = generation
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
                    if result.isFinal { self.rotate(); return }
                }
                if let error {
                    let ns = error as NSError
                    // Silence/no-speech can terminate a segment; re-arm while recording.
                    if [203, 1110, 216, 301].contains(ns.code) { self.rotate() }
                    else { self.failure("\(self.source) transcription: \(error.localizedDescription)"); self.stop() }
                }
            }
        }
    }
    func append(_ buffer: AVAudioPCMBuffer) { lock.lock(); request?.append(buffer); lock.unlock() }
    func append(_ buffer: CMSampleBuffer) { lock.lock(); request?.appendAudioSampleBuffer(buffer); lock.unlock() }
    func rotate() { guard running else { return }; stop(); begin() }
    func stop() {
        running = false; generation = UUID()
        lock.lock(); let old = request; request = nil; lock.unlock()
        old?.endAudio(); task?.cancel(); task = nil
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { final(source, text) }
        text = ""; partial(source, "")
    }
}

final class AudioCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var engine: AVAudioEngine?
    private var stream: SCStream?
    private var microphone: SpeechChannel?
    private var computer: SpeechChannel?
    private var rotateTimer: Timer?
    private var microphoneTapInstalled = false
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    var level: (Double) -> Void = { _ in }

    @MainActor func start(config: Configuration) async throws {
        guard config.microphone || config.systemAudio else { throw VelinError.message("Enable microphone or computer audio in Audio settings.") }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw VelinError.message("Allow Speech Recognition in Setup before listening.") }
        do {
            if config.microphone {
                guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw VelinError.message("Allow Microphone in Setup before listening.") }
                let channel = try channel("You", config); microphone = channel; channel.begin()
                let engine = AVAudioEngine(); self.engine = engine
                let input = engine.inputNode, format = input.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { throw VelinError.message("No microphone is available. Connect one or disable microphone capture.") }
                input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self, weak channel] buffer, _ in
                    channel?.append(buffer)
                    if let samples = buffer.floatChannelData?[0] {
                        let count = Int(buffer.frameLength)
                        if count > 0 {
                            var sum: Float = 0
                            for i in 0..<count { sum += samples[i] * samples[i] }
                            let value = min(1, Double(sqrt(sum / Float(count))) * 8)
                            DispatchQueue.main.async { self?.level(value) }
                        }
                    }
                }
                microphoneTapInstalled = true; engine.prepare(); try engine.start()
            }
            if config.systemAudio {
                guard CGPreflightScreenCaptureAccess() else { throw VelinError.message("Allow Screen & System Audio Recording in Setup for computer audio.") }
                let channel = try channel("Computer", config); computer = channel; channel.begin()
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { throw VelinError.message("No display is available for system-audio capture.") }
                let filter = SCContentFilter(display: display, excludingApplications: content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }, exceptingWindows: [])
                let cfg = SCStreamConfiguration(); cfg.width = 2; cfg.height = 2
                cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                cfg.capturesAudio = true; cfg.excludesCurrentProcessAudio = true; cfg.sampleRate = 16000; cfg.channelCount = 1
                let stream = SCStream(filter: filter, configuration: cfg, delegate: self); self.stream = stream
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: .main)
                try await stream.startCapture()
            }
            rotateTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in self?.microphone?.rotate(); self?.computer?.rotate() }
        } catch { await stop(); throw error }
    }
    private func channel(_ source: String, _ config: Configuration) throws -> SpeechChannel {
        let channel = try SpeechChannel(source: source, locale: config.language, localOnly: config.localSpeechOnly)
        channel.partial = partial; channel.final = final; channel.failure = failure
        return channel
    }
    @MainActor func stop() async {
        rotateTimer?.invalidate(); rotateTimer = nil
        engine?.stop()
        if microphoneTapInstalled { engine?.inputNode.removeTap(onBus: 0); microphoneTapInstalled = false }
        engine = nil
        let oldStream = stream; stream = nil
        if let oldStream { try? await oldStream.stopCapture() }
        microphone?.stop(); computer?.stop(); microphone = nil; computer = nil; level(0)
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .audio, sampleBuffer.isValid { computer?.append(sampleBuffer) }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { DispatchQueue.main.async { [weak self] in self?.failure("Computer audio stopped: \(error.localizedDescription)") } }
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
