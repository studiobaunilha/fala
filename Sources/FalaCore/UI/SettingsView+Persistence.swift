import SwiftUI

enum SettingsFocusedField: Hashable {
    case activationCode
}

extension AppSettings {
    /// Persists current values and updates the Transcriber without requiring a restart.
    public func save() {
        let previousLanguage = config.appLanguage
        if previousLanguage != appLanguage {
            relocalizeUntouchedDefaults(targetLanguage: appLanguage)
        }

        config = snapshotConfig()

        AppLocalization.apply(languageCode: appLanguage)
        config.save()

        Task { await transcriber.setModel(dictationModel) }
        Task {
            await transcriber.setConfig(
                language: transcriptionLanguage,
                temperature: dictationTemperature,
                prompt: ""
            )
        }
        warmupCoordinator.scheduleSelectedWarmup()
        readiness.refresh()
    }

    private func relocalizeUntouchedDefaults(targetLanguage: String) {
        let resolvedLanguage = AppLocalization.resolveLanguageCode(targetLanguage)

        if AppConfig.isKnownLocalizedDefault(llmPrompt, preset: .llmPrompt) {
            llmPrompt = AppConfig.localizedDefault(for: .llmPrompt, languageCode: resolvedLanguage)
        }

        if AppConfig.isKnownLocalizedDefault(customModeName, preset: .customModeName) {
            customModeName = AppConfig.localizedDefault(for: .customModeName, languageCode: resolvedLanguage)
        }

        if AppConfig.isKnownLocalizedDefault(customModePrompt, preset: .customModePrompt) {
            customModePrompt = AppConfig.localizedDefault(for: .customModePrompt, languageCode: resolvedLanguage)
        }

        if AppConfig.isKnownLocalizedDefault(globalSystemPrompt, preset: .globalSystemPrompt) {
            globalSystemPrompt = AppConfig.localizedDefault(
                for: .globalSystemPrompt,
                languageCode: resolvedLanguage
            )
        }

        for (key, modeConfig) in Array(modeConfigs) {
            guard let prompt = modeConfig.prompt,
                  let template = DictationTemplate(rawValue: key),
                  AppConfig.isKnownDefaultPrompt(prompt, for: template)
            else {
                continue
            }

            var updated = modeConfig
            updated.prompt = nil
            modeConfigs[key] = updated
        }
    }
}

extension View {
    func observeSettingsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.appLanguage) { settings.save() }
            .onChange(of: settings.dictationModel) { settings.save() }
            .onChange(of: settings.batchModel) { settings.save() }
            .onChange(of: settings.transcriptionLanguage) { settings.save() }
            .onChange(of: settings.dictationTemperature) { settings.save() }
            .onChange(of: settings.batchTemperature) { settings.save() }
            .onChange(of: settings.replacements) { settings.save() }
            .onChange(of: settings.replacementRules) { settings.save() }
            .observeMoreSettingsChanges(settings)
    }

    func observeMoreSettingsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.enableDiarization) { settings.save() }
            .onChange(of: settings.selectedDictationTemplate) { settings.save() }
            .onChange(of: settings.llmProvider) { settings.save() }
            .onChange(of: settings.llmPrompt) { settings.save() }
            .observeCredentialsChanges(settings)
    }

    func observeCredentialsChanges(_ settings: AppSettings) -> some View {
        self
            .onChange(of: settings.openAIKey) { settings.save() }
            .onChange(of: settings.geminiKey) { settings.save() }
            .onChange(of: settings.geminiModel) { settings.save() }
            .onChange(of: settings.openAIModel) { settings.save() }
            .onChange(of: settings.mlxModel) { settings.save() }
    }
}
