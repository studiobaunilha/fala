import AppKit
import AVFoundation
import ApplicationServices

public enum MicrophonePermissionState: String, Equatable, Sendable {
    case granted
    case notDetermined
    case denied
}

@MainActor
public protocol SystemPermissionProviding: AnyObject {
    func microphonePermissionState() -> MicrophonePermissionState
    func requestMicrophoneAccess() async -> Bool
    func isAccessibilityTrusted() -> Bool
    func openMicrophoneSettings()
    func openAccessibilitySettings()
}

@MainActor
public final class SystemPermissionProvider: SystemPermissionProviding {
    public init() {}

    public func microphonePermissionState() -> MicrophonePermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    public func requestMicrophoneAccess() async -> Bool {
        if microphonePermissionState() == .granted {
            return true
        }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public func openMicrophoneSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    public func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
