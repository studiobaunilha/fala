import Foundation

public enum BatchAudioPreparationMode: String, Equatable, Sendable {
    case passthrough
    case converted
}

public struct PreparedBatchAudio: Equatable, Sendable {
    public let wavURL: URL
    public let requiresCleanup: Bool
    public let mode: BatchAudioPreparationMode

    public init(
        wavURL: URL,
        requiresCleanup: Bool,
        mode: BatchAudioPreparationMode
    ) {
        self.wavURL = wavURL
        self.requiresCleanup = requiresCleanup
        self.mode = mode
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

        let wavURL = temporaryDirectory
            .appendingPathComponent("fala-batch-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        do {
            try cancellationCheck()
            try AudioConverter.write16kMonoWAV(
                from: inputURL,
                to: wavURL,
                cancellationCheck: cancellationCheck
            )
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: wavURL)
            throw CancellationError()
        } catch {
            try? FileManager.default.removeItem(at: wavURL)
            throw AudioError.conversionFailed
        }
        return PreparedBatchAudio(
            wavURL: wavURL,
            requiresCleanup: true,
            mode: .converted
        )
    }
}
