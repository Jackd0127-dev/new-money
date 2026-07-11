import SwiftUI

private func shortDate(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
}

private let activityDisplayDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE, d MMM yyyy"
    return formatter
}()

private func activityDisplayDate(_ value: String) -> String {
    activityDisplayDateFormatter.string(from: FinanceEngine.parseDate(value.prefixDateLabel))
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

private let planDayToolbarMorphAnimation = Animation.spring(
    response: 0.28,
    dampingFraction: 0.86
)

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
    static let subtitle = ""
    static let dayDetailInitialLeadingAction = "close"
    static let dayDetailAdvancedLeadingAction = "previousDay"
    static let dayDetailTrailingAction = "nextDay"
    static let dayDetailUsesPlaceholderOptions = false
    static let dayDetailPreviousSymbol = "arrow.left"
    static let dayDetailNextSymbol = "arrow.right"
    static let dayDetailLeadingUsesLiquidGlassMorph = true
    static let dayDetailTrailingUsesAccentColor = true
    static let repeatedSelectedDayTapOpensDayDetail = true
    static let dayDetailShowsNavigationDivider = false
    static let dayDetailIncludesMoneyFlowGraph = true
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

enum CreditDetailPresentation: Equatable {
    case navigationPush
}

struct CreditLayoutPolicy {
    static let summaryPresentation: CreditDetailPresentation = .navigationPush
    static let summaryDetailUsesInlineTitle = true
    static let cardsPlacement = "belowSummaryAboveDueSoon"
    static let cardsPresentation = "lazyHStack"
    static let cardsUseCardsViewRow = false
    static let cardsUseFloatingPreview = true
    static let cardsShowOuterRowBox = false
    static let removesPhysicalCardStrip = true
    static let cardRowWidth: CGFloat = CreditCardVisualLayoutPolicy.rowCardMaxWidth
    static let cardRowCornerRadius: CGFloat = AppTheme.Radius.md
    static let cardRowsUseHorizontalScroll = true
}

struct PlanView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .tabRoot
    var toolbarMode: AppToolbarMode = .none

    var body: some View {
        ScreenScaffold(
            title: "Plan",
            subtitle: PlanLayoutPolicy.subtitle,
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
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
                    PlanSubtitleCard(
                        text: "\(occurrence.payment.name) is due \(shortDate(occurrence.dueDate)).",
                        trailingText: MoneyParser.formatPence(occurrence.amountPence)
                    )
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
    var trailingText: String?

    var body: some View {
        AppCard {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.md) {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingText {
                    Text(trailingText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.warning)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
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
                            handleDayTap(isoDate)
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
                            presentDayDetail(for: selectedDate)
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

    private func handleDayTap(_ isoDate: String) {
        if isoDate == selectedDate {
            presentDayDetail(for: isoDate)
            return
        }

        withAnimation(AppTheme.Animation.standard) {
            selectedDate = isoDate
        }
    }

    private func presentDayDetail(for isoDate: String) {
        selectedDayDetail = PlanDayDetail(date: isoDate, eventsByDate: eventsByDate)
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
            return AppTheme.Colors.controlText
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
    var eventsByDate: [String: [CalendarEvent]]
}

private struct PlanDayDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var detail: PlanDayDetail
    @State private var currentDate: String

    init(detail: PlanDayDetail) {
        self.detail = detail
        _currentDate = State(initialValue: detail.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    PlanDayDateHeader(date: currentDate)

                    AppCard(glow: true) {
                        MetricRow(label: "Money in", value: MoneyParser.formatPence(moneyIn), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Money out", value: MoneyParser.formatPence(moneyOut), valueColor: moneyOut > 0 ? AppTheme.Colors.warning : AppTheme.Colors.primaryText)
                        MetricRow(label: "Net change", value: MoneyParser.formatPence(moneyIn - moneyOut), valueColor: moneyIn - moneyOut < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    }

                    SectionTitle("Items")
                    if currentEvents.isEmpty {
                        AppCard {
                            Text(PlanLayoutPolicy.emptySelectedDayMessage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(currentEvents) { event in
                            AppCard {
                                MetricRow(label: event.title, value: event.amountPence.map { MoneyParser.formatPence($0) } ?? event.detail, valueColor: event.type == .payday ? AppTheme.Colors.success : AppTheme.Colors.warning)
                                MetricRow(label: "Type", value: event.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, valueColor: AppTheme.Colors.secondaryText)
                            }
                        }
                    }

                    PlanDayMoneyFlowCard(
                        events: currentEvents,
                        moneyIn: moneyIn,
                        moneyOut: moneyOut
                    )
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Day")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    PlanDayLeadingToolbarButton(
                        isInitialDate: currentDate == detail.date,
                        closeAction: { dismiss() },
                        previousAction: { moveDay(by: -1) }
                    )
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PlanDayTrailingToolbarButton {
                        moveDay(by: 1)
                    }
                }
            }
        }
    }

    private var currentEvents: [CalendarEvent] {
        detail.eventsByDate[currentDate] ?? []
    }

    private var moneyIn: Int {
        currentEvents.filter { $0.type == .payday }.compactMap(\.amountPence).reduce(0, +)
    }

    private var moneyOut: Int {
        currentEvents.filter { $0.type != .payday }.compactMap(\.amountPence).reduce(0, +)
    }

    private func moveDay(by value: Int) {
        withAnimation(planDayToolbarMorphAnimation) {
            currentDate = FinanceEngine.addIsoDays(date: currentDate, days: value)
        }
    }
}

private struct PlanDayMoneyFlowCard: View {
    var events: [CalendarEvent]
    var moneyIn: Int
    var moneyOut: Int
    @State private var drawProgress = 0.0

    private var points: [PlanDayMoneyFlowPoint] {
        var inTotal = 0
        var outTotal = 0
        var values = [PlanDayMoneyFlowPoint(index: 0, moneyInPence: 0, moneyOutPence: 0)]

        for (index, event) in events.enumerated() {
            let amount = event.amountPence ?? 0
            if event.type == .payday {
                inTotal += amount
            } else {
                outTotal += amount
            }
            values.append(PlanDayMoneyFlowPoint(index: index + 1, moneyInPence: inTotal, moneyOutPence: outTotal))
        }

        if values.count == 1 {
            values.append(PlanDayMoneyFlowPoint(index: 1, moneyInPence: 0, moneyOutPence: 0))
        }

        return values
    }

    private var maxPence: Int {
        max(points.map { max($0.moneyInPence, $0.moneyOutPence) }.max() ?? 0, 1)
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle("Money flow")
                        Text(events.isEmpty ? "No movement recorded for this day." : "In and out across this day.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        graphGrid

                        PlanDayMoneyFlowLineShape(points: points, series: .moneyOut, maxPence: maxPence)
                            .trim(from: 0, to: drawProgress)
                            .stroke(
                                AppTheme.Colors.neonMoneyDown,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: AppTheme.Colors.neonMoneyDown.opacity(moneyOut > 0 ? 0.38 : 0), radius: 10, y: 5)

                        PlanDayMoneyFlowLineShape(points: points, series: .moneyIn, maxPence: maxPence)
                            .trim(from: 0, to: drawProgress)
                            .stroke(
                                AppTheme.Colors.neonMoneyUp,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                            )
                            .shadow(color: AppTheme.Colors.neonMoneyUp.opacity(moneyIn > 0 ? 0.38 : 0), radius: 10, y: 5)

                        if let finalPoint = points.last {
                            PlanDayMoneyFlowMarker(
                                point: finalPoint,
                                series: .moneyIn,
                                pointCount: points.count,
                                maxPence: maxPence,
                                size: proxy.size,
                                color: AppTheme.Colors.neonMoneyUp
                            )
                            .opacity(moneyIn > 0 ? drawProgress : 0)

                            PlanDayMoneyFlowMarker(
                                point: finalPoint,
                                series: .moneyOut,
                                pointCount: points.count,
                                maxPence: maxPence,
                                size: proxy.size,
                                color: AppTheme.Colors.neonMoneyDown
                            )
                            .opacity(moneyOut > 0 ? drawProgress : 0)
                        }
                    }
                }
                .frame(height: 118)
                .onAppear(perform: startAnimation)
                .onChange(of: events.map(\.id)) { _, _ in
                    startAnimation()
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    PlanDayMoneyFlowPill(title: "Money in", value: MoneyParser.formatPence(moneyIn), color: AppTheme.Colors.neonMoneyUp)
                    PlanDayMoneyFlowPill(title: "Money out", value: MoneyParser.formatPence(moneyOut), color: AppTheme.Colors.neonMoneyDown)
                }
            }
        }
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                AppTheme.Colors.border.opacity(0.3)
                    .frame(height: 1)
                Spacer()
            }
            AppTheme.Colors.border.opacity(0.42)
                .frame(height: 1)
        }
        .padding(.bottom, 6)
    }

    private func startAnimation() {
        drawProgress = 0
        withAnimation(.easeOut(duration: 0.9)) {
            drawProgress = 1
        }
    }
}

private struct PlanDayMoneyFlowPoint: Equatable {
    var index: Int
    var moneyInPence: Int
    var moneyOutPence: Int
}

private enum PlanDayMoneyFlowSeries {
    case moneyIn
    case moneyOut

    func value(for point: PlanDayMoneyFlowPoint) -> Int {
        switch self {
        case .moneyIn:
            point.moneyInPence
        case .moneyOut:
            point.moneyOutPence
        }
    }
}

private struct PlanDayMoneyFlowLineShape: Shape {
    var points: [PlanDayMoneyFlowPoint]
    var series: PlanDayMoneyFlowSeries
    var maxPence: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(index: index, point: point, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        return path
    }

    private func pointPosition(index: Int, point: PlanDayMoneyFlowPoint, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 12, 1)
        let x = rect.minX + CGFloat(index) / CGFloat(max(points.count - 1, 1)) * rect.width
        let normalized = CGFloat(series.value(for: point)) / CGFloat(max(maxPence, 1))
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct PlanDayMoneyFlowMarker: View {
    var point: PlanDayMoneyFlowPoint
    var series: PlanDayMoneyFlowSeries
    var pointCount: Int
    var maxPence: Int
    var size: CGSize
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(AppTheme.Colors.primaryText.opacity(0.68), lineWidth: 1.5))
            .shadow(color: color.opacity(0.64), radius: 8, y: 4)
            .position(position)
    }

    private var position: CGPoint {
        let drawingHeight = max(size.height - 12, 1)
        let x = CGFloat(max(pointCount - 1, 0)) / CGFloat(max(pointCount - 1, 1)) * max(size.width, 1)
        let normalized = CGFloat(series.value(for: point)) / CGFloat(max(maxPence, 1))
        let y = drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(8, min(drawingHeight, y)))
    }
}

