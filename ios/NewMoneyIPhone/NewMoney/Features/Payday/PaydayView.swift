import SwiftUI

struct PaydayView: View {
    @ObservedObject var store: PlannerStore
    @State private var payday = Date()
    @State private var hoursWorked = ""
    @State private var hourlyRate = ""
    @State private var actualAmount = ""
    @State private var selectedPotId = ""
    @State private var allocationAmount = ""

    var body: some View {
        ScreenScaffold(
            title: "Payday",
            subtitle: "Calculate pay, create periods, and set money aside."
        ) {
            createPlanCard
            allocationCard
            payPeriodHistory
        }
        .onAppear {
            selectedPotId = store.activePots.first?.id ?? ""
        }
    }

    private var createPlanCard: some View {
        AppCard(glow: store.selectedPayPeriod == nil) {
            SectionTitle("Create paycheck plan")
            DatePicker("Payday", selection: $payday, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(AppTheme.Colors.primaryOrange)
                .foregroundStyle(AppTheme.Colors.primaryText)

            Picker("Frequency", selection: bindingPayFrequency) {
                ForEach(PayFrequency.allCases) { frequency in
                    Text(frequency.rawValue.capitalized).tag(frequency)
                }
            }
            .pickerStyle(.segmented)

            TextField("Hours worked", text: $hoursWorked)
                .keyboardType(.decimalPad)
                .textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Hourly rate", text: $hourlyRate)
            MoneyField(title: "Actual received (optional)", text: $actualAmount)

            PrimaryButton(title: "Save paycheck plan", systemImage: "checkmark", isDisabled: !canSavePaycheckPlan) {
                let hours = Double(hoursWorked) ?? 0
                let rate = MoneyParser.parsePoundsToPence(hourlyRate)
                let actual = actualAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : MoneyParser.parsePoundsToPence(actualAmount)
                store.createPayPeriod(payday: payday.isoDateString, hoursWorked: hours, hourlyRatePence: rate, actualAmountPence: actual)
                hoursWorked = ""
                hourlyRate = ""
                actualAmount = ""
            }
        }
    }

    private var canSavePaycheckPlan: Bool {
        let hours = Double(hoursWorked) ?? 0
        let rate = MoneyParser.parsePoundsToPence(hourlyRate)
        let actual = MoneyParser.parsePoundsToPence(actualAmount)
        return actual > 0 || (hours > 0 && rate > 0)
    }

    private var allocationCard: some View {
        AppCard {
            SectionTitle("Allocate to pot")
            if store.activePots.isEmpty || store.selectedPayPeriod == nil {
                EmptyStateView(title: "No active period", message: "Create a paycheck plan before allocating money.", systemImage: "wallet.pass")
            } else {
                Picker("Pot", selection: $selectedPotId) {
                    ForEach(store.activePots) { pot in
                        Text(pot.name).tag(pot.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primaryOrange)

                MoneyField(title: "Amount", text: $allocationAmount)
                SecondaryButton(title: "Add allocation", systemImage: "plus") {
                    store.addPotAllocation(potId: selectedPotId, amountPence: MoneyParser.parsePoundsToPence(allocationAmount))
                    allocationAmount = ""
                }
            }
        }
    }

    private var payPeriodHistory: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Pay periods")
            if store.snapshot.payPeriods.isEmpty {
                AppCard {
                    EmptyStateView(title: "No paydays yet", message: "Saved paycheck plans appear here.", systemImage: "calendar")
                }
            } else {
                ForEach(store.snapshot.payPeriods.sorted { $0.payday > $1.payday }) { period in
                    AppCard {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(period.payday)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text("\(period.startDate) to \(period.endDate)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(MoneyParser.formatPence(period.incomePence))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                                Pill(text: period.status.rawValue.capitalized, systemImage: "circle.fill", color: period.status == .active ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    private var bindingPayFrequency: Binding<PayFrequency> {
        Binding {
            store.snapshot.settings.payFrequency
        } set: { newValue in
            var settings = store.snapshot.settings
            settings.payFrequency = newValue
            settings.defaultPayPeriodDays = FinanceEngine.frequencyToDays(newValue)
            store.updateSettings(settings)
        }
    }
}
