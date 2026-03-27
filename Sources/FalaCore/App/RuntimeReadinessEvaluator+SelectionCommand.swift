import Foundation

extension RuntimeReadinessEvaluator {
    public func issuesForSelectionCommand() -> [ReadinessIssue] {
        let config = settings.snapshotConfig()
        let effective = config.getEffectiveSelectionCommandConfig()

        switch effective.provider {
        case "apple":
            return selectionCommandAppleIssues()
        case "mlx":
            return selectionCommandMLXIssues(config: config, effective: effective)
        case "gemini":
            return selectionCommandSettingsIssues(
                kind: .cloudAPIKeyMissing,
                title: L10n("Chave Gemini necessária"),
                message: L10n("Configure uma chave da API Gemini para usar Seleção + IA."),
                apiKey: config.geminiKey
            )
        case "openai":
            return selectionCommandSettingsIssues(
                kind: .cloudAPIKeyMissing,
                title: L10n("Chave OpenAI necessária"),
                message: L10n("Configure uma chave da API OpenAI para usar Seleção + IA."),
                apiKey: config.openAIKey
            )
        default:
            return []
        }
    }
}

private extension RuntimeReadinessEvaluator {
    func selectionCommandAppleIssues() -> [ReadinessIssue] {
        guard !settings.isAppleProviderUsable else {
            return []
        }

        return [
            selectionCommandSettingsIssue(
                kind: .appleIntelligenceUnavailable,
                title: L10n("Apple Intelligence indisponível"),
                message: L10n("Troque para MLX, Gemini ou OpenAI para usar Seleção + IA neste Mac.")
            )
        ]
    }

    func selectionCommandMLXIssues(
        config: AppConfig,
        effective: AppConfig.EffectiveConfig
    ) -> [ReadinessIssue] {
        let modelID = effective.model.isEmpty ? config.mlxModel : effective.model
        let resolution = mlxCatalogService.resolveSelection(repoID: modelID)

        guard resolution.status != .unsupported else {
            return [
                selectionCommandSettingsIssue(
                    kind: .mlxModelMissing,
                    title: L10n("Modelo MLX incompatível"),
                    message: L10n("Selecione um modelo MLX válido do catálogo antes de usar Seleção + IA.")
                )
            ]
        }

        guard let resolvedEntry = resolution.entry,
              mlxCatalogService.isDownloaded(repoID: resolvedEntry.repoID) else {
            return [
                selectionCommandSettingsIssue(
                    kind: .mlxModelMissing,
                    title: L10n("Modelo MLX necessário"),
                    message: L10n("Baixe ou selecione um modelo MLX local compatível antes de usar Seleção + IA.")
                )
            ]
        }

        return []
    }

    func selectionCommandSettingsIssues(
        kind: ReadinessIssueKind,
        title: String,
        message: String,
        apiKey: String
    ) -> [ReadinessIssue] {
        guard apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        return [
            selectionCommandSettingsIssue(
                kind: kind,
                title: title,
                message: message
            )
        ]
    }

    func selectionCommandSettingsIssue(
        kind: ReadinessIssueKind,
        title: String,
        message: String
    ) -> ReadinessIssue {
        ReadinessIssue(
            kind: kind,
            title: title,
            message: message,
            action: .openSettings(.panel(.llm)),
            actionTitle: L10n("Abrir Ajustes"),
            blocking: true
        )
    }
}
