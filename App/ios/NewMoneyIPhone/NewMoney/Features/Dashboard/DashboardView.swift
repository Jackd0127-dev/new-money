import SwiftUI

enum DashboardHomeSection: String, Equatable {
    case hero
    case accounts
    case paydayPlanning
    case spendingSnapshot
    case monthlySpendChart
    case upcomingBeforePayday
    case alerts
    case fundingChecklist
    case recentActivity
}

enum DashboardDetailPresentation: Equatable {
    case navigationPush
}

struct DashboardHomeLayoutPolicy {
    static let homeSections: [DashboardHomeSection] = [
        .hero,
        .accounts,
        .monthlySpendChart,
        .upcomingBeforePayday,
        .alerts,
        .fundingChecklist
    ]

    static let moneyLeftDetailSections: [DashboardHomeSection] = [
        .hero,
        .spendingSnapshot
    ]

    static let moneyLeftDetailPresentation: DashboardDetailPresentation = .navigationPush
}

private enum DashboardSheetDestination: Identifiable {
    case paycheck(Paycheck)

    var id: String {
        switch self {
        case .paycheck(let paycheck):
            "paycheck-\(paycheck.id)"
        }
    }
}

private struct DashboardTabPresentation {
    var selectedPayPeriod: PayPeriod?
    var currentCostSummary: PayPeriodCostSummary
    var fundingChecklistItems: [FundingChecklistPresentationItem]
    var manualMonthlySpendData: DashboardMonthlySpendChartData
    var outgoingsMonthlySpendData: DashboardMonthlySpendChartData
    var alertRows: [HomeAlertRow]
    var upcomingMoneyEvents: [CalendarEvent]
    var recentRows: [DashboardActivityRow]
}

