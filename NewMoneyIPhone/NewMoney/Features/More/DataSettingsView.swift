import SwiftUI

struct DataSettingsView: View {
    @EnvironmentObject private var authSession: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    @State private var showResetAlert = false

    var body: some View {
        ScreenScaffold(
            title: "Data",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            PlannerSaveStatusView(store: store, session: authSession)

            SettingsPanel(
                title: "Planner data",
                subtitle: "Reset the active planner without deleting your login.",
                systemImage: "externaldrive.badge.xmark",
                tint: AppTheme.Colors.danger,
                isDestructive: true
            ) {
                Text("Resetting clears paychecks, pots, bills, cards, debts, spending, history, and settings in the active planner. This reset also syncs to its cloud copy.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                Button(role: .destructive) {
                    showResetAlert = true
                } label: {
                    CompactMenuRow(
                        title: "Reset active planner",
                        systemImage: "trash",
                        isDestructive: true,
                        showsDisclosure: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTopDividerHidden()
        .alert("Reset active planner?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.resetLocalData()
            }
        } message: {
            Text("This clears the active planner on this iPhone and syncs the reset to the cloud. Your login and other planner accounts are kept.")
        }
        .accessibilityIdentifier("data-settings-screen")
    }
}
