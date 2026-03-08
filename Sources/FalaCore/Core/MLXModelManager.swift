import Foundation
import Hub
import MLXLMCommon
import MLXLLM

public struct MLXModelInfo: Identifiable, Sendable {
    public let id: String
    public let repoID: String
    public let label: String
    public let estimatedSize: String
}

// MARK: - MLX Model Manager

/// Manages MLX LLM model lifecycle: scan cache, download, delete.
@MainActor
public final class MLXModelManager: ObservableObject {
    @Published public private(set) var catalogEntries: [MLXCatalogEntry] = []

    /// Repo IDs found in the local cache.
    @Published public var localModels: Set<String> = []

    /// Download progress per short model id (0.0–1.0).
    @Published public var downloads: [String: Double] = [:]

    /// Loading status message per short model id.
    @Published public var loadingStatus: [String: String] = [:]

    /// Error status per short model id (shown in UI when download fails).
    @Published public var downloadErrors: [String: String] = [:]

    /// Shared HubApi instance — all download, scan and load operations use
    /// the same base directory to avoid path mismatches.
    static let hub: HubApi = defaultHubApi

    /// Model directory for a given repo ID, consistent with HubApi.snapshot.
    static func modelDir(for repoID: String) -> URL {
        let repo = Hub.Repo(id: repoID)
        return hub.localRepoLocation(repo)
    }

    nonisolated static func isUsableModelDirectory(_ directory: URL) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let hasConfig = files.contains(where: { $0.lastPathComponent == "config.json" })
        let hasWeights = files.contains(where: { $0.pathExtension == "safetensors" })
        return hasConfig && hasWeights
    }

    public init() {
        scanLocal()
    }

    public func updateCatalogEntries(_ entries: [MLXCatalogEntry]) {
        catalogEntries = entries.sorted { lhs, rhs in
            if lhs.family.sortOrder == rhs.family.sortOrder {
                return lhs.selectionPriority < rhs.selectionPriority
            }
            return lhs.family.sortOrder < rhs.family.sortOrder
        }
        scanLocal()
    }

    public static func isRepoDownloaded(_ repoID: String) -> Bool {
        let dir = modelDir(for: repoID)
        return isUsableModelDirectory(dir)
    }

    // MARK: - Scan

    /// Scans for downloaded MLX models using the same HubApi paths.
    public func scanLocal() {
        localModels = Self.scanDownloaded(knownModels: catalogEntries)
    }

    /// Returns repo IDs of known models present locally.
    static func scanDownloaded(knownModels: [MLXCatalogEntry]) -> Set<String> {
        var found: Set<String> = []
        for model in knownModels {
            let dir = modelDir(for: model.repoID)
            if isUsableModelDirectory(dir) {
                found.insert(model.repoID)
            }
        }
        return found
    }

    // MARK: - Query

    /// Whether a model (by short id) is downloaded locally.
    public func isDownloaded(_ shortId: String) -> Bool {
        guard let info = catalogEntries.first(where: { $0.id == shortId }) else {
            return false
        }
        return localModels.contains(info.repoID)
    }

    public func isDownloaded(repoID: String) -> Bool {
        localModels.contains(repoID) || Self.isRepoDownloaded(repoID)
    }

    /// Returns the repo ID for a short id.
    public func repoID(for shortId: String) -> String? {
        catalogEntries.first(where: { $0.id == shortId })?.repoID
    }

    // MARK: - Download

    /// Downloads a model. Uses downloadModel which only fetches files
    /// without loading weights into memory (avoids OOM crashes).
    public func download(_ shortId: String) {
        guard !downloads.keys.contains(shortId) else { return }
        guard let info = catalogEntries.first(where: { $0.id == shortId }) else { return }
        download(repoID: info.repoID, shortID: shortId)
    }

    public func download(repoID: String, shortID overrideShortID: String? = nil) {
        let shortId = overrideShortID
            ?? catalogEntries.first(where: { $0.repoID == repoID })?.id
            ?? repoID
        downloads[shortId] = 0.0
        downloadErrors.removeValue(forKey: shortId)
        loadingStatus[shortId] = L10n("Preparando download...")
        let (stream, continuation) = AsyncStream<Double>.makeStream()

        // Watch progress on MainActor.
        Task { [weak self] in
            for await fraction in stream {
                self?.downloads[shortId] = fraction
            }
            self?.downloads.removeValue(forKey: shortId)
            self?.loadingStatus.removeValue(forKey: shortId)
            self?.scanLocal()
        }

        // Download in detached task — only fetches files, does NOT load
        // model weights into memory (~2 GB+).
        Task.detached {
            do {
                let configuration = ModelConfiguration(id: repoID)
                let modelDirectory = try await downloadModel(
                    hub: MLXModelManager.hub, configuration: configuration
                ) { progress in
                    let fraction = progress.fractionCompleted
                    continuation.yield(fraction)
                }
                guard MLXModelManager.isUsableModelDirectory(modelDirectory) else {
                    throw LLMError.mlxModelNotDownloaded(repoID)
                }
                continuation.finish()
                NotificationCenter.default.post(
                    name: .mlxDownloadCompleted,
                    object: nil,
                    userInfo: ["repoID": repoID, "shortId": shortId]
                )
            } catch {
                NSLog(
                    "[Fala] MLX download failed for %@: %@",
                    shortId, error.localizedDescription
                )
                await MainActor.run {
                    MLXModelManager.notifyDownloadError(
                        shortId: shortId,
                        message: error.localizedDescription
                    )
                }
                continuation.finish()
            }
        }
    }

    /// Called when a download fails; updates observable state on MainActor.
    @MainActor
    private static var sharedInstance: MLXModelManager?

    @MainActor
    static func notifyDownloadError(shortId: String, message: String) {
        // Post a notification so any active MLXModelManager can pick it up
        NotificationCenter.default.post(
            name: .mlxDownloadFailed,
            object: nil,
            userInfo: ["shortId": shortId, "message": message]
        )
    }

    // MARK: - Delete

    /// Deletes a downloaded model.
    public func delete(_ shortId: String) throws {
        guard let info = catalogEntries.first(where: { $0.id == shortId }) else { return }
        try delete(repoID: info.repoID)
    }

    public func delete(repoID: String) throws {
        let dir = Self.modelDir(for: repoID)
        try FileManager.default.removeItem(at: dir)
        // Evict from in-memory cache
        Task {
            await MLXModelCache.shared.evict(repoID)
        }
        scanLocal()
    }

    /// Calculates the on-disk size of a downloaded model.
    public func diskSize(for shortId: String) -> String? {
        guard let info = catalogEntries.first(where: { $0.id == shortId }) else { return nil }
        return diskSize(repoID: info.repoID)
    }

    public func diskSize(repoID: String) -> String? {
        let dir = Self.modelDir(for: repoID)
        guard let bytes = Self.directorySize(dir) else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    public func label(for repoID: String) -> String {
        catalogEntries.first(where: { $0.repoID == repoID })?.displayName ?? repoID
    }

    public func estimatedSize(for repoID: String) -> String? {
        catalogEntries.first(where: { $0.repoID == repoID })?.estimatedDownloadSize
    }

    private static func directorySize(_ url: URL) -> UInt64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}

