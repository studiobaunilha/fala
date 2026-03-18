import Foundation

struct ReplacementRuleSet: Sendable, Equatable {
    private(set) var rules: [ReplacementRule]

    init(_ rules: [ReplacementRule] = []) {
        self.rules = rules
    }

    @discardableResult
    mutating func upsert(variant: String, replacement: String) -> Bool {
        let normalizedVariant = normalized(variant)
        let normalizedReplacement = normalized(replacement)

        guard !normalizedVariant.isEmpty, !normalizedReplacement.isEmpty else {
            return false
        }
        guard normalizedVariant.caseInsensitiveCompare(normalizedReplacement) != .orderedSame else {
            return false
        }

        if let index = rules.firstIndex(where: {
            $0.replacement.caseInsensitiveCompare(normalizedReplacement) == .orderedSame
        }) {
            if rules[index].variants.contains(where: {
                $0.caseInsensitiveCompare(normalizedVariant) == .orderedSame
            }) {
                return false
            }

            rules[index].variants.append(normalizedVariant)
            return true
        }

        rules.append(
            ReplacementRule(
                variants: [normalizedVariant],
                replacement: normalizedReplacement
            )
        )
        return true
    }

    @discardableResult
    mutating func removeRule(id: UUID) -> Bool {
        let originalCount = rules.count
        rules.removeAll { $0.id == id }
        return rules.count != originalCount
    }

    @discardableResult
    mutating func removeVariant(_ variant: String, fromRuleID ruleID: UUID) -> Bool {
        let normalizedVariant = normalized(variant)
        guard let ruleIndex = rules.firstIndex(where: { $0.id == ruleID }) else {
            return false
        }
        guard let variantIndex = rules[ruleIndex].variants.firstIndex(where: {
            $0.caseInsensitiveCompare(normalizedVariant) == .orderedSame
        }) else {
            return false
        }

        rules[ruleIndex].variants.remove(at: variantIndex)
        if rules[ruleIndex].variants.isEmpty {
            rules.remove(at: ruleIndex)
        }
        return true
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
