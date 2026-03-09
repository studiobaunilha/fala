import AppKit
import Combine
import SwiftUI

public struct OnboardingStep: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let message: String
    public let completed: Bool
    public let issue: ReadinessIssue?
}

private struct OnboardingStepCard: View {
    let step: OnboardingStep
    let onAction: (ReadinessIssue) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            Image(systemName: step.completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(step.completed ? FalaColors.success : FalaColors.warning)
                .font(.title2)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(step.title)
                    .font(.headline)
                Text(step.message)
                    .foregroundStyle(.secondary)

                if let issue = step.issue,
                   let actionTitle = issue.actionTitle {
                    Button(actionTitle) {
                        onAction(issue)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
    }
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var hasCompletedEssentials = false

    private let settings: AppSettings
    private let readiness: RuntimeReadinessEvaluator
    private let licenseManager: LicenseManager
    private let permissionProvider: SystemPermissionProviding
    private let defaults: UserDefaults
    private let completionKey = "dev.fala.onboarding-essential-complete"
    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettings,
        readiness: RuntimeReadinessEvaluator,
        licenseManager: LicenseManager = .shared,
        permissionProvider: SystemPermissionProviding,
        defaults: UserDefaults = .standard
    ) {
        self.settings = settings
        self.readiness = readiness
        self.licenseManager = licenseManager
        self.permissionProvider = permissionProvider
        self.defaults = defaults
        self.hasCompletedEssentials = defaults.bool(forKey: completionKey)

        readiness.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var shouldPresentOnLaunch: Bool {
        !hasCompletedEssentials || !readiness.isOnboardingReady
    }

    public var isReadyToContinue: Bool {
        readiness.isOnboardingReady
    }

    public var steps: [OnboardingStep] {
        let issues = readiness.issuesForOnboarding()
        return [
            step(
                id: "microphone",
                title: L10n("Microfone"),
                fallbackMessage: L10n("Permita o microfone para usar o ditado."),
                issueKind: .microphonePermission,
                issues: issues
            ),
            step(
                id: "accessibility",
                title: L10n("Acessibilidade"),
                fallbackMessage: L10n("Permita acessibilidade para inserir texto no app em foco."),
                issueKind: .accessibilityPermission,
                issues: issues
            ),
            step(
                id: "license",
                title: L10n("Licença ou trial"),
                fallbackMessage: L10n("A licença ou o trial deste Mac já estão válidos."),
                issueKind: .licenseInactive,
                issues: issues
            ),
            step(
                id: "engine",
                title: L10n("Motor e modelo prontos"),
                fallbackMessage: L10n("O motor selecionado já está com a configuração mínima válida."),
                issueKind: .whisperModelMissing,
                issues: issues
            ),
            step(
                id: "llm",
                title: L10n("IA pronta para o modo atual"),
                fallbackMessage: L10n("O provedor e o modelo de IA do modo atual já estão válidos."),
                issueKind: llmIssueKind(from: issues),
                issues: issues
            )
        ]
    }

    public func markCompleted() {
        defaults.set(true, forKey: completionKey)
        hasCompletedEssentials = true
    }

    public func refresh() {
        readiness.refresh()
        objectWillChange.send()
    }

    public func performAction(for issue: ReadinessIssue?) {
        guard let issue else {
            return
        }

        switch issue.action {
        case .none:
            break
        case .openSettings(let selection):
            settings.openSettings(selection)
        case .openMicrophoneSettings:
            Task {
                if permissionProvider.microphonePermissionState() == .notDetermined {
                    _ = await permissionProvider.requestMicrophoneAccess()
                } else {
                    permissionProvider.openMicrophoneSettings()
                }
                refresh()
            }
        case .openAccessibilitySettings:
            permissionProvider.openAccessibilitySettings()
            refresh()
        case .validateLicense:
            Task {
                await licenseManager.refreshEntitlement()
                refresh()
            }
        }
    }

    private func step(
        id: String,
        title: String,
        fallbackMessage: String,
        issueKind: ReadinessIssueKind,
        issues: [ReadinessIssue]
    ) -> OnboardingStep {
        let issue = issues.first(where: { $0.kind == issueKind })
        return OnboardingStep(
            id: id,
            title: title,
            message: issue?.message ?? fallbackMessage,
            completed: issue == nil,
            issue: issue
        )
    }

    private func llmIssueKind(from issues: [ReadinessIssue]) -> ReadinessIssueKind {
        if issues.contains(where: { $0.kind == .mlxModelMissing }) {
            return .mlxModelMissing
        }
        if issues.contains(where: { $0.kind == .cloudAPIKeyMissing }) {
            return .cloudAPIKeyMissing
        }
        if issues.contains(where: { $0.kind == .appleIntelligenceUnavailable }) {
            return .appleIntelligenceUnavailable
        }
        return .restartRecommended
    }
}

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(L10n("Configurar o Fala"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(
                    L10n("Conclua o básico uma vez para o app já abrir pronto para ditado e transcrição.")
                )
                .foregroundStyle(.secondary)
            }

            VStack(spacing: Spacing.lg) {
                ForEach(viewModel.steps) { step in
                    OnboardingStepCard(step: step) { issue in
                        viewModel.performAction(for: issue)
                    }
                }
            }

            HStack {
                Button(L10n("Revalidar estado")) {
                    viewModel.refresh()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(L10n("Continuar")) {
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isReadyToContinue)
            }
        }
        .padding(Spacing.xxl)
        .frame(width: WindowSize.onboardingDefaultWidth)
        .fixedSize(horizontal: false, vertical: true)
    }
}

@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: OnboardingViewModel

