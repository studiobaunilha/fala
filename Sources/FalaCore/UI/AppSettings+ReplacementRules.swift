import Foundation

public extension AppSettings {
    @discardableResult
    func addReplacementRule(variant: String, replacement: String) -> Bool {
        var rules = ReplacementRuleSet(replacementRules)
        let didChange = rules.upsert(variant: variant, replacement: replacement)
        if didChange {
            replacementRules = rules.rules
        }
        return didChange
    }

    @discardableResult
    func removeReplacementVariant(_ variant: String, fromRuleID ruleID: UUID) -> Bool {
        var rules = ReplacementRuleSet(replacementRules)
        let didChange = rules.removeVariant(variant, fromRuleID: ruleID)
        if didChange {
            replacementRules = rules.rules
        }
        return didChange
    }

    @discardableResult
    func removeReplacementRule(id: UUID) -> Bool {
        var rules = ReplacementRuleSet(replacementRules)
        let didChange = rules.removeRule(id: id)
        if didChange {
            replacementRules = rules.rules
        }
        return didChange
    }
}
