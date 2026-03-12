import Foundation

/// CLI batch transcription mode.
/// Usage: fala transcribe <file> [--format txt|md] [--model <name>] [--profile] [--prepare-only]
public enum BatchMode {
    public static let supportedExtensions: Set<String> = ["m4a", "mp3", "wav", "mp4", "aac", "flac", "ogg"]

    public static func run(arguments: [String]) async throws {
        guard let inputPath = arguments.first else {
            throw BatchError.noInputFile
        }

        let inputURL = URL(fileURLWithPath: inputPath)
        let ext = inputURL.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw BatchError.unsupportedFormat(ext)
        }

        let config = AppConfig.load()
        let opts = parseOptions(arguments, config: config)
        let profiler = CLIBatchExecutionProfiler(inputURL: inputURL)
        var outcome: BatchExecutionOutcome = .failed

        do {
            let preparedAudio = try await prepareAudioInput(from: inputURL, profiler: profiler)
            let wavURL = preparedAudio.wavURL
            let needsCleanup = preparedAudio.requiresCleanup

            defer {
                if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
            }

            if opts.prepareOnly {
                print("Audio prepared.")
                outcome = .succeeded
            } else {
                try await performTranscription(
                    config: config,
                    wavURL: wavURL,
                    inputURL: inputURL,
                    options: opts,
                    profiler: profiler
                )

                outcome = .succeeded
            }

            await emitTimingLog(profiler: profiler, outcome: outcome)
        } catch is CancellationError {
            outcome = .cancelled
            await emitTimingLog(profiler: profiler, outcome: outcome)
            throw CancellationError()
        } catch {
            outcome = .failed
            await emitTimingLog(profiler: profiler, outcome: outcome)
            throw error
        }
    }

    private static func prepareAudioInput(
        from inputURL: URL,
        profiler: CLIBatchExecutionProfiler
    ) async throws -> PreparedBatchAudio {
        let preparedAudio = try await profiler.measure(.audioPreparation) {
            try BatchAudioPreparer.prepareTranscriptionInput(from: inputURL)
        }
        profiler.recordAudioPreparationMode(preparedAudio.mode)
        return preparedAudio
    }

    private static func performTranscription(
        config: AppConfig,
        wavURL: URL,
        inputURL: URL,
        options: BatchOptions,
        profiler: CLIBatchExecutionProfiler
    ) async throws {
        print("Model: \(options.model)")
        print("Transcribing \(inputURL.lastPathComponent)…")

        let outputURL = inputURL
            .deletingPathExtension()
            .appendingPathExtension(options.format)

        let transcriber: any AudioTranscribing = if config.transcriptionEngine == "parakeet" {
            ParakeetTranscriber()
        } else {
            Transcriber(modelName: options.model)
        }

        let loadState = await transcriber.loadState()
        profiler.recordModelLoadState(loadState)
        try await profiler.measure(.modelPreparation) {
            try await transcriber.loadIfNeeded(progress: nil)
        }

        let text = try await profiler.measure(.transcription) {
            try await transcriber.transcribe(audioPath: wavURL.path)
        }

        let content = options.format == "md"
            ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(text)\n"
            : text + "\n"

        try await profiler.measure(.fileSaving) {
            guard (try? content.write(
                to: outputURL, atomically: true, encoding: .utf8
            )) != nil else {
                throw BatchError.outputWriteFailed
            }
        }

        print("Done → \(outputURL.path)")
    }

    struct BatchOptions {
        var format: String
        var model: String
        var template: DictationTemplate
        var profile: Bool
        var prepareOnly: Bool
    }

    /// Parses `--format`, `--model`, `--mode`, and diagnostics flags from CLI arguments.
    static func parseOptions(_ arguments: [String], config: AppConfig) -> BatchOptions {
        var opts = BatchOptions(
            format: config.outputFormat,
            model: config.activeWhisperModel,
            template: config.selectedDictationTemplate,
            profile: false,
            prepareOnly: false
        )
        var idx = 1
        while idx < arguments.count {
            switch arguments[idx] {
            case "--format":
                idx += 1
                if idx < arguments.count { opts.format = arguments[idx] }
            case "--model":
                idx += 1
                if idx < arguments.count { opts.model = arguments[idx] }
            case "--mode":
                idx += 1
                if idx < arguments.count,
                   let parsed = DictationTemplate(rawValue: arguments[idx]) {
                    opts.template = parsed
                }
            case "--profile":
                opts.profile = true
            case "--prepare-only":
                opts.prepareOnly = true
            default:
                break
            }
            idx += 1
        }
        return opts
    }

    private static func emitTimingLog(
        profiler: CLIBatchExecutionProfiler,
        outcome: BatchExecutionOutcome
    ) async {
        let metrics = await profiler.snapshot(outcome: outcome)
        fputs("[Fala] Batch CLI timing \(metrics.debugSummary)\n", stderr)
    }
}

private final class CLIBatchExecutionProfiler {
    private let clock = ContinuousClock()
    private let totalStart: ContinuousClock.Instant
    private let inputURL: URL
    private var stageDurations: [BatchExecutionStage: Duration] = [:]
    private var audioPreparationMode: BatchAudioPreparationMode?
    private var modelLoadState: TranscriberLoadState?

    init(inputURL: URL) {
        self.totalStart = clock.now
        self.inputURL = inputURL
    }

    func measure<T>(
        _ stage: BatchExecutionStage,
        operation: () async throws -> T
    ) async rethrows -> T {
        let stageStart = clock.now
        do {
            let value = try await operation()
            stageDurations[stage] = clock.now - stageStart
            return value
        } catch {
            stageDurations[stage] = clock.now - stageStart
            throw error
        }
    }

    func recordAudioPreparationMode(_ mode: BatchAudioPreparationMode) {
        audioPreparationMode = mode
    }

    func recordModelLoadState(_ state: TranscriberLoadState) {
        modelLoadState = state
    }

    func snapshot(outcome: BatchExecutionOutcome) async -> BatchExecutionMetrics {
        let fileSize = (try? FileManager.default.attributesOfItem(
            atPath: inputURL.path
        )[.size] as? Int64) ?? nil
        let audioDuration = await AudioDurationReader.duration(of: inputURL)

        return BatchExecutionMetrics(
            fileName: inputURL.lastPathComponent,
            fileExtension: inputURL.pathExtension.lowercased(),
            inputFileSize: fileSize,
            audioDuration: audioDuration,
            usedPostProcessing: false,
            audioPreparationMode: audioPreparationMode,
            modelLoadState: modelLoadState,
            outcome: outcome,
            audioPreparation: stageDurations[.audioPreparation],
            modelPreparation: stageDurations[.modelPreparation],
            transcription: stageDurations[.transcription],
            postProcessing: stageDurations[.postProcessing],
            fileSaving: stageDurations[.fileSaving],
            total: clock.now - totalStart
        )
    }
}
