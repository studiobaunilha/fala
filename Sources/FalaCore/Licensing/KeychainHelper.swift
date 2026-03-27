import Foundation
import Security

// SecAccessCreate has no modern replacement for controlling login-keychain ACLs
// in Developer ID apps. Reference the C symbol directly to avoid the propagating
// deprecation warning under -warnings-as-errors.
@_silgen_name("SecAccessCreate")
private func secAccessCreate(
    _ descriptor: CFString,
    _ trustedlist: CFArray?,
    _ accessRef: UnsafeMutablePointer<SecAccess?>
) -> OSStatus

public protocol SecureStringStore: Sendable {
    func save(token: String, for account: String) throws
    func read(account: String) throws -> String?
    func read(accounts: [String]) throws -> [String: String]
    func delete(account: String) throws
}

public extension SecureStringStore {
    func read(accounts: [String]) throws -> [String: String] {
        var values: [String: String] = [:]
        for account in accounts {
            if let value = try read(account: account) {
                values[account] = value
            }
        }
        return values
    }
}

public struct KeychainSecureStore: SecureStringStore {
    public init() {}

    public func save(token: String, for account: String) throws {
        try KeychainHelper.save(token: token, for: account)
    }

    public func read(account: String) throws -> String? {
        try KeychainHelper.read(account: account)
    }

    public func read(accounts: [String]) throws -> [String: String] {
        try KeychainHelper.read(accounts: accounts)
    }

    public func delete(account: String) throws {
        try KeychainHelper.delete(account: account)
    }
}

struct InMemorySecureStore: SecureStringStore {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var values: [String: String] = [:]
    }

    private let storage = Storage()

    func save(token: String, for account: String) throws {
        storage.lock.lock()
        storage.values[account] = token
        storage.lock.unlock()
    }

    func read(account: String) throws -> String? {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.values[account]
    }

    func delete(account: String) throws {
        storage.lock.lock()
        storage.values.removeValue(forKey: account)
        storage.lock.unlock()
    }

    func read(accounts: [String]) throws -> [String: String] {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        var result: [String: String] = [:]
        for account in accounts {
            if let value = storage.values[account] {
                result[account] = value
            }
        }
        return result
    }
}

/// Helper to securely store, read, and delete strings in the macOS Keychain.
///
/// Uses `SecAccessCreate` with a nil trusted-application list so that any version
/// of the app (regardless of binary hash) can access the items without triggering
/// a system password prompt on updates.
public enum KeychainHelper {
    private static let serviceName = "dev.fala.app.license"

    private static func makePermissiveAccess() throws -> SecAccess {
        var access: SecAccess?
        let status = secAccessCreate(serviceName as CFString, nil, &access)
        guard status == errSecSuccess, let result = access else {
            throw KeychainError.unhandledError(status: status)
        }
        return result
    }

    public static func save(token: String, for account: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            // Delete and re-add with permissive ACL (SecItemUpdate cannot change ACLs)
            SecItemDelete(query as CFDictionary)
            fallthrough
        case errSecItemNotFound:
            var newQuery = query
            newQuery[kSecValueData as String] = data
            newQuery[kSecAttrAccess as String] = try makePermissiveAccess()

            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: addStatus)
            }
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    public static func read(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }

        return token
    }

    public static func read(accounts: [String]) throws -> [String: String] {
        var values: [String: String] = [:]
        for account in accounts {
            if let value = try read(account: account) {
                values[account] = value
            }
        }
        return values
    }

    public static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

public enum KeychainError: Error, LocalizedError {
    case unhandledError(status: OSStatus)
    case unexpectedData

    public var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        }
    }
}
