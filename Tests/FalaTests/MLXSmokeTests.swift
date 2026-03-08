import XCTest
@testable import FalaCore

final class MLXSmokeTests: XCTestCase {
    func testMLXQwenCompactSmoke() async throws {
        try await assertSmoke(modelID: "mlx-community/Qwen3-4B-4bit")
    }

    func testMLXGemmaCompactSmoke() async throws {
        try await assertSmoke(modelID: "mlx-community/gemma-3-text-4b-it-4bit")
    }

    func testMLXLiquidCompactSmoke() async throws {
        try await assertSmoke(modelID: "mlx-community/LFM2-1.2B-4bit")
    }
}

private extension MLXSmokeTests {
    func assertSmoke(modelID: String) async throws {
        let hasXcodeBundle = Bundle.allBundles.contains {
            $0.bundleURL.pathExtension == "xctest" && $0.bundleURL.path.contains(".xcodebuild-tests")
        }
        guard hasXcodeBundle else {
            throw XCTSkip("MLX smoke desabilitado neste processo. Use scripts/test-mlx.sh.")
        }

        guard MLXRuntimeSupport.defaultMetallibURL() != nil else {
            throw XCTSkip("MLX runtime ausente neste processo. Rode via xcodebuild para validar o smoke test.")
        }

        let modelDir = await MLXModelManager.modelDir(for: modelID)
        guard MLXModelManager.isUsableModelDirectory(modelDir) else {
            throw XCTSkip("Modelo MLX de smoke não está baixado localmente.")
        }

        let prompt = "Você é um assistente objetivo. Responda em uma frase."
        let text = "Qual é a capital da França?"

        let output = try await TranscriptionJob.processWithMLX(
            text: text,
            prompt: prompt,
            modelID: modelID
        )

        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
