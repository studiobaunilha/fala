import XCTest
import CryptoKit
@testable import FalaCore

final class StubLicensingClient: LicensingAPIClientProtocol, @unchecked Sendable {
    var isBackendConfigured = true
    var activateRequests: [ActivationRequestPayload] = []
    var trialRequests: [TrialStartRequestPayload] = []
    var refreshRequests: [RefreshRequestPayload] = []
    var deactivateRequests: [DeactivateRequestPayload] = []

    var activateHandler: @Sendable (ActivationRequestPayload) async throws -> EntitlementGrant = { _ in
        throw StubError.unimplemented
    }
    var trialHandler: @Sendable (TrialStartRequestPayload) async throws -> EntitlementGrant = { _ in
        throw StubError.unimplemented
    }
    var refreshHandler: @Sendable (RefreshRequestPayload) async throws -> EntitlementGrant = { _ in
        throw StubError.unimplemented
    }
    var deactivateHandler: @Sendable (DeactivateRequestPayload) async throws -> Void = { _ in
        throw StubError.unimplemented
    }

    func activate(
        activationCode: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        let request = ActivationRequestPayload(
            activationCode: activationCode,
            deviceFingerprint: deviceFingerprint,
            machineName: machineName,
            appVersion: appVersion
        )
        activateRequests.append(request)
        return try await activateHandler(request)
    }

    func startTrial(
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        let request = TrialStartRequestPayload(
            deviceFingerprint: deviceFingerprint,
            machineName: machineName,
            appVersion: appVersion
        )
        trialRequests.append(request)
        return try await trialHandler(request)
    }

    func refresh(
        entitlementToken: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        let request = RefreshRequestPayload(
            entitlementToken: entitlementToken,
            deviceFingerprint: deviceFingerprint,
            machineName: machineName,
            appVersion: appVersion
        )
        refreshRequests.append(request)
        return try await refreshHandler(request)
    }

    func deactivate(entitlementToken: String, deviceFingerprint: String) async throws {
        let request = DeactivateRequestPayload(
            entitlementToken: entitlementToken,
            deviceFingerprint: deviceFingerprint
        )
        deactivateRequests.append(request)
        try await deactivateHandler(request)
    }
}

struct ActivationRequestPayload: Sendable {
    let activationCode: String
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

struct TrialStartRequestPayload: Sendable {
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

struct RefreshRequestPayload: Sendable {
    let entitlementToken: String
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

struct DeactivateRequestPayload: Sendable {
    let entitlementToken: String
    let deviceFingerprint: String
}

struct StubDeviceFingerprintProvider: DeviceFingerprintProviding {
    let fingerprint: String

    func currentFingerprint() throws -> String {
        fingerprint
    }
}

final class InMemorySecureStore: SecureStringStore, @unchecked Sendable {
    private var values: [String: String]

    init(_ initialValues: [String: String] = [:]) {
        values = initialValues
    }

    func save(token: String, for account: String) throws {
        values[account] = token
    }

    func read(account: String) throws -> String? {
        values[account]
    }

    func delete(account: String) throws {
        values.removeValue(forKey: account)
    }

    func value(for account: String) -> String? {
        values[account]
    }
}

struct EntitlementTokenSigner {
    private let privateKey = Curve25519.Signing.PrivateKey()

    var publicKeyBase64: String {
        privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    func makePaidToken(
        deviceFingerprint: String,
        issuedAt: Date = Date(),
        expiresAt: Date
    ) throws -> String {
        try makeToken(
            payload: TokenPayload(
                iat: Int(issuedAt.timeIntervalSince1970),
                exp: Int(expiresAt.timeIntervalSince1970),
                productId: "fala-pro",
                entitlementKind: "paid",
                deviceFingerprint: deviceFingerprint,
                machineName: "Test Mac",
                trialEndsAt: nil,
                licenseId: "lic_test",
                transactionId: "txn_test",
                email: "buyer@example.com"
            )
        )
    }

    func makeTrialToken(
        deviceFingerprint: String,
        issuedAt: Date = Date(),
        expiresAt: Date,
        trialEndsAt: Date
    ) throws -> String {
        try makeToken(
            payload: TokenPayload(
                iat: Int(issuedAt.timeIntervalSince1970),
                exp: Int(expiresAt.timeIntervalSince1970),
                productId: "fala-pro",
                entitlementKind: "trial",
                deviceFingerprint: deviceFingerprint,
                machineName: "Test Mac",
                trialEndsAt: Int(trialEndsAt.timeIntervalSince1970),
                licenseId: nil,
                transactionId: nil,
                email: nil
            )
        )
    }

    private func makeToken(payload: TokenPayload) throws -> String {
        let headerData = try JSONEncoder().encode(TokenHeader())
        let payloadData = try JSONEncoder().encode(payload)
        let header = headerData.base64URLEncodedString()
        let body = payloadData.base64URLEncodedString()
        let signingData = Data("\(header).\(body)".utf8)
        let signature = try privateKey.signature(for: signingData)
        return "\(header).\(body).\(signature.base64URLEncodedString())"
    }
}

enum StubError: Error {
    case unimplemented
    case expectedFailure
}

private struct TokenHeader: Encodable {
    let alg = "EdDSA"
    let typ = "JWT"
}

private struct TokenPayload: Encodable {
    let iat: Int
    let exp: Int
    let productId: String
    let entitlementKind: String
    let deviceFingerprint: String
    let machineName: String
    let trialEndsAt: Int?
    let licenseId: String?
    let transactionId: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case iat
        case exp
        case productId = "product_id"
        case entitlementKind = "entitlement_kind"
        case deviceFingerprint = "device_fingerprint"
        case machineName = "machine_name"
        case trialEndsAt = "trial_ends_at"
        case licenseId = "license_id"
        case transactionId = "transaction_id"
        case email
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
func eventually(
    timeout: TimeInterval = 1.5,
    interval: TimeInterval = 0.05,
    condition: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
        if condition() {
            return true
        }

        if Date() >= deadline {
            return false
        }

        try? await Task.sleep(for: .seconds(interval))
    }
}

func makeGrant(
    token: String,
    kind: EntitlementKind,
    email: String? = nil,
    serverNow: Date
) -> EntitlementGrant {
    EntitlementGrant(
        entitlementToken: token,
        email: email,
        serverNow: serverNow,
        offlineWindowSeconds: kind == .paid ? 14 * 24 * 60 * 60 : 24 * 60 * 60,
        entitlementKind: kind
    )
}
