import AVFoundation
import XCTest
@testable import FalaCore

private final class CancellationCheckCounter: @unchecked Sendable {
    var value = 0
}

/// Tests AudioConverter.toFloat16k using synthetically created audio files.
/// No microphone or hardware access is required — AVAudioFile can write/read
/// from disk in test processes.
final class AudioConverterTests: XCTestCase {
    func testSilentFileAt44100ProducesOutputAt16kHz() throws {
        let sourceRate = 44_100.0
        let duration = 1.0

        let url = try makeSilentWAV(sampleRate: sourceRate, durationSeconds: duration)
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

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

    func testStereoAACM4AProducesOutputAt16kHzMono() throws {
        let url = try makeSilentAudioFile(
            sampleRate: 48_000,
            durationSeconds: 0.5,
            channels: 2,
            fileExtension: "m4a"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        let expected = Int(16_000 * 0.5)
        XCTAssertEqual(samples.count, expected, accuracy: 2)
        XCTAssertTrue(samples.allSatisfy { $0 == 0.0 }, "Silent input must produce all-zero output")
    }

    func testWrite16kMonoWAVSupportsStereoAACM4AInput() throws {
        let sourceURL = try makeSilentAudioFile(
            sampleRate: 48_000,
            durationSeconds: 0.5,
            channels: 2,
            fileExtension: "m4a"
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try AudioConverter.write16kMonoWAV(from: sourceURL, to: outputURL)

        let file = try AVAudioFile(forReading: outputURL)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
    }

    func testExportedAACM4AProducesOutputAt16kHzMono() throws {
        let url = try makeExportedAACM4A(
            sampleRate: 48_000,
            durationSeconds: 0.5,
            testCase: self
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let samples = try AudioConverter.toFloat16k(from: url)

        let expected = Int(16_000 * 0.5)
        XCTAssertEqual(samples.count, expected, accuracy: 2)
        XCTAssertTrue(samples.allSatisfy { $0 == 0.0 }, "Silent input must produce all-zero output")
    }

    func testWrite16kMonoWAVSupportsExportedAACM4AInput() throws {
        let sourceURL = try makeExportedAACM4A(
            sampleRate: 48_000,
            durationSeconds: 0.5,
            testCase: self
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("exported-converted-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        try AudioConverter.write16kMonoWAV(from: sourceURL, to: outputURL)

        let file = try AVAudioFile(forReading: outputURL)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
    }

    func testWrite16kMonoWAVPropagatesCancellationCheck() throws {
        let sourceURL = try makeSilentWAV(sampleRate: 44_100, durationSeconds: 1.0)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancelled-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        let counter = CancellationCheckCounter()

        XCTAssertThrowsError(
            try AudioConverter.write16kMonoWAV(from: sourceURL, to: outputURL) {
                counter.value += 1
                if counter.value >= 1 {
                    throw CancellationError()
                }
            }
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(counter.value, 1)
    }
}
