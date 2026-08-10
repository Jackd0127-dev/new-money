import SwiftUI

struct DataSettingsView: View {
    @ObservedObject var store: PlannerStore
    @State private var showResetAlert = false

    var body: some View {
        ScreenScaffold(
            title: "Data",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                Text("Resetting local data clears paychecks, pots, bills, cards, debts, spending, history, date simulation, and saved settings from this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button("Reset local data", role: .destructive) {
                    showResetAlert = true
                }
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.danger)
            }
        }
        .navigationTopDividerHidden()
        .alert("Reset local planner?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetLocalData()
            }
        } message: {
            Text("This clears local iPhone planner inputs and returns the app to its default data.")
        }
        .accessibilityIdentifier("data-settings-screen")
    }
}
