import ApplicationServices
import Foundation

enum VersionChangeDetector {
    private static let lastRunVersionKey = "dev.fala.last-run-version"
    private static let onboardingCompleteKey = "dev.fala.onboarding-essential-complete"

    /// Detects whether the app was upgraded since the previous launch.
    /// Returns `true` when a previous version existed and differs from the
    /// current one. First installs return `false` so callers (like the
    /// release-notes modal) don't show update prompts to brand-new users.
    @discardableResult
    static func handleVersionChangeIfNeeded() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: lastRunVersionKey)

        let wasUpgrade = lastVersion != nil && lastVersion != currentVersion
        if wasUpgrade {
            onVersionChanged()
        }

        UserDefaults.standard.set(currentVersion, forKey: lastRunVersionKey)
        return wasUpgrade
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
