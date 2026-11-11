import Foundation

extension AppSettings {
    func loadVocabularyContexts(from config: AppConfig) {
        parakeetVocabularyTerms = config.parakeetVocabularyTerms
        vocabularyContextsEnabled = config.vocabularyContextsEnabled
        vocabularyContexts = config.vocabularyContexts
        selectedVocabularyContextID = config.selectedVocabularyContextID
    }

    var effectiveVocabularyContext: VocabularyContextSnapshot {
        snapshotConfig().effectiveVocabularyContext
    }

    @discardableResult
    func createVocabularyContext(name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailableContextName(name, excluding: nil) else { return false }
        let context = VocabularyContext(name: name)
        vocabularyContexts.append(context)
        selectedVocabularyContextID = context.id
        saveVocabularyContexts()
        return true
    }

    @discardableResult
    func renameVocabularyContext(id: UUID, name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailableContextName(name, excluding: id),
              let index = vocabularyContexts.firstIndex(where: { $0.id == id }) else { return false }
        vocabularyContexts[index].name = name
        vocabularyContexts[index].revision = UUID()
        saveVocabularyContexts()
        return true
    }

    func deleteVocabularyContext(id: UUID) {
        vocabularyContexts.removeAll { $0.id == id }
        if selectedVocabularyContextID == id { selectedVocabularyContextID = nil }
        saveVocabularyContexts()
    }

    func selectVocabularyContext(id: UUID?) {
        selectedVocabularyContextID = vocabularyContexts.contains { $0.id == id } ? id : nil
        saveVocabularyContexts()
    }

    func setVocabularyTerms(_ terms: [ParakeetVocabularyTerm], contextID: UUID?) {
        let normalized = ParakeetVocabularyStore(terms: terms).terms
        if let contextID {
            guard let index = vocabularyContexts.firstIndex(where: { $0.id == contextID }) else { return }
            vocabularyContexts[index].terms = normalized
            vocabularyContexts[index].revision = UUID()
        } else {
            parakeetVocabularyTerms = normalized
        }
        saveVocabularyContexts()
    }

    func saveVocabularyContexts() {
        config = snapshotConfig()
        persistVocabularyConfiguration(config)
    }

    private func isAvailableContextName(_ name: String, excluding id: UUID?) -> Bool {
        !name.isEmpty && !vocabularyContexts.contains {
            $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }
}
