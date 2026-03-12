import Foundation

public struct ReplacementRule: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var variants: [String]
    public var replacement: String

    public init(variants: [String], replacement: String) {
        self.id = UUID()
        self.variants = variants
        self.replacement = replacement
    }

    public static func applyAll(_ text: String, rules: [ReplacementRule]) -> String {
        var result = text
        for rule in rules {
            for variant in rule.variants where !variant.isEmpty {
                result = result.replacingOccurrences(
                    of: variant, with: rule.replacement, options: .caseInsensitive
                )
            }
        }
        return result
    }
}
