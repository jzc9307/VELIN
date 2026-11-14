import AppKit
import AVFoundation
import CryptoKit
import Speech

/// Optional weights are kept out of Git and installers. Downloading never sends audio.
@MainActor final class SpeechModels: ObservableObject {
    static let shared = SpeechModels()
    @Published var downloading = false
    @Published var checking = false
    @Published var progress = 0.0
    @Published var result = ""
    @Published var installed: Set<String> = []
    @Published var downloadingID: String?
    private var download: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?
    static let baseSHA = SpeechModelOption.all[0].sha
    static let smallSHA = SpeechModelOption.all[1].sha
    static var folder: URL { SessionStore().root.appendingPathComponent("Models") }
    static func destination(_ option: SpeechModelOption) -> URL { folder.appendingPathComponent(option.fileName) }
    nonisolated static func verified(_ url: URL, sha: String) -> Bool {
        guard let stream = InputStream(url: url) else { return false }
        stream.open(); defer { stream.close() }
        var digest = Insecure.SHA1(), bytes = [UInt8](repeating: 0, count: 1_048_576)
        while true { let count = stream.read(&bytes, maxLength: bytes.count); if count < 0 { return false }; if count == 0 { break }; digest.update(data: Data(bytes.prefix(count))) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined() == sha
    }
    func refresh() {
        guard !checking, !downloading else { return }; checking = true
        let candidates = SpeechModelOption.all.map { ($0.id, Self.destination($0), $0.sha) }
        Task {
            let found = await Task.detached(priority: .utility) { Set(candidates.filter { Self.verified($0.1, sha: $0.2) }.map { $0.0 }) }.value
            installed = found; checking = false
        }
    }
    func fetch(_ option: SpeechModelOption, completion: @escaping (URL) -> Void) {
        guard !downloading, !checking else { return }
        let destination = Self.destination(option)
        if installed.contains(option.id), FileManager.default.fileExists(atPath: destination.path) { result = option.name + " already installed. Selected without downloading."; completion(destination); return }
        downloading = true; downloadingID = option.id; progress = 0; result = "Downloading " + option.name + ". No audio is uploaded."
        let url = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + option.fileName)!
        let task = URLSession.shared.downloadTask(with: url) { [weak self] temporary, response, error in
            do {
                if let error { throw error }
                guard let temporary, (response as? HTTPURLResponse)?.statusCode == 200 else { throw VelinError.message("The model download did not complete. Try again later.") }
                guard Self.verified(temporary, sha: option.sha) else { throw VelinError.message("Model integrity check failed. The downloaded file was not installed.") }
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                if FileManager.default.fileExists(atPath: destination.path) { _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary) }
                else { try FileManager.default.moveItem(at: temporary, to: destination) }
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
                Task { @MainActor in guard let self else { return }; self.downloading = false; self.downloadingID = nil; self.observation = nil; self.installed.insert(option.id); self.result = option.name + " installed and selected."; completion(destination) }
            } catch { let message = error.localizedDescription; Task { @MainActor in self?.downloading = false; self?.downloadingID = nil; self?.observation = nil; self?.result = message } }
        }
        download = task
        observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in let value = progress.fractionCompleted; Task { @MainActor in self?.progress = value } }
        task.resume()
    }
    func cancel() { download?.cancel() }
}

