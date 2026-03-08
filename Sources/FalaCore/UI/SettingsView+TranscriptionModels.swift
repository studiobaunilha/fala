import SwiftUI

extension SettingsView {
    var modelsView: some View {
        Form {
            transcriptionEngineSection
            transcriptionLanguageSection

            if settings.transcriptionEngine == "whisper" {
                whisperTemperatureTuningSection
                whisperReadinessSection
                whisperSelectionSummarySection
                whisperCatalogSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Motor de Transcrição"))
    }
}

private extension SettingsView {
    var transcriptionEngineSection: some View {
        Section {
            Text(
                L10n(
                    // swiftlint:disable:next line_length
                    "Escolha o motor de transcrição. Você pode trocar depois, mas o app precisa reiniciar para aplicar a mudança."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            TranscriptionEngineOptionCard(
                title: L10n("Parakeet V3"),
                subtitle: L10n("Recomendado para a maioria"),
                summary: L10n(
                    // swiftlint:disable:next line_length
                    "Mais rápido no uso diário. Ideal para quem quer abrir, falar ou selecionar um arquivo e seguir em frente."
                ),
                badges: [
                    CatalogBadgeDescriptor(
                        title: L10n("Recomendado"),
                        color: FalaColors.badgeRecommended
                    ),
                    CatalogBadgeDescriptor(
                        title: L10n("Muito rápido"),
                        color: FalaColors.badgeNeutral
                    ),
                    CatalogBadgeDescriptor(
                        title: L10n("Menos espera"),
                        color: FalaColors.badgeNeutral
                    )
                ],
                isSelected: settings.transcriptionEngine == "parakeet",
                actionTitle: L10n("Usar Parakeet")
            ) {
                settings.requestTranscriptionEngineChange("parakeet")
            }

            TranscriptionEngineOptionCard(
                title: L10n("Whisper"),
                subtitle: L10n("Mais controle e mais modelos"),
                summary: L10n(
                    // swiftlint:disable:next line_length
                    "Escolha o tamanho do modelo e use recursos como tradução para inglês quando precisar de mais controle."
                ),
                badges: [
                    CatalogBadgeDescriptor(
                        title: L10n("Mais controle"),
                        color: FalaColors.badgeNeutral
                    ),
                    CatalogBadgeDescriptor(
                        title: L10n("Tradução"),
                        color: FalaColors.badgeNeutral
                    ),
                    CatalogBadgeDescriptor(
                        title: L10n("WhisperKit"),
                        color: FalaColors.badgeNeutral
                    )
                ],
                isSelected: settings.transcriptionEngine == "whisper",
                actionTitle: L10n("Usar Whisper")
            ) {
                settings.requestTranscriptionEngineChange("whisper")
            }
        } header: {
            Text(L10n("Motor de Transcrição"))
        } footer: {
            Text(activeTranscriptionEngineFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var transcriptionLanguageSection: some View {
        Section {
            if settings.supportsExplicitEngineLanguageSelection {
                Picker(L10n("Idioma do Áudio"), selection: $settings.transcriptionLanguage) {
                    ForEach(settings.availableLanguagesForEngine) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .pickerStyle(.menu)
            } else {
                LabeledContent(L10n("Idioma do Áudio")) {
                    Text(L10n("Detecção automática"))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(L10n("Idioma do Motor"))
        } footer: {
            Text(transcriptionLanguageFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var whisperReadinessSection: some View {
        if let issue = settings.readiness.issuesForBatch(batchPrompt: "").first(where: {
            $0.kind == .whisperModelMissing
        }) {
            Section {
                readinessIssueCard(issue)
            }
        }
    }

    var whisperTemperatureTuningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("\(L10n("Temperatura Ditado")) (\(settings.dictationTemperature, specifier: "%.1f"))")
                Slider(value: $settings.dictationTemperature, in: 0.0...1.0, step: 0.1)
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("\(L10n("Temperatura Batch")) (\(settings.batchTemperature, specifier: "%.1f"))")
                Slider(value: $settings.batchTemperature, in: 0.0...1.0, step: 0.1)
            }
        } header: {
            Text(L10n("Acurácia vs. Velocidade"))
        } footer: {
            Text(L10n("Zero significa alta acurácia (Greedy Decoding). Aplicável apenas ao motor Whisper."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    var whisperSelectionSummarySection: some View {
        Section {
            if let selectedModel = selectedWhisperModel {
                WhisperModelSelectionSummaryView(
                    model: selectedModel,
                    isDownloaded: modelManager.isDownloaded(selectedModel.id),
                    progress: modelManager.downloads[selectedModel.id],
                    primaryActionTitle: whisperSummaryActionTitle(for: selectedModel),
                    primaryAction: whisperSummaryAction(for: selectedModel)
                )
            } else {
                NoticeCard(
                    title: L10n("Modelo Whisper inválido"),
                    message: L10n(
                        "A seleção atual não está mais disponível. Escolha um modelo Whisper abaixo para continuar."
                    ),
                    tone: .warning
                )
            }
        } header: {
            Text(L10n("Modelo Whisper Ativo"))
        } footer: {
            Text(
                L10n("O Fala agora usa um único modelo Whisper ativo para ditado e transcrição de arquivos.")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var whisperCatalogSection: some View {
        Section {
            ForEach(knownModels) { model in
                WhisperCatalogModelRow(
                    model: model,
                    isDownloaded: modelManager.isDownloaded(model.id),
                    isSelected: settings.activeWhisperModel == model.id,
                    progress: modelManager.downloads[model.id],
                    diskSize: modelManager.diskSize(for: model.id),
                    primaryActionTitle: whisperRowPrimaryActionTitle(for: model),
                    isPrimaryActionDisabled: whisperRowPrimaryActionIsDisabled(for: model),
                    primaryAction: { performWhisperPrimaryAction(for: model) },
                    removeAction: whisperRemoveAction(for: model)
                )
            }
        } header: {
            Text(L10n("Modelos Whisper (Offline)"))
        } footer: {
            Text(
                L10n("Baixe um modelo, selecione-o e use o mesmo Whisper em toda a aplicação.")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    var activeTranscriptionEngineFooter: String {
        if settings.transcriptionEngine == "parakeet" {
            return L10n(
                "Parakeet está ativo. Ele é o caminho mais direto para uma experiência rápida no lançamento do app."
            )
        }

        return L10n(
            "Whisper está ativo. O mesmo modelo será usado tanto no ditado quanto na transcrição de arquivos."
        )
    }

    var transcriptionLanguageFooter: String {
        if settings.supportsExplicitEngineLanguageSelection {
            return L10n(
                // swiftlint:disable:next line_length
                "O Whisper pode detectar automaticamente o idioma do áudio ou usar um idioma fixo para melhorar a transcrição e a tradução."
            )
        }

        return L10n(
            // swiftlint:disable:next line_length
            "Na integração atual do Fala, o Parakeet opera em modo multilíngue com detecção automática. O SDK usado pelo app não expõe um parâmetro público de idioma para este motor."
        )
    }

    var selectedWhisperModel: ModelInfo? {
        knownModels.first(where: { $0.id == settings.activeWhisperModel })
    }

    func whisperSummaryActionTitle(for model: ModelInfo) -> String? {
        let isDownloaded = modelManager.isDownloaded(model.id)
        return isDownloaded ? nil : L10n("Baixar")
    }

    func whisperSummaryAction(for model: ModelInfo) -> (() -> Void)? {
        let isDownloaded = modelManager.isDownloaded(model.id)
        guard !isDownloaded else { return nil }
        return {
            modelManager.download(model.id)
        }
    }

    func whisperRowPrimaryActionTitle(for model: ModelInfo) -> String {
        let isDownloaded = modelManager.isDownloaded(model.id)
        let isSelected = settings.activeWhisperModel == model.id

        if isDownloaded && isSelected {
            return L10n("Ativo")
        }
        if isDownloaded {
            return L10n("Selecionar")
        }
        return L10n("Baixar")
    }

    func whisperRowPrimaryActionIsDisabled(for model: ModelInfo) -> Bool {
        modelManager.isDownloaded(model.id) && settings.activeWhisperModel == model.id
    }

    func performWhisperPrimaryAction(for model: ModelInfo) {
        let isDownloaded = modelManager.isDownloaded(model.id)

        if isDownloaded {
            settings.activeWhisperModel = model.id
            return
        }

        modelManager.download(model.id)
    }

    func whisperRemoveAction(for model: ModelInfo) -> (() -> Void)? {
        guard modelManager.isDownloaded(model.id) else { return nil }
        return {
            removeWhisperModel(model)
        }
    }

    func removeWhisperModel(_ model: ModelInfo) {
        if settings.activeWhisperModel == model.id,
           let fallbackModel = knownModels
            .filter({ $0.id != model.id && modelManager.isDownloaded($0.id) })
            .max(by: { $0.selectionPriority < $1.selectionPriority }) {
            settings.activeWhisperModel = fallbackModel.id
        }

        try? modelManager.delete(model.id)
    }
}