private struct PlanDayMoneyFlowPill: View {
    var title: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct PlanDayDateHeader: View {
    var date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected day")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.cardEyebrow)
                .textCase(.uppercase)
            Text(date.formattedDayLabel)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Spacing.sm)
    }
}

private struct PlanDayLeadingToolbarButton: View {
    var isInitialDate: Bool
    var closeAction: () -> Void
    var previousAction: () -> Void

    var body: some View {
        if isInitialDate {
            Button("Close", action: closeAction)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .accessibilityLabel("Close")
        } else {
            Button(action: previousAction) {
                Image(systemName: PlanLayoutPolicy.dayDetailPreviousSymbol)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(AppTheme.Colors.accent)
            .accessibilityLabel("Previous day")
        }
    }
}

private struct PlanDayTrailingToolbarButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: PlanLayoutPolicy.dayDetailNextSymbol)
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(AppTheme.Colors.accent)
        .accessibilityLabel("Next day")
    }
}

enum ActivitySection: String, Equatable {
    case recentActivity
    case monthBalance
    case income
    case spending
}

enum ActivityDetailPresentation: Equatable {
    case navigationPush
}

struct ActivityLayoutPolicy {
    static let sections: [ActivitySection] = [
        .recentActivity,
        .monthBalance,
        .income,
        .spending
    ]
    static let recentActivityMarkerStyle = "coloredDot"
    static let recentActivityDateFormat = "EEE, d MMM yyyy"
    static let recentActivityDetailPresentation: ActivityDetailPresentation = .navigationPush
    static let recentActivityDetailUsesInlineTitle = true
    static let recentActivityShowsGeneratedPayPeriodSummaries = false
    static let recentActivityShowsGeneratedAutomaticPaychecks = false
    static let recentActivityShowsZeroValuePaychecks = false
    static let paycheckActivityDateSource = "payday"
    static let monthBalanceChartMetric = "currentMonthIncomeMinusSpending"
    static let monthBalanceDetailPresentation: ActivityDetailPresentation = .navigationPush
    static let monthBalanceDetailUsesInlineTitle = true
    static let showsDetailRecordId = false
    static let incomeDetailToolbarMode = "editDone"
    static let spendingDetailToolbarMode = "editDone"
    static let incomeDetailUsesNativeToolbarMorph = true
    static let spendingDetailUsesNativeToolbarMorph = true

    static func paycheckActivityDate(paycheck: Paycheck, payPeriod: PayPeriod?) -> String {
        payPeriod?.payday ?? paycheck.createdAt.prefixDateLabel
    }
}

enum ActivityTimelineLayoutPolicy {
    static let toolbarActionId = "activity-infinity-toolbar-action"
    static let toolbarSymbol = "infinity"
    static let presentation = "placeholder"
    static let isPlaceholderOnly = true
    static let opensTimeline = false
    static let branchStyle = "slowVariableStoryWalkthrough"
    static let autoScrollsWhileRevealing = true
    static let includesAccountCreation = true
    static let usesVariableNaturalBranches = true
    static let revealsCardBeforeDrawingNextBranch = true
    static let scrollFollowMode = "branchMidpointThenEventCard"
    static let scrollsToBranchBeforeNextCard = true
    static let scrollUsesCardFocusAnchors = true
    static let eventSources = [
        "account",
        "income",
        "spending",
        "bills",
        "billGroups",
        "pots",
        "cards",
        "cardRepayments",
        "debts",
        "debtPayments",
        "debtReserves",
        "customPayments",
        "dailyBriefs"
    ]
    static let branchRevealDelaySeconds = 0.95
    static let cardRevealDurationSeconds = 0.72
    static let cardReadDelaySeconds = 0.72
    static let branchDrawDurationSeconds = 1.08
    static let branchSettleDelaySeconds = 0.24
    static let autoScrollDurationSeconds = 0.82
}

enum ActivityTimelineLane: String, CaseIterable {
    case right
    case left
    case center
    case innerRight
    case innerLeft
}

struct ActivityTimelineEventLayout {
    var index: Int
    var lane: ActivityTimelineLane
    var cardLeading: CGFloat
    var cardTop: CGFloat
    var cardWidth: CGFloat
    var anchorPoint: CGPoint
}

enum ActivityTimelineBranchLayoutPolicy {
    static let lanePattern: [ActivityTimelineLane] = [.right, .left, .center, .innerRight, .innerLeft, .center]
    static let connectorEndpointPolicy = "eventAnchorToEventAnchor"
    static let avoidsFixedLeftRail = true
    static let nodeOverlapsEventCard = true
    static let nodeAnchorPolicy = "cardEdgeOverlap"
    static let nodeRevealFollowsCardOffset = true
    static let branchFocusUsesConnectorMidpoint = true
    static let rowHeight: CGFloat = 258
    static let cardTopInset: CGFloat = 34
    static let minimumCardWidth: CGFloat = 238
    static let maximumCardWidth: CGFloat = 314
    static let preferredCardWidthFraction: CGFloat = 0.72
    static let bottomPadding: CGFloat = 84

    static func lane(for index: Int) -> ActivityTimelineLane {
        lanePattern[abs(index % lanePattern.count)]
    }

    static func totalHeight(eventCount: Int) -> CGFloat {
        guard eventCount > 0 else { return 0 }
        return CGFloat(eventCount) * rowHeight + bottomPadding
    }

    static func layout(for index: Int, containerWidth: CGFloat) -> ActivityTimelineEventLayout {
        let lane = lane(for: index)
        let width = max(1, containerWidth)
        let cardWidth = min(maximumCardWidth, min(width, max(minimumCardWidth, width * preferredCardWidthFraction)))
        let maxLeading = max(0, width - cardWidth)
        let verticalNudge = verticalOffset(for: index)
        let cardTop = CGFloat(index) * rowHeight + cardTopInset + verticalNudge
        let cardLeading: CGFloat

        switch lane {
        case .left:
            cardLeading = 0
        case .innerLeft:
            cardLeading = maxLeading * 0.22
        case .center:
            cardLeading = maxLeading * 0.5
        case .innerRight:
            cardLeading = maxLeading * 0.78
        case .right:
            cardLeading = maxLeading
        }

        let anchorPoint = CGPoint(
            x: anchorX(for: lane, cardLeading: cardLeading, cardWidth: cardWidth, index: index),
            y: cardTop + 42
        )

        return ActivityTimelineEventLayout(
            index: index,
            lane: lane,
            cardLeading: cardLeading,
            cardTop: cardTop,
            cardWidth: cardWidth,
            anchorPoint: anchorPoint
        )
    }

    static func cardFocusPoint(for layout: ActivityTimelineEventLayout) -> CGPoint {
        CGPoint(
            x: layout.cardLeading + layout.cardWidth / 2,
            y: layout.cardTop + 96
        )
    }

    static func branchFocusPoint(from start: CGPoint, to end: CGPoint) -> CGPoint {
        CGPoint(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2
        )
    }

    private static func verticalOffset(for index: Int) -> CGFloat {
        [0, 18, 4, 24, 10, 28][abs(index % 6)]
    }

