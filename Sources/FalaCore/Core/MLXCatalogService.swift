import Foundation

public struct MLXCatalogEntry: Identifiable, Equatable, Sendable {
    public let id: String
    public let repoID: String
    public let label: String
    public let estimatedSize: String?
    public let compatibility: MLXModelCompatibility

    public init(
        id: String,
        repoID: String,
        label: String,
        estimatedSize: String?,
        compatibility: MLXModelCompatibility
    ) {
        self.id = id
        self.repoID = repoID
        self.label = label
        self.estimatedSize = estimatedSize
        self.compatibility = compatibility
    }
}

@MainActor
public final class MLXCatalogService: ObservableObject {
    @Published public var customRepoID: String = ""

    public let manager: MLXModelManager

    public static let curatedEntries: [MLXCatalogEntry] = knownMLXModels.map {
        MLXCatalogEntry(
            id: $0.id,
            repoID: $0.repoID,
            label: $0.label,
            estimatedSize: $0.estimatedSize,
            compatibility: .curated
        )
    }

    public static let suggestedCustomEntries: [MLXCatalogEntry] = [
        MLXCatalogEntry(
            id: "qwen3.5-4b-custom",
            repoID: "mlx-community/Qwen3.5-4B-MLX-4bit",
            label: "Qwen 3.5 4B",
            estimatedSize: nil,
            compatibility: .customOnly
        )
    ]

    public init(manager: MLXModelManager) {
        self.manager = manager
    }

    public var curatedModels: [MLXCatalogEntry] {
        Self.curatedEntries
    }

    public var suggestedCustomModels: [MLXCatalogEntry] {
        Self.suggestedCustomEntries
    }

    public func normalizedCustomRepoID() -> String? {
        let normalized = customRepoID.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    public func useSuggestedCustom(_ entry: MLXCatalogEntry) {
        customRepoID = entry.repoID
    }

    public func isDownloaded(repoID: String) -> Bool {
        manager.isDownloaded(repoID: repoID)
    }

    public func diskSize(repoID: String) -> String? {
        manager.diskSize(repoID: repoID)
    }
}
