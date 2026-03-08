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
                        fileTranscriptionView
                    case .llm:
                        llmView
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
