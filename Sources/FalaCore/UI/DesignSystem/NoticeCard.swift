import SwiftUI

public enum NoticeTone {
    case info
    case warning
    case error
    case success

    var color: Color {
        switch self {
        case .info:
            FalaColors.info
        case .warning:
            FalaColors.warning
        case .error:
            FalaColors.error
        case .success:
            FalaColors.success
        }
    }

    var systemImage: String {
        switch self {
        case .info:
            "info.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        case .success:
            "checkmark.circle.fill"
        }
    }
}

public struct NoticeCard<Actions: View>: View {
    public let title: String
    public let message: String
    public let tone: NoticeTone
    public let systemImage: String?
    public let textAlignment: TextAlignment

    private let actions: Actions

    public init(
        title: String,
        message: String,
        tone: NoticeTone,
        systemImage: String? = nil,
        textAlignment: TextAlignment = .leading,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.tone = tone
        self.systemImage = systemImage
        self.textAlignment = textAlignment
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: textAlignment == .center ? .center : .leading, spacing: Spacing.lg) {
            Label(title, systemImage: systemImage ?? tone.systemImage)
                .font(Typography.headline)
                .foregroundStyle(tone.color)

            Text(message)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(textAlignment)

            actions
        }
        .frame(
            maxWidth: .infinity,
            alignment: textAlignment == .center ? .center : .leading
        )
        .padding(Spacing.xl)
        .background(tone.color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(tone.color.opacity(0.18), lineWidth: 1)
        )
    }
}

public extension NoticeCard where Actions == EmptyView {
    init(
        title: String,
        message: String,
        tone: NoticeTone,
        systemImage: String? = nil,
        textAlignment: TextAlignment = .leading
    ) {
        self.init(
            title: title,
            message: message,
            tone: tone,
            systemImage: systemImage,
            textAlignment: textAlignment
        ) {
            EmptyView()
        }
    }
}