    private static func anchorX(for lane: ActivityTimelineLane, cardLeading: CGFloat, cardWidth: CGFloat, index: Int) -> CGFloat {
        let edgeInset: CGFloat = 14
        switch lane {
        case .right:
            return cardLeading + edgeInset
        case .left:
            return cardLeading + cardWidth - edgeInset
        case .center:
            return cardLeading + (index.isMultiple(of: 2) ? edgeInset : cardWidth - edgeInset)
        case .innerRight:
            return cardLeading + edgeInset
        case .innerLeft:
            return cardLeading + cardWidth - edgeInset
        }
    }
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
        case .monthBalance:
            activityMonthBalance
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
                ActivitySpendingDetailView(store: store)
            } label: {
                activityRouteCard(title: "Spending", subtitle: "Spent this period and spending by pay period.", symbol: "receipt")
            }
            .buttonStyle(.plain)
        case .recentActivity, .monthBalance:
            EmptyView()
        }
    }

    @ViewBuilder
    private var activityMonthBalance: some View {
        let data = ActivityMonthlyBalanceChartData.make(
            snapshot: store.snapshot,
            todayIso: store.todayIso
        )

        NavigationLink {
            ActivityMonthlyBalanceDetailView(data: data)
        } label: {
            ActivityMonthlyBalanceCard(data: data)
        }
        .buttonStyle(.plain)
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
                    let visibleEntries = Array(filteredEntries.prefix(18))
                    ForEach(Array(visibleEntries.enumerated()), id: \.offset) { index, entry in
                        NavigationLink {
                            ActivityEntryDetailView(entry: entry)
                        } label: {
                            ActivityEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        if index < visibleEntries.count - 1 {
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
        let potsById = store.snapshot.pots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }
        let cardsById = store.snapshot.creditCards.reduce(into: [String: CreditCard]()) { result, card in
            result[card.id] = card
        }
        let recurringById = store.snapshot.recurringPayments.reduce(into: [String: RecurringPayment]()) { result, payment in
            result[payment.id] = payment
        }
        let periodsById = store.snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in
            result[period.id] = period
        }

        let spending = store.snapshot.transactions
            .filter { $0.type == .spending }
            .map { transaction in
                let amount = "-\(MoneyParser.formatPence(transaction.amountPence))"
                let date = activityDisplayDate(transaction.date)
                var detailRows = [
                    ActivityDetailRow(label: "Amount", value: amount, valueColor: AppTheme.Colors.orangeHighlight),
                    ActivityDetailRow(label: "Date", value: date),
                    ActivityDetailRow(label: "Type", value: formattedActivityLabel(transaction.type.rawValue)),
                    ActivityDetailRow(label: "Payment method", value: activityPaymentMethodLabel(transaction.paymentMethod))
                ]

                if let potId = transaction.potId {
                    detailRows.append(ActivityDetailRow(label: "Pot", value: potsById[potId]?.name ?? potId))
                }
                if let creditCardId = transaction.creditCardId {
                    detailRows.append(ActivityDetailRow(label: "Credit card", value: cardsById[creditCardId]?.name ?? creditCardId))
                }
                if let recurringPaymentId = transaction.recurringPaymentId {
                    detailRows.append(ActivityDetailRow(label: "Linked bill", value: recurringById[recurringPaymentId]?.name ?? recurringPaymentId))
                }
                if let payPeriodId = transaction.payPeriodId, let period = periodsById[payPeriodId] {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                } else if let payPeriodId = transaction.payPeriodId {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: payPeriodId))
                }
                if !transaction.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailRows.append(ActivityDetailRow(label: "Note", value: transaction.note))
                }

                return ActivityEntry(
                    id: transaction.id,
                    kind: .spending,
                    title: transaction.note.isEmpty ? "Spending" : transaction.note,
                    detail: "\(date) · \(transaction.paymentMethod == .creditCard ? "Credit card" : "Manual")",
                    amount: amount,
                    typeLabel: "Spending",
                    color: AppTheme.Colors.orangeHighlight,
                    sortDate: transaction.date,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: transaction.createdAt, updatedAt: transaction.updatedAt)
                )
            }

        let income = store.snapshot.paychecks
            .filter { $0.deletedAt == nil }
            .filter { ActivityLayoutPolicy.recentActivityShowsGeneratedAutomaticPaychecks || !$0.id.hasPrefix("paycheck-pay-period-") }
            .filter { ActivityLayoutPolicy.recentActivityShowsZeroValuePaychecks || paycheckActivityAmount($0) > 0 }
            .map { paycheck in
                let period = periodsById[paycheck.payPeriodId]
                let activityDate = ActivityLayoutPolicy.paycheckActivityDate(paycheck: paycheck, payPeriod: period)
                let amountPence = paycheckActivityAmount(paycheck)
                var detailRows = [
                    ActivityDetailRow(label: "Amount", value: MoneyParser.formatPence(amountPence), valueColor: AppTheme.Colors.success),
                    ActivityDetailRow(label: "Recorded", value: activityDisplayDate(paycheck.createdAt)),
                    ActivityDetailRow(label: "Hours worked", value: String(format: "%.2f", paycheck.hoursWorked)),
                    ActivityDetailRow(label: "Hourly rate", value: MoneyParser.formatPence(paycheck.hourlyRatePence)),
                    ActivityDetailRow(label: "Calculated pay", value: MoneyParser.formatPence(paycheck.calculatedAmountPence))
                ]

                if let actualAmountPence = paycheck.actualAmountPence {
                    detailRows.append(ActivityDetailRow(label: "Actual pay", value: MoneyParser.formatPence(actualAmountPence), valueColor: AppTheme.Colors.success))
                }
                if let period {
                    detailRows.append(ActivityDetailRow(label: "Payday", value: activityDisplayDate(period.payday)))
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                    detailRows.append(ActivityDetailRow(label: "Status", value: formattedActivityLabel(period.status.rawValue)))
                }

                return ActivityEntry(
                    id: paycheck.id,
                    kind: .income,
                    title: "Paycheck",
                    detail: activityDisplayDate(activityDate),
                    amount: MoneyParser.formatPence(amountPence),
                    typeLabel: "Income",
                    color: AppTheme.Colors.success,
                    sortDate: activityDate,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: paycheck.createdAt, updatedAt: paycheck.updatedAt)
                )
            }

        let oneOffIncome = store.snapshot.oneOffIncomes
            .filter { $0.deletedAt == nil }
            .map { income in
                var detailRows = [
                    ActivityDetailRow(label: "Amount", value: MoneyParser.formatPence(income.amountPence), valueColor: AppTheme.Colors.success),
                    ActivityDetailRow(label: "Date", value: activityDisplayDate(income.date)),
                    ActivityDetailRow(label: "Type", value: "One-off income")
                ]

                if let payPeriodId = income.payPeriodId, let period = periodsById[payPeriodId] {
                    detailRows.append(ActivityDetailRow(label: "Pay period", value: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))"))
                }
                if !income.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailRows.append(ActivityDetailRow(label: "Note", value: income.note))
                }

                return ActivityEntry(
                    id: income.id,
                    kind: .income,
                    title: income.name,
                    detail: activityDisplayDate(income.date),
                    amount: MoneyParser.formatPence(income.amountPence),
                    typeLabel: "One-off",
                    color: AppTheme.Colors.success,
                    sortDate: income.date,
                    detailRows: detailRows,
                    recordRows: activityRecordRows(createdAt: income.createdAt, updatedAt: income.updatedAt)
                )
            }

        return (spending + income + oneOffIncome + payPeriodSummaryEntries()).sorted { $0.sortDate > $1.sortDate }
    }

    private func payPeriodSummaryEntries() -> [ActivityEntry] {
        guard ActivityLayoutPolicy.recentActivityShowsGeneratedPayPeriodSummaries else { return [] }

        return store.snapshot.payPeriods.map { period in
            var detailRows = [
                ActivityDetailRow(label: "Income", value: MoneyParser.formatPence(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: store.snapshot, payPeriod: period)), valueColor: AppTheme.Colors.success),
                ActivityDetailRow(label: "Start", value: activityDisplayDate(period.startDate)),
                ActivityDetailRow(label: "End", value: activityDisplayDate(period.endDate)),
                ActivityDetailRow(label: "Payday", value: activityDisplayDate(period.payday)),
                ActivityDetailRow(label: "Next payday", value: activityDisplayDate(period.nextPayday)),
                ActivityDetailRow(label: "Status", value: formattedActivityLabel(period.status.rawValue))
            ]
            if let payFrequency = period.payFrequency {
                detailRows.append(ActivityDetailRow(label: "Frequency", value: formattedActivityLabel(payFrequency.rawValue)))
            }

            return ActivityEntry(
                id: "period-\(period.id)",
                kind: .income,
                title: "Pay period",
                detail: "\(activityDisplayDate(period.startDate)) to \(activityDisplayDate(period.endDate))",
                amount: MoneyParser.formatPence(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: store.snapshot, payPeriod: period)),
                typeLabel: "Pay period",
                color: AppTheme.Colors.primaryOrange,
                sortDate: period.startDate,
                detailRows: detailRows,
                recordRows: activityRecordRows(createdAt: period.createdAt, updatedAt: period.updatedAt)
            )
        }
    }

    private func paycheckActivityAmount(_ paycheck: Paycheck) -> Int {
        paycheck.actualAmountPence ?? paycheck.calculatedAmountPence
    }

    private func activityRecordRows(createdAt: String, updatedAt: String) -> [ActivityDetailRow] {
        [
            ActivityDetailRow(label: "Created", value: activityDisplayDate(createdAt)),
            ActivityDetailRow(label: "Updated", value: activityDisplayDate(updatedAt))
        ]
    }

    private func activityPaymentMethodLabel(_ method: PaymentMethod?) -> String {
        switch method {
        case .creditCard:
            "Credit card"
        case .pot:
            "Pot"
        case nil:
            "Manual"
        }
    }

    private func formattedActivityLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
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

struct ActivityAccountTimelineView: View {
    @ObservedObject var store: PlannerStore
    @State private var storyProgress = 0.0

    private var account: PlannerAccount? {
        store.activePlannerAccount
            ?? store.plannerAccounts.first { $0.id == store.activePlannerAccountId }
            ?? store.plannerAccounts.first
    }

    private var events: [ActivityTimelineEvent] {
        ActivityTimelineData.make(
            snapshot: store.snapshot,
            account: account,
            todayIso: store.todayIso
        )
    }

