import Foundation

enum FinanceEngine {
    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    static func calculatePaycheckAmount(
        hoursWorked: Double,
        hourlyRatePence: Int,
        actualAmountPence: Int?
    ) -> Int {
        validatedPaycheckAmount(hoursWorked: hoursWorked, hourlyRatePence: hourlyRatePence, actualAmountPence: actualAmountPence) ?? 0
    }

    static func validatedPaycheckAmount(hoursWorked: Double, hourlyRatePence: Int, actualAmountPence: Int?) -> Int? {
        if let actualAmountPence {
            return actualAmountPence
        }
        guard hoursWorked.isFinite else { return nil }
        return Int(exactly: (hoursWorked * Double(hourlyRatePence)).rounded())
    }

    static func formatPaydayLabel(_ isoDate: String) -> String {
        let date = parseDate(isoDate)
        let calendar = utcCalendar
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        return "\(ordinalDayLabel(day)) \(fullMonthLabel(month)) \(String(format: "%02d", year % 100))"
    }

    static func formatShortDateLabel(_ isoDate: String) -> String {
        let date = parseDate(isoDate)
        let calendar = utcCalendar
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        return "\(day) \(shortMonthLabel(month)) \(year)"
    }

    static func getAllocationBalance(
        incomePence: Int,
        reservedPence: Int,
        allocationPence: Int
    ) -> AllocationBalance {
        let availableAfterReservedPence = incomePence - reservedPence
        let remainingPence = availableAfterReservedPence - allocationPence

        return AllocationBalance(
            availableAfterReservedPence: availableAfterReservedPence,
            remainingPence: remainingPence,
            isOverAllocated: remainingPence < 0
        )
    }

    static func applyTransactionToPot(_ pot: Pot, amountPence: Int, type: TransactionType) -> Pot {
        var updated = pot
        let delta = type == .spending ? -abs(amountPence) : amountPence
        updated.balancePence += delta
        updated.updatedAt = DateUtilities.nowIsoString()
        return updated
    }

    static func getPotBalanceAfterTransactionRemoval(_ pot: Pot, transaction: Transaction) -> Int {
        switch transaction.type {
        case .spending:
            return pot.balancePence + transaction.netAmountPence
        case .allocation:
            return pot.balancePence - abs(transaction.amountPence)
        case .transfer, .adjustment:
            return pot.balancePence
        }
    }

    static func getAppTodayIso(settings: Settings?) -> String {
        if settings?.appDateMode == .manual,
           let manualTodayIso = settings?.manualTodayIso,
           isIsoDate(manualTodayIso) {
            return manualTodayIso
        }

        return toIsoDate(Date())
    }

    static func createNextPayPeriod(
        payday: String,
        frequency: PayFrequency,
        monthlyAnchorDay: Int? = nil
    ) -> NextPayPeriod {
        guard let start = validatedDate(payday) else {
            return NextPayPeriod(startDate: payday, endDate: payday, nextPayday: payday)
        }
        let nextPayday: Date
        if frequency == .monthly {
            let preferredDay = monthlyAnchorDay ?? utcCalendar.component(.day, from: start)
            nextPayday = addMonthsClamped(start, months: 1, preferredDay: preferredDay)
        } else {
            nextPayday = addDays(start, days: frequencyToDays(frequency))
        }
        let end = addDays(nextPayday, days: -1)

        return NextPayPeriod(
            startDate: toIsoDate(start),
            endDate: toIsoDate(end),
            nextPayday: toIsoDate(nextPayday)
        )
    }

    static func getTotalPence<T>(_ items: [T], amount: (T) -> Int) -> Int {
        items.reduce(0) { $0 + amount($1) }
    }

    static func getSpendablePence(pots: [Pot]) -> Int {
        pots
            .filter { !$0.archived && ($0.type == .spending || $0.type == .buffer) }
            .reduce(0) { $0 + $1.balancePence }
    }

    static func getLinkedCreditCardPotPence(pots: [Pot], creditCardId: String?) -> Int {
        guard let creditCardId else { return 0 }
        return pots
            .filter { !$0.archived && $0.linkedCreditCardId == creditCardId }
            .reduce(0) { $0 + max(0, $1.balancePence) }
    }

    static func getLinkedDebtPotPence(pots: [Pot], debtId: String?) -> Int {
        guard let debtId else { return 0 }
        return pots
            .filter { !$0.archived && $0.linkedDebtId == debtId }
            .reduce(0) { $0 + max(0, $1.balancePence) }
    }

