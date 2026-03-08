import Foundation

public struct BatchQueueItem: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case pending
        case converting
        case transcribing(String)
        case processingLLM
        case done(URL, warning: BatchProcessingWarning?)
        case error(String)
        case cancelled

        public var isTerminal: Bool {
            switch self {
            case .done, .error, .cancelled:
                return true
            case .pending, .converting, .transcribing, .processingLLM:
                return false
            }
        }

        public var isRetryable: Bool {
            switch self {
            case .pending, .error, .cancelled:
                return true
            case .converting, .transcribing, .processingLLM, .done:
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
    public var status: Status

    public init(
        id: UUID = UUID(),
        inputURL: URL,
        status: Status = .pending
    ) {
        self.id = id
        self.inputURL = inputURL
        self.status = status
    }
}
