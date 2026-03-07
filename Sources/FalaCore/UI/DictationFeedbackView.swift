import SwiftUI

/// Floating dictation overlay — shows audio waveform and stage progress.
/// Uses native macOS material for the surface and lightweight custom rendering
/// for the animated voice treatment.
enum DictationFeedbackLayout {
    static let width: CGFloat = 292
    static let height: CGFloat = 132
    static let cornerRadius: CGFloat = 27
    static let waveformHeight: CGFloat = 46
    static let barWidth: CGFloat = 10
    static let barSpacing: CGFloat = 5
    static let inactiveDotSize: CGFloat = 9
}

struct DictationFeedbackView: View {
    @ObservedObject var model: DictationFeedbackModel

    private let panelShape = RoundedRectangle(
        cornerRadius: DictationFeedbackLayout.cornerRadius,
        style: .continuous
    )

    var body: some View {
        ZStack {
            panelShape
                .fill(.ultraThinMaterial)

            panelShape
                .fill(Color.black.opacity(0.16))

            panelShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.screen)

            panelShape
                .fill(
                    RadialGradient(
                        colors: [
                            FalaColors.accent.opacity(model.stage == .recording ? 0.12 : 0.05),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 220
                    )
                )

            panelShape
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)

            VStack(spacing: Spacing.lg) {
                StageIndicatorRow(stage: model.stage, template: model.template)
                WaveformBars(
                    levels: model.rmsHistory,
                    isRecording: model.stage == .recording
                )
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
        }
        .frame(
            width: DictationFeedbackLayout.width,
            height: DictationFeedbackLayout.height
        )
        .clipShape(panelShape)
        .overlay {
            GlowBorder(isActive: model.stage == .recording)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)
        .animation(AnimationConfig.spring, value: model.stage)
    }
}

// MARK: - Stage Indicator Row

private struct StageIndicatorRow: View {
    let stage: DictationStage
    let template: DictationTemplate

    private var activeStages: [(DictationStage, String)] {
        var stages: [(DictationStage, String)] = [
            (.recording, "mic.fill"),
            (.transcribing, "waveform")
        ]
        if template.requiresLLM {
            stages.append((.processing, "gearshape"))
        }
        stages.append(contentsOf: [
            (.inserting, "doc.on.clipboard"),
            (.done, "checkmark.circle")
        ])
        return stages
    }

    var body: some View {
        let stages = activeStages
        HStack(spacing: Spacing.md) {
            ForEach(Array(stages.enumerated()), id: \.offset) { idx, item in
                let (itemStage, icon) = item
                let state = indicatorState(for: itemStage, order: stages.map(\.0))
                Image(systemName: state == .completed ? "checkmark.circle.fill" : icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.color)
                    .scaleEffect(state == .active ? 1.12 : 1.0)
                    .animation(AnimationConfig.spring, value: stage)

                if idx < stages.count - 1 {
                    Capsule()
                        .fill(state.lineColor)
                        .frame(width: 16, height: 1)
                }
            }
        }
    }

    private enum IndicatorState {
        case pending
        case active
        case completed

        var color: Color {
            switch self {
            case .pending:
                return .secondary.opacity(0.4)
            case .active:
                return FalaColors.accent
            case .completed:
                return FalaColors.success
            }
        }

        var lineColor: Color {
            switch self {
            case .completed:
                return FalaColors.success.opacity(0.55)
            case .active:
                return FalaColors.accent.opacity(0.45)
            case .pending:
                return Color.secondary.opacity(0.18)
            }
        }
    }

    private func indicatorState(for itemStage: DictationStage, order: [DictationStage]) -> IndicatorState {
        guard let current = order.firstIndex(of: stage),
              let target = order.firstIndex(of: itemStage) else {
            return .pending
        }

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
        Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
            let barCount = max(levels.count, 1)
            let totalSpacing = CGFloat(max(barCount - 1, 0)) * DictationFeedbackLayout.barSpacing
            let totalWaveWidth = (CGFloat(barCount) * DictationFeedbackLayout.barWidth) + totalSpacing
            let startX = max((size.width - totalWaveWidth) / 2, 0)
            let availableHeight = max(size.height - 8, 8)
            let baseline = size.height / 2
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    FalaColors.accent.opacity(0.98),
                    .cyan.opacity(0.95),
                    FalaColors.purple.opacity(0.9)
                ]),
                startPoint: CGPoint(x: 0, y: size.height),
                endPoint: CGPoint(x: 0, y: 0)
            )

            for (index, level) in levels.enumerated() {
                let originX = startX + (CGFloat(index) * (
                    DictationFeedbackLayout.barWidth + DictationFeedbackLayout.barSpacing
                ))
                let path: Path

                if isRecording {
                    let easedLevel = pow(CGFloat(level), 0.82)
                    let height = max((easedLevel * availableHeight), 7)
                    let rect = CGRect(
                        x: originX,
                        y: baseline - (height / 2),
                        width: DictationFeedbackLayout.barWidth,
                        height: height
                    )
                    path = Path(
                        roundedRect: rect,
                        cornerRadius: DictationFeedbackLayout.barWidth / 2
                    )
                } else {
                    let dotRect = CGRect(
                        x: originX - ((DictationFeedbackLayout.inactiveDotSize - DictationFeedbackLayout.barWidth) / 2),
                        y: baseline - (DictationFeedbackLayout.inactiveDotSize / 2),
                        width: DictationFeedbackLayout.inactiveDotSize,
                        height: DictationFeedbackLayout.inactiveDotSize
                    )
                    path = Path(ellipseIn: dotRect)
                }

                context.fill(path, with: gradient)
            }
        }
        .frame(height: DictationFeedbackLayout.waveformHeight)
    }
}

// MARK: - Animated Glow Border

private struct GlowBorder: View {
    let isActive: Bool

    @State private var phase: Double = 0

    private let colors: [Color] = [
        .blue, .cyan, .purple, .pink, .orange, .yellow, .blue
    ]

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: DictationFeedbackLayout.cornerRadius,
            style: .continuous
        )

        shape
            .strokeBorder(gradient, lineWidth: isActive ? 1.6 : 0.85)
            .opacity(isActive ? 1.0 : 0.55)
            .shadow(color: Color.cyan.opacity(isActive ? 0.24 : 0.08), radius: isActive ? 14 : 5)
            .shadow(color: FalaColors.purple.opacity(isActive ? 0.18 : 0.05), radius: isActive ? 24 : 8)
            .shadow(color: FalaColors.accent.opacity(isActive ? 0.16 : 0.04), radius: isActive ? 10 : 4)
            .padding(0.8)
            .allowsHitTesting(false)
            .onAppear { updateAnimation() }
            .onChange(of: isActive) { _, _ in updateAnimation() }
    }

    private var gradient: AngularGradient {
        AngularGradient(
            colors: colors,
            center: .center,
            startAngle: .degrees(phase),
            endAngle: .degrees(phase + 360)
        )
    }

    private func updateAnimation() {
        if isActive {
            phase = 0
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = 360
            }
        } else {
            phase = 0
        }
    }
}
