import Foundation

/// CLI batch transcription mode.
/// Usage: sussurro transcribe <file> [--format txt|md] [--model <name>]
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
        let wavURL: URL
        let needsCleanup: Bool

        if ext == "wav" {
            wavURL = inputURL
            needsCleanup = false
        } else {
            let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            wavURL = tempDir.appendingPathComponent("sus_\(UUID().uuidString).wav")
            try await FFmpegConverter.convert(input: inputURL, output: wavURL)
            needsCleanup = true
        }

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
            model: config.batchModel,
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

// MARK: – FFmpeg process wrapper

public enum FFmpegConverter {
    private static let ffmpegPath = "/opt/homebrew/bin/ffmpeg"

    public static func convert(input: URL, output: URL) async throws {
        guard FileManager.default.fileExists(atPath: ffmpegPath) else {
            throw BatchError.ffmpegNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y",
            "-i", input.path,
            "-ar", "16000",
            "-ac", "1",
            "-f", "wav",
            output.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        try process.run()

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in cont.resume() }
        }

        guard process.terminationStatus == 0 else {
            throw BatchError.ffmpegFailed(process.terminationStatus)
        }
    }
}
