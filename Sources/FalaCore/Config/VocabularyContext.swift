import Foundation

struct VocabularyContext: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var revision: UUID
    var terms: [ParakeetVocabularyTerm]

    init(id: UUID = UUID(), name: String, terms: [ParakeetVocabularyTerm] = []) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.revision = UUID()
        self.terms = ParakeetVocabularyStore(terms: terms).terms
    }
}

struct VocabularyContextSnapshot: Sendable, Equatable {
    let id: UUID?
    let name: String
    let revision: UUID?
    let store: ParakeetVocabularyStore

    var displayName: String { id == nil ? L10n("Padrão") : name }
}

extension AppConfig {
    var effectiveVocabularyContext: VocabularyContextSnapshot {
        if let capturedVocabularyContext { return capturedVocabularyContext }
        guard vocabularyContextsEnabled,
              let selected = vocabularyContexts.first(where: { $0.id == selectedVocabularyContextID }) else {
            return VocabularyContextSnapshot(
                id: nil, name: "Padrão", revision: nil, store: parakeetVocabularyStore
            )
        }
        return VocabularyContextSnapshot(
            id: selected.id, name: selected.name, revision: selected.revision,
            store: ParakeetVocabularyStore(terms: selected.terms)
        )
    }

    mutating func applyVocabularySnapshot(from captured: AppConfig?) {
        guard let captured else { return }
        capturedVocabularyContext = captured.effectiveVocabularyContext
        vocabularyContextsEnabled = captured.vocabularyContextsEnabled
        vocabularyContexts = captured.vocabularyContexts
        selectedVocabularyContextID = captured.selectedVocabularyContextID
        parakeetVocabularyTerms = captured.parakeetVocabularyTerms
    }
}
