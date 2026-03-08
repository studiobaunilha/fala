import Foundation
import Combine

private enum ReadinessTranscriptionUse {
    case dictation
    case batch
}

public enum ReadinessIssueKind: String, Equatable, Sendable {
    case licenseInactive
    case microphonePermission
    case accessibilityPermission
    case whisperModelMissing
    case mlxModelMissing
    case cloudAPIKeyMissing
    case appleIntelligenceUnavailable
    case restartRecommended
}

public enum ReadinessAction: Equatable, Sendable {
    case none
    case openSettings(SettingsSelection)
    case openMicrophoneSettings
    case openAccessibilitySettings
    case validateLicense
}

public struct ReadinessIssue: Identifiable, Equatable, Sendable {
    public let kind: ReadinessIssueKind
    public let title: String
    public let message: String
    public let action: ReadinessAction
    public let actionTitle: String?
    public let blocking: Bool

    public var id: String { kind.rawValue + title + message }
}

@MainActor
public final class RuntimeReadinessEvaluator: ObservableObject {
    private unowned let settings: AppSettings
    private let modelManager: ModelManager
    private let mlxCatalogService: MLXCatalogService
    private let licenseManager: LicenseManager
    private let permissionProvider: SystemPermissionProviding
    private let warmupCoordinator: WarmupCoordinator

    private var cancellables = Set<AnyCancellable>()

    public init(
        settings: AppSettings,
        modelManager: ModelManager,
        mlxCatalogService: MLXCatalogService,
        licenseManager: LicenseManager = .shared,
        permissionProvider: SystemPermissionProviding = SystemPermissionProvider(),
        warmupCoordinator: WarmupCoordinator
    ) {
        self.settings = settings
        self.modelManager = modelManager
        self.mlxCatalogService = mlxCatalogService
        self.licenseManager = licenseManager
        self.permissionProvider = permissionProvider
        self.warmupCoordinator = warmupCoordinator

        settings.objectWillChange.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        modelManager.objectWillChange.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        mlxCatalogService.objectWillChange.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        licenseManager.objectWillChange.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
        warmupCoordinator.objectWillChange.sink { [weak self] _ in self?.refresh() }.store(in: &cancellables)
    }

    public func refresh() {
        objectWillChange.send()
    }

    public func issuesForDictation() -> [ReadinessIssue] {
        var issues = [ReadinessIssue]()

        if let issue = licenseIssue() {
            issues.append(issue)
        }
        if let issue = microphoneIssue() {
            issues.append(issue)
        }
        if let issue = accessibilityIssue() {
            issues.append(issue)
        }
        issues.append(contentsOf: transcriptionEngineIssues(for: .dictation))
        issues.append(contentsOf: llmIssuesForCurrentMode())

        return issues
    }

    public func issuesForBatch(batchPrompt: String) -> [ReadinessIssue] {
        var issues = [ReadinessIssue]()

        if let issue = licenseIssue() {
            issues.append(issue)
        }
        issues.append(contentsOf: transcriptionEngineIssues(for: .batch))

        if !batchPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(contentsOf: llmIssues(for: .custom))
        }

        return issues
    }

    public func issuesForOnboarding() -> [ReadinessIssue] {
        var issues = [ReadinessIssue]()

        if let issue = microphoneIssue() {
            issues.append(issue)
        }
        if let issue = accessibilityIssue() {
            issues.append(issue)
        }
        if let issue = licenseIssue() {
            issues.append(issue)
        }

        issues.append(contentsOf: transcriptionEngineIssues(for: .dictation))
        issues.append(contentsOf: llmIssuesForCurrentMode())
        return issues
    }

    public func quickMenuModes() -> [DictationTemplate] {
        DictationTemplate.allCases.filter(isModeVisibleInQuickMenu)
    }

    public func isModeVisibleInQuickMenu(_ template: DictationTemplate) -> Bool {
        switch template {
        case .raw:
            return true
        case .translate:
            return settings.transcriptionEngine == "whisper"
        case .custom, .askAI:
            return llmIssues(for: template).isEmpty
        }
    }

    public func primaryIssueForDictation() -> ReadinessIssue? {
        issuesForDictation().first(where: \.blocking)
    }

    public func primaryIssueForBatch(batchPrompt: String) -> ReadinessIssue? {
        issuesForBatch(batchPrompt: batchPrompt).first(where: \.blocking)
    }

    public var isOnboardingReady: Bool {
        issuesForOnboarding().isEmpty
    }
}

private extension RuntimeReadinessEvaluator {
    private func licenseIssue() -> ReadinessIssue? {
        guard !licenseManager.isActivated else {
            return nil
        }

        let message: String
        if licenseManager.accessState == .needsConnection {
            message = L10n("Conecte este Mac à internet para validar a licença ou iniciar o trial.")
        } else {
            message = L10n("Valide online ou ative o Fala Pro para continuar.")
        }

        return ReadinessIssue(
            kind: .licenseInactive,
            title: L10n("Licença ou trial necessários"),
            message: message,
            action: .validateLicense,
            actionTitle: L10n("Validar online agora"),
            blocking: true
        )
    }

