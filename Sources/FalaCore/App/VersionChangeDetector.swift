import ApplicationServices
import Foundation

enum VersionChangeDetector {
    private static let lastRunVersionKey = "dev.fala.last-run-version"
    private static let onboardingCompleteKey = "dev.fala.onboarding-essential-complete"

    static func handleVersionChangeIfNeeded() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastRunVersionKey)

        if let lastVersion, lastVersion != currentVersion {
            onVersionChanged()
        }

        UserDefaults.standard.set(currentVersion, forKey: lastRunVersionKey)
    }

    private static func onVersionChanged() {
        // After a Sparkle update the binary hash changes and macOS invalidates
        // the Accessibility TCC entry. Reset onboarding so the user gets guided
        // to re-grant the permission.
        if !AXIsProcessTrusted() {
            UserDefaults.standard.removeObject(forKey: onboardingCompleteKey)
        }
    }
}
