import Foundation

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
        throw LLMError.appleIntelligenceUnavailable
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
    
    static func applyLLM(to text: String, config: AppConfig, template: DictationTemplate) async -> String {
        guard template.requiresLLM else { return text }
        let effective = config.getEffectiveConfig(for: template)
        let prompt = effective.prompt
        guard !prompt.isEmpty else { return text }
        let provider = effective.provider
        let model = effective.model

        do {
            if provider == "gemini", !config.geminiKey.isEmpty {
                return try await processWithGemini(
                    text: text, prompt: prompt, apiKey: config.geminiKey, model: model
                )
            } else if provider == "openai", !config.openAIKey.isEmpty {
                return try await processWithOpenAI(
                    text: text, prompt: prompt, apiKey: config.openAIKey, model: model
                )
            } else if provider == "apple" {
                return try await processWithAppleNative(text: text, prompt: prompt)
            }
        } catch {
            print("[Sussurro] LLM Error: \(error)")
        }
        return text
    }

    // swiftlint:disable:next function_parameter_count
    func createProcessingTask(
        stream: AsyncStream<TranscriberProgress>,
        config: AppConfig,
        template: DictationTemplate,
        format: String,
        outputURL: URL,
        inputURL: URL
    ) -> Task<String, Never> {
        Task {
            var fullConfirmedText = ""
            var currentWindowId = 0
            var currentWindowRawText = ""

            for await progress in stream {
                // If the window ID increases, the previous window is finalized.
                if progress.windowId > currentWindowId {
                    var cleanedLast = self.cleanText(currentWindowRawText)
                    cleanedLast = ReplacementRule.applyAll(cleanedLast, rules: config.replacementRules)

                    if !cleanedLast.isEmpty {
                        let processed = await Self.applyLLM(to: cleanedLast, config: config, template: template)
                        fullConfirmedText += processed + "\n"
                        self.appendToFile(url: outputURL, text: processed)
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

            // Stream ended. Process the very last window.
            var cleanedLast = self.cleanText(currentWindowRawText)
            cleanedLast = ReplacementRule.applyAll(cleanedLast, rules: config.replacementRules)

            if !cleanedLast.isEmpty {
                let processed = await Self.applyLLM(to: cleanedLast, config: config, template: template)
                fullConfirmedText += processed + "\n"
                self.appendToFile(url: outputURL, text: processed)
            }

            return fullConfirmedText
        }
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
