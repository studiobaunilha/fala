import Foundation
import MLXLLM

public enum MLXCatalogRuntimeKind: String, Codable, Sendable {
    case llm
}

public enum MLXModelFamily: String, Codable, CaseIterable, Sendable {
    case qwen
    case gemma
    case liquid
    case legacy

    public var title: String {
        switch self {
        case .qwen:
            "Qwen"
        case .gemma:
            "Gemma"
        case .liquid:
            "Liquid"
        case .legacy:
            L10n("Legacy")
        }
    }

    var sortOrder: Int {
        switch self {
        case .qwen:
            0
        case .gemma:
            1
        case .liquid:
            2
        case .legacy:
            3
        }
    }
}

public enum MLXHardwareClass: String, Codable, CaseIterable, Sendable {
    case compact
    case balanced
    case pro

    public static func detect(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory) -> MLXHardwareClass {
        let gigabytes = Int(physicalMemory / 1_073_741_824)
        switch gigabytes {
        case ..<24:
            return .compact
        case 24..<36:
            return .balanced
        default:
            return .pro
        }
    }

    public var title: String {
        switch self {
        case .compact:
            L10n("Compacto")
        case .balanced:
            L10n("Balanceado")
        case .pro:
            "Pro"
        }
    }

    public var subtitle: String {
        switch self {
        case .compact:
            L10n("Ideal para Macs com menos de 24 GB de memória unificada.")
        case .balanced:
            L10n("Ideal para Macs com 24 GB a 35 GB de memória unificada.")
        case .pro:
            L10n("Ideal para Macs com 36 GB ou mais de memória unificada.")
        }
    }

    public var shortDescription: String {
        switch self {
        case .compact:
            L10n("Menos de 24 GB")
        case .balanced:
            L10n("24 GB a 35 GB")
        case .pro:
            L10n("36 GB ou mais")
        }
    }
}

public struct MLXCatalogManifest: Codable, Sendable {
    public let entries: [MLXCatalogEntry]
}

public struct MLXCatalogEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let repoID: String
    public let displayName: String
    public let family: MLXModelFamily
    public let summary: String
    public let quantizationLabel: String
    public let estimatedDownloadSize: String
    public let minimumUnifiedMemoryGB: Int
    public let recommendedHardwareClasses: [MLXHardwareClass]
    public let selectionPriority: Int
    public let isRecommended: Bool
    public let runtimeKind: MLXCatalogRuntimeKind
    public let legacyAliases: [String]
    public let replacementID: String?

    public var isLegacy: Bool {
        family == .legacy
    }
}

public struct MLXCatalogValidationResult: Equatable, Sendable {
    public let entries: [MLXCatalogEntry]
    public let warnings: [String]
    public let usedFallback: Bool
}

public struct MLXCatalogSection: Identifiable, Equatable, Sendable {
    public let family: MLXModelFamily
    public let entries: [MLXCatalogEntry]

    public var id: String {
        family.rawValue
    }

    public var title: String {
        family.title
    }
}

public struct MLXCatalogSelectionSummary: Equatable, Sendable {
    public let entry: MLXCatalogEntry
    public let isDownloaded: Bool
    public let isIdealForCurrentMac: Bool
    public let hardwareClassTitle: String
}

public struct MLXCatalogMigrationNotice: Equatable, Sendable {
    public let title: String
    public let message: String
}

public enum MLXCatalogSelectionStatus: Equatable, Sendable {
    case supported
    case migrated
    case unsupported
}

public struct MLXCatalogSelectionResolution: Equatable, Sendable {
    public let status: MLXCatalogSelectionStatus
    public let resolvedRepoID: String
    public let entry: MLXCatalogEntry?
    public let migrationNotice: MLXCatalogMigrationNotice?
}

public struct MLXCatalogConfigNormalization: Equatable, Sendable {
    public let config: AppConfig
    public let migrationNotice: MLXCatalogMigrationNotice?
    public let didChange: Bool
}

enum MLXCatalogValidationError: LocalizedError, Equatable {
    case duplicateID(String)
    case duplicateRepoID(String)
    case invalidReplacement(String)
    case invalidRuntimeKind(String)
    case unsupportedRepo(String)
    case unverifiedRecommended(String)

    var errorDescription: String? {
        switch self {
        case .duplicateID(let id):
            return "Duplicate MLX catalog entry id: \(id)"
        case .duplicateRepoID(let repoID):
            return "Duplicate MLX catalog repo id: \(repoID)"
        case .invalidReplacement(let id):
            return "Invalid MLX catalog replacement id: \(id)"
        case .invalidRuntimeKind(let repoID):
            return "Unsupported MLX runtime kind for repo: \(repoID)"
        case .unsupportedRepo(let repoID):
            return "Unsupported MLX repo for current runtime: \(repoID)"
        case .unverifiedRecommended(let repoID):
            return "Recommended MLX repo is not smoke verified: \(repoID)"
        }
    }
}

enum MLXCatalogManifestLoader {
    static let smokeVerifiedRecommendedRepoIDs: Set<String> = [
        "mlx-community/Qwen3-4B-4bit",
        "mlx-community/gemma-3-text-4b-it-4bit",
        "mlx-community/LFM2-1.2B-4bit"
    ]

