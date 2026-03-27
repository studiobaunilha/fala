import XCTest
import FluidAudio
@testable import FalaCore

final class ParakeetTranscriberTests: XCTestCase {
    func testTranscribeSamplesConfiguresVocabularyBeforeTranscribing() async throws {
        let runtime = ParakeetRuntimeSpy()
        let transcriber = ParakeetTranscriber(
            runtime: runtime,
            vocabularyProvider: {
                ParakeetVocabularyStore(
                    replacementRules: [
                        ReplacementRule(variants: ["jirah"], replacement: "JIRA")
                    ]
                )
            }
        )

        let result = try await transcriber.transcribe(samples: [0.1], task: "transcribe")
        let initializeCalls = await runtime.initializeCalls()
        let configureCalls = await runtime.configureCalls()
        let transcribeCalls = await runtime.transcribeSamplesCalls()
        let configuredTerms = await runtime.lastConfiguredTermTexts()

        XCTAssertEqual(result, "Parakeet output")
        XCTAssertEqual(initializeCalls, 1)
        XCTAssertEqual(configureCalls, 1)
        XCTAssertEqual(transcribeCalls, 1)
        XCTAssertEqual(configuredTerms, ["JIRA"])
    }

    func testTranscribeSamplesDoesNotReconfigureSameVocabularyTwice() async throws {
        let runtime = ParakeetRuntimeSpy()
        let transcriber = ParakeetTranscriber(
            runtime: runtime,
            vocabularyProvider: {
                ParakeetVocabularyStore(
                    replacementRules: [
                        ReplacementRule(variants: ["jirah"], replacement: "JIRA")
                    ]
                )
            }
        )

        _ = try await transcriber.transcribe(samples: [0.1], task: "transcribe")
        _ = try await transcriber.transcribe(samples: [0.2], task: "transcribe")
        let initializeCalls = await runtime.initializeCalls()
        let configureCalls = await runtime.configureCalls()
        let transcribeCalls = await runtime.transcribeSamplesCalls()

        XCTAssertEqual(initializeCalls, 1)
        XCTAssertEqual(configureCalls, 1)
        XCTAssertEqual(transcribeCalls, 2)
    }

    func testTranscribeSamplesFallsBackWhenVocabularyConfigurationFails() async throws {
        let runtime = ParakeetRuntimeSpy()
        await runtime.setConfigureError(ParakeetRuntimeSpy.TestError.failedConfiguration)

        let transcriber = ParakeetTranscriber(
            runtime: runtime,
            vocabularyProvider: {
                ParakeetVocabularyStore(
                    replacementRules: [
                        ReplacementRule(variants: ["jirah"], replacement: "JIRA")
                    ]
                )
            }
        )

        let firstResult = try await transcriber.transcribe(samples: [0.1], task: "transcribe")
        let secondResult = try await transcriber.transcribe(samples: [0.2], task: "transcribe")
        let configureCalls = await runtime.configureCalls()
        let disableCalls = await runtime.disableCalls()
        let transcribeCalls = await runtime.transcribeSamplesCalls()

        XCTAssertEqual(firstResult, "Parakeet output")
        XCTAssertEqual(secondResult, "Parakeet output")
        XCTAssertEqual(configureCalls, 1)
        XCTAssertEqual(disableCalls, 1)
        XCTAssertEqual(transcribeCalls, 2)
    }

    func testTranscribeSamplesDisablesBoostingWhenVocabularyBecomesEmpty() async throws {
        let runtime = ParakeetRuntimeSpy()
        let storeBox = VocabularyStoreBox(
            store: ParakeetVocabularyStore(
                replacementRules: [
                    ReplacementRule(variants: ["jirah"], replacement: "JIRA")
                ]
            )
        )
        let transcriber = ParakeetTranscriber(
            runtime: runtime,
            vocabularyProvider: {
                storeBox.store
            }
        )

        _ = try await transcriber.transcribe(samples: [0.1], task: "transcribe")
        storeBox.store = ParakeetVocabularyStore()
        _ = try await transcriber.transcribe(samples: [0.2], task: "transcribe")
        let configureCalls = await runtime.configureCalls()
        let disableCalls = await runtime.disableCalls()
        let transcribeCalls = await runtime.transcribeSamplesCalls()

        XCTAssertEqual(configureCalls, 1)
        XCTAssertEqual(disableCalls, 1)
        XCTAssertEqual(transcribeCalls, 2)
    }
}

private final class VocabularyStoreBox: @unchecked Sendable {
    private let lock = NSLock()
    private var currentStore: ParakeetVocabularyStore

    init(store: ParakeetVocabularyStore) {
        self.currentStore = store
    }

    var store: ParakeetVocabularyStore {
        get {
            lock.withLock { currentStore }
        }
        set {
            lock.withLock {
                currentStore = newValue
            }
        }
    }
}

private actor ParakeetRuntimeSpy: ParakeetRuntimeManaging {
    enum TestError: Error {
        case failedConfiguration
    }

    private var initializeCallCount = 0
    private var configureCallCount = 0
    private var disableCallCount = 0
    private var transcribeSamplesCallCount = 0
    private var transcribeAudioCallCount = 0
    private var configuredTermTexts: [String] = []
    private var configureError: Error?

    func setConfigureError(_ error: Error?) {
        configureError = error
    }

    func initializeIfNeeded() async throws {
        initializeCallCount += 1
    }

    func configureVocabularyBoosting(_ vocabulary: CustomVocabularyContext) async throws {
        configureCallCount += 1
        configuredTermTexts = vocabulary.terms.map { $0.text }
        if let configureError {
            throw configureError
        }
    }

    func disableVocabularyBoosting() async {
        disableCallCount += 1
    }

    func transcribe(samples: [Float]) async throws -> String {
        transcribeSamplesCallCount += 1
        return "Parakeet output"
    }

    func transcribe(audioURL: URL) async throws -> String {
        transcribeAudioCallCount += 1
        return "Parakeet output"
    }

    func initializeCalls() -> Int {
        initializeCallCount
    }

    func configureCalls() -> Int {
        configureCallCount
    }

    func disableCalls() -> Int {
        disableCallCount
    }

    func transcribeSamplesCalls() -> Int {
        transcribeSamplesCallCount
    }

    func lastConfiguredTermTexts() -> [String] {
        configuredTermTexts
    }
}
