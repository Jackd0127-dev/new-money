import SwiftUI

struct PayDefaultsSettingsView: View {
    @ObservedObject var store: PlannerStore
    @State private var hourlyRate = ""
    @State private var hours = ""

    var body: some View {
        ScreenScaffold(
            title: "Pay defaults",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard {
                Picker("Pay frequency", selection: payFrequencyBinding) {
                    ForEach(PayFrequency.allCases) { frequency in
                        Text(frequency.rawValue.capitalized).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)

                MoneyField(title: "Hourly rate", text: $hourlyRate)

                TextField("Default hours", text: $hours)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(AppTextFieldStyle())

                SecondaryButton(title: "Save pay defaults", systemImage: "checkmark", action: save)
            }
        }
        .navigationTopDividerHidden()
        .onAppear(perform: loadValues)
        .accessibilityIdentifier("pay-defaults-settings-screen")
    }

    private var payFrequencyBinding: Binding<PayFrequency> {
        Binding {
            store.snapshot.settings.payFrequency
        } set: { frequency in
            var settings = store.snapshot.settings
            settings.payFrequency = frequency
            settings.defaultPayPeriodDays = FinanceEngine.frequencyToDays(frequency)
            store.updateSettings(settings)
        }
    }

    private func loadValues() {
        hourlyRate = (Double(store.snapshot.settings.hourlyRatePence) / 100)
            .formatted(.number.precision(.fractionLength(2)))
        hours = store.snapshot.settings.defaultHoursWorked
            .formatted(.number.precision(.fractionLength(0...2)))
    }

    private func save() {
        var settings = store.snapshot.settings
        settings.hourlyRatePence = MoneyParser.parsePoundsToPence(hourlyRate)
        settings.defaultHoursWorked = Double(hours) ?? settings.defaultHoursWorked
        store.updateSettings(settings)
    }
}
