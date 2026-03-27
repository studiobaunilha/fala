import Foundation

public struct SelectionCommandConfig: Codable, Sendable, Equatable {
    public var prompt: String?
    public var providerPrompts: [String: String]?

    public init(
        prompt: String? = nil,
        providerPrompts: [String: String]? = nil
    ) {
        self.prompt = prompt
        self.providerPrompts = providerPrompts
    }
}
