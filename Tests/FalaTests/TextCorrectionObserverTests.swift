import XCTest
@testable import FalaCore

@MainActor
final class TextCorrectionObserverTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        TextCorrectionObserver.shared.stopMonitoring()
        TextCorrectionObserver.shared.onCorrectionDetected = nil
    }

    override func tearDown() async throws {
        TextCorrectionObserver.shared.stopMonitoring()
        TextCorrectionObserver.shared.onCorrectionDetected = nil
        try await super.tearDown()
    }

    func testSingleWordCorrection() {
        let old = "O gato pulou"
        let new = "O cachorro pulou"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "gato")
        XCTAssertEqual(result?.corrected, "cachorro")
    }

    func testPureInsertionReturnsNil() {
        let old = "O rato roeu a roupa"
        let new = "O grande rato roeu a roupa"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testPrefixWordCorrection() {
        let old = "infelizmente isso aconteceu"
        let new = "felizmente isso aconteceu"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "infelizmente")
        XCTAssertEqual(result?.corrected, "felizmente")
    }

    func testTrailingCorrection() {
        let old = "vamos correr rapido"
        let new = "vamos correr rapidamente"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "rapido")
        XCTAssertEqual(result?.corrected, "rapidamente")
    }

    func testPunctuationDifferencesStillReturnCoreCorrection() {
        let old = "O gato pulou."
        let new = "O cachorro pulou!"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "gato")
        XCTAssertEqual(result?.corrected, "cachorro")
    }

    func testIdenticalStringsReturnNil() {
        let old = "texto igual"
        let new = "texto igual"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testTooManyChangesReturnsNil() {
        let old = "O gato preto cruzou a estrada de barro"
        let new = "A vaca branca pulou a cerca de madeira"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testMidWordCharacterReplacement() {
        let old = "A batata estava boa"
        let new = "A batada estava boa"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "batata")
        XCTAssertEqual(result?.corrected, "batada")
    }

    func testMultiWordReplacementIsSupported() {
        let old = "Precisamos falar com o git hub hoje"
        let new = "Precisamos falar com o GitHub hoje"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertEqual(result?.original, "git hub")
        XCTAssertEqual(result?.corrected, "GitHub")
    }

    func testPunctuationOnlyChangesReturnNil() {
        let old = "O gato pulou."
        let new = "O gato pulou!"
        let result = TextCorrectionObserver.shared.extractCorrectionBase(
            oldText: old, newText: new
        )
        XCTAssertNil(result)
    }

    func testCorrectionBelongsToInsertedTextWhenPhraseIsPresent() {
        let belongs = TextCorrectionObserver.shared.correctionBelongsToInsertedText(
            "git hub",
            insertedText: "Precisamos revisar o git hub hoje"
        )

        XCTAssertTrue(belongs)
    }

    func testCorrectionBelongsToInsertedTextRejectsUnrelatedPhrase() {
        let belongs = TextCorrectionObserver.shared.correctionBelongsToInsertedText(
            "planilha",
            insertedText: "Precisamos revisar o git hub hoje"
        )

        XCTAssertFalse(belongs)
    }

    func testCorrectionBelongsToInsertedTextIsCaseAndAccentInsensitive() {
        let belongs = TextCorrectionObserver.shared.correctionBelongsToInsertedText(
            "acao rapida",
            insertedText: "Precisamos de uma Ação Rápida hoje"
        )

        XCTAssertTrue(belongs)
    }
}
