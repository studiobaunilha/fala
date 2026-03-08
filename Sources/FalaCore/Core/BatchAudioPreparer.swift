import Foundation

public struct PreparedBatchAudio: Equatable, Sendable {
    public let wavURL: URL
    public let requiresCleanup: Bool

    public init(wavURL: URL, requiresCleanup: Bool) {
        self.wavURL = wavURL
        self.requiresCleanup = requiresCleanup
    }
}

public enum BatchAudioPreparer {
    public static func prepareTranscriptionInput(
        from inputURL: URL,
        temporaryDirectory: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) throws -> PreparedBatchAudio {
        if inputURL.pathExtension.lowercased() == "wav" {
            return PreparedBatchAudio(wavURL: inputURL, requiresCleanup: false)
        }

        let wavURL = temporaryDirectory
            .appendingPathComponent("fala-batch-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        do {
            try AudioConverter.write16kMonoWAV(from: inputURL, to: wavURL)
        } catch {
            throw AudioError.conversionFailed
        }
        return PreparedBatchAudio(wavURL: wavURL, requiresCleanup: true)
    }
}
