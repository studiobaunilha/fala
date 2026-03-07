import AppKit
import SwiftUI

extension SettingsView {
    @ViewBuilder
    var licenseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n("Licença"))
                    .font(.title2)
                    .fontWeight(.bold)

                statusBannerView
                activationFormView
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            scheduleActivationFieldFocusIfNeeded()
        }
        .onChange(of: licenseManager.isPro) { _, isPro in
            if isPro {
                activationCode = ""
            } else {
                scheduleActivationFieldFocusIfNeeded()
            }
        }
    }

    private var statusBannerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch licenseManager.accessState {
            case .proActive:
                bannerCard(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: L10n("Fala Pro ativo"),
                    subtitle: L10n("Este Mac está autorizado para usar os recursos Pro do Fala.")
                )
            case .proGracePeriod:
                bannerCard(
                    icon: "wifi.exclamationmark",
                    color: .orange,
                    title: L10n("Fala Pro em período de tolerância"),
                    // swiftlint:disable:next line_length
                    subtitle: L10n("O lease offline expirou, mas o app ainda está liberado temporariamente enquanto tenta renovar online.")
                )
            case .trialActive:
                bannerCard(
                    icon: "clock.badge.checkmark",
                    color: .orange,
                    title: L10n("Trial verificado ativo"),
                    subtitle: L10n("Seu trial está válido neste Mac e exige revalidação online periódica.")
                )
            case .needsConnection:
                bannerCard(
                    icon: "wifi.slash",
                    color: .orange,
                    title: L10n("Conexão necessária"),
                    subtitle: L10n("Conecte este Mac à internet para validar o trial ou renovar sua licença.")
                )
            case .expired:
                bannerCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: L10n("Acesso expirado"),
                    subtitle: L10n("O trial ou o lease offline expirou. Faça uma validação online ou ative o Fala Pro.")
                )
            case .unlicensed:
                bannerCard(
                    icon: "sparkles",
                    color: .blue,
                    title: L10n("Pronto para ativar"),
                    // swiftlint:disable:next line_length
                    subtitle: L10n("Você pode colar um código de ativação ou conectar este Mac para iniciar o trial verificado.")
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                if let email = licenseManager.licenseEmail {
                    detailRow(label: L10n("Ativado para"), value: email)
                }

                if licenseManager.isTrialActive {
                    detailRow(
                        label: L10n("Trial termina em"),
                        value: formattedDate(licenseManager.trialEndsAt)
                    )
                    detailRow(
                        label: L10n("Dias restantes"),
                        value: "\(licenseManager.trialDaysRemaining)"
                    )
                }

                if let nextCheck = licenseManager.nextOnlineValidationAt {
                    detailRow(label: L10n("Próxima validação online"), value: formattedDate(nextCheck))
                }

                if let gracePeriodEnd = licenseManager.gracePeriodEndsAt {
                    detailRow(label: L10n("Tolerância até"), value: formattedDate(gracePeriodEnd))
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await licenseManager.refreshEntitlement()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if licenseManager.isRefreshingEntitlement {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(L10n("Validar online agora"))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    licenseManager.isActivating ||
                    licenseManager.isDeactivating ||
                    licenseManager.isRefreshingEntitlement
                )

                if licenseManager.isPro {
                    Button {
                        Task {
                            await licenseManager.deactivate()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if licenseManager.isDeactivating {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(L10n("Remover ativação"))
                        }
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.red)
                    .disabled(licenseManager.isDeactivating || licenseManager.isRefreshingEntitlement)
                }
            }

            if let error = licenseManager.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var activationFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n("Cole o código de ativação recebido após a compra para liberar o Fala Pro neste Mac."))
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let activationAvailabilityMessage = licenseManager.activationAvailabilityMessage {
                Text(activationAvailabilityMessage)
                    .font(.callout)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n("Código de Ativação"))
                    .fontWeight(.medium)

                HStack(spacing: 10) {
                    TextField(L10n("Cole seu código de ativação"), text: $activationCode)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($focusedField, equals: SettingsFocusedField.activationCode)
                        .disabled(licenseManager.isActivating || licenseManager.isDeactivating)

                    Button(L10n("Colar")) {
                        pasteActivationCodeFromClipboard()
                    }
                    .buttonStyle(.bordered)
                    .disabled(licenseManager.isActivating || licenseManager.isDeactivating)
                }
            }

            Button {
                Task {
                    await licenseManager.activate(activationCode: activationCode)
                }
            } label: {
                HStack {
                    if licenseManager.isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(L10n("Ativar Fala Pro"))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                activationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                licenseManager.isActivating ||
                licenseManager.isDeactivating ||
                licenseManager.isRefreshingEntitlement ||
                !licenseManager.canActivate
            )

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text(L10n("Ainda não comprou o Fala Pro?"))
                    if let url = URL(string: "https://studio.baunilha.dev/fala") {
                        Link(L10n("Comprar Agora"), destination: url)
                    }
                }
                .font(.subheadline)

                Text(
                    // swiftlint:disable:next line_length
                    L10n("Se este Mac ainda não iniciou o trial verificado, o botão “Validar online agora” também tenta iniciar o período de avaliação automaticamente.")
                )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bannerCard(
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .cornerRadius(12)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .font(.body)
    }

    private func formattedDate(_ value: Date?) -> String {
        guard let value else {
            return "—"
        }

        return value.formatted(
            .dateTime
                .day(.twoDigits)
                .month(.twoDigits)
                .year()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }

    private func pasteActivationCodeFromClipboard() {
        guard let pasted = NSPasteboard.general.string(forType: .string)?.trimmedNonEmpty else {
            return
        }
        activationCode = pasted
        focusedField = SettingsFocusedField.activationCode
    }

    private func scheduleActivationFieldFocusIfNeeded() {
        guard !licenseManager.isPro else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            focusedField = SettingsFocusedField.activationCode
        }
    }
}
