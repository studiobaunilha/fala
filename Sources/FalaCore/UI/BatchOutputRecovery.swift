import Foundation

struct BatchRetainedTranscript: Equatable, Sendable {
    let text: String
    let warning: BatchProcessingWarning?
}

struct BatchWindowProcessingOutcome: Sendable {
    let text: String
    let warning: BatchProcessingWarning?
    let saveErrorDescription: String?
}

struct BatchProcessingResult: Sendable {
    var fullConfirmedText = ""
    var warning: BatchProcessingWarning?
    var saveErrorDescription: String?

    mutating func append(_ outcome: BatchWindowProcessingOutcome) {
        fullConfirmedText += outcome.text + "\n"
        warning = warning ?? outcome.warning
        saveErrorDescription = saveErrorDescription ?? outcome.saveErrorDescription
    }
}

struct BatchOutputSaveError: LocalizedError {
    let detail: String

    var errorDescription: String? {
        String(format: L10n("Não foi possível salvar a transcrição. Detalhe: %@"), detail)
    }
}
