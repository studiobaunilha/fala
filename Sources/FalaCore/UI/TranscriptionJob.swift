import SwiftUI
import AppKit

// MARK: – State

public enum TranscriptionState: Equatable {
    case idle
    case converting
    case preparingModel
    case transcribing(String)
    case processingLLM
    case done(String)  // output file path
    case error(String)
}

public struct BatchProcessingWarning: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

// MARK: – View Model

@MainActor
public final class TranscriptionJob: ObservableObject {
    typealias AudioPreparationHandler = @Sendable (URL) async throws -> PreparedBatchAudio

    @Published public var inputURL: URL?
    @Published public internal(set) var queue: [BatchQueueItem] = []
    @Published public internal(set) var activeQueueItemID: BatchQueueItem.ID?
    @Published public var state: TranscriptionState = .idle
    @Published public var outputFormat: String
    @Published public var outputDirectory: URL?
    @Published public var batchPostPrompt: String = ""
    @Published public var processingWarning: BatchProcessingWarning?
    @Published var lastExecutionMetrics: BatchExecutionMetrics?
    @Published public internal(set) var isCancelling = false

    // Per-job overrides
    @Published public var overrideModel: String?
    @Published public var overrideLanguage: String?

    // Dependency
    @Published public var appSettings: AppSettings
    var currentTask: Task<Void, Never>?
    var preparationTask: Task<Void, Never>?
    var processingTask: Task<BatchProcessingResult, Never>?
    let batchTranscriberPool: BatchTranscriberPool
    let audioPreparationHandler: AudioPreparationHandler

    public convenience init(appSettings: AppSettings) {
        self.init(appSettings: appSettings, batchTranscriberPool: nil)
    }

    init(
        appSettings: AppSettings,
        batchTranscriberPool: BatchTranscriberPool?,
        audioPreparationHandler: AudioPreparationHandler? = nil
    ) {
        self.appSettings = appSettings
        let config = AppConfig.load()
        self.outputFormat = config.outputFormat
        if !config.defaultExportPath.isEmpty {
            self.outputDirectory = URL(fileURLWithPath: config.defaultExportPath)
        }
        self.batchTranscriberPool = batchTranscriberPool ?? Self.makeDefaultBatchTranscriberPool(config: config)
        self.audioPreparationHandler = audioPreparationHandler ?? Self.defaultAudioPreparation
    }

    public func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = BatchMode.supportedExtensions.compactMap {
            .init(filenameExtension: $0)
        }
        guard panel.runModal() == .OK else { return }
        enqueueInputFiles(panel.urls)
    }

    public func enqueueInputFiles(_ urls: [URL]) {
        let supportedURLs = urls
            .map(\.standardizedFileURL)
            .filter { BatchMode.supportedExtensions.contains($0.pathExtension.lowercased()) }

        guard !supportedURLs.isEmpty else { return }

        var existingURLs = Set(queue.map(\.inputURL.standardizedFileURL))
        let newItems = supportedURLs.compactMap { url -> BatchQueueItem? in
            guard !existingURLs.contains(url) else {
                return nil
            }
            existingURLs.insert(url)
            return BatchQueueItem(inputURL: url)
        }

        guard !newItems.isEmpty else { return }

        queue.append(contentsOf: newItems)
        processingWarning = nil
        state = .idle
        syncPrimaryInputURL()
    }

    func removeQueueItem(_ id: BatchQueueItem.ID) {
        guard currentTask == nil else { return }
        queue.removeAll { $0.id == id }
        if activeQueueItemID == id {
            activeQueueItemID = nil
        }
        syncPrimaryInputURL()
        if queue.isEmpty {
            state = .idle
        }
    }
    
    public func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    public func transcribe() {
        guard currentTask == nil else { return }
        let processableItemIDs = queue
            .filter { $0.status.isRetryable }
            .map(\.id)
        guard !processableItemIDs.isEmpty else { return }

        processingWarning = nil
        lastExecutionMetrics = nil
        prepareForUse()
        if let issue = appSettings.readiness.primaryIssueForBatch(batchPrompt: batchPostPrompt) {
            withAnimation(AnimationConfig.standard) {
                state = .error(issue.message)
            }
            return
        }

        for itemID in processableItemIDs {
            updateQueueItemStatus(itemID, status: .pending)
        }
        currentTask = Task {
            await runQueueTask(itemIDs: processableItemIDs)
        }
    }
}
