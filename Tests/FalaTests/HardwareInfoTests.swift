import XCTest
@testable import FalaCore

final class HardwareInfoTests: XCTestCase {
    
    func testHardwareInfoM1FamiliesAreDetected() {
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "Mac13,1"),
            "M1 should be flagged"
        )
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "Mac14,2"),
            "M2 should be flagged"
        )
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "Mac15,4"),
            "M3 should be flagged"
        )
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "MacBookPro17,1"),
            "M1 Pro/Max laptops should be flagged"
        )
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "Macmini9,1"),
            "M1 MacMini should be flagged"
        )
        XCTAssertTrue(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "iMac21,1"),
            "M1 iMac should be flagged"
        )
    }
    
    func testHardwareInfoM4AndIntelAreIgnored() {
        XCTAssertFalse(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "Mac16,1"),
            "M4 should NOT be flagged"
        )
        XCTAssertFalse(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "x86_64"),
            "Intel should NOT be flagged"
        )
        XCTAssertFalse(
            HardwareInfo.isKnownToFreezeWhisperANE(forModel: "MacPro7,1"),
            "Intel Mac Pro should NOT be flagged"
        )
    }
}
