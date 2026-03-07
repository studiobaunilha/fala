import SwiftUI

extension SettingsView {
    var providerFooterText: Text {
        switch settings.llmProvider {
        case "apple":
            // swiftlint:disable:next line_length
            return Text(L10n("100% offline e gratuito. Roda no Neural Engine do dispositivo. Ideal para tarefas simples como limpar e formatar transcrições."))
        case "mlx":
            // swiftlint:disable:next line_length
            return Text(L10n("100% offline. Roda localmente no Apple Silicon via MLX. Suporta prompts complexos — basta baixar o modelo desejado na seção abaixo."))
        case "gemini":
            // swiftlint:disable:next line_length
            return Text(L10n("On-line — requer chave API gratuita do Google. Cota generosa sem custo. Suporta todos os modos e prompts complexos com alta qualidade."))
        case "openai":
            // swiftlint:disable:next line_length
            return Text(L10n("On-line — requer chave API paga da OpenAI. Alternativa premium com modelos como GPT-5. Suporta todos os modos e prompts complexos."))
        default:
            return Text(L10n("Este é o provedor padrão global. Modos individuais podem sobrescrever esta escolha."))
        }
    }

    var appleIntelligenceSection: some View {
        Section(L10n("Apple Intelligence")) {
            appleAvailabilityRow

            Label {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Modelo compacto (~3B parâmetros)"))
                        .font(.body)
                    // swiftlint:disable:next line_length
                    Text(L10n("Ideal para tarefas simples como limpar e formatar texto. Para prompts criativos ou complexos (Dev, Sumário), considere Gemini, OpenAI ou MLX."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle")
                    .foregroundStyle(FalaColors.info)
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var appleAvailabilityRow: some View {
        Group {
            #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                AppleIntelligenceStatusView()
            } else {
                unavailableRow(L10n("Requer macOS Tahoe (26) ou superior."))
            }
            #else
            unavailableRow(L10n("Requer macOS Tahoe (26) ou superior. Compile com o SDK do macOS 26."))
            #endif
        }
    }

    private func unavailableRow(_ message: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n("Indisponível"))
                    .font(.body)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(FalaColors.warning)
        }
        .padding(.vertical, Spacing.xs)
    }

    var mlxConfigSection: some View {
        Section(L10n("MLX Local")) {
            LabeledContent(L10n("Modelo Padrão")) {
                HStack(spacing: Spacing.xs) {
                    TextField("", text: $settings.mlxModel)
                        .textFieldStyle(.roundedBorder)

                    Menu {
                        ForEach(settings.mlxCatalogService.curatedModels) { model in
                            Button(model.label) {
                                settings.mlxModel = model.repoID
                            }
                        }
                        if !settings.mlxCatalogService.suggestedCustomModels.isEmpty {
                            Divider()
                            ForEach(settings.mlxCatalogService.suggestedCustomModels) { model in
                                Button(model.label) {
                                    settings.mlxCatalogService.useSuggestedCustom(model)
                                    settings.mlxModel = model.repoID
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .frame(width: LayoutMetric.compactPickerIconWidth)
                    .help(L10n("Selecionar modelo conhecido"))
                }
            }

            LabeledContent(L10n("Repo ID customizado")) {
                TextField(
                    L10n("Repo ID customizado"),
                    text: Binding(
                        get: { settings.mlxCatalogService.customRepoID },
                        set: { settings.mlxCatalogService.customRepoID = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(L10n("Usar repo customizado")) {
                    if let repoID = settings.mlxCatalogService.normalizedCustomRepoID() {
                        settings.mlxModel = repoID
                    }
                }
                .disabled(settings.mlxCatalogService.normalizedCustomRepoID() == nil)

                Spacer()

                Menu(L10n("Sugestões")) {
                    ForEach(settings.mlxCatalogService.suggestedCustomModels) { entry in
                        Button(entry.label) {
                            settings.mlxCatalogService.useSuggestedCustom(entry)
                        }
                    }
                }
            }

            Text(L10n("Os modelos MLX rodam localmente no Apple Silicon. Baixe pelo menos um modelo abaixo."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var mlxModelsSection: some View {
        Section {
            ForEach(settings.mlxCatalogService.curatedModels) { entry in
                MLXModelRow(
                    model: MLXModelInfo(
                        id: entry.id,
                        repoID: entry.repoID,
                        label: entry.label,
                        estimatedSize: entry.estimatedSize ?? L10n("Tamanho variável")
                    ),
                    manager: settings.mlxModelManager,
                    isSelected: settings.mlxModel == entry.repoID
                )
            }

            if let customRepoID = settings.mlxCatalogService.normalizedCustomRepoID() {
                customMLXModelRow(repoID: customRepoID)
            }
        } header: {
            Text(L10n("Modelos MLX Locais"))
        } footer: {
            // swiftlint:disable:next line_length
            Text(L10n("Modelos LLM para processamento local via MLX. Rodam inteiramente no dispositivo usando Apple Silicon."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func customMLXModelRow(repoID: String) -> some View {
        let isDownloaded = settings.mlxCatalogService.isDownloaded(repoID: repoID)
        let progress = settings.mlxModelManager.downloads[repoID]

        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(repoID)
                        .font(.body.monospaced())
                    RoleBadge(title: L10n("Custom"), color: FalaColors.badgeCustom)
                }

                if let size = settings.mlxCatalogService.diskSize(repoID: repoID) {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let progress {
                ProgressView(value: progress)
                    .frame(width: LayoutMetric.compactProgressWidth)
            } else if isDownloaded {
                Button(role: .destructive) {
                    try? settings.mlxModelManager.delete(repoID: repoID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    settings.mlxModelManager.download(repoID: repoID)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
