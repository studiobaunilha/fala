import Foundation

extension AppConfig {
    // MARK: - Vocabulary Learning

    public mutating func addNewReplacementRule(from old: String, to new: String) {
        let variant = old.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = new.trimmingCharacters(in: .whitespacesAndNewlines)

        guard upsertReplacementRule(from: variant, to: replacement) else { return }
        save()
        print("[Fala] Saved learned correction: '\(variant)' -> '\(replacement)'")
    }

    @discardableResult
    mutating func upsertReplacementRule(from old: String, to new: String) -> Bool {
        let variant = old.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = new.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !variant.isEmpty, !replacement.isEmpty else { return false }
        guard variant.caseInsensitiveCompare(replacement) != .orderedSame else {
            return false
        }

        if let idx = replacementRules.firstIndex(where: {
            $0.replacement.caseInsensitiveCompare(replacement) == .orderedSame
        }) {
            if !replacementRules[idx].variants.contains(where: {
                $0.caseInsensitiveCompare(variant) == .orderedSame
            }) {
                replacementRules[idx].variants.append(variant)
                return true
            }
            return false
        }

        replacementRules.append(
            ReplacementRule(
                variants: [variant],
                replacement: replacement
            )
        )
        return true
    }
}
