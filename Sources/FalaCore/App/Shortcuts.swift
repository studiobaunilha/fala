import KeyboardShortcuts

@MainActor
public extension KeyboardShortcuts.Name {
    /// Global push-to-talk shortcut. Default: Option+Space.
    static let startDictation = Self("startDictation", default: .init(.space, modifiers: [.option]))
}
