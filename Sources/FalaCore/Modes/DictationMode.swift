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
    typealias TranscriberPrewarmer = @Sendable (_ config: AppConfig) async -> Void
    typealias LLMProcessor = (
        _ text: String,
        _ prompt: String,
        _ config: AppConfig,
        _ effective: AppConfig.EffectiveConfig
    ) async throws -> String

    let recorder: any AudioRecording
    let inserter: any TextInserting
    weak var statusBar: StatusBarController?
    let feedback: DictationFeedbackController?
    let configProvider: ConfigProvider
    private let transcriberResolver: TranscriberResolver
    private let transcriberPrewarmer: TranscriberPrewarmer?
    let llmProcessor: LLMProcessor?
    private let readiness: RuntimeReadinessEvaluator?
    private let selectionCapture: SelectionCapture?
    let selectionCommandController: SelectionCommandController?
    public let conversationMemory = ConversationMemory()

    var isRecording = false
    var pendingSelectionContext: String?
    var keyDownTime: Date?

    /// Test-only: inject a simulated selection context.
    func setPendingSelectionForTesting(_ text: String?) {
        pendingSelectionContext = text
    }

    /// Production initialiser — uses real concrete implementations.
    public convenience init(transcriber: Transcriber, statusBar: StatusBarController) {
        self.init(
            recorder: AudioEngine(),
            transcriber: transcriber,
            inserter: TextInserter(),
            statusBar: statusBar,
            selectionCapture: SelectionCapture()
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
        transcriberPrewarmer: TranscriberPrewarmer? = nil,
        llmProcessor: LLMProcessor? = nil,
        readiness: RuntimeReadinessEvaluator? = nil,
        selectionCapture: SelectionCapture? = nil,
        selectionCommandController: SelectionCommandController? = nil
    ) {
        self.recorder = recorder
        self.inserter = inserter
        self.statusBar = statusBar
        self.feedback = feedback
        self.configProvider = configProvider ?? { [config] in
            config ?? AppConfig.load()
        }
        self.transcriberResolver = transcriberResolver ?? { _ in transcriber }
        self.transcriberPrewarmer = transcriberPrewarmer
        self.llmProcessor = llmProcessor
        self.readiness = readiness
        self.selectionCapture = selectionCapture
        self.selectionCommandController = selectionCommandController
    }

    final class WeakBox: @unchecked Sendable {
        weak var value: DictationMode?
        init(_ value: DictationMode?) {
            self.value = value
        }
    }

    nonisolated private static func makeKeyDownAction(box: WeakBox) -> () -> Void {
        return {
            Task { @MainActor in
                guard let mode = box.value, !mode.isRecording else { return }
                await mode.startRecording()
            }
        }
    }

    nonisolated private static func makeKeyUpAction(box: WeakBox) -> () -> Void {
        return {
            Task { @MainActor in
                guard let mode = box.value, mode.isRecording else { return }
                await mode.stopAndTranscribe()
            }
        }
    }

    /// Binds global keyboard shortcut handlers. Call once at app startup.
    public func setup() {
        let box = WeakBox(self)
        KeyboardShortcuts.onKeyDown(for: .startDictation, action: Self.makeKeyDownAction(box: box))
        KeyboardShortcuts.onKeyUp(for: .startDictation, action: Self.makeKeyUpAction(box: box))
    }

    // MARK: – Internal (accessible from tests via @testable import)

    func startRecording() async {
        guard !isRecording else { return }
        if let issue = readiness?.primaryIssueForDictation() {
            statusBar?.showTemporaryWarning(issue.message)
            return
        } else if readiness == nil, !LicenseManager.shared.isActivated {
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
            let config = configProvider()
            keyDownTime = Date()

            // Set immediately — before any await — so keyUp can always
            // reach stopAndTranscribe() even for very short taps.
            isRecording = true

            // Capture selected text before recording for AI modes.
            // Must happen before startRecording() so the simulated Cmd+C
            // doesn't interfere with audio capture.
            if let capture = selectionCapture {
                pendingSelectionContext = await capture.captureSelection()
            }

            // If stopAndTranscribe() already ran during the await above
            // (quick tap), skip the rest — the panel is already showing.
            guard isRecording else { return }

            // Wire RMS levels to the floating feedback panel
            if let feedback {
                feedback.model.reset()
                feedback.model.template = config.selectedDictationTemplate
                feedback.model.conversationTurnCount = conversationMemory.turnCount
                recorder.setRMSHandler { [weak feedback] rms in
                    feedback?.model.ingestRMS(rms)
                }
            }
            try recorder.startRecording()
            if let transcriberPrewarmer {
                let prewarmConfig = config
                let prewarmer = transcriberPrewarmer
                Task.detached {
                    await prewarmer(prewarmConfig)
                }
            }
            statusBar?.setState(.recording)
            feedback?.model.stage = pendingSelectionContext != nil
                ? .selectionCommand : .recording
            feedback?.show()
        } catch {
            isRecording = false
            print("[Fala] Recording start failed: \(error.localizedDescription)")
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func stopAndTranscribe() async {
        isRecording = false
        recorder.setRMSHandler(nil)

        if handleQuickTapIfNeeded() { return }

        statusBar?.setState(.transcribing)
        feedback?.model.stage = .transcribing

        let profiler = DictationProfiler.makeIfEnabled()
        var ctx = DictationProfilingContext()

        do {
            let audioURL = try profiler.measure(.stopRecording) {
                try recorder.stopRecording()
            }
            defer { try? FileManager.default.removeItem(at: audioURL) }

            let samples = try await profiler.measure(.audioConversion) {
                try await Task.detached {
                    try AudioConverter.toFloat16k(from: audioURL)
                }.value
            }
            ctx.audioSampleCount = samples.count
            guard !samples.isEmpty else {
                ctx.outcome = .silentAudio
                profiler.finish(ctx)
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            // Skip silent audio — avoids unnecessary transcription and LLM calls
            let rms: Float = profiler.measure(.rmsValidation) {
                var sum: Float = 0
                for sample in samples { sum += sample * sample }
                return sqrt(sum / Float(samples.count))
            }
            ctx.audioRMS = rms
            guard rms > 0.001 else {
                NSLog("[Fala] Audio too quiet (RMS: %.6f), skipping", rms)
                ctx.outcome = .silentAudio
                profiler.finish(ctx)
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            let (config, activeTranscriber, template, effectiveConfig) =
                profiler.measure(.transcriberSetup) {
                    let cfg = configProvider()
                    let transcriber = transcriberResolver(cfg)
                    let tmpl = cfg.selectedDictationTemplate
                    let eff = cfg.getEffectiveConfig(for: tmpl)
                    return (cfg, transcriber, tmpl, eff)
                }
            ctx.template = template.rawValue
            ctx.engine = config.transcriptionEngine
            ctx.llmProvider = effectiveConfig.provider

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
                ctx.outcome = .translationUnsupported
                profiler.finish(ctx)
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            let task = template == .translate ? "translate" : "transcribe"
            let text = try await profiler.measure(.transcription) {
                try await activeTranscriber.transcribe(samples: samples, task: task)
            }
            ctx.transcribedText = text

            // Filter short noise hallucinations (e.g. "the", "okay", "um")
            let words = text.split(separator: " ")
            guard !text.isEmpty, words.count > 1 || text.count > 5 else {
                if !text.isEmpty {
                    NSLog("[Fala] Transcription too short, likely noise: '%@'", text)
                }
                ctx.outcome = .tooShort
                profiler.finish(ctx)
                statusBar?.setState(.idle)
                feedback?.dismiss()
                return
            }

            feedback?.model.stage = .processing

            let selectionContext = pendingSelectionContext
            pendingSelectionContext = nil

            // Selection + AI Command: when the user has selected text and
            // the current template does NOT normally use an LLM (.raw,
            // .translate), treat the dictated text as an instruction to
            // apply to the selected content via the LLM.
            let isSelectionCommand = selectionContext != nil
                && !template.requiresLLM

            let finalText: String
            if isSelectionCommand, let selection = selectionContext {
                finalText = await processSelectionCommand(
                    text, selection: selection, config: config,
                    profiler: profiler
                )
            } else {
                if template.requiresLLM {
                    inserter.saveToClipboard(text)
                }
                finalText = await profiledProcessText(
                    text, config: config, template: template,
                    selectionContext: selectionContext, profiler: profiler
                )
            }

            if isSelectionCommand && !config.selectionPasteDirectly {
                feedback?.model.stage = .done
                feedback?.dismiss()
                showRefinementPanel(for: finalText, timeout: nil)
            } else {
                feedback?.model.stage = .inserting
                await profiler.measure(.textInsertion) {
                    await inserter.insert(finalText)
                }
                feedback?.model.stage = .done
                feedback?.dismiss()
                showRefinementPanel(for: finalText, timeout: 5.0)
            }

            profiler.finish(ctx)
        } catch {
            print("[Fala] Transcription error: \(error.localizedDescription)")
            ctx.outcome = .failed
            profiler.finish(ctx)
            feedback?.dismiss()
        }

        statusBar?.setState(.idle)
    }

    private func profiledProcessText(
        _ text: String,
        config: AppConfig,
        template: DictationTemplate,
        selectionContext: String? = nil,
        profiler: any DictationProfiling
    ) async -> String {
        var finalText = profiler.measure(.replacementRules) {
            ReplacementRule.applyAll(text, rules: config.replacementRules)
        }

        let modeConfig = config.getEffectiveConfig(for: template)
        let basePrompt = modeConfig.prompt

        if template.requiresLLM, !basePrompt.isEmpty {
            let prompt = buildLLMPrompt(
                basePrompt: basePrompt, template: template,
                modeConfig: modeConfig, config: config
            )
            // Include conversation history for providers that support it.
            // Apple Intelligence is excluded — its ~3B model handles
            // multi-turn poorly; each call is a standalone exchange.
            let useMemory = template.isConversational
                && PromptDefaults.supportsConversationMemory(modeConfig.provider)
            let history = useMemory
                ? conversationMemory.messagesForAPI()
                : []
            // Wrap user text with selection context when available.
            let userText = Self.wrapWithSelectionContext(
                text, selection: selectionContext
            )
            do {
                let result = try await profiler.measure(.llmProcessing) {
                    try await llmResponse(
                        text: userText, prompt: prompt,
                        config: config, effective: modeConfig,
                        previousMessages: history,
                        conversational: useMemory
                    )
                }
                finalText = stripLLMPreamble(result)
                if useMemory {
                    let ctxKey = "\(template.rawValue)::\(modeConfig.provider)"
                    conversationMemory.append(
                        userText: userText, assistantResponse: finalText,
                        contextKey: ctxKey
                    )
                    feedback?.model.conversationTurnCount = conversationMemory.turnCount
                }
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
}
