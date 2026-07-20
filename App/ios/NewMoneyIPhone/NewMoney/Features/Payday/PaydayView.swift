import SwiftUI

struct PaydayView: View {
    @Environment(\.editMode) private var editMode
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var selectedPeriod: PayPeriod? { store.selectedPayPeriod }
    private var periodSummary: PayPeriodCostSummary {
        PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: selectedPeriod, asOfDate: store.todayIso)
    }

    var body: some View {
        ScreenScaffold(
            title: "Spending",
            subtitle: "Spent this period and money left.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            spendingHero
            spendingByPeriod
        }
    }

    private var spendingHero: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Text("Spent this pay period")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                        Text("-\(MoneyParser.formatPence(selectedPeriodSpendPence))")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(selectedPeriodSpendPence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.primaryText)
                            .minimumScaleFactor(0.62)
                        Text(periodLabel)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Pill(text: "\(selectedPeriodTransactions.count) entries", systemImage: "receipt", color: selectedPeriodTransactions.isEmpty ? AppTheme.Colors.tertiaryText : AppTheme.Colors.warning)
                }

                AppDivider()

                MetricRow(label: "Money left", value: MoneyParser.formatPence(periodSummary.currentMoneyLeftPence), valueColor: periodSummary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                MetricRow(label: "Projected costs", value: MoneyParser.formatPence(periodSummary.projectedCostsPence), valueColor: AppTheme.Colors.warning)
                if periodSummary.unfundedChecklistPence > 0 {
                    MetricRow(label: "Unfunded checklist", value: MoneyParser.formatPence(periodSummary.unfundedChecklistPence), valueColor: AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var spendingByPeriod: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Spending by pay period")
            if spendingGroups.isEmpty {
                AppCard {
                    EmptyStateView(title: "No spending yet", message: "Recorded spending will appear here by pay period.", systemImage: "receipt")
                }
            } else {
                ForEach(spendingGroups) { group in
                    AppCard(glow: group.isSelected) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(group.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(group.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            Text("-\(MoneyParser.formatPence(group.totalPence))")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(group.totalPence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.tertiaryText)
                        }

                        if group.transactions.isEmpty {
                            Text("No spending recorded for this period.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        } else {
                            AppDivider()
                            ForEach(group.transactions) { transaction in
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    MetricRow(
                                        label: transaction.note.isEmpty ? "Manual spend" : transaction.note,
                                        value: "\(friendlyDate(transaction.date)) · \(transactionRouteLabel(transaction))",
                                        valueColor: AppTheme.Colors.secondaryText
                                    )

                                    if editMode?.wrappedValue.isEditing == true {
                                        DestructiveBadgeButton(
                                            accessibilityLabel: "Delete \(transaction.note.isEmpty ? "manual spend" : transaction.note)",
                                            confirmationTitle: "Delete this spending entry?",
                                            confirmationMessage: "This spending entry will be removed and any linked balance will be restored.",
                                            action: {
                                                store.deleteTransaction(id: transaction.id)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var selectedPeriodTransactions: [Transaction] {
        guard let selectedPeriod else { return [] }
        return snapshot.transactions
            .filter { $0.type == .spending && $0.deletedAt == nil && !$0.isRefunded && transactionBelongsToPeriod($0, selectedPeriod) }
            .sorted { $0.date > $1.date }
    }

    private var selectedPeriodSpendPence: Int {
        selectedPeriodTransactions.reduce(0) { $0 + $1.amountPence }
    }

    private var periodLabel: String {
        guard let selectedPeriod else { return "No current pay period yet" }
        return "\(friendlyDate(selectedPeriod.startDate)) to \(friendlyDate(selectedPeriod.endDate))"
    }

    private var spendingGroups: [SpendingPeriodGroup] {
        var groups: [String: SpendingPeriodGroup] = [:]

        if let selectedPeriod {
            groups[selectedPeriod.id] = SpendingPeriodGroup(
                id: selectedPeriod.id,
                title: "\(friendlyDate(selectedPeriod.payday)) pay period",
                subtitle: "\(friendlyDate(selectedPeriod.startDate)) to \(friendlyDate(selectedPeriod.endDate))",
                transactions: [],
                totalPence: 0,
                isSelected: true,
                sortDate: selectedPeriod.startDate
            )
        }

        for transaction in snapshot.transactions where transaction.type == .spending && transaction.deletedAt == nil && !transaction.isRefunded {
            let period = period(for: transaction)
            let id = period?.id ?? "outside-periods"
            var group = groups[id] ?? SpendingPeriodGroup(
                id: id,
                title: period.map { "\(friendlyDate($0.payday)) pay period" } ?? "Outside saved pay periods",
                subtitle: period.map { "\(friendlyDate($0.startDate)) to \(friendlyDate($0.endDate))" } ?? "No matching pay period",
                transactions: [],
                totalPence: 0,
                isSelected: period?.id == selectedPeriod?.id,
                sortDate: period?.startDate ?? transaction.date
            )
            group.transactions.append(transaction)
            group.totalPence += transaction.amountPence
            groups[id] = group
        }

        return groups.values
            .map { group in
                var copy = group
                copy.transactions.sort { $0.date > $1.date }
                return copy
            }
            .sorted {
                if $0.isSelected != $1.isSelected {
                    return $0.isSelected
                }
                return $0.sortDate > $1.sortDate
            }
    }

    private func period(for transaction: Transaction) -> PayPeriod? {
        if let payPeriodId = transaction.payPeriodId,
           let period = snapshot.payPeriods.first(where: { $0.id == payPeriodId }) {
            return period
        }

        return PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: transaction.date)
    }

    private func transactionBelongsToPeriod(_ transaction: Transaction, _ period: PayPeriod) -> Bool {
        transaction.payPeriodId == period.id || (transaction.date >= period.startDate && transaction.date <= period.endDate)
    }

    private func transactionRouteLabel(_ transaction: Transaction) -> String {
        if transaction.paymentMethod == .income {
            return PaymentMethod.income.displayName
        }

        if transaction.paymentMethod == .creditCard || transaction.creditCardId != nil {
            guard let cardId = transaction.creditCardId else { return "Credit card" }
            return snapshot.creditCards.first { $0.id == cardId }?.name ?? "Credit card"
        }

        if let potId = transaction.potId {
            return snapshot.pots.first { $0.id == potId }?.name ?? "Pot"
        }

        return "Money left"
    }

    private func friendlyDate(_ isoDate: String) -> String {
        let date = FinanceEngine.parseDate(isoDate)
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct SpendingPeriodGroup: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var transactions: [Transaction]
    var totalPence: Int
    var isSelected: Bool
    var sortDate: String
}

struct AddPaycheckSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var isOneOffIncome = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if isOneOffIncome {
                        OneOffIncomeFormCard(store: store) {
                            dismiss()
                        }
                    } else {
                        PaycheckPlanFormCard(store: store) {
                            dismiss()
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add income")
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isOneOffIncome ? "Paycheck" : "One off") {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            isOneOffIncome.toggle()
                        }
                    }
                }
            }
        }
    }
}

struct PaycheckPlanFormCard: View {
    @ObservedObject var store: PlannerStore
    var onSaved: (() -> Void)?
    @State private var payday = Date()
    @State private var hoursWorked = ""
    @State private var hourlyRate = ""

    var body: some View {
        AppCard(glow: true) {
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
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                MoneyField(title: "Hourly rate", text: $hourlyRate)
                    .layoutPriority(1)
                paidInPreview
                    .frame(width: 132)
            }

            PrimaryButton(title: "Save paycheck plan", systemImage: "checkmark", isDisabled: !canSavePaycheckPlan) {
                store.createPayPeriod(
                    payday: payday.isoDateString,
                    hoursWorked: Double(hoursWorked) ?? 0,
                    hourlyRatePence: MoneyParser.parsePoundsToPence(hourlyRate),
                    actualAmountPence: nil,
                    payFrequency: store.snapshot.settings.payFrequency
                )
                hoursWorked = ""
                hourlyRate = ""
                onSaved?()
            }
        }
    }

    private var paidInPreview: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Paid in")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(MoneyParser.formatPence(calculatedPayPence))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.success)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(AppTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AppTheme.Colors.success.opacity(0.35), lineWidth: 1)
        )
    }

    private var canSavePaycheckPlan: Bool {
        let hours = Double(hoursWorked) ?? 0
        let rate = MoneyParser.parsePoundsToPence(hourlyRate)
        return hours > 0 && rate > 0
    }

    private var calculatedPayPence: Int {
        FinanceEngine.calculatePaycheckAmount(
            hoursWorked: Double(hoursWorked) ?? 0,
            hourlyRatePence: MoneyParser.parsePoundsToPence(hourlyRate),
            actualAmountPence: nil
        )
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

struct OneOffIncomeFormCard: View {
    @ObservedObject var store: PlannerStore
    var onSaved: (() -> Void)?
    @State private var incomeDate = Date()
    @State private var name = ""
    @State private var amount = ""
    @State private var note = ""

    var body: some View {
        AppCard(glow: true) {
            SectionTitle("Add one-off income")
            DatePicker("Date", selection: $incomeDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(AppTheme.Colors.primaryOrange)
                .foregroundStyle(AppTheme.Colors.primaryText)

            TextField("Source", text: $name)
                .textFieldStyle(AppTextFieldStyle())

            MoneyField(title: "Amount", text: $amount)

            TextField("Note", text: $note)
                .textFieldStyle(AppTextFieldStyle())

            PrimaryButton(title: "Add income", systemImage: "plus", isDisabled: !canSave) {
                guard store.addOneOffIncome(
                    name: name,
                    amountPence: MoneyParser.parsePoundsToPence(amount),
                    date: incomeDate.isoDateString,
                    note: note
                ) else { return }
                name = ""
                amount = ""
                note = ""
                onSaved?()
            }
        }
    }

    private var canSave: Bool {
        MoneyParser.parsePoundsToPence(amount) > 0
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
