import SwiftUI

extension SettingsView {
    @ViewBuilder
    var licenseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Licença")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if LicenseManager.shared.isPro {
                    activatedStateView
                } else {
                    activationFormView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            LicenseManager.shared.validateLocalToken()
        }
    }
    
    private var activatedStateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fala Pro Ativado")
                        .font(.headline)
                    Text("Obrigado por apoiar o desenvolvimento independente!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            if let email = LicenseManager.shared.licenseEmail {
                HStack {
                    Text("Licenciado para:")
                        .fontWeight(.medium)
                    Text(email)
                        .foregroundColor(.secondary)
                }
                .font(.body)
            }
            
            Button("Desativar Licença") {
                LicenseManager.shared.deactivate()
            }
            .buttonStyle(.link)
            .foregroundColor(.red)
            .padding(.top, 8)
        }
    }
    
    private var activationFormView: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            if LicenseManager.shared.isTrialActive {
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Modo de Avaliação (Trial)")
                            .font(.headline)
                        Text(
                            "Você tem \(LicenseManager.shared.trialDaysRemaining) " +
                            "dias restantes para testar o Fala Pro."
                        )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Período de Teste Esgotado")
                            .font(.headline)
                        Text("Suas funções Pro estão bloqueadas. Adquira uma licença para continuar.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            
            Text(
                "Insira sua chave de licença do Lemon Squeezy ou Polar.sh " +
                "para liberar as funcionalidades Pro do Fala de forma permanente."
            )
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Chave de Licença")
                    .fontWeight(.medium)
                
                TextField("XXXX-XXXX-XXXX-XXXX", text: $newCorrect)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(LicenseManager.shared.isActivating)
            }
            
            if let error = LicenseManager.shared.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button {
                Task {
                    await LicenseManager.shared.activate(key: newCorrect)
                }
            } label: {
                HStack {
                    if LicenseManager.shared.isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text("Ativar Licença")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                newCorrect.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                LicenseManager.shared.isActivating
            )
            .padding(.top, 8)
            
            Divider()
                .padding(.vertical, 8)
            
            HStack {
                Text("Ainda não tem uma licença?")
                if let url = URL(string: "https://studio.baunilha.dev/fala") {
                    Link("Comprar Agora", destination: url)
                }
            }
            .font(.subheadline)
        }
    }
}
