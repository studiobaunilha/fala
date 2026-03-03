import Foundation

public enum AudioError: Error, LocalizedError {
    case engineStartFailed
    case noRecording
    case invalidFormat
    case conversionFailed
    case bufferAllocationFailed

    public var errorDescription: String? {
        switch self {
        case .engineStartFailed: "Failed to start audio engine"
        case .noRecording: "No active recording to stop"
        case .invalidFormat: "Could not create target audio format"
        case .conversionFailed: "Audio conversion failed"
        case .bufferAllocationFailed: "Could not allocate audio buffer"
        }
    }
}

public enum TranscriberError: Error, LocalizedError {
    case notLoaded
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .notLoaded: "Transcriber model is not loaded"
        case .emptyResult: "Transcription returned no text"
        }
    }
}

public enum LLMError: Error, LocalizedError {
    case noAPIKey(provider: String)
    case providerNotConfigured(String)
    case appleIntelligenceUnavailable
    case appleIntelligenceNotEnabled
    case deviceNotEligible
    case appleIntelligenceModelNotReady
    case mlxModelNotLoaded(String)

    public var errorDescription: String? {
        switch self {
        case .noAPIKey(let provider):
            "Chave API não configurada para \(provider)"
        case .providerNotConfigured(let provider):
            "Provedor '\(provider)' não reconhecido"
        case .appleIntelligenceUnavailable:
            "Apple Intelligence requer macOS Tahoe (26+)"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence não está ativado nas Preferências do Sistema"
        case .deviceNotEligible:
            "Este dispositivo não suporta Apple Intelligence"
        case .appleIntelligenceModelNotReady:
            "Modelo Apple Intelligence ainda sendo baixado"
        case .mlxModelNotLoaded(let modelID):
            "Não foi possível carregar o modelo local '\(modelID)'"
        }
    }
}

public enum BatchError: Error, LocalizedError {
    case noInputFile
    case unsupportedFormat(String)
    case ffmpegNotFound
    case ffmpegFailed(Int32)
    case outputWriteFailed

    public var errorDescription: String? {
        switch self {
        case .noInputFile: "No input file specified"
        case .unsupportedFormat(let ext): "Unsupported format: \(ext)"
        case .ffmpegNotFound: "ffmpeg not found. Install with: brew install ffmpeg"
        case .ffmpegFailed(let code): "ffmpeg exited with code \(code)"
        case .outputWriteFailed: "Failed to write output file"
        }
    }
}
