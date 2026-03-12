import Foundation

public struct ModeConfig: Codable, Sendable, Equatable {
    public var provider: String?              // "openai", "gemini", "apple", or nil (use global)
    public var model: String?                 // Specific model or nil (use global)
    public var prompt: String?                // Custom system prompt or nil (use default)
    public var providerPrompts: [String: String]?  // Per-provider prompt overrides

    public init(
        provider: String? = nil,
        model: String? = nil,
        prompt: String? = nil,
        providerPrompts: [String: String]? = nil
    ) {
        self.provider = provider
        self.model = model
        self.prompt = prompt
        self.providerPrompts = providerPrompts
    }
}
