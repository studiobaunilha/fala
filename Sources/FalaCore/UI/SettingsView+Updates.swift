import SwiftUI
import Sparkle

extension SettingsView {
    var applicationIdentitySection: some View {
        Section {
            HStack(spacing: Spacing.xl) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Fala"))
                        .font(.title2)
                        .fontWeight(.bold)

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text(L10n("Versão") + " \(version) (\(build))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    @ViewBuilder
    var updatesPreferencesSection: some View {
        Section {
            if let updater = settings.updater {
                Toggle(
                    L10n("Verificar atualizações automaticamente"),
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                )

                Toggle(
                    L10n("Baixar atualizações automaticamente"),
                    isOn: Binding(
                        get: { updater.automaticallyDownloadsUpdates },
                        set: { updater.automaticallyDownloadsUpdates = $0 }
                    )
                )

                HStack {
                    Button(L10n("Verificar Agora")) {
                        updater.checkForUpdates()
                    }

                    Spacer()

                    if let lastCheck = updater.lastUpdateCheckDate {
                        Text(
                            L10n("Última verificação:") + " " +
                            lastCheck.formatted(
                                .dateTime
                                    .day().month(.abbreviated).year()
                                    .hour().minute()
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            } else {
                Text(L10n("Atualizações não disponíveis nesta versão."))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(L10n("Atualizações"))
        }
    }
}
