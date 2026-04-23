import AppKit
import CoreGraphics

/// Captures the currently selected text in the frontmost application
/// by simulating Cmd+C, reading the clipboard, then restoring it.
///
/// Requires Accessibility permission. Returns `nil` when no text is
/// selected or permissions are missing.
@MainActor
public struct SelectionCapture {
    private static let cKeyCode: CGKeyCode = 0x08 // kVK_ANSI_C

    public init() {}

    /// Attempts to capture the user's current text selection.
    ///
    /// The flow: snapshot clipboard → Cmd+C → read → restore clipboard.
    /// Returns `nil` when nothing is selected or Accessibility is off.
    public func captureSelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        let previousContents = PasteboardSnapshot.capture(from: pasteboard)

        print("[Fala] SelectionCapture: simulating Cmd+C...")
        simulateCmdC()

        // Give the target app time to write to the clipboard.
        try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms

        guard pasteboard.changeCount != changeCount else {
            // Clipboard unchanged — no selection was copied.
            print("[Fala] SelectionCapture: clipboard unchanged — no selection detected.")
            return nil
        }

        let captured = pasteboard.string(forType: .string)

        // Restore original clipboard content.
        previousContents.restore(to: pasteboard)

        // Only return meaningful content (not whitespace-only).
        guard let text = captured?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            print("[Fala] SelectionCapture: captured empty/whitespace text.")
            return nil
        }
        print("[Fala] SelectionCapture: captured \(text.count) chars.")
        return text
    }

    private func simulateCmdC() {
        let src = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(
                keyboardEventSource: src,
                virtualKey: Self.cKeyCode,
                keyDown: true
            ),
            let up = CGEvent(
                keyboardEventSource: src,
                virtualKey: Self.cKeyCode,
                keyDown: false
            )
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
