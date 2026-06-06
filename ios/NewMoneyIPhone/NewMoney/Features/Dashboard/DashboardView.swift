import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedPaycheck: Paycheck?

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        ScreenScaffold(
            title: "Overview",
            subtitle: "Payday pressure, pots, cards, debts, and recent activity."
        ) {
            if store.isLoading {
                LoadingView()
            }

            if let message = store.errorMessage {
                ErrorBanner(message: message) {
                    store.errorMessage = nil
                }
            }

            heroCard
            statsGrid
            recentActivity
        }
        .sheet(item: $selectedPaycheck) { paycheck in
            PaycheckDetailView(store: store, paycheck: paycheck)
        }
    }

    private var heroCard: some View {
        AppCard(glow: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Safe to spend")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.warmSand)
                    Text(MoneyParser.formatPence(dailySafeToSpend))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .minimumScaleFactor(0.62)
                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Pill(text: store.selectedPayPeriod?.payday ?? "No payday", systemImage: "calendar")
                    Text(MoneyParser.formatPence(spendablePence))
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
            statLink {
                IncomeBreakdownView(store: store)
            } label: {
                StatCard(title: "Income", value: MoneyParser.formatPence(store.selectedPayPeriod?.incomePence ?? 0), subtitle: "Current plan", systemImage: "sterlingsign.circle")
            }
            statLink {
                BillsBreakdownView(store: store)
            } label: {
                StatCard(title: "Bills", value: MoneyParser.formatPence(billsDuePence), subtitle: "Due in period", systemImage: "calendar.badge.clock", tone: AppTheme.Colors.warning)
            }
            statLink {
                CardsBreakdownView(store: store)
            } label: {
                StatCard(title: "Cards", value: MoneyParser.formatPence(totalCardOwed), subtitle: "\(store.activeCards.count) active", systemImage: "creditcard", tone: AppTheme.Colors.orangeHighlight)
            }
            statLink {
                DebtsBreakdownView(store: store)
            } label: {
                StatCard(title: "Debts", value: MoneyParser.formatPence(debtSummary.totalCurrentBalancePence), subtitle: "\(debtSummary.activeDebtCount) active", systemImage: "exclamationmark.shield", tone: debtSummary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
            }
        }
    }

    private func statLink<Destination: View, Label: View>(
        @ViewBuilder destination: () -> Destination,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            label()
                .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Recent activity")
            if recentRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "No activity yet", message: "Payday plans, pot allocations, and spend records will appear here.", systemImage: "clock")
                }
            } else {
                AppCard {
                    ForEach(recentRows.prefix(6), id: \.id) { row in
                        if let paycheckId = row.paycheckId {
                            Button {
                                selectedPaycheck = snapshot.paychecks.first(where: { $0.id == paycheckId })
                            } label: {
                                DashboardActivityRowView(row: row, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            DashboardActivityRowView(row: row)
                        }
                    }
                }
            }
        }
    }

    private var heroSubtitle: String {
        guard let period = store.selectedPayPeriod else {
            return "Start with Payday to create a live period."
        }
        return "Based on spendable pots until \(period.endDate)."
    }

    private var spendablePence: Int {
        FinanceEngine.getSpendablePence(pots: snapshot.pots)
    }

    private var dailySafeToSpend: Int {
        guard let period = store.selectedPayPeriod else { return 0 }
        return FinanceEngine.getDailySafeToSpendPence(spendablePence: spendablePence, today: store.todayIso, endDate: period.endDate)
    }

    private var billsDuePence: Int {
        guard let period = store.selectedPayPeriod else { return 0 }
        return PlannerDerivedData.recurringOccurrences(
            payments: snapshot.recurringPayments,
            startDate: period.startDate,
            endDate: period.endDate
        )
        .reduce(0) { $0 + $1.amountPence }
    }

    private var totalCardOwed: Int {
        store.activeCards.reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: snapshot) }
    }

    private var debtSummary: DebtSummary {
        FinanceEngine.getDebtSummary(debts: snapshot.debts, payments: snapshot.debtPayments, reserves: snapshot.debtReserves, pots: snapshot.pots, today: store.todayIso)
    }

    private var recentRows: [DashboardActivityRow] {
        let transactions = snapshot.transactions.map {
            DashboardActivityRow(
                id: $0.id,
                title: $0.note.isEmpty ? "Spending" : $0.note,
                detail: $0.date,
                amount: "-\(MoneyParser.formatPence($0.amountPence))",
                symbol: $0.paymentMethod == .creditCard ? "creditcard" : "cart",
                color: AppTheme.Colors.orangeHighlight
            )
        }
        let paychecks = snapshot.paychecks.map {
            DashboardActivityRow(
                id: $0.id,
                title: "Paycheck",
                detail: $0.createdAt.prefixDateLabel,
                amount: MoneyParser.formatPence($0.calculatedAmountPence),
                symbol: "sterlingsign.circle",
                color: AppTheme.Colors.success,
                paycheckId: $0.id
            )
        }
        let allocations = snapshot.potAllocations.map { allocation in
            DashboardActivityRow(
                id: allocation.id,
                title: snapshot.pots.first(where: { pot in pot.id == allocation.potId })?.name ?? "Pot allocation",
                detail: allocation.createdAt.prefixDateLabel,
                amount: MoneyParser.formatPence(allocation.amountPence),
                symbol: "wallet.pass",
                color: AppTheme.Colors.primaryOrange
            )
        }
        return (transactions + paychecks + allocations).prefix(12).map { $0 }
    }
}

