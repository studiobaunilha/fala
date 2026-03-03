import Foundation
import MLXLMCommon
import MLXLLM

// MARK: - Known MLX Models

public struct MLXModelInfo: Identifiable, Sendable {
    public let id: String
    public let repoID: String
    public let label: String
    public let estimatedSize: String
}

// swiftlint:disable trailing_comma
public let knownMLXModels: [MLXModelInfo] = [
    MLXModelInfo(
        id: "qwen2.5-3b",
        repoID: "mlx-community/Qwen2.5-3B-Instruct-4bit",
        label: "Qwen 2.5 3B",
        estimatedSize: "~2 GB"
    ),
    MLXModelInfo(
        id: "llama3.2-3b",
        repoID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
        label: "Llama 3.2 3B",
        estimatedSize: "~2 GB"
    ),
    MLXModelInfo(
        id: "llama3.1-8b",
        repoID: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
        label: "Llama 3.1 8B",
        estimatedSize: "~5 GB"
    ),
]
// swiftlint:enable trailing_comma

// MARK: - MLX Model Manager

/// Manages MLX LLM model lifecycle: scan cache, download, delete.
@MainActor
public final class MLXModelManager: ObservableObject {

    /// Repo IDs found in the local HuggingFace cache.
    @Published public var localModels: Set<String> = []

    /// Download progress per short model id (0.0–1.0).
    @Published public var downloads: [String: Double] = [:]

    /// Loading status message per short model id.
    @Published public var loadingStatus: [String: String] = [:]

    /// Root of the HuggingFace Hub cache.
    public static let cacheDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub")
    }()

    public init() {
        scanLocal()
    }

    // MARK: - Scan

    /// Scans the HuggingFace cache for downloaded MLX models.
    public func scanLocal() {
        localModels = Self.scanCache(Self.cacheDir, knownModels: knownMLXModels)
    }

    /// Returns repo IDs of known models present in the cache.
    static func scanCache(_ cacheDir: URL, knownModels: [MLXModelInfo]) -> Set<String> {
        let fm = FileManager.default
        var found: Set<String> = []
        for model in knownModels {
            let dirName = "models--" + model.repoID.replacingOccurrences(of: "/", with: "--")
            let modelDir = cacheDir.appendingPathComponent(dirName)
            let snapshotsDir = modelDir.appendingPathComponent("snapshots")
            // Model is downloaded if snapshots directory exists with content
            if let snapshots = try? fm.contentsOfDirectory(
                at: snapshotsDir,
                includingPropertiesForKeys: nil
            ), !snapshots.isEmpty {
                found.insert(model.repoID)
            }
        }
        return found
    }

    // MARK: - Query

    /// Whether a model (by short id) is downloaded locally.
    public func isDownloaded(_ shortId: String) -> Bool {
        guard let info = knownMLXModels.first(where: { $0.id == shortId }) else {
            return false
        }
        return localModels.contains(info.repoID)
    }

    /// Returns the repo ID for a short id.
    public func repoID(for shortId: String) -> String? {
        knownMLXModels.first(where: { $0.id == shortId })?.repoID
    }

    // MARK: - Download

    /// Downloads a model. Uses loadModel which auto-downloads from Hub.
    public func download(_ shortId: String) {
        guard !downloads.keys.contains(shortId) else { return }
        guard let info = knownMLXModels.first(where: { $0.id == shortId }) else { return }
        downloads[shortId] = 0.0
        loadingStatus[shortId] = "Preparando download..."

        let repoID = info.repoID
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

        // Download in detached task.
        Task.detached {
            do {
                _ = try await loadModel(id: repoID) { progress in
                    let fraction = progress.fractionCompleted
                    continuation.yield(fraction)
                }
                continuation.finish()
            } catch {
                NSLog("[Sussurro] MLX download failed for %@: %@",
                      shortId, error.localizedDescription)
                continuation.finish()
            }
        }
    }

    // MARK: - Delete

    /// Deletes a downloaded model from the HuggingFace cache.
    public func delete(_ shortId: String) throws {
        guard let info = knownMLXModels.first(where: { $0.id == shortId }) else { return }
        let dirName = "models--" + info.repoID.replacingOccurrences(of: "/", with: "--")
        let dir = Self.cacheDir.appendingPathComponent(dirName)
        try FileManager.default.removeItem(at: dir)
        // Evict from in-memory cache
        Task {
            await MLXModelCache.shared.evict(info.repoID)
        }
        scanLocal()
    }

    /// Calculates the on-disk size of a downloaded model.
    public func diskSize(for shortId: String) -> String? {
        guard let info = knownMLXModels.first(where: { $0.id == shortId }) else { return nil }
        let dirName = "models--" + info.repoID.replacingOccurrences(of: "/", with: "--")
        let dir = Self.cacheDir.appendingPathComponent(dirName)
        guard let bytes = Self.directorySize(dir) else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
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
        let context = try await getOrLoad(repoID)
        // ChatSession is not Sendable; nonisolated(unsafe) is safe here
        // because we create and consume it within this single call.
        nonisolated(unsafe) let session = ChatSession(
            context, instructions: systemPrompt
        )
        return try await session.respond(to: userText)
    }

    /// Returns a loaded model, using the cache when available.
    private func getOrLoad(_ repoID: String) async throws -> ModelContext {
        if let hit = cache[repoID] { return hit }
        let context = try await loadModel(id: repoID)
        cache[repoID] = context
        return context
    }

    /// Removes a model from the in-memory cache.
    public func evict(_ repoID: String) {
        cache.removeValue(forKey: repoID)
    }
}
