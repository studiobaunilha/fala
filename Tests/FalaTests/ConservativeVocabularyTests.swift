import Foundation
import FluidAudio
import XCTest
@testable import FalaCore

final class ConservativeVocabularyTests: XCTestCase, @unchecked Sendable {
    func testDeclaredRulesPreserveOtherWordsAndCanonicalizeAliases() {
        let rules = [ReplacementRule(variants: ["Maqui", "Maki"], replacement: "Qanty")]
        let unchanged = ["aqui", "Aqui!", "estou aqui agora", "maquiagem", "maquiavel", "comunico", "MakiExtra"]
        for text in unchanged {
            XCTAssertEqual(ReplacementRule.applyAll(text, rules: rules), text)
        }
        XCTAssertEqual(ReplacementRule.applyAll("MAQUI, Maki!", rules: rules), "Qanty, Qanty!")
    }

    func testNativeTermsRequireDeclaredSpellingForRulesAndExplicitTerms() throws {
        let store = ParakeetVocabularyStore(
            replacementRules: [ReplacementRule(variants: ["Maqui"], replacement: "Qanty")],
            explicitTerms: [ParakeetVocabularyTerm(text: "CloudCode", aliases: ["cloud code"])]
        )
        let terms = try XCTUnwrap(store.customVocabularyContext).terms
        XCTAssertEqual(terms.count, 2)
        for term in terms {
            XCTAssertEqual(term.minSimilarity, 1, term.text)
        }
        XCTAssertEqual(terms.first?.aliases, ["cloud code"])
        XCTAssertEqual(terms.last?.aliases, ["Maqui"])
    }

    private var replayFixtures: [(ParakeetVocabularyTerm, [(String, String)])] {
        [
            (.init(text: "Qanty", aliases: ["Maqui", "Maki"]), [
                ("aqui", "aqui"), ("Aqui!", "Aqui!"), ("estou aqui agora", "estou aqui agora"),
                ("maquiagem", "maquiagem"), ("maquiavel", "maquiavel"), ("comunico", "comunico"),
                ("MakiExtra", "MakiExtra"), ("préMaqui", "préMaqui"),
                ("Maqui", "Qanty"), ("Maki", "Qanty"), ("MAQUI!", "Qanty!"),
                ("Ma qui", "Qanty"), ("Qanty", "Qanty")
            ]),
            (.init(text: "CloudCode", aliases: ["cloud code"]), [
                ("cloud code", "CloudCode"), ("cloud codec", "cloud codec"),
                ("cloud coder", "cloud coder"), ("cloud", "cloud")
            ]),
            (.init(text: "CaféTools", aliases: ["café tool"]), [
                ("CAFÉ TOOL", "CaféTools"), ("cafe\u{301} tool", "CaféTools"),
                ("cafe tool", "cafe tool")
            ])
        ]
    }

    // Synthetic decoder disagreement exercises the real pinned SDK, with no audio inference.
    // Opt in only where CTC models are already installed; never download them from a test.
    func testNativeConsumerReplayPreservesUnlistedLetters() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FALA_RUN_VOCABULARY_REPLAY"] == "1")
        let directory = CtcModels.defaultCacheDirectory()
        try XCTSkipUnless(CtcModels.modelsExist(at: directory), "Cached CTC models required")
        let models = try await CtcModels.loadDirect(from: directory)
        let tokenizer = try await CtcTokenizer.load(from: directory)
        let spotter = CtcKeywordSpotter(models: models)
        for (fixture, cases) in replayFixtures {
            let native = try XCTUnwrap(ParakeetVocabularyStore(terms: [fixture]).customVocabularyContext)
            let term = try XCTUnwrap(native.terms.first)
            let tokens = tokenizer.encode(term.text)
            let tokenized = CustomVocabularyContext(terms: [CustomVocabularyTerm(
                text: term.text, weight: term.weight, aliases: term.aliases,
                ctcTokenIds: tokens, minSimilarity: term.minSimilarity
            )])
            let width = max(1025, (tokens.max() ?? 0) + 1)
            var probabilities = [[Float]](repeating: [Float](repeating: -30, count: width), count: 100)
            for frame in probabilities.indices { probabilities[frame][1024] = -0.01 }
            for (index, token) in tokens.enumerated() {
                for frame in (10 + index * 5)..<(14 + index * 5) {
                    probabilities[frame][token] = -0.01
                    probabilities[frame][1024] = -8
                }
            }
            for rescue in [true, false] {
                let rescorer = try await VocabularyRescorer.create(
                    spotter: spotter, vocabulary: tokenized,
                    config: .init(spotterRescueEnabled: rescue), ctcModelDirectory: directory
                )
                for (base, expected) in cases {
                    let words = base.split(separator: " ")
                    let timings = words.enumerated().map { index, word in
                        TokenTiming(
                            token: "▁" + String(word), tokenId: index + 1,
                            startTime: Double(index) * 0.2, endTime: Double(index + 1) * 0.2,
                            confidence: 1
                        )
                    }
                    let output = rescorer.ctcTokenRescore(
                        transcript: base, tokenTimings: timings, logProbs: probabilities,
                        frameDuration: 0.01, cbw: 0, minSimilarity: 0.7
                    )
                    XCTAssertEqual(output.text, expected, "base=\(base), rescue=\(rescue)")
                }
            }
        }
    }
}
