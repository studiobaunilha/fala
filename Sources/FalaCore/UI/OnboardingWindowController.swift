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
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            ZStack {
                Image(systemName: step.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.completed ? FalaColors.success : FalaColors.warning)
                    .font(.title2)
                    .opacity(showProgress ? 0 : 1)
                
                if showProgress {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(step.title)
                    .font(.headline)
                Text(step.message)
                    .foregroundStyle(.secondary)

                if step.id == "license" && !step.completed && !showProgress {
                    licenseInputView
                } else if let issue = step.issue,
                          let actionTitle = issue.actionTitle,
                          !showProgress {
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

    private var showProgress: Bool {
        step.id == "license" && viewModel.isProcessingLicense
    }

    private var licenseInputView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                TextField(L10n("Cole seu código de ativação"), text: $viewModel.activationCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                
                Button(L10n("Ativar")) {
                    viewModel.activateLicense()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.activationCode.isEmpty)
            }
            
            Button(L10n("Validar online ou iniciar trial")) {
                viewModel.startTrial()
            }
            .buttonStyle(.link)
            .controlSize(.small)
            
            if let error = viewModel.licenseManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(FalaColors.error)
            }
        }
        .padding(.top, Spacing.xs)
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
                    OnboardingStepCard(step: step, onAction: { issue in
                        viewModel.performAction(for: issue)
                    }, viewModel: viewModel)
                }
            }

            HStack {
                Button(L10n("Revalidar estado")) {
                    viewModel.refresh()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(
                    viewModel.shouldOpenSettingsAfterContinue
                        ? L10n("Continuar e abrir Ajustes")
                        : L10n("Continuar")
                ) {
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
    private let onFinish: () -> Void

    var currentWindow: NSWindow? {
        window
    }

    public init(
        viewModel: OnboardingViewModel,
        onFinish: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onFinish = onFinish
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
                let shouldOpenSettings = self?.viewModel.shouldOpenSettingsAfterContinue ?? false
                self?.viewModel.markCompleted()
                self?.window?.orderOut(nil)
                if shouldOpenSettings {
                    self?.onFinish()
                }
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
                let shouldOpenSettings = self?.viewModel.shouldOpenSettingsAfterContinue ?? false
                self?.viewModel.markCompleted()
                self?.window?.orderOut(nil)
                if shouldOpenSettings {
                    self?.onFinish()
                }
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
