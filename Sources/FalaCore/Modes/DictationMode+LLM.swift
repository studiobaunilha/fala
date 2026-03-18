import AppKit

extension DictationMode {

    /// Detects a quick tap (\<400ms) with a pending selection and opens
    /// the typed‐command panel instead of transcribing.
    /// Returns `true` when the quick-tap was handled.
    func handleQuickTapIfNeeded() -> Bool {
        let elapsed = -(keyDownTime?.timeIntervalSinceNow ?? -1)
        keyDownTime = nil
        guard elapsed < 0.4,
              let selection = pendingSelectionContext else {
            return false
        }
        pendingSelectionContext = nil
        _ = try? recorder.stopRecording()
        feedback?.dismiss()
        statusBar?.setState(.idle)
        let config = configProvider()
        selectionCommandController?.show(
            selection: selection,
            near: NSEvent.mouseLocation
        ) { [weak self] command, sel in
            guard let self else { return }
            Task { @MainActor in
                await self.executeTypedCommand(
                    command, selection: sel, config: config
                )
            }
        }
        return true
    }
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

    /// Formats the LLM input for Selection + AI Command mode.
    ///
    /// Unlike `wrapWithSelectionContext` (used for conversational ask-AI),
    /// this frames the dictated text as an **instruction** to apply to
    /// the selected content.
    static func wrapForSelectionCommand(
        _ command: String, selection: String
    ) -> String {
        return """
        Selected text:
        ---
        \(selection)
        ---

        User instruction:
        \(command)
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

    /// Processes a voice command applied to selected text via the LLM.
    /// Falls back to the raw transcription when the LLM call fails.
    func processSelectionCommand(
        _ command: String,
        selection: String,
        config: AppConfig,
        profiler: any DictationProfiling
    ) async -> String {
        let userText = Self.wrapForSelectionCommand(
            command, selection: selection
        )
        let aiConfig = config.getEffectiveConfig(for: .askAI)
        let prompt = PromptDefaults.selectionCommandPrompt(
            for: aiConfig.provider
        )
        inserter.saveToClipboard(command)
        do {
            let result = try await profiler.measure(.llmProcessing) {
                try await llmResponse(
                    text: userText, prompt: prompt,
                    config: config, effective: aiConfig
                )
            }
            return stripLLMPreamble(result)
        } catch let error as LLMError {
            let msg = error.localizedDescription
            print("[Fala] \(msg) — selection command requer LLM.")
            statusBar?.showTemporaryWarning(msg)
            return command
        } catch {
            print(
                "[Fala] Selection command LLM error: "
                + "\(error.localizedDescription)"
            )
            return command
        }
    }

    /// Entry point for the typed command panel flow.
    /// Called when the user types a command and presses Enter.
    func executeTypedCommand(
        _ command: String,
        selection: String,
        config: AppConfig
    ) async {
        feedback?.model.reset()
        feedback?.model.stage = .processing
        feedback?.show()
        statusBar?.setState(.recording)

        let profiler = DictationProfiler.makeIfEnabled()
        let result = await processSelectionCommand(
            command, selection: selection,
            config: config, profiler: profiler
        )

        if config.selectionPasteDirectly {
            feedback?.model.stage = .inserting
            await inserter.insert(result)
            feedback?.model.stage = .done
            feedback?.dismiss()
            statusBar?.setState(.idle)

            // Feature D: Start monitoring for manual corrections
            TextCorrectionObserver.shared.onCorrectionDetected = { oldText, newText in
                CorrectionLearningController.shared.promptForCorrection(
                    original: oldText,
                    corrected: newText
                ) {
                    var config = AppConfig()
                    config.addNewReplacementRule(from: oldText, to: newText)
                }
            }
            TextCorrectionObserver.shared.startMonitoring(insertedText: result)
        } else {
            showRefinementPanel(for: result, timeout: nil)
        }
    }

    /// Shows the result panel with refinement field.
    /// After paste (or when `selectionPasteDirectly` is off), the user
    /// gets ~5s to type a follow-up refinement command, or indefinitely if timeout is nil.
    func showRefinementPanel(for text: String, timeout: Double?) {
        feedback?.dismiss()
        statusBar?.setState(.idle)
        selectionCommandController?.showResult(
            text: text,
            near: NSEvent.mouseLocation,
            timeout: timeout,
            onRefine: nil, // Feature disabled for now
            onPaste: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.inserter.insert(text)

                    // Feature D: Start monitoring for manual corrections after manual paste
                    TextCorrectionObserver.shared.onCorrectionDetected = { oldText, newText in
                        CorrectionLearningController.shared.promptForCorrection(
                            original: oldText,
                            corrected: newText
                        ) {
                            var config = AppConfig()
                            config.addNewReplacementRule(from: oldText, to: newText)
                        }
                    }
                    TextCorrectionObserver.shared.startMonitoring(insertedText: text)
                }
            }
        )
    }

    /// Re-processes a refinement command using the previous result
    /// as context. Chains indefinitely (each result shows a new
    /// refinement panel).
    private func processRefinement(
        _ command: String, previousResult: String
    ) async {
        feedback?.model.reset()
        feedback?.model.stage = .processing
        feedback?.show()
        statusBar?.setState(.recording)

        let config = configProvider()
        let profiler = DictationProfiler.makeIfEnabled()
        let result = await processSelectionCommand(
            command, selection: previousResult,
            config: config, profiler: profiler
        )

        if config.selectionPasteDirectly {
            feedback?.model.stage = .inserting
            await inserter.insert(result)
            feedback?.model.stage = .done
            feedback?.dismiss()
            statusBar?.setState(.idle)
            showRefinementPanel(for: result, timeout: 5.0)

            // Feature D: Start monitoring for manual corrections
            Task { @MainActor in
                TextCorrectionObserver.shared.onCorrectionDetected = { oldText, newText in
                    Task { @MainActor in
                        CorrectionLearningController.shared.promptForCorrection(
                            original: oldText,
                            corrected: newText
                        ) {
                            var config = AppConfig()
                            config.addNewReplacementRule(from: oldText, to: newText)
                        }
                    }
                }
                TextCorrectionObserver.shared.startMonitoring(insertedText: result)
            }
        } else {
            showRefinementPanel(for: result, timeout: nil)
        }
    }

    func llmResponse(
        text: String,
        prompt: String,
        config: AppConfig,
        effective: AppConfig.EffectiveConfig,
        previousMessages: [[String: String]] = [],
        conversational: Bool = false
    ) async throws -> String {
        if let processor = self.llmProcessor {
            return try await processor(text, prompt, config, effective)
        }
        return try await dispatchLLM(
            text: text, prompt: prompt,
            config: config, effective: effective,
            previousMessages: previousMessages,
            conversational: conversational
        )
    }

    private func dispatchLLM(
        text: String, prompt: String, config: AppConfig,
        effective: AppConfig.EffectiveConfig,
        previousMessages: [[String: String]] = [],
        conversational: Bool = false
    ) async throws -> String {
        let model = effective.model
        switch effective.provider {
        case "gemini":
            guard !config.geminiKey.isEmpty else { throw LLMError.noAPIKey(provider: "Gemini") }
            return try await TranscriptionJob.processWithGemini(
                text: text, prompt: prompt, apiKey: config.geminiKey,
                model: model, previousMessages: previousMessages)
        case "openai":
            guard !config.openAIKey.isEmpty else { throw LLMError.noAPIKey(provider: "OpenAI") }
            return try await TranscriptionJob.processWithOpenAI(
                text: text, prompt: prompt, apiKey: config.openAIKey,
                model: model, previousMessages: previousMessages)
        case "apple":
            return try await TranscriptionJob.processWithAppleNative(text: text, prompt: prompt)
        case "mlx":
            let modelID = model.isEmpty ? config.mlxModel : model
            return try await TranscriptionJob.processWithMLX(
                text: text, prompt: prompt, modelID: modelID, conversational: conversational)
        default:
            throw LLMError.providerNotConfigured(effective.provider)
        }
    }
}
