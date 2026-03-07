import XCTest
@testable import FalaCore

final class MLXSmokeTests: XCTestCase {
    func testMLXQwenSmoke() async throws {
        let hasXcodeBundle = Bundle.allBundles.contains {
            $0.bundleURL.pathExtension == "xctest" && $0.bundleURL.path.contains(".xcodebuild-tests")
        }
        guard hasXcodeBundle else {
            throw XCTSkip("MLX smoke desabilitado neste processo. Use scripts/test-mlx.sh.")
        }

        guard MLXRuntimeSupport.defaultMetallibURL() != nil else {
            throw XCTSkip("MLX runtime ausente neste processo. Rode via xcodebuild para validar o smoke test.")
        }

        let modelID = "mlx-community/Qwen2.5-3B-Instruct-4bit"
        let modelDir = await MLXModelManager.modelDir(for: modelID)
        let hasSafetensors = ((try? FileManager.default.contentsOfDirectory(
            at: modelDir,
            includingPropertiesForKeys: nil
        )) ?? []).contains(where: { $0.pathExtension == "safetensors" })
        guard hasSafetensors else {
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
