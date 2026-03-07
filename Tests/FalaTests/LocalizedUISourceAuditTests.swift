import Foundation
import XCTest

final class LocalizedUISourceAuditTests: XCTestCase {
    func testCriticalViewsDoNotContainHardcodedUserFacingStrings() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let files = [
            "Sources/FalaCore/App/AppMainMenu.swift",
            "Sources/FalaCore/UI/StatusBarController.swift",
            "Sources/FalaCore/UI/SettingsView.swift",
            "Sources/FalaCore/UI/SettingsView+Ext.swift",
            "Sources/FalaCore/UI/SettingsView+LLM.swift",
            "Sources/FalaCore/UI/SettingsView+LLMProviders.swift",
            "Sources/FalaCore/UI/SettingsView+License.swift",
            "Sources/FalaCore/UI/SettingsView+Modes.swift",
            "Sources/FalaCore/UI/SettingsView+Updates.swift",
            "Sources/FalaCore/UI/SettingsWindowController.swift",
            "Sources/FalaCore/UI/TranscribeWindowController.swift"
        ].map { repoRoot.appendingPathComponent($0) }

        let uiLiteralPattern =
            #"\b(?:Text|Button|Label|Section|Picker|LabeledContent|"#
            + #"TextField|SecureField|navigationTitle|help)\(\s*"([^"]+)""#
        let menuLiteralPattern = #"NSMenuItem\s*\(\s*title:\s*"([^"]+)""#
        let patterns = [uiLiteralPattern, menuLiteralPattern]

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
                    guard !literal.isEmpty else { continue }
                    guard !literal.contains(#"\("#) else { continue }
                    violations.append("\(fileURL.lastPathComponent): \(literal)")
                }
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Critical UI files still contain raw user-facing strings:\n\(violations.joined(separator: "\n"))"
        )
    }
}
