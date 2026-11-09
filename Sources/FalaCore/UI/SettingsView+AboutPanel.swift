import SwiftUI

extension SettingsView {
    var aboutPanelView: some View {
        Form {
            applicationIdentitySection
            updatesPreferencesSection
            releaseNotesSection
            aboutApplicationSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n("Sobre"))
    }
}
