import Foundation

struct LLMApplicationOutcome: Sendable {
    let text: String
    let warning: BatchProcessingWarning?
}

struct BatchProcessingResult: Sendable {
    let fullConfirmedText: String
    let warning: BatchProcessingWarning?
}

private struct PreparedLLMRequest {
    let provider: String
    let model: String
    let prompt: String
}

extension TranscriptionJob {
    static func applyLLM(
        to text: String,
        config: AppConfig,
        template: DictationTemplate,
        promptOverride: String? = nil
    ) async -> String {
        let outcome = await applyLLMWithOutcome(
            to: text,
            config: config,
            template: template,
            promptOverride: promptOverride
        )
        return outcome.text
    }

    static func applyLLMWithOutcome(
        to text: String,
        config: AppConfig,
        template: DictationTemplate,
        promptOverride: String? = nil
    ) async -> LLMApplicationOutcome {
        guard let request = preparedLLMRequest(
            config: config,
            template: template,
            promptOverride: promptOverride
        ) else {
            return LLMApplicationOutcome(text: text, warning: nil)
        }

        do {
            guard let result = try await runLLMIfConfigured(
                request: request,
                text: text,
                config: config
            ) else {
                return LLMApplicationOutcome(text: text, warning: nil)
            }

            return LLMApplicationOutcome(
                text: stripLLMPreamble(result),
                warning: nil
            )
        } catch {
            print("[Fala] LLM Error: \(error)")
            return LLMApplicationOutcome(
                text: text,
                warning: processingWarning(for: request.provider, error: error)
            )
        }
    }
}

private extension TranscriptionJob {
    static func preparedLLMRequest(
        config: AppConfig,
        template: DictationTemplate,
        promptOverride: String?
    ) -> PreparedLLMRequest? {
        guard template.requiresLLM else {
            return nil
        }

        let effective = config.getEffectiveConfig(for: template)
        let rawPrompt = promptOverride ?? effective.prompt
        guard !rawPrompt.isEmpty else {
            return nil
        }

        var enriched = rawPrompt
        if config.enableDiarization, effective.provider != "apple" {
            // swiftlint:disable:next line_length
            enriched += "\n\n" + L10n("IMPORTANTE: O áudio possui múltiplos locutores. Identifique as trocas de falantes pelo contexto e formate o texto indicando quem está falando (Ex: Locutor 1: ..., Locutor 2: ...).")
        }

        return PreparedLLMRequest(
            provider: effective.provider,
            model: effective.model,
            prompt: promptForTemplate(
                template,
                enriched: enriched,
                config: config,
                provider: effective.provider
            )
        )
    }

    static func runLLMIfConfigured(
        request: PreparedLLMRequest,
        text: String,
        config: AppConfig
    ) async throws -> String? {
        switch request.provider {
        case "gemini" where !config.geminiKey.isEmpty:
            return try await processWithGemini(
                text: text,
                prompt: request.prompt,
                apiKey: config.geminiKey,
                model: request.model
            )
        case "openai" where !config.openAIKey.isEmpty:
            return try await processWithOpenAI(
                text: text,
                prompt: request.prompt,
                apiKey: config.openAIKey,
                model: request.model
            )
        case "apple":
            return try await processWithAppleNative(text: text, prompt: request.prompt)
        case "mlx":
            let modelID = request.model.isEmpty
                ? AppConfig.defaultMLXModelRepoID
                : request.model
            return try await processWithMLX(
                text: text,
                prompt: request.prompt,
                modelID: modelID
            )
        default:
            return nil
        }
    }

    static func processingWarning(
        for provider: String,
        error: Error
    ) -> BatchProcessingWarning {
        let providerName = localizedProviderLabel(for: provider)
        let format = L10n(
            "A transcrição foi concluída, mas o processamento com %@ falhou. "
                + "O texto final foi salvo sem essa etapa. Detalhe: %@"
        )
        return BatchProcessingWarning(
            title: L10n("Pós-processamento com IA não foi aplicado"),
            message: String(
                format: format,
                providerName,
                error.localizedDescription
            )
        )
    }

    static func localizedProviderLabel(for provider: String) -> String {
        switch provider {
        case "apple":
            return L10n("Apple Intelligence")
        case "mlx":
            return L10n("MLX Local")
        case "gemini":
            return L10n("Google Gemini")
        case "openai":
            return L10n("OpenAI")
        default:
            return provider
        }
    }

    static func promptForTemplate(
        _ template: DictationTemplate,
        enriched: String,
        config: AppConfig,
        provider: String
    ) -> String {
        if template.isConversational {
            if provider == "apple" {
                let preferredLanguage = config.transcriptionLanguage == "auto"
                    ? AppLocalization.resolveLanguageCode(config.appLanguage)
                    : config.transcriptionLanguage
                let langName = AppSettings.transcriptionLanguageDisplayName(for: preferredLanguage)
                return enriched + "\nIMPORTANTE: Responda SEMPRE em \(langName)."
            }
            return enriched
        }

        if provider == "apple" {
            return wrapPromptForAppleIntelligence(enriched)
        }

        return wrapPromptForCleanOutput(
            enriched,
            globalPrompt: config.globalSystemPrompt
        )
    }
}
