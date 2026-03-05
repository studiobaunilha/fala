import XCTest
import AVFoundation
@testable import FalaCore

/// Tests AudioConverter.toFloat16k using synthetically created audio files.
/// No microphone or hardware access is required — AVAudioFile can write/read
/// from disk in test processes.
final class AudioConverterTests: XCTestCase {

    // MARK: – Helpers

    /// Creates a silent mono WAV file at the given sample rate and duration,
    /// writes it to a temp path, and returns that URL.
    private func makeSilentWAV(sampleRate: Double, durationSeconds: Double) throws -> URL {
        let format = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)
        )
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        // All frames default to 0.0 (silence) — no explicit fill needed.

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).wav")

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    // MARK: – Tests

    func testSilentFileAt44100ProducesOutputAt16kHz() throws {
        let sourceRate = 44_100.0
        let duration = 1.0 // seconds

        let url = try makeSilentWAV(sampleRate: sourceRate, durationSeconds: duration)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        // Expected ~16 000 frames (with ±1 tolerance for rounding).
        let expected = Int(16_000 * duration)
        XCTAssertEqual(samples.count, expected, accuracy: 1)
    }

    func testSilentFileAt48000ProducesOutputAt16kHz() throws {
        let url = try makeSilentWAV(sampleRate: 48_000, durationSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        let expected = Int(16_000 * 0.5)
        XCTAssertEqual(samples.count, expected, accuracy: 1)
    }

    func testSilentSamplesAreAllZero() throws {
        let url = try makeSilentWAV(sampleRate: 44_100, durationSeconds: 0.1)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { $0 == 0.0 }, "Silent input must produce all-zero output")
    }

    func testAlreadyAt16kHzPassesThrough() throws {
        let url = try makeSilentWAV(sampleRate: 16_000, durationSeconds: 0.25)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        let expected = Int(16_000 * 0.25)
        XCTAssertEqual(samples.count, expected, accuracy: 1)
    }

    func testNonExistentFileThrows() {
        let url = URL(fileURLWithPath: "/nonexistent/file.wav")
        XCTAssertThrowsError(try AudioConverter.toFloat16k(from: url))
    }
}
