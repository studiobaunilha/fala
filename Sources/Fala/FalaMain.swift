import AppKit
import Foundation
import FalaCore

@main
enum FalaMain {
    static func main() async {
        let cliArgs = Array(CommandLine.arguments.dropFirst())

        switch cliArgs.first {
        case "transcribe":
            do {
                try await BatchMode.run(arguments: Array(cliArgs.dropFirst()))
                exit(0)
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
                exit(1)
            }

        case "mlx-smoke":
            do {
                try await MLXSmokeMode().run(arguments: Array(cliArgs.dropFirst()))
                exit(0)
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
                exit(1)
            }

        case "--help", "-h":
            print(helpText)
            exit(0)

        case nil:
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()

        default:
            fputs("Unknown command: \(cliArgs[0])\nRun 'fala --help' for usage.\n", stderr)
            exit(1)
        }
    }
}

private extension FalaMain {
    static let helpText = """
    Fala — local audio transcription

    USAGE
      fala                              Start dictation mode (menu bar)
      fala transcribe <file> [options]  Transcribe an audio file
      fala mlx-smoke                    Validate local MLX inference on the packaged app binary

    DICTATION MODE
      Hold ⌥Space to record, release to transcribe and insert text.
      Default shortcut can be changed via the menu bar.

    TRANSCRIBE OPTIONS
      --format <txt|md>    Output format (default: from config, fallback: txt)
      --model  <name>      WhisperKit model (default: large-v3-turbo)
      --parakeet-model <ultra|v3>  Use this Parakeet model for this invocation only
      --profile           Print timing diagnostics for audio prep and model warmup
      --prepare-only      Normalize audio and exit before model warmup/transcription

    MLX SMOKE
      Runs a real local inference using the packaged app runtime and any
      downloaded smoke-verified MLX model.

    SUPPORTED FORMATS
      .m4a  .mp3  .wav  .mp4  .aac  .flac  .ogg
    """
}
