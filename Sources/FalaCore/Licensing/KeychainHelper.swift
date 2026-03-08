import Foundation
import Security

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
public enum KeychainHelper {
    private static let serviceName = "dev.fala.app.license"

    public static func save(token: String, for account: String) throws {
        guard let data = token.data(using: .utf8) else { return }

        // Secure baseline matching query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        // Check if item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            // Update existing item
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledError(status: updateStatus)
            }
        case errSecItemNotFound:
            // Add new item
            var newQuery = query
            newQuery[kSecValueData as String] = data
            // Restrict access to when the device is unlocked
            newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            
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
            kSecReturnData as String: true,
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
        let requestedAccounts = Set(accounts)
        guard !requestedAccounts.isEmpty else {
            return [:]
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return [:]
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let entries = item as? [[String: Any]] else {
            throw KeychainError.unexpectedData
        }

        var values: [String: String] = [:]
        for entry in entries {
            guard let account = entry[kSecAttrAccount as String] as? String,
                  requestedAccounts.contains(account),
                  let data = entry[kSecValueData as String] as? Data,
                  let token = String(data: data, encoding: .utf8)
            else {
                continue
            }

            values[account] = token
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
