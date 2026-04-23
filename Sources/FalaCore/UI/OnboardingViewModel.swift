import Foundation
import Combine

@MainActor
public final class OnboardingViewModel: ObservableObject {
    @Published public private(set) var hasCompletedEssentials = false
    @Published public var activationCode: String = ""

    private let settings: AppSettings
    public let licenseManager: LicenseManager
    private let readiness: RuntimeReadinessEvaluator
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

        licenseManager.objectWillChange
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

    public var shouldOpenSettingsAfterContinue: Bool {
        !hasCompletedEssentials
    }

    public var isProcessingLicense: Bool {
        licenseManager.isActivating || 
        licenseManager.isRefreshingEntitlement || 
        licenseManager.isReconcilingOnLaunch
    }

    public func activateLicense() {
        guard !activationCode.isEmpty else { return }
        Task {
            await licenseManager.activate(activationCode: activationCode)
            refresh()
        }
    }

    public func startTrial() {
        Task {
            await licenseManager.refreshEntitlement()
            refresh()
        }
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
