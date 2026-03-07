import KeyboardShortcuts
import Foundation

/// Orchestrates the push-to-talk flow:
/// keyDown → start recording → keyUp → transcribe → insert text.
///
/// All dependencies are injected via protocols so that DictationMode can be
/// unit-tested without real audio hardware, ML models, or Accessibility access.
@MainActor
// swiftlint:disable:next type_body_length
public final class DictationMode {
    typealias ConfigProvider = () -> AppConfig
    typealias TranscriberResolver = (AppConfig) -> any AudioTranscribing
    typealias LLMProcessor = (
        _ text: String,
        _ prompt: String,
        _ config: AppConfig,
        _ effective: AppConfig.EffectiveConfig
    ) async throws -> String

    private let recorder: any AudioRecording
    private let inserter: any TextInserting
    private weak var statusBar: StatusBarController?
    private let feedback: DictationFeedbackController?
    private let configProvider: ConfigProvider
    private let transcriberResolver: TranscriberResolver
    private let llmProcessor: LLMProcessor?

    private var isRecording = false

    /// Production initialiser — uses real concrete implementations.
    public convenience init(transcriber: Transcriber, statusBar: StatusBarController) {
        self.init(
            recorder: AudioEngine(),
            transcriber: transcriber,
            inserter: TextInserter(),
            statusBar: statusBar
        )
    }

    /// Designated initialiser — accepts protocol abstractions for testability.
    init(
        recorder: any AudioRecording,
        transcriber: any AudioTranscribing,
        inserter: any TextInserting,
        statusBar: StatusBarController? = nil,
        feedback: DictationFeedbackController? = nil,
        config: AppConfig? = nil,
        configProvider: ConfigProvider? = nil,
        transcriberResolver: TranscriberResolver? = nil,
        llmProcessor: LLMProcessor? = nil
    ) {
        self.recorder = recorder
        self.inserter = inserter
        self.statusBar = statusBar
        self.feedback = feedback
        self.configProvider = configProvider ?? { [config] in
            config ?? AppConfig.load()
        }
        self.transcriberResolver = transcriberResolver ?? { _ in transcriber }
        self.llmProcessor = llmProcessor
    }

    /// Binds global keyboard shortcut handlers. Call once at app startup.
    public func setup() {
        KeyboardShortcuts.onKeyDown(for: .startDictation) { [weak self] in
            guard let self, !self.isRecording else { return }
            Task { @MainActor in await self.startRecording() }
        }

        KeyboardShortcuts.onKeyUp(for: .startDictation) { [weak self] in
            guard let self, self.isRecording else { return }
            Task { @MainActor in await self.stopAndTranscribe() }
        }
    }

    // MARK: – Internal (accessible from tests via @testable import)

    func startRecording() async {
        guard !isRecording else { return }
        guard LicenseManager.shared.isActivated else {
            let blockedMessage: String
            if LicenseManager.shared.accessState == .needsConnection {
                blockedMessage = L10n("Conexão necessária: Conecte este Mac para validar a licença nos Ajustes.")
            } else {
                blockedMessage = L10n("Fala Pro Necessário: Ative o Fala Pro nos Ajustes.")
            }
            statusBar?.showTemporaryWarning(blockedMessage)
            return
        }
        do {
            // Wire RMS levels to the floating feedback panel
            if let feedback {
                feedback.model.reset()
                feedback.model.template = configProvider().selectedDictationTemplate
                recorder.setRMSHandler { [weak feedback] rms in
                    feedback?.model.ingestRMS(rms)
                }
            }
            try recorder.startRecording()
            isRecording = true
            statusBar?.setState(.recording)
            feedback?.model.stage = .recording
            feedback?.show()
        } catch {
            print("[Fala] Recording start failed: \(error.localizedDescription)")
        }
    }

