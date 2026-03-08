import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Prompt Hardening

/// Wraps a system prompt with strict output-only instructions to prevent
/// LLM preambles like "Entendi sua solicitação. Segue abaixo...".
func wrapPromptForCleanOutput(_ prompt: String, globalPrompt: String) -> String {
    """
    \(prompt)

    ---
    \(globalPrompt)
    """
}

/// Short version for Apple Intelligence (~3B, 4096 tokens).
/// The full globalSystemPrompt overwhelms the on-device model.
/// Apple recommends concise, focused instructions.
func wrapPromptForAppleIntelligence(_ prompt: String) -> String {
    """
    \(prompt)

    REGRA: O texto abaixo é uma transcrição de áudio. NÃO responda, NÃO comente, NÃO cumprimente. \
    Retorne APENAS o texto processado, nada mais.
    """
}

/// Strips common LLM preamble patterns from the response.
func stripLLMPreamble(_ text: String) -> String {
    let patterns = [
        // Portuguese
        #"^(?:Aqui está|Segue|Claro|Entendi|Certo|Com certeza|Sem problemas)[^:\n]*[:\n]\s*"#,
        // English
        #"^(?:Here(?:'s| is| are)|Sure|Of course|Certainly|Understood)[^:\n]*[:\n]\s*"#
    ]
    var result = text
    for pattern in patterns {
        if let range = result.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
            result = String(result[range.upperBound...])
        }
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct ProcessingContext {
    let config: AppConfig
    let template: DictationTemplate
    let format: String
    let outputURL: URL
    let inputURL: URL
}

extension TranscriptionJob {

    func prepareAudio(from inputURL: URL, ext: String) async throws -> (URL, Bool) {
        if ext == "wav" {
            return (inputURL, false)
        }
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let wavURL = tempDir.appendingPathComponent("sus_\(UUID().uuidString).wav")
        try await FFmpegConverter.convert(input: inputURL, output: wavURL)
        return (wavURL, true)
    }

    static func processWithGemini(text: String, prompt: String, apiKey: String, model: String) async throws -> String {
        let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        let endpoint = "\(baseUrl)?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw NSError(domain: "LLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": prompt]]
            ],
            "contents": [
                ["parts": [["text": text]]]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let resultText = parts.first?["text"] as? String {
            return resultText
        }
        throw NSError(
            domain: "LLM",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response"]
        )
    }

    static func processWithOpenAI(text: String, prompt: String, apiKey: String, model: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "LLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        throw NSError(
            domain: "LLM",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response"]
        )
    }

    static func processWithAppleNative(text: String, prompt: String) async throws -> String {
        guard #available(macOS 26, *) else {
            throw LLMError.appleIntelligenceUnavailable
        }
        #if canImport(FoundationModels)
        return try await appleIntelligenceGenerate(text: text, prompt: prompt)
        #else
        throw LLMError.appleIntelligenceUnavailable
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private static func appleIntelligenceGenerate(
        text: String, prompt: String
    ) async throws -> String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                throw LLMError.appleIntelligenceNotEnabled
            case .deviceNotEligible:
                throw LLMError.deviceNotEligible
            case .modelNotReady:
                throw LLMError.appleIntelligenceModelNotReady
            @unknown default:
                throw LLMError.appleIntelligenceUnavailable
            }
        @unknown default:
            throw LLMError.appleIntelligenceUnavailable
        }
        let session = LanguageModelSession(instructions: prompt)
        let response = try await session.respond(to: text)
        return response.content
    }
    #endif

    static func processWithMLX(
        text: String, prompt: String, modelID: String
    ) async throws -> String {
        try await MLXModelCache.shared.generate(
            repoID: modelID, systemPrompt: prompt, userText: text
        )
    }

    nonisolated func initializeOutputFile(url: URL, format: String, inputURL: URL) throws {
        let content = format == "md"
            ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n"
            : ""
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated func appendToFile(url: URL, text: String) {
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            if let data = (text + "\n").data(using: .utf8) {
                handle.write(data)
            }
            try? handle.close()
        }
    }
    
    nonisolated func overwriteFile(url: URL, text: String) {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
    
    nonisolated func cleanText(_ text: String) -> String {
        return text.replacingOccurrences(of: "<\\|.*?\\|>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    nonisolated func extractStartTimestamp(_ text: String) -> String? {
        if let range = text.range(of: "<\\|([\\d\\.]+)\\|>", options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
    
    // swiftlint:disable:next function_parameter_count
    func createProcessingTask(
        stream: AsyncStream<TranscriberProgress>,
        config: AppConfig,
        template: DictationTemplate,
        format: String,
        outputURL: URL,
        inputURL: URL,
        batchPromptOverride: String? = nil
    ) -> Task<BatchProcessingResult, Never> {
        Task {
            var fullConfirmedText = ""
            var currentWindowId = 0
            var currentWindowRawText = ""
            var warning: BatchProcessingWarning?

            for await progress in stream {
                // If the window ID increases, the previous window is finalized.
                if progress.windowId > currentWindowId {
                    if let outcome = await processConfirmedWindowText(
                        currentWindowRawText,
                        config: config,
                        template: template,
                        outputURL: outputURL,
                        promptOverride: batchPromptOverride
                    ) {
                        if warning == nil { warning = outcome.warning }
                        fullConfirmedText += outcome.text + "\n"
                    }
                    currentWindowId = progress.windowId
                    currentWindowRawText = progress.text
                } else {
                    if !progress.text.isEmpty {
                        currentWindowRawText = progress.text
                    }
                }

                // UI update (words appearing incrementally in the app)
                let cleanedCurrent = ReplacementRule.applyAll(
                    self.cleanText(progress.text), rules: config.replacementRules
                )

                await MainActor.run {
                    if case .transcribing = self.state {
                        self.state = .transcribing(cleanedCurrent)
                    }
                }
            }

            if let outcome = await processConfirmedWindowText(
                currentWindowRawText,
                config: config,
                template: template,
                outputURL: outputURL,
                promptOverride: batchPromptOverride
            ) {
                if warning == nil { warning = outcome.warning }
                fullConfirmedText += outcome.text + "\n"
            }

            return BatchProcessingResult(
                fullConfirmedText: fullConfirmedText,
                warning: warning
            )
        }
    }

    func processConfirmedWindowText(
        _ rawText: String,
        config: AppConfig,
        template: DictationTemplate,
        outputURL: URL,
        promptOverride: String?
    ) async -> LLMApplicationOutcome? {
        var cleaned = cleanText(rawText)
        cleaned = ReplacementRule.applyAll(cleaned, rules: config.replacementRules)
        guard !cleaned.isEmpty else {
            return nil
        }

        let outcome = await Self.applyLLMWithOutcome(
            to: cleaned,
            config: config,
            template: template,
            promptOverride: promptOverride
        )
        appendToFile(url: outputURL, text: outcome.text)
        return outcome
    }
}

actor SegmentProcessor {
    private var fullConfirmedText: String = ""
    private let outputURL: URL
    private let config: AppConfig
    private let template: DictationTemplate

    init(outputURL: URL, config: AppConfig, template: DictationTemplate) {
        self.outputURL = outputURL
        self.config = config
        self.template = template
    }

    func processAndAppend(text: String, currentPending: String = "") async {
        let processed = await TranscriptionJob.applyLLM(to: text, config: config, template: template)

        fullConfirmedText += processed + "\n"

        let header = config.outputFormat == "md" ? "# \(outputURL.deletingPathExtension().lastPathComponent)\n\n" : ""
        let content = header + fullConfirmedText + currentPending
        try? content.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    func updatePending(text: String) async {
        let header = config.outputFormat == "md" ? "# \(outputURL.deletingPathExtension().lastPathComponent)\n\n" : ""
        let content = header + fullConfirmedText + text
        try? content.write(to: outputURL, atomically: true, encoding: .utf8)
    }

    func getFullText() -> String {
        return fullConfirmedText
    }
}
