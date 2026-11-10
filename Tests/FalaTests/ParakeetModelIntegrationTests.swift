import CryptoKit
import FluidAudio
import XCTest
@testable import FalaCore

/// Model inference is an explicit local gate; ordinary unit runs do not download model weights.
final class ParakeetModelIntegrationTests: XCTestCase {
    func testSyntheticPortugueseControlKeepsComunicoIntactWithNameVocabulary() async throws {
        let url = try fixtureURL(environmentKey: "FALA_PARAKEET_NIKO_FIXTURE")
        let vocabulary = CustomVocabularyContext(terms: [CustomVocabularyTerm(text: "Niko", aliases: ["Nico"])])

        for model in ParakeetModel.allCases {
            let runtime = DefaultParakeetRuntimeManager(model: model)
            try await runtime.initializeIfNeeded()
            try await runtime.configureVocabularyBoosting(vocabulary)
            let boosted = try await runtime.transcribe(audioURL: url)
            await runtime.disableVocabularyBoosting()
            let unboosted = try await runtime.transcribe(audioURL: url)

            XCTAssertTrue(boosted.lowercased().contains("comunico"), "\(model): \(boosted)")
            XCTAssertFalse(boosted.lowercased().contains("comuniko"), "\(model): \(boosted)")
            XCTAssertTrue(unboosted.lowercased().contains("comunico"), "\(model): \(unboosted)")
            print("[Fala synthetic control] \(model.rawValue) boosted=\(boosted) unboosted=\(unboosted)")
        }
    }

    func testUltraAndV3TranscribeTheSamePublicAudioAsSamplesAndAsAFile() async throws {
        let url = try fixtureURL(environmentKey: "FALA_PARAKEET_JFK_FIXTURE")
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e")
        let samples = try FalaCore.AudioConverter.toFloat16k(from: url)

        for model in ParakeetModel.allCases {
            let transcriber = ParakeetTranscriber(
                runtime: DefaultParakeetRuntimeManager(model: model),
                vocabularyProvider: { ParakeetVocabularyStore() }
            )
            let dictation = try await transcriber.transcribe(samples: samples)
            let batch = try await transcriber.transcribe(audioPath: url.path)

            XCTAssertTrue(dictation.lowercased().contains("country"), "\(model): \(dictation)")
            XCTAssertTrue(batch.lowercased().contains("country"), "\(model): \(batch)")
            print("[Fala model smoke] \(model.rawValue) samples=\(dictation) file=\(batch)")
        }
    }

    private func fixtureURL(environmentKey: String) throws -> URL {
        guard let path = ProcessInfo.processInfo.environment[environmentKey] else {
            throw XCTSkip("Set \(environmentKey) to run the explicit model inference gate.")
        }
        return URL(fileURLWithPath: path)
    }
}
