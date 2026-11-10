import XCTest
@testable import FalaCore

final class ReplacementRuleTests: XCTestCase {
    func testNameCorrectionDoesNotChangePartOfAnotherWord() {
        let rules = [ReplacementRule(variants: ["Nico"], replacement: "Niko")]

        XCTAssertEqual(
            ReplacementRule.applyAll("Eu comunico com Nico", rules: rules),
            "Eu comunico com Niko"
        )
    }

    func testReplacementOutputIsNotRewrittenByAnotherRule() {
        let rules = [
            ReplacementRule(variants: ["Nico"], replacement: "Niko"),
            ReplacementRule(variants: ["Niko"], replacement: "Nicolau")
        ]

        XCTAssertEqual(
            ReplacementRule.applyAll("Nico e Niko", rules: rules),
            "Niko e Nicolau"
        )
    }

    func testLongerPhraseWinsOverItsComponentWord() {
        let rules = [
            ReplacementRule(variants: ["git"], replacement: "Git"),
            ReplacementRule(variants: ["git hub"], replacement: "GitHub")
        ]

        XCTAssertEqual(ReplacementRule.applyAll("git hub e git", rules: rules), "GitHub e Git")
    }

    func testUnicodeBoundariesPreserveLargerWordsAndIdentifiers() {
        let rules = [ReplacementRule(variants: ["Nico"], replacement: "Niko")]

        XCTAssertEqual(
            ReplacementRule.applyAll(
                "Nicolas, comunico, econômico, áNico, Nico2, _Nico, Nico_, Nico\u{301}, Nico\u{200D}x; \u{1F44B} NICO!",
                rules: rules
            ),
            "Nicolas, comunico, econômico, áNico, Nico2, _Nico, Nico_, Nico\u{301}, Nico\u{200D}x; \u{1F44B} Niko!"
        )
    }

    func testVariantsAndReplacementSymbolsAreLiteral() {
        let rules = [ReplacementRule(variants: ["C++", "Nico"], replacement: #"$1\path"#)]

        XCTAssertEqual(
            ReplacementRule.applyAll("C++ e C.x (Nico)", rules: rules),
            #"$1\path e C.x ($1\path)"#
        )
    }

    func testCanonicallyEquivalentAccentsAndReplacementCaseArePreserved() {
        let rules = [ReplacementRule(variants: ["café"], replacement: "CaféCentral")]

        XCTAssertEqual(
            ReplacementRule.applyAll("cafe\u{301}, CAFÉ e cafe", rules: rules),
            "CaféCentral, CaféCentral e cafe"
        )
    }

    func testLegacyRulesKeepIdentifiersAndUseSafeMatchingAfterDecoding() throws {
        let json = #"[{"id":"0E49DCEE-2235-4F5A-9EC8-91A722B1B14E","variants":["Nico",""],"replacement":"Niko"}]"#
        let rules = try JSONDecoder().decode([ReplacementRule].self, from: Data(json.utf8))

        XCTAssertEqual(rules[0].id.uuidString, "0E49DCEE-2235-4F5A-9EC8-91A722B1B14E")
        XCTAssertEqual(ReplacementRule.applyAll("comunico com Nico", rules: rules), "comunico com Niko")
        let roundTrip = try JSONDecoder().decode([ReplacementRule].self, from: JSONEncoder().encode(rules))
        XCTAssertEqual(roundTrip, rules)
    }

    func testConflictingLegacyVariantsUseConfiguredOrderWithoutCascading() {
        let rules = [
            ReplacementRule(variants: ["Nico"], replacement: "Niko"),
            ReplacementRule(variants: ["nico"], replacement: "Nicolau")
        ]

        XCTAssertEqual(ReplacementRule.applyAll("Nico, Nico!", rules: rules), "Niko, Niko!")
    }

    func testEmptyAndWhitespaceOnlyVariantsCannotRewriteSpacing() {
        let rules = [ReplacementRule(variants: ["", "  "], replacement: "Niko")]

        XCTAssertEqual(ReplacementRule.applyAll("  ", rules: rules), "  ")
    }
}
