import Foundation

@MainActor
public final class MLXCatalogService: ObservableObject {
    @Published public private(set) var validationResult: MLXCatalogValidationResult
    @Published public private(set) var currentHardwareClass: MLXHardwareClass

    public let manager: MLXModelManager

    public init(
        manager: MLXModelManager,
        hardwareClass: MLXHardwareClass? = nil,
        manifestLoader: (() -> MLXCatalogValidationResult)? = nil
    ) {
        self.manager = manager
        self.currentHardwareClass = hardwareClass ?? MLXHardwareClass.detect()
        let loadManifest = manifestLoader ?? { MLXCatalogManifestLoader.load() }
        self.validationResult = loadManifest()
        manager.updateCatalogEntries(validationResult.entries)
    }

    public var entries: [MLXCatalogEntry] {
        validationResult.entries
    }

    public var validationWarnings: [String] {
        validationResult.warnings
    }

    public var usedFallbackCatalog: Bool {
        validationResult.usedFallback
    }

    public var defaultSelectionRepoID: String {
        fallbackSelection(excluding: nil) ?? AppConfig.defaultMLXModelRepoID
    }

    public func sections(selectedRepoID: String? = nil) -> [MLXCatalogSection] {
        let normalizedSelection = selectedRepoID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldShowLegacy = entries.contains(where: {
            $0.isLegacy && (
                $0.repoID == normalizedSelection
                    || manager.isDownloaded(repoID: $0.repoID)
            )
        })

        let grouped = Dictionary(grouping: entries) { $0.family }
        return MLXModelFamily.allCases.compactMap { family in
            guard let familyEntries = grouped[family] else {
                return nil
            }
            if family == .legacy && !shouldShowLegacy {
                return nil
            }

            let sortedEntries = familyEntries.sorted {
                if isIdealForCurrentMac($0) == isIdealForCurrentMac($1) {
                    return $0.selectionPriority < $1.selectionPriority
                }
                return isIdealForCurrentMac($0) && !isIdealForCurrentMac($1)
            }
            return MLXCatalogSection(family: family, entries: sortedEntries)
        }
    }

    public func entry(for repoID: String) -> MLXCatalogEntry? {
        let normalized = repoID.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.first(where: { $0.repoID == normalized })
    }

    public func label(for repoID: String) -> String {
        let resolution = resolveSelection(repoID: repoID)
        if let entry = resolution.entry {
            return entry.displayName
        }
        return manager.label(for: resolution.resolvedRepoID)
    }

    public func isDownloaded(repoID: String) -> Bool {
        manager.isDownloaded(repoID: repoID)
    }

    public func diskSize(repoID: String) -> String? {
        manager.diskSize(repoID: repoID)
    }

    public func supports(repoID: String) -> Bool {
        resolveSelection(repoID: repoID).status != .unsupported
    }

    public func isIdealForCurrentMac(_ entry: MLXCatalogEntry) -> Bool {
        entry.recommendedHardwareClasses.contains(currentHardwareClass)
    }

    public func selectionSummary(for repoID: String) -> MLXCatalogSelectionSummary? {
        let resolution = resolveSelection(repoID: repoID)
        guard let entry = resolution.entry else {
            return nil
        }
        return MLXCatalogSelectionSummary(
            entry: entry,
            isDownloaded: isDownloaded(repoID: entry.repoID),
            isIdealForCurrentMac: isIdealForCurrentMac(entry),
            hardwareClassTitle: currentHardwareClass.title
        )
    }

    public func resolveSelection(repoID: String) -> MLXCatalogSelectionResolution {
        let normalized = repoID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            let fallbackRepoID = defaultSelectionRepoID
            let fallbackEntry = entry(for: fallbackRepoID)
            return MLXCatalogSelectionResolution(
                status: .supported,
                resolvedRepoID: fallbackRepoID,
                entry: fallbackEntry,
                migrationNotice: nil
            )
        }

