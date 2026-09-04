import SwiftUI

struct CalendarPlannerView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @State private var didInitializeDate = false
    @State private var month = Date()
    @State private var selectedDate = FinanceEngine.toIsoDate(Date())
    @State private var mode: CalendarDisplayMode = .calendar
    @State private var monthPresentationCache = RevisionPresentationCache<CalendarMonthPresentationKey, CalendarMonthPresentation>()

    var body: some View {
        ScreenScaffold(
            title: "Calendar",
            subtitle: "Money events by month.",
            navigationMode: navigationMode,
            toolbarMode: .actions([
                AppToolbarAction(id: "calendar-mode-toggle", symbol: "ellipsis.circle", accessibilityLabel: "Toggle Calendar View") {
                    withAnimation(AppTheme.Animation.standard) {
                        mode = mode == .calendar ? .list : .calendar
                    }
                }
            ])
        ) {
            calendarHeader
            if mode == .calendar {
                calendarGrid
                selectedDayDetails
            } else {
                agendaList
            }
        }
        .onAppear {
            if !didInitializeDate {
                month = FinanceEngine.parseDate(store.todayIso)
                selectedDate = store.todayIso
                didInitializeDate = true
            }
            if selectedDate < monthStart || selectedDate > monthEnd {
                selectedDate = monthStart
            }
        }
    }

    private var calendarHeader: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(mode == .calendar ? "Calendar view" : "List view")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                HStack(spacing: AppTheme.Spacing.sm) {
                    monthButton(direction: -1, label: "Previous month")
                    Spacer(minLength: 0)
                    Text("\(ordinalDay(selectedDate)) \(monthName(selectedDate))")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    monthButton(direction: 1, label: "Next month")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func monthButton(direction: Int, label: String) -> some View {
        Button {
            moveMonth(by: direction)
        } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryOrange)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private var calendarGrid: some View {
        let days = calendarDays
        return AppCard {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<(days.count / 7), id: \.self) { row in
                    HStack(spacing: 6) {
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
    private func dayCell(_ day: CalendarDay) -> some View {
        if let isoDate = day.isoDate {
            Button {
                withAnimation(AppTheme.Animation.standard) {
                    selectedDate = isoDate
                }
            } label: {
                VStack(spacing: 6) {
                    Text("\(day.dayNumber)")
                        .font(.subheadline.weight(day.isToday ? .bold : .semibold))
                        .foregroundStyle(dayTextColor(day))
                        .lineLimit(1)
                        .frame(width: 28, height: 28)
                        .background(dayBackground(day))
                        .clipShape(Circle())

                    HStack(spacing: 2) {
                        ForEach(Array(eventTypes(for: isoDate).prefix(3)), id: \.rawValue) { type in
                            Circle()
                                .fill(color(for: type))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Rectangle())
                .opacity(day.isCurrentMonth ? 1 : 0.32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FinanceEngine.parseDate(isoDate).formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
            .accessibilityAddTraits(isoDate == selectedDate ? .isSelected : [])
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 56)
                .accessibilityHidden(true)
        }
    }

    private var selectedDayDetails: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("\(weekdayName(selectedDate)), \(ordinalDay(selectedDate))")
            let dayEvents = eventsByDate[selectedDate] ?? []
            if dayEvents.isEmpty {
                AppCard {
                    EmptyStateView(title: "Nothing planned", message: "No finance events are scheduled for this day.", systemImage: "calendar")
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ForEach(dayEvents) { event in
                    calendarEventCard(event)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(AppTheme.Animation.standard, value: selectedDate)
    }

    private var agendaList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("This month")
            if groupedDates.isEmpty {
                AppCard {
                    EmptyStateView(title: "No events this month", message: "Paydays, bills, card payments, spending, and debts appear here.", systemImage: "calendar")
                }
            } else {
                ForEach(groupedDates, id: \.self) { date in
                    AppCard {
                        HStack(alignment: .firstTextBaseline) {
                            Pill(text: monthName(date), systemImage: nil, color: AppTheme.Colors.primaryOrange)
                            Spacer()
                            Text(ordinalDay(date))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }
                        ForEach(eventsByDate[date] ?? []) { event in
                            calendarEventLine(event)
                        }
                    }
                }
            }
        }
    }

    private func calendarEventCard(_ event: CalendarEvent) -> some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol(for: event.type))
                    .foregroundStyle(color(for: event.type))
                    .frame(width: 34, height: 34)
                    .background(color(for: event.type).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(eventSubtitle(event))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let amountPence = event.amountPence {
                Text(MoneyParser.formatPence(amountPence))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color(for: event.type))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func calendarEventLine(_ event: CalendarEvent) -> some View {
        CalendarMetricRow(
            label: "\(event.title) · \(eventTypeLabel(event.type))",
            value: event.amountPence.map { MoneyParser.formatPence($0) } ?? eventSubtitle(event),
            valueColor: color(for: event.type)
        )
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

    private var groupedDates: [String] {
        monthPresentation.eventDates
    }

    private var weekdaySymbols: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var calendarDays: [CalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = FinanceEngine.parseDate(monthStart)
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let weekday = calendar.component(.weekday, from: start)
        let leadingEmptyCount = (weekday + 5) % 7
        var days = (0..<leadingEmptyCount).map { CalendarDay(id: "blank-\($0)", date: nil, isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false) }

        days += dayRange.map { day in
            var components = calendar.dateComponents([.year, .month], from: start)
            components.day = day
            let date = calendar.date(from: components) ?? start
            let isoDate = FinanceEngine.toIsoDate(date)
            return CalendarDay(id: isoDate, date: date, isoDate: isoDate, dayNumber: day, isCurrentMonth: true, isToday: isoDate == store.todayIso)
        }

        while days.count % 7 != 0 {
            days.append(CalendarDay(id: "blank-\(days.count)", date: nil, isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false))
        }

        return days
    }

    private func moveMonth(by value: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        selectedDate = monthStart
    }

    private func eventTypes(for date: String) -> [CalendarEventType] {
        Array(Set(eventsByDate[date]?.map(\.type) ?? []))
            .sorted { eventRank($0) < eventRank($1) }
    }

    private func dayTextColor(_ day: CalendarDay) -> Color {
        guard let isoDate = day.isoDate else { return AppTheme.Colors.tertiaryText }
        if isoDate == selectedDate || day.isToday {
            return AppTheme.Colors.controlText
        }
        return AppTheme.Colors.primaryText
    }

    private func dayBackground(_ day: CalendarDay) -> AnyShapeStyle {
        guard let isoDate = day.isoDate else { return AnyShapeStyle(Color.clear) }
        if isoDate == selectedDate {
            return AnyShapeStyle(AppTheme.Gradients.primary)
        }
        if day.isToday {
            return AnyShapeStyle(AppTheme.Colors.primaryOrange.opacity(0.34))
        }
        return AnyShapeStyle(Color.clear)
    }

    private func eventSubtitle(_ event: CalendarEvent) -> String {
        switch event.type {
        case .payday:
            return event.amountPence == nil ? "Next period starts" : "Income lands"
        case .recurring:
            return event.detail.replacingOccurrences(of: "_", with: " ").capitalized
        case .savedPayment:
            return "Saved payment"
        case .spending:
            return event.detail.replacingOccurrences(of: "_", with: " ").capitalized
        case .cardPayment:
            return "Card repayment"
        case .debtDue:
            return event.detail
        case .debtReserve:
            return "Debt reserve"
        case .debtPayment:
            return event.detail.isEmpty ? "Debt payment" : event.detail
        case .allocation:
            return "Pot allocation"
        }
    }

    private func eventTypeLabel(_ type: CalendarEventType) -> String {
        switch type {
        case .payday: "Payday"
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

    private func symbol(for type: CalendarEventType) -> String {
        switch type {
        case .payday: "sterlingsign.circle"
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

    private func color(for type: CalendarEventType) -> Color {
        switch type {
        case .payday: AppTheme.Colors.success
        case .recurring, .savedPayment, .debtDue: AppTheme.Colors.warning
        case .cardPayment, .spending: AppTheme.Colors.orangeHighlight
        case .debtReserve, .debtPayment, .allocation: AppTheme.Colors.primaryOrange
        }
    }

    private func eventRank(_ type: CalendarEventType) -> Int {
        switch type {
        case .payday: 0
        case .recurring: 1
        case .savedPayment: 2
        case .debtDue: 3
        case .cardPayment: 4
        case .spending: 5
        case .debtReserve: 6
        case .debtPayment: 7
        case .allocation: 8
        }
    }

    private func ordinalDay(_ isoDate: String) -> String {
        let day = Calendar(identifier: .gregorian).component(.day, from: FinanceEngine.parseDate(isoDate))
        let suffix: String
        if (11...13).contains(day % 100) {
            suffix = "th"
        } else {
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    private func monthName(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.month(.abbreviated))
    }

    private func weekdayName(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.weekday(.wide))
    }

}

private enum CalendarDisplayMode {
    case calendar
    case list
}

private struct CalendarDay: Identifiable {
    var id: String
    var date: Date?
    var isoDate: String?
    var dayNumber: Int
    var isCurrentMonth: Bool
    var isToday: Bool
}

struct CalendarSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            CalendarPlannerView(store: store, navigationMode: .inline, toolbarMode: .none)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