    private var timelineIdentity: String {
        "\(events.count)-\(events.first?.id ?? "empty")-\(events.last?.id ?? "empty")"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    timelineHero

                    if events.isEmpty {
                        AppCard {
                            EmptyStateView(
                                title: "Nothing to walk through yet",
                                message: "Your account timeline will build as you add spending, income, bills, pots, cards, and debts.",
                                systemImage: "point.3.connected.trianglepath.dotted"
                            )
                        }
                    } else {
                        timelineRows
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .padding(.bottom, 110)
            }
            .premiumScreenBackground()
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task(id: timelineIdentity) {
                await animateTimeline(proxy: proxy)
            }
        }
    }

    private var timelineHero: some View {
        AppCard(glow: true) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Gradients.primary)
                    Image(systemName: "infinity")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.controlText)
                }
                .frame(width: 58, height: 58)
                .shadow(color: AppTheme.Colors.accentGlow, radius: 18, y: 8)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(account?.name ?? "Account")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(heroSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AppTheme.Spacing.sm) {
                        Pill(text: "\(events.count) events", systemImage: "sparkles", color: AppTheme.Colors.primaryOrange)
                        Pill(text: "\(revealedCount)/\(events.count)", systemImage: "play.fill", color: AppTheme.Colors.success)
                    }

                    ProgressView(value: events.isEmpty ? 0 : min(storyProgress, maxStoryProgress) / maxStoryProgress)
                        .tint(AppTheme.Colors.primaryOrange)
                        .background(AppTheme.Colors.divider)
                }
            }
        }
    }

    private var heroSubtitle: String {
        guard let first = events.first, let last = events.last else {
            return "A living walkthrough of everything that has happened in this account."
        }

        return "\(timelineDateLabel(first.sortKey)) to \(timelineDateLabel(last.sortKey))"
    }

    private var timelineRows: some View {
        ActivityTimelineCanvas(
            events: events,
            activeCardIndex: activeCardIndex,
            cardProgress: { phaseProgress(index: $0, phase: 0) },
            branchProgress: { phaseProgress(index: $0, phase: 1) }
        )
    }

    @MainActor
    private func animateTimeline(proxy: ScrollViewProxy) async {
        storyProgress = 0
        guard !events.isEmpty else { return }

        for index in events.indices {
            if Task.isCancelled { return }

            await sleep(seconds: index == 0 ? 0.24 : ActivityTimelineLayoutPolicy.branchRevealDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.spring(response: ActivityTimelineLayoutPolicy.cardRevealDurationSeconds, dampingFraction: 0.88)) {
                storyProgress = Double(index * 2 + 1)
            }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.autoScrollDurationSeconds)) {
                proxy.scrollTo(events[index].cardScrollID, anchor: .center)
            }

            guard index < events.count - 1 else { continue }

            await sleep(seconds: ActivityTimelineLayoutPolicy.cardReadDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.branchDrawDurationSeconds)) {
                storyProgress = Double(index * 2 + 2)
                proxy.scrollTo(events[index].branchScrollID, anchor: .center)
            }

            await sleep(seconds: ActivityTimelineLayoutPolicy.branchSettleDelaySeconds)

            if Task.isCancelled { return }

            withAnimation(.easeInOut(duration: ActivityTimelineLayoutPolicy.autoScrollDurationSeconds * 0.72)) {
                proxy.scrollTo(events[index + 1].cardScrollID, anchor: .center)
            }
        }
    }

    private var maxStoryProgress: Double {
        max(1, Double(events.count * 2 - 1))
    }

    private var revealedCount: Int {
        min(events.count, max(0, Int((storyProgress + 1) / 2)))
    }

    private var activeCardIndex: Int {
        guard !events.isEmpty else { return 0 }
        return min(events.count - 1, max(0, Int((storyProgress - 1) / 2)))
    }

    private func phaseProgress(index: Int, phase: Int) -> Double {
        min(1, max(0, storyProgress - Double(index * 2 + phase)))
    }

    private func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

private struct ActivityTimelineCanvas: View {
    var events: [ActivityTimelineEvent]
    var activeCardIndex: Int
    var cardProgress: (Int) -> Double
    var branchProgress: (Int) -> Double

    var body: some View {
        GeometryReader { proxy in
            let layouts = events.indices.map {
                ActivityTimelineBranchLayoutPolicy.layout(for: $0, containerWidth: proxy.size.width)
            }
            let totalHeight = ActivityTimelineBranchLayoutPolicy.totalHeight(eventCount: events.count)

            ZStack(alignment: .topLeading) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(ActivityTimelineBranchLayoutPolicy.cardFocusPoint(for: layouts[index]))
                        .id(event.cardScrollID)
                        .accessibilityHidden(true)
                }

                ForEach(Array(events.indices.dropLast()), id: \.self) { index in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(
                            ActivityTimelineBranchLayoutPolicy.branchFocusPoint(
                                from: layouts[index].anchorPoint,
                                to: layouts[index + 1].anchorPoint
                            )
                        )
                        .id(events[index].branchScrollID)
                        .accessibilityHidden(true)
                }

                ForEach(Array(events.indices.dropLast()), id: \.self) { index in
                    ActivityTimelineBranchConnector(
                        start: layouts[index].anchorPoint,
                        end: layouts[index + 1].anchorPoint,
                        variant: index
                    )
                    .trim(from: 0, to: CGFloat(branchProgress(index)))
                    .stroke(
                        events[index].color.opacity(index == activeCardIndex ? 0.95 : 0.66),
                        style: StrokeStyle(lineWidth: index == activeCardIndex ? 2.9 : 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: events[index].color.opacity(index == activeCardIndex ? 0.34 : 0.16), radius: index == activeCardIndex ? 12 : 6)
                    .frame(width: proxy.size.width, height: totalHeight, alignment: .topLeading)
                    .allowsHitTesting(false)
                }

                ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                    let layout = layouts[index]
                    let progress = cardProgress(index)
                    let revealOffset = cardRevealOffset(for: layout, progress: progress, containerWidth: proxy.size.width)

                    ActivityTimelineEventCard(event: event, isActive: index == activeCardIndex)
                        .frame(width: layout.cardWidth, alignment: .topLeading)
                        .offset(x: layout.cardLeading + revealOffset, y: layout.cardTop)
                        .opacity(progress)
                        .scaleEffect(CGFloat(0.93 + (0.07 * progress)), anchor: cardScaleAnchor(for: layout.lane))
                        .zIndex(2)

                    ActivityTimelineNode(event: event, isActive: index == activeCardIndex, isRevealed: progress > 0.08)
                        .frame(width: 44, height: 44)
                        .position(x: layout.anchorPoint.x + revealOffset, y: layout.anchorPoint.y)
                        .opacity(progress > 0 ? 1 : 0.25)
                        .zIndex(3)
                }
            }
            .frame(width: proxy.size.width, height: totalHeight, alignment: .topLeading)
        }
        .frame(height: ActivityTimelineBranchLayoutPolicy.totalHeight(eventCount: events.count))
    }

    private func cardRevealOffset(for layout: ActivityTimelineEventLayout, progress: Double, containerWidth: CGFloat) -> CGFloat {
        guard progress < 1 else { return 0 }
        let centerX = layout.cardLeading + layout.cardWidth / 2
        let direction: CGFloat = centerX > containerWidth / 2 ? 1 : -1
        return direction * CGFloat(1 - progress) * 28
    }

    private func cardScaleAnchor(for lane: ActivityTimelineLane) -> UnitPoint {
        switch lane {
        case .left, .innerLeft:
            .trailing
        case .right, .innerRight:
            .leading
        case .center:
            .center
        }
    }
}

private struct ActivityTimelineNode: View {
    var event: ActivityTimelineEvent
    var isActive: Bool
    var isRevealed: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(event.color.opacity(isActive ? 0.24 : 0.14))
                .frame(width: isActive ? 44 : 36, height: isActive ? 44 : 36)
                .blur(radius: isActive ? 1 : 0)

            Circle()
                .fill(AppTheme.Colors.elevatedSurface)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(event.color.opacity(isActive ? 0.95 : 0.58), lineWidth: isActive ? 2 : 1)
                )

            Image(systemName: event.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(event.color)
        }
        .opacity(isRevealed ? 1 : 0.25)
        .scaleEffect(isRevealed ? 1 : 0.74)
        .shadow(color: isActive ? event.color.opacity(0.46) : .clear, radius: 16, y: 4)
    }
}

private struct ActivityTimelineBranchConnector: Shape {
    var start: CGPoint
    var end: CGPoint
    var variant: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let controls = branchControls(in: rect)

        path.move(to: start)
        path.addCurve(
            to: end,
            control1: controls.first,
            control2: controls.second
        )
        return path
    }

    private func branchControls(in rect: CGRect) -> (first: CGPoint, second: CGPoint) {
        let deltaX = end.x - start.x
        let deltaY = max(1, end.y - start.y)
        let profile = branchProfile
        let direction: CGFloat = deltaX >= 0 ? 1 : -1
        let wave = min(max(abs(deltaX) * 0.42 + profile.wave, 28), 112) * direction
        let firstX = clamp(start.x + deltaX * profile.firstX + wave, min: rect.minX + 20, max: rect.maxX - 20)
        let secondX = clamp(end.x - deltaX * profile.secondX - wave * profile.returnStrength, min: rect.minX + 20, max: rect.maxX - 20)

        return (
            CGPoint(x: firstX, y: start.y + deltaY * profile.firstY),
            CGPoint(x: secondX, y: start.y + deltaY * profile.secondY)
        )
    }

    private var branchProfile: (firstX: CGFloat, firstY: CGFloat, secondX: CGFloat, secondY: CGFloat, wave: CGFloat, returnStrength: CGFloat) {
        switch abs(variant % 6) {
        case 0:
            return (0.12, 0.24, 0.16, 0.72, 38, 0.52)
        case 1:
            return (0.22, 0.18, 0.22, 0.76, 58, 0.72)
        case 2:
            return (0.14, 0.34, 0.12, 0.64, 30, 0.48)
        case 3:
            return (0.30, 0.22, 0.18, 0.82, 68, 0.58)
        case 4:
            return (0.18, 0.28, 0.28, 0.70, 44, 0.66)
        default:
            return (0.26, 0.16, 0.16, 0.78, 52, 0.44)
        }
    }

    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

