import SwiftUI
import KeyboardShortcuts

// MARK: – View Components

// MARK: – Settings View

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var navigationState: SettingsNavigationState
    @ObservedObject var licenseManager = LicenseManager.shared
    @ObservedObject private var localizationObserver = AppLocalizationObserver.shared
    @State var newIncorrect: String = ""
    @State var newCorrect: String = ""
    @State var activationCode: String = ""
    @FocusState var focusedField: SettingsFocusedField?
    
    // Key testing state
    @State var isTestingKey = false
    @State var testKeyResult: String?
    @State var showTestKeyAlert = false
    @State var availableGeminiModels: [String] = [
        "gemini-2.0-flash", "gemini-2.5-flash", "gemini-1.5-flash"
    ]

    var body: some View {
        NavigationSplitView {
            List(selection: $navigationState.selection) {
                Section {
                    ForEach(SettingsPanel.allCases) { panel in
                        Label(panel.localizedName, systemImage: panel.icon)
                            .tag(SettingsSelection.panel(panel))
                    }
                }
                
                Section(L10n("Modos")) {
                    ForEach(DictationTemplate.allCases, id: \.self) { template in
                        HStack {
                            Label(template.localizedName, systemImage: template.icon)
                            if template == .translate && settings.transcriptionEngine != "whisper" {
                                Spacer()
                                SidebarWarningIndicator(
                                    helpText: L10n("Tradução requer o motor Whisper")
                                )
                            }
                            if template == .custom && settings.llmProvider == "apple" {
                                Spacer()
                                SidebarWarningIndicator(
                                    helpText: L10n(
                                        "Modo personalizado requer provedor diferente do Apple Intelligence"
                                    )
                                )
                            }
                        }
                        .tag(SettingsSelection.template(template))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .listStyle(.sidebar)
        } detail: {
            if let selection = navigationState.selection {
                switch selection {
                case .panel(let panel):
                    switch panel {
                    case .general:
                        generalView
                    case .models:
                        modelsView
                    case .advanced:
                        advancedView
                    case .llm:
                        llmView
                    case .license:
                        licenseView
                    case .updates:
                        updatesView
                    case .about:
                        aboutView
                    }
                case .template(let template):
                    ModeDetailView(template: template, settings: settings)
                        .id(template)
                }
            } else {
                Text(L10n("Selecione um painel à esquerda"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(removing: .sidebarToggle)
        .id(localizationObserver.revision)
        .environment(\.locale, AppLocalization.currentLocale())
        .frame(minWidth: WindowSize.settingsDefaultWidth, minHeight: WindowSize.settingsDefaultHeight)
        .observeSettingsChanges(settings)
    }
}

// MARK: – Model Row

struct ModelRow: View {
    let model: ModelInfo
    @ObservedObject var manager: ModelManager
    let isDictation: Bool
    let isBatch: Bool

    private var isDownloaded: Bool { manager.isDownloaded(model.id) }
    private var progress: Double? { manager.downloads[model.id] }
    private var isActive: Bool { isDictation || isBatch }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.sm) {
                    Text(model.label)
                        .font(.body)
                    if isDownloaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FalaColors.success)
                            .font(.caption)
                    }
                }
                HStack(spacing: Spacing.md) {
                    Text(sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isDictation {
                        RoleBadge.dictation
                    }
                    if isBatch {
                        RoleBadge.batch
                    }
                }
            }

            Spacer()

            if let progress {
                ProgressView(value: progress)
                    .frame(width: LayoutMetric.compactProgressWidth)
                    .controlSize(.small)
                Text("\(Int(progress * 100))%")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: LayoutMetric.compactProgressValueWidth, alignment: .trailing)
            } else if isDownloaded {
                Button(role: .destructive) {
                    try? manager.delete(model.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(isActive)
                .help(isActive ? L10n("Não pode apagar modelo ativo") : L10n("Apagar modelo"))
            } else {
                Button {
                    manager.download(model.id)
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .help(L10n("Baixar modelo"))
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var sizeLabel: String {
        manager.diskSize(for: model.id) ?? model.estimatedSize
    }
}
