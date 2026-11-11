import AVFoundation
import XCTest
@testable import FalaCore

final class BatchAudioPreparerTests: XCTestCase {
    private func makeSilentAudioFile(
        sampleRate: Double,
        durationSeconds: Double,
        fileExtension: String
    ) async throws -> URL {
        if fileExtension == "m4a" {
            return try await makeExportedAACM4A(
                sampleRate: sampleRate,
                durationSeconds: durationSeconds,
                channels: 1
            )
        }

        let pcmFormat = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )
        )
        let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount))
        buffer.frameLength = frameCount

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("batch-audio-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        let file = try AVAudioFile(forWriting: url, settings: pcmFormat.settings)
        try file.write(from: buffer)
        return url
    }

    func testPrepareTranscriptionInputReturnsOriginalWAVWithoutCleanup() async throws {
        let wavURL = try await makeSilentAudioFile(
            sampleRate: 16_000,
            durationSeconds: 0.2,
            fileExtension: "wav"
        )
        defer { try? FileManager.default.removeItem(at: wavURL) }

        let prepared = try BatchAudioPreparer.prepareTranscriptionInput(from: wavURL)

        XCTAssertEqual(prepared.wavURL.standardizedFileURL, wavURL.standardizedFileURL)
        XCTAssertFalse(prepared.requiresCleanup)
        XCTAssertEqual(prepared.mode, .passthrough)
    }

    func testPrepareTranscriptionInputReturnsSamplesForNonWAVInput() async throws {
        let sourceURL = try await makeSilentAudioFile(
            sampleRate: 44_100,
            durationSeconds: 0.25,
            fileExtension: "m4a"
        )
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let prepared = try BatchAudioPreparer.prepareTranscriptionInput(from: sourceURL)
        defer {
            if prepared.requiresCleanup {
                try? FileManager.default.removeItem(at: prepared.wavURL)
            }
        }

        XCTAssertEqual(prepared.wavURL.standardizedFileURL, sourceURL.standardizedFileURL)
        XCTAssertFalse(prepared.requiresCleanup)
        XCTAssertEqual(prepared.mode, .converted)
        let extractedSamples = try XCTUnwrap(prepared.samples)
        XCTAssertFalse(extractedSamples.isEmpty)
    }

    func testPrepareTranscriptionInputCancellation() async throws {
        let sourceURL = try await makeSilentAudioFile(
            sampleRate: 44_100,
            durationSeconds: 1.0,
            fileExtension: "m4a"
        )
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }

        XCTAssertThrowsError(
            try BatchAudioPreparer.prepareTranscriptionInput(
                from: sourceURL
            ) {
                throw CancellationError()
            }
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }
}