/// One warm local worker per enabled source. PCM stays in memory/private pipes.
final class MultilingualSpeechChannel: SpeechInput, @unchecked Sendable {
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    private let source: String, modelPath: String, hint: String
    private let state = NSLock()
    private var process: Process?
    private var token = UUID()
    private let audioQueue = DispatchQueue(label: "app.velin.multilingual.audio", qos: .userInitiated)
    private let decodeQueue = DispatchQueue(label: "app.velin.multilingual.decode", qos: .userInitiated)
    private var input: FileHandle?, output: FileHandle?
    private var samples: [Float] = [], quietSamples = 0
    private var converter: AVAudioConverter?
    private var busy = false, active = false
    private var flushTimer: DispatchSourceTimer?
    private var lastVoice = Date()
    init(source: String, modelPath: String, hint: String) { self.source = source; self.modelPath = modelPath; self.hint = String(hint.prefix(1000)) }
    func begin() async throws {
        guard FileManager.default.fileExists(atPath: modelPath) else { throw VelinError.message("Download or choose a multilingual model in Audio & Permissions first.") }
        guard let executable = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("VelinSpeech"), FileManager.default.isExecutableFile(atPath: executable.path) else { throw VelinError.message("The local speech worker is missing. Rebuild VELIN with scripts/build-speech.py.") }
        let worker = Process(), incoming = Pipe(), outgoing = Pipe()
        worker.executableURL = executable; worker.arguments = [modelPath, hint]
        worker.standardInput = incoming; worker.standardOutput = outgoing; worker.standardError = FileHandle.nullDevice
        try worker.run()
        let generation = state.withLock { process = worker; input = incoming.fileHandleForWriting; output = outgoing.fileHandleForReading; token = UUID(); return token }
        DispatchQueue.global().asyncAfter(deadline: .now() + 45) { [weak self, weak worker] in
            guard let self else { return }; self.state.lock(); let waiting = !self.active && self.token == generation; self.state.unlock(); if waiting && worker?.isRunning == true { worker?.terminate() }
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                decodeQueue.async { [weak self] in
                    do { _ = try Self.readFrame(outgoing.fileHandleForReading); guard let self else { throw CancellationError() }; self.state.lock(); self.active = true; self.state.unlock(); continuation.resume() }
                    catch { continuation.resume(throwing: VelinError.message("The local model could not load. Choose a multilingual ggml .bin model (not .en), or try the smaller Base model.")) }
                }
            }
        } catch { stop(); throw error }
        audioQueue.async { [weak self] in
            guard let self else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.audioQueue)
            timer.schedule(deadline: .now() + 0.25, repeating: 0.25)
            timer.setEventHandler { [weak self] in guard let self, !self.busy, self.samples.count >= 8000, Date().timeIntervalSince(self.lastVoice) > 0.65 else { return }; self.decode() }
            self.flushTimer = timer; timer.resume()
        }
        worker.terminationHandler = { [weak self] _ in guard let self else { return }; self.state.lock(); let report = self.active && self.token == generation; self.state.unlock(); if report { DispatchQueue.main.async { self.failure("Local multilingual speech stopped. Start Listen again to retry.") } } }
    }
    private static func readFrame(_ handle: FileHandle) throws -> String {
        func bytes(_ count: Int) throws -> Data { var data = Data(); while data.count < count { guard let next = try handle.read(upToCount: count - data.count), !next.isEmpty else { throw VelinError.message("Local worker closed its pipe.") }; data.append(next) }; return data }
        let header = try bytes(4); let size = header.enumerated().reduce(0) { $0 | Int($1.element) << ($1.offset * 8) }
        guard size <= 64000 else { throw VelinError.message("Local worker returned too much text.") }
        return String(data: try bytes(size), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let owned = Self.copy(buffer) else { return }
        audioQueue.async { [weak self] in self?.accept(owned) }
    }
    func append(_ sample: CMSampleBuffer) {
        let count = CMSampleBufferGetNumSamples(sample)
        guard count > 0, count < 1_000_000, let description = CMSampleBufferGetFormatDescription(sample) else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList) == noErr else { return }; append(buffer)
    }
    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard source.frameLength > 0, let destination = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        destination.frameLength = source.frameLength
        let from = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList), to = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard from.count == to.count else { return nil }
        for index in from.indices { guard let a = from[index].mData, let b = to[index].mData else { return nil }; memcpy(b, a, min(Int(from[index].mDataByteSize), Int(to[index].mDataByteSize))) }
        return destination
    }
    private func accept(_ buffer: AVAudioPCMBuffer) {
        state.lock(); let running = active; state.unlock(); guard running else { return }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else { return }
        if converter == nil || converter?.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: format) }
        guard let converter, let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * 16000 / buffer.format.sampleRate + 32)) else { return }
        var supplied = false, error: NSError?
        converter.convert(to: converted, error: &error) { _, status in if supplied { status.pointee = .noDataNow; return nil }; supplied = true; status.pointee = .haveData; return buffer }
        guard error == nil, let channel = converted.floatChannelData?[0], converted.frameLength > 0 else { return }
        let values = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
        let rms = AudioCapture.normalizedLevel(values)
        if rms < 0.025 { quietSamples += values.count } else { quietSamples = 0; lastVoice = Date() }
        if samples.isEmpty && rms < 0.025 { return } // Avoid silence hallucinations.
        samples += values
        if samples.count > 16000 * 20 { samples = []; DispatchQueue.main.async { [weak self] in self?.failure("Local speech could not keep up. Choose Base or the Apple engine and restart Listen.") }; return }
        if !busy && (samples.count >= 16000 * 6 || samples.count >= 16000 && quietSamples >= 8000) { decode() }
    }
    private func decode() {
        guard !samples.isEmpty, let input, let output else { return }
        let chunk = samples; samples.removeAll(keepingCapacity: true); quietSamples = 0; busy = true
        state.lock(); let generation = token; state.unlock()
        decodeQueue.async { [weak self] in
            guard let self else { return }
            do {
                var length = UInt32(chunk.count).littleEndian
                try withUnsafeBytes(of: &length) { try input.write(contentsOf: Data($0)) }
                try chunk.withUnsafeBytes { try input.write(contentsOf: Data($0)) }
                let words = try Self.readFrame(output)
                DispatchQueue.main.async { [weak self] in guard let self else { return }; self.state.lock(); let valid = self.active && self.token == generation; self.state.unlock(); if valid && words.rangeOfCharacter(from: .alphanumerics) != nil { self.final(self.source, words); self.partial(self.source, "") } }
            } catch { DispatchQueue.main.async { [weak self] in guard let self else { return }; self.state.lock(); let valid = self.active && self.token == generation; self.state.unlock(); if valid { self.failure("Local speech processing stopped. Restart Listen; your transcript is preserved.") } } }
            self.audioQueue.async { [weak self] in self?.busy = false }
        }
    }
    func rotate(after: TimeInterval) {}
    func stop() {
        state.lock(); active = false; token = UUID(); let worker = process; process = nil; state.unlock()
        worker?.terminationHandler = nil; if worker?.isRunning == true { worker?.terminate() }
        try? input?.close(); try? output?.close()
        audioQueue.async { [weak self] in self?.flushTimer?.cancel(); self?.flushTimer = nil; self?.samples = []; self?.converter = nil; self?.busy = false }
    }
    deinit { stop() }
}
