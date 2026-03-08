import XCTest
@testable import FalaCore

@MainActor
final class BatchTranscriberPoolTests: XCTestCase {

    func testWhisperTranscriberIsReusedAcrossBatchRequests() async {
        let whisperSpy = WhisperBatchSpy()
        let parakeetSpy = PreloadableBatchSpy()
        var whisperFactoryCalls = 0

        let pool = BatchTranscriberPool(
            whisperFactory: {
                whisperFactoryCalls += 1
                return BatchWhisperTranscriber(
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
                    loadIfNeeded: { _ in
                        try await parakeetSpy.loadIfNeeded()
                    },
                    transcribeSamples: { _, _ in "" },
                    transcribeAudioPath: { _, _, _ in "" }
                )
            }
        )

        var config = AppConfig()
        config.transcriptionEngine = "whisper"
        config.batchTemperature = 0.4

        _ = await pool.transcriber(using: config, modelName: "small", language: "pt")
        _ = await pool.transcriber(using: config, modelName: "large-v3", language: "en")

        let snapshot = await whisperSpy.snapshot()
        XCTAssertEqual(whisperFactoryCalls, 1)
        XCTAssertEqual(snapshot.models, ["small", "large-v3"])
        XCTAssertEqual(snapshot.languages, ["pt", "en"])
        XCTAssertEqual(snapshot.temperatures, [0.4, 0.4])
        XCTAssertEqual(snapshot.loadCount, 0)
    }

    func testWarmPreloadsCurrentWhisperBatchSelection() async throws {
        let whisperSpy = WhisperBatchSpy()

        let pool = BatchTranscriberPool(
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

        var config = AppConfig()
        config.transcriptionEngine = "whisper"
        config.batchModel = "medium"
        config.transcriptionLanguage = "pt-BR"
        config.batchTemperature = 0.2

        try await pool.warm(using: config)

        let snapshot = await whisperSpy.snapshot()
        XCTAssertEqual(snapshot.models, ["medium"])
        XCTAssertEqual(snapshot.languages, ["pt-BR"])
        XCTAssertEqual(snapshot.temperatures, [0.2])
        XCTAssertEqual(snapshot.loadCount, 1)
    }

    func testParakeetTranscriberIsReusedAcrossBatchRequests() async {
        let parakeetSpy = PreloadableBatchSpy()
        var parakeetFactoryCalls = 0

        let pool = BatchTranscriberPool(
            whisperFactory: {
                BatchWhisperTranscriber(
                    loadIfNeeded: { _ in },
                    setModel: { _ in },
                    setConfig: { _, _, _ in },
                    transcribeSamples: { _, _ in "" },
                    transcribeAudioPath: { _, _, _ in "" }
                )
            },
            parakeetFactory: {
                parakeetFactoryCalls += 1
                return BatchPreloadableTranscriber(
                    loadIfNeeded: { _ in
                        try await parakeetSpy.loadIfNeeded()
                    },
                    transcribeSamples: { _, _ in "" },
                    transcribeAudioPath: { _, _, _ in "" }
                )
            }
        )

        var config = AppConfig()
        config.transcriptionEngine = "parakeet"

        _ = await pool.transcriber(using: config, modelName: "ignored", language: "auto")
        _ = await pool.transcriber(using: config, modelName: "ignored", language: "auto")

        let loadCount = await parakeetSpy.currentLoadCount()
        XCTAssertEqual(parakeetFactoryCalls, 1)
        XCTAssertEqual(loadCount, 0)
    }
}

private actor WhisperBatchSpy {
    struct Snapshot {
        let models: [String]
        let languages: [String]
        let temperatures: [Float]
        let loadCount: Int
    }

    nonisolated let supportsTranslation = true

    private var models: [String] = []
    private var languages: [String] = []
    private var temperatures: [Float] = []
    private var loadCountValue = 0

    func loadIfNeeded() async throws {
        loadCountValue += 1
    }

    func setModel(_ name: String) {
        models.append(name)
    }

    func setConfig(language: String, temperature: Float, prompt: String) {
        languages.append(language)
        temperatures.append(temperature)
    }

    func snapshot() -> Snapshot {
        Snapshot(
            models: models,
            languages: languages,
            temperatures: temperatures,
            loadCount: loadCountValue
        )
    }
}

private actor PreloadableBatchSpy {
    private var loadCount = 0

    func loadIfNeeded() async throws {
        loadCount += 1
    }

    func currentLoadCount() -> Int {
        loadCount
    }
}
