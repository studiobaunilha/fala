import Foundation

struct CorrectionLearningAnalyzer {
    struct LearnedCorrection: Equatable {
        let original: String
        let corrected: String
    }

    func learnedCorrection(
        from oldText: String,
        to newText: String,
        insertedText: String? = nil
    ) -> LearnedCorrection? {
        guard let diff = extractCorrectionBase(
            oldText: oldText,
            newText: newText
        ) else {
            return nil
        }

        if let insertedText,
           !correctionBelongsToInsertedText(
               diff.original,
               insertedText: insertedText
           ) {
            return nil
        }

        return LearnedCorrection(
            original: diff.original,
            corrected: diff.corrected
        )
    }

    /// Finds a small word-level correction between `oldText` and `newText`.
    /// Pure punctuation changes and pure insertions/deletions are ignored.
    func extractCorrectionBase(
        oldText: String,
        newText: String
    ) -> (original: String, corrected: String)? {
        guard oldText != newText else { return nil }

        let oldTokens = wordTokens(in: oldText)
        let newTokens = wordTokens(in: newText)

        guard !oldTokens.isEmpty || !newTokens.isEmpty else { return nil }
        guard oldTokens.map(\.raw) != newTokens.map(\.raw) else { return nil }

        var prefixLen = 0
        while prefixLen < oldTokens.count,
              prefixLen < newTokens.count,
              oldTokens[prefixLen].raw == newTokens[prefixLen].raw {
            prefixLen += 1
        }

        var suffixLen = 0
        while suffixLen < (oldTokens.count - prefixLen),
              suffixLen < (newTokens.count - prefixLen),
              oldTokens[oldTokens.count - 1 - suffixLen].raw
                == newTokens[newTokens.count - 1 - suffixLen].raw {
            suffixLen += 1
        }

        let oldDiff = Array(oldTokens[prefixLen..<(oldTokens.count - suffixLen)])
        let newDiff = Array(newTokens[prefixLen..<(newTokens.count - suffixLen)])

        guard !oldDiff.isEmpty, !newDiff.isEmpty else { return nil }
        guard oldDiff.count <= 3, newDiff.count <= 3 else { return nil }

        let original = oldDiff.map(\.raw).joined(separator: " ")
        let corrected = newDiff.map(\.raw).joined(separator: " ")

        guard original.count <= 40, corrected.count <= 40 else {
            return nil
        }

        return (original, corrected)
    }

    func correctionBelongsToInsertedText(
        _ original: String,
        insertedText: String
    ) -> Bool {
        let insertedTokens = wordTokens(in: insertedText).map(\.normalized)
        let originalTokens = wordTokens(in: original).map(\.normalized)

        guard !insertedTokens.isEmpty, !originalTokens.isEmpty else {
            return false
        }
        guard originalTokens.count <= insertedTokens.count else {
            return false
        }

        let lastStart = insertedTokens.count - originalTokens.count
        for start in 0...lastStart {
            let end = start + originalTokens.count
            if Array(insertedTokens[start..<end]) == originalTokens {
                return true
            }
        }
        return false
    }

    private func wordTokens(in text: String) -> [WordToken] {
        let pattern = #"[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)

        return regex.matches(in: text, range: range).map { match in
            let raw = nsText.substring(with: match.range)
            return WordToken(
                raw: raw,
                normalized: raw.folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: .current
                )
            )
        }
    }
}

private struct WordToken {
    let raw: String
    let normalized: String
}
