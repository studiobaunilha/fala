import AppKit
import SwiftUI

private struct QueueWorkItem {
    let itemID: BatchQueueItem.ID
    let inputURL: URL
    let ext: String
    let outputURL: URL
}

private struct QueueRunSummary {
    var reservedOutputURLs: Set<URL> = []
    var lastCompletedOutputPath: String?
    var lastErrorMessage: String?
}

extension TranscriptionJob {
    var hasMultipleQueuedFiles: Bool {
        queue.count > 1
    }

    var hasRetryableQueueItems: Bool {
        queue.contains { $0.status.isRetryable }
    }

    var completedQueueCount: Int {
        queue.reduce(into: 0) { total, item in
            if case .done = item.status {
                total += 1
            }
        }
    }

    var failedQueueCount: Int {
        queue.reduce(into: 0) { total, item in
            if case .error = item.status {
                total += 1
            }
        }
    }

    var cancelledQueueCount: Int {
        queue.reduce(into: 0) { total, item in
            if case .cancelled = item.status {
                total += 1
            }
        }
    }

    var activeQueueItem: BatchQueueItem? {
        guard let activeQueueItemID else { return nil }
        return queue.first { $0.id == activeQueueItemID }
    }

    var activeQueueOrdinal: Int? {
        guard let activeQueueItemID,
              let index = queue.firstIndex(where: { $0.id == activeQueueItemID })
        else {
            return nil
        }
        return index + 1
    }

    var completedOutputDirectory: URL? {
        let outputURLs = queue.compactMap(\.status.outputURL)
        guard let firstDirectory = outputURLs.first?.deletingLastPathComponent() else {
            return outputDirectory
        }
        let allMatch = outputURLs.allSatisfy {
            $0.deletingLastPathComponent().standardizedFileURL == firstDirectory.standardizedFileURL
        }
        return allMatch ? firstDirectory : nil
    }

    public func prepareForUse() {
        preparationTask?.cancel()
        let config = preparationConfig()
        preparationTask = Task { [batchTranscriberPool] in
            do {
                try await batchTranscriberPool.warm(using: config)
            } catch is CancellationError {
                return
            } catch {
                NSLog("[Fala] Batch warmup failed: %@", error.localizedDescription)
            }
        }
    }

    public func cancel() {
        isCancelling = true
        processingTask?.cancel()
        currentTask?.cancel()
        preparationTask?.cancel()
    }

    func revealInFinder() {
        if case .done(let path) = state {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
    }

    func revealOutput(for itemID: BatchQueueItem.ID) {
        guard let outputURL = queue.first(where: { $0.id == itemID })?.status.outputURL else {
            return
        }
        NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: "")
    }

    func revealOutputDirectory() {
        guard let completedOutputDirectory else { return }
        NSWorkspace.shared.selectFile(completedOutputDirectory.path, inFileViewerRootedAtPath: "")
    }

    func clearQueue() {
        queue = []
        inputURL = nil
        activeQueueItemID = nil
        processingWarning = nil
        lastExecutionMetrics = nil
        isCancelling = false
        processingTask = nil
        state = .idle
    }

    func reset() {
        cancel()
        clearQueue()
        overrideModel = nil
        overrideLanguage = nil
        processingWarning = nil
        state = .idle
    }
}

extension TranscriptionJob {
    func preparationConfig() -> AppConfig {
        var config = appSettings.snapshotConfig()
        let selectedWhisperModel = overrideModel ?? config.activeWhisperModel
        config.dictationModel = selectedWhisperModel
        config.batchModel = selectedWhisperModel
        config.transcriptionLanguage = overrideLanguage ?? config.transcriptionLanguage
        return config
    }

    func syncPrimaryInputURL() {
        if let activeQueueItem {
            inputURL = activeQueueItem.inputURL
        } else {
            inputURL = queue.first?.inputURL
        }
    }

