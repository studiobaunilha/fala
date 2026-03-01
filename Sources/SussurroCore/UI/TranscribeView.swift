import SwiftUI
import AppKit

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
