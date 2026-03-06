import Foundation

protocol LicensingAPIClientProtocol: Sendable {
    var isBackendConfigured: Bool { get }
    func activate(
        activationCode: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant
    func startTrial(
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant
    func refresh(
        entitlementToken: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant
    func deactivate(
        entitlementToken: String,
        deviceFingerprint: String
    ) async throws
}

struct EntitlementAPIClient: LicensingAPIClientProtocol, Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isBackendConfigured: Bool {
        LicensingConfiguration.backendBaseURL != nil
    }

    func activate(
        activationCode: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        try await performGrantRequest(
            path: "/api/licenses/activate",
            body: ActivationRequest(
                activationCode: activationCode,
                deviceFingerprint: deviceFingerprint,
                machineName: machineName,
                appVersion: appVersion
            )
        )
    }

    func startTrial(
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        try await performGrantRequest(
            path: "/api/licenses/trial/start",
            body: TrialStartRequest(
                deviceFingerprint: deviceFingerprint,
                machineName: machineName,
                appVersion: appVersion
            )
        )
    }

    func refresh(
        entitlementToken: String,
        deviceFingerprint: String,
        machineName: String,
        appVersion: String
    ) async throws -> EntitlementGrant {
        try await performGrantRequest(
            path: "/api/licenses/refresh",
            body: RefreshRequest(
                entitlementToken: entitlementToken,
                deviceFingerprint: deviceFingerprint,
                machineName: machineName,
                appVersion: appVersion
            )
        )
    }

    func deactivate(
        entitlementToken: String,
        deviceFingerprint: String
    ) async throws {
        _ = try await performRequest(
            path: "/api/licenses/deactivate",
            body: DeactivationRequest(
                entitlementToken: entitlementToken,
                deviceFingerprint: deviceFingerprint
            )
        )
    }

    private func performGrantRequest<Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> EntitlementGrant {
        let data = try await performRequest(path: path, body: body)
        let decoder = JSONDecoder()

        guard let parsed = try? decoder.decode(APIGrantResponse.self, from: data),
              let entitlementToken = parsed.entitlementToken?.trimmedNonEmpty,
              let entitlementKind = parsed.entitlementKind,
              let offlineWindowSeconds = parsed.offlineWindowSeconds,
              let serverNow = parsed.serverNow()
        else {
            throw LicenseError.invalidActivationResponse
        }

        return EntitlementGrant(
            entitlementToken: entitlementToken,
            email: parsed.email?.trimmedNonEmpty,
            serverNow: serverNow,
            offlineWindowSeconds: offlineWindowSeconds,
            entitlementKind: entitlementKind
        )
    }

    private func performRequest<Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> Data {
        guard let baseURL = LicensingConfiguration.backendBaseURL else {
            throw LicenseError.missingBackendConfiguration
        }

        let endpoint = baseURL.appendingPathComponent(trimmedPath(path))
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LicenseError.networkUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LicenseError.invalidActivationResponse
        }

        let decoder = JSONDecoder()
        let parsedError = try? decoder.decode(APIErrorResponse.self, from: data)

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw LicenseError.apiFailure(
                code: parsedError?.code?.trimmedNonEmpty,
                message: parsedError?.bestMessage ?? "O servidor recusou a operação (\(httpResponse.statusCode))."
            )
        }

        return data
    }

    private func trimmedPath(_ value: String) -> String {
        value.hasPrefix("/") ? String(value.dropFirst()) : value
    }
}

private struct ActivationRequest: Codable {
    let activationCode: String
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

private struct TrialStartRequest: Codable {
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

private struct RefreshRequest: Codable {
    let entitlementToken: String
    let deviceFingerprint: String
    let machineName: String
    let appVersion: String
}

private struct DeactivationRequest: Codable {
    let entitlementToken: String
    let deviceFingerprint: String
}

private struct APIGrantResponse: Codable {
    let entitlementToken: String?
    let email: String?
    let serverNowRaw: String?
    let offlineWindowSeconds: TimeInterval?
    let entitlementKind: EntitlementKind?

    enum CodingKeys: String, CodingKey {
        case entitlementToken = "entitlementToken"
        case email
        case serverNowRaw = "serverNow"
        case offlineWindowSeconds
        case entitlementKind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        entitlementToken =
            try container.decodeIfPresentOne(of: ["entitlementToken", "entitlement_token", "token"])
        email = try container.decodeIfPresentOne(of: ["email", "customerEmail", "customer_email"])
        serverNowRaw = try container.decodeIfPresentOne(of: ["serverNow", "server_now"])
        offlineWindowSeconds = try container.decodeIfPresentTimeInterval(
            of: ["offlineWindowSeconds", "offline_window_seconds"]
        )
        entitlementKind = try container.decodeIfPresentEnum(
            of: ["entitlementKind", "entitlement_kind"],
            type: EntitlementKind.self
        )
    }

    func serverNow() -> Date? {
        guard let raw = serverNowRaw?.trimmedNonEmpty else {
            return nil
        }

        let fractionalSecondFormatter = ISO8601DateFormatter()
        fractionalSecondFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalSecondFormatter.date(from: raw) {
            return parsed
        }

        let internetDateTimeFormatter = ISO8601DateFormatter()
        internetDateTimeFormatter.formatOptions = [.withInternetDateTime]
        if let parsed = internetDateTimeFormatter.date(from: raw) {
            return parsed
        }

        if let unixSeconds = TimeInterval(raw) {
            return Date(timeIntervalSince1970: unixSeconds)
        }

        return nil
    }
}

private struct APIErrorResponse: Codable {
    let code: String?
    let error: String?
    let message: String?
    let detail: String?

    var bestMessage: String? {
        for value in [message, detail, error] {
            if let trimmed = value?.trimmedNonEmpty {
                return trimmed
            }
        }

        return nil
    }
}

private struct DynamicCodingKeys: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKeys {
    func decodeIfPresentOne(of keys: [String]) throws -> String? {
        for key in keys {
            guard let codingKey = DynamicCodingKeys(stringValue: key) else {
                continue
            }
            if let value = try decodeIfPresent(String.self, forKey: codingKey) {
                return value
            }
        }

        return nil
    }

    func decodeIfPresentTimeInterval(of keys: [String]) throws -> TimeInterval? {
        for key in keys {
            guard let codingKey = DynamicCodingKeys(stringValue: key) else {
                continue
            }
            if let value = try decodeIfPresent(Double.self, forKey: codingKey) {
                return value
            }
            if let value = try decodeIfPresent(Int.self, forKey: codingKey) {
                return TimeInterval(value)
            }
        }

        return nil
    }

    func decodeIfPresentEnum<T: RawRepresentable>(
        of keys: [String],
        type: T.Type
    ) throws -> T? where T.RawValue == String {
        for key in keys {
            guard let codingKey = DynamicCodingKeys(stringValue: key) else {
                continue
            }
            if let value = try decodeIfPresent(String.self, forKey: codingKey),
               let parsed = T(rawValue: value) {
                return parsed
            }
        }

        return nil
    }
}
