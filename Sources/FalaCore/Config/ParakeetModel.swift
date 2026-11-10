import Foundation

public enum ParakeetModel: String, Codable, CaseIterable, Sendable {
    case ultra
    case v3

    public var displayName: String {
        switch self {
        case .ultra: return "Parakeet Ultra"
        case .v3: return "Parakeet V3"
        }
    }
}
