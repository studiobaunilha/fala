import Foundation

extension AppConfig {
    // MARK: – Helper Methods for Mode Config
    
    public struct EffectiveConfig: Sendable {
        public let provider: String
        public let model: String
        public let prompt: String
    }
    
    public func getEffectiveConfig(for template: DictationTemplate) -> EffectiveConfig {
        let modeConfig = modeConfigs[template.rawValue]

        let provider = modeConfig?.provider ?? llmProvider

        let model = resolvedLLMModel(for: provider, preferredModel: modeConfig?.model)

        // Prompt resolution hierarchy:
        // 1. Per-provider override from providerPrompts
        // 2. General prompt from mode config
        // 3. For .custom: customModePrompt field
        // 4. PromptDefaults optimized for provider + template
        // 5. template.defaultSystemPrompt (legacy fallback)
        // 6. Empty string (prevents LLM on raw/translate)
        let prompt: String
        if let providerPrompt = modeConfig?.providerPrompts?[provider], !providerPrompt.isEmpty {
            prompt = providerPrompt
        } else if let modePrompt = modeConfig?.prompt {
            prompt = modePrompt
        } else if template == .custom {
            prompt = customModePrompt
        } else if let defaultPrompt = PromptDefaults.resolved(for: provider, template: template, model: model) {
            prompt = defaultPrompt
        } else {
            prompt = template.defaultSystemPrompt ?? ""
        }

        return EffectiveConfig(provider: provider, model: model, prompt: prompt)
    }

}