        if let exactEntry = entry(for: normalized) {
            if let replacementID = exactEntry.replacementID,
               let replacement = entries.first(where: { $0.id == replacementID }) {
                return MLXCatalogSelectionResolution(
                    status: .migrated,
                    resolvedRepoID: replacement.repoID,
                    entry: replacement,
                    migrationNotice: migrationNotice(from: exactEntry, to: replacement)
                )
            }

            return MLXCatalogSelectionResolution(
                status: .supported,
                resolvedRepoID: exactEntry.repoID,
                entry: exactEntry,
                migrationNotice: nil
            )
        }

        if let migratedEntry = entries.first(where: { $0.legacyAliases.contains(normalized) }) {
            return MLXCatalogSelectionResolution(
                status: .migrated,
                resolvedRepoID: migratedEntry.repoID,
                entry: migratedEntry,
                migrationNotice: migrationNotice(fromRepoID: normalized, to: migratedEntry)
            )
        }

        return MLXCatalogSelectionResolution(
            status: .unsupported,
            resolvedRepoID: normalized,
            entry: nil,
            migrationNotice: nil
        )
    }

    public func normalize(config: AppConfig) -> MLXCatalogConfigNormalization {
        var normalized = config
        var migrationMessages: [String] = []

        if normalized.mlxModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.mlxModel = defaultSelectionRepoID
        }

        let globalResolution = resolveSelection(repoID: normalized.mlxModel)
        if globalResolution.status == .migrated {
            normalized.mlxModel = globalResolution.resolvedRepoID
            if let message = globalResolution.migrationNotice?.message {
                migrationMessages.append(message)
            }
        }

        for key in normalized.modeConfigs.keys.sorted() {
            guard var modeConfig = normalized.modeConfigs[key],
                  let model = modeConfig.model,
                  !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                continue
            }

            let resolution = resolveSelection(repoID: model)
            guard resolution.status == .migrated else {
                continue
            }

            modeConfig.model = resolution.resolvedRepoID
            normalized.modeConfigs[key] = modeConfig
            if let message = resolution.migrationNotice?.message,
               !migrationMessages.contains(message) {
                migrationMessages.append(message)
            }
        }

        let notice = migrationMessages.isEmpty ? nil : MLXCatalogMigrationNotice(
            title: L10n("Catálogo MLX atualizado"),
            message: migrationMessages.joined(separator: "\n")
        )

        return MLXCatalogConfigNormalization(
            config: normalized,
            migrationNotice: notice,
            didChange: normalized != config
        )
    }

    public func fallbackSelection(excluding repoID: String?) -> String? {
        let normalizedExclusion = repoID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = entries
            .filter { !$0.isLegacy && $0.repoID != normalizedExclusion }
            .sorted { $0.selectionPriority < $1.selectionPriority }
            .first
        if let preferred {
            return preferred.repoID
        }
        return entries.first(where: { $0.repoID != normalizedExclusion })?.repoID
    }

    public func reloadCatalog(
        hardwareClass: MLXHardwareClass? = nil,
        manifestLoader: (() -> MLXCatalogValidationResult)? = nil
    ) {
        currentHardwareClass = hardwareClass ?? MLXHardwareClass.detect()
        let loadManifest = manifestLoader ?? { MLXCatalogManifestLoader.load() }
        validationResult = loadManifest()
        manager.updateCatalogEntries(validationResult.entries)
    }
}

private extension MLXCatalogService {
    func migrationNotice(from source: MLXCatalogEntry, to destination: MLXCatalogEntry) -> MLXCatalogMigrationNotice {
        MLXCatalogMigrationNotice(
            title: L10n("Modelo MLX migrado"),
            message: String(
                format: L10n("O modelo %@ foi substituído por %@ para manter compatibilidade com o catálogo atual."),
                source.displayName,
                destination.displayName
            )
        )
    }

    func migrationNotice(
        fromRepoID sourceRepoID: String,
        to destination: MLXCatalogEntry
    ) -> MLXCatalogMigrationNotice {
        MLXCatalogMigrationNotice(
            title: L10n("Modelo MLX migrado"),
            message: String(
                format: L10n("A seleção antiga %@ foi migrada para %@."),
                sourceRepoID,
                destination.displayName
            )
        )
    }
}
