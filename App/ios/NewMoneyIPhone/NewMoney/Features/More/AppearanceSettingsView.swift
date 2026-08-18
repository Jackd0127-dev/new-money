import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue

    var body: some View {
        ScreenScaffold(
            title: "Appearance",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppearanceThemeCustomizerCard(selectedThemeRawValue: $selectedThemeRawValue)
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("appearance-settings-screen")
    }
}
