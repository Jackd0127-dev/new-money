import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    var onOpenCards: (() -> Void)?
    @State private var selectedPaycheck: Paycheck?

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        ScreenScaffold(
            title: "Overview",
            subtitle: "Payday pressure, pots, cards, debts, and recent activity.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
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
            fundingChecklist
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
                    Text("Money left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.warmSand)
                    Text(MoneyParser.formatPence(currentCostSummary.currentMoneyLeftPence))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(currentCostSummary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                        .minimumScaleFactor(0.62)
                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Pill(text: store.selectedPayPeriod?.payday ?? "No payday", systemImage: "calendar")
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Projected costs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Text(MoneyParser.formatPence(currentCostSummary.projectedCostsPence))
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var statsGrid: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Button {
                onOpenCards?()
            } label: {
                StatCard(title: "Cards", value: MoneyParser.formatPence(totalCardOwed), subtitle: "\(store.activeCards.count) active", systemImage: "creditcard", tone: AppTheme.Colors.orangeHighlight)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.md) {
                statLink {
                    BillsBreakdownView(store: store)
                } label: {
                    StatCard(title: "Bills", value: MoneyParser.formatPence(billsDuePence), subtitle: "Due in period", systemImage: "calendar.badge.clock", tone: AppTheme.Colors.warning)
                }
                statLink {
                    DebtsBreakdownView(store: store)
                } label: {
                    StatCard(title: "Debts", value: MoneyParser.formatPence(debtSummary.totalCurrentBalancePence), subtitle: "\(debtSummary.activeDebtCount) active", systemImage: "exclamationmark.shield", tone: debtSummary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                }
            }
        }
    }

    @ViewBuilder
    private var fundingChecklist: some View {
        let items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
        let activeItems = items.filter { $0.status != .paidCompleted }
        let paidItems = items.filter { $0.status == .paidCompleted }
        let fundedCount = items.filter(\.isCompleted).count
        let hasPendingFunding = activeItems.contains { !$0.isCompleted }

        if !items.isEmpty {
            AppCard(glow: items.contains { !$0.isCompleted }) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionTitle("Funding checklist")
                        Text(fundingChecklistProgressText(fundedCount: fundedCount, totalCount: items.count, hasPendingFunding: hasPendingFunding))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "checklist.checked")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.Colors.success.opacity(0.12))
                        .clipShape(Circle())
                }

                AppDivider()

                checklistSection(title: "Active funding", items: activeItems, isReadOnly: false)

                if !paidItems.isEmpty {
                    AppDivider()
                    checklistSection(title: "Paid / completed", items: paidItems, isReadOnly: true)
                }
            }
        }
    }

    private func fundingChecklistProgressText(fundedCount: Int, totalCount: Int, hasPendingFunding: Bool) -> String {
        let countText = "\(fundedCount)/\(totalCount) funded"
        return hasPendingFunding ? "Funding pending · \(countText)" : countText
    }

    @ViewBuilder
    private func checklistSection(title: String, items: [FundingChecklistPresentationItem], isReadOnly: Bool) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)
                .accessibilityIdentifier("dashboard-funding-section-\(title.accessibilityIdentifierSlug)")

            ForEach(items) { item in
                FundingChecklistRow(item: item, isReadOnly: isReadOnly) {
                    applyFundingChecklistAction(item)
                }
                if item.id != items.last?.id {
                    AppDivider()
                }
            }
        }
    }

    private func applyFundingChecklistAction(_ item: FundingChecklistPresentationItem) {
        guard item.status != .paidCompleted else { return }

        switch item.action {
        case .recurringBill(let paymentId, let dueDate, let payPeriodId):
            _ = store.setRecurringBillFundingCompleted(
                paymentId: paymentId,
                dueDate: dueDate,
                payPeriodId: payPeriodId,
                completed: !item.isCompleted
            )
        case .cardBill(let paymentId, let dueDate, let payPeriodId):
            _ = store.setCardBillFundingCompleted(
                paymentId: paymentId,
                dueDate: dueDate,
                payPeriodId: payPeriodId,
                completed: !item.isCompleted
            )
        case .cardSpend(let transactionId, let payPeriodId):
            _ = store.setCardSpendFundingCompleted(
                transactionId: transactionId,
                payPeriodId: payPeriodId,
                completed: !item.isCompleted
            )
        case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
            _ = store.setCardOpeningBalanceFundingCompleted(
                cardId: cardId,
                directDebitDate: directDebitDate,
                payPeriodId: payPeriodId,
                completed: !item.isCompleted
            )
        case .debt(let debtId, let dueDate, let payPeriodId):
            _ = store.setDebtFundingCompleted(
                debtId: debtId,
                dueDate: dueDate,
                payPeriodId: payPeriodId,
                completed: !item.isCompleted
            )
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
            return "Add income to create a live period."
        }
        if currentCostSummary.unfundedChecklistPence > 0 {
            return "\(MoneyParser.formatPence(currentCostSummary.unfundedChecklistPence)) still unfunded. Projected after funding: \(MoneyParser.formatPence(currentCostSummary.projectedMoneyLeftPence))."
        }
        return "Income minus committed costs until \(friendlyDate(period.endDate))."
    }

    private var currentCostSummary: PayPeriodCostSummary {
        PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: store.selectedPayPeriod, asOfDate: store.todayIso)
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
        let cardRepayments = snapshot.creditCardRepayments.map {
            DashboardActivityRow(
                id: $0.id,
                title: $0.note.isEmpty ? "Card repayment" : $0.note,
                detail: $0.date,
                amount: MoneyParser.formatPence($0.amountPence),
                symbol: "creditcard.and.123",
                color: AppTheme.Colors.success
            )
        }
        return (transactions + paychecks + allocations + cardRepayments).prefix(12).map { $0 }
    }

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
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

