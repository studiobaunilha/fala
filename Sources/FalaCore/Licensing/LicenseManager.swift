import Foundation
import CryptoKit
import Combine

@MainActor
public final class LicenseManager: ObservableObject {
    @Published public internal(set) var licenseEmail: String?
    @Published public internal(set) var errorMessage: String?
    @Published public var isActivating = false
    @Published public var isDeactivating = false
    @Published public internal(set) var trialDaysRemaining = 0
    @Published public internal(set) var isPro = false
    @Published public internal(set) var accessState: LicenseAccessState = .unlicensed
    @Published public internal(set) var isRefreshingEntitlement = false
    @Published public internal(set) var nextOnlineValidationAt: Date?
    @Published public internal(set) var trialEndsAt: Date?
    @Published public internal(set) var gracePeriodEndsAt: Date?
    @Published public internal(set) var requiresOnlineValidation = false

    public var isTrialActive: Bool { accessState == .trialActive }
    public var isActivated: Bool {
        accessState == .trialActive || accessState == .proActive || accessState == .proGracePeriod
    }
    public var canActivate: Bool { activationAvailabilityMessage == nil }
    public var activationAvailabilityMessage: String? {
        if !licensingClient.isBackendConfigured {
            return LicenseError.missingBackendConfiguration.errorDescription
        }

        if LicensingConfiguration.entitlementPublicKey == nil {
            return LicenseError.missingVerificationKey.errorDescription
        }

        return nil
    }

    let productId = "fala-pro"
    let entitlementTokenAccount = "fala-entitlement-token"
    let entitlementEmailAccount = "fala-entitlement-email"
    let legacyLicenseTokenAccount = "fala-license-token"
    let lastKnownServerTimeAccount = "fala-license-server-time"
    let licensingClient: any LicensingAPIClientProtocol
    let secureStore: any SecureStringStore
    let deviceFingerprintProvider: any DeviceFingerprintProviding
    let now: @Sendable () -> Date

    private var backgroundRefreshTask: Task<Void, Never>?

    public static let shared = LicenseManager()

    init(
        licensingClient: any LicensingAPIClientProtocol = EntitlementAPIClient(),
        secureStore: any SecureStringStore = KeychainSecureStore(),
        deviceFingerprintProvider: any DeviceFingerprintProviding = MacDeviceFingerprintProvider(),
        now: @escaping @Sendable () -> Date = Date.init,
        shouldRestoreStateOnLaunch: Bool = true
    ) {
        self.licensingClient = licensingClient
        self.secureStore = secureStore
        self.deviceFingerprintProvider = deviceFingerprintProvider
        self.now = now

        migrateLegacyEntitlementIfNeeded()

        if shouldRestoreStateOnLaunch {
            restoreEntitlementState(scheduleRefreshIfNeeded: true)
        } else {
            applyUnlicensedState()
        }
    }