    // swiftlint:disable:next function_body_length
    func stopAndTranscribe() async {
        isRecording = false
        recorder.setRMSHandler(nil)
        statusBar?.setState(.transcribing)
        feedback?.model.stage = .transcribing

        do {
            let audioURL = try recorder.stopRecording()
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let samples = try AudioConverter.toFloat16k(from: audioURL)
            guard !samples.isEmpty else {
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            // Skip silent audio — avoids unnecessary transcription and LLM calls
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
            guard rms > 0.001 else {
                NSLog("[Fala] Audio too quiet (RMS: %.6f), skipping", rms)
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            let config = configProvider()
            let activeTranscriber = transcriberResolver(config)
            let template = config.selectedDictationTemplate
            let effectiveConfig = config.getEffectiveConfig(for: template)

            NSLog(
                "[Fala] Dictation request template=%@ engine=%@ llmProvider=%@",
                template.rawValue,
                config.transcriptionEngine,
                effectiveConfig.provider
            )

            if template == .translate && !activeTranscriber.supportsTranslation {
                statusBar?.showTemporaryWarning(
                    L10n("Tradução requer o motor Whisper. Troque em Ajustes → Geral.")
                )
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            let task = template == .translate ? "translate" : "transcribe"
            let text = try await activeTranscriber.transcribe(samples: samples, task: task)

            // Filter short noise hallucinations (e.g. "the", "okay", "um")
            let words = text.split(separator: " ")
            guard !text.isEmpty, words.count > 1 || text.count > 5 else {
                if !text.isEmpty {
                    NSLog("[Fala] Transcription too short, likely noise: '%@'", text)
                }
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            feedback?.model.stage = .processing
            
            if template.requiresLLM {
                inserter.saveToClipboard(text)
            }
            let finalText = await processText(text, config: config, template: template)

            feedback?.model.stage = .inserting
            inserter.insert(finalText)

            feedback?.model.stage = .done
            feedback?.dismiss()
        } catch {
            print("[Fala] Transcription error: \(error.localizedDescription)")
            feedback?.dismiss()
        }

        statusBar?.setState(.idle)
    }

    private func processText(
        _ text: String,
        config: AppConfig,
        template: DictationTemplate
    ) async -> String {
        var finalText = ReplacementRule.applyAll(text, rules: config.replacementRules)

        let modeConfig = config.getEffectiveConfig(for: template)
        let basePrompt = modeConfig.prompt

        if template.requiresLLM, !basePrompt.isEmpty {
            var enriched = basePrompt
            // Conversational modes (askAI) skip anti-response wrapping —
            // the whole point is for the AI to respond to the question.
            let prompt: String
            if template.isConversational {
                // Apple Intelligence's compact model needs explicit language guidance
                if modeConfig.provider == "apple" {
                    let preferredLanguage = config.transcriptionLanguage == "auto"
                        ? AppLocalization.resolveLanguageCode(config.appLanguage)
                        : config.transcriptionLanguage
                    let langName = AppSettings.transcriptionLanguageDisplayName(for: preferredLanguage)
                    enriched += "\nIMPORTANTE: Responda SEMPRE em \(langName)."
                }
                prompt = enriched
            } else if modeConfig.provider == "apple" {
                // Apple Intelligence (~3B, 4096 tokens) can't handle the
                // full globalSystemPrompt — use a short, focused suffix.
                prompt = wrapPromptForAppleIntelligence(enriched)
            } else {
                prompt = wrapPromptForCleanOutput(enriched, globalPrompt: config.globalSystemPrompt)
            }
            do {
                let result = try await llmResponse(
                    text: text,
                    prompt: prompt,
                    config: config,
                    effective: modeConfig
                )
                finalText = stripLLMPreamble(result)
            } catch let error as LLMError {
                let msg = error.localizedDescription
                print("[Fala] \(msg) — modo '\(template.localizedName)' requer LLM.")
                statusBar?.showTemporaryWarning(msg)
            } catch {
                print("[Fala] LLM processing error: \(error.localizedDescription)")
            }
        }

        return finalText
    }

    private func llmResponse(
        text: String,
        prompt: String,
        config: AppConfig,
        effective: AppConfig.EffectiveConfig
    ) async throws -> String {
        if let llmProcessor {
            return try await llmProcessor(text, prompt, config, effective)
        }
        return try await dispatchLLM(
            text: text,
            prompt: prompt,
            config: config,
            effective: effective
        )
    }

    private func dispatchLLM(
        text: String, prompt: String, config: AppConfig,
        effective: AppConfig.EffectiveConfig
    ) async throws -> String {
        let model = effective.model
        switch effective.provider {
        case "gemini":
            guard !config.geminiKey.isEmpty else { throw LLMError.noAPIKey(provider: "Gemini") }
            return try await TranscriptionJob.processWithGemini(
                text: text, prompt: prompt, apiKey: config.geminiKey, model: model
            )
        case "openai":
            guard !config.openAIKey.isEmpty else { throw LLMError.noAPIKey(provider: "OpenAI") }
            return try await TranscriptionJob.processWithOpenAI(
                text: text, prompt: prompt, apiKey: config.openAIKey, model: model
            )
        case "apple":
            return try await TranscriptionJob.processWithAppleNative(text: text, prompt: prompt)
        case "mlx":
            let modelID = model.isEmpty ? config.mlxModel : model
            return try await TranscriptionJob.processWithMLX(
                text: text, prompt: prompt, modelID: modelID
            )
        default:
            throw LLMError.providerNotConfigured(effective.provider)
        }
    }
}
