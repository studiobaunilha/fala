import Foundation

enum BatchExecutionOutcome: String, Equatable, Sendable {
    case succeeded
    case cancelled
    case failed
}

enum BatchExecutionStage: String, CaseIterable, Sendable {
    case audioPreparation = "audio_preparation"
    case modelPreparation = "model_preparation"
    case transcription = "transcription"
    case postProcessing = "post_processing"
    case fileSaving = "file_saving"
}

struct BatchExecutionMetrics: Equatable, Sendable {
    let fileName: String
    let fileExtension: String
    let inputFileSize: Int64?
    let audioDuration: Double?
    let usedPostProcessing: Bool
    let audioPreparationMode: BatchAudioPreparationMode?
    let modelLoadState: TranscriberLoadState?
    let outcome: BatchExecutionOutcome
    let audioPreparation: Duration?
    let modelPreparation: Duration?
    let transcription: Duration?
    let postProcessing: Duration?
    let fileSaving: Duration?
    let total: Duration

    var humanReadableTotal: String {
        total.humanReadableText
    }

    var stageBreakdown: [(label: String, value: String)] {
        [
            ("Preparar audio", audioPreparation),
            ("Preparar modelo", modelPreparation),
            ("Transcrever", transcription),
            ("Pos-processar", postProcessing),
            ("Salvar arquivo", fileSaving)
        ].compactMap { label, duration in
            guard let duration else { return nil }
            return (label, duration.humanReadableText)
        }
    }

    var stageBreakdownTooltip: String {
        stageBreakdown
            .map { "\($0.label): \($0.value)" }
            .joined(separator: "\n")
    }

    var debugSummary: String {
        String(
            format: "file=%@ ext=%@ size=%@ duration=%@ audioMode=%@ modelState=%@ "
                + "outcome=%@ prepare=%@ model=%@ transcribe=%@ post=%@ save=%@ total=%@",
            fileName,
            fileExtension,
            inputFileSize.fileSizeText,
            audioDuration.audioDurationText,
            audioPreparationMode?.rawValue ?? "n/a",
            modelLoadState?.rawValue ?? "n/a",
            outcome.rawValue,
            audioPreparation.debugDurationText,
            modelPreparation.debugDurationText,
            transcription.debugDurationText,
            postProcessing.debugDurationText,
            fileSaving.debugDurationText,
            total.debugDurationText
        )
    }
}

extension Optional where Wrapped == Int64 {
    var fileSizeText: String {
        guard let bytes = self else { return "n/a" }
        if bytes < 1_024 { return "\(bytes)B" }
        if bytes < 1_048_576 {
            return String(format: "%.1fKB", Double(bytes) / 1_024)
        }
        return String(format: "%.1fMB", Double(bytes) / 1_048_576)
    }
}

extension Optional where Wrapped == Double {
    var audioDurationText: String {
        guard let secs = self else { return "n/a" }
        let mins = Int(secs) / 60
        let remainder = secs - Double(mins * 60)
        if mins > 0 {
            return String(format: "%dm %02.0fs", mins, remainder)
        }
        return String(format: "%.1fs", secs)
    }
}

private extension Optional where Wrapped == Duration {
    var debugDurationText: String {
        guard let duration = self else {
            return "n/a"
        }
        return duration.debugDurationText
    }
}

private extension Duration {
    var debugDurationText: String {
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        return String(format: "%.3fs", seconds + attoseconds)
    }

    var humanReadableText: String {
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        let totalSeconds = max(0, seconds + attoseconds)

        if totalSeconds < 1 {
            return "\(Int((totalSeconds * 1_000).rounded()))ms"
        }

        if totalSeconds < 60 {
            return String(format: "%.1fs", totalSeconds)
        }

        let minutes = Int(totalSeconds / 60)
        let remainder = totalSeconds - Double(minutes * 60)
        return String(format: "%dm %04.1fs", minutes, remainder)
    }
}
