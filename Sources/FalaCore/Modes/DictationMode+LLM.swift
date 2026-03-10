import Foundation

extension DictationMode {

    static func wrapWithSelectionContext(
        _ text: String, selection: String?
    ) -> String {
        guard let selection, !selection.isEmpty else {
            return text
        }
        return """
        Context (text selected by the user):
        ---
        \(selection)
        ---

        User question:
        \(text)
        """
    }

    func buildLLMPrompt(
        basePrompt: String,
        template: DictationTemplate,
        modeConfig: AppConfig.EffectiveConfig,
        config: AppConfig
    ) -> String {
        if template.isConversational, modeConfig.provider == "apple" {
            let preferredLanguage = config.transcriptionLanguage == "auto"
                ? AppLocalization.resolveLanguageCode(config.appLanguage)
                : config.transcriptionLanguage
            let langName = AppSettings.transcriptionLanguageDisplayName(
                for: preferredLanguage
            )
            return basePrompt + "\nIMPORTANTE: Responda SEMPRE em \(langName)."
        }
        // PromptDefaults already provides self-contained prompts per provider,
        // so no wrapping or globalSystemPrompt concatenation is needed.
        return basePrompt
    }
}
