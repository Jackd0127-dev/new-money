import SwiftUI

private func shortDate(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
}

private extension String {
    var formattedDayLabel: String {
        FinanceEngine.parseDate(self).formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    var prefixDateLabel: String {
        String(prefix(10))
    }
}

enum PlanSection: String, Equatable {
    case calendar
    case upcomingBills
    case recurringPayments
    case incomeSchedule
}

enum PlanCalendarElement: String, Equatable {
    case monthHeaderCard
    case swipeMonthGrid
    case selectedDaySummary
}

enum PlanMonthSwipeTransition: Equatable {
    case horizontalSlide
}

struct PlanLayoutPolicy {
    static let sections: [PlanSection] = [
        .calendar,
        .upcomingBills,
        .recurringPayments
    ]

    static let calendarElements: [PlanCalendarElement] = [
        .swipeMonthGrid,
        .selectedDaySummary
    ]

    static let showsCalendarSectionTitle = false
    static let monthSwipeTransition: PlanMonthSwipeTransition = .horizontalSlide
    static let dayCellHeight: CGFloat = 42
    static let emptySelectedDayMessage = "No money events are scheduled for this day."
    static let emptyUpcomingBillsSubtitle = "Upcoming bills will appear here."
    static let emptyRecurringPaymentsSubtitle = "Recurring payments will appear here."
}

enum CreditRoute: String, CaseIterable, Equatable {
    case cards
    case debts

    var title: String {
        switch self {
        case .cards: "Cards"
        case .debts: "Debts"
        }
    }

    var subtitle: String {
        switch self {
        case .cards: "Balances, limits, repayments, and card activity."
        case .debts: "Balances, reserves, minimums, and payoff progress."
        }
    }

    var symbol: String {
        switch self {
        case .cards: "creditcard"
        case .debts: "exclamationmark.shield"
        }
    }
}

struct PlanView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "Plan",
            subtitle: "Bills, income, and calendar planning.",
            navigationMode: .tabRoot,
            toolbarMode: .none
        ) {
            ForEach(PlanLayoutPolicy.sections, id: \.rawValue) { section in
                planSection(section)
            }
        }
    }

    @ViewBuilder
    private func planSection(_ section: PlanSection) -> some View {
        switch section {
        case .calendar:
            PlanCalendarSection(store: store)
        case .upcomingBills:
            upcomingBills
        case .recurringPayments:
            recurringPayments
        case .incomeSchedule:
            EmptyView()
        }
    }

    private var upcomingBills: some View {
        let endDate = FinanceEngine.addIsoDays(date: store.todayIso, days: 30)
        let upcoming = PlannerDerivedData.recurringOccurrences(
            payments: store.snapshot.recurringPayments,
            startDate: store.todayIso,
            endDate: endDate
        )

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Upcoming bills")
            if upcoming.isEmpty {
                PlanSubtitleCard(text: PlanLayoutPolicy.emptyUpcomingBillsSubtitle)
            } else {
                ForEach(Array(upcoming.prefix(4))) { occurrence in
                    PlanSubtitleCard(text: "\(occurrence.payment.name) is due \(shortDate(occurrence.dueDate)).")
                }
            }
        }
    }

    private var recurringPayments: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Recurring payments")
            if store.snapshot.recurringPayments.isEmpty {
                PlanSubtitleCard(text: PlanLayoutPolicy.emptyRecurringPaymentsSubtitle)
            } else {
                ForEach(store.snapshot.recurringPayments.prefix(6)) { payment in
                    PlanSubtitleCard(text: "\(payment.name) repeats \(payment.frequency.rawValue.lowercased()).")
                }
            }
        }
    }

}

private struct PlanSubtitleCard: View {
    var text: String

