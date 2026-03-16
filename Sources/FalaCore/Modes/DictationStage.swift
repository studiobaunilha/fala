/// Stages of the dictation pipeline, used to drive the floating feedback UI.
public enum DictationStage: Sendable, Equatable {
    /// Recording a voice command over selected text (Selection + AI).
    case selectionCommand
    case recording
    case transcribing
    case processing
    case inserting
    case done
}
