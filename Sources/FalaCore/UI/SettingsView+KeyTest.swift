import SwiftUI

// MARK: - API Key Testing

extension SettingsView {

    func testKey(provider: String, key: String) async {
        isTestingKey = true
        defer { isTestingKey = false }

        do {
            if provider == "gemini" {
                try await testGeminiKey(key)
            } else {
                try await testOpenAIKey(key)
            }
        } catch {
            testKeyResult = L10n("Falha no teste: ") + error.localizedDescription
        }

        showTestKeyAlert = true
    }

    private func testGeminiKey(_ key: String) async throws {
        let baseUrl = "https://generativelanguage.googleapis.com/"
            + "v1beta/models/gemini-1.5-flash:generateContent"
        guard let url = URL(string: "\(baseUrl)?key=\(key)") else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json",
                      forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": "Hi"]]]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode == 200 {
            testKeyResult = L10n("Sucesso! A chave do Gemini está funcionando.")
            return
        }

        if http.statusCode == 404 {
            try await checkGeminiModelsList(key)
            return
        }

        let errBody = String(data: data, encoding: .utf8)
            ?? L10n("Erro desconhecido")
        let msg = L10n("Erro ") + "\(http.statusCode): \(errBody)"
        throw NSError(
            domain: "API", code: http.statusCode,
            userInfo: [NSLocalizedDescriptionKey: msg]
        )
    }

    private func checkGeminiModelsList(_ key: String) async throws {
        let listUrlString = "https://generativelanguage.googleapis.com/"
            + "v1beta/models?key=\(key)"
        guard let listUrl = URL(string: listUrlString) else {
            throw URLError(.badURL)
        }

        let (listData, listResp) = try await URLSession.shared
            .data(from: listUrl)
        guard let listHttp = listResp as? HTTPURLResponse,
              listHttp.statusCode == 200 else {
            throw NSError(domain: "API", code: 404, userInfo: [
                NSLocalizedDescriptionKey:
                    L10n("Modelo não encontrado e falha ao listar modelos.")
            ])
        }

        if let json = try JSONSerialization
            .jsonObject(with: listData) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            let names = models.compactMap {
                ($0["name"] as? String)?
                    .components(separatedBy: "/").last
            }
            self.availableGeminiModels = names
            testKeyResult = L10n("Chave válida. Lista de modelos atualizada.")
        } else {
            testKeyResult = L10n("Chave válida, mas erro ao listar modelos.")
        }
    }

    private func testOpenAIKey(_ key: String) async throws {
        guard let url = URL(
            string: "https://api.openai.com/v1/chat/completions"
        ) else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(key)",
                      forHTTPHeaderField: "Authorization")
        req.addValue("application/json",
                      forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": 5
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8)
                ?? L10n("Erro desconhecido")
            let msg = L10n("Erro ") + "\(http.statusCode): \(errBody)"
            throw NSError(
                domain: "API", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }

        testKeyResult = L10n("Sucesso! A chave da OpenAI está funcionando.")
    }
}

// MARK: - Apple Intelligence Status (macOS 26+)

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
struct AppleIntelligenceStatusView: View {
    @State private var availability: SystemLanguageModel
        .Availability = .available

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(statusText)
                    .font(.body)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, Spacing.xs)
        .task {
            availability = SystemLanguageModel.default.availability
        }
    }

    private var statusText: String {
        switch availability {
        case .available:
            return L10n("Disponível")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return L10n("Dispositivo não suportado")
            case .appleIntelligenceNotEnabled:
                return L10n("Apple Intelligence desativado")
            case .modelNotReady:
                return L10n("Modelo sendo baixado")
            @unknown default:
                return L10n("Indisponível")
            }
        @unknown default:
            return L10n("Status desconhecido")
        }
    }

    private var statusDetail: String {
        switch availability {
        case .available:
            return L10n("Pronto para uso. Nenhuma configuração necessária.")
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return L10n("Este Mac não suporta Apple Intelligence.")
            case .appleIntelligenceNotEnabled:
                return L10n("Ative em Ajustes do Sistema → Apple Intelligence e Siri.")
            case .modelNotReady:
                return L10n("O modelo está sendo preparado. Tente novamente em alguns minutos.")
            @unknown default:
                return L10n("Verifique os Ajustes do Sistema.")
            }
        @unknown default:
            return ""
        }
    }

    private var statusIcon: String {
        switch availability {
        case .available: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle"
        @unknown default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch availability {
        case .available: return .green
        case .unavailable: return .orange
        @unknown default: return .secondary
        }
    }
}
#endif

// MARK: - MLX Model Row

struct MLXModelRow: View {
    let model: MLXModelInfo
    @ObservedObject var manager: MLXModelManager
    let isSelected: Bool

    private var isDownloaded: Bool { manager.isDownloaded(model.id) }
    private var progress: Double? { manager.downloads[model.id] }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(model.label)
                        .font(.body)
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.caption)
                    }
                }
                HStack(spacing: Spacing.md) {
                    Text(sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isSelected && isDownloaded {
                        Text(L10n("Ativo"))
                            .font(.caption2)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            if let progress {
                ProgressView(value: progress)
                    .frame(width: 80)
                    .controlSize(.small)
                Text("\(Int(progress * 100))%")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            } else if isDownloaded {
                Button(role: .destructive) {
                    try? manager.delete(model.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help(L10n("Apagar modelo"))
            } else {
                Button {
                    manager.download(model.id)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(L10n("Baixar modelo"))
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var sizeLabel: String {
        manager.diskSize(for: model.id) ?? model.estimatedSize
    }
}
