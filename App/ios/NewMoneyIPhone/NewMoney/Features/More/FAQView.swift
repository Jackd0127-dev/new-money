import SwiftUI

struct FAQView: View {
    var body: some View {
        ScreenScaffold(
            title: "FAQ",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                VStack(spacing: 0) {
                    DisclosureGroup("What does Money left include?") {
                        Text("Money left uses your current cash position. You can choose in Settings whether pot balances are included in that total.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.sm)

                    AppDivider()

                    DisclosureGroup("How do upcoming card payments work?") {
                        Text("The first payment is the issued statement balance. The following payment updates from spending recorded after that statement and moves forward when the current Direct Debit is paid.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.sm)

                    AppDivider()

                    DisclosureGroup("What does date simulation change?") {
                        Text("Manual date simulation lets you inspect how the planner behaves on another date. Switching back to Automatic returns the app to the real current date.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.sm)

                    AppDivider()

                    DisclosureGroup("Is my planner synced?") {
                        Text("When you are signed in and cloud sync is available, New Money keeps the current planner account synced. The Account settings page shows the current sync status.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.sm)

                    AppDivider()

                    DisclosureGroup("What happens when I reset data?") {
                        Text("Reset Data from Profile permanently resets planner data after two confirmations while keeping your login account. The Data settings page also provides the existing local-iPhone reset.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .tint(AppTheme.Colors.accent)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
            }
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("faq-screen")
    }
}
