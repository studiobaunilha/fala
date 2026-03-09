import XCTest
@testable import FalaCore

final class LicenseManagerSecureStoreTests: LicenseManagerTestCase {
    @MainActor
    func testRestoreUsesSingleBatchedSecureStoreReadForPaidEntitlement() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Batch Read Mac",
            appVersion: "1.0.0"
        )

        let store = CountingSecureStore([
            "fala-entitlement-token": try signer.makePaidToken(
                deviceFingerprint: "batch-read-fingerprint",
                issuedAt: now,
                expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
            ),
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])

        let manager = LicenseManager(
            licensingClient: StubLicensingClient(),
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "batch-read-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(store.batchReadCallCount, 1)
        XCTAssertEqual(store.readCallCount, 0)
    }

    @MainActor
    func testRestoreMigratesLegacyTokenFromSingleBatchedRead() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        let legacyToken = try signer.makePaidToken(
            deviceFingerprint: "legacy-fingerprint",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
        )

        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Legacy Mac",
            appVersion: "1.0.0"
        )

        let store = CountingSecureStore([
            "fala-license-token": legacyToken,
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])

        let manager = LicenseManager(
            licensingClient: StubLicensingClient(),
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "legacy-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(store.batchReadCallCount, 1)
        XCTAssertEqual(store.readCallCount, 0)
        XCTAssertEqual(store.value(for: "fala-entitlement-token"), legacyToken)
        XCTAssertNil(store.value(for: "fala-license-token"))
    }

    @MainActor
    func testRestoreDoesNotRetrySecureStoreOperationsWhenBatchReadFails() {
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: EntitlementTokenSigner().publicKeyBase64,
            machineName: "Denied Mac",
            appVersion: "1.0.0"
        )

        let store = FailingBatchReadSecureStore()

        let manager = LicenseManager(
            licensingClient: StubLicensingClient(),
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "denied-fingerprint"),
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertEqual(manager.accessState, .unlicensed)
        XCTAssertEqual(store.batchReadCallCount, 1)
        XCTAssertEqual(store.readCallCount, 0)
        XCTAssertEqual(store.deleteCallCount, 0)
    }

    @MainActor
    func testManualRefreshReloadsSecureStoreAfterInitialBatchReadFailure() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Recovered Mac",
            appVersion: "1.0.0"
        )

        let originalToken = try signer.makePaidToken(
            deviceFingerprint: "recovered-fingerprint",
            issuedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60)
        )
        let refreshedToken = try signer.makePaidToken(
            deviceFingerprint: "recovered-fingerprint",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
        )
        let store = FlakyBatchReadSecureStore([
            "fala-entitlement-token": originalToken,
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { request in
            XCTAssertEqual(request.entitlementToken, originalToken)
            return makeGrant(
                token: refreshedToken,
                kind: .paid,
                email: "buyer@example.com",
                serverNow: now
            )
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "recovered-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertEqual(manager.accessState, .unlicensed)

        await manager.refreshEntitlement()

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(manager.accessState, .proActive)
        XCTAssertEqual(client.refreshRequests.count, 1)
        XCTAssertEqual(store.batchReadCallCount, 2)
        XCTAssertEqual(store.value(for: "fala-entitlement-token"), refreshedToken)
    }

    @MainActor
    func testLaunchReconciliationRetriesLicenseValidationAfterInitialBatchReadFailure() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Launch Retry Mac",
            appVersion: "1.0.0"
        )

        let originalToken = try signer.makePaidToken(
            deviceFingerprint: "launch-retry-fingerprint",
            issuedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60)
        )
        let refreshedToken = try signer.makePaidToken(
            deviceFingerprint: "launch-retry-fingerprint",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
        )
        let store = FlakyBatchReadSecureStore([
            "fala-entitlement-token": originalToken,
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { request in
            XCTAssertEqual(request.entitlementToken, originalToken)
            return makeGrant(
                token: refreshedToken,
                kind: .paid,
                email: "buyer@example.com",
                serverNow: now
            )
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "launch-retry-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertEqual(manager.accessState, .unlicensed)

        manager.reconcileEntitlementOnAppLaunch()

        let recovered = await eventually {
            manager.isPro && client.refreshRequests.count == 1
        }

        XCTAssertTrue(recovered)
        XCTAssertEqual(manager.accessState, .proActive)
        XCTAssertEqual(store.batchReadCallCount, 2)
        XCTAssertEqual(store.value(for: "fala-entitlement-token"), refreshedToken)
    }
}