    var body: some View {
        AppCard {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PlanCalendarSection: View {
    @ObservedObject var store: PlannerStore
    @State private var month = Date()
    @State private var selectedDate = FinanceEngine.toIsoDate(Date())
    @State private var selectedDayDetail: PlanDayDetail?
    @State private var dragTranslation: CGFloat = 0
    @State private var monthSwipeDirection = 1

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            calendarGrid
            selectedDaySummary
        }
        .sheet(item: $selectedDayDetail) { detail in
            PlanDayDetailSheet(detail: detail)
        }
        .onAppear {
            if selectedDate < monthStart || selectedDate > monthEnd {
                selectedDate = store.todayIso
            }
        }
    }

    private var calendarGrid: some View {
        AppCard {
            ZStack {
                monthGridContent
                    .id(monthStart)
                    .offset(x: dragTranslation)
                    .transition(monthSlideTransition)
            }
            .clipped()
        }
        .gesture(monthSwipeGesture)
    }

    private var monthGridContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    if let isoDate = day.isoDate {
                        Button {
                            withAnimation(AppTheme.Animation.standard) {
                                selectedDate = isoDate
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(day.dayNumber)")
                                    .font(.caption.weight(day.isToday ? .bold : .semibold))
                                    .foregroundStyle(dayTextColor(day))
                                    .frame(width: 28, height: 28)
                                    .background(dayBackground(day))
                                    .clipShape(Circle())

                                HStack(spacing: 2) {
                                    ForEach(markers(for: isoDate), id: \.self) { marker in
                                        Image(systemName: marker == .moneyIn ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                            .font(.system(size: 6, weight: .bold))
                                            .foregroundStyle(marker == .moneyIn ? AppTheme.Colors.success : AppTheme.Colors.warning)
                                    }
                                }
                                .frame(height: 6)
                            }
                            .frame(maxWidth: .infinity, minHeight: PlanLayoutPolicy.dayCellHeight)
                            .opacity(day.isCurrentMonth ? 1 : 0.32)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(minHeight: PlanLayoutPolicy.dayCellHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var selectedDaySummary: some View {
        let events = eventsByDate[selectedDate] ?? []
        let moneyIn = events.filter(isMoneyIn).compactMap(\.amountPence).reduce(0, +)
        let moneyOut = events.filter { !isMoneyIn($0) }.compactMap(\.amountPence).reduce(0, +)
        let net = moneyIn - moneyOut

        if events.isEmpty {
            PlanSubtitleCard(text: PlanLayoutPolicy.emptySelectedDayMessage)
        } else {
            AppCard {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionTitle(selectedDate.formattedDayLabel)
                            Text("\(events.count) item\(events.count == 1 ? "" : "s") planned")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        Spacer()
                        Button("View day") {
                            selectedDayDetail = PlanDayDetail(date: selectedDate, events: events)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                    }

                    MetricRow(label: "Money in", value: MoneyParser.formatPence(moneyIn), valueColor: AppTheme.Colors.success)
                    MetricRow(label: "Money out", value: MoneyParser.formatPence(moneyOut), valueColor: moneyOut > 0 ? AppTheme.Colors.warning : AppTheme.Colors.primaryText)
                    MetricRow(label: "Net change", value: MoneyParser.formatPence(net), valueColor: net < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)

                    AppDivider()
                    ForEach(events.prefix(4)) { event in
                        calendarEventLine(event)
                    }
                }
            }
        }
    }

    private var monthStart: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month], from: month)
        return FinanceEngine.toIsoDate(calendar.date(from: components) ?? month)
    }

    private var monthEnd: String {
        let start = monthStart.isoDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return FinanceEngine.toIsoDate(FinanceEngine.addDays(next, days: -1))
    }

    private var events: [CalendarEvent] {
        PlannerDerivedData.calendarEvents(snapshot: store.snapshot, startDate: monthStart, endDate: monthEnd)
    }

    private var eventsByDate: [String: [CalendarEvent]] {
        Dictionary(grouping: events, by: \.date)
    }

    private var calendarDays: [PlanCalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = FinanceEngine.parseDate(monthStart)
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let weekday = calendar.component(.weekday, from: start)
        let leadingEmptyCount = (weekday + 5) % 7
        var days = (0..<leadingEmptyCount).map { PlanCalendarDay(id: "blank-\($0)", isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false) }

        days += dayRange.map { day in
            var components = calendar.dateComponents([.year, .month], from: start)
            components.day = day
            let date = calendar.date(from: components) ?? start
            let isoDate = FinanceEngine.toIsoDate(date)
            return PlanCalendarDay(id: isoDate, isoDate: isoDate, dayNumber: day, isCurrentMonth: true, isToday: isoDate == store.todayIso)
        }

        while days.count % 7 != 0 {
            days.append(PlanCalendarDay(id: "blank-\(days.count)", isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false))
        }

        return days
    }

    private func moveMonth(by value: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        selectedDate = monthStart
    }

    private var monthSlideTransition: AnyTransition {
        let insertion: Edge = monthSwipeDirection > 0 ? .trailing : .leading
        let removal: Edge = monthSwipeDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion),
            removal: .move(edge: removal)
        )
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 26)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                dragTranslation = horizontal
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 44, abs(horizontal) > abs(vertical) else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        dragTranslation = 0
                    }
                    return
                }

                monthSwipeDirection = horizontal < 0 ? 1 : -1
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    dragTranslation = 0
                    moveMonth(by: monthSwipeDirection)
                }
            }
    }

    private func markers(for date: String) -> [PlanCalendarMarker] {
        let dayEvents = eventsByDate[date] ?? []
        var markers: [PlanCalendarMarker] = []
        if dayEvents.contains(where: isMoneyIn) {
            markers.append(.moneyIn)
        }
        if dayEvents.contains(where: { !isMoneyIn($0) }) {
            markers.append(.moneyOut)
        }
        return markers
    }

    private func isMoneyIn(_ event: CalendarEvent) -> Bool {
        event.type == .payday
    }

    private func calendarEventLine(_ event: CalendarEvent) -> some View {
        MetricRow(
            label: "\(event.title) · \(calendarEventTypeLabel(event.type))",
            value: event.amountPence.map { MoneyParser.formatPence($0) } ?? event.detail,
            valueColor: isMoneyIn(event) ? AppTheme.Colors.success : AppTheme.Colors.warning
        )
    }

    private func calendarEventTypeLabel(_ type: CalendarEventType) -> String {
        switch type {
        case .payday: "Money in"
        case .recurring: "Bill"
        case .savedPayment: "Saved"
        case .spending: "Spend"
        case .cardPayment: "Card"
        case .debtDue: "Debt"
        case .debtReserve: "Reserve"
        case .debtPayment: "Debt paid"
        case .allocation: "Pot"
        }
    }

    private func dayTextColor(_ day: PlanCalendarDay) -> Color {
        guard let isoDate = day.isoDate else { return AppTheme.Colors.tertiaryText }
        if isoDate == selectedDate || day.isToday {
            return .white
        }
        return AppTheme.Colors.primaryText
    }

    private func dayBackground(_ day: PlanCalendarDay) -> AnyShapeStyle {
        guard let isoDate = day.isoDate else { return AnyShapeStyle(Color.clear) }
        if isoDate == selectedDate {
            return AnyShapeStyle(AppTheme.Gradients.primary)
        }
        if day.isToday {
            return AnyShapeStyle(AppTheme.Colors.primaryOrange.opacity(0.34))
        }
        return AnyShapeStyle(Color.clear)
    }
}

