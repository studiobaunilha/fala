import Foundation

extension AppConfig {
    public func getEffectiveSelectionCommandConfig() -> EffectiveConfig {
        let provider = llmProvider
        let model = resolvedLLMModel(for: provider)
        let prompt = resolvedSelectionCommandPrompt(for: provider)
        return EffectiveConfig(provider: provider, model: model, prompt: prompt)
    }

    func resolvedLLMModel(
        for provider: String,
        preferredModel: String? = nil
    ) -> String {
        if let preferredModel, !preferredModel.isEmpty {
            return preferredModel
        }

        switch provider {
        case "gemini":
            return geminiModel
        case "openai":
            return openAIModel
        case "mlx":
            return mlxModel
        default:
            return ""
        }
    }
}

private extension AppConfig {
    func resolvedSelectionCommandPrompt(for provider: String) -> String {
        if let prompt = selectionCommandConfig.providerPrompts?[provider],
           !prompt.isEmpty {
            return prompt
        }

        if let prompt = selectionCommandConfig.prompt,
           !prompt.isEmpty {
            return prompt
        }

        return PromptDefaults.selectionCommandPrompt(for: provider)
    }
}
