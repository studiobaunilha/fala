import Foundation

enum DiagnosticLogCollector {
    struct DiagnosticReport: Sendable {
        let appVersion: String
        let macOSVersion: String
        let transcriptionEngine: String
        let llmProvider: String
        let llmModel: String
        let recentMetrics: [MetricsHistoryEntry]
        let timestamp: Date
    }

    @MainActor
    static func collect(settings: AppSettings) -> DiagnosticReport {
        let config = settings.snapshotConfig()
        return DiagnosticReport(
            appVersion: appVersionString(),
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            transcriptionEngine: config.transcriptionEngine,
            llmProvider: config.llmProvider,
            llmModel: llmModel(for: config),
            recentMetrics: MetricsHistoryStore.shared.entries,
            timestamp: Date()
        )
    }

    static func formatAsText(_ report: DiagnosticReport) -> String {
        var lines: [String] = []

        lines.append("=== Fala Diagnostic Report ===")
        lines.append("Generated: \(report.timestamp.formatted(.iso8601))")
        lines.append("")
        lines.append("--- Application ---")
        lines.append("Version: \(report.appVersion)")
        lines.append("macOS: \(report.macOSVersion)")
        lines.append("")
        lines.append("--- Configuration ---")
        lines.append("Transcription Engine: \(report.transcriptionEngine)")
        lines.append("LLM Provider: \(report.llmProvider)")
        lines.append("LLM Model: \(report.llmModel)")
        lines.append("")
        lines.append("--- Recent Transcriptions (\(report.recentMetrics.count)) ---")

        for (index, metrics) in report.recentMetrics.enumerated() {
            lines.append(
                "[\(index + 1)] \(metrics.recordedAt.formatted(date: .numeric, time: .standard))"
            )
            lines.append("    \(metrics.metrics.debugSummary)")
        }

        if report.recentMetrics.isEmpty {
            lines.append("(none)")
        }

        lines.append("")
        lines.append("=== End of Report ===")
        return lines.joined(separator: "\n")
    }

    private static func appVersionString() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private static func llmModel(for config: AppConfig) -> String {
        switch config.llmProvider {
        case "gemini": config.geminiModel
        case "openai": config.openAIModel
        case "mlx": config.mlxModel
        case "apple": "Apple Intelligence"
        default: config.llmProvider
        }
    }
}
