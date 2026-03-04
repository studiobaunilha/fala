import Foundation

public enum AudioError: Error, LocalizedError {
    case engineStartFailed
    case noRecording
    case invalidFormat
    case conversionFailed
    case bufferAllocationFailed

    public var errorDescription: String? {
        switch self {
        case .engineStartFailed: L10n("Failed to start audio engine")
        case .noRecording: L10n("No active recording to stop")
        case .invalidFormat: L10n("Could not create target audio format")
        case .conversionFailed: L10n("Audio conversion failed")
        case .bufferAllocationFailed: L10n("Could not allocate audio buffer")
        }
    }
}

public enum TranscriberError: Error, LocalizedError {
    case notLoaded
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .notLoaded: L10n("Transcriber model is not loaded")
        case .emptyResult: L10n("Transcription returned no text")
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
            String(format: L10n("Chave API não configurada para %@"), provider)
        case .providerNotConfigured(let provider):
            String(format: L10n("Provedor '%@' não reconhecido"), provider)
        case .appleIntelligenceUnavailable:
            L10n("Apple Intelligence requer macOS Tahoe (26+)")
        case .appleIntelligenceNotEnabled:
            L10n("Apple Intelligence não está ativado nas Preferências do Sistema")
        case .deviceNotEligible:
            L10n("Este dispositivo não suporta Apple Intelligence")
        case .appleIntelligenceModelNotReady:
            L10n("Modelo Apple Intelligence ainda sendo baixado")
        case .mlxModelNotLoaded(let modelID):
            String(format: L10n("Não foi possível carregar o modelo local '%@'"), modelID)
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
        case .noInputFile: L10n("No input file specified")
        case .unsupportedFormat(let ext): String(format: L10n("Unsupported format: %@"), ext)
        case .ffmpegNotFound: L10n("ffmpeg not found. Install with: brew install ffmpeg")
        case .ffmpegFailed(let code): String(format: L10n("ffmpeg exited with code %d"), code)
        case .outputWriteFailed: L10n("Failed to write output file")
        }
    }
}
