import Foundation
import CryptoKit
import IOKit

protocol DeviceFingerprintProviding: Sendable {
    func currentFingerprint() throws -> String
}

enum DeviceFingerprintError: Error, LocalizedError {
    case platformIdentifierUnavailable

    var errorDescription: String? {
        switch self {
        case .platformIdentifierUnavailable:
            return "Não foi possível identificar este Mac."
        }
    }
}

struct MacDeviceFingerprintProvider: DeviceFingerprintProviding {
    func currentFingerprint() throws -> String {
        let platformUUID = try resolvePlatformUUID()
        let digest = SHA256.hash(data: Data("fala:\(platformUUID.lowercased())".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func resolvePlatformUUID() throws -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else {
            throw DeviceFingerprintError.platformIdentifierUnavailable
        }
        defer { IOObjectRelease(service) }

        guard
            let unmanagedValue = IORegistryEntryCreateCFProperty(
                service,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault,
                0
            ),
            let value = unmanagedValue.takeRetainedValue() as? String,
            let normalizedValue = value.trimmedNonEmpty
        else {
            throw DeviceFingerprintError.platformIdentifierUnavailable
        }

        return normalizedValue
    }
}
