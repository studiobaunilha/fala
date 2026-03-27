import XCTest
@testable import FalaCore

final class SelectionCommandConfigTests: XCTestCase {
    func testAskAIModeMigratesToSelectionCommandConfigAndRawTemplate() throws {
        let payload = Data("""
        {
          "selectedDictationTemplate": "Perguntar à IA",
          "modeConfigs": {
            "Perguntar à IA": {
              "prompt": "Prompt antigo do askAI",
              "providerPrompts": {
                "gemini": "Prompt Gemini do askAI"
              }
            }
          }
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: payload)

        XCTAssertEqual(config.selectedDictationTemplate, .raw)
        XCTAssertEqual(config.selectionCommandConfig.prompt, "Prompt antigo do askAI")
        XCTAssertEqual(
            config.selectionCommandConfig.providerPrompts?["gemini"],
            "Prompt Gemini do askAI"
        )
    }

    func testEffectiveSelectionCommandConfigUsesProviderSpecificOverride() {
        var config = AppConfig()
        config.llmProvider = "gemini"
        config.geminiModel = "gemini-2.5-flash"
        config.selectionCommandConfig = SelectionCommandConfig(
            providerPrompts: [
                "gemini": "Prompt específico de seleção"
            ]
        )

        let effective = config.getEffectiveSelectionCommandConfig()

        XCTAssertEqual(effective.provider, "gemini")
        XCTAssertEqual(effective.model, "gemini-2.5-flash")
        XCTAssertEqual(effective.prompt, "Prompt específico de seleção")
    }
}