struct DashboardView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    var rootTabResetRevision: Int?
    var presentationCache: PlannerTabPresentationCache?
    var presentationContext: PlannerTabPresentationContext?
    var onOpenAccount: (() -> Void)?
    var onViewPlan: (() -> Void)?
    var onViewActivity: (() -> Void)?
    @State private var activeDashboardSheet: DashboardSheetDestination?

    private var snapshot: PlannerSnapshot { store.snapshot }

    var body: some View {
        ScreenScaffold(
            title: "Home",
            subtitle: "Money left and upcoming pressure.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode,
            rootTabResetRevision: rootTabResetRevision
        ) {
            if store.isLoading {
                LoadingView()
            }

            if let message = store.errorMessage {
                ErrorBanner(message: message) {
                    store.errorMessage = nil
                }
            }

            ForEach(DashboardHomeLayoutPolicy.homeSections, id: \.rawValue) { section in
                homeSection(section)
            }
        }
        .sheet(item: $activeDashboardSheet) { sheet in
            switch sheet {
            case .paycheck(let paycheck):
                PaycheckDetailView(store: store, paycheck: paycheck)
            }
        }
    }

    @ViewBuilder
    private func homeSection(_ section: DashboardHomeSection) -> some View {
        switch section {
        case .hero:
            heroCard
        case .accounts:
            accountButton
        case .monthlySpendChart:
            monthlySpendChart
        case .upcomingBeforePayday:
            upcomingBeforePayday
        case .alerts:
            homeAlerts
        case .fundingChecklist:
            fundingChecklist
        case .recentActivity:
            recentActivity
        case .paydayPlanning, .spendingSnapshot:
            EmptyView()
        }
    }

    private var accountButton: some View {
        HStack {
            Button {
                onOpenAccount?()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "person.2.fill")
                        .font(.caption.weight(.bold))
                    Text("Accounts")
                        .font(.caption.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .foregroundStyle(AppTheme.Colors.primaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(AppTheme.Gradients.softAccentSurface)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.primaryOrange.opacity(0.24), lineWidth: 1)
                )
                .shadow(color: AppTheme.Colors.glowOrange.opacity(0.24), radius: 10, y: 5)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(onOpenAccount == nil)
            .accessibilityLabel("Open Accounts")

            Spacer()
        }
    }

    private var heroCard: some View {
        NavigationLink {
            DashboardMoneyLeftDetailView(store: store)
        } label: {
            AppCard(glow: true) {
                DashboardMoneyLeftHeroContent(
                    summary: currentCostSummary,
                    subtitle: heroSubtitle,
                    paydayLabel: paydayLabel,
                    safeToSpendTodayPence: safeToSpendTodayPence,
                    showsDetailAffordance: true
                )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Open money left details")
        .accessibilityHint("Shows spending snapshot and money left details.")
    }

    private var paydayLabel: String {
        guard let period = tabPresentation.selectedPayPeriod else {
            return "No payday"
        }
        return FinanceEngine.formatPaydayLabel(period.payday)
    }

    private var safeToSpendTodayPence: Int? {
        guard let period = tabPresentation.selectedPayPeriod else {
            return nil
        }
        return FinanceEngine.getDailySafeToSpendPence(
            spendablePence: currentCostSummary.projectedMoneyLeftPence,
            today: store.todayIso,
            endDate: period.endDate
        )
    }

    @ViewBuilder
    private var fundingChecklist: some View {
        let items = tabPresentation.fundingChecklistItems
        let activeItems = items.filter { $0.status != .paidCompleted }
        let paidItems = items.filter { $0.status == .paidCompleted }
        let fundedCount = items.filter(\.isCompleted).count
        let hasPendingFunding = activeItems.contains { !$0.isCompleted && !$0.isExcluded }

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
                } excludeAction: {
                    applyFundingChecklistExclusion(item)
                }
                if item.id != items.last?.id {
                    AppDivider()
                }
            }
        }
    }

    private func applyFundingChecklistAction(_ item: FundingChecklistPresentationItem) {
        guard item.status != .paidCompleted else { return }

        _ = store.setFundingChecklistCompleted(action: item.action, completed: item.isExcluded || !item.isCompleted)
    }

    private func applyFundingChecklistExclusion(_ item: FundingChecklistPresentationItem) {
        guard item.status != .paidCompleted else { return }
        _ = store.setFundingChecklistExcluded(action: item.action, excluded: !item.isExcluded)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Recent activity")
            if recentRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "No activity yet", message: "Payday plans, pot allocations, and spend records will appear here.", systemImage: "clock")
                }
            } else {
                let visibleRows = Array(recentRows.prefix(5))
                AppCard {
                    ForEach(visibleRows, id: \.id) { row in
                        if let paycheckId = row.paycheckId {
                            Button {
                                if let paycheck = snapshot.paychecks.first(where: { $0.id == paycheckId }) {
                                    activeDashboardSheet = .paycheck(paycheck)
                                }
                            } label: {
                                DashboardActivityRowView(row: row, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            DashboardActivityRowView(row: row)
                        }

                        if row.id != visibleRows.last?.id {
                            AppDivider()
                        }
                    }

                    AppDivider()
                    feedFooterButton("See all", action: onViewActivity)
                }
            }
        }
    }

    @ViewBuilder
    private var homeAlerts: some View {
        let alerts = alertRows
        if !alerts.isEmpty {
            AppCard(glow: true) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    SectionTitle("Alerts")
                    ForEach(alerts) { alert in
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: alert.symbol)
                                .foregroundStyle(alert.color)
                                .frame(width: 32, height: 32)
                                .background(alert.color.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(alert.message)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upcomingBeforePayday: some View {
        if tabPresentation.selectedPayPeriod != nil {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Before payday")
                AppCard {
                    if upcomingMoneyEvents.isEmpty {
                        EmptyStateView(
                            title: "No planned events before payday",
                            message: "Bills, debts, card payments, and paydays will appear here.",
                            systemImage: "calendar.badge.clock"
                        )
                    } else {
                        let visibleEvents = Array(upcomingMoneyEvents.prefix(5))
                        ForEach(visibleEvents) { event in
                            DashboardMoneyEventRowView(
                                title: event.title,
                                subtitle: "\(friendlyDate(event.date)) · \(homeEventTypeLabel(event.type))",
                                amount: homeEventAmountText(event),
                                symbol: homeEventSymbol(event.type),
                                color: homeEventColor(event.type)
                            )

                            if event.id != visibleEvents.last?.id {
                                AppDivider()
                            }
                        }

                        AppDivider()
                        feedFooterButton("See all", action: onViewPlan)
                    }
                }
            }
        }
    }

    private var monthlySpendChart: some View {
        DashboardMonthlySpendChartView(
            manualData: tabPresentation.manualMonthlySpendData,
            outgoingsData: tabPresentation.outgoingsMonthlySpendData
        )
    }

    private var heroSubtitle: String {
        guard let period = tabPresentation.selectedPayPeriod else {
            return "Add income to create a live period."
        }
        if currentCostSummary.unfundedChecklistPence > 0 {
            return "\(MoneyParser.formatPence(currentCostSummary.unfundedChecklistPence)) still unfunded. Projected after funding: \(MoneyParser.formatPence(currentCostSummary.projectedMoneyLeftPence))."
        }
        return "Income minus committed costs until \(friendlyDate(period.endDate))."
    }

    private var currentCostSummary: PayPeriodCostSummary {
        tabPresentation.currentCostSummary
    }

    private var alertRows: [HomeAlertRow] {
        tabPresentation.alertRows
    }

    private var upcomingMoneyEvents: [CalendarEvent] {
        tabPresentation.upcomingMoneyEvents
    }

    @ViewBuilder
    private func feedFooterButton(_ title: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(title)
    }

    private var recentRows: [DashboardActivityRow] {
        tabPresentation.recentRows
    }

    private var tabPresentation: DashboardTabPresentation {
        let context = presentationContext ?? PlannerTabPresentationContext(
            snapshot: store.snapshot,
            activePlannerAccountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriod: store.selectedPayPeriod
        )

        guard let presentationCache else {
            return Self.makePresentation(context: context)
        }

        return presentationCache.value(for: context.key(for: .home)) {
            Self.makePresentation(context: context)
        }
    }

    static func warmPresentation(cache: PlannerTabPresentationCache, context: PlannerTabPresentationContext) {
        _ = cache.value(for: context.key(for: .home)) {
            makePresentation(context: context)
        } as DashboardTabPresentation
    }

    private static func makePresentation(context: PlannerTabPresentationContext) -> DashboardTabPresentation {
        let snapshot = context.snapshot
        let payPeriod = context.selectedPayPeriod
        let todayIso = context.todayIso
        let costSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: todayIso
        )
        let checklistItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: todayIso
        )
        let debtSummary = FinanceEngine.getDebtSummary(
            debts: snapshot.debts,
            payments: snapshot.debtPayments,
            reserves: snapshot.debtReserves,
            pots: snapshot.pots,
            today: todayIso
        )
        let overdueStatements = PlannerDerivedData.creditCardStatementSummaries(
            snapshot: snapshot,
            asOfDate: todayIso
        )
        .filter { $0.status == .overdue }

        var alerts: [HomeAlertRow] = []
        if costSummary.currentMoneyLeftPence < 0 {
            alerts.append(
                HomeAlertRow(
                    title: "Money left is negative",
                    message: "\(MoneyParser.formatPence(abs(costSummary.currentMoneyLeftPence))) over the current position.",
                    symbol: "exclamationmark.triangle",
                    color: AppTheme.Colors.danger
                )
            )
        }
        if costSummary.unfundedChecklistPence > 0 {
            alerts.append(
                HomeAlertRow(
                    title: "Funding still pending",
                    message: "\(MoneyParser.formatPence(costSummary.unfundedChecklistPence)) is not marked as funded yet.",
                    symbol: "checklist.unchecked",
                    color: AppTheme.Colors.warning
                )
            )
        }
        if debtSummary.overdueDebtCount > 0 {
            alerts.append(
                HomeAlertRow(
                    title: "Debt payment overdue",
                    message: "\(debtSummary.overdueDebtCount) debt item\(debtSummary.overdueDebtCount == 1 ? "" : "s") need attention.",
                    symbol: "exclamationmark.shield",
                    color: AppTheme.Colors.danger
                )
            )
        }
        if !overdueStatements.isEmpty {
            alerts.append(
                HomeAlertRow(
                    title: "Statement payment overdue",
                    message: "\(overdueStatements.count) card statement\(overdueStatements.count == 1 ? "" : "s") are overdue.",
                    symbol: "creditcard.trianglebadge.exclamationmark",
                    color: AppTheme.Colors.danger
                )
            )
        }

        let fallbackEndDate = FinanceEngine.addIsoDays(date: todayIso, days: 14)
        let eventEndDate = payPeriod?.payday ?? fallbackEndDate
        let upcomingEvents = PlannerDerivedData.calendarEvents(
            snapshot: snapshot,
            startDate: todayIso,
            endDate: eventEndDate
        )
        .filter { $0.date >= todayIso && $0.type != .spending }
        .sorted { $0.date < $1.date }

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        let transactionRows = snapshot.transactions.map {
            DashboardActivityRow(
                id: $0.id,
                title: $0.note.isEmpty ? "Spending" : $0.note,
                detail: dashboardFriendlyDate($0.date),
                amount: "-\(MoneyParser.formatPence($0.amountPence))",
                symbol: $0.paymentMethod == .creditCard ? "creditcard" : "cart",
                color: AppTheme.Colors.orangeHighlight
            )
        }
        let paycheckRows = snapshot.paychecks.map {
            DashboardActivityRow(
                id: $0.id,
                title: "Paycheck",
                detail: $0.createdAt.prefixDateLabel,
                amount: "+\(MoneyParser.formatPence($0.calculatedAmountPence))",
                symbol: "sterlingsign.circle",
                color: AppTheme.Colors.success,
                paycheckId: $0.id
            )
        }
        let allocationRows = snapshot.potAllocations.map { allocation in
            DashboardActivityRow(
                id: allocation.id,
                title: potsById[allocation.potId]?.name ?? "Pot allocation",
                detail: allocation.createdAt.prefixDateLabel,
                amount: "-\(MoneyParser.formatPence(allocation.amountPence))",
                symbol: "wallet.pass",
                color: AppTheme.Colors.primaryOrange
            )
        }
        let repaymentRows = snapshot.creditCardRepayments.map {
            DashboardActivityRow(
                id: $0.id,
                title: $0.note.isEmpty ? "Card repayment" : $0.note,
                detail: dashboardFriendlyDate($0.date),
                amount: "-\(MoneyParser.formatPence($0.amountPence))",
                symbol: "creditcard.and.123",
                color: AppTheme.Colors.warning
            )
        }

        return DashboardTabPresentation(
            selectedPayPeriod: payPeriod,
            currentCostSummary: costSummary,
            fundingChecklistItems: checklistItems,
            manualMonthlySpendData: DashboardMonthlySpendChartData.make(
                transactions: snapshot.transactions,
                todayIso: todayIso
            ),
            outgoingsMonthlySpendData: DashboardMonthlySpendChartData.makeAllOutgoings(
                snapshot: snapshot,
                todayIso: todayIso
            ),
            alertRows: alerts,
            upcomingMoneyEvents: upcomingEvents,
            recentRows: Array((transactionRows + paycheckRows + allocationRows + repaymentRows).prefix(12))
        )
    }

    private static func dashboardFriendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func homeEventAmountText(_ event: CalendarEvent) -> String? {
        guard let amountPence = event.amountPence else { return nil }
        let formattedAmount = MoneyParser.formatPence(amountPence)
        return event.type == .payday ? "+\(formattedAmount)" : "-\(formattedAmount)"
    }

    private func homeEventTypeLabel(_ type: CalendarEventType) -> String {
        switch type {
        case .payday: "Money in"
        case .recurring: "Bill"
        case .savedPayment: "Saved payment"
        case .spending: "Spend"
        case .cardPayment: "Card payment"
        case .debtDue: "Debt due"
        case .debtReserve: "Debt reserve"
        case .debtPayment: "Debt paid"
        case .allocation: "Pot allocation"
        }
    }

    private func homeEventSymbol(_ type: CalendarEventType) -> String {
        switch type {
        case .payday: "arrow.down.circle"
        case .recurring: "calendar.badge.clock"
        case .savedPayment: "calendar.badge.plus"
        case .spending: "receipt"
        case .cardPayment: "creditcard"
        case .debtDue: "exclamationmark.shield"
        case .debtReserve: "plus.circle"
        case .debtPayment: "checkmark.circle"
        case .allocation: "wallet.pass"
        }
    }

    private func homeEventColor(_ type: CalendarEventType) -> Color {
        switch type {
        case .payday:
            AppTheme.Colors.success
        case .recurring, .savedPayment, .debtDue:
            AppTheme.Colors.warning
        case .spending, .cardPayment:
            AppTheme.Colors.orangeHighlight
        case .debtReserve, .debtPayment, .allocation:
            AppTheme.Colors.primaryOrange
        }
    }

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct HomeAlertRow: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var symbol: String
    var color: Color
}

