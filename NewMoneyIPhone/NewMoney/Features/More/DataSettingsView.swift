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
            SettingsPanel(
                title: "Local planner data",
                subtitle: "Clear this iPhone without deleting your login.",
                systemImage: "externaldrive.badge.xmark",
                tint: AppTheme.Colors.danger,
                isDestructive: true
            ) {
                Text("Resetting local data clears paychecks, pots, bills, cards, debts, spending, history, date simulation, and saved settings from this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    CompactMenuRow(
                        title: "Reset local data",
                        systemImage: "trash",
                        isDestructive: true,
                        showsDisclosure: false
                    )
                }
                .buttonStyle(.plain)
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
