import SwiftUI

public struct MLXCatalogSelectionSummaryView: View {
    public let summary: MLXCatalogSelectionSummary

    public init(summary: MLXCatalogSelectionSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(L10n("Modelo selecionado"))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)

                    Text(summary.entry.displayName)
                        .font(Typography.title)

                    Text(summary.entry.summary)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if summary.isIdealForCurrentMac {
                    RoleBadge(title: L10n("Ideal para este Mac"), color: FalaColors.badgeIdeal)
                }
            }

            HStack(spacing: Spacing.sm) {
                RoleBadge(title: summary.entry.family.title, color: FalaColors.badgeNeutral)
                RoleBadge(title: summary.entry.quantizationLabel, color: FalaColors.badgeNeutral)
                RoleBadge(title: summary.entry.estimatedDownloadSize, color: FalaColors.badgeNeutral)
                RoleBadge(
                    title: String(
                        format: L10n("Mínimo: %d GB"),
                        summary.entry.minimumUnifiedMemoryGB
                    ),
                    color: FalaColors.badgeNeutral
                )
            }

            Text(
                summary.isIdealForCurrentMac
                    ? String(
                        format: L10n("Ajuste recomendado para a classe %@ deste Mac."),
                        summary.hardwareClassTitle
                    )
                    : summary.entry.recommendedHardwareClasses.first?.subtitle
                        ?? MLXHardwareClass.pro.subtitle
            )
            .font(Typography.caption)
            .foregroundStyle(.secondary)
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

public struct MLXCatalogModelRow: View {
    public let entry: MLXCatalogEntry
    public let isDownloaded: Bool
    public let isSelected: Bool
    public let progress: Double?
    public let isIdealForCurrentMac: Bool
    public let diskSize: String?
    public let actionTitle: String
    public let actionRole: ButtonRole?
    public let action: () -> Void

    public init(
        entry: MLXCatalogEntry,
        isDownloaded: Bool,
        isSelected: Bool,
        progress: Double?,
        isIdealForCurrentMac: Bool,
        diskSize: String?,
        actionTitle: String,
        actionRole: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.entry = entry
        self.isDownloaded = isDownloaded
        self.isSelected = isSelected
        self.progress = progress
        self.isIdealForCurrentMac = isIdealForCurrentMac
        self.diskSize = diskSize
        self.actionTitle = actionTitle
        self.actionRole = actionRole
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Text(entry.displayName)
                        .font(Typography.headline)
                    if isSelected && isDownloaded {
                        RoleBadge(title: L10n("Ativo"), color: FalaColors.badgeActive)
                    }
                    if entry.isRecommended {
                        RoleBadge(title: L10n("Recomendado"), color: FalaColors.badgeRecommended)
                    }
                    if isIdealForCurrentMac {
                        RoleBadge(title: L10n("Ideal para este Mac"), color: FalaColors.badgeIdeal)
                    }
                    if entry.isLegacy {
                        RoleBadge(title: L10n("Legacy"), color: FalaColors.badgeLegacy)
                    }
                }

                Text(entry.summary)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: Spacing.sm) {
                    RoleBadge(title: entry.quantizationLabel, color: FalaColors.badgeNeutral)
                    RoleBadge(title: diskSize ?? entry.estimatedDownloadSize, color: FalaColors.badgeNeutral)
                    RoleBadge(
                        title: String(format: L10n("Mínimo: %d GB"), entry.minimumUnifiedMemoryGB),
                        color: FalaColors.badgeNeutral
                    )
                }
            }

            Spacer(minLength: 0)

            if let progress {
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    ProgressView(value: progress)
                        .frame(width: LayoutMetric.compactProgressWidth)
                        .controlSize(.small)
                    Text("\(Int(progress * 100))%")
                        .font(Typography.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(actionTitle, role: actionRole, action: action)
                    .frame(minWidth: LayoutMetric.mlxCatalogActionMinWidth)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
