import SwiftUI
import AppKit

// MARK: – State

enum TranscriptionState: Equatable {
    case idle
    case converting
    case transcribing
    case done(String)  // output file path
    case error(String)
}

// MARK: – View Model

@MainActor
final class TranscriptionJob: ObservableObject {
    @Published var inputURL: URL?
    @Published var state: TranscriptionState = .idle
    @Published var outputFormat: String

    init() {
        self.outputFormat = AppConfig.load().outputFormat
    }

    func selectFile() {
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

    func transcribe() {
        guard let inputURL else { return }
        let ext = inputURL.pathExtension.lowercased()
        let config = AppConfig.load()
        let format = outputFormat
        let modelName = config.batchModel

        state = ext == "wav" ? .transcribing : .converting

        Task {
            do {
                let wavURL: URL
                let needsCleanup: Bool

                if ext == "wav" {
                    wavURL = inputURL
                    needsCleanup = false
                } else {
                    wavURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("sus_\(UUID().uuidString).wav")
                    try await FFmpegConverter.convert(input: inputURL, output: wavURL)
                    needsCleanup = true
                }

                defer {
                    if needsCleanup {
                        try? FileManager.default.removeItem(at: wavURL)
                    }
                }

                state = .transcribing

                let transcriber = Transcriber(modelName: modelName)
                let text = try await transcriber.transcribe(audioPath: wavURL.path)

                let outputURL = inputURL
                    .deletingPathExtension()
                    .appendingPathExtension(format)

                let content = format == "md"
                    ? "# \(inputURL.deletingPathExtension().lastPathComponent)\n\n\(text)\n"
                    : text + "\n"

                try content.write(to: outputURL, atomically: true, encoding: .utf8)
                state = .done(outputURL.path)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
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
        .frame(minWidth: 400, minHeight: 280)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.state {
        case .idle:
            Button("Transcrever") { job.transcribe() }
                .controlSize(.large)

        case .converting:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Convertendo áudio…").foregroundStyle(.secondary)
            }

        case .transcribing:
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("Transcrevendo…").foregroundStyle(.secondary)
            }

        case .done(let path):
            VStack(alignment: .leading, spacing: 8) {
                Label("Concluído", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(path)
                    .font(.caption).foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    Button("Mostrar no Finder") { job.revealInFinder() }
                    Button("Nova Transcrição") { job.reset() }
                }
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Erro", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption).foregroundStyle(.secondary)
                Button("Tentar Novamente") { job.state = .idle }
            }
        }
    }
}
