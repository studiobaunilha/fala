import AVFoundation
import Foundation
import os

private let batchLogger = Logger(
    subsystem: "dev.fala.app", category: "BatchProfiling"
)

@MainActor
final class BatchExecutionProfiler {
    private let clock = ContinuousClock()
    private let totalStart: ContinuousClock.Instant
    private let inputURL: URL
    private let usedPostProcessing: Bool
    private var stageDurations: [BatchExecutionStage: Duration] = [:]
    private var audioPreparationMode: BatchAudioPreparationMode?
    private var modelLoadState: TranscriberLoadState?

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

    func recordAudioPreparationMode(_ mode: BatchAudioPreparationMode) {
        audioPreparationMode = mode
    }

    func recordModelLoadState(_ state: TranscriberLoadState) {
        modelLoadState = state
    }

    func snapshot(outcome: BatchExecutionOutcome) -> BatchExecutionMetrics {
        let fileSize = (try? FileManager.default.attributesOfItem(
            atPath: inputURL.path
        )[.size] as? Int64) ?? nil
        let audioDuration = AudioDurationReader.duration(of: inputURL)

        return BatchExecutionMetrics(
            fileName: inputURL.lastPathComponent,
            fileExtension: inputURL.pathExtension.lowercased(),
            inputFileSize: fileSize,
            audioDuration: audioDuration,
            usedPostProcessing: usedPostProcessing,
            audioPreparationMode: audioPreparationMode,
            modelLoadState: modelLoadState,
            outcome: outcome,
            audioPreparation: stageDurations[.audioPreparation],
            modelPreparation: stageDurations[.modelPreparation],
            transcription: stageDurations[.transcription],
            postProcessing: stageDurations[.postProcessing],
            fileSaving: stageDurations[.fileSaving],
            total: clock.now - totalStart
        )
    }
}

extension TranscriptionJob {
    func recordBatchMetrics(_ metrics: BatchExecutionMetrics) {
        lastExecutionMetrics = metrics
        batchLogger.notice(
            "[Fala] Batch timing \(metrics.debugSummary, privacy: .public)"
        )
    }
}

enum AudioDurationReader {
    static func duration(of url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite ? seconds : nil
    }
}
