import SwiftUI

public struct CatalogBadgeDescriptor: Equatable {
    public let title: String
    public let color: Color

    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }
}

public struct TranscriptionEngineOptionCard: View {
    public let title: String
    public let subtitle: String
    public let summary: String
    public let badges: [CatalogBadgeDescriptor]
    public let isSelected: Bool
    public let actionTitle: String
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String,
        summary: String,
        badges: [CatalogBadgeDescriptor],
        isSelected: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.badges = badges
        self.isSelected = isSelected
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.title)

                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)

                    Text(summary)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    RoleBadge(title: L10n("Ativo"), color: FalaColors.badgeActive)
                }
            }

            HStack(spacing: Spacing.sm) {
                ForEach(Array(badges.enumerated()), id: \.offset) { badge in
                    RoleBadge(title: badge.element.title, color: badge.element.color)
                }
            }

            Button(actionTitle, action: action)
                .frame(minWidth: LayoutMetric.mlxCatalogActionMinWidth)
                .disabled(isSelected)
        }
        .padding(Spacing.xl)
        .background(FalaColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(FalaColors.border, lineWidth: 1)
        )
    }
}

public struct WhisperModelSelectionSummaryView: View {
    public let model: ModelInfo
    public let isDownloaded: Bool
    public let progress: Double?
    public let primaryActionTitle: String?
    public let primaryAction: (() -> Void)?

    public init(
        model: ModelInfo,
        isDownloaded: Bool,
        progress: Double? = nil,
        primaryActionTitle: String? = nil,
        primaryAction: (() -> Void)? = nil
    ) {
        self.model = model
        self.isDownloaded = isDownloaded
        self.progress = progress
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Modelo ativo"))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)

                    Text(model.label)
                        .font(Typography.title)

                    Text(model.summary)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.isRecommended {
                    RoleBadge(title: L10n("Recomendado"), color: FalaColors.badgeRecommended)
                }
            }

            HStack(spacing: Spacing.sm) {
                RoleBadge(title: model.audienceLabel, color: FalaColors.badgeNeutral)
                RoleBadge(title: model.usageLabel, color: FalaColors.badgeNeutral)
                RoleBadge(title: model.estimatedSize, color: FalaColors.badgeNeutral)
            }

            Text(
                isDownloaded
                    ? L10n("Este modelo já está pronto para ditado e transcrição de arquivos.")
                    : L10n("Baixe este modelo para usar o Whisper em ditado e transcrição de arquivos.")
            )
            .font(Typography.caption)
            .foregroundStyle(.secondary)

            if let progress {
                CatalogProgressStatusView(progress: progress)
            } else if let primaryActionTitle, let primaryAction {
                CatalogPrimaryActionButton(title: primaryActionTitle, action: primaryAction)
            }
        }
        .padding(Spacing.xl)
        .background(FalaColors.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .stroke(FalaColors.border, lineWidth: 1)
        )
    }
}

public struct WhisperCatalogModelRow: View {
    public let model: ModelInfo
    public let isDownloaded: Bool
    public let isSelected: Bool
    public let progress: Double?
    public let diskSize: String?
    public let primaryActionTitle: String
    public let isPrimaryActionDisabled: Bool
    public let primaryAction: () -> Void
    public let removeAction: (() -> Void)?

    public init(
        model: ModelInfo,
        isDownloaded: Bool,
        isSelected: Bool,
        progress: Double?,
        diskSize: String?,
        primaryActionTitle: String,
        isPrimaryActionDisabled: Bool = false,
        primaryAction: @escaping () -> Void,
        removeAction: (() -> Void)? = nil
    ) {
        self.model = model
        self.isDownloaded = isDownloaded
        self.isSelected = isSelected
        self.progress = progress
        self.diskSize = diskSize
        self.primaryActionTitle = primaryActionTitle
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.primaryAction = primaryAction
        self.removeAction = removeAction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Text(model.label)
                        .font(Typography.headline)
                    if isSelected {
                        RoleBadge(title: L10n("Ativo"), color: FalaColors.badgeActive)
                    }
                    if model.isRecommended {
                        RoleBadge(title: L10n("Recomendado"), color: FalaColors.badgeRecommended)
                    }
                }

                Text(model.summary)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.sm) {
                    RoleBadge(title: model.audienceLabel, color: FalaColors.badgeNeutral)
                    RoleBadge(title: model.usageLabel, color: FalaColors.badgeNeutral)
                    RoleBadge(title: diskSize ?? model.estimatedSize, color: FalaColors.badgeNeutral)
                }
            }

            Spacer(minLength: 0)

            if let progress {
                CatalogProgressStatusView(progress: progress)
            } else {
                HStack(spacing: Spacing.sm) {
                    CatalogPrimaryActionButton(
                        title: primaryActionTitle,
                        isDisabled: isPrimaryActionDisabled,
                        action: primaryAction
                    )

                    if let removeAction {
                        CatalogRemoveButton(action: removeAction)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