private enum PlanCalendarMarker: Hashable {
    case moneyIn
    case moneyOut
}

private struct PlanCalendarDay: Identifiable {
    var id: String
    var isoDate: String?
    var dayNumber: Int
    var isCurrentMonth: Bool
    var isToday: Bool
}

private struct PlanDayDetail: Identifiable {
    var id: String { date }
    var date: String
    var events: [CalendarEvent]
}

private struct PlanDayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var detail: PlanDayDetail

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    AppCard(glow: true) {
                        MetricRow(label: "Date", value: detail.date.formattedDayLabel)
                        MetricRow(label: "Money in", value: MoneyParser.formatPence(moneyIn), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Money out", value: MoneyParser.formatPence(moneyOut), valueColor: moneyOut > 0 ? AppTheme.Colors.warning : AppTheme.Colors.primaryText)
                        MetricRow(label: "Net change", value: MoneyParser.formatPence(moneyIn - moneyOut), valueColor: moneyIn - moneyOut < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    }

                    SectionTitle("Items")
                    ForEach(detail.events) { event in
                        AppCard {
                            MetricRow(label: event.title, value: event.amountPence.map { MoneyParser.formatPence($0) } ?? event.detail, valueColor: event.type == .payday ? AppTheme.Colors.success : AppTheme.Colors.warning)
                            MetricRow(label: "Type", value: event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, valueColor: AppTheme.Colors.secondaryText)
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var moneyIn: Int {
        detail.events.filter { $0.type == .payday }.compactMap(\.amountPence).reduce(0, +)
    }

    private var moneyOut: Int {
        detail.events.filter { $0.type != .payday }.compactMap(\.amountPence).reduce(0, +)
    }
}

enum ActivitySection: String, Equatable {
    case recentActivity
    case income
    case spending
}

struct ActivityLayoutPolicy {
    static let sections: [ActivitySection] = [
        .recentActivity,
        .income,
        .spending
    ]
}

struct ActivityView: View {
    @ObservedObject var store: PlannerStore
    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""

    var body: some View {
        ScreenScaffold(
            title: "Activity",
            subtitle: "Transactions, spending, income, and pay-period history.",
            navigationMode: .tabRoot,
            toolbarMode: .none
        ) {
            ForEach(ActivityLayoutPolicy.sections, id: \.rawValue) { section in
                activitySection(section)
            }
        }
    }

    @ViewBuilder
    private func activitySection(_ section: ActivitySection) -> some View {
        switch section {
        case .recentActivity:
            activityFeed
        case .income:
            activityRoute(.income)
        case .spending:
            activityRoute(.spending)
        }
    }

    private var activityControls: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Picker("Activity filter", selection: $filter) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                TextField("Search activity", text: $searchText)
                    .textFieldStyle(AppTextFieldStyle())
            }
        }
    }

    @ViewBuilder
    private func activityRoute(_ section: ActivitySection) -> some View {
        switch section {
        case .income:
            NavigationLink {
                IncomeBreakdownView(store: store)
            } label: {
                activityRouteCard(title: "Income", subtitle: "Paycheck inputs, pay periods, and money left.", symbol: "sterlingsign.circle")
            }
            .buttonStyle(.plain)
        case .spending:
            NavigationLink {
                PaydayView(store: store, navigationMode: .inline, toolbarMode: .actions([AppToolbarAction.edit()]))
            } label: {
                activityRouteCard(title: "Spending", subtitle: "Spent this period and spending by pay period.", symbol: "receipt")
            }
            .buttonStyle(.plain)
        case .recentActivity:
            EmptyView()
        }
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Recent activity")
            if shouldShowActivityControls {
                activityControls
            }
            if filteredEntries.isEmpty {
                AppCard {
                    EmptyStateView(title: "No matching activity", message: "Spending, paychecks, and pay periods will appear here.", systemImage: "list.bullet.rectangle")
                }
            } else {
                AppCard {
                    ForEach(filteredEntries.prefix(18)) { entry in
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: entry.symbol)
                                .foregroundStyle(entry.color)
                                .frame(width: 32, height: 32)
                                .background(entry.color.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(entry.detail)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }

                            Spacer()

                            Text(entry.amount)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(entry.color)
                        }

                        if entry.id != filteredEntries.prefix(18).last?.id {
                            AppDivider()
                        }
                    }
                }
            }
        }
    }

    private var filteredEntries: [ActivityEntry] {
        activityEntries
            .filter { entry in
                filter == .all || entry.kind == filter
            }
            .filter { entry in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return entry.title.localizedCaseInsensitiveContains(query) || entry.detail.localizedCaseInsensitiveContains(query)
            }
    }

    private var shouldShowActivityControls: Bool {
        activityEntries.count > 4 || filter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activityEntries: [ActivityEntry] {
        let spending = store.snapshot.transactions
            .filter { $0.type == .spending }
            .map { transaction in
                ActivityEntry(
                    id: transaction.id,
                    kind: .spending,
                    title: transaction.note.isEmpty ? "Spending" : transaction.note,
                    detail: "\(shortDate(transaction.date)) · \(transaction.paymentMethod == .creditCard ? "Credit card" : "Manual")",
                    amount: "-\(MoneyParser.formatPence(transaction.amountPence))",
                    symbol: transaction.paymentMethod == .creditCard ? "creditcard" : "receipt",
                    color: AppTheme.Colors.orangeHighlight,
                    sortDate: transaction.date
                )
            }

        let income = store.snapshot.paychecks.map { paycheck in
            ActivityEntry(
                id: paycheck.id,
                kind: .income,
                title: "Paycheck",
                detail: paycheck.createdAt.prefixDateLabel,
                amount: MoneyParser.formatPence(paycheck.actualAmountPence ?? paycheck.calculatedAmountPence),
                symbol: "sterlingsign.circle",
                color: AppTheme.Colors.success,
                sortDate: paycheck.createdAt.prefixDateLabel
            )
        }

        let periods = store.snapshot.payPeriods.map { period in
            ActivityEntry(
                id: "period-\(period.id)",
                kind: .income,
                title: "Pay period",
                detail: "\(shortDate(period.startDate)) to \(shortDate(period.endDate))",
                amount: MoneyParser.formatPence(period.incomePence),
                symbol: "calendar",
                color: AppTheme.Colors.primaryOrange,
                sortDate: period.startDate
            )
        }

        return (spending + income + periods).sorted { $0.sortDate > $1.sortDate }
    }

    private func activityRouteCard(title: String, subtitle: String, symbol: String) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }
}

private enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case spending
    case income

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .spending: "Spending"
        case .income: "Income"
        }
    }
}

private struct ActivityEntry: Identifiable {
    var id: String
    var kind: ActivityFilter
    var title: String
    var detail: String
    var amount: String
    var symbol: String
    var color: Color
    var sortDate: String
}

struct CreditView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "Credit",
            subtitle: "Cards, debts, and payments due.",
            navigationMode: .tabRoot,
            toolbarMode: .none
        ) {
            creditSummary
            paymentDueSummary
            creditRoutes
        }
    }

    private var creditSummary: some View {
        let cardOwed = store.activeCards.reduce(0) { total, card in
            total + PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot)
        }
        let debtSummary = FinanceEngine.getDebtSummary(
            debts: store.snapshot.debts,
            payments: store.snapshot.debtPayments,
            reserves: store.snapshot.debtReserves,
            pots: store.snapshot.pots,
            today: store.todayIso
        )
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
        let unpaidStatements = statements.reduce(0) { $0 + $1.unpaidAmountPence }

        return AppCard(glow: true) {
            MetricRow(label: "Total owed", value: MoneyParser.formatPence(cardOwed + debtSummary.totalCurrentBalancePence), valueColor: cardOwed + debtSummary.totalCurrentBalancePence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.primaryText)
            MetricRow(label: "Cards owed", value: MoneyParser.formatPence(cardOwed))
            MetricRow(label: "Debt balance", value: MoneyParser.formatPence(debtSummary.totalCurrentBalancePence))
            MetricRow(label: "Unpaid statements", value: MoneyParser.formatPence(unpaidStatements), valueColor: unpaidStatements > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
        }
    }

    private var paymentDueSummary: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Due soon")
            AppCard {
                if dueItems.isEmpty {
                    EmptyStateView(title: "Nothing due soon", message: "Card statements and debt payments will appear here when scheduled.", systemImage: "checkmark.circle")
                } else {
                    ForEach(dueItems.prefix(6)) { item in
                        MetricRow(label: "\(item.title) · \(shortDate(item.date))", value: MoneyParser.formatPence(item.amountPence), valueColor: item.isOverdue ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var creditRoutes: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(CreditRoute.allCases, id: \.rawValue) { route in
                creditRoute(route)
            }
        }
    }

    @ViewBuilder
    private func creditRoute(_ route: CreditRoute) -> some View {
        switch route {
        case .cards:
            NavigationLink {
                CardsView(store: store, navigationMode: .inline)
            } label: {
                creditRouteCard(route)
            }
            .buttonStyle(.plain)
        case .debts:
            NavigationLink {
                DebtsView(store: store)
            } label: {
                creditRouteCard(route)
            }
            .buttonStyle(.plain)
        }
    }

    private var dueItems: [CreditDueItem] {
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
            .filter { $0.status != .paid }
            .map {
                CreditDueItem(
                    id: "statement-\($0.id)",
                    title: "\($0.cardName) statement",
                    date: $0.directDebitDate,
                    amountPence: $0.unpaidAmountPence,
                    isOverdue: $0.status == .overdue
                )
            }

        let debts = PlannerDerivedData.debtScheduleItems(snapshot: store.snapshot, payPeriod: nil)
            .filter { $0.status != .paid && $0.status != .cancelled }
            .map { item in
                CreditDueItem(
                    id: "debt-\(item.id)",
                    title: store.snapshot.debts.first { debt in debt.id == item.debtId }?.name ?? "Debt payment",
                    date: item.dueDate,
                    amountPence: item.plannedAmountPence,
                    isOverdue: item.dueDate < store.todayIso
                )
            }

        return (statements + debts).sorted { $0.date < $1.date }
    }

    private func creditRouteCard(_ route: CreditRoute) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: route.symbol)
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(route.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(route.subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
    }
}

private struct CreditDueItem: Identifiable {
    var id: String
    var title: String
    var date: String
    var amountPence: Int
    var isOverdue: Bool
}

struct StatementsLayoutPolicy {
    static let toolbarActionId = "edit-toolbar-action"

    static func toolbarMode(editAction: @escaping () -> Void = {}) -> AppToolbarMode {
        .actions([AppToolbarAction.edit(action: editAction)])
    }
}

struct StatementsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = StatementsLayoutPolicy.toolbarMode()

    var body: some View {
        ScreenScaffold(
            title: "Credit Statements",
            subtitle: "Created card statements and direct debit status.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            let statements = PlannerDerivedData.creditCardStatementSummaries(
                snapshot: store.snapshot,
                asOfDate: store.todayIso
            )

            if statements.isEmpty {
                AppCard {
                    EmptyStateView(title: "No statements yet", message: "Statements appear after a card statement date has passed.", systemImage: "doc.text")
                }
            } else {
                ForEach(statements) { statement in
                    StatementSummaryCard(statement: statement)
                }
            }
        }
        .accessibilityIdentifier("statements-screen")
    }
}

