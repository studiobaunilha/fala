import Foundation
import CryptoKit
import Combine

@MainActor
public final class LicenseManager: ObservableObject {
    @Published public private(set) var licenseEmail: String?
    @Published public private(set) var errorMessage: String?
    @Published public var isActivating: Bool = false
    
    // Trial logic
    @Published public private(set) var trialDaysRemaining: Int = 0
    public var isTrialActive: Bool { trialDaysRemaining > 0 && !isPro }
    
    // Core state
    public var isActivated: Bool { isPro || isTrialActive }
    @Published public private(set) var isPro: Bool = false

    // Replace with your actual Polar.sh public verification key.
    // For EdDSA, it's typically a raw 32-byte string or base64.
    private let providerPublicKeyBase64 = "REPLACE_ME_WITH_REAL_BASE64_PUBLIC_KEY"
    
    // Replace with your actual product ID / organization name
    private let productId = "fala-pro"
    
    // The account identifiers used in Keychain
    private let keychainAccount = "fala-license-token"
    private let trialStartDateAccount = "fala-trial-start"
    private let trialDurationDays: Double = 7

    public static let shared = LicenseManager()

    private init() {
        validateLocalToken()
        checkTrialStatus()
    }

    /// Called by the UI when the user enters a license key
    public func activate(key: String) async {
        isActivating = true
        errorMessage = nil
        defer { isActivating = false }

        // Implement actual API call to Polar.sh to activate the key.
        // The API should return a JWT (JSON Web Token) that proves activation.
        // For now, this is a placeholder mimicking a successful activation.
        
        /*
         Example Flow:
         let url = URL(string: "https://api.polar.sh/v1/licenses/activate")!
         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
         
         let (data, response) = try await URLSession.shared.data(for: request)
         // Parse the JWT from 'data'
         let jwtToken = parsed.token
         
         // Save to keychain
         try KeychainHelper.save(token: jwtToken, for: keychainAccount)
         */

        do {
            // Fake successful activation for boilerplate
            // try KeychainHelper.save(token: "fake.jwt.token", for: keychainAccount)
            
            // In a real scenario, after saving, we immediately validate it locally:
            // validateLocalToken()
            
            // Temporary Fake Success:
            self.isPro = true
            self.licenseEmail = "user@example.com"
            self.trialDaysRemaining = 0 // Once Pro, trial is irrelevant
        } catch {
            errorMessage = "Falha ao salvar a licença no sistema: \(error.localizedDescription)"
        }
    }

    /// Validates the token stored in the local Keychain without needing Internet access.
    public func validateLocalToken() {
        do {
            guard let token = try KeychainHelper.read(account: keychainAccount) else {
                isPro = false
                return
            }

            // 1. Split JWT into Header, Payload, Signature
            let parts = token.components(separatedBy: ".")
            guard parts.count == 3 else {
                throw LicenseError.invalidTokenFormat
            }
            
            // 2. Decode the Payload to check expiration
            guard let payloadData = base64URLDecode(parts[1]) else {
                throw LicenseError.invalidTokenFormat
            }
            
            let payload = try JSONDecoder().decode(JWTPayload.self, from: payloadData)
            
            // Allow a small clock skew (e.g., 5 minutes)
            let now = Date().timeIntervalSince1970
            if payload.exp < now {
                throw LicenseError.tokenExpired
            }
            
            // 3. Cryptographic Signature Verification
            // Note: In production, uncomment the CryptoKit EdDSA/RSA verification below.
            /*
            guard let signatureData = base64URLDecode(parts[2]),
                  let publicKeyData = Data(base64Encoded: providerPublicKeyBase64) else {
                throw LicenseError.invalidSignature
            }
            
            let signedData = "\(parts[0]).\(parts[1])".data(using: .utf8)!
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            
            guard publicKey.isValidSignature(signatureData, for: signedData) else {
                throw LicenseError.invalidSignature
            }
            */

            // 4. If all checks pass, we are activated!
            self.isPro = true
            self.licenseEmail = payload.email
            self.trialDaysRemaining = 0

        } catch {
            self.isPro = false
            self.licenseEmail = nil
            // If the token is invalid or expired, we should ideally wipe it
            try? KeychainHelper.delete(account: keychainAccount)
            NSLog("[Fala] Local license validation failed: \(error.localizedDescription)")
        }
    }

    public func deactivate() {
        try? KeychainHelper.delete(account: keychainAccount)
        isPro = false
        licenseEmail = nil
        errorMessage = nil
        checkTrialStatus() // Resume trial if unexpired
    }
    
#if DEBUG
    public func setTestActivated(_ activated: Bool) {
        self.isPro = activated
        if activated {
            self.trialDaysRemaining = 0
        }
    }
#endif

    // MARK: - Trial Logic

    private func checkTrialStatus() {
        guard !isPro else {
            trialDaysRemaining = 0
            return
        }

        let now = Date().timeIntervalSince1970
        let trialStartString = try? KeychainHelper.read(account: trialStartDateAccount)
        
        var startDate: Double
        
        if let trialStartString, let storedDate = Double(trialStartString) {
            startDate = storedDate
        } else {
            // First time opening the app, start trial
            startDate = now
            try? KeychainHelper.save(token: String(startDate), for: trialStartDateAccount)
            NSLog("[Fala] Trial started at \(Date(timeIntervalSince1970: startDate))")
        }
        
        let elapsedDays = (now - startDate) / (60 * 60 * 24)
        
        // Prevent reverse-clock tampering (if now is wildly before startDate)
        if elapsedDays < -1.0 {
            trialDaysRemaining = 0
            NSLog("[Fala] Invalid system clock detected. Trial disabled.")
            return
        }
        
        let remaining = Int(ceil(trialDurationDays - elapsedDays))
        trialDaysRemaining = max(0, remaining)
    }

    // MARK: - Helpers

    private func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = String(repeating: "=", count: Int(paddingLength))
            base64 += padding
        }
        return Data(base64Encoded: base64, options: .ignoreUnknownCharacters)
    }
}

// MARK: - Models

struct JWTPayload: Codable {
    let exp: TimeInterval
    let iat: TimeInterval
    let productId: String?
    let email: String?
    
    enum CodingKeys: String, CodingKey {
        case exp, iat, email
        case productId = "product_id"
    }
}

public enum LicenseError: Error, LocalizedError {
    case invalidTokenFormat
    case invalidSignature
    case tokenExpired

    public var errorDescription: String? {
        switch self {
        case .invalidTokenFormat: return "O formato da licença é inválido."
        case .invalidSignature: return "A assinatura da licença foi corrompida ou é inválida."
        case .tokenExpired: return "Sua sessão de licença expirou. Conecte-se à internet para revalidar."
        }
    }
}
