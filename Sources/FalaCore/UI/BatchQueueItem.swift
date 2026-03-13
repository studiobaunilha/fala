import Foundation
import SwiftUI

public struct BatchQueueItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case pending
        case converting
        case preparingModel
        case transcribing(String)
        case processingLLM
        case done(URL, warning: BatchProcessingWarning?)
        case error(String)
        case cancelled

        public var isTerminal: Bool {
            switch self {
            case .done, .error, .cancelled:
                return true
            case .pending, .converting, .preparingModel, .transcribing, .processingLLM:
                return false
            }
        }

        public var isRetryable: Bool {
            switch self {
            case .pending, .error, .cancelled:
                return true
            case .converting, .preparingModel, .transcribing, .processingLLM, .done:
                return false
            }
        }

        public var outputURL: URL? {
            if case .done(let outputURL, _) = self {
                return outputURL
            }
            return nil
        }
    }

    public let id: UUID
    public let inputURL: URL
    public var customName: String?
    var metrics: BatchExecutionMetrics?
    public var startedAt: Date?
    public var status: Status

    public var displayName: String {
        let trimmedCustomName = customName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCustomName.isEmpty {
            return trimmedCustomName
        }
        return inputURL.deletingPathExtension().lastPathComponent
    }

    public init(
        id: UUID = UUID(),
        inputURL: URL,
        customName: String? = nil,
        startedAt: Date? = nil,
        status: Status = .pending
    ) {
        self.id = id
        self.inputURL = inputURL
        self.customName = customName
        self.startedAt = startedAt
        self.metrics = nil
        self.status = status
    }

    public var statusTitle: String {
        switch status {
        case .pending:
            return L10n("Aguardando na fila")
        case .converting:
            return L10n("Preparando arquivo de áudio…")
        case .preparingModel:
            return L10n("Preparando motor de transcrição…")
        case .transcribing:
            return L10n("Transcrevendo…")
        case .processingLLM:
            return L10n("Aprimorando com IA (LLM)…")
        case .done:
            return L10n("Transcrição Concluída")
        case .error(let message):
            return message
        case .cancelled:
            return L10n("Cancelado pelo usuário")
        }
    }

    var statusIcon: String {
        switch status {
        case .pending:
            return "list.bullet.clipboard"
        case .converting:
            return "waveform"
        case .preparingModel:
            return "cpu"
        case .transcribing:
            return "waveform.and.magnifyingglass"
        case .processingLLM:
            return "wand.and.stars"
        case .done:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    var statusTint: Color {
        switch status {
        case .pending:
            return .accentColor
        case .converting, .preparingModel, .transcribing, .processingLLM:
            return FalaColors.info
        case .done:
            return FalaColors.success
        case .error:
            return FalaColors.error
        case .cancelled:
            return .secondary
        }
    }
}
