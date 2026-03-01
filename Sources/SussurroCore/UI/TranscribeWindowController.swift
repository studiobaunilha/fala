import AppKit
import SwiftUI

/// Creates and manages the file transcription window.
@MainActor
public final class TranscribeWindowController {
    private var window: NSWindow?
    private let job = TranscriptionJob()

    public init() {}

    public func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        makeWindow()
    }

    private func makeWindow() {
        let hosting = NSHostingView(rootView: TranscribeView(job: job))
        hosting.sizingOptions = .preferredContentSize

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Transcrever Arquivo — Sussurro"
        win.contentView = hosting
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}
