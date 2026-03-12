import Foundation

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
        status: Status = .pending
    ) {
        self.id = id
        self.inputURL = inputURL
        self.customName = customName
        self.metrics = nil
        self.status = status
    }
}
