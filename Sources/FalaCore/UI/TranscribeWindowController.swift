import AppKit
import SwiftUI

/// Creates and manages the file transcription window.
@MainActor
public final class TranscribeWindowController {
    private var window: NSWindow?
    private let job: TranscriptionJob

    public init(settings: AppSettings) {
        self.job = TranscriptionJob(appSettings: settings)
    }

    var currentWindow: NSWindow? {
        window
    }

    public func show() {
        if let window {
            reloadLocalizedContent()
            WindowFactory.show(window)
            return
        }
        makeWindow()
    }

    public func reloadLocalizedContent() {
        guard let window else { return }
        WindowFactory.applyContent(TranscribeView(job: job), config: windowConfig, to: window)
    }

    private func makeWindow() {
        let config = windowConfig
        
        let win = WindowFactory.makeWindow(config: config, content: TranscribeView(job: job))
        self.window = win
        WindowFactory.show(win)
    }

    private var windowConfig: WindowConfig {
        WindowConfig(
            title: L10n("Transcrever Arquivo — Fala"),
            width: WindowSize.transcribeDefaultWidth,
            height: WindowSize.transcribeDefaultHeight,
            isResizable: true,
            minSize: NSSize(width: WindowSize.transcribeMinWidth, height: WindowSize.transcribeMinHeight),
            maxSize: NSSize(width: WindowSize.transcribeMaxWidth, height: WindowSize.transcribeMaxHeight)
        )
    }
}
