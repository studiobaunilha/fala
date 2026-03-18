import Foundation

extension AppConfig {
    // MARK: - Vocabulary Learning

    public mutating func addNewReplacementRule(from old: String, to new: String) {
        guard upsertReplacementRule(from: old, to: new) else { return }
        save()
        print("[Fala] Saved learned correction: '\(old)' -> '\(new)'")
    }

    @discardableResult
    mutating func upsertReplacementRule(from old: String, to new: String) -> Bool {
        var rules = ReplacementRuleSet(replacementRules)
        let didChange = rules.upsert(variant: old, replacement: new)
        if didChange {
            replacementRules = rules.rules
        }
        return didChange
    }
}
