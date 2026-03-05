import SwiftUI

public enum AnimationConfig {
    @MainActor public static var enabled: Bool = true

    @MainActor public static var standard: Animation? {
        enabled ? .easeInOut(duration: 0.2) : nil
    }
    @MainActor public static var spring: Animation? {
        enabled ? .spring(response: 0.35, dampingFraction: 0.8) : nil
    }
}
