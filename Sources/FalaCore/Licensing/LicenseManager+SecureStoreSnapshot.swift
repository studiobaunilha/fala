import Foundation

struct StoredEntitlementSnapshot: Equatable, Sendable {
    let entitlementToken: String?
    let legacyEntitlementToken: String?
    let entitlementEmail: String?
    let lastKnownServerTime: String?

    var resolvedEntitlementToken: String? {
        entitlementToken ?? legacyEntitlementToken
    }

    var isEmpty: Bool {
        resolvedEntitlementToken == nil &&
        entitlementEmail == nil &&
        lastKnownServerTime == nil
    }

    var needsLegacyMigration: Bool {
        entitlementToken == nil && legacyEntitlementToken != nil
    }

    func migratedLegacyToken() -> StoredEntitlementSnapshot {
        StoredEntitlementSnapshot(
            entitlementToken: legacyEntitlementToken,
            legacyEntitlementToken: nil,
            entitlementEmail: entitlementEmail,
            lastKnownServerTime: lastKnownServerTime
        )
    }

    static let empty = StoredEntitlementSnapshot(
        entitlementToken: nil,
        legacyEntitlementToken: nil,
        entitlementEmail: nil,
        lastKnownServerTime: nil
    )

    init(
        values: [String: String],
        entitlementTokenAccount: String,
        entitlementEmailAccount: String,
        legacyLicenseTokenAccount: String,
        lastKnownServerTimeAccount: String
    ) {
        entitlementToken = values[entitlementTokenAccount]?.trimmedNonEmpty
        legacyEntitlementToken = values[legacyLicenseTokenAccount]?.trimmedNonEmpty
        entitlementEmail = values[entitlementEmailAccount]?.trimmedNonEmpty
        lastKnownServerTime = values[lastKnownServerTimeAccount]?.trimmedNonEmpty
    }

    init(
        entitlementToken: String?,
        legacyEntitlementToken: String?,
        entitlementEmail: String?,
        lastKnownServerTime: String?
    ) {
        self.entitlementToken = entitlementToken?.trimmedNonEmpty
        self.legacyEntitlementToken = legacyEntitlementToken?.trimmedNonEmpty
        self.entitlementEmail = entitlementEmail?.trimmedNonEmpty
        self.lastKnownServerTime = lastKnownServerTime?.trimmedNonEmpty
    }
}

extension LicenseManager {
    func loadStoredEntitlementSnapshot(forceReload: Bool = false) throws -> StoredEntitlementSnapshot {
        if !forceReload, let storedEntitlementSnapshot {
            return storedEntitlementSnapshot
        }

        let values = try secureStore.read(
            accounts: [
                entitlementTokenAccount,
                entitlementEmailAccount,
                legacyLicenseTokenAccount,
                lastKnownServerTimeAccount
            ]
        )

        var snapshot = StoredEntitlementSnapshot(
            values: values,
            entitlementTokenAccount: entitlementTokenAccount,
            entitlementEmailAccount: entitlementEmailAccount,
            legacyLicenseTokenAccount: legacyLicenseTokenAccount,
            lastKnownServerTimeAccount: lastKnownServerTimeAccount
        )

        if snapshot.needsLegacyMigration,
           let legacyToken = snapshot.legacyEntitlementToken {
            do {
                try secureStore.save(token: legacyToken, for: entitlementTokenAccount)
                try secureStore.delete(account: legacyLicenseTokenAccount)
                snapshot = snapshot.migratedLegacyToken()
            } catch {
                NSLog("[Fala] Failed to migrate legacy entitlement token: %@", error.localizedDescription)
            }
        }

        storedEntitlementSnapshot = snapshot
        return snapshot
    }

    func storeEntitlementSnapshot(
        entitlementToken: String?,
        entitlementEmail: String?,
        lastKnownServerTime: String?
    ) {
        storedEntitlementSnapshot = StoredEntitlementSnapshot(
            entitlementToken: entitlementToken,
            legacyEntitlementToken: nil,
            entitlementEmail: entitlementEmail,
            lastKnownServerTime: lastKnownServerTime
        )
    }

    func clearEntitlementSnapshot() {
        storedEntitlementSnapshot = .empty
    }

    func invalidateEntitlementSnapshotCache() {
        storedEntitlementSnapshot = nil
    }
}
