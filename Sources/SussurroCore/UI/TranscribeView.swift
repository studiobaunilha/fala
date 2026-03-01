import SwiftUI
import AppKit

// MARK: – State

public enum TranscriptionState: Equatable {
    case idle
    case converting
    case transcribing
    case done(String)  // output file path
    case error(String)
}

// MARK: – View Model

@MainActor
public final class TranscriptionJob: ObservableObject {
    @Published public var inputURL: URL?
    @Published public var state: TranscriptionState = .idle
    @Published public var outputFormat: String

    public init() {
        self.outputFormat = AppConfig.load().outputFormat
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

    public func transcribe() {
        guard let inputURL else { return }
        let ext = inputURL.pathExtension.lowercased()
        let format = outputFormat
        let modelName = AppConfig.load().batchModel

        withAnimation(AnimationConfig.standard) {
            state = ext == "wav" ? .transcribing : .converting
        }

        Task {
            do {
                let (wavURL, needsCleanup) = try await prepareAudio(from: inputURL, ext: ext)
                defer {
                    if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
                }

                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .transcribing }
                }

                let text = try await Transcriber(modelName: modelName).transcribe(audioPath: wavURL.path)

                let outputURL = inputURL
                    .deletingPathExtension()
                    .appendingPathExtension(format)

                let content = format == "md"
                    ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(text)\n"
                    : text + "\n"

                try content.write(to: outputURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .done(outputURL.path) }
                }
            } catch {
                await MainActor.run {
                    withAnimation(AnimationConfig.standard) { state = .error(error.localizedDescription) }
                }
            }
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

    private var isWorking: Bool {
        job.state == .converting || job.state == .transcribing
    }

    var body: some View {
        Form {
            Section("Arquivo") {
                if let url = job.inputURL {
                    LabeledContent("Nome") {
                        Text(url.lastPathComponent)
                    }
                    Button("Trocar Arquivo…") { job.selectFile() }
                        .disabled(isWorking)
                } else {
                    Button("Selecionar Arquivo…") { job.selectFile() }
                }
            }

            if job.inputURL != nil {
                Section("Opções") {
                    Picker("Formato de saída", selection: $job.outputFormat) {
                        Text("Texto (.txt)").tag("txt")
                        Text("Markdown (.md)").tag("md")
                    }
                    .disabled(isWorking)
                }

                Section {
                    statusView
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: WindowSize.transcribeMinWidth, minHeight: WindowSize.transcribeMinHeight)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.state {
        case .idle:
            Button("Transcrever") {
                job.transcribe()
            }
            .controlSize(.large)

        case .converting:
            StatusBanner(message: "Convertendo áudio…")

        case .transcribing:
            StatusBanner(message: "Transcrevendo…")

        case .done(let path):
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Concluído", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(SussurroColors.success)
                Text(path)
                    .font(Typography.caption).foregroundStyle(SussurroColors.textSecondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Mostrar no Finder") { job.revealInFinder() }
                    Button("Nova Transcrição") {
                        withAnimation(AnimationConfig.standard) {
                            job.reset()
                        }
                    }
                }
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Erro", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(SussurroColors.error)
                Text(message)
                    .font(Typography.caption).foregroundStyle(SussurroColors.textSecondary)
                Button("Tentar Novamente") {
                    withAnimation(AnimationConfig.standard) {
                        job.state = .idle
                    }
                }
            }
        }
    }
}
