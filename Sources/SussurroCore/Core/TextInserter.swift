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

    public init() {}

    public func insert(_ text: String) {
        guard AXIsProcessTrusted() else {
            // Accessibility not granted: copy to clipboard so text is not lost.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            print("""
            [Sussurro] Texto copiado para o clipboard (Acessibilidade não habilitada).
            → Abra: Ajustes do Sistema → Privacidade e Segurança → Acessibilidade
            → Habilite Sussurro na lista.
            """)
            return
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Let the clipboard settle before simulating the keystroke.
        Thread.sleep(forTimeInterval: 0.05)
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

    private func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        guard
            let down = CGEvent(keyboardEventSource: src, virtualKey: Self.vKeyCode, keyDown: true),
            let up   = CGEvent(keyboardEventSource: src, virtualKey: Self.vKeyCode, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags   = .maskCommand

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