private struct ActivityTimelineEventCard: View {
    var event: ActivityTimelineEvent
    var isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.dateLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(event.color)
                    Text(event.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                if let amountLabel = event.amountLabel {
                    Text(amountLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(event.amountColor)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 7)
                        .background(event.amountColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(event.detail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: AppTheme.Spacing.sm) {
                Text(event.typeLabel.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(event.color)
                    .padding(.horizontal, AppTheme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(event.color.opacity(0.12))
                    .clipShape(Capsule())

                if let secondaryLabel = event.secondaryLabel {
                    Text(secondaryLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.elevatedSurface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Gradients.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(isActive ? event.color.opacity(0.62) : AppTheme.Colors.border, lineWidth: isActive ? 1.4 : 1)
        )
        .shadow(color: isActive ? event.color.opacity(0.20) : AppTheme.Colors.shadow, radius: isActive ? 18 : 10, y: isActive ? 8 : 4)
    }
}

private enum ActivityTimelineData {
    static func make(snapshot: PlannerSnapshot, account: PlannerAccount?, todayIso: String) -> [ActivityTimelineEvent] {
        let potsById = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in result[pot.id] = pot }
        let cardsById = snapshot.creditCards.reduce(into: [String: CreditCard]()) { result, card in result[card.id] = card }
        let debtsById = snapshot.debts.reduce(into: [String: Debt]()) { result, debt in result[debt.id] = debt }
        let payPeriodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in result[period.id] = period }
        let billGroupsById = snapshot.billGroups.reduce(into: [String: BillGroup]()) { result, group in result[group.id] = group }

        var events: [ActivityTimelineEvent] = []
        let accountCreatedAt = account?.createdAt ?? snapshot.settings.createdAt
        let accountName = account?.name ?? "Account"

        events.append(
            ActivityTimelineEvent(
                id: "account-created-\(account?.id ?? "single")",
                sortKey: accountCreatedAt,
                title: "Account created",
                detail: "\(accountName) started tracking money here.",
                typeLabel: "Account",
                secondaryLabel: "Start",
                amountPence: nil,
                amountStyle: .neutral,
                color: AppTheme.Colors.primaryOrange,
                symbol: "person.crop.circle"
            )
        )

        for group in snapshot.billGroups {
            events.append(
                ActivityTimelineEvent(
                    id: "bill-group-created-\(group.id)",
                    sortKey: group.createdAt,
                    title: "Bill group created",
                    detail: group.name,
                    typeLabel: "Bills",
                    secondaryLabel: "Group",
                    amountPence: nil,
                    amountStyle: .neutral,
                    color: Color(hex: group.color),
                    symbol: "folder"
                )
            )
            appendDeletedEvent(prefix: "bill-group", name: group.name, deletedAt: group.deletedAt, typeLabel: "Bills", color: Color(hex: group.color), symbol: "archivebox", into: &events)
        }

        for pot in snapshot.pots {
            events.append(
                ActivityTimelineEvent(
                    id: "pot-created-\(pot.id)",
                    sortKey: pot.createdAt,
                    title: "Pot created",
                    detail: "\(pot.name) opened as \(prettyLabel(pot.type.rawValue)).",
                    typeLabel: "Pot",
                    secondaryLabel: pot.category,
                    amountPence: pot.balancePence,
                    amountStyle: .positive,
                    color: Color(hex: pot.color),
                    symbol: "wallet.pass"
                )
            )
            appendDeletedEvent(prefix: "pot", name: pot.name, deletedAt: pot.deletedAt, typeLabel: "Pot", color: Color(hex: pot.color), symbol: "archivebox", into: &events)
        }

        for card in snapshot.creditCards {
            events.append(
                ActivityTimelineEvent(
                    id: "card-created-\(card.id)",
                    sortKey: card.createdAt,
                    title: "Card added",
                    detail: "\(card.name) from \(card.provider.isEmpty ? "Card" : card.provider).",
                    typeLabel: "Credit",
                    secondaryLabel: "Limit \(MoneyParser.formatPence(card.limitPence))",
                    amountPence: card.openingBalancePence ?? card.openingStatementBalancePence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "creditcard"
                )
            )
            appendDeletedEvent(prefix: "card", name: card.name, deletedAt: card.deletedAt, typeLabel: "Credit", color: AppTheme.Colors.warning, symbol: "archivebox", into: &events)
        }

        for debt in snapshot.debts {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-created-\(debt.id)",
                    sortKey: debt.createdAt,
                    title: "Debt added",
                    detail: "\(debt.name) with \(debt.lender).",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(debt.status.rawValue),
                    amountPence: debt.currentBalancePence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.danger,
                    symbol: "exclamationmark.shield"
                )
            )
            appendDeletedEvent(prefix: "debt", name: debt.name, deletedAt: debt.deletedAt, typeLabel: "Debt", color: AppTheme.Colors.danger, symbol: "archivebox", into: &events)
        }

        for payment in snapshot.recurringPayments {
            let cardName = payment.creditCardId.flatMap { cardsById[$0]?.name }
            let potName = payment.potId.flatMap { potsById[$0]?.name }
            let groupName = payment.billGroupId.flatMap { billGroupsById[$0]?.name }
            let linkDetail = [groupName, cardName, potName]
                .compactMap { $0 }
                .joined(separator: " • ")
            events.append(
                ActivityTimelineEvent(
                    id: "bill-created-\(payment.id)",
                    sortKey: payment.createdAt,
                    title: "Bill added",
                    detail: linkDetail.isEmpty ? payment.name : "\(payment.name) • \(linkDetail)",
                    typeLabel: "Bill",
                    secondaryLabel: prettyLabel(payment.frequency.rawValue),
                    amountPence: payment.amountPence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "calendar.badge.clock"
                )
            )
            appendDeletedEvent(prefix: "bill", name: payment.name, deletedAt: payment.deletedAt, typeLabel: "Bill", color: AppTheme.Colors.warning, symbol: "archivebox", into: &events)
        }

        for period in snapshot.payPeriods {
            events.append(
                ActivityTimelineEvent(
                    id: "pay-period-\(period.id)",
                    sortKey: period.createdAt,
                    title: "Pay period created",
                    detail: "\(timelineDateLabel(period.startDate)) to \(timelineDateLabel(period.endDate)).",
                    typeLabel: "Income",
                    secondaryLabel: prettyLabel(period.status.rawValue),
                    amountPence: period.incomePence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "calendar"
                )
            )
        }

        for paycheck in snapshot.paychecks {
            let period = payPeriodsById[paycheck.payPeriodId]
            events.append(
                ActivityTimelineEvent(
                    id: "paycheck-\(paycheck.id)",
                    sortKey: paycheck.createdAt,
                    title: "Income recorded",
                    detail: period.map { "Payday \(timelineDateLabel($0.payday))" } ?? "Paycheck recorded.",
                    typeLabel: "Income",
                    secondaryLabel: "\(String(format: "%.1f", paycheck.hoursWorked)) hours",
                    amountPence: paycheck.actualAmountPence ?? paycheck.calculatedAmountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.neonMoneyUp,
                    symbol: "sterlingsign.circle"
                )
            )
        }

        for income in snapshot.oneOffIncomes where income.deletedAt == nil {
            events.append(
                ActivityTimelineEvent(
                    id: "one-off-income-\(income.id)",
                    sortKey: income.createdAt,
                    title: "One-off income recorded",
                    detail: income.note.isEmpty ? income.name : "\(income.name) • \(income.note)",
                    typeLabel: "Income",
                    secondaryLabel: timelineDateLabel(income.date),
                    amountPence: income.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.neonMoneyUp,
                    symbol: "plus.circle"
                )
            )
        }

        for allocation in snapshot.potAllocations {
            let potName = allocation.potId.isEmpty ? "Pot" : (potsById[allocation.potId]?.name ?? "Pot")
            events.append(
                ActivityTimelineEvent(
                    id: "allocation-\(allocation.id)",
                    sortKey: allocation.createdAt,
                    title: "Pot funded",
                    detail: potName,
                    typeLabel: "Pot",
                    secondaryLabel: allocation.source.map { prettyLabel($0.rawValue) },
                    amountPence: allocation.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "arrow.down.to.line.compact"
                )
            )
        }

        for transaction in snapshot.transactions {
            let isSpending = transaction.type == .spending
            let route = transaction.creditCardId.flatMap { cardsById[$0]?.name }
                ?? transaction.potId.flatMap { potsById[$0]?.name }
                ?? "Manual"
            events.append(
                ActivityTimelineEvent(
                    id: "transaction-\(transaction.id)",
                    sortKey: transaction.date,
                    title: transaction.note.isEmpty ? (isSpending ? "Spending recorded" : "Money movement recorded") : transaction.note,
                    detail: route,
                    typeLabel: isSpending ? "Spend" : prettyLabel(transaction.type.rawValue),
                    secondaryLabel: transaction.paymentMethod.map { prettyLabel($0.rawValue) },
                    amountPence: transaction.amountPence,
                    amountStyle: isSpending ? .negative : .positive,
                    color: isSpending ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp,
                    symbol: isSpending ? "receipt" : "arrow.left.arrow.right"
                )
            )
        }

        for payment in snapshot.creditCardRepayments {
            events.append(
                ActivityTimelineEvent(
                    id: "card-repayment-\(payment.id)",
                    sortKey: payment.date,
                    title: "Card payment",
                    detail: cardsById[payment.creditCardId]?.name ?? "Credit card",
                    typeLabel: "Credit",
                    secondaryLabel: payment.source.map { prettyLabel($0.rawValue) } ?? "Manual",
                    amountPence: payment.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "creditcard.and.123"
                )
            )
        }

        for cardPot in snapshot.creditCardPots {
            events.append(
                ActivityTimelineEvent(
                    id: "card-pot-\(cardPot.id)",
                    sortKey: cardPot.createdAt,
                    title: "Card pot created",
                    detail: "\(cardPot.name) for \(cardsById[cardPot.creditCardId]?.name ?? "Credit card").",
                    typeLabel: "Credit",
                    secondaryLabel: prettyLabel(cardPot.status.rawValue),
                    amountPence: cardPot.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.primaryOrange,
                    symbol: "wallet.pass"
                )
            )
        }

        for payment in snapshot.customPayments {
            events.append(
                ActivityTimelineEvent(
                    id: "custom-payment-\(payment.id)",
                    sortKey: payment.createdAt,
                    title: "Custom payment added",
                    detail: payment.name,
                    typeLabel: "Payment",
                    secondaryLabel: timelineDateLabel(payment.dueDate),
                    amountPence: payment.amountPence,
                    amountStyle: .negative,
                    color: AppTheme.Colors.warning,
                    symbol: "calendar.badge.plus"
                )
            )
        }

        for reserve in snapshot.debtReserves {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-reserve-\(reserve.id)",
                    sortKey: reserve.createdAt,
                    title: "Debt reserve created",
                    detail: debtsById[reserve.debtId]?.name ?? "Debt",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(reserve.status.rawValue),
                    amountPence: reserve.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.primaryOrange,
                    symbol: "shield.lefthalf.filled"
                )
            )
        }

        for payment in snapshot.debtPayments {
            events.append(
                ActivityTimelineEvent(
                    id: "debt-payment-\(payment.id)",
                    sortKey: payment.date,
                    title: "Debt payment",
                    detail: debtsById[payment.debtId]?.name ?? "Debt",
                    typeLabel: "Debt",
                    secondaryLabel: prettyLabel(payment.paymentType.rawValue),
                    amountPence: payment.amountPence,
                    amountStyle: .positive,
                    color: AppTheme.Colors.success,
                    symbol: "checkmark.shield"
                )
            )
        }

        for brief in snapshot.dailyBriefs {
            events.append(
                ActivityTimelineEvent(
                    id: "daily-brief-\(brief.id)",
                    sortKey: brief.createdAt,
                    title: "Daily brief saved",
                    detail: brief.content.isEmpty ? "Planner summary captured." : brief.content,
                    typeLabel: "Brief",
                    secondaryLabel: timelineDateLabel(brief.date),
                    amountPence: nil,
                    amountStyle: .neutral,
                    color: AppTheme.Colors.secondaryText,
                    symbol: "sparkles"
                )
            )
        }

        return events
            .sorted {
                if $0.sortKey == $1.sortKey {
                    return $0.id < $1.id
                }
                return $0.sortKey < $1.sortKey
            }
    }

