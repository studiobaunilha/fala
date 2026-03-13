import Foundation

public enum BatchAudioPreparationMode: String, Equatable, Sendable {
    case passthrough
    case converted
}

public struct PreparedBatchAudio: @unchecked Sendable {
    public let wavURL: URL
    public let requiresCleanup: Bool
    public let mode: BatchAudioPreparationMode
    public let samples: [Float]?

    public init(
        wavURL: URL,
        requiresCleanup: Bool,
        mode: BatchAudioPreparationMode,
        samples: [Float]? = nil
    ) {
        self.wavURL = wavURL
        self.requiresCleanup = requiresCleanup
        self.mode = mode
        self.samples = samples
    }
}

public enum BatchAudioPreparer {
    public static func prepareTranscriptionInput(
        from inputURL: URL,
        temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true),
        cancellationCheck: @escaping @Sendable () throws -> Void = {}
    ) throws -> PreparedBatchAudio {
        if inputURL.pathExtension.lowercased() == "wav" {
            return PreparedBatchAudio(
                wavURL: inputURL,
                requiresCleanup: false,
                mode: .passthrough
            )
        }

        let samples: [Float]
        do {
            try cancellationCheck()
            samples = try AudioConverter.toFloat16k(
                from: inputURL,
                cancellationCheck: cancellationCheck
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AudioError.conversionFailed
        }
        
        return PreparedBatchAudio(
            wavURL: inputURL, // Doesn't matter, transcriber will prefer `samples` array
            requiresCleanup: false,
            mode: .converted,
            samples: samples
        )
    }
}
