import SwiftUI

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
    static let dayCellHeight: CGFloat = 44
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
        let upcoming = PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: store.snapshot,
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didInitializeDate = false
    @State private var month = Date()
    @State private var selectedDate = FinanceEngine.toIsoDate(Date())
    @State private var selectedDayDetail: PlanDayDetail?
    @State private var dragTranslation: CGFloat = 0
    @State private var monthSwipeDirection = 1
    @State private var monthPresentationCache = RevisionPresentationCache<CalendarMonthPresentationKey, CalendarMonthPresentation>()

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            calendarGrid
            selectedDaySummary
        }
        .sheet(item: $selectedDayDetail) { detail in
            PlanDayDetailSheet(detail: detail)
        }
        .onAppear {
            if !didInitializeDate {
                month = FinanceEngine.parseDate(store.todayIso)
                selectedDate = store.todayIso
                didInitializeDate = true
            }
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
        let days = calendarDays
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)

            // A month has at most six rows. Eager rows give the clipped swipe
            // container its complete height, including the final week.
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<(days.count / 7), id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(Array(days[(row * 7)..<(row * 7 + 7)])) { day in
                            dayCell(day)
                        }
                    }
                }
            }
            .dynamicTypeSize(.xSmall ... .xLarge)
        }
    }

    @ViewBuilder
    private func dayCell(_ day: PlanCalendarDay) -> some View {
        if let isoDate = day.isoDate {
            Button {
                handleDayTap(isoDate)
            } label: {
                VStack(spacing: 3) {
                    Text("\(day.dayNumber)")
                        .font(.caption.weight(day.isToday ? .bold : .semibold))
                        .foregroundStyle(dayTextColor(day))
                        .lineLimit(1)
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
                .contentShape(Rectangle())
                .opacity(day.isCurrentMonth ? 1 : 0.32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FinanceEngine.parseDate(isoDate).formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
            .accessibilityAddTraits(isoDate == selectedDate ? .isSelected : [])
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: PlanLayoutPolicy.dayCellHeight)
                .accessibilityHidden(true)
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
                    let headingLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.Spacing.sm))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: AppTheme.Spacing.sm))
                    headingLayout {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionTitle(selectedDate.formattedDayLabel)
                            Text("\(events.count) item\(events.count == 1 ? "" : "s") planned")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Button("View day") {
                            presentDayDetail(for: selectedDate)
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .frame(minHeight: 44)
                    }

                    CalendarMetricRow(label: "Money in", value: MoneyParser.formatPence(moneyIn), valueColor: AppTheme.Colors.success)
                    CalendarMetricRow(label: "Money out", value: MoneyParser.formatPence(moneyOut), valueColor: moneyOut > 0 ? AppTheme.Colors.warning : AppTheme.Colors.primaryText)
                    CalendarMetricRow(label: "Net change", value: MoneyParser.formatPence(net), valueColor: net < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)

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

    private var monthPresentation: CalendarMonthPresentation {
        let key = CalendarMonthPresentationKey(
            revision: PlannerPresentationRevision(
                accountId: store.activePlannerAccountId,
                snapshotRevision: store.snapshotRevision,
                todayIso: store.todayIso,
                selectedPayPeriodId: store.selectedPayPeriod?.id
            ),
            startDate: monthStart,
            endDate: monthEnd
        )
        return monthPresentationCache.value(for: key) {
            CalendarMonthPresentation.make(snapshot: store.snapshot, startDate: key.startDate, endDate: key.endDate)
        }
    }

    private var eventsByDate: [String: [CalendarEvent]] {
        monthPresentation.eventsByDate
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
        CalendarMetricRow(
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
                        CalendarMetricRow(label: "Money in", value: MoneyParser.formatPence(moneyIn), valueColor: AppTheme.Colors.success)
                        CalendarMetricRow(label: "Money out", value: MoneyParser.formatPence(moneyOut), valueColor: moneyOut > 0 ? AppTheme.Colors.warning : AppTheme.Colors.primaryText)
                        CalendarMetricRow(label: "Net change", value: MoneyParser.formatPence(moneyIn - moneyOut), valueColor: moneyIn - moneyOut < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
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

/// Calendar amounts keep their decimal digits together and move below a long
/// label when the current text size cannot fit both on one line.
struct CalendarMetricRow: View {
    var label: String
    var value: String
    var valueColor: Color = AppTheme.Colors.primaryText

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                labelText.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: AppTheme.Spacing.sm)
                valueText.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                labelText.fixedSize(horizontal: false, vertical: true)
                valueText
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var labelText: some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(AppTheme.Colors.secondaryText)
    }

    private var valueText: some View {
        Text(value)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(valueColor)
            .lineLimit(1)
    }
}