    static let fallbackEntries: [MLXCatalogEntry] = [
        MLXCatalogEntry(
            id: "qwen3-4b-4bit",
            repoID: "mlx-community/Qwen3-4B-4bit",
            displayName: "Qwen 3 4B",
            family: .qwen,
            summary: "Opção compacta e equilibrada para pós-processamento local.",
            quantizationLabel: "4-bit",
            estimatedDownloadSize: "~2.6 GB",
            minimumUnifiedMemoryGB: 8,
            recommendedHardwareClasses: [.compact, .balanced],
            selectionPriority: 10,
            isRecommended: true,
            runtimeKind: .llm,
            legacyAliases: ["mlx-community/Qwen2.5-3B-Instruct-4bit"],
            replacementID: nil
        ),
        MLXCatalogEntry(
            id: "llama3.2-3b-legacy",
            repoID: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            displayName: "Llama 3.2 3B",
            family: .legacy,
            summary: "Compatibilidade para instalações existentes.",
            quantizationLabel: "4-bit",
            estimatedDownloadSize: "~2.0 GB",
            minimumUnifiedMemoryGB: 8,
            recommendedHardwareClasses: [.compact],
            selectionPriority: 200,
            isRecommended: false,
            runtimeKind: .llm,
            legacyAliases: [],
            replacementID: nil
        ),
        MLXCatalogEntry(
            id: "llama3.1-8b-legacy",
            repoID: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            displayName: "Llama 3.1 8B",
            family: .legacy,
            summary: "Compatibilidade para instalações existentes.",
            quantizationLabel: "4-bit",
            estimatedDownloadSize: "~4.8 GB",
            minimumUnifiedMemoryGB: 16,
            recommendedHardwareClasses: [.balanced, .pro],
            selectionPriority: 210,
            isRecommended: false,
            runtimeKind: .llm,
            legacyAliases: [],
            replacementID: nil
        )
    ]

    private static let runtimeSupportMarkers: [MLXModelFamily: [String]] = [
        .qwen: [
            "mlx-community/Qwen3-4B-4bit"
        ],
        .gemma: [
            "mlx-community/gemma-3-1b-it-qat-4bit"
        ],
        .liquid: [
            "mlx-community/LFM2-1.2B-4bit"
        ],
        .legacy: [
            "mlx-community/Llama-3.2-3B-Instruct-4bit",
            "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"
        ]
    ]

    static func load(bundle: Bundle = .module) -> MLXCatalogValidationResult {
        guard let url = bundle.url(forResource: "MLXCatalog", withExtension: "json") else {
            return fallbackResult(warning: "Missing bundled MLX catalog manifest.")
        }

        do {
            let data = try Data(contentsOf: url)
            return try load(data: data)
        } catch {
            return fallbackResult(warning: error.localizedDescription)
        }
    }

    static func load(data: Data) throws -> MLXCatalogValidationResult {
        let manifest = try JSONDecoder().decode(MLXCatalogManifest.self, from: data)
        return try validate(manifest: manifest)
    }

    static func validate(manifest: MLXCatalogManifest) throws -> MLXCatalogValidationResult {
        var ids = Set<String>()
        var repoIDs = Set<String>()
        let entries = manifest.entries.sorted {
            if $0.family.sortOrder == $1.family.sortOrder {
                return $0.selectionPriority < $1.selectionPriority
            }
            return $0.family.sortOrder < $1.family.sortOrder
        }

        for entry in entries {
            guard ids.insert(entry.id).inserted else {
                throw MLXCatalogValidationError.duplicateID(entry.id)
            }
            guard repoIDs.insert(entry.repoID).inserted else {
                throw MLXCatalogValidationError.duplicateRepoID(entry.repoID)
            }
            guard entry.runtimeKind == .llm else {
                throw MLXCatalogValidationError.invalidRuntimeKind(entry.repoID)
            }
            guard supportsRuntime(for: entry) else {
                throw MLXCatalogValidationError.unsupportedRepo(entry.repoID)
            }
            if entry.isRecommended && !smokeVerifiedRecommendedRepoIDs.contains(entry.repoID) {
                throw MLXCatalogValidationError.unverifiedRecommended(entry.repoID)
            }
        }

        let knownIDs = Set(entries.map(\.id))
        for entry in entries {
            guard let replacementID = entry.replacementID else {
                continue
            }
            guard replacementID != entry.id, knownIDs.contains(replacementID) else {
                throw MLXCatalogValidationError.invalidReplacement(replacementID)
            }
        }

        return MLXCatalogValidationResult(entries: entries, warnings: [], usedFallback: false)
    }

    private static func fallbackResult(warning: String) -> MLXCatalogValidationResult {
        NSLog("[Fala] MLX catalog manifest fallback: %@", warning)
        return MLXCatalogValidationResult(
            entries: fallbackEntries,
            warnings: [warning],
            usedFallback: true
        )
    }

    private static func supportsRuntime(for entry: MLXCatalogEntry) -> Bool {
        if LLMRegistry.shared.contains(id: entry.repoID) {
            return true
        }

        guard let markers = runtimeSupportMarkers[entry.family],
              markers.contains(where: { LLMRegistry.shared.contains(id: $0) })
        else {
            return false
        }

        switch entry.family {
        case .qwen:
            return entry.repoID.contains("/Qwen3-")
        case .gemma:
            return entry.repoID.lowercased().contains("/gemma-3-text-")
        case .liquid:
            return entry.repoID.contains("/LFM2-")
        case .legacy:
            return entry.repoID.contains("/Llama-") || entry.repoID.contains("/Meta-Llama-")
        }
    }
}
