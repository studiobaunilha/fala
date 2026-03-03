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

            // Skip silent audio — avoids unnecessary transcription and LLM calls
            let rms = sqrt(samples.map { $0 * $0 }.reduce(0, +) / Float(samples.count))
            guard rms > 0.001 else {
                NSLog("[Sussurro] Audio too quiet (RMS: %.6f), skipping", rms)
                statusBar?.setState(.idle)
                return
            }

            let config = AppConfig.load()
            let template = config.selectedDictationTemplate

            let task = template == .translate ? "translate" : "transcribe"
            let text = try await transcriber.transcribe(samples: samples, task: task)

            // Filter short noise hallucinations (e.g. "the", "okay", "um")
            let words = text.split(separator: " ")
            guard !text.isEmpty, words.count > 1 || text.count > 5 else {
                if !text.isEmpty {
                    NSLog("[Sussurro] Transcription too short, likely noise: '%@'", text)
                }
                statusBar?.setState(.idle)
                return
            }

            let finalText = await processText(text, config: config, template: template)
            inserter.insert(finalText)
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
        var finalText = ReplacementRule.applyAll(text, rules: config.replacementRules)

        let modeConfig = config.getEffectiveConfig(for: template)
        let basePrompt = modeConfig.prompt

        if template.requiresLLM, !basePrompt.isEmpty {
            var enriched = basePrompt
            if template == .promptDev, !config.devStack.isEmpty {
                enriched += "\n\nStack do projeto: \(config.devStack)"
            }
            let prompt = wrapPromptForCleanOutput(enriched)
            do {
                let result = try await dispatchLLM(
                    text: text, prompt: prompt, config: config,
                    effective: modeConfig
                )
                finalText = stripLLMPreamble(result)
            } catch let error as LLMError {
                let msg = error.localizedDescription
                print("[Sussurro] ⚠️ \(msg) — modo '\(template.rawValue)' requer LLM.")
                statusBar?.showTemporaryWarning(msg)
            } catch {
                print("[Sussurro] LLM processing error: \(error.localizedDescription)")
            }
        }

        return finalText
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
