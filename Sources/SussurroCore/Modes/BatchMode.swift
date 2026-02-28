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
        var outputFormat = config.outputFormat
        var modelName = config.batchModel

        var i = 1
        while i < arguments.count {
            switch arguments[i] {
            case "--format":
                i += 1
                if i < arguments.count { outputFormat = arguments[i] }
            case "--model":
                i += 1
                if i < arguments.count { modelName = arguments[i] }
            default:
                break
            }
            i += 1
        }

        // Convert to 16 kHz WAV if not already WAV.
        let wavURL: URL
        let needsCleanup: Bool

        if ext == "wav" {
            wavURL = inputURL
            needsCleanup = false
        } else {
            wavURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("sus_\(UUID().uuidString).wav")
            try await FFmpegConverter.convert(input: inputURL, output: wavURL)
            needsCleanup = true
        }

        defer {
            if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
        }

        print("Model: \(modelName)")
        print("Transcribing \(inputURL.lastPathComponent)…")

        let transcriber = Transcriber(modelName: modelName)
        let text = try await transcriber.transcribe(audioPath: wavURL.path)

        let outputURL = inputURL
            .deletingPathExtension()
            .appendingPathExtension(outputFormat)

        let content = outputFormat == "md"
            ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(text)\n"
            : text + "\n"

        guard (try? content.write(to: outputURL, atomically: true, encoding: .utf8)) != nil else {
            throw BatchError.outputWriteFailed
        }

        print("Done → \(outputURL.path)")
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
