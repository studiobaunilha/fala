import Foundation

public struct MLXSmokeMode {
    public typealias AvailableModelsResolver = @Sendable ([String]) async -> [String]
    public typealias Generator =
        @Sendable (_ modelID: String, _ prompt: String, _ text: String) async throws -> String
    public typealias Logger = @Sendable (String) -> Void

    static let defaultPrompt = "You are a concise assistant. Answer in one sentence."
    static let defaultInput = "What is the capital of France?"

    let candidateModels: [String]
    let resolveAvailableModels: AvailableModelsResolver
    let generate: Generator
    let logger: Logger

    public init() {
        self.init(
            candidateModels: Array(MLXCatalogManifestLoader.smokeVerifiedRecommendedRepoIDs)
                .sorted(),
            resolveAvailableModels: Self.defaultAvailableModels,
            generate: Self.defaultGenerate,
            logger: { print($0) }
        )
    }

    init(
        candidateModels: [String],
        resolveAvailableModels: @escaping AvailableModelsResolver,
        generate: @escaping Generator,
        logger: @escaping Logger
    ) {
        self.candidateModels = candidateModels
        self.resolveAvailableModels = resolveAvailableModels
        self.generate = generate
        self.logger = logger
    }

    public func run(arguments: [String] = []) async throws {
        guard arguments.isEmpty else {
            throw MLXSmokeModeError.unsupportedArguments(arguments)
        }

        let availableModels = await resolveAvailableModels(candidateModels)
        guard !availableModels.isEmpty else {
            throw MLXSmokeModeError.noLocalModels(candidateModels)
        }

        logger("MLX smoke: validating \(availableModels.count) local model(s).")

        for modelID in availableModels {
            logger("MLX smoke: running \(modelID)")
            let output = try await generate(modelID, Self.defaultPrompt, Self.defaultInput)
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MLXSmokeModeError.emptyResponse(modelID)
            }
            logger("MLX smoke: ok \(modelID)")
        }
    }
}

extension MLXSmokeMode {
    static func defaultAvailableModels(_ candidateModels: [String]) async -> [String] {
        var available: [String] = []
        for modelID in candidateModels {
            let modelDir = await MLXModelManager.modelDir(for: modelID)
            if MLXModelManager.isUsableModelDirectory(modelDir) {
                available.append(modelID)
            }
        }
        return available
    }

    static func defaultGenerate(
        modelID: String,
        prompt: String,
        text: String
    ) async throws -> String {
        try MLXRuntimeSupport.ensureRuntimeAvailable()
        return try await MLXModelCache.shared.generate(
            repoID: modelID,
            systemPrompt: prompt,
            userText: text
        )
    }
}

enum MLXSmokeModeError: LocalizedError, Equatable {
    case unsupportedArguments([String])
    case noLocalModels([String])
    case emptyResponse(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedArguments(let arguments):
            return "MLX smoke does not accept arguments: \(arguments.joined(separator: " "))"
        case .noLocalModels(let candidateModels):
            return """
            No local MLX smoke model is available. Download at least one of: \
            \(candidateModels.joined(separator: ", "))
            """
        case .emptyResponse(let modelID):
            return "MLX smoke returned an empty response for \(modelID)."
        }
    }
}
