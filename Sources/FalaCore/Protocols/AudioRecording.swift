import Foundation

/// Abstraction over the microphone capture engine.
/// Enables testing DictationMode without real hardware.
public protocol AudioRecording: Sendable {
    func startRecording() throws
    func stopRecording() throws -> URL
    /// Sets a callback that receives RMS audio levels from the recording tap.
    /// Called ~every 85ms on the Core Audio thread. Pass nil to stop.
    func setRMSHandler(_ handler: (@Sendable (Float) -> Void)?)
}
