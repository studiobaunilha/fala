import Foundation
import CryptoKit

enum LicensingConfiguration {
    private static let backendBaseURLKey = "FalaLicensingBaseURL"
    private static let entitlementPublicKeyKey = "FalaEntitlementPublicKeyBase64"
    static let clockRollbackTolerance: TimeInterval = 5 * 60
    static let paidGracePeriod: TimeInterval = 3 * 24 * 60 * 60
    static let paidRefreshLeadTime: TimeInterval = 24 * 60 * 60
    static let trialRefreshLeadTime: TimeInterval = 60 * 60
    nonisolated(unsafe) private static var overrides = TestOverrides()

    static var backendBaseURL: URL? {
        if let overrideURL = overrides.backendBaseURL {
            return overrideURL
        }

        guard let rawValue = infoValue(for: backendBaseURLKey),
              let url = URL(string: rawValue),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else {
            return nil
        }

        return url
    }

    static var entitlementPublicKey: Curve25519.Signing.PublicKey? {
        if let overrideValue = overrides.entitlementPublicKey {
            return overrideValue
        }

        guard let rawValue = infoValue(for: entitlementPublicKeyKey),
              let data = Data(base64Encoded: rawValue)
        else {
            return nil
        }

        return try? Curve25519.Signing.PublicKey(rawRepresentation: data)
    }

    static func appVersion() -> String {
        if let overrideValue = overrides.appVersion?.trimmedNonEmpty {
            return overrideValue
        }

        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        switch (shortVersion?.trimmedNonEmpty, buildVersion?.trimmedNonEmpty) {
        case let (.some(short), .some(build)):
            return "\(short) (\(build))"
        case let (.some(short), _):
            return short
        case let (_, .some(build)):
            return build
        default:
            return "unknown"
        }
    }

    static func machineName() -> String {
        if let overrideValue = overrides.machineName?.trimmedNonEmpty {
            return overrideValue
        }

        if let localizedName = Host.current().localizedName?.trimmedNonEmpty {
            return localizedName
        }

        return ProcessInfo.processInfo.hostName.trimmedNonEmpty ?? "unknown-mac"
    }

    #if DEBUG
    static func setTestOverrides(
        backendBaseURL: URL? = nil,
        entitlementPublicKeyBase64: String? = nil,
        machineName: String? = nil,
        appVersion: String? = nil
    ) {
        overrides = TestOverrides(
            backendBaseURL: backendBaseURL,
            entitlementPublicKey: entitlementPublicKey(from: entitlementPublicKeyBase64),
            machineName: machineName,
            appVersion: appVersion
        )
    }

    static func resetTestOverrides() {
        overrides = TestOverrides()
    }
    #endif

    private static func entitlementPublicKey(from base64: String?) -> Curve25519.Signing.PublicKey? {
        guard let base64 = base64?.trimmedNonEmpty,
              let data = Data(base64Encoded: base64)
        else {
            return nil
        }

        return try? Curve25519.Signing.PublicKey(rawRepresentation: data)
    }

    private static func infoValue(for key: String) -> String? {
        guard let value = Bundle.main.infoDictionary?[key] as? String else {
            return nil
        }

        return value.trimmedNonEmpty
    }
}

private struct TestOverrides {
    let backendBaseURL: URL?
    let entitlementPublicKey: Curve25519.Signing.PublicKey?
    let machineName: String?
    let appVersion: String?

    init(
        backendBaseURL: URL? = nil,
        entitlementPublicKey: Curve25519.Signing.PublicKey? = nil,
        machineName: String? = nil,
        appVersion: String? = nil
    ) {
        self.backendBaseURL = backendBaseURL
        self.entitlementPublicKey = entitlementPublicKey
        self.machineName = machineName
        self.appVersion = appVersion
    }
}
