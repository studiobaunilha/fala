import XCTest
import FluidAudio
@testable import FalaCore

final class VocabularyScopedTranscriberTests: XCTestCase {
    func testConcurrentSnapshotsKeepTheirVocabularyOnOneRuntime() async throws {
        let runtime = ScopedVocabularyRuntime()
        let parent = ParakeetTranscriber(runtime: runtime, vocabularyProvider: { .init() })
        let first = parent.scoped(to: .init(terms: [ParakeetVocabularyTerm(text: "Alpha")]))
        let second = parent.scoped(to: .init(terms: [ParakeetVocabularyTerm(text: "Beta")]))
        async let firstResult = first.transcribe(samples: [0.1], task: "transcribe")
        async let secondResult = second.transcribe(samples: [0.2], task: "transcribe")
        let results = try await (firstResult, secondResult)
        XCTAssertEqual(results.0, "Alpha")
        XCTAssertEqual(results.1, "Beta")
        let empty = parent.scoped(to: .init())
        let emptyResult = try await empty.transcribe(samples: [0.3], task: "transcribe")
        XCTAssertEqual(emptyResult, "Default")
        let initializationCount = await runtime.initializationCount
        XCTAssertEqual(initializationCount, 1)
    }

    func testCancellationWhileWaitingDoesNotConfigureAnotherVocabulary() async throws {
        let inferenceStarted = expectation(description: "first inference acquired lease")
        let runtime = ScopedVocabularyRuntime(blockFirstInference: true, onFirstInference: {
            inferenceStarted.fulfill()
        })
        let parent = ParakeetTranscriber(runtime: runtime, vocabularyProvider: { .init() })
        let first = parent.scoped(to: .init(terms: [ParakeetVocabularyTerm(text: "Alpha")]))
        let second = parent.scoped(to: .init(terms: [ParakeetVocabularyTerm(text: "Beta")]))
        let firstTask = Task { try await first.transcribe(samples: [0.1], task: "transcribe") }
        defer {
            firstTask.cancel()
            Task { await runtime.releaseFirstInference() }
        }
        await fulfillment(of: [inferenceStarted], timeout: 1)
        guard await runtime.firstInferenceStarted else { return }
        let secondTask = Task { try await second.transcribe(samples: [0.2], task: "transcribe") }
        secondTask.cancel()
        await runtime.releaseFirstInference()
        let firstResult = try await firstTask.value
        XCTAssertEqual(firstResult, "Alpha")
        do {
            _ = try await secondTask.value
            XCTFail("A cancelled request must not infer with another vocabulary")
        } catch is CancellationError {
            let configured = await runtime.configuredVocabularies
            XCTAssertEqual(configured, ["Alpha"])
        }
    }
}

private actor ScopedVocabularyRuntime: ParakeetRuntimeManaging {
    private var vocabulary = "Default"
    private(set) var firstInferenceStarted = false
    private let onFirstInference: (@Sendable () -> Void)?
    private var wasReleased = false
    private var blockedInference: CheckedContinuation<Void, Never>?
    private var blockFirstInference: Bool
    private(set) var initializationCount = 0
    private(set) var configuredVocabularies: [String] = []

    init(blockFirstInference: Bool = false, onFirstInference: (@Sendable () -> Void)? = nil) {
        self.blockFirstInference = blockFirstInference
        self.onFirstInference = onFirstInference
    }

    func initializeIfNeeded() async throws { initializationCount += 1 }

    func configureVocabularyBoosting(_ vocabulary: CustomVocabularyContext) async throws {
        self.vocabulary = vocabulary.terms.map(\.text).joined(separator: ",")
        configuredVocabularies.append(self.vocabulary)
        await Task.yield()
    }

    func disableVocabularyBoosting() async { vocabulary = "Default" }

    func transcribe(samples: [Float]) async throws -> String {
        if !firstInferenceStarted {
            firstInferenceStarted = true
            onFirstInference?()
        }
        if blockFirstInference && !wasReleased {
            blockFirstInference = false
            await withCheckedContinuation { blockedInference = $0 }
        }
        await Task.yield()
        return vocabulary
    }

    func transcribe(audioURL: URL) async throws -> String { try await transcribe(samples: []) }

    func releaseFirstInference() {
        wasReleased = true
        blockedInference?.resume()
        blockedInference = nil
    }
}
