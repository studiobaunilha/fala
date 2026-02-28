import Foundation

/// Abstraction over the microphone capture engine.
/// Enables testing DictationMode without real hardware.
public protocol AudioRecording: Sendable {
    func startRecording() throws
    func stopRecording() throws -> URL
}
