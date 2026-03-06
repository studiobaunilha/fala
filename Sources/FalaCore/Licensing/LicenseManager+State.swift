import Foundation

extension LicenseManager {
    func applyValidatedEntitlement(_ payload: EntitlementPayload) {
        switch payload.entitlementKind ?? .paid {
        case .paid:
            applyPaidEntitlement(payload, gracePeriodEnd: nil)
        case .trial:
            applyTrialEntitlement(payload, requiresConnection: false)
        }
        errorMessage = nil
    }

    func applyPaidEntitlement(_ payload: EntitlementPayload, gracePeriodEnd: Date?) {
        let storedEmail = try? secureStore.read(account: entitlementEmailAccount)
        accessState = gracePeriodEnd == nil ? .proActive : .proGracePeriod
        isPro = true
        licenseEmail = payload.email?.trimmedNonEmpty ?? storedEmail ?? nil
        trialDaysRemaining = 0
        trialEndsAt = nil
        nextOnlineValidationAt = Date(timeIntervalSince1970: payload.exp)
        gracePeriodEndsAt = gracePeriodEnd
        requiresOnlineValidation = gracePeriodEnd != nil
    }

    func applyTrialEntitlement(_ payload: EntitlementPayload, requiresConnection: Bool) {
        let trialEndDate = payload.trialEndsAt.map { Date(timeIntervalSince1970: $0) }
        trialEndsAt = trialEndDate
        nextOnlineValidationAt = Date(timeIntervalSince1970: payload.exp)
        gracePeriodEndsAt = nil
        licenseEmail = nil
        isPro = false
        requiresOnlineValidation = requiresConnection

        if let trialEndDate {
            let remainingDays = max(0, Int(ceil(trialEndDate.timeIntervalSince(now()) / (24 * 60 * 60))))
            trialDaysRemaining = remainingDays
            accessState = requiresConnection ? .needsConnection : (remainingDays > 0 ? .trialActive : .expired)
        } else {
            trialDaysRemaining = 0
            accessState = requiresConnection ? .needsConnection : .expired
        }
    }

    func applyNeedsConnectionState(from payload: EntitlementPayload) {
        switch payload.entitlementKind ?? .paid {
        case .paid:
            if let gracePeriodEnd = paidGracePeriodEnd(for: payload), now() <= gracePeriodEnd {
                applyPaidEntitlement(payload, gracePeriodEnd: gracePeriodEnd)
            } else {
                accessState = .needsConnection
                isPro = false
                trialDaysRemaining = 0
                trialEndsAt = nil
                nextOnlineValidationAt = Date(timeIntervalSince1970: payload.exp)
                gracePeriodEndsAt = nil
                requiresOnlineValidation = true
            }
        case .trial:
            applyTrialEntitlement(payload, requiresConnection: true)
        }
    }

    func applyClockRollbackState(for payload: EntitlementPayload) {
        accessState = .needsConnection
        isPro = false
        requiresOnlineValidation = true
        nextOnlineValidationAt = Date(timeIntervalSince1970: payload.exp)
        gracePeriodEndsAt = nil

        switch payload.entitlementKind ?? .paid {
        case .paid:
            licenseEmail = payload.email?.trimmedNonEmpty ?? (try? secureStore.read(account: entitlementEmailAccount))
            trialDaysRemaining = 0
            trialEndsAt = nil
        case .trial:
            licenseEmail = nil
            trialEndsAt = payload.trialEndsAt.map { Date(timeIntervalSince1970: $0) }
            trialDaysRemaining = 0
        }
    }

    func applyNeedsConnectionState(clearEmail: Bool) {
        accessState = .needsConnection
        isPro = false
        if clearEmail {
            licenseEmail = nil
        }
        trialDaysRemaining = 0
        trialEndsAt = nil
        nextOnlineValidationAt = nil
        gracePeriodEndsAt = nil
        requiresOnlineValidation = true
    }

    func applyExpiredState(from payload: EntitlementPayload?) {
        accessState = .expired
        isPro = false
        licenseEmail = nil
        gracePeriodEndsAt = nil
        requiresOnlineValidation = false

        if let payload {
            trialEndsAt = payload.trialEndsAt.map { Date(timeIntervalSince1970: $0) }
            nextOnlineValidationAt = Date(timeIntervalSince1970: payload.exp)
            trialDaysRemaining = 0
        } else {
            trialEndsAt = nil
            nextOnlineValidationAt = nil
            trialDaysRemaining = 0
        }
    }

    func applyUnlicensedState() {
        accessState = .unlicensed
        isPro = false
        licenseEmail = nil
        trialDaysRemaining = 0
        trialEndsAt = nil
        nextOnlineValidationAt = nil
        gracePeriodEndsAt = nil
        requiresOnlineValidation = false
    }
}
