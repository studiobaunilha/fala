import AVFoundation
import Foundation

/// Thread-safe file writer for the AVAudioEngine tap callback.
private final class AudioWriter: @unchecked Sendable {
    private var file: AVAudioFile?
    private let lock = NSLock()

    func open(url: URL, settings: [String: Any]) throws {
        let f = try AVAudioFile(forWriting: url, settings: settings)
        lock.withLock { file = f }
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.withLock { try? file?.write(from: buffer) }
    }

    func close() {
        lock.withLock { file = nil }
    }
}

/// Captures microphone audio to a temporary WAV file.
///
/// NOT @MainActor intentionally: AVAudioEngine's tap callback runs on the
/// Core Audio I/O thread (RealtimeMessenger.mServiceQueue). If this class were
/// @MainActor, Swift 6 would SIGTRAP because the tap closure inherits the
/// enclosing function's actor isolation and the audio thread != main thread.
/// Thread safety is handled explicitly with NSLock instead.
public final class AudioEngine: @unchecked Sendable, AudioRecording {
    private let engine = AVAudioEngine()
    private let writer = AudioWriter()
    private let lock   = NSLock()
    private var tmpURL: URL?
    private var running = false

    public init() {}

    public func startRecording() throws {
        try lock.withLock {
            guard !running else { return }

            let inputNode = engine.inputNode
            let format    = inputNode.outputFormat(forBus: 0)

            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("sus_\(UUID().uuidString).wav")
            tmpURL = url

            try writer.open(url: url, settings: format.settings)

            // Capture only `writer` (@unchecked Sendable, no actor isolation).
            // Core Audio calls this closure on its own thread — no @MainActor here.
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [writer] buffer, _ in
                writer.write(buffer)
            }

            engine.prepare()
            try engine.start()
            running = true
        }
    }

    /// Stops recording and returns the URL of the temporary WAV file.
    /// Caller is responsible for deleting the file after use.
    public func stopRecording() throws -> URL {
        try lock.withLock {
            guard running else { throw AudioError.noRecording }
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            writer.close()
            running = false
            guard let url = tmpURL else { throw AudioError.noRecording }
            return url
        }
    }
}
