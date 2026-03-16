import SwiftUI

/// Floating dictation overlay — shows audio waveform and stage progress.
/// Uses native macOS material for the surface and lightweight custom rendering
/// for the animated voice treatment.
///
/// Layout: pill shape (width × 80, cornerRadius 40). The waveform area
/// communicates the current stage visually — no explicit icon row needed.
enum DictationFeedbackLayout {
    static let width: CGFloat = 292
    static let height: CGFloat = 80
    static let cornerRadius: CGFloat = 40
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
                            accentColor(for: model.stage).opacity(model.stage == .recording ? 0.12 : 0.05),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 220
                    )
                )

            panelShape
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)

            WaveformBars(
                levels: model.rmsHistory,
                stage: model.stage
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)

            // Conversation turn badge — overlaid top-right corner
            if model.template.isConversational, model.conversationTurnCount > 0 {
                ConversationTurnBadge(count: model.conversationTurnCount)
                    .padding(.trailing, Spacing.sm)
                    .padding(.top, Spacing.sm)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topTrailing
                    )
            }
        }
        .frame(
            width: DictationFeedbackLayout.width,
            height: DictationFeedbackLayout.height
        )
        .clipShape(panelShape)
        .overlay {
            GlowBorder(isActive: model.stage == .recording || model.stage == .selectionCommand)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)
        .animation(AnimationConfig.spring, value: model.stage)
    }

    private func accentColor(for stage: DictationStage) -> Color {
        switch stage {
        case .selectionCommand: return .orange
        case .recording: return FalaColors.accent
        case .transcribing: return .cyan
        case .processing, .inserting: return FalaColors.purple
        case .done: return FalaColors.success
        }
    }
}

// MARK: - Waveform Bars

/// Renders the waveform area. Visual appearance adapts to the dictation stage:
/// - `.recording`            → dynamic bars driven by real-time RMS
/// - `.transcribing`         → staggered breathing dots (cyan)
/// - `.processing/.inserting`→ a bright dot traveling left-to-right (purple)
/// - `.done`                 → faded breathing dots (fade-out handled by controller)
private struct WaveformBars: View {
    let levels: [Float]
    let stage: DictationStage

    @State private var breathPhase: Double = 0
    @State private var travelOffset: Double = 0

    var body: some View {
        Group {
            switch stage {
            case .selectionCommand, .recording:
                recordingCanvas
            case .transcribing:
                breathingCanvas
            case .processing, .inserting:
                travelCanvas
            case .done:
                breathingCanvas
                    .opacity(0.3)
            }
        }
        .frame(height: DictationFeedbackLayout.waveformHeight)
        .onAppear { startAnimations() }
        .onChange(of: stage) { _, _ in startAnimations() }
    }

    // MARK: Recording — dynamic bars driven by real RMS

    private var recordingCanvas: some View {
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
                let easedLevel = pow(CGFloat(level), 0.82)
                let height = max(easedLevel * availableHeight, 7)
                let rect = CGRect(
                    x: originX,
                    y: baseline - height / 2,
                    width: DictationFeedbackLayout.barWidth,
                    height: height
                )
                let path = Path(roundedRect: rect, cornerRadius: DictationFeedbackLayout.barWidth / 2)
                context.fill(path, with: gradient)
            }
        }
    }

    // MARK: Transcribing — dots that breathe with staggered phase

    private var breathingCanvas: some View {
        Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
            let barCount = max(levels.count, 1)
            let totalSpacing = CGFloat(max(barCount - 1, 0)) * DictationFeedbackLayout.barSpacing
            let totalWaveWidth = (CGFloat(barCount) * DictationFeedbackLayout.barWidth) + totalSpacing
            let startX = max((size.width - totalWaveWidth) / 2, 0)
            let baseline = size.height / 2
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    Color.cyan.opacity(0.9),
                    FalaColors.accent.opacity(0.7)
                ]),
                startPoint: CGPoint(x: 0, y: size.height),
                endPoint: CGPoint(x: 0, y: 0)
            )
            for index in 0..<barCount {
                let originX = startX + (CGFloat(index) * (
                    DictationFeedbackLayout.barWidth + DictationFeedbackLayout.barSpacing
                ))
                let phaseOffset = (Double(index) / Double(max(barCount - 1, 1))) * .pi
                let breathe = (sin(breathPhase + phaseOffset) + 1) / 2
                let dotSize = DictationFeedbackLayout.inactiveDotSize * (0.55 + 0.45 * breathe)
                let dotRect = CGRect(
                    x: originX - (dotSize - DictationFeedbackLayout.barWidth) / 2,
                    y: baseline - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(ellipseIn: dotRect), with: gradient)
            }
        }
    }

    // MARK: Processing/Inserting — bright dot traveling left → right

    private var travelCanvas: some View {
        Canvas(opaque: false, colorMode: .extendedLinear, rendersAsynchronously: true) { context, size in
            let barCount = max(levels.count, 1)
            let totalSpacing = CGFloat(max(barCount - 1, 0)) * DictationFeedbackLayout.barSpacing
            let totalWaveWidth = (CGFloat(barCount) * DictationFeedbackLayout.barWidth) + totalSpacing
            let startX = max((size.width - totalWaveWidth) / 2, 0)
            let baseline = size.height / 2
            let gradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [
                    FalaColors.purple.opacity(0.95),
                    FalaColors.accent.opacity(0.8),
                    Color.cyan.opacity(0.6)
                ]),
                startPoint: CGPoint(x: 0, y: size.height),
                endPoint: CGPoint(x: 0, y: 0)
            )
            for index in 0..<barCount {
                let originX = startX + (CGFloat(index) * (
                    DictationFeedbackLayout.barWidth + DictationFeedbackLayout.barSpacing
                ))
                let fraction = (Double(index) / Double(max(barCount - 1, 1)) + travelOffset)
                    .truncatingRemainder(dividingBy: 1.0)
                // Gaussian intensity — bright peak sweeps left to right
                let dist = abs(fraction - 0.5)
                let intensity = exp(-dist * dist * 18)
                let dotSize = DictationFeedbackLayout.inactiveDotSize * (0.4 + 0.6 * intensity)
                let dotRect = CGRect(
                    x: originX - (dotSize - DictationFeedbackLayout.barWidth) / 2,
                    y: baseline - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(ellipseIn: dotRect), with: gradient)
            }
        }
    }

    private func startAnimations() {
        breathPhase = 0
        travelOffset = 0
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            breathPhase = .pi * 2
        }
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            travelOffset = 1.0
        }
    }
}

// MARK: - Conversation Turn Badge

private struct ConversationTurnBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(minWidth: 18, minHeight: 18)
            .background(FalaColors.accent.opacity(0.55))
            .clipShape(Capsule())
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
            // Amber glow for selectionCommand is derived from isActive
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
