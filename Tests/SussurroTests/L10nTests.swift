import XCTest
@testable import SussurroCore

final class L10nTests: XCTestCase {
    func testL10nResolvesStringsWithModuleBundle() {
        // Assert that the `L10n` Solid boundary correctly resolves strings
        // using the underlying `Bundle.module` injected by SwiftPM's resources
        // mapping, preventing "Bundle doesn't exist" crashes.
        let resolved = L10n("Usar Padrão do Sistema")
        
        // This confirms the string doesn't crash on resolution.
        XCTAssertEqual(resolved, "Usar Padrão do Sistema")
    }
}
