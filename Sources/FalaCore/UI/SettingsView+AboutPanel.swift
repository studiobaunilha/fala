import SwiftUI

extension SettingsView {
    var aboutPanelView: some View {
        Form {
            applicationIdentitySection
            updatesPreferencesSection
            releaseNotesSection
            licenseStatusSection
            if !licenseManager.isPro {
                licenseActivationSection
            }
            aboutApplicationSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Sobre"))
    }
}
