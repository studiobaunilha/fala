import Foundation

public extension AppConfig {
    var activeWhisperModel: String {
        Self.resolveActiveWhisperModel(
            dictationModel: dictationModel,
            batchModel: batchModel
        )
    }

    mutating func normalizeWhisperModelSelection() {
        let resolvedModel = activeWhisperModel
        dictationModel = resolvedModel
        batchModel = resolvedModel
    }
}

extension AppConfig {
    static func resolveActiveWhisperModel(
        dictationModel: String,
        batchModel: String
    ) -> String {
        let normalizedDictationModel = normalizeWhisperModelID(dictationModel)
        let normalizedBatchModel = normalizeWhisperModelID(batchModel)

        guard let normalizedDictationModel else {
            return normalizedBatchModel ?? defaultWhisperModelID
        }

        guard let normalizedBatchModel else {
            return normalizedDictationModel
        }

        if normalizedDictationModel == normalizedBatchModel {
            return normalizedDictationModel
        }

        if normalizedDictationModel == defaultWhisperModelID
            && normalizedBatchModel != defaultWhisperModelID {
            return normalizedBatchModel
        }

        if normalizedBatchModel == defaultWhisperModelID
            && normalizedDictationModel != defaultWhisperModelID {
            return normalizedDictationModel
        }

        if knownModels.contains(where: { $0.id == normalizedBatchModel }) {
            return normalizedBatchModel
        }

        if knownModels.contains(where: { $0.id == normalizedDictationModel }) {
            return normalizedDictationModel
        }

        return normalizedBatchModel
    }

    private static func normalizeWhisperModelID(_ modelID: String) -> String? {
        let normalizedModelID = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModelID.isEmpty, normalizedModelID != "none" else {
            return nil
        }
        return normalizedModelID
    }
}