    private static func appendDeletedEvent(prefix: String, name: String, deletedAt: String?, typeLabel: String, color: Color, symbol: String, into events: inout [ActivityTimelineEvent]) {
        guard let deletedAt else { return }
        events.append(
            ActivityTimelineEvent(
                id: "\(prefix)-deleted-\(name)-\(deletedAt)",
                sortKey: deletedAt,
                title: "\(name) archived",
                detail: "This item was removed from the active account view.",
                typeLabel: typeLabel,
                secondaryLabel: "Archived",
                amountPence: nil,
                amountStyle: .neutral,
                color: color,
                symbol: symbol
            )
        )
    }

    private static func prettyLabel(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private struct ActivityTimelineEvent: Identifiable {
    enum AmountStyle {
        case positive
        case negative
        case neutral
    }

    var id: String
    var sortKey: String
    var title: String
    var detail: String
    var typeLabel: String
    var secondaryLabel: String?
    var amountPence: Int?
    var amountStyle: AmountStyle
    var color: Color
    var symbol: String

    var dateLabel: String {
        timelineDateLabel(sortKey)
    }

    var cardScrollID: String {
        "timeline-card-\(id)"
    }

    var branchScrollID: String {
        "timeline-branch-\(id)"
    }

    var amountLabel: String? {
        guard let amountPence else { return nil }
        switch amountStyle {
        case .positive:
            return "+\(MoneyParser.formatPence(amountPence))"
        case .negative:
            return "-\(MoneyParser.formatPence(amountPence))"
        case .neutral:
            return MoneyParser.formatPence(amountPence)
        }
    }

    var amountColor: Color {
        switch amountStyle {
        case .positive:
            return AppTheme.Colors.neonMoneyUp
        case .negative:
            return AppTheme.Colors.neonMoneyDown
        case .neutral:
            return AppTheme.Colors.primaryText
        }
    }
}

private func timelineDateLabel(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate.prefixDateLabel).formatted(.dateTime.day().month(.abbreviated).year())
}

private struct ActivitySpendingDetailView: View {
    @ObservedObject var store: PlannerStore
    @State private var editMode: EditMode = .inactive

    var body: some View {
        PaydayView(
            store: store,
            navigationMode: .inline,
            toolbarMode: .editDone(isEditing: editMode.isEditing) {
                toggleEditMode()
            }
        )
        .environment(\.editMode, $editMode)
    }

    private func toggleEditMode() {
        withAnimation(appToolbarMorphAnimation) {
            editMode = editMode.isEditing ? .inactive : .active
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
    var typeLabel: String
    var color: Color
    var sortDate: String
    var detailRows: [ActivityDetailRow]
    var recordRows: [ActivityDetailRow]
}

private struct ActivityDetailRow: Identifiable {
    var label: String
    var value: String
    var valueColor: Color = AppTheme.Colors.primaryText

    var id: String { label }
}

private struct ActivityEntryRow: View {
    var entry: ActivityEntry

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Circle()
                .fill(entry.color)
                .frame(width: 10, height: 10)
                .shadow(color: entry.color.opacity(0.45), radius: 6, y: 2)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(entry.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(entry.amount)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(entry.color)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel("Open details for \(entry.title)")
    }
}

private struct ActivityEntryDetailView: View {
    var entry: ActivityEntry

    var body: some View {
        ScreenScaffold(
            title: "Activity detail",
            subtitle: entry.title,
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            activityHero

            SectionTitle("Details")
            ActivityDetailRowsCard(rows: entry.detailRows)

            if !entry.recordRows.isEmpty {
                SectionTitle("Record")
                ActivityDetailRowsCard(rows: entry.recordRows)
            }
        }
    }

    private var activityHero: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 10, height: 10)
                                .shadow(color: entry.color.opacity(0.55), radius: 8, y: 2)

                            Text(entry.typeLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.cardEyebrow)
                                .textCase(.uppercase)
                        }

                        Text(entry.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(entry.amount)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(entry.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: 150, alignment: .trailing)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    ActivityHeroInfoPill(label: "Date", value: heroDate, color: entry.color)
                    ActivityHeroInfoPill(label: "Source", value: heroSource, color: AppTheme.Colors.primaryOrange)
                }
            }
        }
    }

    private var detailParts: [String] {
        entry.detail.components(separatedBy: " · ")
    }

    private var heroDate: String {
        detailParts.first ?? entry.detail
    }

    private var heroSource: String {
        guard detailParts.count > 1 else { return entry.typeLabel }
        return detailParts.dropFirst().joined(separator: " · ")
    }
}

private struct ActivityHeroInfoPill: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .textCase(.uppercase)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct ActivityDetailRowsCard: View {
    var rows: [ActivityDetailRow]

    var body: some View {
        AppCard {
            ForEach(rows.indices, id: \.self) { index in
                MetricRow(
                    label: rows[index].label,
                    value: rows[index].value,
                    valueColor: rows[index].valueColor
                )

                if index < rows.count - 1 {
                    AppDivider()
                }
            }
        }
    }
}

private struct ActivityMonthlyBalanceChartPoint: Identifiable, Equatable {
    var day: Int
    var dateLabel: String
    var balancePence: Int
    var incomePence: Int
    var spentPence: Int
    var isCurrentDay: Bool
    var isFuture: Bool

    var id: Int { day }

    var netPence: Int {
        incomePence - spentPence
    }
}

private struct ActivityMonthlyBalanceChartData: Equatable {
    var monthLabel: String
    var startPence: Int
    var currentPence: Int
    var incomePence: Int
    var spentPence: Int
    var currentDay: Int
    var daysInMonth: Int
    var points: [ActivityMonthlyBalanceChartPoint]

    var id: String {
        "\(monthLabel)-\(startPence)-\(currentPence)-\(incomePence)-\(spentPence)-\(currentDay)-\(daysInMonth)"
    }

    var hasData: Bool {
        incomePence != 0 || spentPence != 0
    }

    var netMovementPence: Int {
        incomePence - spentPence
    }

    var activePoints: [ActivityMonthlyBalanceChartPoint] {
        points.filter { !$0.isFuture }
    }

    var movementPoints: [ActivityMonthlyBalanceChartPoint] {
        activePoints.filter { point in
            point.incomePence != 0 || point.spentPence != 0 || point.isCurrentDay
        }
    }

    var graphMinPence: Int {
        min(0, points.map(\.balancePence).min() ?? 0)
    }

    var graphMaxPence: Int {
        let maxValue = max(0, points.map(\.balancePence).max() ?? 0)
        return maxValue == graphMinPence ? maxValue + 1 : maxValue
    }

    var progressLabel: String {
        "\(currentDay)/\(daysInMonth)"
    }

    static func make(snapshot: PlannerSnapshot, todayIso: String) -> ActivityMonthlyBalanceChartData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let today = FinanceEngine.parseDate(todayIso)
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 1
        let currentDay = min(max(todayComponents.day ?? 1, 1), max(daysInMonth, 1))

        // Cloud/local merges can contain the same record ID more than once. Keep the
        // latest array entry instead of trapping while constructing the lookup.
        let payPeriodsById = snapshot.payPeriods.reduce(into: [String: PayPeriod]()) { result, period in
            result[period.id] = period
        }
        let paycheckIncomeEvents = snapshot.paychecks.compactMap { paycheck -> ActivityDailyAmount? in
            guard paycheck.deletedAt == nil else { return nil }
            let date = payPeriodsById[paycheck.payPeriodId]?.payday ?? paycheck.createdAt.prefixDateLabel
            guard let day = dayInCurrentMonth(date, calendar: calendar, todayComponents: todayComponents) else { return nil }
            return ActivityDailyAmount(day: day, amountPence: paycheck.actualAmountPence ?? paycheck.calculatedAmountPence)
        }

        let periodIncomeEvents = snapshot.payPeriods.compactMap { period -> ActivityDailyAmount? in
            guard period.deletedAt == nil,
                  let day = dayInCurrentMonth(period.payday, calendar: calendar, todayComponents: todayComponents)
            else {
                return nil
            }
            return ActivityDailyAmount(day: day, amountPence: period.incomePence)
        }

        let oneOffIncomeEvents = snapshot.oneOffIncomes.compactMap { income -> ActivityDailyAmount? in
            guard income.deletedAt == nil,
                  let day = dayInCurrentMonth(income.date, calendar: calendar, todayComponents: todayComponents),
                  day <= currentDay
            else {
                return nil
            }
            return ActivityDailyAmount(day: day, amountPence: income.amountPence)
        }

        let incomeEvents = (paycheckIncomeEvents.isEmpty ? periodIncomeEvents : paycheckIncomeEvents) + oneOffIncomeEvents
        let spendingEvents = snapshot.transactions.compactMap { transaction -> ActivityDailyAmount? in
            guard transaction.deletedAt == nil,
                  transaction.type == .spending,
                  let day = dayInCurrentMonth(transaction.date, calendar: calendar, todayComponents: todayComponents),
                  day <= currentDay
            else {
                return nil
            }
            return ActivityDailyAmount(day: day, amountPence: abs(transaction.amountPence))
        }