private struct DashboardMoneyLeftDetailView: View {
    @ObservedObject var store: PlannerStore

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var currentCostSummary: PayPeriodCostSummary {
        PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: store.selectedPayPeriod, asOfDate: store.todayIso)
    }

    var body: some View {
        ScreenScaffold(
            title: "Money left",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            ForEach(DashboardHomeLayoutPolicy.moneyLeftDetailSections, id: \.rawValue) { section in
                detailSection(section)
            }
        }
    }

    @ViewBuilder
    private func detailSection(_ section: DashboardHomeSection) -> some View {
        switch section {
        case .hero:
            AppCard(glow: true) {
                DashboardMoneyLeftHeroContent(
                    summary: currentCostSummary,
                    subtitle: heroSubtitle,
                    paydayLabel: paydayLabel,
                    safeToSpendTodayPence: safeToSpendTodayPence,
                    showsDetailAffordance: false
                )
            }
        case .spendingSnapshot:
            DashboardSpendingSnapshotCard(
                summary: currentCostSummary,
                periodLabel: spendingPeriodLabel,
                entryCount: selectedPeriodTransactions.count
            )
        case .accounts, .paydayPlanning, .monthlySpendChart, .upcomingBeforePayday, .alerts, .fundingChecklist, .recentActivity:
            EmptyView()
        }
    }

    private var paydayLabel: String {
        guard let period = store.selectedPayPeriod else {
            return "No payday"
        }
        return FinanceEngine.formatPaydayLabel(period.payday)
    }

    private var safeToSpendTodayPence: Int? {
        guard let period = store.selectedPayPeriod else {
            return nil
        }
        return FinanceEngine.getDailySafeToSpendPence(
            spendablePence: currentCostSummary.projectedMoneyLeftPence,
            today: store.todayIso,
            endDate: period.endDate
        )
    }

    private var selectedPeriodTransactions: [Transaction] {
        guard let period = store.selectedPayPeriod else { return [] }
        return snapshot.transactions.filter {
            $0.type == .spending &&
            ($0.payPeriodId == period.id || ($0.date >= period.startDate && $0.date <= period.endDate))
        }
    }

    private var spendingPeriodLabel: String {
        guard let period = store.selectedPayPeriod else {
            return "No current pay period yet"
        }
        return "\(friendlyDate(period.startDate)) to \(friendlyDate(period.endDate))"
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

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct DashboardMoneyLeftHeroContent: View {
    var summary: PayPeriodCostSummary
    var subtitle: String
    var paydayLabel: String
    var safeToSpendTodayPence: Int?
    var showsDetailAffordance: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Money left")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.cardEyebrow)
                    Text(MoneyParser.formatPence(summary.currentMoneyLeftPence))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(summary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                        .minimumScaleFactor(0.62)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if showsDetailAffordance {
                        HStack(spacing: 5) {
                            Text("Details")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.primaryOrange.opacity(0.13))
                        .clipShape(Capsule())
                    }

                    Pill(text: paydayLabel, systemImage: "calendar")
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Planned costs")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        Text(MoneyParser.formatPence(summary.projectedCostsPence))
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }
                }
            }

            if let safeToSpendTodayPence {
                AppDivider()
                MetricRow(
                    label: "Safe to spend today",
                    value: safeToSpendTodayPence == 0
                        ? "No spending remaining"
                        : MoneyParser.formatPence(safeToSpendTodayPence),
                    valueColor: safeToSpendTodayPence == 0 ? AppTheme.Colors.danger : AppTheme.Colors.success
                )
            }
        }
    }
}

private struct DashboardSpendingSnapshotCard: View {
    var summary: PayPeriodCostSummary
    var periodLabel: String
    var entryCount: Int

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionTitle("Spending snapshot")
                        Text(periodLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer()

                    Pill(
                        text: "\(entryCount) entries",
                        systemImage: "receipt",
                        color: entryCount == 0 ? AppTheme.Colors.tertiaryText : AppTheme.Colors.warning
                    )
                }

