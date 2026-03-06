import Foundation

extension LicenseManager {
    func resolveDeviceFingerprint() throws -> String {
        do {
            return try deviceFingerprintProvider.currentFingerprint()
        } catch {
            throw LicenseError.missingDeviceFingerprint
        }
    }

    func readStoredEntitlementToken() throws -> String? {
        try secureStore.read(account: entitlementTokenAccount)?.trimmedNonEmpty
    }

    func loadStoredPayload() throws -> EntitlementPayload? {
        guard let token = try readStoredEntitlementToken() else {
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
        try secureStore.save(token: grant.entitlementToken, for: entitlementTokenAccount)

        if let email = email?.trimmedNonEmpty {
            try secureStore.save(token: email, for: entitlementEmailAccount)
        } else {
            try? secureStore.delete(account: entitlementEmailAccount)
        }

        try secureStore.save(
            token: String(grant.serverNow.timeIntervalSince1970),
            for: lastKnownServerTimeAccount
        )
    }

    func clearStoredEntitlement() throws {
        try secureStore.delete(account: entitlementTokenAccount)
        try secureStore.delete(account: entitlementEmailAccount)
    }

    func migrateLegacyEntitlementIfNeeded() {
        guard (try? secureStore.read(account: entitlementTokenAccount)?.trimmedNonEmpty) == nil,
              let legacyToken = try? secureStore.read(account: legacyLicenseTokenAccount)?.trimmedNonEmpty
        else {
            return
        }

        do {
            try secureStore.save(token: legacyToken, for: entitlementTokenAccount)
            try secureStore.delete(account: legacyLicenseTokenAccount)
        } catch {
            NSLog("[Fala] Failed to migrate legacy entitlement token: \(error.localizedDescription)")
        }
    }

    func clearLocalEntitlementAndReset() {
        try? clearStoredEntitlement()
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