        let incomeByDay = groupedAmounts(incomeEvents.filter { $0.day <= currentDay })
        let spendByDay = groupedAmounts(spendingEvents)

        var cumulativeIncome = 0
        var cumulativeSpend = 0
        var points: [ActivityMonthlyBalanceChartPoint] = []

        for day in 1...max(daysInMonth, 1) {
            let dailyIncome = day <= currentDay ? incomeByDay[day, default: 0] : 0
            let dailySpend = day <= currentDay ? spendByDay[day, default: 0] : 0

            if day <= currentDay {
                cumulativeIncome += dailyIncome
                cumulativeSpend += dailySpend
            }

            points.append(
                ActivityMonthlyBalanceChartPoint(
                    day: day,
                    dateLabel: dateLabel(for: day, calendar: calendar, todayComponents: todayComponents),
                    balancePence: cumulativeIncome - cumulativeSpend,
                    incomePence: dailyIncome,
                    spentPence: dailySpend,
                    isCurrentDay: day == currentDay,
                    isFuture: day > currentDay
                )
            )
        }

        let activePoints = points.filter { !$0.isFuture }

        return ActivityMonthlyBalanceChartData(
            monthLabel: today.formatted(.dateTime.month(.wide).year()),
            startPence: 0,
            currentPence: activePoints.last?.balancePence ?? 0,
            incomePence: cumulativeIncome,
            spentPence: cumulativeSpend,
            currentDay: currentDay,
            daysInMonth: max(daysInMonth, 1),
            points: points
        )
    }

    private static func groupedAmounts(_ amounts: [ActivityDailyAmount]) -> [Int: Int] {
        amounts.reduce(into: [:]) { result, amount in
            result[amount.day, default: 0] += amount.amountPence
        }
    }

    private static func dayInCurrentMonth(_ isoDate: String, calendar: Calendar, todayComponents: DateComponents) -> Int? {
        let date = FinanceEngine.parseDate(isoDate.prefixDateLabel)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard components.year == todayComponents.year,
              components.month == todayComponents.month,
              let day = components.day
        else {
            return nil
        }
        return day
    }

    private static func dateLabel(for day: Int, calendar: Calendar, todayComponents: DateComponents) -> String {
        let components = DateComponents(year: todayComponents.year, month: todayComponents.month, day: day)
        guard let date = calendar.date(from: components) else {
            return "Day \(day)"
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct ActivityDailyAmount {
    var day: Int
    var amountPence: Int
}

enum ActivityMonthlyBalanceChartLayoutPolicy {
    static let estimatedLineStyle = "fullMonthProjectedLine"
    static let actualLineStyle = "dayAnchoredNeonLine"
    static let todayMarkerFollowsActualLine = true
}

private func signedMoney(_ amountPence: Int) -> String {
    if amountPence < 0 {
        return "-\(MoneyParser.formatPence(abs(amountPence)))"
    }
    if amountPence > 0 {
        return "+\(MoneyParser.formatPence(amountPence))"
    }
    return MoneyParser.formatPence(0)
}

private struct ActivityMonthlyBalanceCard: View {
    var data: ActivityMonthlyBalanceChartData

    var body: some View {
        AppCard(glow: data.hasData) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Net left this month")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                            .textCase(.uppercase)
                        Text(MoneyParser.formatPence(data.currentPence))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(data.currentPence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(data.hasData ? "Income minus spending in \(data.monthLabel) so far" : "No income or spending recorded in \(data.monthLabel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    ActivityMonthProgressBadge(progress: Double(data.currentDay) / Double(max(data.daysInMonth, 1)), label: data.progressLabel)
                }

                ActivityBalanceLineGraph(data: data)
                    .frame(height: 148)

                HStack(spacing: AppTheme.Spacing.sm) {
                    ActivityChartMetricPill(label: "Opening", value: MoneyParser.formatPence(data.startPence), color: AppTheme.Colors.primaryOrange)
                    ActivityChartMetricPill(label: "Income", value: MoneyParser.formatPence(data.incomePence), color: AppTheme.Colors.neonMoneyUp)
                    ActivityChartMetricPill(label: "Spent", value: MoneyParser.formatPence(data.spentPence), color: AppTheme.Colors.neonMoneyDown)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net left this month \(MoneyParser.formatPence(data.currentPence))")
    }
}

private struct ActivityMonthlyBalanceDetailView: View {
    var data: ActivityMonthlyBalanceChartData

    var body: some View {
        ScreenScaffold(
            title: "Cash flow",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            detailHero

            SectionTitle("Monthly line")
            AppCard(glow: data.hasData) {
                ActivityBalanceLineGraph(data: data)
                    .frame(height: 190)
            }

            SectionTitle("Breakdown")
            ActivityDetailRowsCard(rows: breakdownRows)

            SectionTitle("Daily movement")
            AppCard {
                let rows = dailyMovementRows
                ForEach(rows.indices, id: \.self) { index in
                    ActivityMonthlyBalanceDayRow(point: rows[index])

                    if index < rows.count - 1 {
                        AppDivider()
                    }
                }
            }
        }
    }

    private var detailHero: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(data.monthLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.cardEyebrow)
                        .textCase(.uppercase)

                    Text(MoneyParser.formatPence(data.currentPence))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(data.currentPence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text("Net income minus spending from the start of the month to now.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    ActivityChartMetricPill(label: "Income", value: MoneyParser.formatPence(data.incomePence), color: AppTheme.Colors.neonMoneyUp)
                    ActivityChartMetricPill(label: "Spent", value: MoneyParser.formatPence(data.spentPence), color: AppTheme.Colors.neonMoneyDown)
                    ActivityChartMetricPill(label: "Net", value: signedMoney(data.netMovementPence), color: data.netMovementPence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp)
                }
            }
        }
    }

    private var breakdownRows: [ActivityDetailRow] {
        [
            ActivityDetailRow(label: "Opening", value: MoneyParser.formatPence(data.startPence), valueColor: AppTheme.Colors.primaryOrange),
            ActivityDetailRow(label: "Income recorded", value: MoneyParser.formatPence(data.incomePence), valueColor: AppTheme.Colors.neonMoneyUp),
            ActivityDetailRow(label: "Spending recorded", value: MoneyParser.formatPence(data.spentPence), valueColor: AppTheme.Colors.neonMoneyDown),
            ActivityDetailRow(label: "Net left", value: signedMoney(data.currentPence), valueColor: data.currentPence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp),
            ActivityDetailRow(label: "Progress", value: "\(data.currentDay) of \(data.daysInMonth) days")
        ]
    }

    private var dailyMovementRows: [ActivityMonthlyBalanceChartPoint] {
        if data.movementPoints.isEmpty {
            return Array(data.activePoints.suffix(1))
        }
        return data.movementPoints
    }
}

private struct ActivityMonthlyBalanceDayRow: View {
    var point: ActivityMonthlyBalanceChartPoint

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(point.dateLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(point.isCurrentDay ? "Today" : "Day \(point.day)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(signedMoney(point.netPence))
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(point.netPence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp)
                    Text("Net day")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                ActivityChartMetricPill(label: "In", value: MoneyParser.formatPence(point.incomePence), color: AppTheme.Colors.neonMoneyUp)
                ActivityChartMetricPill(label: "Out", value: MoneyParser.formatPence(point.spentPence), color: AppTheme.Colors.neonMoneyDown)
                ActivityChartMetricPill(label: "Left", value: signedMoney(point.balancePence), color: point.balancePence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ActivityBalanceLineGraph: View {
    var data: ActivityMonthlyBalanceChartData
    @State private var drawProgress = 0.0

    private var trendColor: Color {
        data.currentPence < 0 ? AppTheme.Colors.neonMoneyDown : AppTheme.Colors.neonMoneyUp
    }

    var body: some View {
        GeometryReader { proxy in
            let minValue = data.graphMinPence
            let maxValue = data.graphMaxPence
            let activePoints = data.activePoints
            let lineColor = trendColor

            ZStack(alignment: .topLeading) {
                graphGrid

                ActivityBalanceLineShape(
                    points: data.points,
                    daysInMonth: data.daysInMonth,
                    minValue: minValue,
                    maxValue: maxValue
                )
                    .stroke(
                        AppTheme.Colors.border.opacity(0.62),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )

                ActivityBalanceAreaShape(
                    points: activePoints,
                    daysInMonth: data.daysInMonth,
                    minValue: minValue,
                    maxValue: maxValue
                )
                    .fill(
                        LinearGradient(
                            colors: [
                                lineColor.opacity(data.hasData ? 0.22 : 0.08),
                                lineColor.opacity(data.hasData ? 0.08 : 0.03),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(drawProgress)

                ActivityBalanceLineShape(
                    points: activePoints,
                    daysInMonth: data.daysInMonth,
                    minValue: minValue,
                    maxValue: maxValue
                )
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: data.hasData ? lineColor.opacity(0.44) : .clear, radius: 12, y: 6)

                if let currentPoint = activePoints.last {
                    todayMarker(point: currentPoint, size: proxy.size, minValue: minValue, maxValue: maxValue, color: lineColor)
                }

                HStack {
                    Text("1")
                    Spacer()
                    Text("\(data.daysInMonth)")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: 18)
            }
            .onAppear {
                startAnimation()
            }
            .onChange(of: data.id) { _, _ in
                startAnimation()
            }
        }
    }

    private var graphGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                AppTheme.Colors.border.opacity(0.32)
                    .frame(height: 1)
                Spacer()
            }
            AppTheme.Colors.border.opacity(0.42)
                .frame(height: 1)
        }
        .padding(.bottom, 8)
    }

    private func todayMarker(point: ActivityMonthlyBalanceChartPoint, size: CGSize, minValue: Int, maxValue: Int, color: Color) -> some View {
        let position = pointPosition(
            day: point.day,
            balancePence: point.balancePence,
            size: size,
            daysInMonth: data.daysInMonth,
            minValue: minValue,
            maxValue: maxValue
        )

        return ZStack {
            Text("Now")
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.Colors.controlText)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(color, in: Capsule())
                .shadow(color: color.opacity(0.55), radius: 8, y: 3)
                .offset(y: -27)

            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 28, height: 28)

            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(AppTheme.Colors.primaryText.opacity(0.72), lineWidth: 2))
                .shadow(color: color.opacity(0.72), radius: 10, y: 4)
        }
        .position(position)
    }

    private func pointPosition(day: Int, balancePence: Int, size: CGSize, daysInMonth: Int, minValue: Int, maxValue: Int) -> CGPoint {
        let drawingHeight = max(size.height - 26, 1)
        let clampedDay = min(max(day, 1), max(daysInMonth, 1))
        let x = CGFloat(clampedDay - 1) / CGFloat(max(daysInMonth - 1, 1)) * max(size.width, 1)
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(8, min(drawingHeight, y)))
    }

    private func startAnimation() {
        drawProgress = 0
        withAnimation(.easeOut(duration: 1.15)) {
            drawProgress = 1
        }
    }
}

private struct ActivityBalanceLineShape: Shape {
    var points: [ActivityMonthlyBalanceChartPoint]
    var daysInMonth: Int
    var minValue: Int
    var maxValue: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(day: point.day, balancePence: point.balancePence, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        if points.count == 1 {
            let position = pointPosition(day: points[0].day, balancePence: points[0].balancePence, rect: rect)
            path.addLine(to: CGPoint(x: min(rect.maxX, position.x + 0.5), y: position.y))
        }

        return path
    }

    private func pointPosition(day: Int, balancePence: Int, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 26, 1)
        let clampedDay = min(max(day, 1), max(daysInMonth, 1))
        let x = rect.minX + CGFloat(clampedDay - 1) / CGFloat(max(daysInMonth - 1, 1)) * rect.width
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct ActivityBalanceAreaShape: Shape {
    var points: [ActivityMonthlyBalanceChartPoint]
    var daysInMonth: Int
    var minValue: Int
    var maxValue: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        for (index, point) in points.enumerated() {
            let position = pointPosition(day: point.day, balancePence: point.balancePence, rect: rect)
            if index == 0 {
                path.move(to: position)
            } else {
                path.addLine(to: position)
            }
        }

        let lastX = pointPosition(day: points.last?.day ?? 1, balancePence: points.last?.balancePence ?? 0, rect: rect).x
        let firstX = pointPosition(day: points[0].day, balancePence: points[0].balancePence, rect: rect).x
        path.addLine(to: CGPoint(x: lastX, y: rect.maxY - 18))
        path.addLine(to: CGPoint(x: firstX, y: rect.maxY - 18))
        path.closeSubpath()
        return path
    }

    private func pointPosition(day: Int, balancePence: Int, rect: CGRect) -> CGPoint {
        let drawingHeight = max(rect.height - 26, 1)
        let clampedDay = min(max(day, 1), max(daysInMonth, 1))
        let x = rect.minX + CGFloat(clampedDay - 1) / CGFloat(max(daysInMonth - 1, 1)) * rect.width
        let range = CGFloat(max(maxValue - minValue, 1))
        let normalized = CGFloat(balancePence - minValue) / range
        let y = rect.minY + drawingHeight - (normalized * drawingHeight)
        return CGPoint(x: x, y: max(rect.minY + 8, min(rect.minY + drawingHeight, y)))
    }
}

private struct ActivityMonthProgressBadge: View {
    var progress: Double
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Colors.border, lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AppTheme.Gradients.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
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
        .frame(width: 60, height: 60)
    }
}

