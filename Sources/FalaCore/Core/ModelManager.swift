import Foundation
import WhisperKit

/// Known models with human-readable metadata.
/// The `id` is the short name used in config; `variant` is the full HuggingFace directory name.
public struct ModelInfo: Identifiable, Sendable {
    public let id: String
    public let variant: String
    public let label: String
    public let estimatedSize: String
}

// Current size labels follow Argmax's public WhisperKit Core ML catalog on Hugging Face.
// swiftlint:disable trailing_comma
public let knownModels: [ModelInfo] = [
    ModelInfo(id: "tiny", variant: "openai_whisper-tiny", label: "Tiny", estimatedSize: "66 MB"),
    ModelInfo(id: "base", variant: "openai_whisper-base", label: "Base", estimatedSize: "145 MB"),
    ModelInfo(id: "small", variant: "openai_whisper-small", label: "Small", estimatedSize: "483 MB"),
    ModelInfo(id: "medium", variant: "openai_whisper-medium", label: "Medium", estimatedSize: "1.53 GB"),
    ModelInfo(
        id: "large-v3-turbo", variant: "openai_whisper-large-v3_turbo",
        label: "Large v3 Turbo", estimatedSize: "3.1 GB"
    ),
    ModelInfo(id: "large-v3", variant: "openai_whisper-large-v3", label: "Large v3", estimatedSize: "3.1 GB"),
]
// swiftlint:enable trailing_comma

/// Manages WhisperKit model lifecycle: scan local cache, download, delete.
@MainActor
public final class ModelManager: ObservableObject {

    /// Variant directory names found on disk (e.g. "openai_whisper-medium").
    @Published public var localModels: Set<String> = []

    /// Download progress per short model id (0.0–1.0). Present only while downloading.
    @Published public var downloads: [String: Double] = [:]

    /// Root of WhisperKit's HuggingFace model cache.
    public static let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
    }()

    public init() {}

    // MARK: – Scan

    /// Scans the local cache directory for downloaded models.
    /// A model is considered complete if it contains `AudioEncoder.mlmodelc`.
    public func scanLocal() {
        localModels = Self.scanDirectory(Self.cacheDir)
    }

    /// Scans a directory for model subdirectories that contain `AudioEncoder.mlmodelc`.
    /// Extracted as a static for testability.
    static func scanDirectory(_ dir: URL) -> Set<String> {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }
        var found: Set<String> = []
        for entry in entries {
            let encoder = entry.appendingPathComponent("AudioEncoder.mlmodelc")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: encoder.path, isDirectory: &isDir), isDir.boolValue {
                found.insert(entry.lastPathComponent)
            }
        }
        return found
    }

    // MARK: – Query

    /// Returns whether a model (by short id like "medium") is downloaded locally.
    public func isDownloaded(_ shortId: String) -> Bool {
        guard let info = knownModels.first(where: { $0.id == shortId }) else {
            return false
        }
        return localModels.contains(info.variant)
    }

    public func isDownloaded(variant: String) -> Bool {
        localModels.contains(variant)
    }

    /// Returns the full variant name for a short id.
    public func variantName(for shortId: String) -> String? {
        knownModels.first(where: { $0.id == shortId })?.variant
    }

    /// Calculates the on-disk size of a downloaded model.
    public func diskSize(for shortId: String) -> String? {
        guard let info = knownModels.first(where: { $0.id == shortId }) else { return nil }
        let dir = Self.cacheDir.appendingPathComponent(info.variant)
        guard let bytes = directorySize(dir) else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: – Download

    /// Downloads a model variant. Updates `downloads[shortId]` with progress.
    public func download(_ shortId: String) {
        guard !downloads.keys.contains(shortId) else { return } // already downloading
        guard let info = knownModels.first(where: { $0.id == shortId }) else { return }
        downloads[shortId] = 0.0

        // Use the full variant name (e.g. "openai_whisper-large-v3_turbo") so
        // WhisperKit's glob matching finds the correct model on HuggingFace.
        let variant = info.variant

        // AsyncStream bridges progress from the detached download task back to MainActor.
        let (stream, continuation) = AsyncStream<Double>.makeStream()

        // Watch progress on MainActor.
        Task { [weak self] in
            for await fraction in stream {
                self?.downloads[shortId] = fraction
            }
            self?.downloads.removeValue(forKey: shortId)
            self?.scanLocal()
        }

        // Download in a detached task (no actor isolation → no Sendable issues).
        Task.detached {
            do {
                _ = try await WhisperKit.download(variant: variant) { progress in
                    continuation.yield(progress.fractionCompleted)
                }
                continuation.finish()
                NotificationCenter.default.post(
                    name: .whisperModelDownloadCompleted,
                    object: nil,
                    userInfo: ["modelId": shortId, "variant": variant]
                )
            } catch {
                NSLog("[Fala] Download failed for %@: %@", shortId, error.localizedDescription)
                continuation.finish()
            }
        }
    }

    // MARK: – Delete

    /// Deletes a downloaded model from disk.
    public func delete(_ shortId: String) throws {
        guard let info = knownModels.first(where: { $0.id == shortId }) else { return }
        let dir = Self.cacheDir.appendingPathComponent(info.variant)
        try FileManager.default.removeItem(at: dir)
        scanLocal()
    }

    // MARK: – Helpers

    private func directorySize(_ url: URL) -> UInt64? {
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

extension Notification.Name {
    static let whisperModelDownloadCompleted = Notification.Name("whisperModelDownloadCompleted")
}
