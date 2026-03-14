import AppKit
import Foundation
import MetricKit

/// Listens for `MXCrashDiagnostic` payloads delivered by the system on app launch
/// if the application crashed during its previous session.
/// Automatically prompts the user to submit a bug report via email with the crash log attached.
@MainActor
public final class CrashReporter: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    public static let shared = CrashReporter()

    private let logCollector: () -> DiagnosticLogCollector.DiagnosticReport
    private let metricManager = MXMetricManager.shared

    private override init() {
        self.logCollector = {
            // Provide a graceful fallback snapshot if AppSettings is somehow unavailable
            let config = AppConfig.load()
            return DiagnosticLogCollector.DiagnosticReport(
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                transcriptionEngine: config.transcriptionEngine,
                llmProvider: config.llmProvider,
                llmModel: config.llmProvider == "mlx" ? config.mlxModel :
                    (config.llmProvider == "openai" ? config.openAIModel : config.geminiModel),
                licenseStatus: "Unknown (Crash Recovery)",
                recentMetrics: [],
                timestamp: Date()
            )
        }
        super.init()
    }

    /// Register to receive diagnostic payloads on app launch.
    public func start() {
        if #available(macOS 12.0, *) {
            metricManager.add(self)
        }
    }

    public func stop() {
        if #available(macOS 12.0, *) {
            metricManager.remove(self)
        }
    }

    // MARK: - MXMetricManagerSubscriber

    // Metrics are standard usage reports (ignored here).
    nonisolated public func didReceive(_ payloads: [MXMetricPayload]) {
    }

    // Diagnostics contain crash logs and hangs.
    @available(macOS 12.0, *)
    nonisolated public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            if let crashes = payload.crashDiagnostics {
                for crash in crashes {
                    let type = crash.exceptionType?.intValue ?? -1
                    let code = crash.exceptionCode?.intValue ?? -1
                    let signal = crash.signal?.intValue ?? -1
                    let stackData = crash.callStackTree.jsonRepresentation()

                    Task { @MainActor [weak self] in
                        self?.handleCrashDiagnostic(type: type, code: code, signal: signal, stackData: stackData)
                    }
                }
            }
        }
    }

    @available(macOS 12.0, *)
    private func handleCrashDiagnostic(type: Int, code: Int, signal: Int, stackData: Data) {
        // Create an alert on the main thread asking to report the crash
        let alert = NSAlert()
        alert.messageText = L10n("O Fala foi encerrado inesperadamente.")
        let info = L10n(
            "Um relatório do erro foi gerado com segurança e não contém dados pessoais. " +
            "Gostaria de enviar o diagnóstico para a equipe de suporte ajudar a resolver o problema?"
        )
        alert.informativeText = info
        alert.alertStyle = .critical

        alert.addButton(withTitle: L10n("Reportar Problema"))
        alert.addButton(withTitle: L10n("Ignorar"))

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        do {
            try prepareAndPromptEmailReport(type: type, code: code, signal: signal, stackData: stackData)
        } catch {
            print("[Fala] Falha ao exportar log de crash: \(error)")
        }
    }

    @available(macOS 12.0, *)
    private func prepareAndPromptEmailReport(type: Int, code: Int, signal: Int, stackData: Data) throws {
        // 1. Build the log
        let report = logCollector()
        var text = DiagnosticLogCollector.formatAsText(report)

        text += "\n\n=== EXCEPTION INFO ===\n"
        text += "Exception Type: \(type)\n"
        text += "Exception Code: \(code)\n"
        text += "Signal: \(signal)\n"
        text += "\n=== STACK TRACE ===\n"

        if let stackString = String(data: stackData, encoding: .utf8) {
            text += stackString
        }

        // 2. Write it to Downloads for easiest attachment
        let downloadsURL = try FileManager.default.url(
            for: .downloadsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let filename = "Fala-Crash-Report-\(Int(Date().timeIntervalSince1970)).txt"
        let fileURL = downloadsURL.appendingPathComponent(filename)

        try text.write(to: fileURL, atomically: true, encoding: .utf8)

        // 3. Highlight the file in Finder
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])

        // 4. Open Support Email
        let subject = "Fala Crash Report"
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let bodyText = String(
            format: L10n("Olá! O app foi encerrado inesperadamente. Anexei o arquivo de crash ('%@') " +
                         "gerado na minha pasta Downloads.\n\nMaior detalhe sobre o que eu estava fazendo (Opcional):"),
            filename
        )
        let body = bodyText
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""

        if let mailto = URL(string: "mailto:support@baunilha.dev?subject=\(subject)&body=\(body)") {
            NSWorkspace.shared.open(mailto)
        }
    }
}
