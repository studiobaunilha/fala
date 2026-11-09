import XCTest
@testable import FalaCore

final class L10nTests: XCTestCase {
    override func tearDown() {
        AppLocalization.apply(languageCode: "auto")
        super.tearDown()
    }

    func testL10nResolvesStringsWithModuleBundle() {
        AppLocalization.apply(languageCode: "en")
        XCTAssertEqual(L10n("Usar Padrão Global"), "Use Global Default")
        XCTAssertEqual(L10n("Atalhos do Sistema"), "System Shortcuts")
        XCTAssertEqual(L10n("Armazenamento"), "Storage")
    }

    func testL10nRespectsExplicitPortugueseAppLanguageOverride() {
        AppLocalization.apply(languageCode: "pt-BR")

        XCTAssertEqual(L10n("Atalhos do Sistema"), "Atalhos do Sistema")
        XCTAssertEqual(L10n("Armazenamento"), "Armazenamento")
        XCTAssertEqual(L10n("Salvar Transcrições"), "Salvar Transcrições")
    }

    func testL10nRespectsExplicitAppLanguageOverride() {
        AppLocalization.apply(languageCode: "en")

        XCTAssertEqual(L10n("Ajustes"), "Settings")
        XCTAssertEqual(L10n("Sobre"), "About")
        XCTAssertEqual(L10n("Idioma do Aplicativo"), "App Language")
        XCTAssertEqual(L10n("Atalhos do Sistema"), "System Shortcuts")
        XCTAssertEqual(L10n("Armazenamento"), "Storage")
        XCTAssertEqual(L10n("Salvar Transcrições"), "Save Transcriptions")
    }

    func testL10nRespectsSpanishAppLanguageOverride() {
        AppLocalization.apply(languageCode: "es")

        XCTAssertEqual(L10n("Ajustes"), "Ajustes")
        XCTAssertEqual(L10n("Sobre"), "Acerca de")
        XCTAssertEqual(L10n("Idioma do Aplicativo"), "Idioma de la aplicación")
        XCTAssertEqual(L10n("Atalhos do Sistema"), "Atajos del Sistema")
        XCTAssertEqual(L10n("Armazenamento"), "Almacenamiento")
        XCTAssertEqual(L10n("Salvar Transcrições"), "Guardar transcripciones")
    }

    func testL10nRespectsFrenchAppLanguageOverride() {
        AppLocalization.apply(languageCode: "fr")

        XCTAssertEqual(L10n("Ajustes"), "Réglages")
        XCTAssertEqual(L10n("Sobre"), "À propos")
        XCTAssertEqual(L10n("Idioma do Aplicativo"), "Langue de l\u{2019}application")
        XCTAssertEqual(L10n("Atalhos do Sistema"), "Raccourcis système")
        XCTAssertEqual(L10n("Armazenamento"), "Stockage")
        XCTAssertEqual(L10n("Salvar Transcrições"), "Enregistrer les transcriptions")
    }

    @MainActor
    func testLocalizationObserverInvalidatesWhenLanguageChanges() async {
        let observer = AppLocalizationObserver.shared
        let initialRevision = observer.revision

        AppLocalization.apply(languageCode: "en")
        await Task.yield()

        XCTAssertGreaterThan(observer.revision, initialRevision)

        AppLocalization.apply(languageCode: "auto")
    }
}
