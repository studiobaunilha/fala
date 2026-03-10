import Foundation
import os.log

private let logger = Logger(subsystem: "dev.fala.app", category: "DictationProfiling")

enum DictationStageID: String, CaseIterable, Sendable {
    case stopRecording = "stop_recording"
    case audioConversion = "audio_conversion"
    case rmsValidation = "rms_validation"
    case transcriberSetup = "transcriber_setup"
    case transcription = "transcription"
    case replacementRules = "replacement_rules"
    case llmProcessing = "llm_processing"
    case textInsertion = "text_insertion"

    var displayName: String {
        switch self {
        case .stopRecording: "Stop Recording"
        case .audioConversion: "Audio Conversion"
        case .rmsValidation: "RMS Validation"
        case .transcriberSetup: "Transcriber Setup"
        case .transcription: "Transcription"
        case .replacementRules: "Replacement Rules"
        case .llmProcessing: "LLM Processing"
        case .textInsertion: "Text Insertion"
        }
    }
}

/// Context for a finished profiling session — passed to `finish()`.
struct DictationProfilingContext: Sendable {
    var template: String = ""
    var engine: String = ""
    var llmProvider: String = ""
    var audioSampleCount: Int = 0
    var audioRMS: Float = 0
    var transcribedText: String = ""
    var outcome: DictationTimingOutcome = .succeeded
}

struct DictationTimingMetrics: Sendable {
    let context: DictationProfilingContext
    let stages: [(stage: DictationStageID, duration: Duration)]
    let total: Duration

    var debugSummary: String {
        var parts: [String] = []
        parts.append("template=\(context.template)")
        parts.append("engine=\(context.engine)")
        if !context.llmProvider.isEmpty { parts.append("llm=\(context.llmProvider)") }
        parts.append("outcome=\(context.outcome.rawValue)")
        for (stage, duration) in stages {
            parts.append("\(stage.rawValue)=\(duration.debugText)")
        }
        parts.append("total=\(total.debugText)")
        let measuredSum = stages.reduce(Duration.zero) { $0 + $1.duration }
        let gap = total - measuredSum
        parts.append("gap=\(gap.debugText)")
        parts.append("samples=\(context.audioSampleCount)")
        if context.audioSampleCount > 0 {
            let audioDuration = Double(context.audioSampleCount) / 16000.0
            parts.append(String(format: "audio_duration=%.2fs", audioDuration))
        }
        return parts.joined(separator: " ")
    }
}

enum DictationTimingOutcome: String, Sendable {
    case succeeded
    case silentAudio = "silent_audio"
    case tooShort = "too_short"
    case translationUnsupported = "translation_unsupported"
    case failed
}

// MARK: - Profiler protocol + implementations

/// Profiler that either measures or passes through, depending on whether
/// profiling is enabled. This avoids any runtime overhead when disabled.
protocol DictationProfiling: Sendable {
    @discardableResult
    func measure<T>(_ stage: DictationStageID, _ body: () throws -> T) rethrows -> T
    @discardableResult
    func measure<T>(_ stage: DictationStageID, _ body: sending () async throws -> T) async rethrows -> T
    @discardableResult
    func finish(_ context: DictationProfilingContext) -> DictationTimingMetrics?
}

/// Active profiler — measures each stage and logs a summary at the end.
final class DictationProfiler: DictationProfiling, Sendable {
    private let clock = ContinuousClock()
    private let wallStart: ContinuousClock.Instant

    // Accumulated stage results — nonisolated(unsafe) is fine because
    // the profiler is always used linearly within a single Task.
    nonisolated(unsafe) private var stages: [(stage: DictationStageID, duration: Duration)] = []

    /// Controls whether profiling is active. Checked once when creating
    /// the profiler instance — toggling mid-session has no effect.
    ///
    /// Enable via:
    /// - Environment variable: `FALA_PROFILE=1`
    /// - UserDefaults: `defaults write dev.fala.app ProfilingEnabled -bool true`
    /// - In code (debug builds): `DictationProfiler.isEnabled = true`
    #if DEBUG
    nonisolated(unsafe) static var isEnabled: Bool = {
        if ProcessInfo.processInfo.environment["FALA_PROFILE"] != nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "ProfilingEnabled")
    }()
    #else
    static let isEnabled: Bool = {
        if ProcessInfo.processInfo.environment["FALA_PROFILE"] != nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "ProfilingEnabled")
    }()
    #endif

    /// Returns an active profiler if profiling is enabled, otherwise a no-op stub.
    static func makeIfEnabled() -> any DictationProfiling {
        if isEnabled {
            return DictationProfiler()
        }
        return NoOpDictationProfiler()
    }

    init() {
        wallStart = ContinuousClock().now
    }

    @discardableResult
    func measure<T>(_ stage: DictationStageID, _ body: () throws -> T) rethrows -> T {
        let start = clock.now
        let result = try body()
        stages.append((stage, clock.now - start))
        return result
    }

    @discardableResult
    func measure<T>(_ stage: DictationStageID, _ body: sending () async throws -> T) async rethrows -> T {
        let start = clock.now
        let result = try await body()
        stages.append((stage, clock.now - start))
        return result
    }

    @discardableResult
    func finish(_ context: DictationProfilingContext) -> DictationTimingMetrics? {
        let total = clock.now - wallStart
        let metrics = DictationTimingMetrics(
            context: context,
            stages: stages,
            total: total
        )
        logger.notice("[Fala] Dictation timing \(metrics.debugSummary, privacy: .public)")
        return metrics
    }
}

/// No-op profiler — zero overhead, just runs the closures directly.
final class NoOpDictationProfiler: DictationProfiling, Sendable {
    @discardableResult @inline(__always)
    func measure<T>(_ stage: DictationStageID, _ body: () throws -> T) rethrows -> T {
        try body()
    }

    @discardableResult @inline(__always)
    func measure<T>(_ stage: DictationStageID, _ body: sending () async throws -> T) async rethrows -> T {
        try await body()
    }

    @discardableResult @inline(__always)
    func finish(_ context: DictationProfilingContext) -> DictationTimingMetrics? {
        nil
    }
}

private extension Duration {
    var debugText: String {
        let seconds = Double(components.seconds)
        let attoseconds = Double(components.attoseconds) / 1_000_000_000_000_000_000
        let total = seconds + attoseconds
        if total < 0.001 {
            return String(format: "%.1fµs", total * 1_000_000)
        } else if total < 1.0 {
            return String(format: "%.1fms", total * 1000)
        } else {
            return String(format: "%.3fs", total)
        }
    }
}
