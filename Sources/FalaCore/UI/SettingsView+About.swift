import SwiftUI

extension SettingsView {
    var aboutApplicationSection: some View {
        Section(L10n("Sobre")) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Desenvolvido por"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(L10n("Studio Baunilha"))
                        .font(.headline)

                    Text(L10n("Inteligência Artificial para Mac, construída com paixão e performance."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Spacing.lg) {
                    if let url = URL(string: "https://studio.baunilha.dev") {
                        Link(destination: url) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "globe")
                                Text(L10n("Website"))
                            }
                        }
                    }

                    if let githubURL = URL(string: "https://github.com/studiobaunilha") {
                        Link(destination: githubURL) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                Text(L10n("GitHub"))
                            }
                        }
                    }
                }
                .buttonStyle(.link)

                Text(
                    "© \(Calendar.current.component(.year, from: Date())) "
                        + L10n("Studio Baunilha. Todos os direitos reservados.")
                )
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, Spacing.xs)
        }
    }
}
