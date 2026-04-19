import AppKit
import SwiftUI

/// "What's New" modal shown after an app update, and reused as an embedded
/// view inside Settings → About. The same data source (`ReleaseNotesManifest`)
/// feeds both entry points.
public struct ReleaseNotesView: View {
    @ObservedObject private var localizationObserver = AppLocalizationObserver.shared

    let entry: ReleaseNotesEntry
    let onDismiss: () -> Void

    public init(entry: ReleaseNotesEntry, onDismiss: @escaping () -> Void) {
        self.entry = entry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String(format: L10n("Novidades no Fala %@"), entry.version))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(entry.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(Array(entry.localizedHighlights().enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            Text("•")
                                .font(.headline)
                                .foregroundStyle(FalaColors.success)
                            Text(line)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button(L10n("Entendi")) { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xxl)
        .frame(width: WindowSize.releaseNotesWidth)
        .id(localizationObserver.revision)
    }
}

@MainActor
public final class ReleaseNotesWindowController: NSObject, NSWindowDelegate {
    private static let shownKeyPrefix = "dev.fala.release-notes-shown-for."

    private var window: NSWindow?

    public override init() {}

    /// Shows the release notes modal if the current app version has a matching
    /// entry and hasn't been acknowledged by the user yet. Returns `true` if
    /// the window was presented.
    @discardableResult
    public func showIfNeededForCurrentVersion() -> Bool {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              !version.isEmpty,
              let entry = ReleaseNotesManifestLoader.entry(for: version),
              !Self.hasAcknowledged(version: version)
        else {
            return false
        }
        present(entry: entry)
        Self.markAcknowledged(version: version)
        return true
    }

    /// Shows a specific entry on demand (e.g. "Show release notes" menu).
    public func show(entry: ReleaseNotesEntry) {
        present(entry: entry)
    }

    private func present(entry: ReleaseNotesEntry) {
        let config = WindowConfig(
            title: L10n("Novidades"),
            width: WindowSize.releaseNotesWidth,
            height: WindowSize.releaseNotesDefaultHeight,
            styleMask: [.titled, .closable],
            isResizable: true,
            minSize: NSSize(
                width: WindowSize.releaseNotesWidth,
                height: WindowSize.releaseNotesMinHeight
            ),
            maxSize: NSSize(
                width: WindowSize.releaseNotesWidth,
                height: WindowSize.releaseNotesMaxHeight
            )
        )

        let content = ReleaseNotesView(entry: entry) { [weak self] in
            self?.window?.orderOut(nil)
        }

        if let window {
            WindowFactory.applyContent(content, config: config, to: window)
            WindowFactory.show(window)
            return
        }

        let win = WindowFactory.makeWindow(config: config, content: content)
        win.delegate = self
        self.window = win
        WindowFactory.show(win)
    }

    private static func hasAcknowledged(version: String) -> Bool {
        UserDefaults.standard.bool(forKey: shownKeyPrefix + version)
    }

    private static func markAcknowledged(version: String) {
        UserDefaults.standard.set(true, forKey: shownKeyPrefix + version)
    }
}
