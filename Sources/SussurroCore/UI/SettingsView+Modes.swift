import SwiftUI

extension SettingsView {
    
    var modesView: some View {
        List {
            ForEach(DictationTemplate.allCases, id: \.self) { template in
                NavigationLink(destination: ModeDetailView(template: template, settings: settings)) {
                    Label(template.rawValue, systemImage: template.icon)
                }
            }
        }
        .navigationTitle("Modos de Ditado")
    }
}

struct ModeDetailView: View {
    let template: DictationTemplate
    @ObservedObject var settings: AppSettings
    
    // Local state for editing
    @State private var provider: String = "global"
    @State private var model: String = ""
    @State private var prompt: String = ""
    
    // Available providers
    let providers = [
        ("global", "Usar Global"),
        ("apple", "Apple Intelligence"),
        ("gemini", "Google Gemini"),
        ("openai", "OpenAI GPT")
    ]
    
    var body: some View {
        Form {
            Section("Configuração do Modelo") {
                Picker("Provedor LLM", selection: $provider) {
                    ForEach(providers, id: \.0) { key, name in
                        Text(name).tag(key)
                    }
                }
                .onChange(of: provider) { updateConfig() }
                
                if provider != "global" && provider != "apple" {
                    TextField("Nome do Modelo (Opcional)", text: $model)
                        .onChange(of: model) { updateConfig() }
                    Text("Deixe em branco para usar o padrão do provedor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Prompt do Sistema") {
                TextEditor(text: $prompt)
                    .frame(minHeight: 150)
                    .font(.body.monospaced())
                    .onChange(of: prompt) { updateConfig() }
                
                Button("Restaurar Padrão") {
                    restoreDefault()
                }
                .disabled(prompt == (template.defaultSystemPrompt ?? ""))
            }
            
            Section("Informações") {
                LabeledContent("Padrão Original", value: template.defaultSystemPrompt ?? "Nenhum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle(template.rawValue)
        .onAppear { loadConfig() }
    }
    
    private func loadConfig() {
        if let config = settings.modeConfigs[template.rawValue] {
            self.provider = config.provider ?? "global"
            self.model = config.model ?? ""
            self.prompt = config.prompt ?? template.defaultSystemPrompt ?? ""
        } else {
            self.provider = "global"
            self.model = ""
            self.prompt = template.defaultSystemPrompt ?? ""
        }
    }
    
    private func updateConfig() {
        var config = settings.modeConfigs[template.rawValue] ?? ModeConfig()
        
        config.provider = (provider == "global") ? nil : provider
        config.model = model.isEmpty ? nil : model
        
        // If prompt is same as default, store nil? Or store it explicitly?
        // Storing explicitly allows user to revert to default if they want, but if we store nil we fallback to code default which might update in future versions.
        // Let's store explicitly only if different.
        if prompt == template.defaultSystemPrompt {
            config.prompt = nil
        } else {
            config.prompt = prompt
        }
        
        settings.modeConfigs[template.rawValue] = config
        settings.save()
    }
    
    private func restoreDefault() {
        prompt = template.defaultSystemPrompt ?? ""
        updateConfig()
    }
}