    static func getDebtDueAmountPence(_ debt: Debt) -> Int {
        max(0, debt.currentBalancePence)
    }

    static func getPlannedDebtReservePence(reserves: [DebtReserve], debtId: String? = nil) -> Int {
        reserves
            .filter { $0.status == .planned && (debtId == nil || $0.debtId == debtId) }
            .reduce(0) { $0 + $1.amountPence }
    }

    static func getDebtDueAmountAfterReservesPence(debt: Debt, reserves: [DebtReserve]) -> Int {
        max(0, getDebtDueAmountPence(debt) - getPlannedDebtReservePence(reserves: reserves, debtId: debt.id))
    }

    static func getDebtDueAmountAfterReservesAndLinkedPotsPence(
        debt: Debt,
        reserves: [DebtReserve],
        pots: [Pot]
    ) -> Int {
        max(0, getDebtDueAmountAfterReservesPence(debt: debt, reserves: reserves) - getLinkedDebtPotPence(pots: pots, debtId: debt.id))
    }

    static func getUncoveredRecurringPence(
        payments: [RecurringPayment],
        allocations: [PotAllocation]
    ) -> Int {
        var directAllocationByPayment: [String: Int] = [:]
        var remainingAllocationByPot: [String: Int] = [:]

        for allocation in allocations {
            if let recurringPaymentId = allocation.recurringPaymentId {
                directAllocationByPayment[recurringPaymentId, default: 0] += allocation.amountPence
            } else {
                remainingAllocationByPot[allocation.potId, default: 0] += allocation.amountPence
            }
        }

        return payments.reduce(0) { total, payment in
            var total = total
            let directAvailablePence = directAllocationByPayment[payment.id, default: 0]
            let directCoveredPence = min(payment.amountPence, directAvailablePence)
            directAllocationByPayment[payment.id] = directAvailablePence - directCoveredPence
            let remainingPaymentPence = payment.amountPence - directCoveredPence

            guard remainingPaymentPence > 0 else { return total }

            guard let potId = payment.potId else {
                total += remainingPaymentPence
                return total
            }

            let availableInPot = remainingAllocationByPot[potId, default: 0]
            let coveredPence = min(remainingPaymentPence, availableInPot)
            remainingAllocationByPot[potId] = availableInPot - coveredPence
            total += remainingPaymentPence - coveredPence
            return total
        }
    }

    static func getPayPeriodMoneySummary(
        incomePence: Int,
        duePayments: [RecurringPayment],
        allocations: [PotAllocation]
    ) -> PayPeriodMoneySummary {
        let allocatedPence = allocations.reduce(0) { $0 + $1.amountPence }
        let uncoveredRecurringPence = getUncoveredRecurringPence(payments: duePayments, allocations: allocations)
        let totalPaymentsDuePence = allocatedPence + uncoveredRecurringPence
        let moneyLeftPence = incomePence - totalPaymentsDuePence

        return PayPeriodMoneySummary(
            payReceivedPence: incomePence,
            allocatedPence: allocatedPence,
            uncoveredRecurringPence: uncoveredRecurringPence,
            totalPaymentsDuePence: totalPaymentsDuePence,
            moneyLeftPence: moneyLeftPence,
            isOverCommitted: moneyLeftPence < 0
        )
    }

    static func getDebtSummary(
        debts: [Debt],
        payments: [DebtPayment],
        reserves: [DebtReserve],
        pots: [Pot],
        today: String
    ) -> DebtSummary {
        let activeDebts = debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 }
        let overdueDebtCount = activeDebts.filter { $0.status == .overdue || ($0.targetPayoffDate ?? $0.dueDate) < today }.count
        let current = activeDebts.reduce(0) { $0 + $1.currentBalancePence }
        let original = activeDebts.reduce(0) { $0 + $1.originalAmountPence }
        let paidFromBalances = max(0, original - current)
        let activeDebtIds = Set(activeDebts.map(\.id))
        let paidFromPayments = payments
            .filter { activeDebtIds.contains($0.debtId) && !$0.isRefunded }
            .reduce(0) { $0 + $1.netAmountPence }
        let due = activeDebts.reduce(0) { total, debt in
            total + getDebtDueAmountAfterReservesAndLinkedPotsPence(debt: debt, reserves: reserves, pots: pots)
        }
        let progress = original > 0 ? min(100, max(0, Double(paidFromBalances) / Double(original) * 100)) : 0

