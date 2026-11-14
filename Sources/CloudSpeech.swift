import Foundation
import AVFoundation
import AppKit

/// Fixed WSS destination. Raw audio is sent only for an explicitly started cloud
/// control. No audio files, chat-provider keys, biography or screenshots are sent.
final class SonioxSpeechChannel: NSObject, SpeechInput, URLSessionTaskDelegate, @unchecked Sendable {
    var partial: (String, String) -> Void = { _, _ in }
    var final: (String, String) -> Void = { _, _ in }
    var failure: (String) -> Void = { _ in }
    private let source: String, key: String, endpoint: URL
    private var session: URLSession?, socket: URLSessionWebSocketTask?
    private var sender: Task<Void, Never>?, receiver: Task<Void, Never>?, keepalive: Timer?
    private let queue = DispatchQueue(label: "app.velin.cloud-speech.pcm")
    private let capacity = DispatchSemaphore(value: 8)
    private let lock = NSLock()
    private var continuation: AsyncStream<URLSessionWebSocketTask.Message>.Continuation?
    private var running = false
    private var generation = UUID()
    private var converter: AVAudioConverter?
    private var transcript = SonioxTranscript()
    init(source: String, key: String, endpoint: URL = SonioxProtocol.endpoint) {
        precondition(endpoint == SonioxProtocol.endpoint || endpoint.scheme == "ws" && endpoint.host == "127.0.0.1")
        self.source = source; self.key = key; self.endpoint = endpoint
    }
    @MainActor func begin() async throws {
        guard !key.isEmpty, !key.contains("\r"), !key.contains("\n") else { throw VelinError.message("Save a valid Soniox speech API key first.") }
        var request = URLRequest(url: endpoint); request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let socket = session.webSocketTask(with: request); socket.maximumMessageSize = 65536
        self.session = session; self.socket = socket; socket.resume()
        do { try await socket.send(.string(String(decoding: try JSONSerialization.data(withJSONObject: SonioxProtocol.configuration), as: UTF8.self))) }
        catch { socket.cancel(with: .goingAway, reason: nil); session.invalidateAndCancel(); throw VelinError.message("Soniox connection failed. Check the speech API key, network and service availability.") }
        let stream = AsyncStream<URLSessionWebSocketTask.Message>.makeStream(bufferingPolicy: .bufferingNewest(32))
        let token = UUID(); generation = token; transcript = SonioxTranscript()
        lock.withLock { running = true; continuation = stream.continuation }
        sender = Task { @MainActor [weak self] in
            do { for await frame in stream.stream { try Task.checkCancellation(); try await socket.send(frame) } }
            catch { guard let self, self.generation == token else { return }; self.fail("Soniox audio stream disconnected. Restart this control to retry.") }
        }
        receiver = Task { @MainActor [weak self] in
            do {
                while !Task.isCancelled {
                    let message = try await socket.receive(); guard let self, self.generation == token else { return }
                    let data: Data; switch message { case .data(let bytes): data = bytes; case .string(let text): data = Data(text.utf8); @unknown default: continue }
                    guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw VelinError.message("Invalid speech response.") }
                    for text in try self.transcript.accept(response) { self.final(self.source, text) }
                    self.partial(self.source, self.transcript.preview)
                    if response["finished"] as? Bool == true { self.fail("Soniox ended the session. Restart this audio control to continue."); return }
                }
            } catch { guard let self, self.generation == token else { return }; self.fail(error is VelinError ? error.localizedDescription : "Soniox transcription disconnected. Check the speech API key, credits and network.") }
        }
        keepalive = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in self?.enqueue(.string("{\"type\":\"keepalive\"}")) }
    }
    // Explicitly reject redirects rather than forwarding Authorization elsewhere.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    private func enqueue(_ message: URLSessionWebSocketTask.Message) {
        lock.lock(); let stream = running ? continuation : nil; lock.unlock()
        if let stream, case .dropped = stream.yield(message) { DispatchQueue.main.async { [weak self] in self?.fail("Cloud speech could not keep up with the network. Restart this audio control.") } }
    }
    private func fail(_ message: String) { lock.lock(); let active = running; lock.unlock(); guard active else { return }; stop(); failure(message) }
    func append(_ sample: CMSampleBuffer) {
        guard let description = CMSampleBufferGetFormatDescription(sample) else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: description), count = CMSampleBufferGetNumSamples(sample)
        guard count > 0, count <= 1000000, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = buffer.frameCapacity
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count), into: buffer.mutableAudioBufferList) == noErr else { return }
        append(buffer)
    }
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); let active = running; lock.unlock(); guard active else { return }
        guard capacity.wait(timeout: .now()) == .success else { DispatchQueue.main.async { [weak self] in self?.fail("Cloud speech PCM conversion fell behind. Restart this audio control.") }; return }
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { capacity.signal(); return }
        copy.frameLength = buffer.frameLength
        let a = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList), b = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in a.indices { guard let from = a[index].mData, let to = b[index].mData else { capacity.signal(); return }; memcpy(to, from, min(Int(a[index].mDataByteSize), Int(b[index].mDataByteSize))) }
        queue.async { [weak self] in guard let self else { return }; defer { self.capacity.signal() }
            self.lock.lock(); let active = self.running; self.lock.unlock(); guard active else { return }
            guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true) else { return }
            if self.converter?.inputFormat != copy.format { self.converter = AVAudioConverter(from: copy.format, to: format) }
            guard let converter = self.converter, let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(Double(copy.frameLength) * 16000 / copy.format.sampleRate + 64)) else { return }
            var supplied = false, error: NSError?
            converter.convert(to: output, error: &error) { _, status in if supplied { status.pointee = .noDataNow; return nil }; supplied = true; status.pointee = .haveData; return copy }
            guard error == nil, let bytes = output.audioBufferList.pointee.mBuffers.mData, output.frameLength > 0 else { return }
            self.enqueue(.data(Data(bytes: bytes, count: Int(output.frameLength) * 2)))
        }
    }
    func rotate(after: TimeInterval) { }
    func stop() {
        generation = UUID(); lock.lock(); running = false; continuation?.finish(); continuation = nil; lock.unlock()
        keepalive?.invalidate(); keepalive = nil; sender?.cancel(); receiver?.cancel(); sender = nil; receiver = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil; session?.invalidateAndCancel(); session = nil
        if !transcript.preview.isEmpty { final(source, transcript.preview) }; transcript = SonioxTranscript(); partial(source, "")
    }
}
