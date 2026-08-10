import SwiftUI

struct MoneyLeftSettingsView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "Money left",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                Toggle("Include pots in Money left", isOn: includePotsBinding)
                    .tint(AppTheme.Colors.success)
                    .foregroundStyle(AppTheme.Colors.primaryText)

                Text("Turn this off to show only bank-account balances and current income that is not linked to an account. Pot and card-reserve balances stay tracked but are left out of the total.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("money-left-settings-screen")
    }

    private var includePotsBinding: Binding<Bool> {
        Binding {
            store.snapshot.settings.includePotsInMoneyLeft ?? true
        } set: { includesPots in
            var settings = store.snapshot.settings
            settings.includePotsInMoneyLeft = includesPots
            store.updateSettings(settings)
        }
    }
}
