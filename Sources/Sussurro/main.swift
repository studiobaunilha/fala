import AppKit
import Foundation
import SussurroCore

let cliArgs = Array(CommandLine.arguments.dropFirst())

switch cliArgs.first {

case "transcribe":
    // ── CLI batch mode ────────────────────────────────────────────────────────
    let semaphore = DispatchSemaphore(value: 0)
    var exitCode: Int32 = 0

    Task {
        defer { semaphore.signal() }
        do {
            try await BatchMode.run(arguments: Array(cliArgs.dropFirst()))
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exitCode = 1
        }
    }

    semaphore.wait()
    exit(exitCode)

case "--help", "-h":
    print("""
    Sussurro — local audio transcription

    USAGE
      sussurro                              Start dictation mode (menu bar)
      sussurro transcribe <file> [options]  Transcribe an audio file

    DICTATION MODE
      Hold ⌥Space to record, release to transcribe and insert text.
      Default shortcut can be changed via the menu bar.

    TRANSCRIBE OPTIONS
      --format <txt|md>    Output format (default: from config, fallback: txt)
      --model  <name>      WhisperKit model (default: large-v3-turbo)

    SUPPORTED FORMATS
      .m4a  .mp3  .wav  .mp4  .aac  .flac  .ogg
    """)
    exit(0)

case nil:
    // ── Menu bar app mode ─────────────────────────────────────────────────────
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()

default:
    fputs("Unknown command: \(cliArgs[0])\nRun 'sussurro --help' for usage.\n", stderr)
    exit(1)
}
