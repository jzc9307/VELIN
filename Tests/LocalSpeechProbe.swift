import AppKit
import AVFoundation

/// Optional real-engine fixture probe. Uses public audio, never a device or API.
@main struct LocalSpeechProbe {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 3 else { fatalError("Usage: LocalSpeechProbe MODEL PUBLIC_WAV") }
        let channel = MultilingualSpeechChannel(source: "Computer", modelPath: CommandLine.arguments[1], hint: "English. Preserve the spoken words.")
        var received = "", problem = ""
        channel.final = { _, text in received += " " + text }
        channel.failure = { problem = $0 }
        try await channel.begin(); defer { channel.stop() }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: CommandLine.arguments[2]))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { fatalError("Fixture buffer unavailable") }
        try file.read(into: buffer)
        channel.append(buffer)
        let timeout = Date().addingTimeInterval(25)
        while Date() < timeout && !received.lowercased().contains("country") && problem.isEmpty { try await Task.sleep(nanoseconds: 100_000_000) }
        guard problem.isEmpty && received.lowercased().contains("country") else { throw VelinError.message("Native local speech fixture failed: " + problem) }
        print("PASS: native PCM conversion, warm worker pipes, chunk queue and final-text callback produced the public English fixture locally.")
    }
}
