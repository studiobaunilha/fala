import XCTest
@testable import FalaCore

final class ParakeetVocabularyStoreTests: XCTestCase {
    func testInitBuildsUniqueTermsFromReplacementRules() {
        let rules = [
            ReplacementRule(variants: ["jirah", " JIRAH ", ""], replacement: "JIRA"),
            ReplacementRule(variants: ["git hub", "GitHub"], replacement: "GitHub"),
            ReplacementRule(variants: ["git-hub", "github"], replacement: " GitHub ")
        ]

        let store = ParakeetVocabularyStore(replacementRules: rules)

        XCTAssertEqual(
            store.terms,
            [
                ParakeetVocabularyTerm(text: "JIRA", aliases: ["jirah"]),
                ParakeetVocabularyTerm(text: "GitHub", aliases: ["git hub", "git-hub"])
            ]
        )
    }

    func testInitIgnoresRulesWithoutDistinctAliases() {
        let rules = [
            ReplacementRule(variants: [" GitHub "], replacement: "github"),
            ReplacementRule(variants: [" "], replacement: "JIRA")
        ]

        let store = ParakeetVocabularyStore(replacementRules: rules)

        XCTAssertTrue(store.isEmpty)
        XCTAssertTrue(store.terms.isEmpty)
    }

    func testContextReturnsNilWhenVocabularyIsEmpty() {
        let store = ParakeetVocabularyStore()

        XCTAssertNil(store.customVocabularyContext)
    }

    func testInitWithDirectTermsKeepsAliaslessBoostTerms() {
        let store = ParakeetVocabularyStore(
            terms: [
                ParakeetVocabularyTerm(text: "OpenAI")
            ]
        )

        XCTAssertEqual(store.terms, [ParakeetVocabularyTerm(text: "OpenAI")])
        XCTAssertEqual(store.customVocabularyContext?.terms.map { $0.text }, ["OpenAI"])
    }

    func testInitUnifiesExplicitTermsWithReplacementRules() {
        let store = ParakeetVocabularyStore(
            replacementRules: [
                ReplacementRule(variants: ["jirah"], replacement: "JIRA")
            ],
            explicitTerms: [
                ParakeetVocabularyTerm(text: "OpenAI")
            ]
        )

        XCTAssertEqual(
            store.terms,
            [
                ParakeetVocabularyTerm(text: "OpenAI"),
                ParakeetVocabularyTerm(text: "JIRA", aliases: ["jirah"])
            ]
        )
    }

    func testContextUsesTermsAndAliases() {
        let store = ParakeetVocabularyStore(
            replacementRules: [
                ReplacementRule(variants: ["jirah", "jee-ra"], replacement: "JIRA")
            ]
        )

        let context = store.customVocabularyContext

        XCTAssertEqual(context?.terms.map { $0.text }, ["JIRA"])
        XCTAssertEqual(context?.terms.first?.aliases ?? [], ["jirah", "jee-ra"])
    }
}
