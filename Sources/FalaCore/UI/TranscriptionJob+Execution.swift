import Foundation
import SwiftUI

extension TranscriptionJob {
    func runQueueItem(
        itemID: BatchQueueItem.ID,
        inputURL: URL,
        ext: String,
        outputURL: URL
    ) async throws -> BatchProcessingWarning? {
        let profiler = BatchExecutionProfiler(
            inputURL: inputURL,
            usedPostProcessing: !batchPostPrompt.isEmpty
        )
        var outcome: BatchExecutionOutcome = .failed
        defer {
            recordBatchMetrics(profiler.snapshot(outcome: outcome))
        }

        try Task.checkCancellation()
        setActiveExecutionState(
            itemID: itemID,
            status: ext == "wav" ? .preparingModel : .converting,
            state: ext == "wav" ? .preparingModel : .converting
        )

        let (wavURL, needsCleanup) = try await profiler.measure(.audioPreparation) {
            try await prepareAudio(from: inputURL)
        }
        defer {
            if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
        }

        do {
            let warning = try await executeTranscription(
                wavURL: wavURL,
                inputURL: inputURL,
                outputURL: outputURL,
                itemID: itemID,
                profiler: profiler
            )
            outcome = .succeeded
            return warning
        } catch is CancellationError {
            outcome = .cancelled
            throw CancellationError()
        } catch {
            outcome = .failed
            throw error
        }
    }

    func executeTranscription(
        wavURL: URL,
        inputURL: URL,
        outputURL: URL,
        itemID: BatchQueueItem.ID,
        profiler: BatchExecutionProfiler
    ) async throws -> BatchProcessingWarning? {
        let config = preparationConfig()
        let format = outputFormat
        let transcriber = try await prepareExecutionTranscriber(
            itemID: itemID,
            config: config,
            profiler: profiler
        )

        try initializeOutputFile(url: outputURL, format: format, inputURL: inputURL)
        let context = ProcessingContext(
            config: config,
            template: batchPostPrompt.isEmpty ? .raw : .custom,
            format: format,
            outputURL: outputURL,
            inputURL: inputURL
        )
        let (continuation, processingTask) = makeProcessingPipeline(
            context: context,
            promptOverride: batchPostPrompt.isEmpty ? nil : batchPostPrompt
        )
        self.processingTask = processingTask
        defer {
            self.processingTask = nil
        }

        setActiveExecutionState(
            itemID: itemID,
            status: .transcribing(""),
            state: .transcribing("")
        )
        try await streamTranscription(
            transcriber: transcriber,
            wavPath: wavURL.path,
            profiler: profiler,
            continuation: continuation,
            processingTask: processingTask
        )

        let processingResult = await awaitProcessingResult(
            itemID: itemID,
            profiler: profiler,
            processingTask: processingTask
        )
        processingWarning = processingResult.warning
        try Task.checkCancellation()

        return processingResult.warning
    }
}

private extension TranscriptionJob {
    func makeProcessingPipeline(
        context: ProcessingContext,
        promptOverride: String?
    ) -> (
        AsyncStream<TranscriberProgress>.Continuation,
        Task<BatchProcessingResult, Never>
    ) {
        let (stream, continuation) = AsyncStream<TranscriberProgress>.makeStream()
        let processingTask = createProcessingTask(
            stream: stream,
            context: context,
            batchPromptOverride: promptOverride
        )
        return (continuation, processingTask)
    }

    func prepareExecutionTranscriber(
        itemID: BatchQueueItem.ID,
        config: AppConfig,
        profiler: BatchExecutionProfiler
    ) async throws -> any AudioTranscribing {
        let effectiveModel = overrideModel ?? config.activeWhisperModel
        let effectiveLanguage = overrideLanguage ?? config.transcriptionLanguage
        let transcriber = await batchTranscriberPool.transcriber(
            using: config,
            modelName: effectiveModel,
            language: effectiveLanguage
        )

        setActiveExecutionState(
            itemID: itemID,
            status: .preparingModel,
            state: .preparingModel
        )
        try await profiler.measure(.modelPreparation) {
            try await transcriber.loadIfNeeded(progress: nil)
        }
        try Task.checkCancellation()
        return transcriber
    }

    func streamTranscription(
        transcriber: any AudioTranscribing,
        wavPath: String,
        profiler: BatchExecutionProfiler,
        continuation: AsyncStream<TranscriberProgress>.Continuation,
        processingTask: Task<BatchProcessingResult, Never>
    ) async throws {
        do {
            try await withTaskCancellationHandler {
                _ = try await profiler.measure(.transcription) {
                    try await transcriber.transcribe(audioPath: wavPath) { progressUpdate in
                        guard !Task.isCancelled else { return }
                        continuation.yield(progressUpdate)
                    }
                }
                continuation.finish()
            } onCancel: {
                continuation.finish()
                processingTask.cancel()
            }
        } catch {
            continuation.finish()
            processingTask.cancel()
            throw error
        }
    }

    func awaitProcessingResult(
        itemID: BatchQueueItem.ID,
        profiler: BatchExecutionProfiler,
        processingTask: Task<BatchProcessingResult, Never>
    ) async -> BatchProcessingResult {
        if !batchPostPrompt.isEmpty {
            setActiveExecutionState(
                itemID: itemID,
                status: .processingLLM,
                state: .processingLLM
            )
            return await profiler.measure(.postProcessing) {
                await processingTask.value
            }
        }

        return await processingTask.value
    }

    func setActiveExecutionState(
        itemID: BatchQueueItem.ID,
        status: BatchQueueItem.Status,
        state: TranscriptionState
    ) {
        updateQueueItemStatus(itemID, status: status)
        withAnimation(AnimationConfig.standard) {
            self.state = state
        }
    }
}