private struct DashboardActivityRow {
    var id: String
    var title: String
    var detail: String
    var amount: String
    var symbol: String
    var color: Color
    var paycheckId: String? = nil
}

private struct DashboardActivityRowView: View {
    var row: DashboardActivityRow
    var showsChevron = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: row.symbol)
                .foregroundStyle(row.color)
                .frame(width: 32, height: 32)
                .background(row.color.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            Spacer()
            Text(row.amount)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(row.color)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct DashboardBreakdownScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                ScreenHeader(subtitle: subtitle)
                content
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.sm)
            .padding(.bottom, 110)
        }
        .premiumScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct IncomeBreakdownView: View {
    @ObservedObject var store: PlannerStore

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        DashboardBreakdownScaffold(title: "Income", subtitle: "Paycheck inputs, pay periods, and allocation history.") {
            AppCard(glow: true) {
                MetricRow(label: "Current plan", value: MoneyParser.formatPence(store.selectedPayPeriod?.incomePence ?? 0), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Total income", value: MoneyParser.formatPence(snapshot.payPeriods.reduce(0) { $0 + $1.incomePence }), valueColor: AppTheme.Colors.primaryOrange)
                MetricRow(label: "Paychecks", value: "\(snapshot.paychecks.count)")
                MetricRow(label: "Allocated", value: MoneyParser.formatPence(snapshot.potAllocations.reduce(0) { $0 + $1.amountPence }))
            }

            SectionTitle("Paycheck inputs")
            if snapshot.paychecks.isEmpty {
                AppCard { EmptyStateView(title: "No paycheck inputs", message: "Saved paycheck plans will appear here.", systemImage: "sterlingsign.circle") }
            } else {
                ForEach(snapshot.paychecks.sorted { $0.createdAt > $1.createdAt }) { paycheck in
                    AppCard {
                        MetricRow(label: "Payday", value: period(for: paycheck)?.payday ?? "No linked period")
                        MetricRow(label: "Calculated", value: MoneyParser.formatPence(paycheck.calculatedAmountPence), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Hours", value: formatHours(paycheck.hoursWorked))
                        MetricRow(label: "Hourly rate", value: MoneyParser.formatPence(paycheck.hourlyRatePence))
                        MetricRow(label: "Actual received", value: paycheck.actualAmountPence.map { MoneyParser.formatPence($0) } ?? "Not set", valueColor: AppTheme.Colors.primaryOrange)
                        MetricRow(label: "Created", value: paycheck.createdAt.prefixDateLabel)
                    }
                }
            }

            SectionTitle("Pay periods")
            if snapshot.payPeriods.isEmpty {
                AppCard { EmptyStateView(title: "No pay periods", message: "Create a paycheck plan to start tracking periods.", systemImage: "calendar") }
            } else {
                ForEach(snapshot.payPeriods.sorted { $0.payday > $1.payday }) { period in
                    AppCard {
                        MetricRow(label: "Payday", value: period.payday)
                        MetricRow(label: "Period", value: "\(period.startDate) to \(period.endDate)")
                        MetricRow(label: "Next payday", value: period.nextPayday)
                        MetricRow(label: "Income", value: MoneyParser.formatPence(period.incomePence), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Status", value: period.status.rawValue.capitalized)
                        MetricRow(label: "Allocated", value: MoneyParser.formatPence(allocations(for: period).reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
                        ForEach(allocations(for: period)) { allocation in
                            MetricRow(label: potName(for: allocation.potId), value: MoneyParser.formatPence(allocation.amountPence))
                        }
                    }
                }
            }
        }
    }

    private func period(for paycheck: Paycheck) -> PayPeriod? {
        snapshot.payPeriods.first { $0.id == paycheck.payPeriodId }
    }

    private func allocations(for period: PayPeriod) -> [PotAllocation] {
        snapshot.potAllocations.filter { $0.payPeriodId == period.id }
    }

    private func potName(for id: String) -> String {
        snapshot.pots.first { $0.id == id }?.name ?? "Pot"
    }

    private func formatHours(_ hours: Double) -> String {
        guard hours > 0 else { return "Not set" }
        if hours.rounded() == hours {
            return String(format: "%.0f", hours)
        }
        return String(format: "%.2f", hours)
    }
}

private struct BillsBreakdownView: View {
    @ObservedObject var store: PlannerStore

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        DashboardBreakdownScaffold(title: "Bills", subtitle: "Recurring bills, upcoming due dates, and linked accounts.") {
            AppCard(glow: true) {
                MetricRow(label: "Due in period", value: MoneyParser.formatPence(currentPeriodBills), valueColor: AppTheme.Colors.warning)
                MetricRow(label: "Active bills", value: "\(snapshot.recurringPayments.filter(\.active).count)")
                MetricRow(label: "All bill templates", value: "\(snapshot.recurringPayments.count)")
                MetricRow(label: "Next 30 days", value: MoneyParser.formatPence(upcomingBills.reduce(0) { $0 + $1.amountPence }))
            }

            SectionTitle("Next 30 days")
            if upcomingBills.isEmpty {
                AppCard { EmptyStateView(title: "No upcoming bills", message: "Recurring payments with due dates will appear here.", systemImage: "calendar") }
            } else {
                AppCard {
                    ForEach(upcomingBills) { occurrence in
                        MetricRow(label: "\(occurrence.dueDate) · \(occurrence.payment.name)", value: MoneyParser.formatPence(occurrence.amountPence), valueColor: AppTheme.Colors.warning)
                    }
                }
            }

            SectionTitle("All bills")
            if snapshot.recurringPayments.isEmpty {
                AppCard { EmptyStateView(title: "No bills yet", message: "Add recurring payments from Bills to populate this breakdown.", systemImage: "calendar.badge.plus") }
            } else {
                ForEach(snapshot.recurringPayments.sorted { lhs, rhs in
                    if lhs.active == rhs.active { return lhs.name < rhs.name }
                    return lhs.active && !rhs.active
                }) { payment in
                    AppCard {
                        MetricRow(label: "Name", value: payment.name)
                        MetricRow(label: "Amount", value: MoneyParser.formatPence(payment.amountPence), valueColor: AppTheme.Colors.primaryOrange)
                        MetricRow(label: "Frequency", value: payment.frequency.rawValue.capitalized)
                        MetricRow(label: "Priority", value: payment.priority.rawValue.capitalized)
                        MetricRow(label: "Due day", value: payment.dueDay.map(String.init) ?? "Not set")
                        MetricRow(label: "Linked", value: linkedTarget(for: payment))
                        MetricRow(label: "Status", value: payment.active ? "Active" : "Inactive", valueColor: payment.active ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
                    }
                }
            }
        }
    }

    private var currentPeriodBills: Int {
        guard let period = store.selectedPayPeriod else { return 0 }
        return PlannerDerivedData.recurringOccurrences(payments: snapshot.recurringPayments, startDate: period.startDate, endDate: period.endDate)
            .reduce(0) { $0 + $1.amountPence }
    }

    private var upcomingBills: [RecurringPaymentOccurrence] {
        PlannerDerivedData.recurringOccurrences(
            payments: snapshot.recurringPayments,
            startDate: store.todayIso,
            endDate: FinanceEngine.addIsoDays(date: store.todayIso, days: 30)
        )
    }

    private func linkedTarget(for payment: RecurringPayment) -> String {
        if let potId = payment.potId {
            return snapshot.pots.first { $0.id == potId }?.name ?? "Linked pot"
        }
        if let cardId = payment.creditCardId {
            return snapshot.creditCards.first { $0.id == cardId }?.name ?? "Linked card"
        }
        return "None"
    }
}

private struct CardsBreakdownView: View {
    @ObservedObject var store: PlannerStore

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var activeCards: [CreditCard] { snapshot.creditCards.filter { !$0.archived } }
    private var archivedCards: [CreditCard] { snapshot.creditCards.filter(\.archived) }

    var body: some View {
        DashboardBreakdownScaffold(title: "Cards", subtitle: "Balances, limits, cover pots, saved payments, and repayments.") {
            AppCard(glow: true) {
                MetricRow(label: "Owed", value: MoneyParser.formatPence(totalOwed), valueColor: AppTheme.Colors.orangeHighlight)
                MetricRow(label: "Available credit", value: MoneyParser.formatPence(availableCredit))
                MetricRow(label: "Active cards", value: "\(activeCards.count)")
                MetricRow(label: "Cover pots", value: MoneyParser.formatPence(activeCoverPots.reduce(0) { $0 + $1.amountPence }))
            }

            SectionTitle("Active cards")
            if activeCards.isEmpty {
                AppCard { EmptyStateView(title: "No active cards", message: "Add cards to track balances and repayments.", systemImage: "creditcard") }
            } else {
                ForEach(activeCards) { card in
                    cardBreakdown(card)
                }
            }

            if !archivedCards.isEmpty {
                SectionTitle("Archived cards")
                ForEach(archivedCards) { card in
                    cardBreakdown(card)
                }
            }

            SectionTitle("Saved card payments")
            if snapshot.customPayments.isEmpty {
                AppCard { EmptyStateView(title: "No saved payments", message: "Saved card payments will appear here.", systemImage: "calendar.badge.plus") }
            } else {
                AppCard {
                    ForEach(snapshot.customPayments.sorted { $0.dueDate < $1.dueDate }) { payment in
                        MetricRow(label: "\(payment.dueDate) · \(payment.name)", value: "\(MoneyParser.formatPence(payment.amountPence)) · \(cardName(for: payment.creditCardId))", valueColor: payment.status == .unpaid ? AppTheme.Colors.warning : AppTheme.Colors.tertiaryText)
                    }
                }
            }

            SectionTitle("Repayments")
            if snapshot.creditCardRepayments.isEmpty {
                AppCard { EmptyStateView(title: "No repayments", message: "Card repayments will appear here.", systemImage: "arrow.down.circle") }
            } else {
                AppCard {
                    ForEach(snapshot.creditCardRepayments.sorted { $0.date > $1.date }) { repayment in
                        MetricRow(label: "\(repayment.date) · \(cardName(for: repayment.creditCardId))", value: MoneyParser.formatPence(repayment.amountPence), valueColor: AppTheme.Colors.success)
                    }
                }
            }
        }
    }

    private var totalOwed: Int {
        activeCards.reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: snapshot) }
    }

    private var totalLimits: Int {
        activeCards.reduce(0) { $0 + $1.limitPence }
    }

    private var availableCredit: Int {
        max(0, totalLimits - totalOwed)
    }

    private var activeCoverPots: [CreditCardPot] {
        snapshot.creditCardPots.filter { $0.status == .active }
    }

    private func cardBreakdown(_ card: CreditCard) -> some View {
        let balance = PlannerDerivedData.cardBalance(card: card, snapshot: snapshot)
        let cardCoverPots = snapshot.creditCardPots.filter { $0.creditCardId == card.id && $0.status == .active }
        let cardPayments = snapshot.customPayments.filter { $0.creditCardId == card.id }
        let cardRepayments = snapshot.creditCardRepayments.filter { $0.creditCardId == card.id }

        return AppCard(glow: balance > card.limitPence) {
            Text(card.name)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            MetricRow(label: "Provider", value: card.provider)
            MetricRow(label: "Balance", value: MoneyParser.formatPence(balance), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Limit", value: MoneyParser.formatPence(card.limitPence))
            MetricRow(label: "Available", value: MoneyParser.formatPence(max(0, card.limitPence - balance)), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Opening balance", value: MoneyParser.formatPence(card.openingBalancePence ?? 0))
            MetricRow(label: "Due day", value: card.dueDay.map(String.init) ?? "Not set")
            MetricRow(label: "Cover pots", value: MoneyParser.formatPence(cardCoverPots.reduce(0) { $0 + $1.amountPence }))
            MetricRow(label: "Saved payments", value: MoneyParser.formatPence(cardPayments.reduce(0) { $0 + $1.amountPence }))
            MetricRow(label: "Repayments", value: MoneyParser.formatPence(cardRepayments.reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.success)
        }
    }

    private func cardName(for id: String?) -> String {
        guard let id else { return "No card" }
        return snapshot.creditCards.first { $0.id == id }?.name ?? "Card"
    }
}

private struct DebtsBreakdownView: View {
    @ObservedObject var store: PlannerStore

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var summary: DebtSummary {
        FinanceEngine.getDebtSummary(debts: snapshot.debts, payments: snapshot.debtPayments, reserves: snapshot.debtReserves, pots: snapshot.pots, today: store.todayIso)
    }
    private var activeDebts: [Debt] { snapshot.debts.filter { $0.status == .active } }
    private var inactiveDebts: [Debt] { snapshot.debts.filter { $0.status != .active } }

    var body: some View {
        DashboardBreakdownScaffold(title: "Debts", subtitle: "Balances, due dates, reserves, payments, and payoff progress.") {
            AppCard(glow: true) {
                MetricRow(label: "Current balance", value: MoneyParser.formatPence(summary.totalCurrentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
                MetricRow(label: "Original debt", value: MoneyParser.formatPence(summary.totalOriginalAmountPence))
                MetricRow(label: "Paid", value: MoneyParser.formatPence(summary.totalPaidPence), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Progress", value: "\(Int(summary.progressPercent.rounded()))%")
                MetricRow(label: "Overdue", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
            }

            SectionTitle("Active debts")
            if activeDebts.isEmpty {
                AppCard { EmptyStateView(title: "No active debts", message: "Active balances will appear here.", systemImage: "checkmark.shield") }
            } else {
                ForEach(activeDebts) { debt in
                    debtBreakdown(debt)
                }
            }

            if !inactiveDebts.isEmpty {
                SectionTitle("Archived and paid debts")
                ForEach(inactiveDebts) { debt in
                    debtBreakdown(debt)
                }
            }

            SectionTitle("Reserves")
            if snapshot.debtReserves.isEmpty {
                AppCard { EmptyStateView(title: "No reserves", message: "Debt reserves will appear here.", systemImage: "plus.circle") }
            } else {
                AppCard {
                    ForEach(snapshot.debtReserves.sorted { $0.payday > $1.payday }) { reserve in
                        MetricRow(label: "\(reserve.payday) · \(debtName(for: reserve.debtId))", value: "\(MoneyParser.formatPence(reserve.amountPence)) · \(reserve.status.rawValue)", valueColor: AppTheme.Colors.primaryOrange)
                    }
                }
            }

            SectionTitle("Payments")
            if snapshot.debtPayments.isEmpty {
                AppCard { EmptyStateView(title: "No debt payments", message: "Recorded payments will appear here.", systemImage: "checkmark.circle") }
            } else {
                AppCard {
                    ForEach(snapshot.debtPayments.sorted { $0.date > $1.date }) { payment in
                        MetricRow(label: "\(payment.date) · \(debtName(for: payment.debtId))", value: MoneyParser.formatPence(payment.amountPence), valueColor: AppTheme.Colors.success)
                    }
                }
            }
        }
    }

    private func debtBreakdown(_ debt: Debt) -> some View {
        let reserves = snapshot.debtReserves.filter { $0.debtId == debt.id }
        let payments = snapshot.debtPayments.filter { $0.debtId == debt.id }
        let paidFromBalance = max(0, debt.originalAmountPence - debt.currentBalancePence)

        return AppCard(glow: debt.status == .active && debt.dueDate < store.todayIso) {
            Text(debt.name)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            MetricRow(label: "Lender", value: debt.lender)
            MetricRow(label: "Current balance", value: MoneyParser.formatPence(debt.currentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Original amount", value: MoneyParser.formatPence(debt.originalAmountPence))
            MetricRow(label: "Paid down", value: MoneyParser.formatPence(paidFromBalance), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Minimum payment", value: MoneyParser.formatPence(debt.minimumPaymentPence))
            MetricRow(label: "Due date", value: debt.dueDate)
            MetricRow(label: "APR", value: debt.interestRateApr.map { String(format: "%.2f%%", $0) } ?? "Not set")
            MetricRow(label: "Status", value: debt.status.rawValue.capitalized)
            MetricRow(label: "Reserved", value: MoneyParser.formatPence(reserves.reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
            MetricRow(label: "Payments", value: MoneyParser.formatPence(payments.reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.success)
        }
    }

    private func debtName(for id: String) -> String {
        snapshot.debts.first { $0.id == id }?.name ?? "Debt"
    }
}

private struct PaycheckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var paycheck: Paycheck
    @State private var payday: Date
    @State private var hoursWorked: String
    @State private var hourlyRate: String
    @State private var actualAmount: String
    @State private var showDeleteAlert = false

    init(store: PlannerStore, paycheck: Paycheck) {
        self.store = store
        self.paycheck = paycheck
        let period = store.snapshot.payPeriods.first(where: { $0.id == paycheck.payPeriodId })
        _payday = State(initialValue: period?.payday.isoDate ?? Date())
        _hoursWorked = State(initialValue: Self.formatHours(paycheck.hoursWorked))
        _hourlyRate = State(initialValue: Self.formatMoneyInput(paycheck.hourlyRatePence))
        _actualAmount = State(initialValue: paycheck.actualAmountPence.map(Self.formatMoneyInput) ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    summaryCard
                    editCard
                    SecondaryButton(title: "Delete paycheck", systemImage: "trash", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Paycheck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Delete paycheck?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deletePaycheck(id: paycheck.id)
                    dismiss()
                }
            } message: {
                Text("This removes the linked pay period and its pot allocations.")
            }
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Payday", value: currentPeriod?.payday ?? payday.isoDateString)
            MetricRow(label: "Calculated", value: MoneyParser.formatPence(currentPaycheck.calculatedAmountPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Hours", value: Self.formatHours(currentPaycheck.hoursWorked))
            MetricRow(label: "Hourly rate", value: MoneyParser.formatPence(currentPaycheck.hourlyRatePence))
            if let actualAmountPence = currentPaycheck.actualAmountPence {
                MetricRow(label: "Actual received", value: MoneyParser.formatPence(actualAmountPence), valueColor: AppTheme.Colors.primaryOrange)
            }
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit paycheck")
            DatePicker("Payday", selection: $payday, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(AppTheme.Colors.primaryOrange)
                .foregroundStyle(AppTheme.Colors.primaryText)
            TextField("Hours worked", text: $hoursWorked)
                .keyboardType(.decimalPad)
                .textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Hourly rate", text: $hourlyRate)
            MoneyField(title: "Actual received (optional)", text: $actualAmount)
            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSaveChanges) {
                store.updatePaycheck(
                    id: paycheck.id,
                    payday: payday.isoDateString,
                    hoursWorked: Double(hoursWorked) ?? 0,
                    hourlyRatePence: MoneyParser.parsePoundsToPence(hourlyRate),
                    actualAmountPence: actualAmount.isBlank ? nil : MoneyParser.parsePoundsToPence(actualAmount)
                )
            }
        }
    }

    private var currentPaycheck: Paycheck {
        store.snapshot.paychecks.first(where: { $0.id == paycheck.id }) ?? paycheck
    }

    private var currentPeriod: PayPeriod? {
        store.snapshot.payPeriods.first(where: { $0.id == currentPaycheck.payPeriodId })
    }

    private var canSaveChanges: Bool {
        let hours = Double(hoursWorked) ?? 0
        let rate = MoneyParser.parsePoundsToPence(hourlyRate)
        let actual = MoneyParser.parsePoundsToPence(actualAmount)
        return actual > 0 || (hours > 0 && rate > 0)
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }

    private static func formatHours(_ hours: Double) -> String {
        guard hours > 0 else { return "" }
        if hours.rounded() == hours {
            return String(format: "%.0f", hours)
        }
        return String(format: "%.2f", hours)
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var prefixDateLabel: String {
        String(prefix(10))
    }
}
