import Foundation

/// CLI batch transcription mode.
/// Usage: fala transcribe <file> [--format txt|md] [--model <name>]
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

        // Convert to 16 kHz WAV if not already WAV.
        let preparedAudio = try BatchAudioPreparer.prepareTranscriptionInput(from: inputURL)
        let wavURL = preparedAudio.wavURL
        let needsCleanup = preparedAudio.requiresCleanup

        defer {
            if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
        }

        try await performTranscription(
            config: config,
            wavURL: wavURL,
            inputURL: inputURL,
            modelName: opts.model,
            outputFormat: opts.format
        )
    }

    private static func performTranscription(
        config: AppConfig,
        wavURL: URL,
        inputURL: URL,
        modelName: String,
        outputFormat: String
    ) async throws {
        print("Model: \(modelName)")
        print("Transcribing \(inputURL.lastPathComponent)…")
        
        let outputURL = inputURL
            .deletingPathExtension()
            .appendingPathExtension(outputFormat)

        let transcriber: any AudioTranscribing = config.transcriptionEngine == "parakeet"
            ? ParakeetTranscriber()
            : Transcriber(modelName: modelName)
        
        let text = try await transcriber.transcribe(audioPath: wavURL.path)

        let content = outputFormat == "md"
            ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(text)\n"
            : text + "\n"

        guard (try? content.write(to: outputURL, atomically: true, encoding: .utf8)) != nil else {
            throw BatchError.outputWriteFailed
        }

        print("Done → \(outputURL.path)")
    }

    struct BatchOptions {
        var format: String
        var model: String
        var template: DictationTemplate
    }

    /// Parses `--format`, `--model`, and `--mode` flags from CLI arguments.
    private static func parseOptions(_ arguments: [String], config: AppConfig) -> BatchOptions {
        var opts = BatchOptions(
            format: config.outputFormat,
            model: config.activeWhisperModel,
            template: config.selectedDictationTemplate
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
            default:
                break
            }
            idx += 1
        }
        return opts
    }
}
