import SwiftUI

struct DateSimulationSettingsView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "Date simulation",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            DateSimulationCard(store: store)
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("date-simulation-settings-screen")
    }
}
