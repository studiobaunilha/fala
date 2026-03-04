import SwiftUI

/// Floating dictation overlay — shows audio waveform, stage progress,
/// and live transcription text. Styled after Apple Intelligence/Siri glow.
struct DictationFeedbackView: View {
    @ObservedObject var model: DictationFeedbackModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            StageIndicatorRow(stage: model.stage)
            WaveformBars(
                levels: model.rmsHistory,
                isRecording: model.stage == .recording
            )
            if !model.transcriptionText.isEmpty {
                Text(model.transcriptionText)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(width: 280)
        .background(.clear)
        .overlay { GlowBorder(isActive: model.stage == .recording) }
        .animation(AnimationConfig.spring, value: model.stage)
        .animation(AnimationConfig.spring, value: model.transcriptionText)
    }
}

// MARK: - Stage Indicator Row

private struct StageIndicatorRow: View {
    let stage: DictationStage

    private static let stages: [(DictationStage, String)] = [
        (.recording, "mic.fill"),
        (.transcribing, "waveform"),
        (.processing, "gearshape"),
        (.inserting, "doc.on.clipboard"),
        (.done, "checkmark.circle")
    ]

    var body: some View {
        HStack(spacing: Spacing.md) {
            ForEach(Array(Self.stages.enumerated()), id: \.offset) { idx, item in
                let (itemStage, icon) = item
                let state = indicatorState(for: itemStage)
                Image(systemName: state == .completed ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.color)
                    .scaleEffect(state == .active ? 1.2 : 1.0)
                    .animation(AnimationConfig.spring, value: stage)

                if idx < Self.stages.count - 1 {
                    Rectangle()
                        .fill(state.lineColor)
                        .frame(height: 1)
                        .frame(maxWidth: 16)
                }
            }
        }
    }

    private enum IndicatorState {
        case pending, active, completed

        var color: Color {
            switch self {
            case .pending: .secondary.opacity(0.4)
            case .active: SussurroColors.accent
            case .completed: SussurroColors.success
            }
        }

        var lineColor: Color {
            switch self {
            case .completed: SussurroColors.success.opacity(0.5)
            default: Color.secondary.opacity(0.2)
            }
        }
    }

    private func indicatorState(for itemStage: DictationStage) -> IndicatorState {
        let order: [DictationStage] = [.recording, .transcribing, .processing, .inserting, .done]
        guard let current = order.firstIndex(of: stage),
              let target = order.firstIndex(of: itemStage) else { return .pending }
        if target < current { return .completed }
        if target == current { return .active }
        return .pending
    }
}

// MARK: - Waveform Bars

private struct WaveformBars: View {
    let levels: [Float]
    let isRecording: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                let height = isRecording
                    ? max(CGFloat(level) * 40, 4)
                    : 4
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [SussurroColors.accent, SussurroColors.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: height)
                    .animation(AnimationConfig.spring, value: level)
            }
        }
        .frame(height: 44)
    }
}

// MARK: - Apple Intelligence Glow Border

private struct GlowBorder: View {
    let isActive: Bool
    @State private var phase: Double = 0

    private let colors: [Color] = [
        .blue, .cyan, .purple, .pink, .orange, .yellow, .blue
    ]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20)

        ZStack {
            // Diffuse glow layer
            shape
                .stroke(gradient, lineWidth: isActive ? 3 : 1)
                .blur(radius: isActive ? 24 : 8)
                .opacity(isActive ? 0.8 : 0.3)

            // Sharp edge
            shape
                .stroke(gradient, lineWidth: isActive ? 2 : 0.5)
                .opacity(isActive ? 1.0 : 0.4)
        }
        .onAppear { startAnimating() }
        .onChange(of: isActive) { startAnimating() }
    }

    private var gradient: AngularGradient {
        AngularGradient(
            colors: colors,
            center: .center,
            startAngle: .degrees(phase),
            endAngle: .degrees(phase + 360)
        )
    }

    private func startAnimating() {
        guard isActive else { return }
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            phase = 360
        }
    }
}
