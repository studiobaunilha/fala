import XCTest
@testable import FalaCore

@MainActor
final class TranscriptionJobTests: XCTestCase {

    override func setUp() async throws {
        await MainActor.run { AnimationConfig.enabled = false }
    }

    private func buildSettings(config: AppConfig = AppConfig()) -> AppSettings {
        let transcriber = Transcriber(modelName: "", language: "")
        return AppSettings(config: config, transcriber: transcriber, modelManager: ModelManager())
    }

    func testInitialStateIsIdle() {
        let job = TranscriptionJob(appSettings: buildSettings())
        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testResetClearsState() {
        let job = TranscriptionJob(appSettings: buildSettings())
        job.inputURL = URL(fileURLWithPath: "/tmp/test.wav")
        job.state = .error("Test error")

        job.reset()

        XCTAssertEqual(job.state, .idle)
        XCTAssertNil(job.inputURL)
    }

    func testTranscribeRequiresInputURL() {
        let job = TranscriptionJob(appSettings: buildSettings())
        job.transcribe() // No inputURL set

        XCTAssertEqual(job.state, .idle) // Remains idle
    }

    func testOutputFormatDefaultsFromConfig() {
        // Just verify it doesn't crash and gets a string (from default AppConfig)
        let job = TranscriptionJob(appSettings: buildSettings())
        XCTAssertFalse(job.outputFormat.isEmpty)
    }

    func testPrepareForUseWarmsPoolWithOverrideModelAndLanguage() async {
        let whisperSpy = WhisperBatchSpy()
        var config = AppConfig()
        config.transcriptionEngine = "whisper"
        let job = TranscriptionJob(
            appSettings: buildSettings(config: config),
            batchTranscriberPool: makeBatchPool(whisperSpy: whisperSpy)
        )
        job.overrideModel = "medium"
        job.overrideLanguage = "pt-BR"

        job.prepareForUse()
        try? await Task.sleep(for: .milliseconds(20))

        let snapshot = await whisperSpy.snapshot()
        XCTAssertEqual(snapshot.models, ["medium"])
        XCTAssertEqual(snapshot.languages, ["pt-BR"])
        XCTAssertEqual(snapshot.loadCount, 1)
    }

    func testResetClearsProcessingWarning() {
        let job = TranscriptionJob(appSettings: buildSettings())
        job.processingWarning = BatchProcessingWarning(
            title: "Aviso",
            message: "Detalhe"
        )

        job.reset()

        XCTAssertNil(job.processingWarning)
    }

    func testApplyLLMWithOutcomeReturnsWarningWhenMLXFails() async {
        var config = AppConfig()
        config.llmProvider = "mlx"
        config.mlxModel = "mlx-community/fala-test-missing-model"

        let outcome = await TranscriptionJob.applyLLMWithOutcome(
            to: "Texto original",
            config: config,
            template: .askAI
        )

        XCTAssertEqual(outcome.text, "Texto original")
        XCTAssertEqual(outcome.warning?.title, "Pós-processamento com IA não foi aplicado")
        XCTAssertTrue(
            outcome.warning?.message.contains("MLX Local") == true
        )
    }

    private func makeBatchPool(whisperSpy: WhisperBatchSpy) -> BatchTranscriberPool {
        BatchTranscriberPool(
            whisperFactory: {
                BatchWhisperTranscriber(
                    loadIfNeeded: { _ in
                        try await whisperSpy.loadIfNeeded()
                    },
                    setModel: { modelName in
                        await whisperSpy.setModel(modelName)
                    },
                    setConfig: { language, temperature, prompt in
                        await whisperSpy.setConfig(
                            language: language,
                            temperature: temperature,
                            prompt: prompt
                        )
                    },
                    transcribeSamples: { _, _ in "" },
                    transcribeAudioPath: { _, _, _ in "" }
                )
            },
            parakeetFactory: {
                BatchPreloadableTranscriber(
                    loadIfNeeded: { _ in },
                    transcribeSamples: { _, _ in "" },
                    transcribeAudioPath: { _, _, _ in "" }
                )
            }
        )
    }
}

private actor WhisperBatchSpy {
    struct Snapshot {
        let models: [String]
        let languages: [String]
        let loadCount: Int
    }

    private var models: [String] = []
    private var languages: [String] = []
    private var loadCountValue = 0

    func loadIfNeeded() async throws {
        loadCountValue += 1
    }

    func setModel(_ name: String) {
        models.append(name)
    }

    func setConfig(language: String, temperature: Float, prompt: String) {
        languages.append(language)
    }

    func snapshot() -> Snapshot {
        Snapshot(
            models: models,
            languages: languages,
            loadCount: loadCountValue
        )
    }
}
