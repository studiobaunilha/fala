/// Stages of the dictation pipeline, used to drive the floating feedback UI.
public enum DictationStage: Sendable, Equatable {
    case recording
    case transcribing
    case processing
    case inserting
    case done
}
