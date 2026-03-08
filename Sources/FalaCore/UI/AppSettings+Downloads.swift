import Foundation

public struct ModelDownloadProgress: Equatable, Sendable {
    public let modelName: String
    public let fraction: Double
}

public extension AppSettings {
    func activeModelDownload(
        whisperDownloads: [String: Double]? = nil,
        mlxDownloads: [String: Double]? = nil
    ) -> ModelDownloadProgress? {
        let snapshot = snapshotConfig()
        let activeWhisperDownloads = whisperDownloads ?? modelManager.downloads
        let activeMLXDownloads = mlxDownloads ?? mlxModelManager.downloads

        if let preferredWhisper = preferredWhisperDownload(
            snapshot: snapshot,
            downloads: activeWhisperDownloads
        ) {
            return preferredWhisper
        }

        if let preferredMLX = preferredMLXDownload(
            snapshot: snapshot,
            downloads: activeMLXDownloads
        ) {
            return preferredMLX
        }

        let fallbackWhisper = fallbackWhisperDownload(from: activeWhisperDownloads)
        let fallbackMLX = fallbackMLXDownload(from: activeMLXDownloads)
        return earliestDownload(alternatives: [fallbackWhisper, fallbackMLX])
    }
}

private extension AppSettings {
    func preferredWhisperDownload(
        snapshot: AppConfig,
        downloads: [String: Double]
    ) -> ModelDownloadProgress? {
        let preferredWhisperModels = [snapshot.activeWhisperModel]
            .filter { !$0.isEmpty && $0 != "none" }

        for shortID in preferredWhisperModels {
            if let fraction = downloads[shortID] {
                let modelName = knownModels.first(where: { $0.id == shortID })?.label ?? shortID
                return ModelDownloadProgress(modelName: modelName, fraction: fraction)
            }
        }

        return nil
    }

    func preferredMLXDownload(
        snapshot: AppConfig,
        downloads: [String: Double]
    ) -> ModelDownloadProgress? {
        let effectiveModeConfig = snapshot.getEffectiveConfig(for: snapshot.selectedDictationTemplate)
        let preferredMLXRepoIDs = [
            effectiveModeConfig.provider == "mlx"
                ? (effectiveModeConfig.model.isEmpty ? snapshot.mlxModel : effectiveModeConfig.model)
                : nil,
            snapshot.mlxModel
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        for repoID in preferredMLXRepoIDs {
            if let fraction = activeDownloadFraction(forMLXRepoID: repoID, downloads: downloads) {
                return ModelDownloadProgress(
                    modelName: mlxCatalogService.label(for: repoID),
                    fraction: fraction
                )
            }
        }

        return nil
    }

    func fallbackWhisperDownload(from downloads: [String: Double]) -> ModelDownloadProgress? {
        let candidates = downloads.map { key, value in
            ModelDownloadProgress(
                modelName: knownModels.first(where: { $0.id == key })?.label ?? key,
                fraction: value
            )
        }
        return earliestDownload(alternatives: candidates)
    }

    func fallbackMLXDownload(from downloads: [String: Double]) -> ModelDownloadProgress? {
        let candidates = downloads.map { key, value in
            let repoID = resolvedMLXRepoID(forDownloadKey: key)
            return ModelDownloadProgress(
                modelName: mlxCatalogService.label(for: repoID),
                fraction: value
            )
        }
        return earliestDownload(alternatives: candidates)
    }

    func earliestDownload(alternatives: [ModelDownloadProgress?]) -> ModelDownloadProgress? {
        let resolved = alternatives.compactMap { $0 }
        return earliestDownload(alternatives: resolved)
    }

    func earliestDownload(alternatives: [ModelDownloadProgress]) -> ModelDownloadProgress? {
        alternatives.min {
            $0.modelName.localizedCaseInsensitiveCompare($1.modelName) == .orderedAscending
        }
    }

    func activeDownloadFraction(
        forMLXRepoID repoID: String,
        downloads: [String: Double]
    ) -> Double? {
        let normalizedRepoID = repoID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directMatch = downloads[normalizedRepoID] {
            return directMatch
        }

        let shortID = mlxCatalogService.entry(for: normalizedRepoID)?.id
        if let shortID, let shortMatch = downloads[shortID] {
            return shortMatch
        }

        return nil
    }

    func resolvedMLXRepoID(forDownloadKey key: String) -> String {
        if key.contains("/") {
            return key
        }
        return mlxModelManager.repoID(for: key) ?? key
    }
}
