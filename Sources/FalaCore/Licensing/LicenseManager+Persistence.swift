import Foundation

extension LicenseManager {
    func resolveDeviceFingerprint() throws -> String {
        do {
            return try deviceFingerprintProvider.currentFingerprint()
        } catch {
            throw LicenseError.missingDeviceFingerprint
        }
    }

    func readStoredEntitlementToken(forceReload: Bool = false) throws -> String? {
        try loadStoredEntitlementSnapshot(forceReload: forceReload).resolvedEntitlementToken
    }

    func loadStoredPayload(forceReload: Bool = false) throws -> EntitlementPayload? {
        guard let token = try readStoredEntitlementToken(forceReload: forceReload) else {
            return nil
        }

        let deviceFingerprint = try resolveDeviceFingerprint()
        return try validateEntitlementToken(
            token,
            allowExpired: true,
            expectedDeviceFingerprint: deviceFingerprint
        )
    }

    func saveEntitlement(grant: EntitlementGrant, email: String?) throws {
        let normalizedEmail = email?.trimmedNonEmpty
        let serverTime = String(grant.serverNow.timeIntervalSince1970)

        try secureStore.save(token: grant.entitlementToken, for: entitlementTokenAccount)

        if let normalizedEmail {
            try secureStore.save(token: normalizedEmail, for: entitlementEmailAccount)
        } else {
            try? secureStore.delete(account: entitlementEmailAccount)
        }

        try secureStore.save(token: serverTime, for: lastKnownServerTimeAccount)
        try? secureStore.delete(account: legacyLicenseTokenAccount)
        storeEntitlementSnapshot(
            entitlementToken: grant.entitlementToken,
            entitlementEmail: normalizedEmail,
            lastKnownServerTime: serverTime
        )
    }

    func clearStoredEntitlement() throws {
        let lastKnownServerTime = try loadStoredEntitlementSnapshot().lastKnownServerTime
        try secureStore.delete(account: entitlementTokenAccount)
        try secureStore.delete(account: entitlementEmailAccount)
        try secureStore.delete(account: legacyLicenseTokenAccount)
        storeEntitlementSnapshot(
            entitlementToken: nil,
            entitlementEmail: nil,
            lastKnownServerTime: lastKnownServerTime
        )
    }

    func clearLocalEntitlementAndReset() {
        do {
            try clearStoredEntitlement()
        } catch {
            clearEntitlementSnapshot()
        }
        applyUnlicensedState()
    }

    func requestEntitlementRefresh(for token: String) async throws -> EntitlementPayload {
        if let activationAvailabilityMessage {
            throw LicenseError.configurationIssue(message: activationAvailabilityMessage)
        }

        let deviceFingerprint = try resolveDeviceFingerprint()
        let grant = try await licensingClient.refresh(
            entitlementToken: token,
            deviceFingerprint: deviceFingerprint,
            machineName: LicensingConfiguration.machineName(),
            appVersion: LicensingConfiguration.appVersion()
        )
        let payload = try validateEntitlementToken(
            grant.entitlementToken,
            allowExpired: false,
            expectedDeviceFingerprint: deviceFingerprint
        )

        try saveEntitlement(grant: grant, email: grant.email ?? payload.email)
        return payload
    }

    func handleRefreshFailure(_ licenseError: LicenseError) {
        let payload = try? loadStoredPayload()

        if let payload, applyTransientRefreshFailureIfPossible(payload, licenseError: licenseError) {
            return
        }

        if !licenseError.isTransient {
            try? clearStoredEntitlement()
        }

        guard let payload else {
            applyUnlicensedState()
            return
        }

        applyTerminalRefreshFailure(payload, licenseError: licenseError)
    }

    func applyTransientRefreshFailureIfPossible(
        _ payload: EntitlementPayload,
        licenseError: LicenseError
    ) -> Bool {
        guard licenseError.isTransient else {
            return false
        }

        if payload.entitlementKind == .paid,
           let gracePeriodEnd = paidGracePeriodEnd(for: payload),
           now() <= gracePeriodEnd {
            applyPaidEntitlement(payload, gracePeriodEnd: gracePeriodEnd)
            return true
        }

        if payload.entitlementKind == .trial,
           trialRemainsAvailable(payload) {
            applyNeedsConnectionState(from: payload)
            return true
        }

        return false
    }

    func applyTerminalRefreshFailure(
        _ payload: EntitlementPayload,
        licenseError: LicenseError
    ) {
        if payload.entitlementKind == .trial {
            if trialRemainsAvailable(payload) {
                applyNeedsConnectionState(from: payload)
            } else {
                applyExpiredState(from: payload)
            }
            return
        }

        if licenseError.isTransient {
            applyNeedsConnectionState(from: payload)
        } else {
            applyExpiredState(from: payload)
        }
    }
}