                MetricRow(label: "Spent this period", value: MoneyParser.formatPence(summary.manualSpendingPence), valueColor: summary.manualSpendingPence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.primaryText)
                MetricRow(label: "Money left", value: MoneyParser.formatPence(summary.currentMoneyLeftPence), valueColor: summary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                MetricRow(label: "Projected end", value: MoneyParser.formatPence(summary.projectedMoneyLeftPence), valueColor: summary.projectedMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
            }
        }
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

struct DashboardMonthlySpendChartPoint: Equatable, Identifiable {
    var day: Int
    var amountPence: Int
    var isFuture: Bool

    var id: Int { day }
}

enum DashboardMonthlySpendChartMode: String, Equatable, CaseIterable {
    case manualSpends
    case allOutgoings

    var title: String {
        switch self {
        case .manualSpends: "Manual spends"
        case .allOutgoings: "All outgoings"
        }
    }

    var emptyMessagePrefix: String {
        switch self {
        case .manualSpends: "No manual spend recorded in"
        case .allOutgoings: "No outgoings planned in"
        }
    }

    var activeMessageSuffix: String {
        switch self {
        case .manualSpends: "so far"
        case .allOutgoings: "planned and recorded"
        }
    }

    var next: DashboardMonthlySpendChartMode {
        switch self {
        case .manualSpends: .allOutgoings
        case .allOutgoings: .manualSpends
        }
    }
}

struct DashboardMonthlySpendChartData: Equatable {
    var monthLabel: String
    var totalPence: Int
    var averageDailyPence: Int
    var highestDailyPence: Int
    var daysElapsed: Int
    var daysInMonth: Int
    var points: [DashboardMonthlySpendChartPoint]

    var progressFraction: Double {
        guard daysInMonth > 0 else { return 0 }
        return min(1, max(0, Double(daysElapsed) / Double(daysInMonth)))
    }

    var hasSpending: Bool {
        totalPence > 0
    }

    static func make(transactions: [Transaction], todayIso: String) -> DashboardMonthlySpendChartData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let today = FinanceEngine.parseDate(todayIso)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 0
        let currentDay = min(max(todayComponents.day ?? 1, 1), max(daysInMonth, 1))

        var buckets: [Int: Int] = [:]
        for transaction in transactions where transaction.type == .spending && transaction.deletedAt == nil {
            let transactionDate = FinanceEngine.parseDate(transaction.date)
            let transactionComponents = calendar.dateComponents([.year, .month, .day], from: transactionDate)
            guard transactionComponents.year == todayComponents.year,
                  transactionComponents.month == todayComponents.month,
                  let transactionDay = transactionComponents.day,
                  transactionDay <= currentDay
            else {
                continue
            }
            buckets[transactionDay, default: 0] += transaction.amountPence
        }

        let points = (1...max(daysInMonth, 1)).map { day in
            DashboardMonthlySpendChartPoint(
                day: day,
                amountPence: day <= currentDay ? buckets[day, default: 0] : 0,
                isFuture: day > currentDay
            )
        }
        let totalPence = points.reduce(0) { $0 + ($1.isFuture ? 0 : $1.amountPence) }

        return DashboardMonthlySpendChartData(
            monthLabel: today.formatted(.dateTime.month(.wide).year()),
            totalPence: totalPence,
            averageDailyPence: totalPence / max(currentDay, 1),
            highestDailyPence: points.map(\.amountPence).max() ?? 0,
            daysElapsed: currentDay,
            daysInMonth: max(daysInMonth, 1),
            points: points
        )
    }

    static func makeAllOutgoings(snapshot: PlannerSnapshot, todayIso: String) -> DashboardMonthlySpendChartData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let today = FinanceEngine.parseDate(todayIso)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 0
        let currentDay = min(max(todayComponents.day ?? 1, 1), max(daysInMonth, 1))
        let monthStart = monthBoundaryIsoDate(today, calendar: calendar, day: 1)
        let monthEnd = monthBoundaryIsoDate(today, calendar: calendar, day: max(daysInMonth, 1))

        var buckets: [Int: Int] = [:]
        for event in PlannerDerivedData.calendarEvents(snapshot: snapshot, startDate: monthStart, endDate: monthEnd) {
            // Pot allocations are internal transfers. The bill/card/debt event they
            // fund is already represented in this chart, so including both would
            // inflate "All outgoings" without changing the safe-to-spend calculation.
            guard event.type != .payday,
                  event.type != .allocation,
                  let amountPence = event.amountPence,
                  amountPence > 0
            else {
                continue
            }

            let eventDate = FinanceEngine.parseDate(event.date)
            let eventComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
            guard eventComponents.year == todayComponents.year,
                  eventComponents.month == todayComponents.month,
                  let eventDay = eventComponents.day
            else {
                continue
            }

            buckets[eventDay, default: 0] += amountPence
        }

        let points = (1...max(daysInMonth, 1)).map { day in
            DashboardMonthlySpendChartPoint(
                day: day,
                amountPence: buckets[day, default: 0],
                isFuture: day > currentDay
            )
        }
        let totalPence = points.reduce(0) { $0 + $1.amountPence }

        return DashboardMonthlySpendChartData(
            monthLabel: today.formatted(.dateTime.month(.wide).year()),
            totalPence: totalPence,
            averageDailyPence: totalPence / max(daysInMonth, 1),
            highestDailyPence: points.map(\.amountPence).max() ?? 0,
            daysElapsed: currentDay,
            daysInMonth: max(daysInMonth, 1),
            points: points
        )
    }

    private static func monthBoundaryIsoDate(_ date: Date, calendar: Calendar, day: Int) -> String {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = day
        return FinanceEngine.toIsoDate(calendar.date(from: components) ?? date)
    }
}

private struct DashboardMonthlySpendChartView: View {
    var manualData: DashboardMonthlySpendChartData
    var outgoingsData: DashboardMonthlySpendChartData
    @State private var mode: DashboardMonthlySpendChartMode = .manualSpends

    private var data: DashboardMonthlySpendChartData {
        switch mode {
        case .manualSpends: manualData
        case .allOutgoings: outgoingsData
        }
    }

    var body: some View {
        AppCard(glow: data.hasSpending) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(mode.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                            .textCase(.uppercase)
                        Text(MoneyParser.formatPence(data.totalPence))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(data.hasSpending ? AppTheme.Colors.primaryText : AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(data.hasSpending ? "\(data.monthLabel) \(mode.activeMessageSuffix)" : "\(mode.emptyMessagePrefix) \(data.monthLabel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    VStack(alignment: .trailing, spacing: AppTheme.Spacing.sm) {
                        Button {
                            withAnimation(AppTheme.Animation.standard) {
                                mode = mode.next
                            }
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.Colors.primaryOrange.opacity(0.14))
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("Switch monthly chart")

                        DashboardMonthProgressBadge(progress: data.progressFraction, label: "\(data.daysElapsed)/\(data.daysInMonth)")
                    }
                }

                DashboardSpendBarGraph(data: data)
                    .frame(height: 118)

                HStack(spacing: AppTheme.Spacing.sm) {
                    DashboardChartMetricPill(label: "Daily avg", value: MoneyParser.formatPence(data.averageDailyPence), color: AppTheme.Colors.primaryOrange)
                    DashboardChartMetricPill(label: "Highest", value: MoneyParser.formatPence(data.highestDailyPence), color: AppTheme.Colors.warning)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mode.title) \(MoneyParser.formatPence(data.totalPence))")
    }
}

private struct DashboardSpendBarGraph: View {
    var data: DashboardMonthlySpendChartData

