import Foundation

extension LicenseManager {
    func validateEntitlementToken(
        _ token: String,
        allowExpired: Bool,
        expectedDeviceFingerprint: String
    ) throws -> EntitlementPayload {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw LicenseError.invalidTokenFormat
        }

        guard let payloadData = base64URLDecode(parts[1]),
              let signatureData = base64URLDecode(parts[2])
        else {
            throw LicenseError.invalidTokenFormat
        }

        let payload = try JSONDecoder().decode(EntitlementPayload.self, from: payloadData)

        guard let publicKey = LicensingConfiguration.entitlementPublicKey else {
            throw LicenseError.missingVerificationKey
        }

        let signedData = Data("\(parts[0]).\(parts[1])".utf8)
        guard publicKey.isValidSignature(signatureData, for: signedData) else {
            throw LicenseError.invalidSignature
        }

        if let payloadProductId = payload.productId?.trimmedNonEmpty,
           payloadProductId != productId {
            throw LicenseError.productMismatch
        }

        if let payloadDeviceFingerprint = payload.deviceFingerprint?.trimmedNonEmpty,
           payloadDeviceFingerprint != expectedDeviceFingerprint {
            throw LicenseError.invalidDeviceBinding
        }

        if !allowExpired && payload.exp < now().timeIntervalSince1970 {
            throw LicenseError.tokenExpired
        }

        return payload
    }

    func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            base64 += String(repeating: "=", count: Int(paddingLength))
        }

        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }

    func shouldAutoStartTrial(forceReload: Bool = false) -> Bool {
        (try? loadStoredEntitlementSnapshot(forceReload: forceReload).lastKnownServerTime) == nil
    }

    func isClockRollbackDetected() -> Bool {
        guard let lastServerTimeRaw = try? loadStoredEntitlementSnapshot().lastKnownServerTime,
              let lastServerTimestamp = Double(lastServerTimeRaw)
        else {
            return false
        }

        return now().timeIntervalSince1970 + LicensingConfiguration.clockRollbackTolerance < lastServerTimestamp
    }

    func paidGracePeriodEnd(for payload: EntitlementPayload) -> Date? {
        guard (payload.entitlementKind ?? .paid) == .paid else {
            return nil
        }

        return Date(timeIntervalSince1970: payload.exp + LicensingConfiguration.paidGracePeriod)
    }

    func trialRemainsAvailable(_ payload: EntitlementPayload) -> Bool {
        guard let trialEndsAt = payload.trialEndsAt else {
            return false
        }

        return Date(timeIntervalSince1970: trialEndsAt) > now()
    }

    func shouldScheduleBackgroundRefresh(for payload: EntitlementPayload) -> Bool {
        let expiryDate = Date(timeIntervalSince1970: payload.exp)
        let leadTime: TimeInterval

        switch payload.entitlementKind ?? .paid {
        case .paid:
            leadTime = LicensingConfiguration.paidRefreshLeadTime
        case .trial:
            leadTime = LicensingConfiguration.trialRefreshLeadTime
        }

        return expiryDate.timeIntervalSince(now()) <= leadTime
    }

    func mapLicensingError(_ error: Error) -> LicenseError {
        if let licenseError = error as? LicenseError {
            return licenseError
        }

        if let keychainError = error as? KeychainError {
            return .keychainAccessDenied(message: keychainError.localizedDescription)
        }

        return .apiFailure(code: nil, message: error.localizedDescription)
    }
}