private struct StatementSummaryCard: View {
    var statement: CreditCardStatementSummary

    var body: some View {
        AppCard(glow: statement.status == .overdue) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(statement.cardName) Statement")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text("Statement date: \(shortDate(statement.statementDate))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Text(statusLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(spacing: 8) {
                    MetricRow(label: "Amount", value: MoneyParser.formatPence(statement.statementAmountPence), valueColor: AppTheme.Colors.primaryOrange)
                    MetricRow(label: "Due date", value: shortDate(statement.directDebitDate))
                    if statement.paidAmountPence > 0 {
                        MetricRow(label: "Paid", value: MoneyParser.formatPence(statement.paidAmountPence), valueColor: AppTheme.Colors.success)
                    }
                    if statement.unpaidAmountPence > 0 {
                        MetricRow(label: "Unpaid", value: MoneyParser.formatPence(statement.unpaidAmountPence), valueColor: statement.status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }

                if !statement.transactions.isEmpty {
                    AppDivider()
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionTitle("Transactions")
                            .accessibilityIdentifier("statement-transactions-\(statement.cardId)-\(statement.statementDate)")
                        ForEach(statement.transactions) { transaction in
                            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                    Text("\(sourceLabel(transaction.source)) · \(shortDate(transaction.date))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                Spacer()
                                Text(MoneyParser.formatPence(transaction.amountPence))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("statement-card-\(statement.cardId)-\(statement.statementDate)")
    }

    private var statusLabel: String {
        switch statement.status {
        case .upcoming:
            return "Upcoming"
        case .paid:
            return "Paid"
        case .overdue:
            return "Overdue"
        }
    }

    private var statusColor: Color {
        switch statement.status {
        case .upcoming:
            return AppTheme.Colors.warning
        case .paid:
            return AppTheme.Colors.success
        case .overdue:
            return AppTheme.Colors.danger
        }
    }

    private func sourceLabel(_ source: CreditCardStatementTransactionSource) -> String {
        switch source {
        case .spending:
            return "Card spend"
        case .recurring:
            return "Bill"
        case .custom:
            return "Payment"
        }
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
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

struct DateSimulationCard: View {
    @ObservedObject var store: PlannerStore
    @State private var manualDate = Date()

    var body: some View {
        AppCard(glow: store.snapshot.settings.appDateMode == .manual) {
            SectionTitle("Date simulation")
            MetricRow(label: "Today", value: FinanceEngine.formatShortDateLabel(store.todayIso), valueColor: store.snapshot.settings.appDateMode == .manual ? AppTheme.Colors.primaryOrange : AppTheme.Colors.success)
            Picker("Date mode", selection: dateModeBinding) {
                ForEach(AppDateMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if store.snapshot.settings.appDateMode == .manual {
                DatePicker("Manual today", selection: manualDateBinding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(AppTheme.Colors.primaryOrange)
                    .foregroundStyle(AppTheme.Colors.primaryText)
            }
        }
        .onAppear {
            manualDate = store.snapshot.settings.manualTodayIso?.isoDate ?? store.todayIso.isoDate
        }
    }

    private var dateModeBinding: Binding<AppDateMode> {
        Binding {
            store.snapshot.settings.appDateMode
        } set: { mode in
            var settings = store.snapshot.settings
            settings.appDateMode = mode
            switch mode {
            case .automatic:
                settings.manualTodayIso = nil
            case .manual:
                let selectedDate = settings.manualTodayIso?.isoDate ?? manualDate
                manualDate = selectedDate
                settings.manualTodayIso = selectedDate.isoDateString
            }
            store.updateSettings(settings)
        }
    }

    private var manualDateBinding: Binding<Date> {
        Binding {
            manualDate
        } set: { selectedDate in
            manualDate = selectedDate
            var settings = store.snapshot.settings
            settings.appDateMode = .manual
            settings.manualTodayIso = selectedDate.isoDateString
            store.updateSettings(settings)
        }
    }
}
