import AppKit
import SwiftUI

extension SettingsView {
    var supportView: some View {
        Form {
            contactSection
            bugReportSection
            appStateSection
            diagnosticExportSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Suporte"))
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section {
            if let url = URL(string: "mailto:support@baunilha.dev") {
                Link(destination: url) {
                    Label(L10n("E-mail de Suporte"), systemImage: "envelope")
                }
            }
            if let url = URL(string: "https://studio.baunilha.dev/suporte") {
                Link(destination: url) {
                    Label(L10n("Central de Ajuda"), systemImage: "safari")
                }
            }
        } header: {
            Text(L10n("Contato"))
        } footer: {
            Text(L10n("Entre em contato com a equipe de suporte para dúvidas, sugestões ou problemas."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bug Report

    private var bugReportSection: some View {
        Section {
            TextEditor(text: $supportBugDescription)
                .font(.body)
                .frame(minHeight: LayoutMetric.batchPromptMinHeight)
                .scrollContentBackground(.hidden)

            HStack(spacing: Spacing.lg) {
                Button(L10n("Enviar por E-mail")) {
                    sendBugReportByEmail()
                }
                .disabled(supportBugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(L10n("Exportar Arquivo")) {
                    exportBugReportToFile()
                }
                .disabled(supportBugDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            Text(L10n("Relatar Problema"))
        } footer: {
            // swiftlint:disable:next line_length
            Text(L10n("Descreva o problema encontrado. Ao enviar, informações de diagnóstico serão anexadas automaticamente."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - App State

    private var appStateSection: some View {
        Section {
            LabeledContent(L10n("Motor de Transcrição")) {
                Text(settings.transcriptionEngine == "whisper" ? "Whisper" : "Parakeet")
                    .foregroundStyle(.secondary)
            }
            LabeledContent(L10n("Provedor LLM")) {
                Text(localizedProviderNameForSupport(settings.llmProvider))
                    .foregroundStyle(.secondary)
            }

            if let lastMetrics = metricsHistory.entries.last {
                LabeledContent(L10n("Última transcrição")) {
                    Text(lastMetrics.metrics.fileName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if !metricsHistory.entries.isEmpty {
                LabeledContent(L10n("Total de transcrições")) {
                    Text("\(metricsHistory.entries.count)")
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(metricsHistory.entries.suffix(5).reversed())) { entry in
                    let recordedAtSummary = entry.recordedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(entry.metrics.fileName)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(
                            "\(recordedAtSummary) · \(entry.metrics.humanReadableTotal)"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help(entry.metrics.stageBreakdownTooltip)
                    }
                    .padding(.top, Spacing.xxs)
                }
            }
        } header: {
            Text(L10n("Estado do Aplicativo"))
        }
    }

    // MARK: - Diagnostic Export

    private var diagnosticExportSection: some View {
        Section {
            Button(L10n("Exportar Diagnóstico")) {
                exportDiagnostics()
            }
        } header: {
            Text(L10n("Dados de Diagnóstico"))
        } footer: {
            Text(L10n("Gera um arquivo com informações técnicas para enviar ao suporte."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var metricsHistory: MetricsHistoryStore {
        MetricsHistoryStore.shared
    }

    private func localizedProviderNameForSupport(_ key: String) -> String {
        switch key {
        case "gemini": return L10n("Google Gemini (Cloud)")
        case "openai": return L10n("OpenAI (Cloud)")
        case "apple": return L10n("Apple Intelligence (Local)")
        case "mlx": return L10n("MLX Local")
        default: return key
        }
    }

    private func buildDiagnosticText(description: String? = nil) -> String {
        let report = DiagnosticLogCollector.collect(settings: settings)
        var text = DiagnosticLogCollector.formatAsText(report)
        if let description, !description.isEmpty {
            text = "--- User Description ---\n\(description)\n\n\(text)"
        }
        return text
    }

    private func sendBugReportByEmail() {
        let description = supportBugDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnostic = buildDiagnosticText(description: description)
        let subject = "Fala Bug Report"
        let body = diagnostic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@baunilha.dev?subject=\(subjectEncoded)&body=\(body)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func exportBugReportToFile() {
        let description = supportBugDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let diagnostic = buildDiagnosticText(description: description)
        saveDiagnosticFile(content: diagnostic, defaultName: "fala-bug-report.txt")
    }

    private func exportDiagnostics() {
        let diagnostic = buildDiagnosticText()
        saveDiagnosticFile(content: diagnostic, defaultName: "fala-diagnostic.txt")
    }

    private func saveDiagnosticFile(content: String, defaultName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