    var body: some View {
        GeometryReader { proxy in
            let maxAmount = max(data.highestDailyPence, 1)
            let availableHeight = max(proxy.size.height - 24, 1)

            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        AppTheme.Colors.border.opacity(0.45)
                            .frame(height: 1)
                        Spacer()
                    }
                    AppTheme.Colors.border.opacity(0.45)
                        .frame(height: 1)
                }

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(data.points) { point in
                        Capsule(style: .continuous)
                            .fill(barFill(for: point))
                            .frame(maxWidth: .infinity)
                            .frame(height: barHeight(for: point, maxAmount: maxAmount, availableHeight: availableHeight))
                            .opacity(pointOpacity(point))
                            .shadow(
                                color: point.amountPence == data.highestDailyPence && data.hasSpending ? AppTheme.Colors.glowOrange.opacity(0.72) : .clear,
                                radius: 8,
                                y: 4
                            )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.top, AppTheme.Spacing.sm)

                HStack {
                    Text("1")
                    Spacer()
                    Text("\(data.daysElapsed)")
                    Spacer()
                    Text("\(data.daysInMonth)")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .offset(y: 18)
            }
        }
    }

    private func barFill(for point: DashboardMonthlySpendChartPoint) -> AnyShapeStyle {
        if point.isFuture {
            return AnyShapeStyle(AppTheme.Colors.border.opacity(0.38))
        }
        if point.amountPence == 0 {
            return AnyShapeStyle(AppTheme.Colors.elevatedSurface)
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    AppTheme.Colors.primaryOrange,
                    AppTheme.Colors.warning,
                    AppTheme.Colors.success.opacity(0.78)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    private func barHeight(for point: DashboardMonthlySpendChartPoint, maxAmount: Int, availableHeight: CGFloat) -> CGFloat {
        guard point.amountPence > 0 else { return 7 }
        return max(12, CGFloat(point.amountPence) / CGFloat(maxAmount) * availableHeight)
    }

    private func pointOpacity(_ point: DashboardMonthlySpendChartPoint) -> Double {
        if point.isFuture { return 0.42 }
        return point.amountPence == 0 ? 0.62 : 1
    }
}

private struct DashboardMonthProgressBadge: View {
    var progress: Double
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Colors.border, lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.Gradients.primary,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("days")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .frame(width: 64, height: 64)
    }
}

private struct DashboardChartMetricPill: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DashboardActivityRowView: View {
    var row: DashboardActivityRow
    var showsChevron = false

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            DashboardFeedIcon(symbol: row.symbol, color: row.color, badgeSymbol: row.paycheckId == nil ? nil : "plus")

