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

    public init() {
        let config = AppConfig.load()
        self.outputFormat = config.outputFormat
        if !config.defaultExportPath.isEmpty {
            self.outputDirectory = URL(fileURLWithPath: config.defaultExportPath)
        }
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
        let modelName = config.batchModel

        withAnimation(AnimationConfig.standard) {
            state = ext == "wav" ? .transcribing("") : .converting
        }

        Task {
            do {
                let (wavURL, needsCleanup) = try await prepareAudio(from: inputURL, ext: ext)
                defer {
                    if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
                }

                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .transcribing("") }
                }

                let transcriber = Transcriber(
                    modelName: modelName,
                    language: config.language,
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
                
                try await processOutput(text: text, inputURL: inputURL, config: config, format: format)
            } catch {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .error(error.localizedDescription) }
                }
            }
        }
    }

    private func processOutput(text: String, inputURL: URL, config: AppConfig, format: String) async throws {
        var finalText = text
        
        if config.enableLLMPostProcessing, !config.openAIKey.isEmpty {
            await MainActor.run {
                withAnimation(AnimationConfig.standard) { state = .processingLLM }
            }
            finalText = try await processWithLLM(text: finalText, prompt: config.llmPrompt, apiKey: config.openAIKey)
        }

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
    
    private func processWithLLM(text: String, prompt: String, apiKey: String) async throws -> String {
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
        throw NSError(domain: "LLM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse LLM response"])
    }

    func revealInFinder() {
        if case .done(let path) = state {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }

    func reset() {
        inputURL = nil
        state = .idle
    }
}

// MARK: – View

struct TranscribeView: View {
    @ObservedObject var job: TranscriptionJob
    @State private var isDropTargeted = false

    private var isWorking: Bool {
        if case .idle = job.state { return false }
        if case .done = job.state { return false }
        if case .error = job.state { return false }
        return true
    }

    var body: some View {
        Group {
            if job.inputURL == nil {
                emptyStateView
            } else {
                formView
            }
        }
        .frame(minWidth: WindowSize.transcribeMinWidth, minHeight: WindowSize.transcribeMinHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .dropDestination(for: URL.self) { items, _ in
            return handleDrop(items)
        } isTargeted: { targeted in
            withAnimation(AnimationConfig.standard) {
                isDropTargeted = targeted
            }
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.accentColor.opacity(0.1)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .padding(Spacing.sm)
                }
                .allowsHitTesting(false)
            }
        }
    }
    
    private func handleDrop(_ items: [URL]) -> Bool {
        guard let url = items.first else { return false }
        let ext = url.pathExtension.lowercased()
        if BatchMode.supportedExtensions.contains(ext) {
            job.inputURL = url
            job.state = .idle
            return true
        }
        return false
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.accentColor)
                .padding(.bottom, Spacing.sm)
            
            Text("Arraste e solte um arquivo de áudio aqui")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Ou selecione um arquivo para iniciar a transcrição de alta precisão.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button("Selecionar Arquivo…") {
                job.selectFile()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var formView: some View {
        Form {
            Section("Arquivo") {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "doc.audio.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(job.inputURL?.lastPathComponent ?? "")
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Text("Pronto para transcrever")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Trocar...") { job.selectFile() }
                        .disabled(isWorking)
                }
                .padding(.vertical, Spacing.xs)
            }

            Section("Configurações de Saída") {
                Picker("Formato", selection: $job.outputFormat) {
                    Text("Texto (.txt)").tag("txt")
                    Text("Markdown (.md)").tag("md")
                }
                .disabled(isWorking)
                
                HStack {
                    Text("Salvar em:")
                    Spacer()
                    Text(job.outputDirectory?.lastPathComponent ?? "Mesma Pasta do Original")
                        .foregroundColor(.secondary)
                    Button("Alterar...") { job.selectOutputDirectory() }
                        .disabled(isWorking)
                }
            }

            Section {
                statusView
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.state {
        case .idle:
            Button("Iniciar Transcrição") {
                job.transcribe()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

        case .converting:
            StatusBanner(message: "Preparando arquivo de áudio…")

        case .transcribing(let progressText):
            VStack(alignment: .leading, spacing: Spacing.md) {
                StatusBanner(message: "Transcrevendo…")
                if !progressText.isEmpty {
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .padding(.horizontal, Spacing.sm)
                }
            }
            
        case .processingLLM:
            StatusBanner(message: "Aprimorando com IA (LLM)…")

        case .done(let path):
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Transcrição Concluída", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.green)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Mostrar no Finder") { job.revealInFinder() }
                    Button("Nova Transcrição") {
                        withAnimation(AnimationConfig.standard) {
                            job.reset()
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Falha na Transcrição", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Tentar Novamente") {
                    withAnimation(AnimationConfig.standard) {
                        job.state = .idle
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}