// MARK: - Notification

extension Notification.Name {
    static let mlxDownloadFailed = Notification.Name("mlxDownloadFailed")
    static let mlxDownloadCompleted = Notification.Name("mlxDownloadCompleted")
}

// MARK: - Model Cache (Actor)

/// Caches loaded MLX model contexts to avoid reloading on each inference call.
public actor MLXModelCache {
    public static let shared = MLXModelCache()

    private var cache: [String: ModelContext] = [:]

    /// Runs inference on a cached (or freshly loaded) model entirely within
    /// the actor, avoiding `ModelContext` crossing isolation boundaries.
    public func generate(
        repoID: String, systemPrompt: String, userText: String
    ) async throws -> String {
        try MLXRuntimeSupport.ensureRuntimeAvailable()
        let context = try await getOrLoad(repoID)
        // ChatSession is not Sendable; nonisolated(unsafe) is safe here
        // because we create and consume it within this single call.
        nonisolated(unsafe) let session = ChatSession(
            context, instructions: systemPrompt
        )
        return try await session.respond(to: userText)
    }

    public func warmup(repoID: String) async throws {
        try MLXRuntimeSupport.ensureRuntimeAvailable()
        _ = try await getOrLoad(repoID)
    }

    /// Returns a loaded model, using the cache when available.
    /// Throws `LLMError.mlxModelNotDownloaded` if the model files don't exist.
    private func getOrLoad(_ repoID: String) async throws -> ModelContext {
        if let hit = cache[repoID] { return hit }
        let modelDir = await MLXModelManager.modelDir(for: repoID)
        guard MLXModelManager.isUsableModelDirectory(modelDir) else {
            throw LLMError.mlxModelNotDownloaded(repoID)
        }
        // Load from local directory — avoids re-downloading via hub.snapshot
        let context = try await loadModel(directory: modelDir)
        cache[repoID] = context
        return context
    }

    /// Removes a model from the in-memory cache.
    public func evict(_ repoID: String) {
        cache.removeValue(forKey: repoID)
    }
}
