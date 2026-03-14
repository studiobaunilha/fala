import Foundation

public struct HardwareInfo {
    /// Returns the active Mac hardware model identifier (e.g., "Mac14,2").
    public static var hwModel: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let bytes = model.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    /// Determines if the current Apple Silicon Mac belongs to a generation known to experience
    /// inference freezes or slowness when using the Apple Neural Engine for audio operations in CoreML.
    /// This generally encompasses the M1, M2, and M3 families.
    public static var isKnownToFreezeWhisperANE: Bool {
        isKnownToFreezeWhisperANE(forModel: hwModel)
    }

    /// Evaluates if a given hardware model string matches the Apple Silicon chips
    /// known to hang or slow down CoreML operations using the ANE.
    public static func isKnownToFreezeWhisperANE(forModel model: String) -> Bool {
        let prefixes = [
            "Mac13,", "Mac14,", "Mac15,",
            "MacBookPro17,", "MacBookPro18,",
            "MacBookAir10,", "Macmini9,", "iMac21,"
        ]
        return prefixes.contains { model.hasPrefix($0) }
    }
}
