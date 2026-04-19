import AppKit
import SwiftUI

extension SettingsView {
    var releaseNotesSection: some View {
        let entries = ReleaseNotesManifestLoader.load()
        let recent = Array(entries.prefix(3))
        return Section(L10n("Notas da versão")) {
            if recent.isEmpty {
                Text(L10n("Nenhuma nota de versão disponível."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(recent) { entry in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.sm) {
                                Text(String(format: L10n("Versão %@"), entry.version))
                                    .font(.headline)
                                Text(entry.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(
                                Array(entry.localizedHighlights().prefix(3).enumerated()),
                                id: \.offset
                            ) { _, line in
                                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                                    Text("•").foregroundStyle(.secondary)
                                    Text(line)
                                        .font(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                }
                .padding(.vertical, Spacing.xs)
            }
        }
    }
}
