import SwiftUI

extension SettingsView {
    private var licenseManager: LicenseManager { .shared }

    @ViewBuilder
    var licenseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Licença")
                    .font(.title2)
                    .fontWeight(.bold)

                statusBannerView
                activationFormView
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            licenseManager.validateLocalToken()
        }
    }

    private var statusBannerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch licenseManager.accessState {
            case .proActive:
                bannerCard(
                    icon: "checkmark.seal.fill",
                    color: .green,
                    title: "Fala Pro ativo",
                    subtitle: "Este Mac está autorizado para usar os recursos Pro do Fala."
                )
            case .proGracePeriod:
                bannerCard(
                    icon: "wifi.exclamationmark",
                    color: .orange,
                    title: "Fala Pro em período de tolerância",
                    subtitle: "O lease offline expirou, mas o app ainda está liberado " +
                        "temporariamente enquanto tenta renovar online."
                )
            case .trialActive:
                bannerCard(
                    icon: "clock.badge.checkmark",
                    color: .orange,
                    title: "Trial verificado ativo",
                    subtitle: "Seu trial está válido neste Mac e exige revalidação online periódica."
                )
            case .needsConnection:
                bannerCard(
                    icon: "wifi.slash",
                    color: .orange,
                    title: "Conexão necessária",
                    subtitle: "Conecte este Mac à internet para validar o trial ou renovar sua licença."
                )
            case .expired:
                bannerCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "Acesso expirado",
                    subtitle: "O trial ou o lease offline expirou. Faça uma validação online ou ative o Fala Pro."
                )
            case .unlicensed:
                bannerCard(
                    icon: "sparkles",
                    color: .blue,
                    title: "Pronto para ativar",
                    subtitle: """
                    Você pode colar um código de ativação ou conectar este Mac para iniciar o trial verificado.
                    """
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                if let email = licenseManager.licenseEmail {
                    detailRow(label: "Ativado para", value: email)
                }

                if licenseManager.isTrialActive {
                    detailRow(
                        label: "Trial termina em",
                        value: formattedDate(licenseManager.trialEndsAt)
                    )
                    detailRow(
                        label: "Dias restantes",
                        value: "\(licenseManager.trialDaysRemaining)"
                    )
                }

                if let nextCheck = licenseManager.nextOnlineValidationAt {
                    detailRow(label: "Próxima validação online", value: formattedDate(nextCheck))
                }

                if let gracePeriodEnd = licenseManager.gracePeriodEndsAt {
                    detailRow(label: "Tolerância até", value: formattedDate(gracePeriodEnd))
                }
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await licenseManager.refreshEntitlement()
                    }
                } label: {
                    Text("Validar online agora")
                }
                .buttonStyle(.bordered)
                .disabled(licenseManager.isActivating || licenseManager.isDeactivating)

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
                            Text("Remover ativação")
                        }
                    }
                    .buttonStyle(.link)
                    .foregroundColor(.red)
                    .disabled(licenseManager.isDeactivating)
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
            Text("Cole o código de ativação recebido após a compra para liberar o Fala Pro neste Mac.")
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
                Text("Código de Ativação")
                    .fontWeight(.medium)

                TextField("Cole seu código de ativação", text: $activationCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(licenseManager.isActivating || licenseManager.isDeactivating)
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
                    Text("Ativar Fala Pro")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                activationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                licenseManager.isActivating ||
                licenseManager.isDeactivating ||
                !licenseManager.canActivate
            )

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Ainda não comprou o Fala Pro?")
                    if let url = URL(string: "https://studio.baunilha.dev/fala") {
                        Link("Comprar Agora", destination: url)
                    }
                }
                .font(.subheadline)

                Text(
                    "Se este Mac ainda não iniciou o trial verificado, " +
                    "o botão “Validar online agora” também tenta iniciar o período de avaliação automaticamente."
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
}