private extension String {
    var accessibilityIdentifierSlug: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

private struct FundingChecklistRow: View {
    var item: FundingChecklistPresentationItem
    var isReadOnly: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)
                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: AppTheme.Spacing.sm)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .opacity(isReadOnly ? 0.72 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.secondaryText
    }

    private var titleColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.primaryText
    }

    private var detailText: String {
        guard let paidDate = item.paidDate else {
            return item.detail
        }

        return "\(item.detail) · paid \(shortDate(paidDate))"
    }

    private var accessibilityLabel: String {
        if isReadOnly {
            return "Paid \(item.name)"
        }

        return "\(item.isCompleted ? "Undo" : "Fund") \(item.name)"
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct DashboardBreakdownScaffold<Content: View>: View {
    var title: String
    var subtitle: String
    var toolbarMode: AppToolbarMode = .secondarySingle
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                if !subtitle.isBlank {
                    ScreenHeader(subtitle: subtitle)
                }
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
        .appPlaceholderToolbar(toolbarMode)
    }
}

struct IncomeBreakdownView: View {
    @ObservedObject var store: PlannerStore
    @State private var isAddIncomePresented = false
    @State private var selectedPaycheck: Paycheck?
    @State private var isPaycheckInputsExpanded = true
    @State private var isPayPeriodsExpanded = false

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var costSummary: PayPeriodCostSummary {
        PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: store.selectedPayPeriod, asOfDate: store.todayIso)
    }

    var body: some View {
        DashboardBreakdownScaffold(
            title: "Income",
            subtitle: "Paycheck inputs, pay periods, and period money left.",
            toolbarMode: .add(action: { isAddIncomePresented = true })
        ) {
            AppCard(glow: true) {
                MetricRow(label: "Current plan", value: MoneyParser.formatPence(store.selectedPayPeriod?.incomePence ?? 0), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Money left", value: MoneyParser.formatPence(costSummary.currentMoneyLeftPence), valueColor: costSummary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                MetricRow(label: "Projected costs", value: MoneyParser.formatPence(costSummary.projectedCostsPence), valueColor: AppTheme.Colors.warning)
                if costSummary.unfundedChecklistPence > 0 {
                    MetricRow(label: "Unfunded checklist", value: MoneyParser.formatPence(costSummary.unfundedChecklistPence), valueColor: AppTheme.Colors.secondaryText)
                }
            }

            paycheckInputsSection
            payPeriodsSection
        }
        .sheet(isPresented: $isAddIncomePresented) {
            AddPaycheckSheetView(store: store)
        }
        .sheet(item: $selectedPaycheck) { paycheck in
            PaycheckDetailView(store: store, paycheck: paycheck)
        }
    }

    private var paycheckInputsSection: some View {
        DisclosureGroup(isExpanded: $isPaycheckInputsExpanded) {
            if snapshot.paychecks.isEmpty {
                AppCard { EmptyStateView(title: "No paycheck inputs", message: "Saved paycheck plans will appear here.", systemImage: "sterlingsign.circle") }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(snapshot.paychecks.sorted { $0.createdAt > $1.createdAt }) { paycheck in
                        let paydayLabel = period(for: paycheck).map { FinanceEngine.formatPaydayLabel($0.payday) } ?? "No linked period"
                        Button {
                            selectedPaycheck = paycheck
                        } label: {
                            PaycheckInputRow(paydayLabel: paydayLabel)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open paycheck \(paydayLabel)")
                    }
                }
            }
        } label: {
            SectionTitle("Paycheck inputs")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private var payPeriodsSection: some View {
        DisclosureGroup(isExpanded: $isPayPeriodsExpanded) {
            if snapshot.payPeriods.isEmpty {
                AppCard { EmptyStateView(title: "No pay periods", message: "Create a paycheck plan to start tracking periods.", systemImage: "calendar") }
            } else {
                ForEach(snapshot.payPeriods.sorted { $0.payday > $1.payday }) { period in
                    AppCard {
                        MetricRow(label: "Payday", value: FinanceEngine.formatPaydayLabel(period.payday))
                        MetricRow(label: "Period", value: "\(FinanceEngine.formatPaydayLabel(period.startDate)) to \(FinanceEngine.formatPaydayLabel(period.endDate))")
                        MetricRow(label: "Next payday", value: FinanceEngine.formatPaydayLabel(period.nextPayday))
                        MetricRow(label: "Income", value: MoneyParser.formatPence(period.incomePence), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Status", value: period.status.rawValue.capitalized)
                        MetricRow(label: "Allocated", value: MoneyParser.formatPence(allocations(for: period).reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
                        ForEach(allocations(for: period)) { allocation in
                            MetricRow(label: potName(for: allocation.potId), value: MoneyParser.formatPence(allocation.amountPence))
                        }
                    }
                }
            }
        } label: {
            SectionTitle("Pay periods")
        }
        .tint(AppTheme.Colors.primaryOrange)
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
}

private struct PaycheckInputRow: View {
    var paydayLabel: String

    var body: some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppTheme.Colors.success)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.Colors.success.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Payday")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(paydayLabel)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .contentShape(Rectangle())
        }
    }
}

private struct BillsBreakdownView: View {
    @ObservedObject var store: PlannerStore
    @State private var isAddBillPresented = false
    @State private var selectedBill: RecurringPayment?

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        DashboardBreakdownScaffold(
            title: "Bills",
            subtitle: "Recurring payments, card-linked bills, and period due dates.",
            toolbarMode: .add(action: { isAddBillPresented = true })
        ) {
            billsOverviewCard
            payPeriodBillsSection
            allBillsSection
        }
        .sheet(isPresented: $isAddBillPresented) {
            AddBillSheetView(store: store)
        }
        .sheet(item: $selectedBill) { bill in
            BillDetailView(store: store, payment: bill)
        }
    }

    private var billsOverviewCard: some View {
        AppCard(glow: currentPeriodBills > 0) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("This pay period")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(MoneyParser.formatPence(currentPeriodBills))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.warning)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.warning)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.Colors.warning.opacity(0.12))
                    .clipShape(Circle())
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                Pill(text: "\(activeBillCount) active", systemImage: "checkmark.circle", color: AppTheme.Colors.success)
                Pill(text: nextBillLabel, systemImage: "calendar", color: AppTheme.Colors.primaryOrange)
            }
        }
    }

    private var payPeriodBillsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("This pay period")
            if store.selectedPayPeriod == nil {
                AppCard {
                    EmptyStateView(title: "No active pay period", message: "Create a paycheck plan to see bills due this pay period.", systemImage: "calendar")
                }
            } else if currentPeriodBillOccurrences.isEmpty {
                AppCard {
                    EmptyStateView(title: "No bills this pay period", message: "Recurring payments due in the current period will appear here.", systemImage: "calendar")
                }
            } else {
                AppCard {
                    ForEach(currentPeriodBillOccurrences) { occurrence in
                        BillAgendaRow(occurrence: occurrence, snapshot: snapshot)
                        if occurrence.id != currentPeriodBillOccurrences.last?.id {
                            AppDivider()
                        }
                    }
                }
            }
        }
    }

    private var allBillsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("All bills")
            if snapshot.recurringPayments.isEmpty {
                AppCard {
                    EmptyStateView(title: "No bills yet", message: "Add recurring payments to populate this breakdown.", systemImage: "calendar.badge.plus")
                }
            } else {
                AppCard {
                    ForEach(sortedBills) { payment in
                        Button {
                            selectedBill = payment
                        } label: {
                            BillLibraryRow(payment: payment, snapshot: snapshot)
                        }
                        .buttonStyle(.plain)
                        if payment.id != sortedBills.last?.id {
                            AppDivider()
                        }
                    }
                }
            }
        }
    }

    private var currentPeriodBills: Int {
        currentPeriodBillOccurrences.reduce(0) { $0 + $1.amountPence }
    }

    private var activeBillCount: Int {
        snapshot.recurringPayments.filter(\.active).count
    }

    private var nextBillLabel: String {
        nextBillOccurrence.map { "Next \(billDateLabel($0.dueDate))" } ?? "No upcoming"
    }

    private var nextBillOccurrence: RecurringPaymentOccurrence? {
        let endDate = FinanceEngine.addIsoDays(date: store.todayIso, days: 90)
        return PlannerDerivedData.recurringOccurrences(payments: snapshot.recurringPayments, startDate: store.todayIso, endDate: endDate)
            .sorted { lhs, rhs in
                if lhs.dueDate == rhs.dueDate {
                    return lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name) == .orderedAscending
                }
                return lhs.dueDate < rhs.dueDate
            }
            .first
    }

    private var currentPeriodBillOccurrences: [RecurringPaymentOccurrence] {
        guard let period = store.selectedPayPeriod else { return [] }
        return PlannerDerivedData.recurringOccurrences(payments: snapshot.recurringPayments, startDate: period.startDate, endDate: period.endDate)
            .sorted { lhs, rhs in
                if lhs.dueDate == rhs.dueDate {
                    return lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name) == .orderedAscending
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    private var sortedBills: [RecurringPayment] {
        snapshot.recurringPayments.sorted { lhs, rhs in
            if lhs.active == rhs.active {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.active && !rhs.active
        }
    }
}

private struct BillAgendaRow: View {
    var occurrence: RecurringPaymentOccurrence
    var snapshot: PlannerSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(spacing: 2) {
                Text(billDayNumber(occurrence.dueDate))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(billMonthText(occurrence.dueDate))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(width: 46, height: 48)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.payment.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text(billLinkedTarget(for: occurrence.payment, in: snapshot))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(MoneyParser.formatPence(occurrence.amountPence))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.warning)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct BillLibraryRow: View {
    var payment: RecurringPayment
    var snapshot: PlannerSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(payment.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(payment.active ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(payment.active ? "Active" : "Inactive")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(payment.active ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
                    Text("\(payment.frequency.rawValue.capitalized) · \(billDueDayLabel(payment.dueDay))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Text(billLinkedTarget(for: payment, in: snapshot))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: AppTheme.Spacing.md)

            VStack(alignment: .trailing, spacing: 6) {
                Text(MoneyParser.formatPence(payment.amountPence))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .contentShape(Rectangle())
    }
}

private func billDateLabel(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let date = FinanceEngine.parseDate(isoDate)
    let day = calendar.component(.day, from: date)
    let month = calendar.component(.month, from: date)
    return "\(ordinalDayLabel(day)) \(shortMonthLabel(month))"
}

private func billDayNumber(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return "\(calendar.component(.day, from: FinanceEngine.parseDate(isoDate)))"
}

private func billMonthText(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return shortMonthLabel(calendar.component(.month, from: FinanceEngine.parseDate(isoDate))).uppercased()
}

private func billDueDayLabel(_ dueDay: Int?) -> String {
    guard let dueDay else { return "Not set" }
    return ordinalDayLabel(dueDay)
}

private func billLinkedTarget(for payment: RecurringPayment, in snapshot: PlannerSnapshot) -> String {
    let potName = payment.potId.flatMap { potId in snapshot.pots.first { $0.id == potId }?.name }
    let cardName = payment.creditCardId.flatMap { cardId in snapshot.creditCards.first { $0.id == cardId }?.name }
    if let cardName, let potName {
        return "\(cardName) + \(potName)"
    }
    if let potName { return potName }
    if let cardId = payment.creditCardId {
        return snapshot.creditCards.first { $0.id == cardId }?.name ?? "Linked card"
    }
    return "None"
}

private struct BillDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var payment: RecurringPayment
    @State private var name: String
    @State private var amount: String
    @State private var dueDay: String
    @State private var frequency: RecurringFrequency
    @State private var priority: RecurringPriority
    @State private var potId: String
    @State private var cardId: String
    @State private var routeToCard: Bool
    @State private var isActive: Bool
    @State private var showDeleteAlert = false

    init(store: PlannerStore, payment: RecurringPayment) {
        self.store = store
        self.payment = payment
        _name = State(initialValue: payment.name)
        _amount = State(initialValue: Self.formatMoneyInput(payment.amountPence))
        _dueDay = State(initialValue: payment.dueDay.map(String.init) ?? "")
        _frequency = State(initialValue: payment.frequency)
        _priority = State(initialValue: payment.priority)
        _potId = State(initialValue: payment.potId ?? "")
        _cardId = State(initialValue: payment.creditCardId ?? "")
        _routeToCard = State(initialValue: payment.creditCardId != nil)
        _isActive = State(initialValue: payment.active)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    summaryCard
                    editCard
                    SecondaryButton(title: "Delete bill", systemImage: "trash", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
            .onAppear {
                if potId.isEmpty {
                    potId = store.activePots.first?.id ?? ""
                }
                if cardId.isEmpty {
                    cardId = store.activeCards.first?.id ?? ""
                }
                normalizeSelectedCardPot()
            }
            .onChange(of: cardId) { _, _ in normalizeSelectedCardPot() }
            .onChange(of: routeToCard) { _, _ in normalizeSelectedCardPot() }
            .alert("Delete bill?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deleteRecurringPayment(id: payment.id)
                    dismiss()
                }
            } message: {
                Text("This removes the recurring bill from future breakdowns.")
            }
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Name", value: currentPayment.name)
            MetricRow(label: "Amount", value: MoneyParser.formatPence(currentPayment.amountPence), valueColor: AppTheme.Colors.primaryOrange)
            MetricRow(label: "Frequency", value: currentPayment.frequency.rawValue.capitalized)
            MetricRow(label: "Due day", value: billDueDayLabel(currentPayment.dueDay))
            MetricRow(label: "Linked", value: billLinkedTarget(for: currentPayment, in: store.snapshot))
            MetricRow(label: "Priority", value: currentPayment.priority.rawValue.capitalized)
            MetricRow(label: "Status", value: currentPayment.active ? "Active" : "Inactive", valueColor: currentPayment.active ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit bill")
            TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Amount", text: $amount)
            TextField("Due day", text: $dueDay).keyboardType(.numberPad).textFieldStyle(AppTextFieldStyle())
            Picker("Frequency", selection: $frequency) {
                ForEach(RecurringFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Priority", selection: $priority) {
                ForEach(RecurringPriority.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Active", isOn: $isActive)
                .tint(AppTheme.Colors.primaryOrange)
            Toggle("Linked to card", isOn: $routeToCard)
                .tint(AppTheme.Colors.primaryOrange)
            if routeToCard {
                SelectionField(title: "Card", value: selectedCardName, placeholder: "No card", systemImage: "creditcard") {
                    Button("No card") { cardId = "" }
                    ForEach(store.activeCards) { card in
                        Button(card.name) { cardId = card.id }
                    }
                }
                SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                    Button("No pot") { potId = "" }
                    if cardLinkedPots.isEmpty {
                        Text("No linked card pots")
                    } else {
                        ForEach(cardLinkedPots) { pot in
                            Button(pot.name) { potId = pot.id }
                        }
                    }
                }
            } else {
                SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                    Button("No pot") { potId = "" }
                    ForEach(store.activePots) { pot in
                        Button(pot.name) { potId = pot.id }
                    }
                }
            }
            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSave) {
                var updated = currentPayment
                updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.amountPence = MoneyParser.parsePoundsToPence(amount)
                updated.dueDay = Int(dueDay)
                updated.frequency = frequency
                updated.priority = priority
                updated.potId = cleanPotId
                updated.creditCardId = routeToCard ? cardId.nilIfBlank : nil
                updated.active = isActive
                store.updateRecurringPayment(updated)
            }
        }
    }

    private var currentPayment: RecurringPayment {
        store.snapshot.recurringPayments.first(where: { $0.id == payment.id }) ?? payment
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && MoneyParser.parsePoundsToPence(amount) > 0
    }

    private var cardLinkedPots: [Pot] {
        store.activePots.filter { $0.linkedCreditCardId == cardId }
    }

    private var selectedCardName: String {
        store.activeCards.first { $0.id == cardId }?.name ?? ""
    }

    private var selectedPotName: String {
        store.activePots.first { $0.id == potId }?.name ?? ""
    }

    private var cleanPotId: String? {
        if routeToCard {
            return cardLinkedPots.contains(where: { $0.id == potId }) ? potId.nilIfBlank : nil
        }

        return potId.nilIfBlank
    }

    private func normalizeSelectedCardPot() {
        guard routeToCard else { return }
        if !cardLinkedPots.contains(where: { $0.id == potId }) {
            potId = cardLinkedPots.first?.id ?? ""
        }
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }
}

private struct DebtsBreakdownView: View {
    @ObservedObject var store: PlannerStore
    @State private var isAddDebtPresented = false
    @State private var isRecordPaymentPresented = false
    @State private var selectedPayment: DebtPayment?
    @State private var isActiveDebtsExpanded = true
    @State private var isPaidDebtsExpanded = true
    @State private var isPaymentsExpanded = true

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var summary: DebtSummary {
        FinanceEngine.getDebtSummary(debts: snapshot.debts, payments: snapshot.debtPayments, reserves: snapshot.debtReserves, pots: snapshot.pots, today: store.todayIso)
    }
    private var activeDebts: [Debt] { snapshot.debts.filter { $0.status == .active && $0.currentBalancePence > 0 } }
    private var inactiveDebts: [Debt] { snapshot.debts.filter { $0.status != .active } }

    var body: some View {
        DashboardBreakdownScaffold(
            title: "Debts",
            subtitle: "",
            toolbarMode: .none
        ) {
            AppCard(glow: true) {
                MetricRow(label: "Current debt", value: MoneyParser.formatPence(summary.totalCurrentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
                MetricRow(label: "Overdue", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
            }

            activeDebtsSection

            paidDebtsSection

            paymentsSection
        }
        .toolbar {
            ToolbarItem(id: "debt-actions", placement: .topBarTrailing) {
                Menu {
                    Button {
                        isAddDebtPresented = true
                    } label: {
                        Label("Add Debt", systemImage: "plus.circle")
                    }
                    Button {
                        isRecordPaymentPresented = true
                    } label: {
                        Label("Record Payment", systemImage: "sterlingsign.circle")
                    }
                    .disabled(activeDebts.isEmpty)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Debt actions")
            }
        }
        .sheet(isPresented: $isAddDebtPresented) {
            AddDebtSheetView(store: store)
        }
        .sheet(isPresented: $isRecordPaymentPresented) {
            RecordDebtPaymentSheetView(store: store)
        }
        .sheet(item: $selectedPayment) { payment in
            DebtPaymentEditSheetView(store: store, payment: payment)
        }
    }

    private var activeDebtsSection: some View {
        DisclosureGroup(isExpanded: $isActiveDebtsExpanded) {
            if activeDebts.isEmpty {
                AppCard { EmptyStateView(title: "No active debts", message: "Active balances will appear here.", systemImage: "checkmark.shield") }
            } else {
                ForEach(activeDebts) { debt in
                    compactDebtCard(debt)
                }
            }
        } label: {
            SectionTitle("Active debts")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private var paidDebtsSection: some View {
        DisclosureGroup(isExpanded: $isPaidDebtsExpanded) {
            if inactiveDebts.isEmpty {
                AppCard { EmptyStateView(title: "No paid debts", message: "Paid and archived debts will appear here.", systemImage: "checkmark.circle") }
            } else {
                ForEach(inactiveDebts) { debt in
                    compactDebtCard(debt)
                }
            }
        } label: {
            SectionTitle("Paid Debts")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private var paymentsSection: some View {
        DisclosureGroup(isExpanded: $isPaymentsExpanded) {
            if snapshot.debtPayments.isEmpty {
                AppCard { EmptyStateView(title: "No debt payments", message: "Recorded payments will appear here.", systemImage: "checkmark.circle") }
            } else {
                ForEach(snapshot.debtPayments.sorted { $0.date > $1.date }) { payment in
                    Button {
                        selectedPayment = payment
                    } label: {
                        debtPaymentRow(payment)
                    }
                    .buttonStyle(.plain)
                }
            }
        } label: {
            SectionTitle("Payments")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private func compactDebtCard(_ debt: Debt) -> some View {
        NavigationLink {
            DebtDetailScreenView(store: store, debt: debt)
        } label: {
            AppCard(glow: debt.status == .active && debt.dueDate < store.todayIso) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(debt.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                        Text(debtLinkedSummary(for: debt, in: snapshot))
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: AppTheme.Spacing.md)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(MoneyParser.formatPence(debt.currentBalancePence))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.orangeHighlight)
                            .lineLimit(1)
                        Text("Due \(debtDateLabel(debt.dueDate, relativeTo: store.todayIso))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(debt.name)")
    }

    private func debtPaymentRow(_ payment: DebtPayment) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.success)
                VStack(alignment: .leading, spacing: 4) {
                    Text(debtName(for: payment.debtId))
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(payment.date) · \(payment.note.isBlank ? "Payment" : payment.note)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Text("-\(MoneyParser.formatPence(payment.amountPence))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.success)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }

    private func debtName(for id: String) -> String {
        snapshot.debts.first { $0.id == id }?.name ?? "Debt"
    }

    private func debtLinkedSummary(for debt: Debt, in snapshot: PlannerSnapshot) -> String {
        if let potName = linkedDebtPotName(in: snapshot, debtId: debt.id) {
            return "\(debt.lender) · \(potName)"
        }
        return debt.lender
    }
}

private struct RecordDebtPaymentSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var debtId: String
    @State private var amount = ""
    @State private var paymentDate = Date()
    @State private var note = ""

    init(store: PlannerStore) {
        self.store = store
        _debtId = State(initialValue: store.snapshot.debts.first { $0.status == .active && $0.currentBalancePence > 0 }?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    formCard
                    if let debt = selectedPaymentDebt {
                        AppCard {
                            MetricRow(label: "Current debt", value: MoneyParser.formatPence(debt.currentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
                            MetricRow(label: "Payment", value: "-\(MoneyParser.formatPence(parsedAmountPence))", valueColor: AppTheme.Colors.success)
                            MetricRow(label: "Balance after payment", value: MoneyParser.formatPence(max(0, debt.currentBalancePence - parsedAmountPence)), valueColor: AppTheme.Colors.primaryOrange)
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Record payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var formCard: some View {
        AppCard(glow: true) {
            SectionTitle("Record payment")
            Picker("Debt", selection: $debtId) {
                if selectableDebts.isEmpty {
                    Text("No active debts").tag("")
                } else {
                    ForEach(selectableDebts) { debt in
                        Text("\(debt.name) · \(MoneyParser.formatPence(debt.currentBalancePence))").tag(debt.id)
                    }
                }
            }
            .pickerStyle(.menu)
            MoneyField(title: "Payment amount", text: $amount)
            DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Record payment", systemImage: "checkmark.circle", isDisabled: !canSave) {
                store.recordDebtPayment(
                    debtId: debtId,
                    amountPence: parsedAmountPence,
                    date: paymentDate.isoDateString,
                    note: note
                )
                dismiss()
            }
        }
    }

    private var selectableDebts: [Debt] {
        store.snapshot.debts.filter { $0.status == .active && $0.currentBalancePence > 0 }
    }

    private var selectedPaymentDebt: Debt? {
        selectableDebts.first { $0.id == debtId }
    }

    private var parsedAmountPence: Int {
        MoneyParser.parsePoundsToPence(amount)
    }

    private var canSave: Bool {
        !debtId.isEmpty && parsedAmountPence > 0
    }
}

private struct DebtDetailScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var debt: Debt
    @State private var name: String
    @State private var lender: String
    @State private var balance: String
    @State private var minimum: String
    @State private var dueDate: Date
    @State private var apr: String
    @State private var note: String
    @State private var status: DebtStatus
    @State private var linkedPotId: String
    @State private var showDeleteAlert = false

    init(store: PlannerStore, debt: Debt) {
        self.store = store
        self.debt = debt
        _name = State(initialValue: debt.name)
        _lender = State(initialValue: debt.lender)
        _balance = State(initialValue: Self.formatMoneyInput(debt.currentBalancePence))
        _minimum = State(initialValue: Self.formatMoneyInput(debt.minimumPaymentPence))
        _dueDate = State(initialValue: debt.dueDate.isoDate)
        _apr = State(initialValue: debt.interestRateApr.map { String(format: "%.2f", $0) } ?? "")
        _note = State(initialValue: debt.note)
        _status = State(initialValue: debt.status)
        _linkedPotId = State(initialValue: linkedDebtPot(in: store.snapshot, debtId: debt.id)?.id ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                summaryCard
                editCard
                SecondaryButton(title: "Delete debt", systemImage: "trash", role: .destructive) {
                    showDeleteAlert = true
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle(currentDebt.name.isBlank ? "Debt" : currentDebt.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .appPlaceholderToolbar(.secondarySingle)
        .alert("Delete debt?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteDebt(id: debt.id)
                dismiss()
            }
        } message: {
            Text("This removes the debt and its payment history.")
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Name", value: currentDebt.name)
            MetricRow(label: "Lender", value: currentDebt.lender)
            MetricRow(label: "Current debt", value: MoneyParser.formatPence(currentDebt.currentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Minimum payment", value: MoneyParser.formatPence(currentDebt.minimumPaymentPence))
            MetricRow(label: "Due date", value: debtDateLabel(currentDebt.dueDate, relativeTo: store.todayIso))
            MetricRow(label: "APR", value: currentDebt.interestRateApr.map { String(format: "%.2f%%", $0) } ?? "Not set")
            MetricRow(label: "Payments", value: MoneyParser.formatPence(paymentsTotalPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Linked pot", value: linkedDebtPotName(in: store.snapshot, debtId: currentDebt.id) ?? "None")
            MetricRow(label: "Status", value: currentDebt.status.rawValue.capitalized, valueColor: currentDebt.status == .active ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
            MetricRow(label: "Note", value: currentDebt.note.isBlank ? "No note" : currentDebt.note)
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit debt")
            TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
            TextField("Lender", text: $lender).textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Current debt", text: $balance)
            MoneyField(title: "Minimum payment", text: $minimum)
            DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            Picker("Linked pot", selection: $linkedPotId) {
                Text("No linked pot").tag("")
                ForEach(eligibleDebtPots(in: store.snapshot, debtId: currentDebt.id)) { pot in
                    Text(pot.name).tag(pot.id)
                }
            }
            .pickerStyle(.menu)
            TextField("APR", text: $apr).keyboardType(.decimalPad).textFieldStyle(AppTextFieldStyle())
            Picker("Status", selection: $status) {
                ForEach(DebtStatus.allCases, id: \.self) { status in
                    Text(status.rawValue.capitalized).tag(status)
                }
            }
            .pickerStyle(.segmented)
            TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSave) {
                var updated = currentDebt
                let currentBalancePence = MoneyParser.parsePoundsToPence(balance)
                updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.lender = lender.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.currentBalancePence = currentBalancePence
                updated.minimumPaymentPence = MoneyParser.parsePoundsToPence(minimum)
                updated.dueDate = dueDate.isoDateString
                updated.interestRateApr = Double(apr)
                updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.status = currentBalancePence > 0 ? status : .paid
                store.updateDebt(updated)
                _ = store.setDebtLinkedPot(debtId: updated.id, potId: linkedPotId.nilIfBlank)
            }
        }
    }

    private var currentDebt: Debt {
        store.snapshot.debts.first(where: { $0.id == debt.id }) ?? debt
    }

    private var paymentsTotalPence: Int {
        store.snapshot.debtPayments
            .filter { $0.debtId == currentDebt.id }
            .reduce(0) { $0 + $1.amountPence }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }
}

private struct DebtPaymentEditSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var payment: DebtPayment
    @State private var debtId: String
    @State private var amount: String
    @State private var paymentDate: Date
    @State private var note: String
    @State private var showDeleteAlert = false

    init(store: PlannerStore, payment: DebtPayment) {
        self.store = store
        self.payment = payment
        _debtId = State(initialValue: payment.debtId)
        _amount = State(initialValue: Self.formatMoneyInput(payment.amountPence))
        _paymentDate = State(initialValue: payment.date.isoDate)
        _note = State(initialValue: payment.note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    summaryCard
                    editCard
                    SecondaryButton(title: "Delete payment", systemImage: "trash", role: .destructive) {
                        showDeleteAlert = true
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Debt payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
            .alert("Delete payment?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    store.deleteDebtPayment(id: payment.id)
                    dismiss()
                }
            } message: {
                Text("This restores the payment amount to the linked debt balance.")
            }
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Debt", value: debtName(for: currentPayment.debtId))
            MetricRow(label: "Amount", value: MoneyParser.formatPence(currentPayment.amountPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Date", value: currentPayment.date)
            MetricRow(label: "Note", value: currentPayment.note.isBlank ? "Payment" : currentPayment.note)
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit payment")
            Picker("Debt", selection: $debtId) {
                ForEach(selectableDebts) { debt in
                    Text("\(debt.name) · \(MoneyParser.formatPence(debt.currentBalancePence))").tag(debt.id)
                }
            }
            .pickerStyle(.menu)
            MoneyField(title: "Payment amount", text: $amount)
            DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSave) {
                store.updateDebtPayment(
                    id: payment.id,
                    debtId: debtId,
                    amountPence: MoneyParser.parsePoundsToPence(amount),
                    date: paymentDate.isoDateString,
                    note: note
                )
            }
        }
    }

    private var currentPayment: DebtPayment {
        store.snapshot.debtPayments.first(where: { $0.id == payment.id }) ?? payment
    }

    private var selectableDebts: [Debt] {
        var debts = store.snapshot.debts.filter { $0.status == .active && $0.currentBalancePence > 0 }
        if let linkedDebt = store.snapshot.debts.first(where: { $0.id == currentPayment.debtId }),
           !debts.contains(where: { $0.id == linkedDebt.id }) {
            debts.insert(linkedDebt, at: 0)
        }
        return debts
    }

    private var canSave: Bool {
        !debtId.isEmpty && MoneyParser.parsePoundsToPence(amount) > 0
    }

    private func debtName(for id: String) -> String {
        store.snapshot.debts.first { $0.id == id }?.name ?? "Deleted debt"
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }
}

private func debtDateLabel(_ isoDate: String, relativeTo todayIso: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let date = FinanceEngine.parseDate(isoDate)
    let today = FinanceEngine.parseDate(todayIso)
    let day = calendar.component(.day, from: date)
    let month = calendar.component(.month, from: date)
    let year = calendar.component(.year, from: date)
    let currentYear = calendar.component(.year, from: today)
    let monthLabel = shortMonthLabel(month)
    let baseLabel = "\(ordinalDayLabel(day)) \(monthLabel)"

    guard year != currentYear else { return baseLabel }
    return "\(baseLabel) \(String(format: "%02d", year % 100))"
}

private func eligibleDebtPots(in snapshot: PlannerSnapshot, debtId: String?) -> [Pot] {
    snapshot.pots
        .filter {
            !$0.archived &&
            $0.linkedCreditCardId == nil &&
            ($0.linkedDebtId == nil || $0.linkedDebtId == debtId)
        }
        .sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.id < rhs.id
            }
            return lhs.name < rhs.name
        }
}

private func linkedDebtPot(in snapshot: PlannerSnapshot, debtId: String) -> Pot? {
    eligibleDebtPots(in: snapshot, debtId: debtId)
        .first { $0.linkedDebtId == debtId }
}

private func linkedDebtPotName(in snapshot: PlannerSnapshot, debtId: String) -> String? {
    linkedDebtPot(in: snapshot, debtId: debtId)?.name
}

private func ordinalDayLabel(_ day: Int) -> String {
    let suffix: String
    switch day {
    case 11, 12, 13:
        suffix = "th"
    default:
        switch day % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(day)\(suffix)"
}

private func shortMonthLabel(_ month: Int) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    guard months.indices.contains(month - 1) else { return "Jan" }
    return months[month - 1]
}

private struct PaycheckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var paycheck: Paycheck
    @State private var payday: Date
    @State private var hoursWorked: String
    @State private var hourlyRate: String
    @State private var payFrequency: PayFrequency
    @State private var showDeleteAlert = false

    init(store: PlannerStore, paycheck: Paycheck) {
        self.store = store
        self.paycheck = paycheck
        let period = store.snapshot.payPeriods.first(where: { $0.id == paycheck.payPeriodId })
        _payday = State(initialValue: period?.payday.isoDate ?? Date())
        _hoursWorked = State(initialValue: Self.formatHours(paycheck.hoursWorked))
        _hourlyRate = State(initialValue: Self.formatMoneyInput(paycheck.hourlyRatePence))
        _payFrequency = State(initialValue: period?.payFrequency ?? store.snapshot.settings.payFrequency)
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
            .appPlaceholderToolbar(.modalSingle)
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
            MetricRow(label: "Payday", value: currentPeriod.map { FinanceEngine.formatPaydayLabel($0.payday) } ?? FinanceEngine.formatPaydayLabel(payday.isoDateString))
            MetricRow(label: "Paid in", value: MoneyParser.formatPence(currentPaycheck.calculatedAmountPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Hours", value: hoursLabel(currentPaycheck.hoursWorked))
            MetricRow(label: "Hourly rate", value: MoneyParser.formatPence(currentPaycheck.hourlyRatePence))
            MetricRow(label: "Pay period", value: periodRangeLabel)
            MetricRow(label: "Frequency", value: frequencyLabel(currentPeriod?.payFrequency ?? payFrequency))
            MetricRow(label: "Allocated", value: MoneyParser.formatPence(allocatedPence), valueColor: AppTheme.Colors.primaryOrange)
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit paycheck")
            DatePicker("Payday", selection: $payday, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(AppTheme.Colors.primaryOrange)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Picker("Frequency", selection: $payFrequency) {
                ForEach(PayFrequency.allCases) { frequency in
                    Text(frequencyLabel(frequency)).tag(frequency)
                }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.primaryOrange)
            TextField("Hours worked", text: $hoursWorked)
                .keyboardType(.decimalPad)
                .textFieldStyle(AppTextFieldStyle())
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                MoneyField(title: "Hourly rate", text: $hourlyRate)
                    .layoutPriority(1)
                paidInPreview
                    .frame(width: 132)
            }
            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSaveChanges) {
                store.updatePaycheck(
                    id: paycheck.id,
                    payday: payday.isoDateString,
                    hoursWorked: Double(hoursWorked) ?? 0,
                    hourlyRatePence: MoneyParser.parsePoundsToPence(hourlyRate),
                    actualAmountPence: nil,
                    payFrequency: payFrequency
                )
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

    private var currentPaycheck: Paycheck {
        store.snapshot.paychecks.first(where: { $0.id == paycheck.id }) ?? paycheck
    }

    private var currentPeriod: PayPeriod? {
        store.snapshot.payPeriods.first(where: { $0.id == currentPaycheck.payPeriodId })
    }

    private var periodRangeLabel: String {
        guard let currentPeriod else { return "No linked period" }
        return "\(FinanceEngine.formatPaydayLabel(currentPeriod.startDate)) to \(FinanceEngine.formatPaydayLabel(currentPeriod.endDate))"
    }

    private var allocatedPence: Int {
        store.snapshot.potAllocations
            .filter { $0.payPeriodId == currentPaycheck.payPeriodId }
            .reduce(0) { $0 + $1.amountPence }
    }

    private var calculatedPayPence: Int {
        FinanceEngine.calculatePaycheckAmount(
            hoursWorked: Double(hoursWorked) ?? 0,
            hourlyRatePence: MoneyParser.parsePoundsToPence(hourlyRate),
            actualAmountPence: nil
        )
    }

    private var canSaveChanges: Bool {
        let hours = Double(hoursWorked) ?? 0
        let rate = MoneyParser.parsePoundsToPence(hourlyRate)
        return hours > 0 && rate > 0
    }

    private func hoursLabel(_ hours: Double) -> String {
        let formatted = Self.formatHours(hours)
        return formatted.isBlank ? "Not set" : formatted
    }

    private func frequencyLabel(_ frequency: PayFrequency) -> String {
        frequency.rawValue.capitalized
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

    var nilIfBlank: String? {
        isBlank ? nil : self
    }

    var prefixDateLabel: String {
        String(prefix(10))
    }
}
