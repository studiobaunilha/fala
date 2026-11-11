import SwiftUI

struct VocabularyContextPicker: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        if settings.vocabularyContextsEnabled {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Picker(L10n("Contexto de vocabulário"), selection: selection) {
                    Text(L10n("Padrão")).tag(nil as UUID?)
                    ForEach(settings.vocabularyContexts) { context in
                        Text(context.name).tag(Optional(context.id))
                    }
                }
                .pickerStyle(.menu)
                if settings.transcriptionEngine != "parakeet" {
                    Text(L10n("Contextos de vocabulário requerem Parakeet. O Whisper mantém sua configuração atual."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var selection: Binding<UUID?> {
        Binding(
            get: {
                let selected = settings.selectedVocabularyContextID
                return settings.vocabularyContexts.contains { $0.id == selected } ? selected : nil
            },
            set: { settings.selectVocabularyContext(id: $0) }
        )
    }
}

struct VocabularyContextsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newName = ""
    @State private var renamedName = ""
    @State private var preferredText = ""
    @State private var aliasesText = ""
    @State private var editingTerm: String?
    @State private var validationMessage: String?

    private var selected: VocabularyContext? {
        settings.vocabularyContexts.first { $0.id == settings.selectedVocabularyContextID }
    }

    private var terms: [ParakeetVocabularyTerm] {
        selected?.terms ?? settings.parakeetVocabularyTerms
    }

    var body: some View {
        Form {
            Section {
                Toggle(L10n("Usar contextos de vocabulário"), isOn: $settings.vocabularyContextsEnabled)
                    .onChange(of: settings.vocabularyContextsEnabled) { settings.saveVocabularyContexts() }
                Text(L10n(
                    "Escolha nomes e termos manualmente. Eles orientam o reconhecimento, sem garantir substituições."
                ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VocabularyContextPicker(settings: settings)
            }
            Section(L10n("Gerenciar contextos")) {
                HStack {
                    TextField(L10n("Nome do novo contexto"), text: $newName)
                    Button(L10n("Criar contexto"), action: createContext)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let selected {
                    HStack {
                        TextField(L10n("Nome do contexto"), text: $renamedName)
                        Button(L10n("Renomear")) {
                            validationMessage = settings.renameVocabularyContext(id: selected.id, name: renamedName)
                                ? nil : L10n("Use um nome de contexto único e não vazio.")
                        }
                        Button(L10n("Excluir contexto"), role: .destructive) {
                            settings.deleteVocabularyContext(id: selected.id)
                        }
                    }
                }
                if let validationMessage {
                    Text(validationMessage).foregroundStyle(.red)
                }
            }
            Section(L10n("Termos e aliases")) {
                termEditor
                ForEach(Array(terms.enumerated()), id: \.offset) { _, term in
                    termRow(term)
                }
                Text(L10n("Aliases são grafias alternativas conhecidas. Informe um por linha."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Text(L10n("Padrão preserva o vocabulário global. Contextos nomeados usam apenas seus próprios termos."))
                Text(L10n(
                    "Regras de substituição continuam globais e são aplicadas ao texto final em todos os contextos."
                ))
                Text(L10n("Os termos ficam neste Mac e não são acrescentados aos prompts de IA."))
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .onAppear { resetEditor() }
        .onChange(of: settings.selectedVocabularyContextID) { resetEditor() }
    }

    private var termEditor: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField(L10n("Grafia preferida"), text: $preferredText)
            TextEditor(text: $aliasesText)
                .frame(minHeight: 50, maxHeight: 80)
                .accessibilityLabel(L10n("Aliases, um por linha"))
            HStack {
                Button(editingTerm == nil ? L10n("Adicionar termo") : L10n("Salvar termo"), action: saveTerm)
                    .disabled(preferredText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if editingTerm != nil {
                    Button(L10n("Cancelar")) { clearTermEditor() }
                }
            }
        }
    }

    private func termRow(_ term: ParakeetVocabularyTerm) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(term.text)
                if !term.aliases.isEmpty {
                    Text(term.aliases.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(L10n("Editar")) {
                editingTerm = term.text
                preferredText = term.text
                aliasesText = term.aliases.joined(separator: "\n")
            }
            Button(L10n("Remover"), role: .destructive) {
                settings.setVocabularyTerms(terms.filter { $0.text != term.text }, contextID: selected?.id)
                if editingTerm == term.text { clearTermEditor() }
            }
        }
    }

    private func createContext() {
        if settings.createVocabularyContext(name: newName) {
            newName = ""
            validationMessage = nil
        } else {
            validationMessage = L10n("Use um nome de contexto único e não vazio.")
        }
    }

    private func saveTerm() {
        let originalWeight = terms.first { $0.text == editingTerm }?.weight
        var updated = terms.filter { $0.text != editingTerm }
        updated.append(ParakeetVocabularyTerm(
            text: preferredText,
            aliases: aliasesText.components(separatedBy: .newlines), weight: originalWeight
        ))
        settings.setVocabularyTerms(updated, contextID: selected?.id)
        clearTermEditor()
    }

    private func resetEditor() {
        renamedName = selected?.name ?? ""
        validationMessage = nil
        clearTermEditor()
    }

    private func clearTermEditor() {
        editingTerm = nil
        preferredText = ""
        aliasesText = ""
    }
}
