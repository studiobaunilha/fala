import SwiftUI
import Sparkle

extension SettingsView {
    @ViewBuilder
    var updatesView: some View {
        Form {
            // MARK: – Version Info
            Section {
                HStack(spacing: 16) {
                    if let appIcon = NSImage(named: NSImage.applicationIconName) {
                        Image(nsImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fala Pro")
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
                .padding(.vertical, 4)
            }

            // MARK: – Update Settings
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
        .formStyle(.grouped)
    }
}
