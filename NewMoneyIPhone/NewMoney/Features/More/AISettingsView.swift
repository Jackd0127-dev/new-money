import SwiftUI

struct AISettingsView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "AI",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            SettingsPanel(
                title: "On-device assistant",
                subtitle: "Answers use your saved planner data.",
                systemImage: "sparkles"
            ) {
                Text("No online AI provider is connected. The assistant can explain supported totals, but cannot change your planner.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                SelectionField(title: "Response style", value: responseStyle.label, systemImage: "text.bubble") {
                    ForEach(AssistantResponseStyle.allCases) { style in
                        Button(style.label) {
                            var settings = store.snapshot.settings
                            settings.assistantResponseStyle = style
                            store.updateSettings(settings)
                        }
                    }
                }

                Text("Provider preferences and custom instructions remain saved, but are not used by local replies.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("ai-settings-screen")
    }

    private var responseStyle: AssistantResponseStyle {
        store.snapshot.settings.assistantResponseStyle ?? .straightToThePoint
    }
}
