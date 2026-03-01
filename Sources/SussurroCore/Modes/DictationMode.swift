import KeyboardShortcuts
import Foundation

/// Orchestrates the push-to-talk flow:
/// keyDown → start recording → keyUp → transcribe → insert text.
///
/// All dependencies are injected via protocols so that DictationMode can be
/// unit-tested without real audio hardware, ML models, or Accessibility access.
@MainActor
public final class DictationMode {
    private let recorder: any AudioRecording
    private let transcriber: any AudioTranscribing
    private let inserter: any TextInserting
    private weak var statusBar: StatusBarController?

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
    public init(
        recorder: any AudioRecording,
        transcriber: any AudioTranscribing,
        inserter: any TextInserting,
        statusBar: StatusBarController? = nil
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.inserter = inserter
        self.statusBar = statusBar
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
        do {
            try recorder.startRecording()
            isRecording = true
            statusBar?.setState(.recording)
        } catch {
            print("[Sussurro] Recording start failed: \(error.localizedDescription)")
        }
    }

    func stopAndTranscribe() async {
        isRecording = false
        statusBar?.setState(.transcribing)

        do {
            let audioURL = try recorder.stopRecording()
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let samples = try AudioConverter.toFloat16k(from: audioURL)
            guard !samples.isEmpty else {
                statusBar?.setState(.idle)
                return
            }

            let config = AppConfig.load()
            let template = config.selectedDictationTemplate
            
            let task = template == .translate ? "translate" : "transcribe"
            let text = try await transcriber.transcribe(samples: samples, task: task)
            
            if !text.isEmpty {
                let finalText = await processText(text, config: config, template: template)
                inserter.insert(finalText)
            }
        } catch {
            print("[Sussurro] Transcription error: \(error.localizedDescription)")
        }

        statusBar?.setState(.idle)
    }

    private func processText(
        _ text: String,
        config: AppConfig,
        template: DictationTemplate
    ) async -> String {
        var finalText = text
        
        // Apply replacement rules (multi-variant → single correct word)
        finalText = ReplacementRule.applyAll(finalText, rules: config.replacementRules)
        
        // Resolve effective configuration for this mode
        let modeConfig = config.getEffectiveConfig(for: template)
        let provider = modeConfig.provider
        let model = modeConfig.model
        let basePrompt = modeConfig.prompt
        
        // Apply LLM post-processing if this mode requires it and we have a prompt
        if template.requiresLLM, !basePrompt.isEmpty {
            let prompt = config.enableContextBuffer
                ? ContextManager.shared.buildPrompt(basePrompt: basePrompt)
                : basePrompt

            do {
                if provider == "gemini" {
                    guard !config.geminiKey.isEmpty else {
                        throw LLMError.noAPIKey(provider: "Gemini")
                    }
                    finalText = try await TranscriptionJob.processWithGemini(
                        text: text, prompt: prompt, apiKey: config.geminiKey, model: model
                    )
                } else if provider == "openai" {
                    guard !config.openAIKey.isEmpty else {
                        throw LLMError.noAPIKey(provider: "OpenAI")
                    }
                    finalText = try await TranscriptionJob.processWithOpenAI(
                        text: text, prompt: prompt, apiKey: config.openAIKey, model: model
                    )
                } else if provider == "apple" {
                    finalText = try await TranscriptionJob.processWithAppleNative(
                        text: text, prompt: prompt
                    )
                } else {
                    throw LLMError.providerNotConfigured(provider)
                }
            } catch let error as LLMError {
                print("[Sussurro] ⚠️ \(error.localizedDescription) — modo '\(template.rawValue)' requer LLM.")
                statusBar?.showTemporaryWarning(error.localizedDescription)
            } catch {
                print("[Sussurro] LLM processing error: \(error.localizedDescription)")
            }
        }
        
        // Update context buffer in background (using global config for memory updates as defined in ContextManager)
        if config.enableContextBuffer && template != .raw {
            Task {
                await ContextManager.shared.updateContext(newInput: finalText, config: config)
            }
        }
        
        return finalText
    }
}
