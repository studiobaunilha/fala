import SwiftUI
import AppKit

// MARK: – State

public enum TranscriptionState: Equatable {
    case idle
    case converting
    case transcribing(String)
    case processingLLM
    case done(String)  // output file path
    case error(String)
}

// MARK: – View Model

@MainActor
public final class TranscriptionJob: ObservableObject {
    @Published public var inputURL: URL?
    @Published public var state: TranscriptionState = .idle
    @Published public var outputFormat: String
    @Published public var outputDirectory: URL?
    
    // Per-job overrides
    @Published public var overrideModel: String?
    @Published public var overrideLanguage: String?
    @Published public var enableDiarization: Bool
    
    private var currentTask: Task<Void, Never>?

    public init() {
        let config = AppConfig.load()
        self.outputFormat = config.outputFormat
        if !config.defaultExportPath.isEmpty {
            self.outputDirectory = URL(fileURLWithPath: config.defaultExportPath)
        }
        self.enableDiarization = config.enableDiarization
    }

    public func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = BatchMode.supportedExtensions.compactMap {
            .init(filenameExtension: $0)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        inputURL = url
        state = .idle
    }
    
    public func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    public func transcribe() {
        guard let inputURL else { return }
        let ext = inputURL.pathExtension.lowercased()
        let config = AppConfig.load()
        let format = outputFormat
        
        // Resolve effective parameters
        let effectiveModel = overrideModel ?? config.batchModel
        let effectiveLanguage = overrideLanguage ?? config.language
        // Assuming diarization needs an extra setup which you'll pass down in a future refactor to the transcriber
        // let effectiveDiarization = enableDiarization

        withAnimation(AnimationConfig.standard) {
            state = ext == "wav" ? .transcribing("") : .converting
        }

        currentTask = Task {
            do {
                try Task.checkCancellation()
                let (wavURL, needsCleanup) = try await prepareAudio(from: inputURL, ext: ext)
                defer {
                    if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
                }

                try Task.checkCancellation()
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .transcribing("") }
                }

                let transcriber = Transcriber(
                    modelName: effectiveModel,
                    language: effectiveLanguage,
                    temperature: config.batchTemperature,
                    prompt: config.customDictionary.joined(separator: ", ")
                )
                
                let text = try await transcriber.transcribe(audioPath: wavURL.path) { partialText in
                    Task { @MainActor in
                        if case .transcribing = self.state {
                            self.state = .transcribing(partialText)
                        }
                    }
                }
                
                try Task.checkCancellation()
                try await processOutput(text: text, inputURL: inputURL, config: config, format: format)
            } catch is CancellationError {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .error("Cancelado pelo usuário") }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .error(error.localizedDescription) }
                }
            }
        }
    }
    
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func processOutput(text: String, inputURL: URL, config: AppConfig, format: String) async throws {
        var finalText = text
        
        if config.enableLLMPostProcessing {
            try Task.checkCancellation()
            if config.llmProvider == "gemini", !config.geminiKey.isEmpty {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .processingLLM }
                }
                finalText = try await processWithGemini(
                    text: finalText, prompt: config.llmPrompt, apiKey: config.geminiKey
                )
            } else if config.llmProvider == "openai", !config.openAIKey.isEmpty {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .processingLLM }
                }
                finalText = try await processWithOpenAI(
                    text: finalText, prompt: config.llmPrompt, apiKey: config.openAIKey
                )
            }
        }

        try Task.checkCancellation()
        let baseDir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let outputURL = baseDir
            .appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(format)

        let content = format == "md"
            ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(finalText)\n"
            : finalText + "\n"

        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            withAnimation(AnimationConfig.standard) { state = .done(outputURL.path) }
        }
    }

    private func prepareAudio(from inputURL: URL, ext: String) async throws -> (URL, Bool) {
        if ext == "wav" {
            return (inputURL, false)
        }
        let wavURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sus_\(UUID().uuidString).wav")
        try await FFmpegConverter.convert(input: inputURL, output: wavURL)
        return (wavURL, true)
    }
    
    private func processWithGemini(text: String, prompt: String, apiKey: String) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
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
        throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response"])
    }
    
    private func processWithOpenAI(text: String, prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "LLM", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
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
        throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response"])
    }

    func revealInFinder() {
        if case .done(let path) = state {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }

    func reset() {
        inputURL = nil
        overrideModel = nil
        overrideLanguage = nil
        state = .idle
    }
}
