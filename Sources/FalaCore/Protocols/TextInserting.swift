import Foundation

/// Abstraction over the text-insertion mechanism.
/// Enables testing without Accessibility permission.
/// The insert method is @MainActor because it uses NSPasteboard and CGEventPost.
public protocol TextInserting: Sendable {
    @MainActor func insert(_ text: String) async
    @MainActor func saveToClipboard(_ text: String)
}
