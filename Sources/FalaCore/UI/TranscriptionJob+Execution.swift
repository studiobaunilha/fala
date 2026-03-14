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

        do {
            try Task.checkCancellation()
            setActiveExecutionState(
                itemID: itemID,
                status: ext == "wav" ? .preparingModel : .converting,
                state: ext == "wav" ? .preparingModel : .converting
            )
            profiler.recordAudioPreparationMode(ext == "wav" ? .passthrough : .converted)

            let preparedAudio = try await profiler.measure(.audioPreparation) {
                try await prepareAudio(from: inputURL)
            }
            profiler.recordAudioPreparationMode(preparedAudio.mode)
            let wavURL = preparedAudio.wavURL
            let needsCleanup = preparedAudio.requiresCleanup
            defer {
                if needsCleanup { try? FileManager.default.removeItem(at: wavURL) }
            }

            let warning = try await executeTranscription(
                preparedAudio: preparedAudio,
                inputURL: inputURL,
                outputURL: outputURL,
                itemID: itemID,
                profiler: profiler
            )
            outcome = .succeeded
            recordBatchMetrics(await profiler.snapshot(outcome: outcome))
            return warning
        } catch is CancellationError {
            outcome = .cancelled
            recordBatchMetrics(await profiler.snapshot(outcome: outcome))
            throw CancellationError()
        } catch {
            outcome = .failed
            recordBatchMetrics(await profiler.snapshot(outcome: outcome))
            throw error
        }
    }

    func executeTranscription(
        preparedAudio: PreparedBatchAudio,
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

        try initializeOutputFile(url: outputURL, format: format)
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
            preparedAudio: preparedAudio,
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
        let loadState = await transcriber.loadState()
        profiler.recordModelLoadState(loadState)

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
        preparedAudio: PreparedBatchAudio,
        profiler: BatchExecutionProfiler,
        continuation: AsyncStream<TranscriberProgress>.Continuation,
        processingTask: Task<BatchProcessingResult, Never>
    ) async throws {
        do {
            try await withTaskCancellationHandler {
                _ = try await profiler.measure(.transcription) {
                    if let samples = preparedAudio.samples {
                        // High-speed memory bypass (Zero-Disk)
                        let resultText = try await transcriber.transcribe(samples: samples)
                        guard !Task.isCancelled else { return }
                        continuation.yield(TranscriberProgress(text: resultText, windowId: 0))
                    } else {
                        // Passthrough disk fallback for raw `.wav`s
                        _ = try await transcriber.transcribe(audioPath: preparedAudio.wavURL.path) { progressUpdate in
                            guard !Task.isCancelled else { return }
                            continuation.yield(progressUpdate)
                        }
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

        return await profiler.measure(.fileSaving) {
            await processingTask.value
        }
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
