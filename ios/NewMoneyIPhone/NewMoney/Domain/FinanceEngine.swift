import Foundation

enum FinanceEngine {
    private static func makeIsoFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func calculatePaycheckAmount(
        hoursWorked: Double,
        hourlyRatePence: Int,
        actualAmountPence: Int?
    ) -> Int {
        if let actualAmountPence {
            return actualAmountPence
        }

        return Int((hoursWorked * Double(hourlyRatePence)).rounded())
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
            return pot.balancePence + abs(transaction.amountPence)
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

    static func createNextPayPeriod(payday: String, frequency: PayFrequency) -> NextPayPeriod {
        let start = parseDate(payday)
        let days = frequencyToDays(frequency)
        let nextPayday = addDays(start, days: days)
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
        let activeDebts = debts.filter { $0.status == .active }
        let overdueDebtCount = activeDebts.filter { $0.dueDate < today }.count
        let current = activeDebts.reduce(0) { $0 + $1.currentBalancePence }
        let original = activeDebts.reduce(0) { $0 + $1.originalAmountPence }
        let paidFromBalances = max(0, original - current)
        let paidFromPayments = payments.reduce(0) { $0 + $1.amountPence }
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
        let start = parseDate(startDate)
        let end = parseDate(endDate)
        let days = utcCalendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    static func getDailySafeToSpendPence(spendablePence: Int, today: String, endDate: String) -> Int {
        spendablePence / getDaysInclusive(startDate: today, endDate: endDate)
    }

    static func isIsoDate(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    static func toIsoDate(_ date: Date) -> String {
        makeIsoFormatter().string(from: date)
    }

    static func addIsoDays(date: String, days: Int) -> String {
        toIsoDate(addDays(parseDate(date), days: days))
    }

    static func parseDate(_ value: String) -> Date {
        makeIsoFormatter().date(from: value) ?? Date(timeIntervalSince1970: 0)
    }

    static func addDays(_ date: Date, days: Int) -> Date {
        utcCalendar.date(byAdding: .day, value: days, to: date) ?? date
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
}