            VStack(alignment: .leading, spacing: 5) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(2)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.amount)
                .font(.headline.weight(.bold))
                .foregroundStyle(row.color)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct DashboardMoneyEventRowView: View {
    var title: String
    var subtitle: String
    var amount: String?
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            DashboardFeedIcon(symbol: symbol, color: color)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let amount {
                Text(amount)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DashboardFeedIcon: View {
    var symbol: String
    var color: Color
    var badgeSymbol: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.14))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.28), lineWidth: 1)
                )

            if let badgeSymbol {
                Image(systemName: badgeSymbol)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.surface)
                    .frame(width: 18, height: 18)
                    .background(AppTheme.Colors.primaryText)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: 50, height: 50)
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
    var excludeAction: () -> Void
    @State private var isBreakdownExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
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
                                .strikethrough(item.isExcluded, color: AppTheme.Colors.secondaryText)
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

                FundingChecklistBreakdownToggle(isExpanded: $isBreakdownExpanded, itemName: item.name)

                if !isReadOnly {
                    Button(action: excludeAction) {
                        Image(systemName: item.isExcluded ? "arrow.uturn.backward.circle.fill" : "xmark.circle")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(item.isExcluded ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isExcluded ? "Include \(item.name)" : "Exclude \(item.name)")
                }
            }

            if isBreakdownExpanded {
                FundingChecklistBreakdownList(items: item.breakdown)
            }
        }
        .opacity(isReadOnly ? 0.72 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        if item.isExcluded {
            return AppTheme.Colors.warning
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.secondaryText
    }

    private var titleColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        if item.isExcluded {
            return AppTheme.Colors.secondaryText
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.primaryText
    }

    private var detailText: String {
        if item.isExcluded {
            return "\(item.detail) · excluded this period"
        }

        guard let paidDate = item.paidDate else {
            return item.detail
        }

        return "\(item.detail) · paid \(shortDate(paidDate))"
    }

    private var accessibilityLabel: String {
        if isReadOnly {
            return "Paid \(item.name)"
        }

        if item.isExcluded {
            return "Fund excluded \(item.name)"
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
        .toolbarColorScheme(AppTheme.selectedColorScheme, for: .navigationBar)
        .appPlaceholderToolbar(toolbarMode)
    }
}

struct IncomeBreakdownView: View {
    @ObservedObject var store: PlannerStore
    @State private var isAddIncomePresented = false
    @State private var isPaycheckInputsExpanded = true
    @State private var isOneOffIncomeExpanded = true
    @State private var isPayPeriodsExpanded = false
    @State private var editMode: EditMode = .inactive

    private var snapshot: PlannerSnapshot { store.snapshot }
    private var costSummary: PayPeriodCostSummary {
        PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: store.selectedPayPeriod, asOfDate: store.todayIso)
    }
    private var activePaychecks: [Paycheck] {
        snapshot.paychecks
            .filter { $0.deletedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    private var activeOneOffIncomes: [OneOffIncome] {
        snapshot.oneOffIncomes
            .filter { $0.deletedAt == nil }
            .sorted { $0.date > $1.date }
    }
    private var activePayPeriods: [PayPeriod] {
        snapshot.payPeriods
            .filter { $0.deletedAt == nil }
            .sorted { $0.payday > $1.payday }
    }
    private var hasDeletableIncome: Bool {
        !activePaychecks.isEmpty || !activeOneOffIncomes.isEmpty || !activePayPeriods.isEmpty
    }

    var body: some View {
        DashboardBreakdownScaffold(
            title: "Income",
            subtitle: "Paycheck inputs, pay periods, and period money left.",
            toolbarMode: .editDone(isEditing: editMode.isEditing, canEdit: hasDeletableIncome) {
                toggleEditMode()
            }
        ) {
            AppCard(glow: true) {
                MetricRow(label: "Current plan", value: MoneyParser.formatPence(store.selectedPayPeriod.map { PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: $0) } ?? 0), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Money left", value: MoneyParser.formatPence(costSummary.currentMoneyLeftPence), valueColor: costSummary.currentMoneyLeftPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                MetricRow(label: "Projected costs", value: MoneyParser.formatPence(costSummary.projectedCostsPence), valueColor: AppTheme.Colors.warning)
                if costSummary.unfundedChecklistPence > 0 {
                    MetricRow(label: "Unfunded checklist", value: MoneyParser.formatPence(costSummary.unfundedChecklistPence), valueColor: AppTheme.Colors.secondaryText)
                }
            }

            paycheckInputsSection
            oneOffIncomeSection
            payPeriodsSection
        }
        .sheet(isPresented: $isAddIncomePresented) {
            AddPaycheckSheetView(store: store)
        }
        .environment(\.editMode, $editMode)
    }

    private var paycheckInputsSection: some View {
        IncomeExpandableSection(title: "Paycheck inputs", isExpanded: $isPaycheckInputsExpanded) {
            if activePaychecks.isEmpty {
                AppCard { EmptyStateView(title: "No paycheck inputs", message: "Saved paycheck plans will appear here.", systemImage: "sterlingsign.circle") }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(activePaychecks, id: \.id) { paycheck in
                        let paydayLabel = period(for: paycheck).map { FinanceEngine.formatPaydayLabel($0.payday) } ?? "No linked period"
                        if editMode.isEditing {
                            PaycheckInputRow(
                                paydayLabel: paydayLabel,
                                amountLabel: MoneyParser.formatPence(paycheck.actualAmountPence ?? paycheck.calculatedAmountPence),
                                onDelete: {
                                    store.deletePaycheck(id: paycheck.id)
                                }
                            )
                        } else {
                            NavigationLink {
                                PaycheckDetailView(store: store, paycheck: paycheck, presentation: .push)
                            } label: {
                                PaycheckInputRow(
                                    paydayLabel: paydayLabel,
                                    amountLabel: MoneyParser.formatPence(paycheck.actualAmountPence ?? paycheck.calculatedAmountPence)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open paycheck \(paydayLabel)")
                        }
                    }
                }
            }
        }
    }

    private var oneOffIncomeSection: some View {
        IncomeExpandableSection(title: "One-off income", isExpanded: $isOneOffIncomeExpanded) {
            if activeOneOffIncomes.isEmpty {
                AppCard {
                    EmptyStateView(
                        title: "No one-off income",
                        message: "Birthday money, bonuses, and corrections will appear here.",
                        systemImage: "plus.circle"
                    )
                }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(activeOneOffIncomes, id: \.id) { income in
                        if editMode.isEditing {
                            OneOffIncomeRow(
                                name: income.name,
                                dateLabel: FinanceEngine.formatPaydayLabel(income.date),
                                periodLabel: period(for: income).map { FinanceEngine.formatPaydayLabel($0.payday) },
                                amountLabel: MoneyParser.formatPence(income.amountPence),
                                onDelete: {
                                    _ = store.deleteOneOffIncome(id: income.id)
                                }
                            )
                        } else {
                            NavigationLink {
                                OneOffIncomeDetailView(store: store, income: income)
                            } label: {
                                OneOffIncomeRow(
                                    name: income.name,
                                    dateLabel: FinanceEngine.formatPaydayLabel(income.date),
                                    periodLabel: period(for: income).map { FinanceEngine.formatPaydayLabel($0.payday) },
                                    amountLabel: MoneyParser.formatPence(income.amountPence)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open income \(income.name)")
                        }
                    }
                }
            }
        }
    }

    private var payPeriodsSection: some View {
        IncomeExpandableSection(title: "Pay periods", isExpanded: $isPayPeriodsExpanded) {
            if activePayPeriods.isEmpty {
                AppCard { EmptyStateView(title: "No pay periods", message: "Create a paycheck plan to start tracking periods.", systemImage: "calendar") }
            } else {
                ForEach(activePayPeriods) { period in
                    AppCard {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            MetricRow(label: "Payday", value: FinanceEngine.formatPaydayLabel(period.payday))

                            if editMode.isEditing {
                                DestructiveBadgeButton(
                                    accessibilityLabel: "Delete pay period for \(FinanceEngine.formatPaydayLabel(period.payday))",
                                    confirmationTitle: "Delete this pay period?",
                                    confirmationMessage: "This removes the pay period, its linked paycheck inputs, and its pot allocations.",
                                    action: {
                                        store.deletePayPeriod(id: period.id)
                                    }
                                )
                            }
                        }
                        MetricRow(label: "Period", value: "\(FinanceEngine.formatPaydayLabel(period.startDate)) to \(FinanceEngine.formatPaydayLabel(period.endDate))")
                        MetricRow(label: "Next payday", value: FinanceEngine.formatPaydayLabel(period.nextPayday))
                        MetricRow(label: "Income", value: MoneyParser.formatPence(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period)), valueColor: AppTheme.Colors.success)
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

    private func period(for income: OneOffIncome) -> PayPeriod? {
        if let payPeriodId = income.payPeriodId,
           let period = snapshot.payPeriods.first(where: { $0.id == payPeriodId }) {
            return period
        }
        return PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: income.date)
    }

    private func allocations(for period: PayPeriod) -> [PotAllocation] {
        snapshot.potAllocations.filter { $0.payPeriodId == period.id }
    }

    private func potName(for id: String) -> String {
        snapshot.pots.first { $0.id == id }?.name ?? "Pot"
    }

    private func toggleEditMode() {
        withAnimation(appToolbarMorphAnimation) {
            editMode = editMode.isEditing ? .inactive : .active
        }
    }
}

private struct IncomeExpandableSection<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleExpansion) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    SectionTitle(title)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(AppTheme.Colors.appBackground)
            .zIndex(1)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Closes this section" : "Opens this section")

            if isExpanded {
                content
                    .padding(.top, AppTheme.Spacing.md)
                    .transition(contentTransition)
                    .zIndex(0)
            }
        }
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -14)),
            removal: .opacity.combined(with: .offset(y: -14))
        )
    }

    private func toggleExpansion() {
        let animation = reduceMotion
            ? Animation.linear(duration: 0.12)
            : Animation.easeOut(duration: 0.18)

        withAnimation(animation) {
            isExpanded.toggle()
        }
    }
}

private struct PaycheckInputRow: View {
    var paydayLabel: String
    var amountLabel: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Payday")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(paydayLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }

                Spacer()