    public func activate(activationCode: String) async {
        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        do {
            let normalizedCode = activationCode.trimmedNonEmpty
            guard let normalizedCode else {
                throw LicenseError.emptyActivationCode
            }

            if let activationAvailabilityMessage {
                throw LicenseError.configurationIssue(message: activationAvailabilityMessage)
            }

            let deviceFingerprint = try resolveDeviceFingerprint()
            let grant = try await licensingClient.activate(
                activationCode: normalizedCode,
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
            applyValidatedEntitlement(payload)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            clearLocalEntitlementAndReset()
        }
    }

    public func validateLocalToken() {
        restoreEntitlementState(scheduleRefreshIfNeeded: true)
    }

    public func deactivate() async {
        isDeactivating = true
        errorMessage = nil
        defer { isDeactivating = false }

        do {
            guard let token = try readStoredEntitlementToken() else {
                throw LicenseError.missingStoredEntitlement
            }

            if let activationAvailabilityMessage {
                throw LicenseError.configurationIssue(message: activationAvailabilityMessage)
            }

            let deviceFingerprint = try resolveDeviceFingerprint()
            _ = try validateEntitlementToken(token, allowExpired: true, expectedDeviceFingerprint: deviceFingerprint)
            try await licensingClient.deactivate(entitlementToken: token, deviceFingerprint: deviceFingerprint)

            try clearStoredEntitlement()
            applyUnlicensedState()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    public func refreshEntitlement() async {
        await refreshStoredEntitlement(silently: false)
    }

    #if DEBUG
    public func setTestActivated(_ activated: Bool) {
        accessState = activated ? .proActive : .unlicensed
        isPro = activated
        if activated {
            nextOnlineValidationAt = now().addingTimeInterval(14 * 24 * 60 * 60)
            trialEndsAt = nil
            gracePeriodEndsAt = nil
            trialDaysRemaining = 0
            requiresOnlineValidation = false
        } else {
            applyUnlicensedState()
        }
    }
    #endif
}

private extension LicenseManager {
    func restoreEntitlementState(scheduleRefreshIfNeeded: Bool) {
        backgroundRefreshTask?.cancel()

        do {
            if isClockRollbackDetected() {
                if let payload = try loadStoredPayload() {
                    applyClockRollbackState(for: payload)
                    if scheduleRefreshIfNeeded {
                        scheduleBackgroundRefresh()
                    }
                } else {
                    applyNeedsConnectionState(clearEmail: true)
                }
                return
            }

            guard let token = try readStoredEntitlementToken() else {
                applyUnlicensedState()
                if scheduleRefreshIfNeeded && shouldAutoStartTrial() {
                    scheduleTrialBootstrap()
                }
                return
            }

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
                return
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
        } catch {
            NSLog("[Fala] Local license validation failed: \(error.localizedDescription)")
            clearLocalEntitlementAndReset()
        }
    }

    func scheduleBackgroundRefresh() {
        guard licensingClient.isBackendConfigured,
              LicensingConfiguration.entitlementPublicKey != nil
        else {
            return
        }

        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { [weak self] in
            await self?.refreshStoredEntitlement(silently: true)
        }
    }

    func scheduleTrialBootstrap() {
        guard licensingClient.isBackendConfigured,
              LicensingConfiguration.entitlementPublicKey != nil
        else {
            applyNeedsConnectionState(clearEmail: true)
            return
        }

        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = Task { [weak self] in
            await self?.beginVerifiedTrial(silently: true)
        }
    }

    func beginVerifiedTrial(silently: Bool) async {
        if !silently {
            errorMessage = nil
        }

        do {
            let deviceFingerprint = try resolveDeviceFingerprint()
            let grant = try await licensingClient.startTrial(
                deviceFingerprint: deviceFingerprint,
                machineName: LicensingConfiguration.machineName(),
                appVersion: LicensingConfiguration.appVersion()
            )
            let payload = try validateEntitlementToken(
                grant.entitlementToken,
                allowExpired: false,
                expectedDeviceFingerprint: deviceFingerprint
            )

            try saveEntitlement(grant: grant, email: nil)
            applyValidatedEntitlement(payload)
        } catch {
            let licenseError = mapLicensingError(error)
            if !silently {
                errorMessage = licenseError.errorDescription
            }
            if case .apiFailure(let code, _) = licenseError,
               code == "trial_expired" || code == "trial_already_used" {
                applyExpiredState(from: nil)
            } else {
                applyNeedsConnectionState(clearEmail: true)
            }
        }
    }

    func refreshStoredEntitlement(silently: Bool) async {
        if !silently {
            isRefreshingEntitlement = true
        }
        if !silently {
            errorMessage = nil
        }
        defer {
            if !silently {
                isRefreshingEntitlement = false
            }
        }

        do {
            guard let token = try readStoredEntitlementToken() else {
                if silently {
                    if shouldAutoStartTrial() {
                        await beginVerifiedTrial(silently: true)
                    } else {
                        applyUnlicensedState()
                    }
                } else {
                    await beginVerifiedTrial(silently: false)
                }
                return
            }

            let payload = try await requestEntitlementRefresh(for: token)
            applyValidatedEntitlement(payload)
        } catch {
            let licenseError = mapLicensingError(error)
            handleRefreshFailure(licenseError)
            if !silently || !licenseError.isTransient {
                errorMessage = licenseError.errorDescription
            }
        }
    }
}
