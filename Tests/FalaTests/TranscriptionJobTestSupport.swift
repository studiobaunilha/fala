import AVFoundation
import XCTest
@testable import FalaCore

@MainActor
class TranscriptionJobTestCase: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            AnimationConfig.enabled = false
            LicenseManager.shared.setTestActivated(true)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            LicenseManager.shared.setTestActivated(false)
        }
    }
}

@MainActor
func makeTestSettings(config: AppConfig = AppConfig()) -> AppSettings {
    let transcriber = Transcriber(modelName: "", language: "")
    return AppSettings(config: config, transcriber: transcriber, modelManager: ModelManager())
}

@MainActor
func makeTestBatchPool(whisperSpy: TranscriptionJobWhisperBatchSpy? = nil) -> BatchTranscriberPool {
    BatchTranscriberPool(
        whisperFactory: {
            BatchWhisperTranscriber(
                loadState: { .cold },
                loadIfNeeded: { _ in
                    if let whisperSpy {
                        try await whisperSpy.loadIfNeeded()
                    }
                },
                setModel: { modelName in
                    if let whisperSpy {
                        await whisperSpy.setModel(modelName)
                    }
                },
                setConfig: { language, temperature, prompt in
                    if let whisperSpy {
                        await whisperSpy.setConfig(
                            language: language,
                            temperature: temperature,
                            prompt: prompt
                        )
                    }
                },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { _, _, _ in "" }
            )
        },
        parakeetFactory: {
            BatchPreloadableTranscriber(
                loadState: { .cold },
                loadIfNeeded: { _ in },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { _, _, _ in "" }
            )
        }
    )
}

@MainActor
func makeTestBatchPool(queueSpy: BatchQueueTranscriberSpy) -> BatchTranscriberPool {
    BatchTranscriberPool(
        whisperFactory: {
            BatchWhisperTranscriber(
                loadState: { .cold },
                loadIfNeeded: { _ in },
                setModel: { _ in },
                setConfig: { _, _, _ in },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { audioPath, _, progress in
                    await queueSpy.record(audioPath: audioPath)
                    let stem = URL(fileURLWithPath: audioPath).deletingPathExtension().lastPathComponent
                    progress?(TranscriberProgress(text: stem.uppercased(), windowId: 0))
                    return stem.uppercased()
                }
            )
        },
        parakeetFactory: {
            BatchPreloadableTranscriber(
                loadState: { .cold },
                loadIfNeeded: { _ in },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { audioPath, _, progress in
                    await queueSpy.record(audioPath: audioPath)
                    let stem = URL(fileURLWithPath: audioPath).deletingPathExtension().lastPathComponent
                    progress?(TranscriberProgress(text: stem.uppercased(), windowId: 0))
                    return stem.uppercased()
                }
            )
        }
    )
}

@MainActor
func makeDelayedBatchPool(spy: DelayedBatchTranscriberSpy) -> BatchTranscriberPool {
    BatchTranscriberPool(
        whisperFactory: {
            BatchWhisperTranscriber(
                loadState: {
                    await spy.loadState()
                },
                loadIfNeeded: { _ in
                    try await spy.loadIfNeeded()
                },
                setModel: { _ in },
                setConfig: { _, _, _ in },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { audioPath, _, progress in
                    try await spy.transcribeAudioPath(
                        audioPath: audioPath,
                        progress: progress
                    )
                }
            )
        },
        parakeetFactory: {
            BatchPreloadableTranscriber(
                loadState: {
                    await spy.loadState()
                },
                loadIfNeeded: { _ in
                    try await spy.loadIfNeeded()
                },
                transcribeSamples: { _, _ in "" },
                transcribeAudioPath: { audioPath, _, progress in
                    try await spy.transcribeAudioPath(
                        audioPath: audioPath,
                        progress: progress
                    )
                }
            )
        }
    )
}

func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("fala-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func makeSilentWAV(in directory: URL, named name: String) throws -> URL {
    let format = try XCTUnwrap(
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )
    )
    let frameCount = AVAudioFrameCount(16_000 * 0.1)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount

    let url = directory.appendingPathComponent(name).appendingPathExtension("wav")
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    return url
}

func makeSilentAudioFile(
    in directory: URL,
    named name: String,
    fileExtension: String,
    sampleRate: Double = 44_100
) throws -> URL {
    if fileExtension == "m4a" {
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: true
            )
        )
        let frameCount = AVAudioFrameCount(sampleRate * 0.1)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount

        let url = directory.appendingPathComponent(name).appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return url
    }

    let format = try XCTUnwrap(
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
    )
    let frameCount = AVAudioFrameCount(sampleRate * 0.1)
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount

    let url = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    return url
}

@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() {
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
    XCTFail("Condition not met before timeout")
}

actor TranscriptionJobWhisperBatchSpy {
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

actor BatchQueueTranscriberSpy {
    struct Snapshot {
        let audioPaths: [String]
    }

    private var audioPaths: [String] = []

    func record(audioPath: String) {
        audioPaths.append(audioPath)
    }

    func snapshot() -> Snapshot {
        Snapshot(audioPaths: audioPaths)
    }
}

actor DelayedBatchTranscriberSpy {
    private let loadDelay: Duration
    private let transcribeDelay: Duration
    private var loadStarted = false
    private var loadStateValue: TranscriberLoadState
    private var transcribeAudioCallCountValue = 0

    init(
        loadDelay: Duration,
        transcribeDelay: Duration = .zero,
        initialLoadState: TranscriberLoadState = .cold
    ) {
        self.loadDelay = loadDelay
        self.transcribeDelay = transcribeDelay
        self.loadStateValue = initialLoadState
    }

    func loadIfNeeded() async throws {
        if loadStateValue == .ready {
            return
        }
        loadStateValue = .loading
        loadStarted = true
        if loadDelay > .zero {
            try await Task.sleep(for: loadDelay)
        }
        loadStateValue = .ready
    }

    func loadState() -> TranscriberLoadState {
        loadStateValue
    }

    func waitForLoadStart(timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if loadStarted {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for model preparation to start")
    }

    func transcribeAudioPath(
        audioPath: String,
        progress: (@Sendable (TranscriberProgress) -> Void)?
    ) async throws -> String {
        transcribeAudioCallCountValue += 1
        if transcribeDelay > .zero {
            try await Task.sleep(for: transcribeDelay)
        }
        let stem = URL(fileURLWithPath: audioPath).deletingPathExtension().lastPathComponent
        progress?(TranscriberProgress(text: stem.uppercased(), windowId: 0))
        return stem.uppercased()
    }

    func transcribeAudioCallCount() -> Int {
        transcribeAudioCallCountValue
    }

    func didStartLoading() -> Bool {
        loadStarted
    }
}

actor DelayedBatchAudioPreparationSpy {
    private let delay: Duration
    private let mode: BatchAudioPreparationMode
    private var started = false

    init(delay: Duration, mode: BatchAudioPreparationMode = .passthrough) {
        self.delay = delay
        self.mode = mode
    }

    func prepare(inputURL: URL) async throws -> PreparedBatchAudio {
        started = true
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        return PreparedBatchAudio(wavURL: inputURL, requiresCleanup: false, mode: mode)
    }

    func waitForStart(timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if started {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for audio preparation to start")
    }
}
