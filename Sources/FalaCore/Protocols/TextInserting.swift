import Foundation

/// Abstraction over the text-insertion mechanism.
/// Enables testing without Accessibility permission.
/// The insert method is @MainActor because it uses NSPasteboard and CGEventPost.
public protocol TextInserting: Sendable {
    @MainActor func insert(_ text: String) async
    @MainActor func saveToClipboard(_ text: String)
    @MainActor func undoLastInsertion() async
    @MainActor func replaceLastInsertion(with text: String) async
}

public extension TextInserting {
    @MainActor func undoLastInsertion() async {}

    @MainActor func replaceLastInsertion(with text: String) async {
        await insert(text)
    }
}
