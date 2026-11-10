import XCTest
@testable import FalaCore

final class CorrectionLearningAnalyzerTests: XCTestCase {
    private let analyzer = CorrectionLearningAnalyzer()

    func testSingleWordCorrection() {
        let old = "O gato pulou"
        let new = "O cachorro pulou"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "gato")
        XCTAssertEqual(result?.corrected, "cachorro")
    }

    func testPureInsertionReturnsNil() {
        let old = "O rato roeu a roupa"
        let new = "O grande rato roeu a roupa"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testPrefixWordCorrection() {
        let old = "infelizmente isso aconteceu"
        let new = "felizmente isso aconteceu"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "infelizmente")
        XCTAssertEqual(result?.corrected, "felizmente")
    }

    func testTrailingCorrection() {
        let old = "vamos correr rapido"
        let new = "vamos correr rapidamente"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "rapido")
        XCTAssertEqual(result?.corrected, "rapidamente")
    }

    func testPunctuationDifferencesStillReturnCoreCorrection() {
        let old = "O gato pulou."
        let new = "O cachorro pulou!"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "gato")
        XCTAssertEqual(result?.corrected, "cachorro")
    }

    func testIdenticalStringsReturnNil() {
        let old = "texto igual"
        let new = "texto igual"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testTooManyChangesReturnsNil() {
        let old = "O gato preto cruzou a estrada de barro"
        let new = "A vaca branca pulou a cerca de madeira"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testMidWordCharacterReplacement() {
        let old = "A batata estava boa"
        let new = "A batada estava boa"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "batata")
        XCTAssertEqual(result?.corrected, "batada")
    }

    func testMultiWordReplacementIsSupported() {
        let old = "Precisamos falar com o git hub hoje"
        let new = "Precisamos falar com o GitHub hoje"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "git hub")
        XCTAssertEqual(result?.corrected, "GitHub")
    }

    func testPunctuationOnlyChangesReturnNil() {
        let old = "O gato pulou."
        let new = "O gato pulou!"
        let result = analyzer.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testCorrectionBelongsToInsertedTextWhenPhraseIsPresent() {
        let belongs = analyzer.correctionBelongsToInsertedText(
            "git hub",
            insertedText: "Precisamos revisar o git hub hoje"
        )

        XCTAssertTrue(belongs)
    }

    func testCorrectionBelongsToInsertedTextRejectsUnrelatedPhrase() {
        let belongs = analyzer.correctionBelongsToInsertedText(
            "planilha",
            insertedText: "Precisamos revisar o git hub hoje"
        )

        XCTAssertFalse(belongs)
    }

    func testCorrectionBelongsToInsertedTextIsCaseAndAccentInsensitive() {
        let belongs = analyzer.correctionBelongsToInsertedText(
            "acao rapida",
            insertedText: "Precisamos de uma Ação Rápida hoje"
        )

        XCTAssertTrue(belongs)
    }

    func testLearnedCorrectionReturnsNilWhenChangeDoesNotBelongToInsertedText() {
        let learned = analyzer.learnedCorrection(
            from: "texto com git hub",
            to: "texto com GitHub",
            insertedText: "texto sem relação"
        )

        XCTAssertNil(learned)
    }

    func testLearnedCorrectionUsesInsertedTextAsOwnershipCheck() {
        let learned = analyzer.learnedCorrection(
            from: "texto com git hub",
            to: "texto com GitHub",
            insertedText: "texto com git hub"
        )

        XCTAssertEqual(learned?.original, "git hub")
        XCTAssertEqual(learned?.corrected, "GitHub")
    }

    func testLearnedPhrasePreservesItsActualInternalPunctuation() {
        let learned = analyzer.learnedCorrection(
            from: "Fale com acme, inc hoje",
            to: "Fale com ACME hoje",
            insertedText: "Fale com acme, inc hoje"
        )

        XCTAssertEqual(learned?.original, "acme, inc")
        XCTAssertEqual(learned?.corrected, "ACME")
        let rules = [ReplacementRule(variants: [learned?.original ?? ""], replacement: learned?.corrected ?? "")]
        XCTAssertEqual(ReplacementRule.applyAll("Fale com acme, inc hoje", rules: rules), "Fale com ACME hoje")
    }

    func testSeparateEditsDoNotBecomeOneAutomaticReplacementRule() {
        XCTAssertNil(analyzer.learnedCorrection(
            from: "Nico e Ana chegaram",
            to: "Niko e Anna chegaram",
            insertedText: "Nico e Ana chegaram"
        ))
    }

    func testLearnedCorrectionKeepsCombiningMarksInOriginalWord() {
        let learned = analyzer.learnedCorrection(
            from: "Fale com cafe\u{301} hoje",
            to: "Fale com CaféCentral hoje",
            insertedText: "Fale com cafe\u{301} hoje"
        )

        XCTAssertEqual(learned?.original, "cafe\u{301}")
        XCTAssertEqual(learned?.corrected, "CaféCentral")
    }

    func testLearningRejectsATermWhoseTrailingSymbolsWouldBeLost() {
        XCTAssertNil(analyzer.learnedCorrection(
            from: "Use c mais hoje",
            to: "Use C++ hoje",
            insertedText: "Use c mais hoje"
        ))
    }
}
