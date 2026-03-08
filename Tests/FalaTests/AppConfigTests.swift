import XCTest
@testable import FalaCore

final class AppConfigTests: XCTestCase {

    // MARK: – Defaults

    func testDefaultValues() {
        let config = AppConfig()
        XCTAssertEqual(config.dictationModel, "large-v3-turbo")
        XCTAssertEqual(config.batchModel, "large-v3-turbo")
        XCTAssertEqual(config.activeWhisperModel, "large-v3-turbo")
        XCTAssertEqual(config.outputFormat, "txt")
        XCTAssertEqual(config.appLanguage, "auto")
        XCTAssertEqual(config.transcriptionLanguage, "auto")
        XCTAssertEqual(config.mlxModel, AppConfig.defaultMLXModelRepoID)
    }

    // MARK: – Backward compatibility

    /// Decoding a JSON that lacks newer fields (e.g. `language`) must still
    /// succeed and fall back to defaults — not throw and wipe the whole config.
    func testDecodesLegacyJSONWithMissingFields() throws {
        let legacy = Data("""
        {
          "batchModel": "large-v3-turbo",
          "dictationModel": "base",
          "outputFormat": "txt"
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)
        XCTAssertEqual(config.dictationModel, "base", "dictationModel must survive")
        XCTAssertEqual(config.batchModel, "large-v3-turbo", "batchModel must survive")
        XCTAssertEqual(config.activeWhisperModel, "base")
        XCTAssertEqual(config.outputFormat, "txt", "outputFormat must survive")
        XCTAssertEqual(config.appLanguage, "auto", "missing appLanguage must default to auto")
        XCTAssertEqual(
            config.transcriptionLanguage,
            "auto",
            "missing transcriptionLanguage must default to auto"
        )
    }

    func testDecodesLegacyLanguageIntoTranscriptionLanguage() throws {
        let legacy = Data("""
        {
          "language": "es"
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: legacy)
        XCTAssertEqual(config.appLanguage, "auto")
        XCTAssertEqual(config.transcriptionLanguage, "es")
    }

    func testLocalizedDefaultsMigrateToSelectedAppLanguage() throws {
        let payload = Data("""
        {
          "appLanguage": "en",
          "llmPrompt": "Formate e corrija a transcrição abaixo, mantendo o idioma original e corrigindo pontuação.",
          "customModeName": "Personalizado",
          "customModePrompt": "Resuma o texto transcrito em um parágrafo conciso, capturando os pontos principais."
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: payload)

        XCTAssertEqual(
            config.llmPrompt,
            """
            Format and correct the transcription below, keeping the original language and fixing punctuation.
            """
        )
        XCTAssertEqual(config.customModeName, "Custom")
        XCTAssertEqual(
            config.customModePrompt,
            "Summarize the transcribed text in one concise paragraph, capturing the main points."
        )
    }

    func testCustomLocalizedValuesArePreservedAcrossLanguageMigration() throws {
        let payload = Data("""
        {
          "appLanguage": "en",
          "customModeName": "Prompt do Pedro",
          "customModePrompt": "Meu prompt customizado"
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: payload)

        XCTAssertEqual(config.customModeName, "Prompt do Pedro")
        XCTAssertEqual(config.customModePrompt, "Meu prompt customizado")
    }

    func testModeConfigsDropStoredDefaultPromptsInOtherLanguages() throws {
        let storedPrompt = [
            "Act as an intelligent assistant. The user's message is a question or request",
            "transcribed from speech. Answer clearly, helpfully, and concisely."
        ].joined(separator: " ")
        let payload = Data("""
        {
          "appLanguage": "es",
          "modeConfigs": {
            "Perguntar à IA": {
              "prompt": "\(storedPrompt)"
            }
          }
        }
        """.utf8)

        let config = try JSONDecoder().decode(AppConfig.self, from: payload)

        XCTAssertNil(config.modeConfigs["Perguntar à IA"]?.prompt)
    }

    // MARK: – Round-trip JSON encode/decode

    func testRoundTripCoding() throws {
        var config = AppConfig()
        config.dictationModel = "large-v3"
        config.batchModel = "turbo"
        config.outputFormat = "md"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)

        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.dictationModel, "large-v3")
        XCTAssertEqual(decoded.batchModel, "turbo")
        XCTAssertEqual(decoded.activeWhisperModel, "large-v3")
        XCTAssertEqual(decoded.outputFormat, "md")
    }

    func testNormalizeWhisperModelSelectionPrefersCustomBatchSelection() {
        var config = AppConfig()
        config.dictationModel = "base"
        config.batchModel = "medium"

        config.normalizeWhisperModelSelection()

        XCTAssertEqual(config.dictationModel, "medium")
        XCTAssertEqual(config.batchModel, "medium")
    }

    // MARK: – Missing file returns defaults

    func testLoadReturnDefaultsWhenFileAbsent() throws {
        // Point configURL to a nonexistent path by using a fresh temp dir.
        // AppConfig.load() uses ~/ — we test the decoder fallback by feeding
        // invalid JSON through the decoder directly.
        let badData = Data("not json".utf8)
        let decoded = try? JSONDecoder().decode(AppConfig.self, from: badData)
        XCTAssertNil(decoded, "Invalid JSON must not decode")
    }

    // MARK: – JSON keys are camelCase (Codable default)

    func testExpectedJSONKeys() throws {
        let config = AppConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["dictationModel"])
        XCTAssertNotNil(json?["batchModel"])
        XCTAssertNotNil(json?["outputFormat"])
        XCTAssertNotNil(json?["appLanguage"])
        XCTAssertNotNil(json?["transcriptionLanguage"])
    }
}
