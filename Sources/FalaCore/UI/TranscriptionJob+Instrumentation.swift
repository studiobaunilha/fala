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
    let outcome: BatchExecutionOutcome
    let audioPreparation: Duration?
    let modelPreparation: Duration?
    let transcription: Duration?
    let postProcessing: Duration?
    let total: Duration
}

@MainActor
final class BatchExecutionProfiler {
    private let clock = ContinuousClock()
    private let totalStart: ContinuousClock.Instant
    private let inputURL: URL
    private let usedPostProcessing: Bool
    private var stageDurations: [BatchExecutionStage: Duration] = [:]

    init(inputURL: URL, usedPostProcessing: Bool) {
        self.totalStart = clock.now
        self.inputURL = inputURL
        self.usedPostProcessing = usedPostProcessing
    }

    func measure<T>(
        _ stage: BatchExecutionStage,
        operation: () async throws -> T
    ) async rethrows -> T {
        let stageStart = clock.now
        do {
            let value = try await operation()
            stageDurations[stage] = clock.now - stageStart
            return value
        } catch {
            stageDurations[stage] = clock.now - stageStart
            throw error
        }
    }

    func snapshot(outcome: BatchExecutionOutcome) -> BatchExecutionMetrics {
        BatchExecutionMetrics(
            fileName: inputURL.lastPathComponent,
            fileExtension: inputURL.pathExtension.lowercased(),
            usedPostProcessing: usedPostProcessing,
            outcome: outcome,
            audioPreparation: stageDurations[.audioPreparation],
            modelPreparation: stageDurations[.modelPreparation],
            transcription: stageDurations[.transcription],
            postProcessing: stageDurations[.postProcessing],
            total: clock.now - totalStart
        )
    }
}

extension TranscriptionJob {
    func recordBatchMetrics(_ metrics: BatchExecutionMetrics) {
        lastExecutionMetrics = metrics
        NSLog(
            "[Fala] Batch timing file=%@ ext=%@ outcome=%@ prepare=%@ model=%@ transcribe=%@ post=%@ total=%@",
            metrics.fileName,
            metrics.fileExtension,
            metrics.outcome.rawValue,
            metrics.audioPreparation.debugDurationText,
            metrics.modelPreparation.debugDurationText,
            metrics.transcription.debugDurationText,
            metrics.postProcessing.debugDurationText,
            metrics.total.debugDurationText
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
