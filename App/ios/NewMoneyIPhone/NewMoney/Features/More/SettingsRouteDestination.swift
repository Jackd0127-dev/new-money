import SwiftUI

struct SettingsRouteDestination: View {
    var route: SettingsRoute
    @ObservedObject var store: PlannerStore

    @ViewBuilder
    var body: some View {
        switch route {
        case .appearance:
            AppearanceSettingsView()
        case .payDefaults:
            PayDefaultsSettingsView(store: store)
        case .dateSimulation:
            DateSimulationSettingsView(store: store)
        case .moneyLeft:
            MoneyLeftSettingsView(store: store)
        case .history:
            HistoryView(store: store)
        case .ai:
            AISettingsView(store: store)
        case .account:
            AccountSettingsView()
        case .data:
            DataSettingsView(store: store)
        }
    }
}
