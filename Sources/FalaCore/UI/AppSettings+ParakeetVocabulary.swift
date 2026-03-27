import Foundation

public extension AppSettings {
    @discardableResult
    func addParakeetVocabularyTerm(
        text: String,
        aliases: [String] = [],
        weight: Float? = nil
    ) -> Bool {
        let currentTerms = ParakeetVocabularyStore(terms: parakeetVocabularyTerms).terms
        let updatedTerms = ParakeetVocabularyStore(
            terms: parakeetVocabularyTerms + [
                ParakeetVocabularyTerm(text: text, aliases: aliases, weight: weight)
            ]
        ).terms

        guard updatedTerms != currentTerms else {
            return false
        }

        parakeetVocabularyTerms = updatedTerms
        return true
    }

    @discardableResult
    func removeParakeetVocabularyTerm(text: String) -> Bool {
        let normalizedText = normalizedParakeetVocabularyKey(text)
        let originalCount = parakeetVocabularyTerms.count

        parakeetVocabularyTerms.removeAll {
            normalizedParakeetVocabularyKey($0.text) == normalizedText
        }

        return parakeetVocabularyTerms.count != originalCount
    }
}

private func normalizedParakeetVocabularyKey(_ value: String) -> String {
    value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.caseInsensitive], locale: nil)
}
