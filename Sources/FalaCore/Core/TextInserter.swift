import AppKit
import ApplicationServices
import CoreGraphics

/// Inserts text at the current cursor position using clipboard + Cmd+V.
/// Saves and restores the previous clipboard content.
///
/// Requires Accessibility permission (System Settings → Privacy → Accessibility).
/// If not granted, falls back to copying text to the clipboard without pasting.
@MainActor
public struct TextInserter: TextInserting {
    private static let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
    private static let zKeyCode: CGKeyCode = 0x06 // kVK_ANSI_Z

    public init() {}

    public func saveToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    public func insert(_ text: String) async {
        guard isAccessibilityTrusted(prompt: true) else {
            // Accessibility not granted yet: copy to clipboard so text is not lost.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            return
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Let the clipboard settle before simulating the keystroke.
        try? await Task.sleep(nanoseconds: 50_000_000)
        simulateCmdV()

        // Restore previous clipboard asynchronously after paste completes.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            pasteboard.clearContents()
            if let prev = previousString {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }

    public func undoLastInsertion() async {
        guard isAccessibilityTrusted(prompt: true) else {
            return
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        simulateCommandKey(Self.zKeyCode)
    }

    public func replaceLastInsertion(with text: String) async {
        guard isAccessibilityTrusted(prompt: true) else {
            saveToClipboard(text)
            return
        }

        await undoLastInsertion()
        try? await Task.sleep(nanoseconds: 80_000_000)
        await insert(text)
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func simulateCmdV() {
        simulateCommandKey(Self.vKeyCode)
    }

    private func simulateCommandKey(_ keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
            let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags   = .maskCommand

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
