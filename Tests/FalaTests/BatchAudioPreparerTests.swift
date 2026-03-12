import AVFoundation
import XCTest
@testable import FalaCore

final class BatchAudioPreparerTests: XCTestCase {
    private func makeSilentAudioFile(
        sampleRate: Double,
        durationSeconds: Double,
        fileExtension: String
    ) throws -> URL {
        if fileExtension == "m4a" {
            return try makeExportedAACM4A(
                sampleRate: sampleRate,
                durationSeconds: durationSeconds,
                channels: 1,
                testCase: self
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

    func testPrepareTranscriptionInputReturnsOriginalWAVWithoutCleanup() throws {
        let wavURL = try makeSilentAudioFile(
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

    func testPrepareTranscriptionInputWritesNormalizedTemporaryWAVForNonWAVInput() throws {
        let sourceURL = try makeSilentAudioFile(
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

        XCTAssertNotEqual(prepared.wavURL.standardizedFileURL, sourceURL.standardizedFileURL)
        XCTAssertTrue(prepared.requiresCleanup)
        XCTAssertEqual(prepared.mode, .converted)
        XCTAssertEqual(prepared.wavURL.pathExtension.lowercased(), "wav")
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.wavURL.path))

        let file = try AVAudioFile(forReading: prepared.wavURL)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000, accuracy: 0.1)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
    }

    func testPrepareTranscriptionInputCleansPartialFileWhenConversionIsCancelled() throws {
        let sourceURL = try makeSilentAudioFile(
            sampleRate: 44_100,
            durationSeconds: 1.0,
            fileExtension: "m4a"
        )
        let tempDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        XCTAssertThrowsError(
            try BatchAudioPreparer.prepareTranscriptionInput(
                from: sourceURL,
                temporaryDirectory: tempDirectory
            ) {
                throw CancellationError()
            }
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }

        let createdFiles = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(createdFiles.isEmpty)
    }
}
