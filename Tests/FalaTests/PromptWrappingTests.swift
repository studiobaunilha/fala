import XCTest
@testable import FalaCore

final class PromptWrappingTests: XCTestCase {

    // MARK: - PromptDefaults

    func testPromptDefaultsReturnsNilForNonLLMTemplates() {
        XCTAssertNil(PromptDefaults.resolved(for: "gemini", template: .raw))
        XCTAssertNil(PromptDefaults.resolved(for: "gemini", template: .translate))
    }

    func testPromptDefaultsReturnsEnglishForApple() {
        let prompt = PromptDefaults.resolved(for: "apple", template: .custom)
        XCTAssertNotNil(prompt)
        // Apple prompts are concise English
        XCTAssertTrue(prompt?.contains("Format") == true)
        XCTAssertFalse(prompt?.contains("REGRA CRÍTICA") == true)
    }

    func testPromptDefaultsReturnsPortugueseForCloud() {
        let prompt = PromptDefaults.resolved(for: "gemini", template: .custom)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt?.contains("REGRA CRÍTICA") == true)
    }

    func testPromptDefaultsReturnsConversationalForAskAI() {
        let prompt = PromptDefaults.resolved(for: "gemini", template: .askAI)
        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt?.contains("assistente") == true)
        XCTAssertFalse(prompt?.contains("REGRA CRÍTICA") == true)
    }

    // MARK: - stripLLMPreamble

    func testStripLLMPreambleRemovesCommonPrefixes() {
        let cases = [
            ("Aqui está o texto:\nHello world", "Hello world"),
            ("Entendi! Segue:\nFormatted text", "Formatted text"),
            ("Claro! Aqui vai:\nMy text", "My text")
        ]
        for (input, expected) in cases {
            let result = stripLLMPreamble(input)
            XCTAssertEqual(result, expected, "Failed for input: \(input)")
        }
    }

    func testStripLLMPreamblePreservesCleanText() {
        let clean = "This is already clean text without any preamble."
        XCTAssertEqual(stripLLMPreamble(clean), clean)
    }

    func testStripLLMPreambleRemovesThinkingTags() {
        let input = "<think>Let me analyze this text...</think>\nFormatted output here"
        XCTAssertEqual(stripLLMPreamble(input), "Formatted output here")
    }

    func testStripLLMPreambleRemovesMultilineThinkingTags() {
        let input = "<think>\nStep 1: Read the text\nStep 2: Format it\n</think>\nThe actual result"
        XCTAssertEqual(stripLLMPreamble(input), "The actual result")
    }

    func testStripLLMPreambleRemovesUnclosedThinkingTag() {
        let input = "<think>This model hit the token limit before finishing its thou"
        XCTAssertEqual(stripLLMPreamble(input), "")
    }

    func testStripLLMPreambleHandlesThinkingTagsFollowedByPreamble() {
        let input = "<think>Analyzing...</think>\nAqui está o texto:\nFormatted text"
        XCTAssertEqual(stripLLMPreamble(input), "Formatted text")
    }

    func testStripLLMPreamblePreservesTextWithoutThinkingTags() {
        let clean = "Normal text without any thinking tags"
        XCTAssertEqual(stripLLMPreamble(clean), clean)
    }

    // MARK: - DictationTemplate properties

    func testRequiresLLMForProcessingModes() {
        XCTAssertFalse(DictationTemplate.raw.requiresLLM)
        XCTAssertFalse(DictationTemplate.translate.requiresLLM)
        XCTAssertTrue(DictationTemplate.askAI.requiresLLM)
        XCTAssertTrue(DictationTemplate.custom.requiresLLM)
    }

    func testIsConversationalOnlyForAskAI() {
        for template in DictationTemplate.allCases {
            if template == .askAI {
                XCTAssertTrue(template.isConversational,
                              "\(template) should be conversational")
            } else {
                XCTAssertFalse(template.isConversational,
                               "\(template) should not be conversational")
            }
        }
    }

    func testDefaultSystemPromptNotNilForAskAI() {
        let prompt = DictationTemplate.askAI.defaultSystemPrompt
        XCTAssertNotNil(prompt, "askAI should have a default system prompt")
        if let prompt {
            XCTAssertFalse(prompt.isEmpty, "askAI default prompt should not be empty")
        }
    }

    func testDefaultSystemPromptNilForOtherModes() {
        XCTAssertNil(DictationTemplate.raw.defaultSystemPrompt)
        XCTAssertNil(DictationTemplate.translate.defaultSystemPrompt)
        XCTAssertNil(DictationTemplate.custom.defaultSystemPrompt)
    }

    func testAskAIPromptIsConversational() {
        guard let prompt = DictationTemplate.askAI.defaultSystemPrompt else {
            XCTFail("askAI should have a default prompt")
            return
        }
        // askAI prompt should instruct the model to RESPOND to questions
        XCTAssertTrue(prompt.contains("assistente") || prompt.contains("Responda"),
                      "askAI prompt should be conversational")
        // It should NOT contain anti-response instructions
        XCTAssertFalse(prompt.contains("NUNCA deve responder"))
        XCTAssertFalse(prompt.contains("NÃO é uma pergunta"))
    }

    // MARK: - LLMError

    func testMLXModelNotDownloadedErrorMessage() {
        let error = LLMError.mlxModelNotDownloaded("test-model")
        XCTAssertTrue(error.localizedDescription.contains("test-model"))
        XCTAssertTrue(error.localizedDescription.contains("Ajustes"))
    }

    func testMLXRuntimeUnavailableErrorMessage() {
        let error = LLMError.mlxRuntimeUnavailable
        XCTAssertTrue(error.localizedDescription.contains("MLX"))
        XCTAssertTrue(error.localizedDescription.contains("build") || error.localizedDescription.contains("atualize"))
    }

    func testAllTemplatesHaveIcons() {
        for template in DictationTemplate.allCases {
            XCTAssertFalse(template.icon.isEmpty,
                           "\(template) should have an icon")
        }
    }

    func testAllTemplatesHaveDescriptions() {
        for template in DictationTemplate.allCases {
            XCTAssertFalse(template.modeDescription.isEmpty,
                           "\(template) should have a description")
        }
    }
}
