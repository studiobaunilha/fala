import Foundation

public enum EntitlementKind: String, Codable, Sendable {
    case paid
    case trial
}

public enum LicenseAccessState: Equatable, Sendable {
    case unlicensed
    case trialActive
    case proActive
    case proGracePeriod
    case needsConnection
    case expired
}

struct EntitlementPayload: Codable, Sendable {
    let exp: TimeInterval
    let iat: TimeInterval
    let productId: String?
    let entitlementKind: EntitlementKind?
    let email: String?
    let licenseId: String?
    let transactionId: String?
    let deviceFingerprint: String?
    let machineName: String?
    let trialEndsAt: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case exp
        case iat
        case email
        case productId = "product_id"
        case entitlementKind = "entitlement_kind"
        case licenseId = "license_id"
        case transactionId = "transaction_id"
        case deviceFingerprint = "device_fingerprint"
        case machineName = "machine_name"
        case trialEndsAt = "trial_ends_at"
    }
}

struct EntitlementGrant: Sendable {
    let entitlementToken: String
    let email: String?
    let serverNow: Date
    let offlineWindowSeconds: TimeInterval
    let entitlementKind: EntitlementKind
}

public enum LicenseError: Error, LocalizedError {
    case emptyActivationCode
    case missingBackendConfiguration
    case missingVerificationKey
    case missingDeviceFingerprint
    case configurationIssue(message: String)
    case apiFailure(code: String?, message: String)
    case networkUnavailable
    case invalidActivationResponse
    case missingStoredEntitlement
    case invalidTokenFormat
    case invalidSignature
    case tokenExpired
    case productMismatch
    case invalidDeviceBinding
    case clockRollbackDetected
    case onlineValidationRequired
    case keychainAccessDenied(message: String)

    var isTransient: Bool {
        switch self {
        case .networkUnavailable, .keychainAccessDenied:
            return true
        case .apiFailure(let code, _):
            return code == "network_error" || code == "server_unavailable"
        default:
            return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .emptyActivationCode:
            return "Cole um código de ativação válido para continuar."
        case .missingBackendConfiguration:
            return "A ativação online ainda não está configurada nesta versão do app. Se você já comprou, fale com support@baunilha.dev."
        case .missingVerificationKey:
            return "Esta build do app não possui a chave pública de validação da ativação. Contate support@baunilha.dev."
        case .missingDeviceFingerprint:
            return "Não foi possível identificar este Mac para ativação."
        case .configurationIssue(let message):
            return message
        case .apiFailure(let code, let message):
            switch code {
            case "activation_code_not_found":
                return "Esse código de ativação não foi encontrado."
            case "machine_limit_reached":
                return "Esta licença já está ativa no limite de 3 Macs."
            case "license_revoked":
                return "Esta licença foi revogada. Se precisar, fale com support@baunilha.dev."
            case "machine_not_activated":
                return "Este Mac não está mais ativo nesta licença."
            case "trial_expired":
                return "Seu trial expirou. Compre e ative o Fala Pro para continuar."
            case "trial_already_used":
                return "Este Mac já usou o período de trial."
            case "invalid_entitlement_token":
                return "O token local de ativação é inválido e precisa ser renovado online."
            case "database_schema_outdated", "licensing_internal_error":
                return """
                O servidor de licenças está temporariamente inconsistente.
                Tente novamente em alguns minutos ou fale com support@baunilha.dev.
                """
            default:
                return message
            }
        case .networkUnavailable:
            return "Não foi possível conectar ao servidor de licenças."
        case .invalidActivationResponse:
            return "O servidor respondeu com um formato de ativação inválido."
        case .missingStoredEntitlement:
            return "Nenhuma ativação local foi encontrada neste Mac."
        case .invalidTokenFormat:
            return "O formato do token de ativação é inválido."
        case .invalidSignature:
            return "A assinatura do token de ativação é inválida."
        case .tokenExpired:
            return "Sua ativação offline expirou e precisa ser renovada online."
        case .productMismatch:
            return "O token recebido não pertence ao produto Fala."
        case .invalidDeviceBinding:
            return "Este token de ativação pertence a outro Mac."
        case .clockRollbackDetected:
            return "O relógio do sistema voltou no tempo. Conecte este Mac para validar a licença novamente."
        case .onlineValidationRequired:
            return "Conecte este Mac à internet para validar sua licença e continuar."
        case .keychainAccessDenied(let message):
            return "Acesso bloqueado ao Keychain: \(message)"
        }
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
