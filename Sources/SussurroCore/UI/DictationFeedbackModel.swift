import Foundation

/// Observable model that drives the floating dictation feedback view.
/// Updated by DictationMode at each pipeline stage; read by the SwiftUI view.
@MainActor
public final class DictationFeedbackModel: ObservableObject {
    @Published public var stage: DictationStage = .recording
    @Published public var template: DictationTemplate = .raw
    @Published public var rmsLevel: Float = 0
    @Published public var rmsHistory: [Float] = Array(repeating: 0, count: 12)
    @Published public var transcriptionText: String = ""
    @Published public var isVisible: Bool = false

    private static let historySize = 12

    public init() {}

    /// Normalises raw mic RMS (~0–0.1) to 0–1 and appends to the history ring.
    public func pushRMS(_ raw: Float) {
        let clamped = min(max(raw * 10, 0), 1)
        rmsLevel = clamped
        rmsHistory.append(clamped)
        if rmsHistory.count > Self.historySize {
            rmsHistory.removeFirst()
        }
    }

    /// Resets all state for a new dictation session.
    public func reset() {
        stage = .recording
        rmsLevel = 0
        rmsHistory = Array(repeating: 0, count: Self.historySize)
        transcriptionText = ""
        isVisible = false
    }
}
