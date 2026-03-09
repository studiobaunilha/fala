import Foundation

enum BatchExecutionOutcome: String, Equatable, Sendable {
    case succeeded
    case cancelled
    case failed
}

enum BatchExecutionStage: String, CaseIterable, Sendable {
    case audioPreparation = "audio_preparation"
    case modelPreparation = "model_preparation"
    case transcription = "transcription"
    case postProcessing = "post_processing"
}

struct BatchExecutionMetrics: Equatable, Sendable {
    let fileName: String
    let fileExtension: String
    let usedPostProcessing: Bool
    let audioPreparationMode: BatchAudioPreparationMode?
    let modelLoadState: TranscriberLoadState?
    let outcome: BatchExecutionOutcome
    let audioPreparation: Duration?
    let modelPreparation: Duration?
    let transcription: Duration?
    let postProcessing: Duration?
    let total: Duration

    var debugSummary: String {
        String(
            format: "file=%@ ext=%@ audioMode=%@ modelState=%@ outcome=%@ prepare=%@ "
                + "model=%@ transcribe=%@ post=%@ total=%@",
            fileName,
            fileExtension,
            audioPreparationMode?.rawValue ?? "n/a",
            modelLoadState?.rawValue ?? "n/a",
            outcome.rawValue,
            audioPreparation.debugDurationText,
            modelPreparation.debugDurationText,
            transcription.debugDurationText,
            postProcessing.debugDurationText,
            total.debugDurationText
        )
    }
}

private extension Optional where Wrapped == Duration {
    var debugDurationText: String {
        guard let duration = self else {
            return "n/a"
        }
        return duration.debugDurationText
    }
}

private extension Duration {
    var debugDurationText: String {
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return String(format: "%.3fs", seconds + attoseconds)
    }
}
