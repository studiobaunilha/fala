import AVFoundation
import Foundation

@main
private enum AudioExportSDKSmoke {
    static func main() async throws {
        for channels: AVAudioChannelCount in [1, 2] {
            let url = try await makeExportedAACM4A(
                sampleRate: 48_000, durationSeconds: 0.5, channels: channels
            )
            defer { try? FileManager.default.removeItem(at: url) }
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            precondition(abs(duration - 0.5) < 0.01, "Export duration differs from generated source")
            let file = try AVAudioFile(forReading: url)
            precondition(file.fileFormat.streamDescription.pointee.mFormatID == kAudioFormatMPEG4AAC)
            precondition(file.processingFormat.sampleRate == 48_000)
            precondition(file.processingFormat.channelCount == channels)
            precondition(file.length > 0)
            print("Async M4A fixture PASS: channels=\(channels), sampleRate=48000, duration=\(duration), codec=AAC")
        }
        let url = try await makeSilentAudioFile(
            sampleRate: 48_000, durationSeconds: 0.5, channels: 2, fileExtension: "m4a"
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forReading: url)
        precondition(file.processingFormat.channelCount == 2 && file.length > 0)
        let wav = try makeSilentWAV(sampleRate: 16_000, durationSeconds: 0.25)
        defer { try? FileManager.default.removeItem(at: wav) }
        let wavFile = try AVAudioFile(forReading: wav)
        precondition(wavFile.length == 4_000 && wavFile.processingFormat.channelCount == 1)
        print("Shared M4A async and existing WAV synchronous helper PASS")
    }
}