    var currentWindow: NSWindow? {
        window
    }

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public func showIfNeeded() {
        guard viewModel.shouldPresentOnLaunch else {
            return
        }

        if let window {
            reloadContent()
            WindowFactory.show(window)
            return
        }

        let config = windowConfig

        let win = WindowFactory.makeWindow(
            config: config,
            content: OnboardingView(viewModel: viewModel) { [weak self] in
                self?.viewModel.markCompleted()
                self?.window?.orderOut(nil)
            }
        )
        win.delegate = self
        fitWindowHeight(win, config: config)
        self.window = win
        WindowFactory.show(win)
    }

    public func reloadContent() {
        guard let window else { return }
        let config = windowConfig

        WindowFactory.applyContent(
            OnboardingView(viewModel: viewModel) { [weak self] in
                self?.viewModel.markCompleted()
                self?.window?.orderOut(nil)
            },
            config: config,
            to: window
        )
        fitWindowHeight(window, config: config)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        viewModel.isReadyToContinue
    }

    private var windowConfig: WindowConfig {
        WindowConfig(
            title: L10n("Boas-vindas"),
            width: WindowSize.onboardingDefaultWidth,
            height: WindowSize.onboardingDefaultHeight,
            styleMask: [.titled],
            isResizable: false,
            minSize: NSSize(
                width: WindowSize.onboardingMinWidth,
                height: WindowSize.onboardingMinHeight
            ),
            maxSize: NSSize(
                width: WindowSize.onboardingMaxWidth,
                height: WindowSize.onboardingMaxHeight
            )
        )
    }

    private func fitWindowHeight(_ window: NSWindow, config: WindowConfig) {
        guard let contentView = window.contentView else {
            return
        }

        contentView.layoutSubtreeIfNeeded()

        let fittingHeight = contentView.fittingSize.height
        let minHeight = config.minSize?.height ?? fittingHeight
        let maxHeight = config.maxSize?.height ?? fittingHeight
        let targetHeight = min(max(fittingHeight, minHeight), maxHeight)
        let targetSize = NSSize(width: config.width, height: targetHeight)

        guard window.contentLayoutRect.size != targetSize else {
            return
        }

        window.setContentSize(targetSize)
    }
}
