import Foundation

/// Maintains conversation history for the legacy conversational LLM mode.
/// Memory is held in-process only — it does not persist across app sessions.
@MainActor
public final class ConversationMemory {

    public struct Turn: Sendable {
        public let role: String      // "user" | "assistant"
        public let content: String
        public let timestamp: Date
    }

    public private(set) var turns: [Turn] = []

    /// Maximum number of turns kept (default: 10 = 5 Q&A pairs).
    public let maxTurns: Int

    /// After this duration of inactivity, the memory auto-resets.
    public let inactivityTimeout: TimeInterval

    private var lastActivityDate: Date = .distantPast

    /// Tracks the template+provider used for the current conversation.
    /// Automatically resets memory when context changes.
    private var activeContextKey: String?

    public init(maxTurns: Int = 10, inactivityTimeout: TimeInterval = 300) {
        self.maxTurns = maxTurns
        self.inactivityTimeout = inactivityTimeout
    }

    // MARK: - Public API

    /// Appends a user/assistant exchange and trims to maxTurns.
    /// The `contextKey` identifies the template+provider; a change triggers reset.
    public func append(
        userText: String,
        assistantResponse: String,
        contextKey: String? = nil
    ) {
        resetIfStale()
        if let contextKey, contextKey != activeContextKey {
            clear()
            activeContextKey = contextKey
        }
        let now = Date()
        turns.append(Turn(role: "user", content: userText, timestamp: now))
        turns.append(Turn(role: "assistant", content: assistantResponse, timestamp: now))
        lastActivityDate = now
        trimToMax()
    }

    /// Clears all conversation history.
    public func clear() {
        turns.removeAll()
        lastActivityDate = .distantPast
        activeContextKey = nil
    }

    /// Number of complete Q&A pairs.
    public var turnCount: Int {
        turns.count / 2
    }

    /// Whether there is any conversation history.
    public var hasHistory: Bool {
        !turns.isEmpty
    }

    // MARK: - Provider Integration

    /// Returns messages in OpenAI/Gemini chat format (array of role/content dicts).
    public func messagesForAPI() -> [[String: String]] {
        resetIfStale()
        return turns.map { ["role": $0.role, "content": $0.content] }
    }

    /// Returns a text summary of previous turns for providers that don't support multi-turn.
    public var contextSummary: String {
        resetIfStale()
        guard hasHistory else { return "" }
        return turns.map { turn in
            let label = turn.role == "user" ? "User" : "Assistant"
            return "\(label): \(turn.content)"
        }.joined(separator: "\n")
    }

    // MARK: - Private

    private func resetIfStale() {
        guard hasHistory else { return }
        if Date().timeIntervalSince(lastActivityDate) > inactivityTimeout {
            clear()
        }
    }

    private func trimToMax() {
        while turns.count > maxTurns {
            turns.removeFirst()
        }
    }
}
