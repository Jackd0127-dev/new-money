import Foundation

struct RecurringPaymentOccurrence: Identifiable, Equatable, Sendable {
    var id: String { "\(payment.id)-\(dueDate)" }
    var payment: RecurringPayment
    var dueDate: String
    var amountPence: Int
}

enum CalendarEventType: String, Sendable {
    case payday
    case recurring
    case savedPayment
    case spending
    case cardPayment
    case debtDue
    case debtReserve
    case debtPayment
    case allocation
}

struct CalendarEvent: Identifiable, Equatable, Sendable {
    var id: String
    var date: String
    var title: String
    var amountPence: Int?
    var type: CalendarEventType
    var detail: String
}

enum PlannerDerivedData {
    static func recurringOccurrences(payments: [RecurringPayment], startDate: String, endDate: String) -> [RecurringPaymentOccurrence] {
        payments
            .filter(\.active)
            .flatMap { payment in
                dueDates(for: payment, startDate: startDate, endDate: endDate).map {
                    RecurringPaymentOccurrence(payment: payment, dueDate: $0, amountPence: payment.amountPence)
                }
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return priorityRank($0.payment.priority) < priorityRank($1.payment.priority)
                }
                return $0.dueDate < $1.dueDate
            }
    }

    static func cardBalance(card: CreditCard, snapshot: PlannerSnapshot) -> Int {
        let opening = card.openingBalancePence ?? 0
        let cardSpending = snapshot.transactions
            .filter { $0.creditCardId == card.id && $0.paymentMethod == .creditCard }
            .reduce(0) { $0 + abs($1.amountPence) }
        let recurring = snapshot.recurringPayments
            .filter { $0.active && $0.creditCardId == card.id }
            .reduce(0) { $0 + $1.amountPence }
        let custom = snapshot.customPayments
            .filter { $0.status == .unpaid && $0.creditCardId == card.id }
            .reduce(0) { $0 + $1.amountPence }
        let repayments = snapshot.creditCardRepayments
            .filter { $0.creditCardId == card.id }
            .reduce(0) { $0 + $1.amountPence }
        let pots = snapshot.creditCardPots
            .filter { $0.creditCardId == card.id && $0.status == .active }
            .reduce(0) { $0 + $1.amountPence }

        return max(0, opening + cardSpending + recurring + custom - repayments - pots)
    }

    static func calendarEvents(snapshot: PlannerSnapshot, startDate: String, endDate: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        events += snapshot.payPeriods.flatMap { period in
            [
                CalendarEvent(id: "payday-\(period.id)", date: period.payday, title: "Payday", amountPence: period.incomePence, type: .payday, detail: "\(period.startDate) to \(period.endDate)"),
                CalendarEvent(id: "next-payday-\(period.id)", date: period.nextPayday, title: "Next payday", amountPence: nil, type: .payday, detail: "Next period starts"),
            ]
        }

        events += recurringOccurrences(payments: snapshot.recurringPayments, startDate: startDate, endDate: endDate).map {
            CalendarEvent(id: "recurring-\($0.id)", date: $0.dueDate, title: $0.payment.name, amountPence: $0.amountPence, type: .recurring, detail: "Recurring \($0.payment.frequency.rawValue)")
        }

        events += snapshot.customPayments.map {
            CalendarEvent(id: "custom-\($0.id)", date: $0.dueDate, title: $0.name, amountPence: $0.amountPence, type: .savedPayment, detail: $0.status.rawValue)
        }

        events += snapshot.transactions.map {
            CalendarEvent(id: "transaction-\($0.id)", date: $0.date, title: $0.note.isEmpty ? "Spending" : $0.note, amountPence: $0.amountPence, type: .spending, detail: $0.paymentMethod?.rawValue ?? $0.type.rawValue)
        }

        events += snapshot.debts.filter { $0.status == .active }.map {
            CalendarEvent(id: "debt-\($0.id)", date: $0.dueDate, title: $0.name, amountPence: $0.minimumPaymentPence, type: .debtDue, detail: $0.lender)
        }

        events += snapshot.debtReserves.map {
            CalendarEvent(id: "reserve-\($0.id)", date: $0.payday, title: "Debt reserve", amountPence: $0.amountPence, type: .debtReserve, detail: $0.status.rawValue)
        }

        events += snapshot.debtPayments.map {
            CalendarEvent(id: "debt-payment-\($0.id)", date: $0.date, title: "Debt payment", amountPence: $0.amountPence, type: .debtPayment, detail: $0.note)
        }

        events += snapshot.creditCardRepayments.map {
            CalendarEvent(id: "card-payment-\($0.id)", date: $0.date, title: "Card repayment", amountPence: $0.amountPence, type: .cardPayment, detail: $0.note)
        }

        events += snapshot.potAllocations.compactMap { allocation in
            guard let period = snapshot.payPeriods.first(where: { $0.id == allocation.payPeriodId }) else { return nil }
            let potName = snapshot.pots.first(where: { $0.id == allocation.potId })?.name ?? "Pot"
            return CalendarEvent(id: "allocation-\(allocation.id)", date: period.payday, title: "\(potName) allocation", amountPence: allocation.amountPence, type: .allocation, detail: allocation.source?.rawValue ?? "manual")
        }

        return events
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date == $1.date ? eventRank($0.type) < eventRank($1.type) : $0.date < $1.date }
    }

    private static func dueDates(for payment: RecurringPayment, startDate: String, endDate: String) -> [String] {
        switch payment.frequency {
        case .monthly:
            guard let dueDay = payment.dueDay else { return [] }
            return monthlyDueDates(dueDay: dueDay, startDate: startDate, endDate: endDate)
        case .yearly:
            guard let dueDate = payment.dueDate ?? payment.createdAt.prefixDate else { return [] }
            return yearlyDueDates(seedDate: dueDate, startDate: startDate, endDate: endDate)
        case .weekly:
            return intervalDueDates(seedDate: payment.dueDate ?? payment.createdAt.prefixDate, intervalDays: 7, startDate: startDate, endDate: endDate)
        case .biweekly:
            return intervalDueDates(seedDate: payment.dueDate ?? payment.createdAt.prefixDate, intervalDays: 14, startDate: startDate, endDate: endDate)
        }
    }

    private static func monthlyDueDates(dueDay: Int, startDate: String, endDate: String) -> [String] {
        let start = FinanceEngine.parseDate(startDate)
        let end = FinanceEngine.parseDate(endDate)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = calendar.dateComponents([.year, .month], from: start)
        components.day = 1
        var cursor = calendar.date(from: components) ?? start
        var dates: [String] = []

        while cursor <= end {
            let range = calendar.range(of: .day, in: .month, for: cursor)
            let lastDay = range?.count ?? 28
            var dueComponents = calendar.dateComponents([.year, .month], from: cursor)
            dueComponents.day = min(max(1, dueDay), lastDay)
            let date = calendar.date(from: dueComponents) ?? cursor
            let iso = FinanceEngine.toIsoDate(date)
            if iso >= startDate && iso <= endDate {
                dates.append(iso)
            }
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? end.addingTimeInterval(1)
        }

        return dates
    }

    private static func intervalDueDates(seedDate: String?, intervalDays: Int, startDate: String, endDate: String) -> [String] {
        guard let seedDate else { return [] }
        var cursor = FinanceEngine.parseDate(seedDate)
        let start = FinanceEngine.parseDate(startDate)
        let end = FinanceEngine.parseDate(endDate)

        while cursor < start {
            cursor = FinanceEngine.addDays(cursor, days: intervalDays)
        }

        var dates: [String] = []
        while cursor <= end {
            dates.append(FinanceEngine.toIsoDate(cursor))
            cursor = FinanceEngine.addDays(cursor, days: intervalDays)
        }
        return dates
    }

    private static func yearlyDueDates(seedDate: String, startDate: String, endDate: String) -> [String] {
        let seed = FinanceEngine.parseDate(seedDate)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let seedComponents = calendar.dateComponents([.month, .day], from: seed)
        let startYear = calendar.component(.year, from: FinanceEngine.parseDate(startDate))
        let endYear = calendar.component(.year, from: FinanceEngine.parseDate(endDate))

        return (startYear...endYear).compactMap { year in
            var components = DateComponents()
            components.calendar = calendar
            components.year = year
            components.month = seedComponents.month
            components.day = seedComponents.day
            guard let date = calendar.date(from: components) else { return nil }
            let iso = FinanceEngine.toIsoDate(date)
            return iso >= startDate && iso <= endDate ? iso : nil
        }
    }

    private static func priorityRank(_ priority: RecurringPriority) -> Int {
        switch priority {
        case .essential: 0
        case .important: 1
        case .optional: 2
        }
    }

    private static func eventRank(_ type: CalendarEventType) -> Int {
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
}

private extension String {
    var prefixDate: String? {
        let prefix = String(prefix(10))
        return FinanceEngine.isIsoDate(prefix) ? prefix : nil
    }
}
