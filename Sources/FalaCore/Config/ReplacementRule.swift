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
        var matches: [ReplacementMatch] = []
        for rule in rules {
            for variant in rule.variants where !variant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                for range in wholeTermRanges(of: variant, in: text) {
                    matches.append(ReplacementMatch(
                        range: range,
                        replacement: rule.replacement,
                        priority: matches.count
                    ))
                }
            }
        }
        matches.sort {
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            if $0.range.length != $1.range.length {
                return $0.range.length > $1.range.length
            }
            return $0.priority < $1.priority
        }

        let source = text as NSString
        var result = ""
        var offset = 0
        // Match the original once: inserted output must never trigger another rule.
        for match in matches where match.range.location >= offset {
            result += source.substring(with: NSRange(location: offset, length: match.range.location - offset))
            result += match.replacement
            offset = NSMaxRange(match.range)
        }
        result += source.substring(from: offset)
        return result
    }

    private static func wholeTermRanges(of variant: String, in text: String) -> [NSRange] {
        let source = text as NSString
        var ranges: [NSRange] = []
        var offset = 0
        while offset < source.length {
            let match = source.range(
                of: variant,
                options: .caseInsensitive,
                range: NSRange(location: offset, length: source.length - offset)
            )
            guard match.location != NSNotFound, match.length > 0 else { break }
            if let range = Range(match, in: text),
               !isWordContinuation(text[..<range.lowerBound].unicodeScalars.last),
               !isWordContinuation(text[range.upperBound...].unicodeScalars.first) {
                ranges.append(match)
            }
            offset = match.location + 1
        }
        return ranges
    }

    private static func isWordContinuation(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
            || CharacterSet.nonBaseCharacters.contains(scalar)
            || scalar.properties.generalCategory == .connectorPunctuation
            || scalar.value == 0x200C || scalar.value == 0x200D
    }
}

private struct ReplacementMatch {
    let range: NSRange
    let replacement: String
    let priority: Int
}
