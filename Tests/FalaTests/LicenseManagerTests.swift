import XCTest
@testable import FalaCore

class LicenseManagerTestCase: XCTestCase {
    override func tearDown() {
        LicensingConfiguration.resetTestOverrides()
        super.tearDown()
    }
}

final class LicenseManagerActivationTests: LicenseManagerTestCase {
    @MainActor
    func testActivationPersistsStableDeviceFingerprint() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Test Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore()
        let client = StubLicensingClient()
        client.activateHandler = { request in
            let token = try signer.makePaidToken(
                deviceFingerprint: request.deviceFingerprint,
                issuedAt: now,
                expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
            )
            return makeGrant(token: token, kind: .paid, email: "buyer@example.com", serverNow: now)
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "stable-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: false
        )

        await manager.activate(activationCode: "FALA-AAAA-BBBB-CCCC")

        XCTAssertTrue(manager.isPro)
        XCTAssertEqual(client.activateRequests.first?.deviceFingerprint, "stable-fingerprint")
        XCTAssertEqual(store.value(for: "fala-license-server-time"), String(now.timeIntervalSince1970))
    }

    @MainActor
    func testDeactivateClearsLocalStateOnlyAfterBackendSuccess() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Deactivate Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore([
            "fala-entitlement-token": try signer.makePaidToken(
                deviceFingerprint: "deactivate-fingerprint",
                issuedAt: now,
                expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
            ),
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.deactivateHandler = { _ in
            throw StubError.expectedFailure
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "deactivate-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        await manager.deactivate()
        XCTAssertTrue(manager.isPro)
        XCTAssertNotNil(store.value(for: "fala-entitlement-token"))

        client.deactivateHandler = { _ in }
        await manager.deactivate()

        XCTAssertFalse(manager.isPro)
        XCTAssertNil(store.value(for: "fala-entitlement-token"))
        XCTAssertNil(store.value(for: "fala-entitlement-email"))
    }

    @MainActor
    func testPaidLeaseUses14DaysAndEntersGraceOnTransientFailure() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Paid Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore([
            "fala-entitlement-token": try signer.makePaidToken(
                deviceFingerprint: "paid-fingerprint",
                issuedAt: now.addingTimeInterval(-16 * 24 * 60 * 60),
                expiresAt: now.addingTimeInterval(-30)
            ),
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { _ in
            throw LicenseError.networkUnavailable
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "paid-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertEqual(manager.accessState, .proGracePeriod)
        XCTAssertTrue(manager.isActivated)
        XCTAssertNotNil(manager.gracePeriodEndsAt)
        XCTAssertEqual(manager.nextOnlineValidationAt, Date(timeIntervalSince1970: now.timeIntervalSince1970 - 30))
    }

    @MainActor
    func testRevokedPaidLicenseDropsLocalAccessAfterRefreshFailure() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Revoked Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore([
            "fala-entitlement-token": try signer.makePaidToken(
                deviceFingerprint: "revoked-fingerprint",
                issuedAt: now.addingTimeInterval(-15 * 24 * 60 * 60),
                expiresAt: now.addingTimeInterval(-60)
            ),
            "fala-entitlement-email": "buyer@example.com",
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { _ in
            throw LicenseError.apiFailure(code: "license_revoked", message: "revoked")
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "revoked-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        let didDrop = await eventually {
            manager.isActivated == false && manager.accessState == .expired
        }

        XCTAssertTrue(didDrop)
        XCTAssertNil(store.value(for: "fala-entitlement-token"))
    }
}

final class LicenseManagerTrialTests: LicenseManagerTestCase {
    @MainActor
    func testVerifiedTrialStartsAutomaticallyWhenNoEntitlementExists() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Trial Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore()
        let client = StubLicensingClient()
        client.trialHandler = { request in
            let token = try signer.makeTrialToken(
                deviceFingerprint: request.deviceFingerprint,
                issuedAt: now,
                expiresAt: now.addingTimeInterval(24 * 60 * 60),
                trialEndsAt: now.addingTimeInterval(7 * 24 * 60 * 60)
            )
            return makeGrant(token: token, kind: .trial, serverNow: now)
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "trial-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        let didStartTrial = await eventually {
            manager.isTrialActive && client.trialRequests.count == 1
        }

        XCTAssertTrue(didStartTrial)
        XCTAssertEqual(manager.accessState, .trialActive)
        XCTAssertEqual(manager.trialDaysRemaining, 7)
        XCTAssertEqual(client.trialRequests.first?.deviceFingerprint, "trial-fingerprint")
    }

    @MainActor
    func testExpiredTrialLeaseRequiresOnlineRefresh() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_305_600)
        let trialEnd = now.addingTimeInterval(3 * 24 * 60 * 60)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Trial Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore([
            "fala-entitlement-token": try signer.makeTrialToken(
                deviceFingerprint: "trial-fingerprint",
                issuedAt: now.addingTimeInterval(-48 * 60 * 60),
                expiresAt: now.addingTimeInterval(-60),
                trialEndsAt: trialEnd
            ),
            "fala-license-server-time": String(now.timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { _ in
            throw LicenseError.networkUnavailable
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "trial-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        let needsConnection = await eventually {
            manager.accessState == .needsConnection &&
            manager.isActivated == false &&
            client.refreshRequests.count == 1
        }

        XCTAssertTrue(needsConnection)
        XCTAssertEqual(client.refreshRequests.count, 1)
    }

    @MainActor
    func testClockRollbackRequiresOnlineValidation() async throws {
        let signer = EntitlementTokenSigner()
        let now = Date(timeIntervalSince1970: 1_741_219_200)
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev"),
            entitlementPublicKeyBase64: signer.publicKeyBase64,
            machineName: "Rollback Mac",
            appVersion: "1.0.0"
        )

        let store = InMemorySecureStore([
            "fala-entitlement-token": try signer.makePaidToken(
                deviceFingerprint: "rollback-fingerprint",
                issuedAt: now,
                expiresAt: now.addingTimeInterval(14 * 24 * 60 * 60)
            ),
            "fala-license-server-time": String(now.addingTimeInterval(10 * 60).timeIntervalSince1970)
        ])
        let client = StubLicensingClient()
        client.refreshHandler = { _ in
            throw LicenseError.networkUnavailable
        }

        let manager = LicenseManager(
            licensingClient: client,
            secureStore: store,
            deviceFingerprintProvider: StubDeviceFingerprintProvider(fingerprint: "rollback-fingerprint"),
            now: { now },
            shouldRestoreStateOnLaunch: true
        )

        XCTAssertEqual(manager.accessState, .needsConnection)
        XCTAssertTrue(manager.requiresOnlineValidation)
        XCTAssertFalse(manager.isActivated)
    }
}