        return DebtSummary(
            activeDebtCount: activeDebts.count,
            overdueDebtCount: overdueDebtCount,
            totalCurrentBalancePence: current,
            totalOriginalAmountPence: original,
            totalPaidPence: max(paidFromBalances, paidFromPayments),
            debtDueThisPayPeriodPence: due,
            progressPercent: progress
        )
    }

    static func getDaysInclusive(startDate: String, endDate: String) -> Int {
        guard let start = validatedDate(startDate), let end = validatedDate(endDate) else { return 1 }
        let days = utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    static func getDailySafeToSpendPence(spendablePence: Int, today: String, endDate: String) -> Int {
        max(0, spendablePence) / getDaysInclusive(startDate: today, endDate: endDate)
    }

    static func isIsoDate(_ value: String) -> Bool {
        isoDateParts(value) != nil
    }

    /// Rejects impossible civil dates rather than normalizing them into another cycle.
    static func validatedDate(_ value: String) -> Date? {
        guard let parts = isoDateParts(value) else { return nil }
        return utcCalendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day))
    }

    private static func isoDateParts(_ value: String) -> (year: Int, month: Int, day: Int)? {
        let bytes = Array(value.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              [0, 1, 2, 3, 5, 6, 8, 9].allSatisfy({ (48...57).contains(bytes[$0]) })
        else { return nil }
        let year = bytes[0..<4].reduce(0) { $0 * 10 + Int($1 - 48) }
        let month = Int(bytes[5] - 48) * 10 + Int(bytes[6] - 48)
        let day = Int(bytes[8] - 48) * 10 + Int(bytes[9] - 48)
        guard year > 0, (1...12).contains(month) else { return nil }
        let leapYear = year.isMultiple(of: 4) && (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
        let daysInMonth = [31, leapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        guard (1...daysInMonth).contains(day) else { return nil }
        return (year, month, day)
    }

    static func toIsoDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func addIsoDays(date: String, days: Int) -> String {
        guard let parsed = validatedDate(date) else { return date }
        return toIsoDate(addDays(parsed, days: days))
    }

    static func monthlyDate(onOrAfter isoDate: String, day: Int) -> String {
        let calendar = utcCalendar
        guard let date = validatedDate(isoDate) else { return isoDate }
        let components = calendar.dateComponents([.year, .month], from: date)
        var year = components.year ?? 1970
        var month = components.month ?? 1
        var candidate = monthlyDate(year: year, month: month, day: day)

        if candidate < isoDate {
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
            candidate = monthlyDate(year: year, month: month, day: day)
        }

        return candidate
    }

    static func parseDate(_ value: String) -> Date {
        isoFormatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }

    static func dayOfMonth(_ isoDate: String) -> Int {
        utcCalendar.component(.day, from: parseDate(isoDate))
    }

    static func addDays(_ date: Date, days: Int) -> Date {
        utcCalendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMonthsClamped(_ date: Date, months: Int, preferredDay: Int) -> Date {
        let shifted = utcCalendar.date(byAdding: .month, value: months, to: date) ?? date
        let target = utcCalendar.dateComponents([.year, .month], from: shifted)
        return parseDate(monthlyDate(
            year: target.year ?? 1970,
            month: target.month ?? 1,
            day: preferredDay
        ))
    }

    static func frequencyToDays(_ frequency: PayFrequency) -> Int {
        switch frequency {
        case .weekly:
            return 7
        case .monthly:
            return 31
        case .biweekly, .custom:
            return 14
        }
    }

    private static func monthlyDate(year: Int, month: Int, day: Int) -> String {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.year = year
        components.month = month
        components.day = 1
        let firstOfMonth = utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let lastDay = utcCalendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 28
        components.day = min(max(1, day), lastDay)
        return toIsoDate(utcCalendar.date(from: components) ?? firstOfMonth)
    }

    private static func ordinalDayLabel(_ day: Int) -> String {
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

    private static func fullMonthLabel(_ month: Int) -> String {
        let months = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]
        guard months.indices.contains(month - 1) else { return "January" }
        return months[month - 1]
    }

    private static func shortMonthLabel(_ month: Int) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard months.indices.contains(month - 1) else { return "Jan" }
        return months[month - 1]
    }
}
