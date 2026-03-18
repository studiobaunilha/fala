import AppKit
import ApplicationServices

/// Monitors the text of the currently focused UI element to detect manual corrections
/// made shortly after Fala inserts text.
@MainActor
public final class TextCorrectionObserver {
    private struct WordToken {
        let raw: String
        let normalized: String
    }

    public static let shared = TextCorrectionObserver()

    private var activeObserver: AXObserver?
    private var originalText: String = ""
    private var insertedText: String = ""
    private var monitoringTask: Task<Void, Never>?

    public var onCorrectionDetected: ((_ original: String, _ corrected: String) -> Void)?

    private init() {}

    /// Starts monitoring the currently focused element for changes relative to `insertedText`.
    /// The monitoring stops automatically after `timeout` seconds.
    public func startMonitoring(insertedText: String, timeout: TimeInterval = 6.0) {
        stopMonitoring()

        let trimmedInsertedText = insertedText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedInsertedText.isEmpty else { return }
        guard let focusedElement = getFocusedAXElement() else {
            print("[TextCorrectionObserver] Could not get focused element")
            return
        }

        self.insertedText = trimmedInsertedText

        // Wait briefly so the paste operation finishes and the app's internal AX tree updates
        monitoringTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }

            guard let currentText = self.getAXValue(for: focusedElement) else {
                print("[TextCorrectionObserver] Element does not support kAXValueAttribute")
                return
            }

            // The value immediately after paste is our baseline
            self.originalText = currentText

            // Setup the observer to listen for future edits
            self.setupObserver(for: focusedElement)

            // Stop automatically after timeout
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            if !Task.isCancelled {
                self.stopMonitoring()
            }
        }
    }

    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil

        if let observer = activeObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
            self.activeObserver = nil
        }
        self.originalText = ""
        self.insertedText = ""
    }

    private func setupObserver(for element: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return }

        var observer: AXObserver?

        // The callback logic
        let callback: AXObserverCallback = { _, axElement, notification, refcon in
            guard notification == kAXValueChangedNotification as CFString else { return }

            Task { @MainActor in
                guard let ref = refcon else { return }
                let instance = Unmanaged<TextCorrectionObserver>.fromOpaque(ref)
                    .takeUnretainedValue()
                instance.handleValueChanged(on: axElement)
            }
        }

        guard AXObserverCreate(pid, callback, &observer) == .success,
              let obs = observer else { return }

        // Pass `self` to the callback context
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(
            obs, element, kAXValueChangedNotification as CFString, refcon
        ) == .success else { return }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(obs),
            .defaultMode
        )
        self.activeObserver = obs
    }

    private func handleValueChanged(on element: AXUIElement) {
        guard let newText = getAXValue(for: element) else { return }

        if newText != originalText {
            // A change occurred! Let's pause to let the user finish typing.
            // We debounce this by restarting the timeout task.
            monitoringTask?.cancel()
            monitoringTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // wait 1.5s after last keystroke
                guard !Task.isCancelled else { return }

                self.evaluateCorrection(newText: newText)
                self.stopMonitoring()
            }
        }
    }

    private func evaluateCorrection(newText: String) {
        if let diff = extractCorrectionBase(
            oldText: originalText,
            newText: newText
        ), correctionBelongsToInsertedText(diff.original) {
            onCorrectionDetected?(diff.original, diff.corrected)
        }

        self.originalText = newText
    }

    // MARK: - Diffing Logic

    /// Finds a small word-level correction between `oldText` and `newText`.
    /// Pure punctuation changes and pure insertions/deletions are ignored.
    func extractCorrectionBase(
        oldText: String,
        newText: String
    ) -> (original: String, corrected: String)? {
        guard oldText != newText else { return nil }

        let oldTokens = wordTokens(in: oldText)
        let newTokens = wordTokens(in: newText)

        guard !oldTokens.isEmpty || !newTokens.isEmpty else { return nil }
        guard oldTokens.map(\.raw) != newTokens.map(\.raw) else { return nil }

        var prefixLen = 0
        while prefixLen < oldTokens.count,
              prefixLen < newTokens.count,
              oldTokens[prefixLen].raw == newTokens[prefixLen].raw {
            prefixLen += 1
        }

        var suffixLen = 0
        while suffixLen < (oldTokens.count - prefixLen),
              suffixLen < (newTokens.count - prefixLen),
              oldTokens[oldTokens.count - 1 - suffixLen].raw
                == newTokens[newTokens.count - 1 - suffixLen].raw {
            suffixLen += 1
        }

        let oldDiff = Array(oldTokens[prefixLen..<(oldTokens.count - suffixLen)])
        let newDiff = Array(newTokens[prefixLen..<(newTokens.count - suffixLen)])

        guard !oldDiff.isEmpty, !newDiff.isEmpty else { return nil }
        guard oldDiff.count <= 3, newDiff.count <= 3 else { return nil }

        let original = oldDiff.map(\.raw).joined(separator: " ")
        let corrected = newDiff.map(\.raw).joined(separator: " ")

        guard original.count <= 40, corrected.count <= 40 else {
            return nil
        }

        return (original, corrected)
    }

    private func correctionBelongsToInsertedText(_ original: String) -> Bool {
        correctionBelongsToInsertedText(original, insertedText: insertedText)
    }

    func correctionBelongsToInsertedText(_ original: String, insertedText: String) -> Bool {
        let insertedTokens = wordTokens(in: insertedText).map(\.normalized)
        let originalTokens = wordTokens(in: original).map(\.normalized)

        guard !insertedTokens.isEmpty, !originalTokens.isEmpty else {
            return false
        }
        guard originalTokens.count <= insertedTokens.count else {
            return false
        }

        let lastStart = insertedTokens.count - originalTokens.count
        for start in 0...lastStart {
            let end = start + originalTokens.count
            if Array(insertedTokens[start..<end]) == originalTokens {
                return true
            }
        }
        return false
    }

    private func wordTokens(in text: String) -> [WordToken] {
        let pattern = #"[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, range: range).map { match in
            let raw = nsText.substring(with: match.range)
            return WordToken(
                raw: raw,
                normalized: raw.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
            )
        }
    }

    // MARK: - AX Helpers

    private func getFocusedAXElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let attr = kAXFocusedApplicationAttribute as CFString
        guard AXUIElementCopyAttributeValue(systemWideElement, attr, &focusedApp) == .success,
              let appRef = focusedApp else { return nil }
        
        // swiftlint:disable:next force_cast
        let app = appRef as! AXUIElement
        
        var focusedElement: CFTypeRef?
        let elAttr = kAXFocusedUIElementAttribute as CFString
        guard AXUIElementCopyAttributeValue(
            app, elAttr, &focusedElement
        ) == .success, let elementRef = focusedElement else {
            return nil
        }
        // Force cast is unavoidable here as CFTypeRef must be downcast to AXUIElement.
        // swiftlint:disable:next force_cast
        return (elementRef as! AXUIElement)
    }

    private func getAXValue(for element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let valAttr = kAXValueAttribute as CFString
        guard AXUIElementCopyAttributeValue(element, valAttr, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
