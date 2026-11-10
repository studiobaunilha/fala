import Foundation

extension DictationMode {
    func presentInsertionReviewIfNeeded(for insertedText: String) {
        insertionReviewPresenter?.present(
            insertedText: insertedText,
            using: inserter
        )
    }

    func profiledProcessText(
        _ text: String,
        config: AppConfig,
        template: DictationTemplate,
        selectionContext: String? = nil,
        profiler: any DictationProfiling
    ) async -> String {
        var finalText = text
        let modeConfig = config.getEffectiveConfig(for: template)
        let basePrompt = modeConfig.prompt

        if template.requiresLLM, !basePrompt.isEmpty {
            let prompt = buildLLMPrompt(
                basePrompt: basePrompt,
                template: template,
                modeConfig: modeConfig,
                config: config
            )
            let useMemory = template.isConversational && PromptDefaults.supportsConversationMemory(modeConfig.provider)
            let history = useMemory ? conversationMemory.messagesForAPI() : []
            let userText = Self.wrapWithSelectionContext(text, selection: selectionContext)
            do {
                let result = try await profiler.measure(.llmProcessing) {
                    try await llmResponse(
                        text: userText,
                        prompt: prompt,
                        config: config,
                        effective: modeConfig,
                        previousMessages: history,
                        conversational: useMemory
                    )
                }
                finalText = stripLLMPreamble(result)
                if useMemory {
                    let ctxKey = "\(template.conversationContextKeyPrefix)::\(modeConfig.provider)"
                    conversationMemory.append(
                        userText: userText,
                        assistantResponse: finalText,
                        contextKey: ctxKey
                    )
                    feedback?.model.conversationTurnCount = conversationMemory.turnCount
                }
            } catch let error as LLMError {
                let msg = error.localizedDescription
                print("[Fala] \(msg) — modo '\(template.diagnosticName)' requer LLM.")
                statusBar?.showTemporaryWarning(msg)
            } catch {
                print("[Fala] LLM processing error: \(error.localizedDescription)")
            }
        }
        // Apply once after AI cleanup so it cannot discard corrections or trigger a second replacement cascade.
        return profiler.measure(.replacementRules) {
            ReplacementRule.applyAll(finalText, rules: config.replacementRules)
        }
    }
}
