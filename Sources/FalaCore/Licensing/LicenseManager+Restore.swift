import Foundation

extension LicenseManager {
    func restoreEntitlementState(
        scheduleRefreshIfNeeded: Bool,
        forceSecureStoreReload: Bool = false
    ) {
        backgroundRefreshTask?.cancel()

        do {
            let snapshot = try loadStoredEntitlementSnapshot(forceReload: forceSecureStoreReload)
            try restoreEntitlementState(
                from: snapshot,
                scheduleRefreshIfNeeded: scheduleRefreshIfNeeded
            )
        } catch {
            handleRestoreEntitlementFailure(error)
        }
    }

    func restoreEntitlementState(
        from snapshot: StoredEntitlementSnapshot,
        scheduleRefreshIfNeeded: Bool
    ) throws {
        if isClockRollbackDetected(in: snapshot) {
            try restoreClockRollbackState(scheduleRefreshIfNeeded: scheduleRefreshIfNeeded)
            return
        }

        guard let token = snapshot.resolvedEntitlementToken else {
            applyUnlicensedState()
            if scheduleRefreshIfNeeded && snapshot.lastKnownServerTime == nil {
                scheduleTrialBootstrap()
            }
            return
        }

        try restoreValidatedEntitlement(
            token: token,
            scheduleRefreshIfNeeded: scheduleRefreshIfNeeded
        )
    }

    func restoreClockRollbackState(scheduleRefreshIfNeeded: Bool) throws {
        if let payload = try loadStoredPayload() {
            applyClockRollbackState(for: payload)
            if scheduleRefreshIfNeeded {
                scheduleBackgroundRefresh()
            }
        } else {
            applyNeedsConnectionState(clearEmail: true)
        }
    }

    func restoreValidatedEntitlement(
        token: String,
        scheduleRefreshIfNeeded: Bool
    ) throws {
        let deviceFingerprint = try resolveDeviceFingerprint()

        do {
            let payload = try validateEntitlementToken(
                token,
                allowExpired: false,
                expectedDeviceFingerprint: deviceFingerprint
            )
            applyValidatedEntitlement(payload)
            if scheduleRefreshIfNeeded && shouldScheduleBackgroundRefresh(for: payload) {
                scheduleBackgroundRefresh()
            }
        } catch LicenseError.tokenExpired {
            let payload = try validateEntitlementToken(
                token,
                allowExpired: true,
                expectedDeviceFingerprint: deviceFingerprint
            )
            applyNeedsConnectionState(from: payload)
            if scheduleRefreshIfNeeded {
                scheduleBackgroundRefresh()
            }
        }
    }

    func isClockRollbackDetected(in snapshot: StoredEntitlementSnapshot) -> Bool {
        guard let lastServerTimestamp = snapshot.lastKnownServerTime.flatMap(Double.init) else {
            return false
        }

        return now().timeIntervalSince1970 + LicensingConfiguration.clockRollbackTolerance < lastServerTimestamp
    }

    func handleRestoreEntitlementFailure(_ error: Error) {
        NSLog("[Fala] Local license validation failed: \(error.localizedDescription)")
        if error is KeychainError {
            invalidateEntitlementSnapshotCache()
            applyUnlicensedState()
        } else {
            clearLocalEntitlementAndReset()
        }
    }
}