    private func microphoneIssue() -> ReadinessIssue? {
        switch permissionProvider.microphonePermissionState() {
        case .granted:
            return nil
        case .notDetermined:
            return ReadinessIssue(
                kind: .microphonePermission,
                title: L10n("Permita acesso ao microfone"),
                message: L10n("O Fala precisa do microfone para o ditado e para concluir o setup inicial."),
                action: .openMicrophoneSettings,
                actionTitle: L10n("Permitir microfone"),
                blocking: true
            )
        case .denied:
            return ReadinessIssue(
                kind: .microphonePermission,
                title: L10n("Microfone bloqueado"),
                message: L10n("Ative o acesso ao microfone nos Ajustes do Sistema para usar o ditado."),
                action: .openMicrophoneSettings,
                actionTitle: L10n("Abrir Ajustes do Sistema"),
                blocking: true
            )
        }
    }

    private func accessibilityIssue() -> ReadinessIssue? {
        guard !permissionProvider.isAccessibilityTrusted() else {
            return nil
        }

        return ReadinessIssue(
            kind: .accessibilityPermission,
            title: L10n("Permita acessibilidade"),
            message: L10n("A acessibilidade é necessária para inserir o texto transcrito no app em foco."),
            action: .openAccessibilitySettings,
            actionTitle: L10n("Abrir Ajustes do Sistema"),
            blocking: true
        )
    }

    private func transcriptionEngineIssues(for use: ReadinessTranscriptionUse) -> [ReadinessIssue] {
        let config = settings.snapshotConfig()
        guard config.transcriptionEngine == "whisper" else {
            return []
        }

        let selectedModel = config.activeWhisperModel
        guard selectedModel != "none", modelManager.isDownloaded(selectedModel) else {
            return [
                ReadinessIssue(
                    kind: .whisperModelMissing,
                    title: L10n("Modelo Whisper necessário"),
                    message: L10n("Escolha e baixe um modelo Whisper para continuar."),
                    action: .openSettings(.panel(.models)),
                    actionTitle: L10n("Abrir Ajustes"),
                    blocking: true
                )
            ]
        }

        return []
    }

    private func llmIssuesForCurrentMode() -> [ReadinessIssue] {
        let config = settings.snapshotConfig()
        let template = config.selectedDictationTemplate
        return llmIssues(for: template)
    }

    private func llmIssues(for template: DictationTemplate) -> [ReadinessIssue] {
        guard template.requiresLLM else {
            return []
        }

        let config = settings.snapshotConfig()
        let effective = config.getEffectiveConfig(for: template)

        switch effective.provider {
        case "apple":
            return appleLLMIssues(for: template)
        case "mlx":
            return mlxLLMIssues(config: config, effective: effective)
        case "gemini":
            return cloudProviderIssues(
                apiKey: config.geminiKey,
                title: L10n("Chave Gemini necessária"),
                message: L10n("Configure uma chave da API Gemini para usar este modo.")
            )
        case "openai":
            return cloudProviderIssues(
                apiKey: config.openAIKey,
                title: L10n("Chave OpenAI necessária"),
                message: L10n("Configure uma chave da API OpenAI para usar este modo.")
            )
        default:
            return []
        }
    }

    private func appleLLMIssues(for _: DictationTemplate) -> [ReadinessIssue] {
        if !settings.isAppleProviderUsable {
            return [
                settingsIssue(
                    kind: .appleIntelligenceUnavailable,
                    title: L10n("Apple Intelligence indisponível"),
                    message: L10n("Troque para MLX, Gemini ou OpenAI para usar este modo neste Mac.")
                )
            ]
        }
        return []
    }

    private func mlxLLMIssues(
        config: AppConfig,
        effective: AppConfig.EffectiveConfig
    ) -> [ReadinessIssue] {
        let modelID = effective.model.isEmpty ? config.mlxModel : effective.model
        let resolution = mlxCatalogService.resolveSelection(repoID: modelID)

        guard resolution.status != .unsupported else {
            return [
                settingsIssue(
                    kind: .mlxModelMissing,
                    title: L10n("Modelo MLX incompatível"),
                    message: L10n("Selecione um modelo MLX válido do catálogo antes de usar este modo.")
                )
            ]
        }

        guard let resolvedEntry = resolution.entry,
              mlxCatalogService.isDownloaded(repoID: resolvedEntry.repoID) else {
            return [
                settingsIssue(
                    kind: .mlxModelMissing,
                    title: L10n("Modelo MLX necessário"),
                    message: L10n("Baixe ou selecione um modelo MLX local compatível antes de usar este modo.")
                )
            ]
        }

        return []
    }

    private func cloudProviderIssues(
        apiKey: String,
        title: String,
        message: String
    ) -> [ReadinessIssue] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [
                settingsIssue(
                    kind: .cloudAPIKeyMissing,
                    title: title,
                    message: message
                )
            ]
        }

        return []
    }

    private func settingsIssue(
        kind: ReadinessIssueKind,
        title: String,
        message: String
    ) -> ReadinessIssue {
        ReadinessIssue(
            kind: kind,
            title: title,
            message: message,
            action: .openSettings(.panel(.llm)),
            actionTitle: L10n("Abrir Ajustes"),
            blocking: true
        )
    }
}
