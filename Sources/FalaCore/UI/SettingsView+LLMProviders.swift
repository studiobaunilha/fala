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

}

struct MLXCatalogSectionsView: View {
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var modelManager: MLXModelManager
    @ObservedObject private var catalogService: MLXCatalogService

    init(settings: AppSettings) {
        self._settings = ObservedObject(wrappedValue: settings)
        self._modelManager = ObservedObject(wrappedValue: settings.mlxModelManager)
        self._catalogService = ObservedObject(wrappedValue: settings.mlxCatalogService)
    }

    var body: some View {
        mlxConfigSection
        mlxModelsSection
    }
}

private extension MLXCatalogSectionsView {
    var mlxConfigSection: some View {
        Section(L10n("MLX Local")) {
            if let summary = catalogService.selectionSummary(for: settings.mlxModel) {
                let selectedEntry = summary.entry
                MLXCatalogSelectionSummaryView(
                    summary: summary,
                    progress: mlxSelectionProgress(for: selectedEntry),
                    primaryActionTitle: mlxSummaryActionTitle(for: selectedEntry),
                    primaryAction: mlxSummaryAction(for: selectedEntry)
                )
            } else {
                NoticeCard(
                    title: L10n("Modelo MLX incompatível"),
                    message: L10n(
                        "A seleção atual não está mais disponível. Escolha um modelo curado abaixo para continuar."
                    ),
                    tone: .warning
                )
            }

            if let notice = settings.mlxCatalogMigrationNotice {
                NoticeCard(
                    title: notice.title,
                    message: notice.message,
                    tone: .info
                )
            }

            if let warning = catalogService.validationWarnings.first {
                NoticeCard(
                    title: L10n("Catálogo MLX em modo seguro"),
                    message: warning,
                    tone: .warning
                )
            }

            Text(
                L10n("Escolha um modelo curado abaixo. O Fala só expõe modelos validados para o runtime MLX atual.")
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var mlxModelsSection: some View {
        Group {
            ForEach(catalogService.sections(selectedRepoID: settings.mlxModel)) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        mlxCatalogRow(for: entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func mlxCatalogRow(for entry: MLXCatalogEntry) -> some View {
        let isDownloaded = catalogService.isDownloaded(repoID: entry.repoID)
        let isSelected = settings.mlxModel == entry.repoID
        let progress = modelManager.downloads[entry.id]
            ?? modelManager.downloads[entry.repoID]

        MLXCatalogModelRow(
            entry: entry,
            isDownloaded: isDownloaded,
            isSelected: isSelected,
            progress: progress,
            isIdealForCurrentMac: catalogService.isIdealForCurrentMac(entry),
            diskSize: catalogService.diskSize(repoID: entry.repoID),
            primaryActionTitle: mlxRowPrimaryActionTitle(
                isDownloaded: isDownloaded,
                isSelected: isSelected
            ),
            isPrimaryActionDisabled: isDownloaded && isSelected,
            primaryAction: {
                performMLXPrimaryAction(entry, isDownloaded: isDownloaded)
            },
            removeAction: isDownloaded ? { removeMLXModel(entry) } : nil
        )
    }

    func mlxSelectionProgress(for entry: MLXCatalogEntry) -> Double? {
        modelManager.downloads[entry.id] ?? modelManager.downloads[entry.repoID]
    }

    func mlxSummaryActionTitle(for entry: MLXCatalogEntry) -> String? {
        catalogService.isDownloaded(repoID: entry.repoID) ? nil : L10n("Baixar")
    }

    func mlxSummaryAction(for entry: MLXCatalogEntry) -> (() -> Void)? {
        guard !catalogService.isDownloaded(repoID: entry.repoID) else { return nil }
        return {
            modelManager.download(repoID: entry.repoID, shortID: entry.id)
        }
    }

    func mlxRowPrimaryActionTitle(
        isDownloaded: Bool,
        isSelected: Bool
    ) -> String {
        if isDownloaded && isSelected {
            return L10n("Ativo")
        }
        if isDownloaded {
            return L10n("Selecionar")
        }
        return L10n("Baixar")
    }

    func performMLXPrimaryAction(_ entry: MLXCatalogEntry, isDownloaded: Bool) {
        if isDownloaded {
            settings.mlxModel = entry.repoID
        } else {
            modelManager.download(repoID: entry.repoID, shortID: entry.id)
        }
    }

    func removeMLXModel(_ entry: MLXCatalogEntry) {
        if settings.mlxModel == entry.repoID,
           let fallbackRepoID = catalogService.fallbackSelection(excluding: entry.repoID) {
            settings.mlxModel = fallbackRepoID
        }

        for key in settings.modeConfigs.keys.sorted() {
            guard var modeConfig = settings.modeConfigs[key], modeConfig.model == entry.repoID else {
                continue
            }
            modeConfig.model = nil
            settings.modeConfigs[key] = modeConfig
        }

        settings.save()
        try? modelManager.delete(repoID: entry.repoID)
    }
}