    func updateQueueItemStatus(_ itemID: BatchQueueItem.ID, status: BatchQueueItem.Status) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else { return }
        queue[index].status = status
        syncPrimaryInputURL()
    }

    func markQueueItemsCancelled(_ itemIDs: [BatchQueueItem.ID]) {
        for itemID in itemIDs {
            guard let index = queue.firstIndex(where: { $0.id == itemID }) else { continue }
            if !queue[index].status.isTerminal {
                queue[index].status = .cancelled
            }
        }
    }

    func makeOutputURL(
        for inputURL: URL,
        format: String,
        reservedOutputURLs: Set<URL>
    ) -> URL {
        let baseDirectory = outputDirectory ?? inputURL.deletingLastPathComponent()
        let stem = inputURL.deletingPathExtension().lastPathComponent
        var suffix = 1
        var candidate = baseDirectory
            .appendingPathComponent(stem)
            .appendingPathExtension(format)

        while reservedOutputURLs.contains(candidate.standardizedFileURL) {
            suffix += 1
            candidate = baseDirectory
                .appendingPathComponent("\(stem)-\(suffix)")
                .appendingPathExtension(format)
        }

        return candidate
    }

    func runQueueTask(itemIDs: [BatchQueueItem.ID]) async {
        var summary = QueueRunSummary()

        for (index, itemID) in itemIDs.enumerated() {
            guard let workItem = makeQueueWorkItem(
                for: itemID,
                reservedOutputURLs: &summary.reservedOutputURLs
            ) else {
                continue
            }

            do {
                let warning = try await runQueueItem(
                    itemID: workItem.itemID,
                    inputURL: workItem.inputURL,
                    ext: workItem.ext,
                    outputURL: workItem.outputURL
                )
                recordQueueSuccess(
                    itemID: itemID,
                    outputURL: workItem.outputURL,
                    warning: warning,
                    summary: &summary
                )
            } catch is CancellationError {
                handleQueueCancellation(remainingIDs: Array(itemIDs[index...]))
                return
            } catch {
                recordQueueFailure(itemID: itemID, error: error, summary: &summary)
            }
        }

        finishQueueRun(summary)
    }

    private func makeQueueWorkItem(
        for itemID: BatchQueueItem.ID,
        reservedOutputURLs: inout Set<URL>
    ) -> QueueWorkItem? {
        guard let queueItem = queue.first(where: { $0.id == itemID }) else {
            return nil
        }

        activeQueueItemID = itemID
        syncPrimaryInputURL()

        let inputURL = queueItem.inputURL
        let outputURL = makeOutputURL(
            for: inputURL,
            format: outputFormat,
            reservedOutputURLs: reservedOutputURLs
        )
        reservedOutputURLs.insert(outputURL.standardizedFileURL)

        return QueueWorkItem(
            itemID: itemID,
            inputURL: inputURL,
            ext: inputURL.pathExtension.lowercased(),
            outputURL: outputURL
        )
    }

    private func recordQueueSuccess(
        itemID: BatchQueueItem.ID,
        outputURL: URL,
        warning: BatchProcessingWarning?,
        summary: inout QueueRunSummary
    ) {
        processingWarning = warning
        updateQueueItemStatus(itemID, status: .done(outputURL, warning: warning))
        summary.lastCompletedOutputPath = outputURL.path
    }

    private func recordQueueFailure(
        itemID: BatchQueueItem.ID,
        error: Error,
        summary: inout QueueRunSummary
    ) {
        let message = error.localizedDescription
        updateQueueItemStatus(itemID, status: .error(message))
        summary.lastErrorMessage = message
    }

    func handleQueueCancellation(remainingIDs: [BatchQueueItem.ID]) {
        markQueueItemsCancelled(remainingIDs)
        activeQueueItemID = nil
        currentTask = nil
        preparationTask = nil
        processingTask = nil
        isCancelling = false
        syncPrimaryInputURL()
        withAnimation(AnimationConfig.standard) {
            state = .error(L10n("Cancelado pelo usuário"))
        }
    }

    private func finishQueueRun(_ summary: QueueRunSummary) {
        activeQueueItemID = nil
        currentTask = nil
        preparationTask = nil
        processingTask = nil
        isCancelling = false
        syncPrimaryInputURL()

        if let lastCompletedOutputPath = summary.lastCompletedOutputPath {
            withAnimation(AnimationConfig.standard) {
                state = .done(lastCompletedOutputPath)
            }
            return
        }

        if let lastErrorMessage = summary.lastErrorMessage {
            withAnimation(AnimationConfig.standard) {
                state = .error(lastErrorMessage)
            }
            return
        }

        withAnimation(AnimationConfig.standard) {
            state = .idle
        }
    }

}
