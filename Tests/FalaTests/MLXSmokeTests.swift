import XCTest
@testable import FalaCore

final class MLXSmokeTests: XCTestCase {
    func testRunFailsWhenArgumentsAreProvided() async {
        let mode = MLXSmokeMode(
            candidateModels: ["mlx-community/Qwen3-4B-4bit"],
            resolveAvailableModels: { _ in [] },
            generate: { _, _, _ in "" },
            logger: { _ in }
        )

        do {
            try await mode.run(arguments: ["--unexpected"])
            XCTFail("Expected unsupported arguments error.")
        } catch {
            XCTAssertEqual(
                error as? MLXSmokeModeError,
                .unsupportedArguments(["--unexpected"])
            )
        }
    }

    func testRunFailsWhenNoLocalModelIsAvailable() async {
        let candidates = ["mlx-community/Qwen3-4B-4bit"]
        let mode = MLXSmokeMode(
            candidateModels: candidates,
            resolveAvailableModels: { _ in [] },
            generate: { _, _, _ in "" },
            logger: { _ in }
        )

        do {
            try await mode.run()
            XCTFail("Expected noLocalModels error.")
        } catch {
            XCTAssertEqual(error as? MLXSmokeModeError, .noLocalModels(candidates))
        }
    }

    func testRunExercisesEveryAvailableModel() async throws {
        let expectedModels = [
            "mlx-community/Qwen3-4B-4bit",
            "mlx-community/LFM2-1.2B-4bit"
        ]
        let recorder = SmokeInvocationRecorder()
        let mode = MLXSmokeMode(
            candidateModels: [
                "mlx-community/Qwen3-4B-4bit",
                "mlx-community/gemma-3-text-4b-it-4bit",
                "mlx-community/LFM2-1.2B-4bit"
            ],
            resolveAvailableModels: { candidates in
                XCTAssertEqual(
                    candidates,
                    [
                        "mlx-community/Qwen3-4B-4bit",
                        "mlx-community/gemma-3-text-4b-it-4bit",
                        "mlx-community/LFM2-1.2B-4bit"
                    ]
                )
                return expectedModels
            },
            generate: { modelID, prompt, text in
                await recorder.record(modelID: modelID, prompt: prompt, text: text)
                return "Paris."
            },
            logger: { _ in }
        )

        try await mode.run()

        let invocations = await recorder.invocations
        XCTAssertEqual(invocations.map(\.modelID), expectedModels)
        XCTAssertEqual(Set(invocations.map(\.prompt)), [MLXSmokeMode.defaultPrompt])
        XCTAssertEqual(Set(invocations.map(\.text)), [MLXSmokeMode.defaultInput])
    }

    func testRunRejectsEmptyResponses() async {
        let mode = MLXSmokeMode(
            candidateModels: ["mlx-community/Qwen3-4B-4bit"],
            resolveAvailableModels: { _ in ["mlx-community/Qwen3-4B-4bit"] },
            generate: { _, _, _ in "   \n" },
            logger: { _ in }
        )

        do {
            try await mode.run()
            XCTFail("Expected emptyResponse error.")
        } catch {
            XCTAssertEqual(
                error as? MLXSmokeModeError,
                .emptyResponse("mlx-community/Qwen3-4B-4bit")
            )
        }
    }

    func testDefaultCandidateModelsTrackSmokeVerifiedCatalog() {
        XCTAssertEqual(
            Set(MLXSmokeMode().candidateModels),
            MLXCatalogManifestLoader.smokeVerifiedRecommendedRepoIDs
        )
    }
}

private actor SmokeInvocationRecorder {
    struct Invocation: Equatable {
        let modelID: String
        let prompt: String
        let text: String
    }

    private(set) var invocations: [Invocation] = []

    func record(modelID: String, prompt: String, text: String) {
        invocations.append(Invocation(modelID: modelID, prompt: prompt, text: text))
    }
}
