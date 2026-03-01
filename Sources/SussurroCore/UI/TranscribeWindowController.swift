import AppKit
import SwiftUI

/// Creates and manages the file transcription window.
@MainActor
public final class TranscribeWindowController {
    private var window: NSWindow?
    private let job: TranscriptionJob

    public init(job: TranscriptionJob) {
        self.job = job
    }

    public func show() {
        if let window {
            WindowFactory.show(window)
            return
        }
        makeWindow()
    }

    private func makeWindow() {
        let config = WindowConfig(
            title: "Transcrever Arquivo — Sussurro",
            width: WindowSize.transcribeDefaultWidth,
            height: WindowSize.transcribeDefaultHeight,
            isResizable: true,
            minSize: NSSize(width: WindowSize.transcribeMinWidth, height: WindowSize.transcribeMinHeight),
            maxSize: NSSize(width: WindowSize.transcribeMaxWidth, height: WindowSize.transcribeMaxHeight)
        )
        
        let win = WindowFactory.makeWindow(config: config, content: TranscribeView(job: job))
        self.window = win
        WindowFactory.show(win)
    }
}
