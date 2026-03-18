import Foundation
import XCTest

final class LocalizedUISourceAuditTests: XCTestCase {
    func testUISourcesDoNotContainHardcodedUserFacingStrings() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = try swiftFiles(
            in: [
                repoRoot.appendingPathComponent("Sources/FalaCore/UI"),
                repoRoot.appendingPathComponent("Sources/FalaCore/App")
            ]
        )

        let uiLiteralPattern =
            #"\b(?:Text|Button|Label|Section|Picker|LabeledContent|TextField|SecureField|Toggle|"#
            + #"navigationTitle|help|alert|confirmationDialog)\(\s*"([^"]+)""#
        let menuItemLiteralPattern = #"NSMenuItem\s*\(\s*title:\s*"([^"]+)""#
        let menuLiteralPattern = #"NSMenu\s*\(\s*title:\s*"([^"]+)""#
        let patterns = [uiLiteralPattern, menuItemLiteralPattern, menuLiteralPattern]

        let regexes = try patterns.map { try NSRegularExpression(pattern: $0) }
        var violations: [String] = []

        for fileURL in files {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let fullRange = NSRange(source.startIndex..<source.endIndex, in: source)

            for regex in regexes {
                for match in regex.matches(in: source, range: fullRange) {
                    guard match.numberOfRanges > 1,
                          let range = Range(match.range(at: 1), in: source)
                    else {
                        continue
                    }

                    let literal = String(source[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !shouldIgnoreLiteral(literal) else { continue }
                    let relativePath = fileURL.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                    violations.append("\(relativePath): \(literal)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "UI/App sources still contain raw user-facing strings:\n\(violations.joined(separator: "\n"))"
        )
    }

    private func swiftFiles(in roots: [URL]) throws -> [URL] {
        var files: [URL] = []

        for root in roots {
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension == "swift" else { continue }
                files.append(fileURL)
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    private func shouldIgnoreLiteral(_ literal: String) -> Bool {
        let trimmed = literal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard !trimmed.contains(#"\("#) else { return true }

        return !trimmed.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
    }
}
