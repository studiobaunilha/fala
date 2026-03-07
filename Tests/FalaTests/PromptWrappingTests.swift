import XCTest
@testable import FalaCore

final class PromptWrappingTests: XCTestCase {

    // MARK: - wrapPromptForCleanOutput

    func testWrapPromptForCleanOutputCombinesPromptAndGlobal() {
        let result = wrapPromptForCleanOutput("Edit this text", globalPrompt: "Never respond")
        XCTAssertTrue(result.contains("Edit this text"))
        XCTAssertTrue(result.contains("Never respond"))
        XCTAssertTrue(result.contains("---"))
    }

    func testWrapPromptForCleanOutputPreservesOrder() {
        let result = wrapPromptForCleanOutput("FIRST", globalPrompt: "SECOND")
        guard let firstRange = result.range(of: "FIRST"),
              let secondRange = result.range(of: "SECOND") else {
            XCTFail("Expected both FIRST and SECOND in output")
            return
        }
        XCTAssertTrue(firstRange.lowerBound < secondRange.lowerBound,
                      "Prompt should come before globalPrompt")
    }

    // MARK: - wrapPromptForAppleIntelligence

    func testWrapPromptForAppleIntelligenceAddsTranscriptionContext() {
        let result = wrapPromptForAppleIntelligence("Clean the text")
        XCTAssertTrue(result.contains("Clean the text"))
        XCTAssertTrue(result.contains("transcrição"))
        XCTAssertTrue(result.contains("APENAS"))
    }

    func testWrapPromptForAppleIntelligenceDoesNotContainGlobalPrompt() {
        let result = wrapPromptForAppleIntelligence("Clean the text")
        // Should NOT contain the verbose globalSystemPrompt keywords
        XCTAssertFalse(result.contains("REGRA CRÍTICA"))
        XCTAssertFalse(result.contains("NUNCA deve responder"))
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
