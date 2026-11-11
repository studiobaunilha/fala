import AVFoundation
import Foundation

// Standalone SDK smoke: no inputNode, microphone, capture device or project app instance.
private struct TapSnapshot {
    let frames: Int
    let rms: Float
    let failed: Bool
}

private enum SmokeError: Error {
    case invalidFormat
    case bufferAllocation
}

private final class TapResult: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames = 0
    private var rms: Float = 0
    private var failed = false

    init(url: URL, format: AVAudioFormat) throws {
        file = try AVAudioFile(forWriting: url, settings: format.settings)
    }

    func consume(_ buffer: AVReadOnlyAudioPCMBuffer) {
        lock.withLock {
            guard let file else { return }
            do {
                try file.write(from: buffer)
                let count = buffer.frameLength
                guard count > 0, case .float(let data) = buffer.channelData(0) else { return }
                var sum: Float = 0
                for index in 0..<count { sum += data[index] * data[index] }
                rms = sqrt(sum / Float(count))
                frames += count
            } catch {
                failed = true
            }
        }
    }

    var receivedFrames: Int { lock.withLock { frames } }

    func finish() -> TapSnapshot {
        lock.withLock {
            file?.close()
            file = nil
            return TapSnapshot(frames: frames, rms: rms, failed: failed)
        }
    }
}

@main
private enum AudioTapSDKSmoke {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let channels = AVAudioChannelCount(CommandLine.arguments[2]),
              let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: channels) else {
            throw SmokeError.invalidFormat
        }
        let engine = AVAudioEngine()
        let source = AVAudioSourceNode(format: format) { _, _, count, buffers in
            for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
                guard let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for index in 0..<Int(count) { pointer[index] = 0.25 }
            }
            return noErr
        }
        engine.attach(source)
        try engine.connectNode(source, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4_096)
        let result = try TapResult(url: url, format: format)
        try source.installAudioTap(onBus: 0, bufferSize: 8_192, format: format) { buffer, _ in
            result.consume(buffer)
        }
        try engine.start()
        guard let output = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4_096) else {
            throw SmokeError.bufferAllocation
        }
        for _ in 0..<16 {
            let status = try engine.renderOffline(4_096, to: output)
            precondition(status == .success, "Offline engine did not render successfully")
        }
        let deadline = Date().addingTimeInterval(2)
        while result.receivedFrames == 0 && Date() < deadline { Thread.sleep(forTimeInterval: 0.005) }
        engine.stop()
        source.removeTap(onBus: 0)
        let snapshot = result.finish()
        precondition(!snapshot.failed && snapshot.frames > 0, "New tap did not write PCM")
        precondition(abs(snapshot.rms - 0.25) < 0.000_01, "RMS differs from golden constant PCM")
        let read = try AVAudioFile(forReading: url)
        precondition(read.length == AVAudioFramePosition(snapshot.frames), "Written frame count differs")
        let buffer = try read.read(frameCount: AVAudioFrameCount(snapshot.frames))
        for channel in 0..<Int(channels) {
            guard case .float(let samples) = buffer.channelData(channel) else {
                preconditionFailure("Roundtrip did not return float PCM")
            }
            for sample in samples {
                precondition(abs(sample - 0.25) < 0.000_01, "WAV samples differ from golden PCM")
            }
        }
        print("SDK27 offline tap PASS: channels=\(channels), frames=\(snapshot.frames), RMS=\(snapshot.rms)")
        print("WAV samples preserved; no microphone/device capture")
    }
}
