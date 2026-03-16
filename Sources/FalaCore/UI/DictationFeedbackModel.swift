import Foundation

private final class RMSMailbox: @unchecked Sendable {
    private let lock = NSLock()
    private var latestRaw: Float = 0

    func submit(_ raw: Float) {
        lock.withLock { latestRaw = raw }
    }

    func current() -> Float {
        lock.withLock { latestRaw }
    }

    func reset() {
        lock.withLock { latestRaw = 0 }
    }
}

/// Observable model that drives the floating dictation feedback view.
/// Audio callbacks only submit the latest RMS sample; the view model publishes
/// at a stable cadence suitable for animation.
@MainActor
public final class DictationFeedbackModel: ObservableObject {
    @Published public var stage: DictationStage = .recording
    @Published public var template: DictationTemplate = .raw
    @Published public var rmsLevel: Float = 0
    @Published public var rmsHistory: [Float] = Array(repeating: 0, count: 12)
    @Published public var isVisible: Bool = false
    @Published public var conversationTurnCount: Int = 0

    private static let historySize = 12
    private static let updateCadence = Duration.milliseconds(33)
    private static let smoothingFactor: Float = 0.42
    private static let decayFactor: Float = 0.8

    private let mailbox = RMSMailbox()
    private var displayLoopTask: Task<Void, Never>?
    private var displayedLevel: Float = 0

    public init() {}

    nonisolated public func ingestRMS(_ raw: Float) {
        mailbox.submit(raw)
    }

    /// Test-friendly helper that applies one frame immediately.
    public func pushRMS(_ raw: Float) {
        let normalized = normalizedLevel(for: raw)
        displayedLevel = normalized
        rmsLevel = normalized
        if !rmsHistory.isEmpty {
            rmsHistory.removeFirst()
        }
        rmsHistory.append(normalized)
    }

    public func startDisplayUpdates() {
        guard displayLoopTask == nil else {
            return
        }

        displayLoopTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.renderFrame()
                try? await Task.sleep(for: Self.updateCadence)
            }
        }
    }

    public func stopDisplayUpdates() {
        displayLoopTask?.cancel()
        displayLoopTask = nil
    }

    public func reset() {
        stopDisplayUpdates()
        mailbox.reset()
        stage = .recording
        rmsLevel = 0
        displayedLevel = 0
        rmsHistory = Array(repeating: 0, count: Self.historySize)
        isVisible = false
        conversationTurnCount = 0
    }

    private func renderFrame() {
        let targetLevel = normalizedLevel(for: mailbox.current())
        let nextLevel: Float

        if stage == .recording || stage == .selectionCommand {
            nextLevel = displayedLevel + ((targetLevel - displayedLevel) * Self.smoothingFactor)
        } else {
            nextLevel = displayedLevel * Self.decayFactor
        }

        displayedLevel = max(0, min(nextLevel, 1))
        rmsLevel = displayedLevel

        if !rmsHistory.isEmpty {
            rmsHistory.removeFirst()
        }
        rmsHistory.append(displayedLevel)
    }

    private func normalizedLevel(for raw: Float) -> Float {
        min(max(raw * 10, 0), 1)
    }
}
