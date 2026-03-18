import XCTest
@testable import FalaCore

final class ReplacementRuleSetTests: XCTestCase {
    func testUpsertAppendsNewRule() {
        var rules = ReplacementRuleSet()

        let didChange = rules.upsert(variant: "jirah", replacement: "JIRA")

        XCTAssertTrue(didChange)
        XCTAssertEqual(rules.rules.count, 1)
        XCTAssertEqual(rules.rules[0].variants, ["jirah"])
        XCTAssertEqual(rules.rules[0].replacement, "JIRA")
    }

    func testUpsertMergesVariantIntoExistingReplacementCaseInsensitively() {
        var rules = ReplacementRuleSet([
            ReplacementRule(variants: ["git hub"], replacement: "GitHub")
        ])

        let didChange = rules.upsert(variant: "git-hub", replacement: "github")

        XCTAssertTrue(didChange)
        XCTAssertEqual(rules.rules.count, 1)
        XCTAssertEqual(rules.rules[0].variants, ["git hub", "git-hub"])
        XCTAssertEqual(rules.rules[0].replacement, "GitHub")
    }

    func testUpsertIgnoresIdentityAfterTrimming() {
        var rules = ReplacementRuleSet()

        let didChange = rules.upsert(variant: " GitHub ", replacement: "github")

        XCTAssertFalse(didChange)
        XCTAssertTrue(rules.rules.isEmpty)
    }

    func testRemoveVariantDeletesRuleWhenLastVariantIsRemoved() {
        let rule = ReplacementRule(variants: ["jirah"], replacement: "JIRA")
        var rules = ReplacementRuleSet([rule])

        let didChange = rules.removeVariant("JIRAH", fromRuleID: rule.id)

        XCTAssertTrue(didChange)
        XCTAssertTrue(rules.rules.isEmpty)
    }

    func testRemoveVariantKeepsRuleWhenOtherVariantsRemain() {
        let rule = ReplacementRule(
            variants: ["git hub", "git-hub"],
            replacement: "GitHub"
        )
        var rules = ReplacementRuleSet([rule])

        let didChange = rules.removeVariant("git hub", fromRuleID: rule.id)

        XCTAssertTrue(didChange)
        XCTAssertEqual(rules.rules.count, 1)
        XCTAssertEqual(rules.rules[0].variants, ["git-hub"])
    }

    func testRemoveRuleDeletesMatchingIdentifier() {
        let first = ReplacementRule(variants: ["jira"], replacement: "JIRA")
        let second = ReplacementRule(variants: ["git hub"], replacement: "GitHub")
        var rules = ReplacementRuleSet([first, second])

        let didChange = rules.removeRule(id: first.id)

        XCTAssertTrue(didChange)
        XCTAssertEqual(rules.rules.count, 1)
        XCTAssertEqual(rules.rules[0].replacement, "GitHub")
    }
}