                Text(amountLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let onDelete {
                    DestructiveBadgeButton(
                        accessibilityLabel: "Delete paycheck for \(paydayLabel)",
                        confirmationTitle: "Delete this paycheck?",
                        confirmationMessage: "This removes the paycheck, its linked pay period, and its pot allocations.",
                        action: onDelete
                    )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

private struct OneOffIncomeRow: View {
    var name: String
    var dateLabel: String
    var periodLabel: String?
    var amountLabel: String
    var onDelete: (() -> Void)? = nil

    var body: some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.success)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.success.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    Text(periodLabel.map { "\(dateLabel) · \($0)" } ?? dateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(amountLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if let onDelete {
                    DestructiveBadgeButton(
                        accessibilityLabel: "Delete income \(name)",
                        confirmationTitle: "Delete this income?",
                        confirmationMessage: "This one-off income will be removed from your saved income.",
                        action: onDelete
                    )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
            .contentShape(Rectangle())
        }
    }
}

private struct OneOffIncomeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var income: OneOffIncome
    @State private var name: String
    @State private var amount: String
    @State private var date: Date
    @State private var note: String
    @State private var showDeleteAlert = false

    init(store: PlannerStore, income: OneOffIncome) {
        self.store = store
        self.income = income
        _name = State(initialValue: income.name)
        _amount = State(initialValue: Self.formatMoneyInput(income.amountPence))
        _date = State(initialValue: income.date.isoDate)
        _note = State(initialValue: income.note)
    }

    var body: some View {
        DashboardBreakdownScaffold(
            title: "Edit income",
            subtitle: "",
            toolbarMode: .none
        ) {
            summaryCard
            editCard
            SecondaryButton(title: "Delete income", systemImage: "trash", role: .destructive) {
                showDeleteAlert = true
            }
        }
        .alert("Delete income?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if store.deleteOneOffIncome(id: income.id) {
                    dismiss()
                }
            }
        } message: {
            Text("This removes the income from your totals for this pay period.")
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(label: "Name", value: currentIncome.name)
            MetricRow(label: "Amount", value: MoneyParser.formatPence(currentIncome.amountPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Date", value: FinanceEngine.formatPaydayLabel(currentIncome.date))
            if let period = currentPeriod {
                MetricRow(label: "Pay period", value: "\(FinanceEngine.formatPaydayLabel(period.startDate)) to \(FinanceEngine.formatPaydayLabel(period.endDate))")
            }
        }
    }

    private var editCard: some View {
        AppCard {
            SectionTitle("Edit one-off income")

            TextField("Source", text: $name)
                .textFieldStyle(AppTextFieldStyle())

            MoneyField(title: "Amount", text: $amount)

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .tint(AppTheme.Colors.primaryOrange)
                .foregroundStyle(AppTheme.Colors.primaryText)

            TextField("Note", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(AppTextFieldStyle())

            PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSaveChanges) {
                _ = store.updateOneOffIncome(
                    id: income.id,
                    name: name,
                    amountPence: MoneyParser.parsePoundsToPence(amount),
                    date: date.isoDateString,
                    note: note
                )
            }
        }
    }

    private var currentIncome: OneOffIncome {
        store.snapshot.oneOffIncomes.first(where: { $0.id == income.id }) ?? income
    }

    private var currentPeriod: PayPeriod? {
        if let payPeriodId = currentIncome.payPeriodId,
           let period = store.snapshot.payPeriods.first(where: { $0.id == payPeriodId }) {
            return period
        }
        return PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: currentIncome.date)
    }

    private var canSaveChanges: Bool {
        MoneyParser.parsePoundsToPence(amount) > 0
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        String(format: "%.2f", Double(amountPence) / 100)
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
        return PlannerDerivedData.resolvedRecurringOccurrences(snapshot: snapshot, payments: snapshot.recurringPayments, startDate: store.todayIso, endDate: endDate)
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
        return PlannerDerivedData.resolvedRecurringOccurrences(snapshot: snapshot, payments: snapshot.recurringPayments, startDate: period.startDate, endDate: period.endDate)
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
    private var activeDebts: [Debt] { snapshot.debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 } }
    private var inactiveDebts: [Debt] { snapshot.debts.filter { !$0.status.isActiveLike || $0.currentBalancePence <= 0 } }

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
            AppCard(glow: debt.status == .overdue || debt.status == .dueToday) {
                VStack(alignment: .leading, spacing: 10) {
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
                            Text(debtStatusLabel(debt.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(debt.status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    ProgressView(value: debtProgress(debt))
                        .tint(AppTheme.Colors.primaryOrange)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Next")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                            Text(nextPaymentText(for: debt))
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Funded")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                            Text(MoneyParser.formatPence(nextFundedPence(for: debt)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.success)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(debt.name)")
    }

    private func scheduleItems(for debt: Debt) -> [DebtPaymentScheduleItem] {
        PlannerDerivedData.debtScheduleItems(snapshot: snapshot, payPeriod: nil)
            .filter { $0.debtId == debt.id && $0.status != .cancelled }
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    private func nextScheduleItem(for debt: Debt) -> DebtPaymentScheduleItem? {
        scheduleItems(for: debt).first { $0.status != .paid }
    }

    private func nextPaymentText(for debt: Debt) -> String {
        guard let item = nextScheduleItem(for: debt) else { return "No scheduled payment" }
        return "\(MoneyParser.formatPence(item.plannedAmountPence)) · \(item.dueDate)"
    }

    private func nextFundedPence(for debt: Debt) -> Int {
        nextScheduleItem(for: debt)?.fundedAmountPence ?? 0
    }

    private func debtProgress(_ debt: Debt) -> Double {
        let starting = max(1, debt.startingBalancePence)
        let paid = max(0, starting - debt.currentBalancePence)
        return min(1, max(0, Double(paid) / Double(starting)))
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
            return "\(debt.lender) · \(potName) · \(debtStrategyLabel(debt.repaymentStrategy))"
        }
        return "\(debt.lender) · \(debtStrategyLabel(debt.repaymentStrategy))"
    }
}

private struct RecordDebtPaymentSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var debtId: String
    @State private var amount = ""
    @State private var paymentDate = Date()
    @State private var paymentType: DebtPaymentType = .manualPayNow
    @State private var recalculationMode: DebtRecalculationMode = .finishEarlier
    @State private var note = ""

    init(store: PlannerStore) {
        self.store = store
        _debtId = State(initialValue: store.snapshot.debts.first { $0.status.isActiveLike && $0.currentBalancePence > 0 }?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    formCard
                    if let debt = selectedPaymentDebt {
                        AppCard {
                            MetricRow(label: "Current debt", value: MoneyParser.formatPence(debt.currentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
                            MetricRow(label: paymentType == .manualSetAside ? "Set aside" : "Payment", value: MoneyParser.formatPence(parsedAmountPence), valueColor: AppTheme.Colors.success)
                            MetricRow(label: "Balance after", value: MoneyParser.formatPence(paymentType == .manualSetAside ? debt.currentBalancePence : max(0, debt.currentBalancePence - parsedAmountPence)), valueColor: AppTheme.Colors.primaryOrange)
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
            Picker("Action", selection: $paymentType) {
                Text("Pay now").tag(DebtPaymentType.manualPayNow)
                Text("Set aside").tag(DebtPaymentType.manualSetAside)
            }
            .pickerStyle(.segmented)
            Picker("Recalculate", selection: $recalculationMode) {
                Text("Lower payments").tag(DebtRecalculationMode.lowerFuturePayments)
                Text("Finish earlier").tag(DebtRecalculationMode.finishEarlier)
                Text("Skip next").tag(DebtRecalculationMode.skipNextPayment)
            }
            .pickerStyle(.menu)
            DatePicker("Payment date", selection: $paymentDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Record payment", systemImage: "checkmark.circle", isDisabled: !canSave) {
                store.recordManualDebtPayment(
                    debtId: debtId,
                    amountPence: parsedAmountPence,
                    date: paymentDate.isoDateString,
                    paymentType: paymentType,
                    recalculationMode: recalculationMode,
                    note: note
                )
                dismiss()
            }
        }
    }

    private var selectableDebts: [Debt] {
        store.snapshot.debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 }
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
                scheduleCard
                paymentHistoryCard
                interestCard
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
        .toolbarColorScheme(AppTheme.selectedColorScheme, for: .navigationBar)
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
            MetricRow(label: "Original balance", value: MoneyParser.formatPence(currentDebt.startingBalancePence))
            ProgressView(value: debtProgress)
                .tint(AppTheme.Colors.primaryOrange)
            MetricRow(label: "Minimum payment", value: MoneyParser.formatPence(currentDebt.minimumPaymentPence))
            MetricRow(label: "Strategy", value: debtStrategyLabel(currentDebt.repaymentStrategy))
            MetricRow(label: "Next payment", value: nextScheduleItem.map { "\(MoneyParser.formatPence($0.plannedAmountPence)) on \($0.dueDate)" } ?? "None")
            MetricRow(label: "APR", value: currentDebt.interestRateApr.map { String(format: "%.2f%%", $0) } ?? "Not set")
            MetricRow(label: "Payments", value: MoneyParser.formatPence(paymentsTotalPence), valueColor: AppTheme.Colors.success)
            MetricRow(label: "Linked pot", value: linkedDebtPotName(in: store.snapshot, debtId: currentDebt.id) ?? "None")
            MetricRow(label: "Status", value: debtStatusLabel(currentDebt.status), valueColor: currentDebt.status.isActiveLike ? AppTheme.Colors.success : AppTheme.Colors.tertiaryText)
            MetricRow(label: "Note", value: currentDebt.note.isBlank ? "No note" : currentDebt.note)
        }
    }

    private var scheduleCard: some View {
        AppCard {
            SectionTitle("Schedule")
            if scheduleItems.isEmpty {
                EmptyStateView(title: "No scheduled payments", message: "Manual-only debts show payments after you add them.", systemImage: "calendar")
            } else {
                ForEach(scheduleItems, id: \.id) { (item: DebtPaymentScheduleItem) in
                    scheduleRow(item)
                    Divider().overlay(AppTheme.Colors.divider)
                }
            }
        }
    }

    private func scheduleRow(_ item: DebtPaymentScheduleItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.dueDate)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text("\(item.status.rawValue.replacingOccurrences(of: "_", with: " ")) · funded \(MoneyParser.formatPence(item.fundedAmountPence))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            Spacer()
            Text(MoneyParser.formatPence(item.plannedAmountPence))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.status == .paid ? AppTheme.Colors.success : AppTheme.Colors.orangeHighlight)
        }
    }

    private var paymentHistoryCard: some View {
        AppCard {
            SectionTitle("Payment history")
            let payments = store.snapshot.debtPayments.filter { $0.debtId == currentDebt.id }.sorted { $0.date > $1.date }
            if payments.isEmpty {
                EmptyStateView(title: "No payments yet", message: "Debt payments will appear here.", systemImage: "checkmark.circle")
            } else {
                ForEach(payments) { payment in
                    MetricRow(label: payment.date, value: MoneyParser.formatPence(payment.amountPence), valueColor: AppTheme.Colors.success)
                }
            }
        }
    }

    private var interestCard: some View {
        AppCard {
            SectionTitle("Interest")
            MetricRow(label: "Type", value: debtInterestLabel(currentDebt.interestType))
            MetricRow(label: "Estimated scheduled interest", value: MoneyParser.formatPence(scheduleItems.reduce(0) { $0 + $1.interestAmountPence }))
            if currentDebt.status == .interestRisk {
                Text("Payment does not cover estimated interest. Debt may increase.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.danger)
            }
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
                updated.aprBasisPoints = Double(apr).map { Int(($0 * 100).rounded()) }
                updated.interestType = updated.aprBasisPoints == nil ? .none : .apr
                updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.status = currentBalancePence > 0 ? status : .paidOff
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

    private var scheduleItems: [DebtPaymentScheduleItem] {
        PlannerDerivedData.debtScheduleItems(snapshot: store.snapshot, payPeriod: nil)
            .filter { $0.debtId == currentDebt.id && $0.status != .cancelled }
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
    }

    private var nextScheduleItem: DebtPaymentScheduleItem? {
        scheduleItems.first { $0.status != .paid }
    }

    private var debtProgress: Double {
        let starting = max(1, currentDebt.startingBalancePence)
        return min(1, max(0, Double(max(0, starting - currentDebt.currentBalancePence)) / Double(starting)))
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
        var debts = store.snapshot.debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 }
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

private func debtStatusLabel(_ status: DebtStatus) -> String {
    status.rawValue
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}

private func debtStrategyLabel(_ strategy: DebtRepaymentStrategy) -> String {
    switch strategy {
    case .autoSpreadUntilDueDate: return "Auto spread"
    case .payIn4: return "Pay in 4"
    case .fixedPayment: return "Fixed payment"
    case .minimumPlusExtra: return "Minimum + extra"
    case .manualOnly: return "Manual only"
    }
}

private func debtInterestLabel(_ type: DebtInterestType) -> String {
    switch type {
    case .none: return "None"
    case .apr: return "APR"
    case .fixedFee: return "Fixed fee"
    }
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

private enum PaycheckDetailPresentation: Equatable {
    case sheet
    case push
}

private struct PaycheckDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var paycheck: Paycheck
    var presentation: PaycheckDetailPresentation = .sheet
    @State private var payday: Date
    @State private var hoursWorked: String
    @State private var hourlyRate: String
    @State private var payFrequency: PayFrequency
    @State private var showDeleteAlert = false

    init(store: PlannerStore, paycheck: Paycheck, presentation: PaycheckDetailPresentation = .sheet) {
        self.store = store
        self.paycheck = paycheck
        self.presentation = presentation
        let period = store.snapshot.payPeriods.first(where: { $0.id == paycheck.payPeriodId })
        _payday = State(initialValue: period?.payday.isoDate ?? Date())
        _hoursWorked = State(initialValue: Self.formatHours(paycheck.hoursWorked))
        _hourlyRate = State(initialValue: Self.formatMoneyInput(paycheck.hourlyRatePence))
        _payFrequency = State(initialValue: period?.payFrequency ?? store.snapshot.settings.payFrequency)
    }

    var body: some View {
        switch presentation {
        case .sheet:
            NavigationStack {
                detailContent
            }
        case .push:
            detailContent
        }
    }

    private var detailContent: some View {
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
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(AppTheme.selectedColorScheme, for: .navigationBar)
        .toolbar {
            if presentation == .sheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
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