private struct ActivityChartMetricPill: View {
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
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct CreditView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedCard: CreditCard?

    var body: some View {
        let displayData = creditDisplayData

        ScreenScaffold(
            title: "Credit",
            subtitle: "Cards, debts, and payments due.",
            navigationMode: .tabRoot,
            toolbarMode: .none
        ) {
            creditSummary(summary: displayData.summary, dueItems: displayData.dueItems)
            activeCardRows(cardModels: displayData.cardModels)
            paymentDueSummary(dueItems: displayData.dueItems)
            creditRoutes
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(store: store, card: card)
        }
    }

    private func creditSummary(summary: CreditSummaryData, dueItems: [CreditDueItem]) -> some View {
        NavigationLink {
            CreditOverviewDetailView(summary: summary, dueItems: dueItems)
        } label: {
            CreditSummaryCard(summary: summary, showsDisclosure: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open credit overview")
    }

    private var creditDisplayData: CreditDisplayData {
        let activeCards = store.activeCards
        let cardModels = creditCardPreviewModels(
            cards: activeCards,
            snapshot: store.snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
        let cardOwed = cardModels.reduce(0) { $0 + $1.balancePence }
        let debtSummary = FinanceEngine.getDebtSummary(
            debts: store.snapshot.debts,
            payments: store.snapshot.debtPayments,
            reserves: store.snapshot.debtReserves,
            pots: store.snapshot.pots,
            today: store.todayIso
        )
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: store.todayIso)
        let unpaidStatements = statements.reduce(0) { $0 + $1.unpaidAmountPence }
        let statementDueItems = statements
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
        let debtDueItems = PlannerDerivedData.debtScheduleItems(snapshot: store.snapshot, payPeriod: nil)
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

        return CreditDisplayData(
            summary: CreditSummaryData(
                cardOwedPence: cardOwed,
                debtBalancePence: debtSummary.totalCurrentBalancePence,
                debtPaidPence: debtSummary.totalPaidPence,
                overdueDebtCount: debtSummary.overdueDebtCount,
                unpaidStatementsPence: unpaidStatements,
                unpaidStatementCount: statements.filter { $0.status != .paid }.count,
                activeCardCount: activeCards.count,
                activeDebtCount: store.snapshot.debts.filter { $0.deletedAt == nil && $0.status.isActiveLike }.count
            ),
            dueItems: (statementDueItems + debtDueItems).sorted { $0.date < $1.date },
            cardModels: cardModels
        )
    }

    private func paymentDueSummary(dueItems: [CreditDueItem]) -> some View {
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

    @ViewBuilder
    private func activeCardRows(cardModels: [CreditCardPreviewModel]) -> some View {
        if !cardModels.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Cards")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        ForEach(cardModels) { model in
                            Button {
                                selectedCard = model.card
                            } label: {
                                FloatingCreditCardPreview(model: model)
                                .equatable()
                                .frame(width: CreditLayoutPolicy.cardRowWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                }
                .padding(.horizontal, -AppTheme.Spacing.lg)
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

private struct CreditDisplayData {
    var summary: CreditSummaryData
    var dueItems: [CreditDueItem]
    var cardModels: [CreditCardPreviewModel]
}

private struct CreditSummaryData {
    var cardOwedPence: Int
    var debtBalancePence: Int
    var debtPaidPence: Int
    var overdueDebtCount: Int
    var unpaidStatementsPence: Int
    var unpaidStatementCount: Int
    var activeCardCount: Int
    var activeDebtCount: Int

    var totalOwedPence: Int {
        cardOwedPence + debtBalancePence
    }

    var hasOwedBalance: Bool {
        totalOwedPence > 0 || unpaidStatementsPence > 0
    }
}

private struct CreditSummaryCard: View {
    var summary: CreditSummaryData
    var showsDisclosure: Bool

    var body: some View {
        AppCard(glow: true) {
            MetricRow(
                label: "Total owed",
                value: MoneyParser.formatPence(summary.totalOwedPence),
                valueColor: summary.totalOwedPence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.primaryText
            )
            MetricRow(label: "Cards owed", value: MoneyParser.formatPence(summary.cardOwedPence))
            MetricRow(label: "Debt balance", value: MoneyParser.formatPence(summary.debtBalancePence))
            MetricRow(
                label: "Unpaid statements",
                value: MoneyParser.formatPence(summary.unpaidStatementsPence),
                valueColor: summary.unpaidStatementsPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success
            )

            if showsDisclosure {
                HStack(spacing: 8) {
                    Text("View credit overview")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.black))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .padding(.top, 2)
            }
        }
    }
}

private struct CreditOverviewDetailView: View {
    var summary: CreditSummaryData
    var dueItems: [CreditDueItem]

    var body: some View {
        ScreenScaffold(
            title: "Credit overview",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            CreditSummaryCard(summary: summary, showsDisclosure: false)

            SectionTitle("Breakdown")
            AppCard {
                MetricRow(label: "Active cards", value: "\(summary.activeCardCount)")
                AppDivider()
                MetricRow(label: "Active debts", value: "\(summary.activeDebtCount)")
                AppDivider()
                MetricRow(label: "Paid toward debts", value: MoneyParser.formatPence(summary.debtPaidPence), valueColor: AppTheme.Colors.success)
                AppDivider()
                MetricRow(label: "Overdue debts", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                AppDivider()
                MetricRow(label: "Open statements", value: "\(summary.unpaidStatementCount)")
            }

            SectionTitle("Due soon")
            AppCard {
                if dueItems.isEmpty {
                    EmptyStateView(title: "Nothing due soon", message: "Card statements and debt payments will appear here when scheduled.", systemImage: "checkmark.circle")
                } else {
                    ForEach(dueItems.prefix(10)) { item in
                        MetricRow(
                            label: "\(item.title) · \(shortDate(item.date))",
                            value: MoneyParser.formatPence(item.amountPence),
                            valueColor: item.isOverdue ? AppTheme.Colors.danger : AppTheme.Colors.warning
                        )

                        if item.id != dueItems.prefix(10).last?.id {
                            AppDivider()
                        }
                    }
                }
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
        case .awaitingConfirmation:
            return "Awaiting confirmation"
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
        case .awaitingConfirmation:
            return AppTheme.Colors.warning
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
