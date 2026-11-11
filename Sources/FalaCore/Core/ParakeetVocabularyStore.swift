import Foundation
import FluidAudio

struct ParakeetVocabularyTerm: Codable, Sendable, Equatable {
    let text: String
    let aliases: [String]
    let weight: Float?

    init(text: String, aliases: [String] = [], weight: Float? = nil) {
        self.text = text
        self.aliases = aliases
        self.weight = weight
    }
}

struct ParakeetVocabularyStore: Sendable, Equatable {
    let terms: [ParakeetVocabularyTerm]

    init(terms: [ParakeetVocabularyTerm] = []) {
        self.terms = Self.normalizedTerms(from: terms)
    }

    init(
        replacementRules: [ReplacementRule] = [],
        explicitTerms: [ParakeetVocabularyTerm] = []
    ) {
        let ruleTerms = Self.normalizedTerms(from: replacementRules)
        self.terms = Self.normalizedTerms(from: explicitTerms + ruleTerms)
    }

    var isEmpty: Bool {
        terms.isEmpty
    }

    var customVocabularyContext: CustomVocabularyContext? {
        guard !terms.isEmpty else { return nil }

        let vocabularyTerms = terms.map { term in
            CustomVocabularyTerm(
                text: term.text,
                weight: term.weight,
                aliases: term.aliases.isEmpty ? nil : term.aliases,
                // Declared spellings authorize corrections; similar ordinary words do not.
                minSimilarity: 1
            )
        }
        return CustomVocabularyContext(terms: vocabularyTerms)
    }
}

extension AppConfig {
    var parakeetVocabularyStore: ParakeetVocabularyStore {
        ParakeetVocabularyStore(
            replacementRules: replacementRules,
            explicitTerms: parakeetVocabularyTerms
        )
    }
}

private extension ParakeetVocabularyStore {
    static func normalizedTerms(from replacementRules: [ReplacementRule]) -> [ParakeetVocabularyTerm] {
        var mergedTerms: [ParakeetVocabularyTerm] = []

        for rule in replacementRules {
            let replacement = normalized(rule.replacement)
            guard !replacement.isEmpty else { continue }

            let replacementKey = normalizationKey(for: replacement)
            var aliases: [String] = []
            var seenAliases = Set<String>()

            for variant in rule.variants {
                let alias = normalized(variant)
                guard !alias.isEmpty else { continue }

                let aliasKey = normalizationKey(for: alias)
                guard aliasKey != replacementKey else { continue }
                guard !seenAliases.contains(aliasKey) else { continue }

                seenAliases.insert(aliasKey)
                aliases.append(alias)
            }

            guard !aliases.isEmpty else { continue }

            if let index = mergedTerms.firstIndex(where: {
                normalizationKey(for: $0.text) == replacementKey
            }) {
                mergedTerms[index] = mergeAliases(aliases, into: mergedTerms[index])
                continue
            }

            mergedTerms.append(
                ParakeetVocabularyTerm(
                    text: replacement,
                    aliases: aliases
                )
            )
        }

        return mergedTerms
    }

    static func normalizedTerms(from terms: [ParakeetVocabularyTerm]) -> [ParakeetVocabularyTerm] {
        var normalizedTerms: [ParakeetVocabularyTerm] = []

        for term in terms {
            let text = normalized(term.text)
            guard !text.isEmpty else { continue }

            let textKey = normalizationKey(for: text)
            var aliases: [String] = []
            var seenAliases = Set<String>()

            for aliasValue in term.aliases {
                let alias = normalized(aliasValue)
                guard !alias.isEmpty else { continue }

                let aliasKey = normalizationKey(for: alias)
                guard aliasKey != textKey else { continue }
                guard !seenAliases.contains(aliasKey) else { continue }

                seenAliases.insert(aliasKey)
                aliases.append(alias)
            }

            let normalizedTerm = ParakeetVocabularyTerm(
                text: text,
                aliases: aliases,
                weight: term.weight
            )

            if let index = normalizedTerms.firstIndex(where: {
                normalizationKey(for: $0.text) == textKey
            }) {
                normalizedTerms[index] = mergeAliases(
                    normalizedTerm.aliases,
                    into: normalizedTerms[index]
                )
                continue
            }

            normalizedTerms.append(normalizedTerm)
        }

        return normalizedTerms
    }

    static func mergeAliases(
        _ aliases: [String],
        into existingTerm: ParakeetVocabularyTerm
    ) -> ParakeetVocabularyTerm {
        var mergedAliases = existingTerm.aliases
        var seenAliases = Set(mergedAliases.map(normalizationKey(for:)))

        for alias in aliases {
            let aliasKey = normalizationKey(for: alias)
            guard !seenAliases.contains(aliasKey) else { continue }

            seenAliases.insert(aliasKey)
            mergedAliases.append(alias)
        }

        return ParakeetVocabularyTerm(
            text: existingTerm.text,
            aliases: mergedAliases,
            weight: existingTerm.weight
        )
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizationKey(for value: String) -> String {
        normalized(value).folding(options: [.caseInsensitive], locale: nil)
    }
}
