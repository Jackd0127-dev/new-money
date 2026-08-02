import Foundation

struct RecurringPaymentOccurrence: Identifiable, Equatable, Sendable {
    var id: String { "\(payment.id)-\(scheduledDueDate)" }
    var payment: RecurringPayment
    var scheduledDueDate: String
    var dueDate: String
    var amountPence: Int
    var isAwaitingPayment: Bool = false
}

enum HomeDueEventDirection: String, Equatable, Sendable {
    case incoming
    case outgoing
}

enum HomeDueEventStatus: String, Equatable, Sendable {
    case scheduled
    case awaiting
    case completed
}

enum HomeDueEventSource: Equatable, Sendable {
    case payday(payPeriodId: String, paycheckId: String?)
    case oneOffIncome(incomeId: String)
    case recurringBill(paymentId: String, scheduledDueDate: String)
    case savedPayment(paymentId: String)
    case debtPayment(scheduleItemId: String, debtId: String)
    case cardStatement(cardId: String, scheduledStatementDate: String)
    case cardDirectDebit(cardId: String, scheduledStatementDate: String)
}

struct HomeDueEvent: Identifiable, Equatable, Sendable {
    var id: String
    var scheduledDate: String
    var date: String
    var title: String
    var amountPence: Int
    var direction: HomeDueEventDirection
    var status: HomeDueEventStatus
    var sourceLabel: String
    var cycleLabel: String
    var source: HomeDueEventSource
}

struct PotProgress: Equatable, Sendable {
    var targetPence: Int
    var coveredPence: Int
    var percent: Int
    var targetLabel: String
    var sourceLabels: [String]
    var shortfallPence: Int
    var dueIso: String?
    var nextObligation: PotDueObligation?
    var laterObligation: PotDueObligation?
    var linkedCardPayments: [LinkedCardPaymentDue]
    var usesForecastTarget: Bool
}

enum PotDueObligationSource: Equatable, Sendable {
    case recurringBill
    case cardBill
    case cardOpeningBalance
    case cardSpend
    case debt
}

struct PotDueObligation: Equatable, Sendable {
    var amountPence: Int
    var dueIso: String
    var label: String
    var source: PotDueObligationSource
}

struct LinkedCardPaymentDue: Equatable, Sendable {
    var cardId: String
    var cardName: String
    var statementIso: String
    var dueIso: String
    var amountPence: Int
}

struct CreditCardOwedSummary: Equatable, Sendable {
    var actualOwedPence: Int
    var forecastOwedPence: Int
}

struct CreditCardAvailabilitySummary: Equatable, Sendable {
    var actualOwedPence: Int
    var forecastOwedPence: Int
    var actualAvailablePence: Int
    var forecastAvailablePence: Int
}

struct CreditCardStatementPayment: Equatable, Sendable {
    var statementDate: String
    var directDebitDate: String
    var actualDuePence: Int
    var forecastDuePence: Int
    var scheduledStatementDate: String? = nil
    var isHeld: Bool = false
}

struct CreditCardCycleAdjustmentSummary: Equatable, Sendable {
    var scheduledStatementDate: String
    var statementDate: String
    var directDebitDate: String
    var isStatementHeld: Bool
    var isDirectDebitHeld: Bool
}

struct CreditCardCycleReminder: Equatable, Sendable {
    var cardId: String
    var cardName: String
    var scheduledStatementDate: String
    var statementDate: String
    var directDebitDate: String
}

private struct CreditCardStatementCycle: Equatable, Sendable {
    var scheduledStatementDate: String
    var statementDate: String
    var directDebitDate: String
    var cycleStartDate: String
    var previousStatementDate: String?
    var isStatementHeld: Bool
    var isDirectDebitHeld: Bool

    var isHeld: Bool { isStatementHeld || isDirectDebitHeld }
}

enum FundingChecklistStatus: Equatable, Sendable {
    case needsFunding
    case activeReserved
    case paidCompleted
    case excluded
}

enum FundingChecklistAction: Equatable, Sendable {
    case recurringBill(paymentId: String, dueDate: String, payPeriodId: String)
    case cardBill(paymentId: String, dueDate: String, payPeriodId: String)
    case cardSpend(transactionId: String, payPeriodId: String)
    case cardOpeningBalance(cardId: String, directDebitDate: String, payPeriodId: String)
    case cardPayment(cardId: String, potId: String, directDebitDate: String, payPeriodId: String)
    case debt(debtId: String, dueDate: String, payPeriodId: String)
}

struct FundingChecklistPresentationItem: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var title: String
    var detail: String
    var amountPence: Int
    var dueDate: String
    var breakdown: [FundingChecklistBreakdownItem]
    var isCompleted: Bool
    var isExcluded: Bool
    var status: FundingChecklistStatus
    var paidDate: String?
    var action: FundingChecklistAction
}

struct FundingChecklistBreakdownItem: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var detail: String
    var amountPence: Int
}

struct CreditCardPaymentFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var cardId: String
    var cardName: String
    var amountPence: Int
    var directDebitDate: String
    var payPeriodId: String
    var potId: String
    var potName: String
    var isCompleted: Bool
}

enum CreditCardStatementStatus: Equatable, Sendable {
    case upcoming
    case paid
    case overdue
    case awaitingConfirmation
}

enum CreditCardStatementTransactionSource: Equatable, Sendable {
    case openingStatement
    case spending
    case recurring
    case custom
}

struct CreditCardStatementTransaction: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var date: String
    var amountPence: Int
    var source: CreditCardStatementTransactionSource
}

struct CreditCardStatementSummary: Identifiable, Equatable, Sendable {
    var id: String
    var cardId: String
    var cardName: String
    var statementDate: String
    var directDebitDate: String
    var statementAmountPence: Int
    var paidAmountPence: Int
    var unpaidAmountPence: Int
    var status: CreditCardStatementStatus
    var transactions: [CreditCardStatementTransaction]
}

struct CardBillFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var paymentId: String
    var paymentName: String
    var amountPence: Int
    var dueDate: String
    var fundingDueDate: String
    var payPeriodId: String
    var cardId: String
    var cardName: String
    var potId: String
    var potName: String
    var isCompleted: Bool
}

struct RecurringBillFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var paymentId: String
    var paymentName: String
    var amountPence: Int
    /// The charge date identifies the recurring occurrence and remains stable for
    /// allocations, refunds, and one-off occurrence corrections.
    var dueDate: String
    /// The date this amount must be funded. For card-linked bills this is the
    /// statement direct-debit date; for direct bills it is the charge date.
    var fundingDueDate: String
    var payPeriodId: String
    var cardId: String?
    var cardName: String?
    var potId: String
    var potName: String
    var isCompleted: Bool
}

struct CardSpendFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var transactionId: String
    var transactionName: String
    var amountPence: Int
    var transactionDate: String
    var dueDate: String
    var payPeriodId: String
    var cardId: String
    var cardName: String
    var potId: String
    var potName: String
    var isCompleted: Bool
}

struct CreditCardOpeningBalanceFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var cardId: String
    var cardName: String
    var amountPence: Int
    var directDebitDate: String
    var payPeriodId: String
    var potId: String
    var potName: String
    var isCompleted: Bool
}

struct DebtFundingChecklistItem: Identifiable, Equatable, Sendable {
    var id: String
    var scheduleItemId: String
    var debtId: String
    var debtName: String
    var lenderName: String
    var amountPence: Int
    var dueDate: String
    var payPeriodId: String
    var potId: String
    var potName: String
    var isCompleted: Bool
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

struct DebtPaymentApplication: Equatable, Sendable {
    var debt: Debt
    var scheduleItem: DebtPaymentScheduleItem?
    var payment: DebtPayment
}

enum DebtPlannerEngine {
    static func generateSchedule(for debt: Debt, payPeriods: [PayPeriod], today: String) -> [DebtPaymentScheduleItem] {
        guard debt.currentBalancePence > 0, debt.status != .archived, !debt.status.isPaidLike else { return [] }

        switch debt.repaymentStrategy {
        case .manualOnly:
            return []
        case .autoSpreadUntilDueDate:
            guard let targetPayoffDate = debt.targetPayoffDate ?? nonblank(debt.dueDate) else { return [] }
            let paymentDates = scheduledDates(
                from: today,
                through: targetPayoffDate,
                frequency: debt.paymentFrequency,
                paymentDay: debt.paymentDay ?? dayOfMonth(targetPayoffDate)
            )
            return buildSplitSchedule(debt: debt, dates: paymentDates, today: today)
        case .payIn4:
            let firstDate = firstPaymentDate(for: debt, payPeriods: payPeriods, today: today)
            let paymentDates = (0..<4).map { addMonthsClamped(date: firstDate, months: $0) }
            return buildSplitSchedule(debt: debt, dates: paymentDates, today: today)
        case .fixedPayment:
            return buildFixedSchedule(debt: debt, payPeriods: payPeriods, today: today, regularPaymentPence: max(0, debt.minimumPaymentPence))
        case .minimumPlusExtra:
            return buildFixedSchedule(debt: debt, payPeriods: payPeriods, today: today, regularPaymentPence: max(0, debt.minimumPaymentPence + debt.extraPaymentPence))
        }
    }

    static func estimatedInterestPence(balancePence: Int, aprBasisPoints: Int, days: Int) -> Int {
        guard balancePence > 0, aprBasisPoints > 0, days > 0 else { return 0 }
        let aprDecimal = Double(aprBasisPoints) / 10_000.0
        let dailyRate = pow(1.0 + aprDecimal, 1.0 / 365.0) - 1.0
        let interestPounds = (Double(balancePence) / 100.0) * (pow(1.0 + dailyRate, Double(days)) - 1.0)
        return max(0, Int((interestPounds * 100.0).rounded()))
    }

    static func hasInterestRisk(debt: Debt, paymentAmountPence: Int, days: Int) -> Bool {
        guard debt.interestType == .apr, let aprBasisPoints = debt.aprBasisPoints else { return false }
        return paymentAmountPence < estimatedInterestPence(balancePence: debt.currentBalancePence, aprBasisPoints: aprBasisPoints, days: days)
    }

    static func applyPayment(
        debt: Debt,
        scheduleItem: DebtPaymentScheduleItem?,
        amountPence: Int,
        date: String,
        sourcePotId: String?,
        paymentType: DebtPaymentType,
        note: String = ""
    ) -> DebtPaymentApplication {
        let requested = max(0, abs(amountPence))
        let outstandingFee = max(0, (scheduleItem?.feeAmountPence ?? 0) - (scheduleItem?.paidAmountPence ?? 0))
        var remaining = min(requested, max(0, debt.currentBalancePence + (scheduleItem?.interestAmountPence ?? 0) + outstandingFee))

        let feePaid = min(remaining, max(0, scheduleItem?.feeAmountPence ?? 0))
        remaining -= feePaid
        let interestPaid = min(remaining, max(0, scheduleItem?.interestAmountPence ?? 0))
        remaining -= interestPaid
        let principalPaid = min(remaining, max(0, debt.currentBalancePence))
        let applied = feePaid + interestPaid + principalPaid

        var updatedDebt = debt
        updatedDebt.currentBalancePence = max(0, debt.currentBalancePence - principalPaid)
        updatedDebt.status = updatedDebt.currentBalancePence == 0 ? .paidOff : .active
        updatedDebt.updatedAt = DateUtilities.nowIsoString()

        var updatedScheduleItem = scheduleItem
        if var item = updatedScheduleItem {
            item.paidAmountPence = min(item.plannedAmountPence, item.paidAmountPence + applied)
            item.fundedAmountPence = max(0, item.fundedAmountPence - applied)
            item.paidDate = item.paidAmountPence >= item.plannedAmountPence ? date : item.paidDate
            item.status = item.paidAmountPence >= item.plannedAmountPence ? .paid : .partFunded
            item.updatedAt = DateUtilities.nowIsoString()
            updatedScheduleItem = item
        }

        let payment = DebtPayment(
            id: scheduleItem.map { "linked-debt-pot-payment-\($0.debtId)-\($0.dueDate)" } ?? DateUtilities.newId(prefix: "debt-payment"),
            debtId: debt.id,
            amountPence: applied,
            date: date,
            note: note,
            createdAt: DateUtilities.nowIsoString(),
            updatedAt: DateUtilities.nowIsoString(),
            deletedAt: nil,
            sourcePotId: sourcePotId,
            paymentType: paymentType,
            scheduleItemId: scheduleItem?.id,
            principalPaidPence: principalPaid,
            interestPaidPence: interestPaid,
            feePaidPence: feePaid
        )

        return DebtPaymentApplication(debt: updatedDebt, scheduleItem: updatedScheduleItem, payment: payment)
    }

    static func recalculateSchedule(
        afterExtraPaymentPence extraPaymentPence: Int,
        debt: Debt,
        scheduleItems: [DebtPaymentScheduleItem],
        mode: DebtRecalculationMode,
        payPeriods: [PayPeriod],
        today: String
    ) -> [DebtPaymentScheduleItem] {
        let unpaidItems = scheduleItems
            .filter { $0.debtId == debt.id && $0.status != .paid && $0.status != .cancelled }
            .sorted { $0.dueDate == $1.dueDate ? $0.id < $1.id : $0.dueDate < $1.dueDate }
        guard !unpaidItems.isEmpty else { return [] }

        let remainingTotal = max(0, unpaidItems.reduce(0) { $0 + $1.plannedAmountPence } - max(0, extraPaymentPence))
        guard remainingTotal > 0 else {
            return unpaidItems.map { item in
                var item = item
                item.status = .cancelled
                item.plannedAmountPence = 0
                item.principalAmountPence = 0
                item.interestAmountPence = 0
                item.feeAmountPence = 0
                return item
            }
        }

        switch mode {
        case .lowerFuturePayments:
            if debt.repaymentStrategy == .payIn4 {
                return lowerFinalPayment(total: remainingTotal, items: unpaidItems)
            }
            let split = splitPence(remainingTotal, count: unpaidItems.count)
            return zip(unpaidItems, split).map { item, amount in
                scheduleItem(from: item, amountPence: amount, interestPence: 0, feePence: 0)
            }
        case .finishEarlier:
            var remaining = remainingTotal
            var result: [DebtPaymentScheduleItem] = []
            for item in unpaidItems {
                guard remaining > 0 else { break }
                let amount = min(item.plannedAmountPence, remaining)
                result.append(scheduleItem(from: item, amountPence: amount, interestPence: 0, feePence: 0))
                remaining -= amount
            }
            return result
        case .skipNextPayment:
            var items = unpaidItems
            if !items.isEmpty {
                items[0].status = .cancelled
            }
            let activeItems = Array(items.dropFirst())
            let split = splitPence(remainingTotal, count: max(1, activeItems.count))
            return [items[0]] + zip(activeItems, split).map { item, amount in
                scheduleItem(from: item, amountPence: amount, interestPence: 0, feePence: 0)
            }
        }
    }

    static func snapshot(for debt: Debt, scheduleItems: [DebtPaymentScheduleItem], payments: [DebtPayment], date: String) -> DebtSnapshot {
        let dayPayments = payments.filter { $0.debtId == debt.id && $0.date == date }
        let paymentsMade = dayPayments.reduce(0) { $0 + $1.amountPence }
        let interest = dayPayments.reduce(0) { $0 + $1.interestPaidPence }
        let remainingScheduled = scheduleItems
            .filter { $0.debtId == debt.id && $0.status != .paid && $0.status != .cancelled }
            .reduce(0) { $0 + max(0, $1.plannedAmountPence - $1.paidAmountPence) }
        return DebtSnapshot(
            date: date,
            debtId: debt.id,
            openingBalancePence: debt.currentBalancePence + dayPayments.reduce(0) { $0 + $1.principalPaidPence },
            interestAccruedPence: interest,
            paymentsMadePence: paymentsMade,
            closingBalancePence: debt.currentBalancePence,
            remainingScheduledAmountPence: remainingScheduled,
            status: debt.status
        )
    }

    private static func buildSplitSchedule(debt: Debt, dates: [String], today: String) -> [DebtPaymentScheduleItem] {
        let cleanDates = dates.filter { $0 >= today }.uniqued()
        guard !cleanDates.isEmpty else { return [] }
        let feeTotal = debt.interestType == .fixedFee ? debt.fixedFeePence : 0
        let interestTotal = estimatedInterestTotal(debt: debt, dates: cleanDates, today: today)
        let total = debt.currentBalancePence + feeTotal + interestTotal
        let amounts = splitPence(total, count: cleanDates.count)
        var remainingPrincipal = debt.currentBalancePence
        var remainingInterest = interestTotal
        var remainingFee = feeTotal

        return zip(cleanDates, amounts).map { date, amount in
            let fee = min(remainingFee, amount)
            remainingFee -= fee
            let interest = min(remainingInterest, max(0, amount - fee))
            remainingInterest -= interest
            let principal = min(remainingPrincipal, max(0, amount - fee - interest))
            remainingPrincipal -= principal
            return scheduleItem(id: scheduleItemId(debtId: debt.id, dueDate: date), debtId: debt.id, dueDate: date, amountPence: amount, principalPence: principal, interestPence: interest, feePence: fee)
        }
    }

    private static func buildFixedSchedule(debt: Debt, payPeriods: [PayPeriod], today: String, regularPaymentPence: Int) -> [DebtPaymentScheduleItem] {
        guard regularPaymentPence > 0 else { return [] }
        var items: [DebtPaymentScheduleItem] = []
        var balance = debt.currentBalancePence
        var previousDate = today
        var dueDate = firstPaymentDate(for: debt, payPeriods: payPeriods, today: today)
        var index = 0

        while balance > 0 && index < 600 {
            let days = max(1, FinanceEngine.getDaysInclusive(startDate: previousDate, endDate: dueDate))
            let interest = debt.interestType == .apr ? estimatedInterestPence(balancePence: balance, aprBasisPoints: debt.aprBasisPoints ?? 0, days: days) : 0
            let fee = debt.interestType == .fixedFee && index == 0 ? debt.fixedFeePence : 0
            let planned = min(max(regularPaymentPence, interest + fee), balance + interest + fee)
            let principal = max(0, min(balance, planned - interest - fee))
            items.append(scheduleItem(id: scheduleItemId(debtId: debt.id, dueDate: dueDate), debtId: debt.id, dueDate: dueDate, amountPence: planned, principalPence: principal, interestPence: min(interest, planned), feePence: min(fee, planned)))
            guard principal > 0 else { break }
            balance -= principal
            previousDate = dueDate
            dueDate = nextDate(after: dueDate, frequency: debt.paymentFrequency, paymentDay: debt.paymentDay)
            index += 1
        }

        return items
    }

    private static func estimatedInterestTotal(debt: Debt, dates: [String], today: String) -> Int {
        guard debt.interestType == .apr, let aprBasisPoints = debt.aprBasisPoints else { return 0 }
        var total = 0
        var previousDate = today
        let remainingPrincipal = debt.currentBalancePence
        for date in dates {
            let days = max(1, FinanceEngine.getDaysInclusive(startDate: previousDate, endDate: date))
            let interest = estimatedInterestPence(balancePence: remainingPrincipal, aprBasisPoints: aprBasisPoints, days: days)
            total += interest
            previousDate = date
        }
        return total
    }

    private static func firstPaymentDate(for debt: Debt, payPeriods: [PayPeriod], today: String) -> String {
        switch debt.payFirstTiming {
        case .today:
            return today
        case .customDate:
            if let customDate = debt.customFirstPaymentDate, customDate >= today {
                return customDate
            }
        case .nextPayday:
            if let payday = payPeriods.map(\.payday).filter({ $0 >= today }).sorted().first {
                return payday
            }
        }

        if let paymentDay = debt.paymentDay {
            return nextDayOfMonth(day: paymentDay, onOrAfter: today)
        }
        return today
    }

    private static func scheduledDates(from today: String, through targetDate: String, frequency: DebtPaymentFrequency, paymentDay: Int?) -> [String] {
        guard targetDate >= today else { return [targetDate] }
        var dates: [String] = []
        var cursor = paymentDay.map { nextDayOfMonth(day: $0, onOrAfter: today) } ?? today
        while cursor <= targetDate && dates.count < 600 {
            dates.append(cursor)
            cursor = nextDate(after: cursor, frequency: frequency, paymentDay: paymentDay)
        }
        if dates.last != targetDate {
            dates.append(targetDate)
        }
        return dates
    }

    private static func nextDate(after date: String, frequency: DebtPaymentFrequency, paymentDay: Int?) -> String {
        switch frequency {
        case .weekly:
            return FinanceEngine.addIsoDays(date: date, days: 7)
        case .fortnightly:
            return FinanceEngine.addIsoDays(date: date, days: 14)
        case .monthly, .custom:
            if let paymentDay {
                return nextDayOfMonth(day: paymentDay, onOrAfter: FinanceEngine.addIsoDays(date: date, days: 1))
            }
            return addMonthsClamped(date: date, months: 1)
        }
    }

    private static func splitPence(_ totalPence: Int, count: Int) -> [Int] {
        guard count > 0, totalPence > 0 else { return [] }
        let base = totalPence / count
        let remainder = totalPence % count
        return (0..<count).map { index in base + (index < remainder ? 1 : 0) }
    }

    private static func lowerFinalPayment(total: Int, items: [DebtPaymentScheduleItem]) -> [DebtPaymentScheduleItem] {
        guard !items.isEmpty else { return [] }
        let prefixTotal = items.dropLast().reduce(0) { $0 + $1.plannedAmountPence }
        if prefixTotal >= total {
            return Array(items.dropLast()).reduce(into: (remaining: total, result: [DebtPaymentScheduleItem]())) { state, item in
                guard state.remaining > 0 else { return }
                let amount = min(item.plannedAmountPence, state.remaining)
                state.result.append(scheduleItem(from: item, amountPence: amount, interestPence: 0, feePence: 0))
                state.remaining -= amount
            }.result
        }
        var result = Array(items.dropLast())
        if let last = items.last {
            result.append(scheduleItem(from: last, amountPence: max(0, total - prefixTotal), interestPence: 0, feePence: 0))
        }
        return result
    }

    private static func scheduleItem(from item: DebtPaymentScheduleItem, amountPence: Int, interestPence: Int, feePence: Int) -> DebtPaymentScheduleItem {
        var item = item
        item.plannedAmountPence = max(0, amountPence)
        item.interestAmountPence = max(0, min(interestPence, amountPence))
        item.feeAmountPence = max(0, min(feePence, amountPence - item.interestAmountPence))
        item.principalAmountPence = max(0, amountPence - item.interestAmountPence - item.feeAmountPence)
        item.fundedAmountPence = min(item.fundedAmountPence, item.plannedAmountPence)
        item.updatedAt = DateUtilities.nowIsoString()
        return item
    }

    private static func scheduleItem(id: String, debtId: String, dueDate: String, amountPence: Int, principalPence: Int, interestPence: Int, feePence: Int) -> DebtPaymentScheduleItem {
        DebtPaymentScheduleItem(
            id: id,
            debtId: debtId,
            dueDate: dueDate,
            plannedAmountPence: max(0, amountPence),
            principalAmountPence: max(0, principalPence),
            interestAmountPence: max(0, interestPence),
            feeAmountPence: max(0, feePence),
            fundedAmountPence: 0,
            paidAmountPence: 0,
            paidDate: nil,
            status: .planned,
            createdAt: DateUtilities.nowIsoString(),
            updatedAt: DateUtilities.nowIsoString(),
            deletedAt: nil
        )
    }

    private static func scheduleItemId(debtId: String, dueDate: String) -> String {
        "debt-schedule-\(debtId)-\(dueDate)"
    }

    private static func addMonthsClamped(date: String, months: Int) -> String {
        let parsed = FinanceEngine.parseDate(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let next = calendar.date(byAdding: .month, value: months, to: parsed) ?? parsed
        return FinanceEngine.toIsoDate(next)
    }

    private static func nextDayOfMonth(day: Int, onOrAfter today: String) -> String {
        let clampedDay = min(max(1, day), 31)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let todayDate = FinanceEngine.parseDate(today)
        var components = calendar.dateComponents([.year, .month], from: todayDate)
        components.day = min(clampedDay, lastDayOfMonth(year: components.year ?? 1970, month: components.month ?? 1))
        var candidate = calendar.date(from: components) ?? todayDate
        if FinanceEngine.toIsoDate(candidate) < today {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: todayDate) ?? todayDate
            components = calendar.dateComponents([.year, .month], from: nextMonth)
            components.day = min(clampedDay, lastDayOfMonth(year: components.year ?? 1970, month: components.month ?? 1))
            candidate = calendar.date(from: components) ?? nextMonth
        }
        return FinanceEngine.toIsoDate(candidate)
    }

    private static func dayOfMonth(_ isoDate: String) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.component(.day, from: FinanceEngine.parseDate(isoDate))
    }

    private static func lastDayOfMonth(year: Int, month: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = DateComponents()
        components.year = year
        components.month = month + 1
        components.day = 0
        let date = calendar.date(from: components) ?? Date()
        return calendar.component(.day, from: date)
    }

    private static func nonblank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

enum CurrentMoneyComponentKind: String, Equatable, Sendable {
    case bankAccount
    case pot
    case cardReserve
    case unlinkedIncome
}

struct CurrentMoneyComponent: Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var detail: String
    var amountPence: Int
    var kind: CurrentMoneyComponentKind
}

struct CurrentMoneyBreakdown: Equatable, Sendable {
    var components: [CurrentMoneyComponent]
    var includesPots: Bool

    var totalPence: Int {
        components.reduce(0) { $0 + $1.amountPence }
    }
}

enum PlannerDerivedData {
    static func bankAccountBalance(account: BankAccount, snapshot: PlannerSnapshot) -> Int {
        account.openingBalancePence + bankAccountNetMovementPence(accountId: account.id, snapshot: snapshot)
    }

    /// The cash the user has right now across every tracked balance.
    ///
    /// Linked income and spends are already reflected in bank-account balances,
    /// while pot funding moves cash from its source into the pot. The remaining
    /// income balance therefore only includes income that is not linked to a bank
    /// account, less cash movements that came directly from that balance.
    static func currentTotalMoneyPence(snapshot: PlannerSnapshot, payPeriod: PayPeriod?) -> Int {
        currentMoneyBreakdown(snapshot: snapshot, payPeriod: payPeriod).totalPence
    }

    static func currentMoneyBreakdown(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?
    ) -> CurrentMoneyBreakdown {
        let includesPots = snapshot.settings.includePotsInMoneyLeft ?? true
        let bankComponents = snapshot.bankAccounts
            .filter { !$0.archived && $0.deletedAt == nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { account in
                CurrentMoneyComponent(
                    id: "bank-\(account.id)",
                    title: account.name,
                    detail: account.provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "\(account.type.displayName) account"
                        : account.provider,
                    amountPence: bankAccountBalance(account: account, snapshot: snapshot),
                    kind: .bankAccount
                )
            }
        let potComponents = snapshot.pots
            .filter { !$0.archived }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { pot in
                CurrentMoneyComponent(
                    id: "pot-\(pot.id)",
                    title: pot.name,
                    detail: "\(pot.type.rawValue.capitalized) pot",
                    amountPence: pot.balancePence,
                    kind: .pot
                )
            }
        let activeCreditCardPots = snapshot.creditCardPots.filter {
            $0.deletedAt == nil && $0.status == .active
        }
        let cardReserveComponents = activeCreditCardPots
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { reserve in
                CurrentMoneyComponent(
                    id: "card-reserve-\(reserve.id)",
                    title: reserve.name,
                    detail: "Card reserve",
                    amountPence: max(0, reserve.amountPence),
                    kind: .cardReserve
                )
            }
        var components = bankComponents
        if includesPots {
            components += potComponents
            components += cardReserveComponents
        }

        guard let payPeriod else {
            return CurrentMoneyBreakdown(components: components, includesPots: includesPots)
        }

        let currentPaychecks = snapshot.paychecks.filter {
            $0.deletedAt == nil && $0.payPeriodId == payPeriod.id
        }
        let unlinkedPaycheckIncomePence: Int
        if currentPaychecks.isEmpty {
            // Older snapshots and deterministic fixtures can retain period income
            // without a separate paycheck record.
            unlinkedPaycheckIncomePence = max(0, payPeriod.incomePence)
        } else {
            unlinkedPaycheckIncomePence = currentPaychecks
                .filter { $0.bankAccountId == nil }
                .reduce(0) {
                    let override = incomeOccurrenceOverride(
                        snapshot: snapshot,
                        kind: .paycheck,
                        sourceId: $1.id,
                        scheduledDate: payPeriod.payday
                    )
                    guard override?.state != .awaiting, override?.state != .cancelled else { return $0 }
                    return $0 + max(0, override?.amountPenceOverride ?? $1.actualAmountPence ?? $1.calculatedAmountPence)
                }
        }

        let unlinkedOneOffIncomePence = snapshot.oneOffIncomes
            .filter {
                let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .oneOffIncome, sourceId: $0.id, scheduledDate: $0.date)
                let effectiveDate = effectiveIncomeDate(override: override, scheduledDate: $0.date)
                return $0.deletedAt == nil &&
                $0.bankAccountId == nil &&
                override?.state != .awaiting &&
                override?.state != .cancelled &&
                isIsoDate(effectiveDate, in: payPeriod)
            }
            .reduce(0) {
                let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .oneOffIncome, sourceId: $1.id, scheduledDate: $1.date)
                return $0 + max(0, override?.amountPenceOverride ?? $1.amountPence)
            }

        let incomeFundedSpendingPence = snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.paymentMethod == .income &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let unlinkedPotFundingPence = snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.payPeriodId == payPeriod.id &&
                $0.bankAccountId == nil &&
                $0.fundingPotId == nil
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let paycheckFundedCreditCardPotsPence = activeCreditCardPots
            .filter {
                $0.source == .paycheck &&
                ($0.payPeriodId == payPeriod.id ||
                    ($0.periodStartDate == payPeriod.startDate && $0.periodEndDate == payPeriod.endDate))
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let unlinkedDebtPaymentsPence = snapshot.debtPayments
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.sourcePotId == nil &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let paycheckFundedCardRepaymentsPence = snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, creditCardRepaymentPaycheckContribution($1)) }

        let unlinkedIncomeBalancePence =
            unlinkedPaycheckIncomePence +
            unlinkedOneOffIncomePence -
            incomeFundedSpendingPence -
            unlinkedPotFundingPence -
            paycheckFundedCreditCardPotsPence -
            unlinkedDebtPaymentsPence -
            paycheckFundedCardRepaymentsPence

        if unlinkedIncomeBalancePence != 0 {
            components.append(
                CurrentMoneyComponent(
                    id: "unlinked-income-\(payPeriod.id)",
                    title: "Unlinked income",
                    detail: "Current period after direct spending and transfers",
                    amountPence: unlinkedIncomeBalancePence,
                    kind: .unlinkedIncome
                )
            )
        }

        return CurrentMoneyBreakdown(components: components, includesPots: includesPots)
    }

    static func bankAccountNetMovementPence(accountId: String, snapshot: PlannerSnapshot) -> Int {
        let paycheckIncome = snapshot.paychecks.reduce(0) { total, paycheck in
            guard paycheck.deletedAt == nil, paycheck.bankAccountId == accountId else { return total }
            let payday = snapshot.payPeriods.first { $0.id == paycheck.payPeriodId }?.payday ?? String(paycheck.createdAt.prefix(10))
            let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .paycheck, sourceId: paycheck.id, scheduledDate: payday)
            guard override?.state != .awaiting, override?.state != .cancelled else { return total }
            return total + max(0, override?.amountPenceOverride ?? paycheck.actualAmountPence ?? paycheck.calculatedAmountPence)
        }
        let oneOffIncome = snapshot.oneOffIncomes.reduce(0) { total, income in
            guard income.deletedAt == nil, income.bankAccountId == accountId else { return total }
            let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .oneOffIncome, sourceId: income.id, scheduledDate: income.date)
            guard override?.state != .awaiting, override?.state != .cancelled else { return total }
            return total + max(0, override?.amountPenceOverride ?? income.amountPence)
        }
        let fundedPots = snapshot.potAllocations.reduce(0) { total, allocation in
            guard allocation.deletedAt == nil, allocation.bankAccountId == accountId else { return total }
            return total + max(0, allocation.amountPence)
        }
        let bankTransactions = snapshot.transactions.reduce(0) { total, transaction in
            guard transaction.deletedAt == nil,
                  !transaction.isRefunded,
                  transaction.bankAccountId == accountId
            else { return total }

            switch transaction.type {
            case .spending:
                return total + max(0, transaction.amountPence)
            case .allocation:
                return total + max(0, transaction.amountPence)
            case .transfer, .adjustment:
                return total
            }
        }

        return paycheckIncome + oneOffIncome - fundedPots - bankTransactions
    }

    static func creditCardDirectDebitDate(statementDate: String, dueDay: Int) -> String {
        creditCardDirectDebitDateCore(statementDate: statementDate, dueDay: dueDay)
    }

    static func creditCardOpeningBalanceDirectDebitDate(card: CreditCard, today: String) -> String? {
        creditCardOpeningBalanceDirectDebitDateCore(card: card, today: today)
    }

    static func addIsoMonthsClamped(date: String, months: Int) -> String {
        addIsoMonthsClampedCore(date: date, months: months)
    }

    static func potProgress(pot: Pot, snapshot: PlannerSnapshot, today: String) -> PotProgress {
        var sourceLabels: [String] = []
        var linkedTargetPence = 0
        var dueIso: String?
        var usesForecastTarget = false
        let payPeriod = currentOrLatestPayPeriod(snapshot.payPeriods, today: today)

        let directRecurringBillItems = directRecurringBillTargetItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            today: today,
            potId: pot.id
        )
        let recurringTargetPence = directRecurringBillItems.reduce(0) { $0 + max(0, $1.amountPence) }

        if recurringTargetPence > 0 {
            linkedTargetPence += recurringTargetPence
            sourceLabels.append("Recurring")
            dueIso = minIsoDate(dueIso, directRecurringBillItems.map(\.dueDate).sorted().first)
        }

        if let cardId = pot.linkedCreditCardId {
            if let card = snapshot.creditCards.first(where: { $0.id == cardId && !$0.archived }) {
                let summary = creditCardOwedSummary(
                    card: card,
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    asOfDate: today
                )
                let cardUsesForecastTarget = summary.forecastOwedPence > summary.actualOwedPence
                let rawCardTargetPence = cardUsesForecastTarget ? summary.forecastOwedPence : summary.actualOwedPence
                let otherPotCardBillTargetPence = selectedCardRecurringBillTargetPence(
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    today: today,
                    cardId: cardId,
                    excludingPotId: pot.id
                )
                let cardTargetPence = max(0, rawCardTargetPence - otherPotCardBillTargetPence)
                let activeReserveTargetPence = activeLinkedCreditCardReserveTargetPence(
                    potId: pot.id,
                    cardId: cardId,
                    snapshot: snapshot,
                    asOfDate: today
                )
                let linkedCardTargetPence = max(cardTargetPence, activeReserveTargetPence)

                if linkedCardTargetPence > 0 {
                    linkedTargetPence += linkedCardTargetPence
                    usesForecastTarget = usesForecastTarget || cardUsesForecastTarget
                    sourceLabels.append("\(card.name) card")
                    dueIso = minIsoDate(dueIso, creditCardDueIso(card: card, today: today))
                }
            } else {
                sourceLabels.append("missing card \(cardId)")
            }
        }

        if pot.linkedCreditCardId == nil {
            let selectedCardBillTargetPence = selectedCardRecurringBillTargetPence(
                snapshot: snapshot,
                payPeriod: payPeriod,
                today: today,
                potId: pot.id
            )

            if selectedCardBillTargetPence > 0 {
                linkedTargetPence += selectedCardBillTargetPence
                sourceLabels.append("Card bills")
                dueIso = minIsoDate(
                    dueIso,
                    selectedCardRecurringBillDueDate(snapshot: snapshot, payPeriod: payPeriod, today: today, potId: pot.id)
                )
            }
        }

        if let debtId = pot.linkedDebtId,
           let debt = snapshot.debts.first(where: { $0.id == debtId && $0.status.isActiveLike }),
           debt.currentBalancePence > 0 {
            let targetItems = debtScheduleItems(snapshot: snapshot, payPeriod: payPeriod)
                .filter {
                    $0.debtId == debtId &&
                    $0.status != .paid &&
                    $0.status != .cancelled &&
                    $0.dueDate >= today
                }
            let targetPence = targetItems.reduce(0) { $0 + max(0, $1.plannedAmountPence - $1.paidAmountPence) }
            if targetPence > 0 {
                linkedTargetPence += targetPence
                sourceLabels.append("\(debt.name) debt")
                dueIso = minIsoDate(dueIso, targetItems.map(\.dueDate).sorted().first)
            }
        }

        let manualTargetPence = max(0, pot.targetPence ?? 0)
        let targetPence = linkedTargetPence > 0 ? linkedTargetPence : manualTargetPence
        let coveredPence = max(0, pot.balancePence)
        let shortfallPence = max(0, targetPence - coveredPence)
        let percent = targetPence > 0 ? Int((Double(coveredPence) / Double(targetPence) * 100).rounded()) : 0
        let obligations = potDueObligations(pot: pot, snapshot: snapshot, today: today)
        let linkedCardPayments = linkedCreditCardPayments(pot: pot, snapshot: snapshot, today: today)

        return PotProgress(
            targetPence: targetPence,
            coveredPence: coveredPence,
            percent: percent,
            targetLabel: targetPence > 0 ? "\(MoneyParser.formatPence(targetPence)) total target" : "No target yet",
            sourceLabels: sourceLabels,
            shortfallPence: shortfallPence,
            dueIso: dueIso,
            nextObligation: obligations.first,
            laterObligation: obligations.dropFirst().first,
            linkedCardPayments: linkedCardPayments,
            usesForecastTarget: usesForecastTarget
        )
    }

    static func creditCardOwedSummary(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String
    ) -> CreditCardOwedSummary {
        let rangeStart = payPeriod?.startDate ?? asOfDate
        let rangeEnd = payPeriod?.endDate ?? asOfDate
        let cardItems = creditCardAllocationItems(snapshot: snapshot, rangeStart: rangeStart, rangeEnd: rangeEnd)
            .filter { $0.creditCardId == card.id }
        let actualBalanceItems = actualCreditCardBalanceItems(card: card, transactions: snapshot.transactions, repayments: snapshot.creditCardRepayments, asOfDate: asOfDate)
        let actualOwedPence = max(0, (card.openingBalancePence ?? 0) + actualBalanceItems.reduce(0) { $0 + $1.amountPence })
        let forecastDeltaPence = forecastCreditCardItems(cardItems: cardItems, asOfDate: asOfDate).reduce(0) { $0 + $1.amountPence }
        let forecastOwedPence = max(0, actualOwedPence + forecastDeltaPence)

        return CreditCardOwedSummary(actualOwedPence: actualOwedPence, forecastOwedPence: forecastOwedPence)
    }

    static func totalCreditLimitPence(cards: [CreditCard]) -> Int {
        cards.reduce(0) { total, card in
            guard !card.archived else { return total }
            return total + max(0, card.limitPence)
        }
    }

    static func creditCardAvailabilitySummary(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String
    ) -> CreditCardAvailabilitySummary {
        let owed = creditCardOwedSummary(card: card, snapshot: snapshot, payPeriod: payPeriod, asOfDate: asOfDate)
        return CreditCardAvailabilitySummary(
            actualOwedPence: owed.actualOwedPence,
            forecastOwedPence: owed.forecastOwedPence,
            actualAvailablePence: card.limitPence - owed.actualOwedPence,
            forecastAvailablePence: card.limitPence - owed.forecastOwedPence
        )
    }

    static func recurringBillFundingChecklistItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        groupByFundingDueDate: Bool = false
    ) -> [RecurringBillFundingChecklistItem] {
        guard let payPeriod else { return [] }

        let activeCards = snapshot.creditCards
            .filter { !$0.archived }
            .reduce(into: [String: CreditCard]()) { result, card in
                result[card.id] = card
            }
        let activePots = snapshot.pots
            .filter { !$0.archived }
            .reduce(into: [String: Pot]()) { result, pot in
                result[pot.id] = pot
            }

        return resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments,
            startDate: groupByFundingDueDate
                ? FinanceEngine.addIsoDays(date: payPeriod.startDate, days: -62)
                : payPeriod.startDate,
            endDate: payPeriod.endDate
        )
        .compactMap { occurrence -> RecurringBillFundingChecklistItem? in
            guard let potId = occurrence.payment.potId,
                  let pot = activePots[potId],
                  occurrence.amountPence > 0
            else { return nil }

            let cardId = occurrence.payment.creditCardId
            let cardName: String?
            let fundingDueDate: String
            if let cardId {
                guard let card = activeCards[cardId] else { return nil }
                let directDebitDate = creditCardDirectDebitDate(
                    for: card,
                    snapshot: snapshot,
                    chargeDate: occurrence.dueDate
                )
                if groupByFundingDueDate {
                    guard let directDebitDate,
                          isIsoDate(directDebitDate, in: payPeriod)
                    else { return nil }
                    fundingDueDate = directDebitDate
                } else {
                    fundingDueDate = directDebitDate ?? occurrence.dueDate
                }
                cardName = card.name
            } else {
                guard isIsoDate(occurrence.dueDate, in: payPeriod) else { return nil }
                cardName = nil
                fundingDueDate = occurrence.dueDate
            }

            let fundedPence = snapshot.potAllocations
                .filter {
                    $0.deletedAt == nil &&
                    (groupByFundingDueDate || $0.payPeriodId == payPeriod.id) &&
                    $0.potId == potId &&
                    isRecurringBillFundingSource($0.source) &&
                    $0.recurringPaymentId == occurrence.payment.id &&
                    $0.recurringDueDate == occurrence.dueDate
                }
                .reduce(0) { $0 + max(0, $1.amountPence) }

            return RecurringBillFundingChecklistItem(
                id: recurringBillFundingChecklistId(paymentId: occurrence.payment.id, dueDate: occurrence.dueDate),
                paymentId: occurrence.payment.id,
                paymentName: occurrence.payment.name,
                amountPence: occurrence.amountPence,
                dueDate: occurrence.dueDate,
                fundingDueDate: fundingDueDate,
                payPeriodId: payPeriod.id,
                cardId: cardId,
                cardName: cardName,
                potId: potId,
                potName: pot.name,
                isCompleted: fundedPence >= occurrence.amountPence
            )
        }
    }

    static func recurringBillFundingChecklistId(paymentId: String, dueDate: String) -> String {
        "recurring-bill-funding-\(paymentId)-\(dueDate)"
    }

    static func cardBillFundingChecklistItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        groupByFundingDueDate: Bool = false
    ) -> [CardBillFundingChecklistItem] {
        recurringBillFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            groupByFundingDueDate: groupByFundingDueDate
        )
            .compactMap { item in
                guard let cardId = item.cardId,
                      let cardName = item.cardName
                else { return nil }

                return CardBillFundingChecklistItem(
                    id: cardBillFundingChecklistId(paymentId: item.paymentId, dueDate: item.dueDate),
                    paymentId: item.paymentId,
                    paymentName: item.paymentName,
                    amountPence: item.amountPence,
                    dueDate: item.dueDate,
                    fundingDueDate: item.fundingDueDate,
                    payPeriodId: item.payPeriodId,
                    cardId: cardId,
                    cardName: cardName,
                    potId: item.potId,
                    potName: item.potName,
                    isCompleted: item.isCompleted
                )
            }
    }

    static func cardBillFundingChecklistId(paymentId: String, dueDate: String) -> String {
        "card-bill-funding-\(paymentId)-\(dueDate)"
    }

    static func cardSpendFundingChecklistItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        groupByFundingDueDate: Bool = false
    ) -> [CardSpendFundingChecklistItem] {
        guard let payPeriod else { return [] }

        let activeCards = snapshot.creditCards
            .filter { !$0.archived }
            .reduce(into: [String: CreditCard]()) { result, card in
                result[card.id] = card
            }

        return snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.recurringPaymentId == nil &&
                (groupByFundingDueDate
                    ? $0.date <= payPeriod.endDate
                    : isIsoDate($0.date, in: payPeriod))
            }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.note < rhs.note
                }
                return lhs.date < rhs.date
            }
            .compactMap { transaction -> CardSpendFundingChecklistItem? in
                guard let cardId = transaction.creditCardId,
                      let card = activeCards[cardId],
                      let dueDate = creditCardDirectDebitDate(for: card, snapshot: snapshot, chargeDate: transaction.date)
                else { return nil }
                if groupByFundingDueDate, !isIsoDate(dueDate, in: payPeriod) {
                    return nil
                }

                let linkedPots = activeLinkedCreditCardPots(snapshot: snapshot, creditCardId: cardId)
                guard let fundingPot = linkedPots.first else { return nil }

                let matchingFundingPence = snapshot.potAllocations
                    .filter {
                        $0.deletedAt == nil &&
                        (groupByFundingDueDate || $0.payPeriodId == payPeriod.id) &&
                        $0.source == .cardSpendFunding &&
                        $0.transactionId == transaction.id
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let linkedPotBalancePence = linkedPots.reduce(0) { $0 + max(0, $1.balancePence) }
                let linkedPotIds = Set(linkedPots.map(\.id))
                let otherChecklistFundingPence = linkedCreditCardChecklistFundingPence(
                    snapshot: snapshot,
                    payPeriodId: groupByFundingDueDate ? nil : payPeriod.id,
                    linkedPotIds: linkedPotIds
                ) { allocation in
                    allocation.source == .cardSpendFunding && allocation.transactionId == transaction.id
                }
                let existingNonChecklistBalancePence = max(0, linkedPotBalancePence - matchingFundingPence - otherChecklistFundingPence)
                // An existing reserve may already have reduced the opening-balance
                // checklist item. Do not reuse that same money against every later
                // card-spend row, otherwise one transaction is split into a specific
                // row and a misleading residual card-payment row.
                let openingBalanceCoveragePence = openingBalanceGeneralCoveragePence(
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    cardId: cardId,
                    potId: fundingPot.id
                )
                let availableCardSpendCoveragePence = max(
                    0,
                    existingNonChecklistBalancePence - openingBalanceCoveragePence
                )
                let amountPence = max(0, transaction.amountPence - availableCardSpendCoveragePence)
                let transactionName = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)

                guard amountPence > 0 || matchingFundingPence > 0 else { return nil }

                return CardSpendFundingChecklistItem(
                    id: cardSpendFundingChecklistId(transactionId: transaction.id),
                    transactionId: transaction.id,
                    transactionName: transactionName.isEmpty ? "Card spending" : transactionName,
                    amountPence: amountPence,
                    transactionDate: transaction.date,
                    dueDate: dueDate,
                    payPeriodId: payPeriod.id,
                    cardId: cardId,
                    cardName: card.name,
                    potId: fundingPot.id,
                    potName: fundingPot.name,
                    isCompleted: amountPence > 0 && matchingFundingPence >= amountPence
                )
            }
    }

    static func cardSpendFundingChecklistId(transactionId: String) -> String {
        "card-spend-funding-\(transactionId)"
    }

    private static func openingBalanceGeneralCoveragePence(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod,
        cardId: String,
        potId: String
    ) -> Int {
        guard let card = snapshot.creditCards.first(where: { $0.id == cardId && !$0.archived }) else {
            return 0
        }

        let openingBalancePence = max(0, card.openingBalancePence ?? 0)
        let openingStatementPence = max(0, card.openingStatementBalancePence ?? openingBalancePence)
        let sourceAmountPence = openingStatementPence > 0
            ? openingStatementPence
            : (card.openingStatementBalancePence == 0 ? openingBalancePence : 0)
        guard sourceAmountPence > 0 else { return 0 }

        return cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter { $0.cardId == cardId && $0.potId == potId }
            .reduce(0) { total, item in
                total + max(0, sourceAmountPence - item.amountPence)
            }
    }

    static func cardOpeningBalanceFundingChecklistItems(snapshot: PlannerSnapshot, payPeriod: PayPeriod?) -> [CreditCardOpeningBalanceFundingChecklistItem] {
        guard let payPeriod else { return [] }

        return snapshot.creditCards
            .filter { !$0.archived }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
            .compactMap { card -> CreditCardOpeningBalanceFundingChecklistItem? in
                let openingBalancePence = max(0, card.openingBalancePence ?? 0)
                let openingStatementPence = max(0, card.openingStatementBalancePence ?? openingBalancePence)
                let today = FinanceEngine.getAppTodayIso(settings: snapshot.settings)
                guard let statementDate = card.statementDate,
                      FinanceEngine.isIsoDate(statementDate)
                else { return nil }

                let sourceAmountPence: Int
                let directDebitDate: String
                if openingStatementPence > 0,
                   let statementedDirectDebitDate = creditCardOpeningBalanceDirectDebitDate(card: card, today: today) {
                    sourceAmountPence = openingStatementPence
                    directDebitDate = statementedDirectDebitDate
                } else if openingBalancePence > 0,
                          card.openingStatementBalancePence == 0,
                          let dueDay = card.dueDay {
                    let projectedDirectDebitDate = creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
                    guard isIsoDate(statementDate, in: payPeriod) || isIsoDate(projectedDirectDebitDate, in: payPeriod) else { return nil }
                    sourceAmountPence = openingBalancePence
                    directDebitDate = projectedDirectDebitDate
                } else {
                    return nil
                }

                guard !snapshot.creditCardRepayments.contains(where: {
                    $0.deletedAt == nil &&
                    $0.creditCardId == card.id &&
                    $0.statementDate == statementDate &&
                    $0.amountPence > 0
                }) else { return nil }

                guard isIsoDate(directDebitDate, in: payPeriod) else { return nil }

                let linkedPots = activeLinkedCreditCardPots(snapshot: snapshot, creditCardId: card.id)
                guard let fundingPot = linkedPots.first else { return nil }

                let matchingFundingPence = snapshot.potAllocations
                    .filter {
                        $0.deletedAt == nil &&
                        $0.payPeriodId == payPeriod.id &&
                        $0.source == .cardOpeningBalanceFunding &&
                        $0.creditCardId == card.id &&
                        $0.creditCardDirectDebitDate == directDebitDate
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let linkedPotBalancePence = linkedPots.reduce(0) { $0 + max(0, $1.balancePence) }
                let linkedPotIds = Set(linkedPots.map(\.id))
                let otherChecklistFundingPence = linkedCreditCardChecklistFundingPence(
                    snapshot: snapshot,
                    payPeriodId: payPeriod.id,
                    linkedPotIds: linkedPotIds
                ) { allocation in
                    allocation.source == .cardOpeningBalanceFunding &&
                    allocation.creditCardId == card.id &&
                    allocation.creditCardDirectDebitDate == directDebitDate
                }
                let existingNonChecklistBalancePence = max(0, linkedPotBalancePence - matchingFundingPence - otherChecklistFundingPence)
                let amountPence = max(0, sourceAmountPence - existingNonChecklistBalancePence)

                guard amountPence > 0 || matchingFundingPence > 0 else { return nil }

                return CreditCardOpeningBalanceFundingChecklistItem(
                    id: cardOpeningBalanceFundingChecklistId(cardId: card.id, directDebitDate: directDebitDate),
                    cardId: card.id,
                    cardName: card.name,
                    amountPence: amountPence,
                    directDebitDate: directDebitDate,
                    payPeriodId: payPeriod.id,
                    potId: fundingPot.id,
                    potName: fundingPot.name,
                    isCompleted: amountPence > 0 && matchingFundingPence >= amountPence
                )
            }
    }

    static func cardOpeningBalanceFundingChecklistId(cardId: String, directDebitDate: String) -> String {
        "card-opening-balance-funding-\(cardId)-\(directDebitDate)"
    }

    static func cardPaymentFundingChecklistItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String,
        groupByFundingDueDate: Bool = false
    ) -> [CreditCardPaymentFundingChecklistItem] {
        guard let payPeriod else { return [] }

        return snapshot.creditCards
            .filter { !$0.archived }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name { return lhs.id < rhs.id }
                return lhs.name < rhs.name
            }
            .compactMap { card -> CreditCardPaymentFundingChecklistItem? in
                guard let pot = activeLinkedCreditCardPots(snapshot: snapshot, creditCardId: card.id).first else {
                    return nil
                }

                let matchingAllocations = snapshot.potAllocations.filter {
                    $0.deletedAt == nil &&
                    (groupByFundingDueDate
                        ? $0.creditCardDirectDebitDate.map { isIsoDate($0, in: payPeriod) } == true
                        : $0.payPeriodId == payPeriod.id) &&
                    $0.potId == pot.id &&
                    $0.source == .cardPaymentFunding &&
                    $0.creditCardId == card.id
                }
                let matchingFundingPence = matchingAllocations.reduce(0) { $0 + max(0, $1.amountPence) }
                let progress = potProgress(pot: pot, snapshot: snapshot, today: asOfDate)
                let periodStatementPayments = groupByFundingDueDate
                    ? creditCardStatementPayments(
                        card: card,
                        snapshot: snapshot,
                        startDate: payPeriod.startDate,
                        endDate: payPeriod.endDate,
                        asOfDate: asOfDate
                    )
                    : []
                let fundingTargetPence = groupByFundingDueDate
                    ? periodStatementPayments.reduce(0) {
                        $0 + max(max(0, $1.actualDuePence), max(0, $1.forecastDuePence))
                    }
                    : progress.targetPence
                let balanceBeforeThisFundingPence = max(0, pot.balancePence - matchingFundingPence)
                let pendingRecurringPence = recurringBillFundingChecklistItems(
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    groupByFundingDueDate: groupByFundingDueDate
                )
                    .filter {
                        $0.potId == pot.id &&
                        !$0.isCompleted &&
                        !isFundingChecklistExcluded(
                            snapshot: snapshot,
                            kind: $0.cardId == nil ? .recurringBill : .cardBill,
                            sourceId: $0.paymentId,
                            occurrenceDate: $0.dueDate,
                            payPeriodId: $0.payPeriodId,
                            matchAcrossPayPeriods: groupByFundingDueDate
                        )
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let pendingCardSpendPence = cardSpendFundingChecklistItems(
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    groupByFundingDueDate: groupByFundingDueDate
                )
                    .filter {
                        $0.potId == pot.id &&
                        !$0.isCompleted &&
                        !isFundingChecklistExcluded(
                            snapshot: snapshot,
                            kind: .cardSpend,
                            sourceId: $0.transactionId,
                            occurrenceDate: $0.transactionDate,
                            payPeriodId: $0.payPeriodId,
                            matchAcrossPayPeriods: groupByFundingDueDate
                        )
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let pendingOpeningPence = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                    .filter {
                        $0.potId == pot.id &&
                        !$0.isCompleted &&
                        !isFundingChecklistExcluded(
                            snapshot: snapshot,
                            kind: .cardOpeningBalance,
                            sourceId: $0.cardId,
                            occurrenceDate: $0.directDebitDate,
                            payPeriodId: $0.payPeriodId,
                            matchAcrossPayPeriods: groupByFundingDueDate
                        )
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let balanceAfterSpecificChecklistFundingPence = balanceBeforeThisFundingPence
                    + pendingRecurringPence
                    + pendingCardSpendPence
                    + pendingOpeningPence
                let requiredFundingPence = max(0, fundingTargetPence - balanceAfterSpecificChecklistFundingPence)
                let amountPence = max(matchingFundingPence, requiredFundingPence)

                guard amountPence > 0 else { return nil }

                let storedDueDate = matchingAllocations
                    .compactMap(\.creditCardDirectDebitDate)
                    .sorted()
                    .first
                let explicitCardPaymentDueDate = snapshot.customPayments
                    .filter {
                        $0.deletedAt == nil &&
                        $0.status == .unpaid &&
                        $0.creditCardId == card.id &&
                        $0.amountPence == fundingTargetPence &&
                        $0.dueDate >= asOfDate
                    }
                    .sorted { $0.dueDate < $1.dueDate }
                    .first?
                    .dueDate
                // When a card is added after a statement has been issued, its opening
                // balance can be higher than that statement. That difference belongs to
                // the following statement cycle, not to the already-issued statement's
                // direct debit.
                let nextCycleDirectDebitDate: String? = {
                    guard let statementDate = card.statementDate,
                          let openingBalancePence = card.openingBalancePence,
                          let openingStatementPence = card.openingStatementBalancePence,
                          openingBalancePence > openingStatementPence
                    else { return nil }

                    let nextStatementDate = addIsoMonthsClamped(date: statementDate, months: 1)
                    let nextDueDate = creditCardDirectDebitDate(
                        statementDate: nextStatementDate,
                        dueDay: card.dueDay ?? 1
                    )
                    return nextDueDate >= asOfDate ? nextDueDate : nil
                }()
                let matchingTargetPayment = progress.linkedCardPayments.first {
                    $0.amountPence == fundingTargetPence
                }
                let periodStatementDueDate = periodStatementPayments
                    .map(\.directDebitDate)
                    .sorted()
                    .first
                guard let directDebitDate = storedDueDate
                    ?? explicitCardPaymentDueDate
                    ?? periodStatementDueDate
                    ?? nextCycleDirectDebitDate
                    ?? matchingTargetPayment?.dueIso
                    ?? progress.linkedCardPayments.first?.dueIso
                    ?? progress.dueIso
                else { return nil }
                if groupByFundingDueDate, !isIsoDate(directDebitDate, in: payPeriod) {
                    return nil
                }

                return CreditCardPaymentFundingChecklistItem(
                    id: cardPaymentFundingChecklistId(cardId: card.id, potId: pot.id, directDebitDate: directDebitDate),
                    cardId: card.id,
                    cardName: card.name,
                    amountPence: amountPence,
                    directDebitDate: directDebitDate,
                    payPeriodId: payPeriod.id,
                    potId: pot.id,
                    potName: pot.name,
                    isCompleted: matchingFundingPence >= amountPence
                )
            }
    }

    static func cardPaymentFundingChecklistId(cardId: String, potId: String, directDebitDate: String) -> String {
        "card-payment-funding-\(cardId)-\(potId)-\(directDebitDate)"
    }

    static func fundingChecklistPresentationItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String,
        groupByFundingDueDate: Bool = false
    ) -> [FundingChecklistPresentationItem] {
        let recurringItems = recurringBillFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            groupByFundingDueDate: groupByFundingDueDate
        ).map {
            let isExcluded = isFundingChecklistExcluded(
                snapshot: snapshot,
                kind: $0.cardId == nil ? .recurringBill : .cardBill,
                sourceId: $0.paymentId,
                occurrenceDate: $0.dueDate,
                payPeriodId: $0.payPeriodId,
                matchAcrossPayPeriods: groupByFundingDueDate
            )
            let chargePaidDate = paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: asOfDate)
            // A card charge and a pot funding tick only reserve money for a later
            // statement payment. A recurring card bill becomes paid/completed only
            // after the repayment for that statement has actually been recorded.
            let statusPaidDate: String?
            let presentationPaidDate: String?
            if $0.cardId != nil {
                let statementPaidDate = paidDateForRecurringCardBillStatementRepayment(
                    item: $0,
                    snapshot: snapshot,
                    asOfDate: asOfDate
                )
                statusPaidDate = statementPaidDate
                presentationPaidDate = statementPaidDate
            } else {
                statusPaidDate = isUnfundedPaydayDirectRecurringBillAlreadyPaid(
                    item: $0,
                    paidDate: chargePaidDate,
                    payPeriod: payPeriod
                ) ? nil : chargePaidDate
                presentationPaidDate = chargePaidDate
            }
            let detail: String
            if let cardName = $0.cardName {
                detail = groupByFundingDueDate
                    ? "\($0.paymentName) bill · \(cardName) · charged \(shortDate($0.dueDate)) · due \(shortDate($0.fundingDueDate))"
                    : "\($0.paymentName) bill · \(cardName) · due \(shortDate($0.dueDate))"
            } else {
                detail = "\($0.paymentName) bill · due \(shortDate($0.dueDate))"
            }
            return FundingChecklistPresentationItem(
                id: "recurring-\($0.id)",
                name: $0.paymentName,
                title: "Add \(MoneyParser.formatPence($0.amountPence)) to \($0.potName)",
                detail: detail,
                amountPence: $0.amountPence,
                dueDate: groupByFundingDueDate ? $0.fundingDueDate : $0.dueDate,
                breakdown: [
                    FundingChecklistBreakdownItem(
                        id: "recurring-\($0.id)",
                        title: $0.paymentName,
                        detail: $0.cardId == nil || !groupByFundingDueDate
                            ? "Bill due \(shortDate($0.dueDate))"
                            : "Card charge \(shortDate($0.dueDate)) · payment due \(shortDate($0.fundingDueDate))",
                        amountPence: $0.amountPence
                    )
                ],
                isCompleted: $0.isCompleted,
                isExcluded: isExcluded,
                status: isExcluded ? .excluded : checklistStatus(isCompleted: $0.isCompleted, paidDate: statusPaidDate),
                paidDate: presentationPaidDate,
                action: .recurringBill(paymentId: $0.paymentId, dueDate: $0.dueDate, payPeriodId: $0.payPeriodId)
            )
        }

        let cardSpendItems = cardSpendFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            groupByFundingDueDate: groupByFundingDueDate
        ).map {
            let isExcluded = isFundingChecklistExcluded(
                snapshot: snapshot,
                kind: .cardSpend,
                sourceId: $0.transactionId,
                occurrenceDate: $0.transactionDate,
                payPeriodId: $0.payPeriodId,
                matchAcrossPayPeriods: groupByFundingDueDate
            )
            let paidDate = paidDateForCardSpendFunding(item: $0, snapshot: snapshot, asOfDate: asOfDate)
            return FundingChecklistPresentationItem(
                id: "card-spend-\($0.id)",
                name: $0.transactionName,
                title: "Add \(MoneyParser.formatPence($0.amountPence)) to \($0.potName)",
                detail: "\($0.transactionName) spend · \($0.cardName) · due \(shortDate($0.dueDate))",
                amountPence: $0.amountPence,
                dueDate: $0.dueDate,
                breakdown: [
                    FundingChecklistBreakdownItem(
                        id: "card-spend-\($0.transactionId)",
                        title: $0.transactionName,
                        detail: "\($0.cardName) card spend · \(shortDate($0.transactionDate))",
                        amountPence: $0.amountPence
                    )
                ],
                isCompleted: $0.isCompleted,
                isExcluded: isExcluded,
                status: isExcluded ? .excluded : checklistStatus(isCompleted: $0.isCompleted, paidDate: paidDate),
                paidDate: paidDate,
                action: .cardSpend(transactionId: $0.transactionId, payPeriodId: $0.payPeriodId)
            )
        }

        let openingItems = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod).map {
            let isExcluded = isFundingChecklistExcluded(
                snapshot: snapshot,
                kind: .cardOpeningBalance,
                sourceId: $0.cardId,
                occurrenceDate: $0.directDebitDate,
                payPeriodId: $0.payPeriodId,
                matchAcrossPayPeriods: groupByFundingDueDate
            )
            let paidDate = paidDateForOpeningBalanceFunding(item: $0, snapshot: snapshot, asOfDate: asOfDate)
            return FundingChecklistPresentationItem(
                id: "card-opening-\($0.id)",
                name: "\($0.cardName) opening balance",
                title: "Add \(MoneyParser.formatPence($0.amountPence)) to \($0.potName)",
                detail: "\($0.cardName) opening balance · due \(shortDate($0.directDebitDate))",
                amountPence: $0.amountPence,
                dueDate: $0.directDebitDate,
                breakdown: [
                    FundingChecklistBreakdownItem(
                        id: "opening-\($0.id)",
                        title: "Opening statement balance",
                        detail: "\($0.cardName) · due \(shortDate($0.directDebitDate))",
                        amountPence: $0.amountPence
                    )
                ],
                isCompleted: $0.isCompleted,
                isExcluded: isExcluded,
                status: isExcluded ? .excluded : checklistStatus(isCompleted: $0.isCompleted, paidDate: paidDate),
                paidDate: paidDate,
                action: .cardOpeningBalance(cardId: $0.cardId, directDebitDate: $0.directDebitDate, payPeriodId: $0.payPeriodId)
            )
        }
        let allocationBackedOpeningItems = paidOpeningBalanceFundingPresentationItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: asOfDate,
            excludingIds: Set(openingItems.map(\.id))
        )

        let cardPaymentItems = cardPaymentFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: asOfDate,
            groupByFundingDueDate: groupByFundingDueDate
        ).map {
            let isExcluded = isFundingChecklistExcluded(
                snapshot: snapshot,
                kind: .cardPayment,
                sourceId: $0.cardId,
                occurrenceDate: $0.directDebitDate,
                payPeriodId: $0.payPeriodId,
                matchAcrossPayPeriods: groupByFundingDueDate
            )
            let paidDate = paidDateForCardPaymentFunding(item: $0, snapshot: snapshot, asOfDate: asOfDate)
            return FundingChecklistPresentationItem(
                id: "card-payment-\($0.id)",
                name: "\($0.cardName) card payment",
                title: "Add \(MoneyParser.formatPence($0.amountPence)) to \($0.potName)",
                detail: "\($0.cardName) card payment · due \(shortDate($0.directDebitDate))",
                amountPence: $0.amountPence,
                dueDate: $0.directDebitDate,
                breakdown: cardPaymentFundingBreakdown(item: $0, snapshot: snapshot, asOfDate: asOfDate),
                isCompleted: $0.isCompleted,
                isExcluded: isExcluded,
                status: isExcluded ? .excluded : checklistStatus(isCompleted: $0.isCompleted, paidDate: paidDate),
                paidDate: paidDate,
                action: .cardPayment(cardId: $0.cardId, potId: $0.potId, directDebitDate: $0.directDebitDate, payPeriodId: $0.payPeriodId)
            )
        }

        let debtItems = debtFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod).map {
            let isExcluded = isFundingChecklistExcluded(
                snapshot: snapshot,
                kind: .debt,
                sourceId: $0.debtId,
                occurrenceDate: $0.dueDate,
                payPeriodId: $0.payPeriodId,
                matchAcrossPayPeriods: groupByFundingDueDate
            )
            let paidDate = paidDateForDebtFunding(item: $0, snapshot: snapshot, asOfDate: asOfDate)
            return FundingChecklistPresentationItem(
                id: "debt-\($0.id)",
                name: $0.debtName,
                title: "Add \(MoneyParser.formatPence($0.amountPence)) to \($0.potName)",
                detail: "\($0.debtName) debt · \($0.lenderName) · due \(shortDate($0.dueDate))",
                amountPence: $0.amountPence,
                dueDate: $0.dueDate,
                breakdown: [
                    FundingChecklistBreakdownItem(
                        id: "debt-\($0.scheduleItemId)",
                        title: $0.debtName,
                        detail: "\($0.lenderName) · due \(shortDate($0.dueDate))",
                        amountPence: $0.amountPence
                    )
                ],
                isCompleted: $0.isCompleted,
                isExcluded: isExcluded,
                status: isExcluded ? .excluded : checklistStatus(isCompleted: $0.isCompleted, paidDate: paidDate),
                paidDate: paidDate,
                action: .debt(debtId: $0.debtId, dueDate: $0.dueDate, payPeriodId: $0.payPeriodId)
            )
        }

        return (recurringItems + cardSpendItems + openingItems + allocationBackedOpeningItems + cardPaymentItems + debtItems)
            .sorted(by: sortFundingChecklistPresentationItems)
    }

    static func debtFundingChecklistItems(snapshot: PlannerSnapshot, payPeriod: PayPeriod?) -> [DebtFundingChecklistItem] {
        guard let payPeriod else { return [] }

        let scheduleItems = debtScheduleItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.deletedAt == nil &&
                $0.status != .paid &&
                $0.status != .cancelled &&
                $0.plannedAmountPence > 0 &&
                isIsoDate($0.dueDate, in: payPeriod)
            }

        return scheduleItems
            .compactMap { item -> (DebtPaymentScheduleItem, Debt)? in
                guard let debt = snapshot.debts.first(where: { $0.id == item.debtId && $0.status.isActiveLike && $0.currentBalancePence > 0 }) else {
                    return nil
                }
                return (item, debt)
            }
            .sorted { lhs, rhs in
                if lhs.0.dueDate == rhs.0.dueDate {
                    return lhs.1.name < rhs.1.name
                }
                return lhs.0.dueDate < rhs.0.dueDate
            }
            .compactMap { item, debt -> DebtFundingChecklistItem? in
                let linkedPots = activeLinkedDebtPots(snapshot: snapshot, debtId: debt.id)
                guard let fundingPot = linkedPots.first else { return nil }

                let allocationFundingPence = snapshot.potAllocations
                    .filter {
                        $0.deletedAt == nil &&
                        $0.payPeriodId == payPeriod.id &&
                        $0.source == .debtFunding &&
                        $0.debtId == debt.id &&
                        (
                            $0.debtScheduleItemId == item.id ||
                            ($0.debtScheduleItemId == nil && $0.debtDueDate == item.dueDate)
                        )
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let matchingFundingPence = max(allocationFundingPence, max(0, item.fundedAmountPence))

                let linkedPotBalancePence = linkedPots.reduce(0) { $0 + max(0, $1.balancePence) }
                let existingNonChecklistBalancePence = max(0, linkedPotBalancePence - matchingFundingPence)
                let requiredFundingPence = max(0, item.plannedAmountPence - item.paidAmountPence - existingNonChecklistBalancePence)

                guard requiredFundingPence > 0 || matchingFundingPence > 0 else { return nil }

                return DebtFundingChecklistItem(
                    id: debtFundingChecklistId(debtId: debt.id, dueDate: item.dueDate),
                    scheduleItemId: item.id,
                    debtId: debt.id,
                    debtName: debt.name,
                    lenderName: debt.lender,
                    amountPence: requiredFundingPence,
                    dueDate: item.dueDate,
                    payPeriodId: payPeriod.id,
                    potId: fundingPot.id,
                    potName: fundingPot.name,
                    isCompleted: requiredFundingPence > 0 && matchingFundingPence >= requiredFundingPence
                )
            }
    }

    static func debtFundingChecklistId(debtId: String, dueDate: String) -> String {
        "debt-funding-\(debtId)-\(dueDate)"
    }

    static func debtScheduleItems(snapshot: PlannerSnapshot, payPeriod: PayPeriod?) -> [DebtPaymentScheduleItem] {
        let existingItems = snapshot.debtPaymentScheduleItems
        let debtIdsWithExistingItems = Set(existingItems.map(\.debtId))
        let today = payPeriod?.startDate ?? FinanceEngine.getAppTodayIso(settings: snapshot.settings)
        let generatedItems = snapshot.debts
            .filter { $0.status.isActiveLike && $0.currentBalancePence > 0 && !debtIdsWithExistingItems.contains($0.id) }
            .flatMap { debt in
                DebtPlannerEngine.generateSchedule(for: debt, payPeriods: snapshot.payPeriods, today: today)
            }
        return existingItems + generatedItems
    }

    private static func creditCardStatementCycles(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        through endDate: String
    ) -> [CreditCardStatementCycle] {
        guard var scheduledStatementDate = card.statementDate,
              FinanceEngine.isIsoDate(scheduledStatementDate),
              let dueDay = card.dueDay,
              FinanceEngine.isIsoDate(endDate)
        else { return [] }

        let overrides = Dictionary(
            uniqueKeysWithValues: snapshot.creditCardCycleOverrides
                .filter { $0.deletedAt == nil && $0.creditCardId == card.id }
                .map { ($0.scheduledStatementDate, $0) }
        )
        var cycles: [CreditCardStatementCycle] = []
        var previousStatementDate: String?

        let boundedEndDate = max(endDate, scheduledStatementDate)
        for _ in 0..<240 {
            let override = overrides[scheduledStatementDate]
            let statementDate = override?.statementState == .confirmed &&
                (override?.actualStatementDate.map(FinanceEngine.isIsoDate) ?? false)
                ? override!.actualStatementDate!
                : scheduledStatementDate
            let derivedDirectDebitDate = creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
            let directDebitDate = override?.directDebitState == .confirmed &&
                (override?.actualDirectDebitDate.map(FinanceEngine.isIsoDate) ?? false)
                ? override!.actualDirectDebitDate!
                : derivedDirectDebitDate
            let cycleStartDate = previousStatementDate ?? (card.createdAt.prefixDate ?? statementDate)

            cycles.append(
                CreditCardStatementCycle(
                    scheduledStatementDate: scheduledStatementDate,
                    statementDate: statementDate,
                    directDebitDate: directDebitDate,
                    cycleStartDate: cycleStartDate,
                    previousStatementDate: previousStatementDate,
                    isStatementHeld: override?.statementState == .awaitingConfirmation,
                    isDirectDebitHeld: override?.directDebitState == .awaitingPayment
                )
            )

            guard scheduledStatementDate < boundedEndDate else { break }
            previousStatementDate = statementDate
            scheduledStatementDate = addIsoMonthsClamped(date: scheduledStatementDate, months: 1)
        }

        return cycles
    }

    static func creditCardCycleAdjustmentSummary(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> CreditCardCycleAdjustmentSummary? {
        creditCardStatementCycles(
            card: card,
            snapshot: snapshot,
            through: addIsoMonthsClamped(date: asOfDate, months: 1)
        )
            .first { cycle in
                cycle.isHeld || cycle.directDebitDate >= asOfDate || cycle.statementDate >= asOfDate
            }
            .map {
                CreditCardCycleAdjustmentSummary(
                    scheduledStatementDate: $0.scheduledStatementDate,
                    statementDate: $0.statementDate,
                    directDebitDate: $0.directDebitDate,
                    isStatementHeld: $0.isStatementHeld,
                    isDirectDebitHeld: $0.isDirectDebitHeld
                )
            }
    }

    static func creditCardNextStatementDate(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> String? {
        guard FinanceEngine.isIsoDate(asOfDate) else { return nil }

        return creditCardStatementCycles(
            card: card,
            snapshot: snapshot,
            through: addIsoMonthsClamped(date: asOfDate, months: 2)
        )
        .first { $0.statementDate > asOfDate }
        .map(\.statementDate)
    }

    static func creditCardCycleReminders(snapshot: PlannerSnapshot, asOfDate: String, months: Int = 3) -> [CreditCardCycleReminder] {
        let endDate = addIsoMonthsClamped(date: asOfDate, months: months)
        return snapshot.creditCards
            .filter { !$0.archived }
            .flatMap { card in
                creditCardStatementCycles(card: card, snapshot: snapshot, through: endDate)
                    .filter { $0.statementDate >= asOfDate && $0.statementDate <= endDate }
                    .map {
                        CreditCardCycleReminder(
                            cardId: card.id,
                            cardName: card.name,
                            scheduledStatementDate: $0.scheduledStatementDate,
                            statementDate: $0.statementDate,
                            directDebitDate: $0.directDebitDate
                        )
                    }
            }
    }

    static func creditCardHeldCycleReservePence(card: CreditCard, snapshot: PlannerSnapshot, asOfDate: String) -> Int {
        creditCardStatementCycles(
            card: card,
            snapshot: snapshot,
            through: addIsoMonthsClamped(date: asOfDate, months: 1)
        )
            .filter { $0.isHeld && $0.cycleStartDate <= asOfDate }
            .reduce(0) { total, cycle in
                let breakdown = creditCardStatementBreakdown(
                    card: card,
                    snapshot: snapshot,
                    statementDate: asOfDate,
                    previousStatementDate: cycle.previousStatementDate,
                    nextStatementDate: addIsoMonthsClamped(date: cycle.scheduledStatementDate, months: 1),
                    directDebitDate: cycle.directDebitDate,
                    asOfDate: asOfDate
                )
                let reserve = max(0, breakdown.reduce(0) { $0 + $1.amountPence })
                return total + reserve
            }
    }

    static func creditCardStatementPayments(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        startDate: String,
        endDate: String,
        asOfDate: String
    ) -> [CreditCardStatementPayment] {
        guard card.statementDate != nil, card.dueDay != nil else { return [] }

        var payments: [CreditCardStatementPayment] = []
        for cycle in creditCardStatementCycles(card: card, snapshot: snapshot, through: endDate) {
            if cycle.directDebitDate > endDate { break }
            if cycle.directDebitDate >= startDate, !cycle.isHeld {
                let nextStatementDate = addIsoMonthsClamped(date: cycle.scheduledStatementDate, months: 1)
                let breakdown = creditCardStatementBreakdown(
                    card: card,
                    snapshot: snapshot,
                    statementDate: cycle.statementDate,
                    previousStatementDate: cycle.previousStatementDate,
                    nextStatementDate: nextStatementDate,
                    directDebitDate: cycle.directDebitDate,
                    asOfDate: asOfDate
                )
                let actualDuePence = max(0, breakdown
                    .filter { $0.source == .openingStatement || $0.source == .spending || $0.source == .repayment }
                    .reduce(0) { $0 + $1.amountPence })
                let forecastDuePence = max(0, breakdown.reduce(0) { $0 + $1.amountPence })
                let amountOverride = snapshot.creditCardCycleOverrides.first {
                    $0.deletedAt == nil &&
                    $0.creditCardId == card.id &&
                    $0.scheduledStatementDate == cycle.scheduledStatementDate
                }?.amountPenceOverride.map { max(0, $0) }

                payments.append(
                    CreditCardStatementPayment(
                        statementDate: cycle.statementDate,
                        directDebitDate: cycle.directDebitDate,
                        actualDuePence: amountOverride ?? actualDuePence,
                        forecastDuePence: amountOverride ?? forecastDuePence,
                        scheduledStatementDate: cycle.scheduledStatementDate,
                        isHeld: false
                    )
                )
            }
        }

        return payments
    }

    static func creditCardStatementSummaries(snapshot: PlannerSnapshot, asOfDate: String) -> [CreditCardStatementSummary] {
        snapshot.creditCards
            .filter { !$0.archived }
            .flatMap { card -> [CreditCardStatementSummary] in
                guard card.statementDate != nil, card.dueDay != nil else { return [] }

                var summaries: [CreditCardStatementSummary] = []
                for cycle in creditCardStatementCycles(
                    card: card,
                    snapshot: snapshot,
                    through: addIsoMonthsClamped(date: asOfDate, months: 1)
                ) {
                    if cycle.statementDate > asOfDate && !cycle.isStatementHeld { break }

                    let cycleEnd = cycle.isStatementHeld ? asOfDate : cycle.statementDate
                    let includesCycleStart = cycle.cycleStartDate == (card.createdAt.prefixDate ?? cycle.statementDate)
                    let transactions = creditCardStatementTransactions(
                        card: card,
                        snapshot: snapshot,
                        cycleStart: cycle.cycleStartDate,
                        statementDate: cycleEnd,
                        includesCycleStart: includesCycleStart,
                        asOfDate: asOfDate
                    )
                    let statementAmountPence = transactions.reduce(0) { $0 + max(0, $1.amountPence) }
                    let paidAmountPence = min(
                        statementAmountPence,
                        snapshot.creditCardRepayments
                            .filter {
                                $0.deletedAt == nil &&
                                $0.creditCardId == card.id &&
                                (
                                    ($0.statementDate == cycle.statementDate && $0.date >= cycle.statementDate) ||
                                    ($0.statementDate == nil && $0.date > cycle.statementDate && $0.date <= cycle.directDebitDate)
                                ) &&
                                $0.date <= asOfDate
                            }
                            .reduce(0) { $0 + max(0, $1.amountPence) }
                    )
                    let unpaidAmountPence = max(0, statementAmountPence - paidAmountPence)
                    let status: CreditCardStatementStatus
                    if cycle.isHeld {
                        status = .awaitingConfirmation
                    } else if statementAmountPence > 0 && unpaidAmountPence == 0 {
                        status = .paid
                    } else if unpaidAmountPence > 0 && cycle.directDebitDate < asOfDate {
                        status = .overdue
                    } else {
                        status = .upcoming
                    }

                    if statementAmountPence > 0 || paidAmountPence > 0 {
                        summaries.append(
                            CreditCardStatementSummary(
                                id: "\(card.id)-\(cycle.scheduledStatementDate)",
                                cardId: card.id,
                                cardName: card.name,
                                statementDate: cycle.statementDate,
                                directDebitDate: cycle.directDebitDate,
                                statementAmountPence: statementAmountPence,
                                paidAmountPence: paidAmountPence,
                                unpaidAmountPence: unpaidAmountPence,
                                status: status,
                                transactions: transactions
                            )
                        )
                    }

                }

                return summaries
            }
            .sorted {
                if $0.statementDate == $1.statementDate {
                    return $0.cardName < $1.cardName
                }
                return $0.statementDate > $1.statementDate
            }
    }

    static func recurringOccurrences(payments: [RecurringPayment], startDate: String, endDate: String) -> [RecurringPaymentOccurrence] {
        payments
            .filter(\.active)
            .flatMap { payment in
                dueDates(for: payment, startDate: startDate, endDate: endDate).map {
                    RecurringPaymentOccurrence(payment: payment, scheduledDueDate: $0, dueDate: $0, amountPence: payment.amountPence)
                }
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return priorityRank($0.payment.priority) < priorityRank($1.payment.priority)
                }
                return $0.dueDate < $1.dueDate
            }
    }

    static func resolvedRecurringOccurrences(
        snapshot: PlannerSnapshot,
        payments: [RecurringPayment],
        startDate: String,
        endDate: String
    ) -> [RecurringPaymentOccurrence] {
        guard startDate <= endDate else { return [] }

        let activePayments = payments.filter(\.active)
        let paymentsById = Dictionary(uniqueKeysWithValues: activePayments.map { ($0.id, $0) })
        let overrides = snapshot.recurringPaymentOccurrenceOverrides.filter {
            $0.deletedAt == nil && paymentsById[$0.paymentId] != nil
        }
        let overridesByKey = Dictionary(uniqueKeysWithValues: overrides.map { ("\($0.paymentId)-\($0.scheduledDueDate)", $0) })
        var scheduledOccurrences = recurringOccurrences(payments: activePayments, startDate: startDate, endDate: endDate)
        var presentKeys = Set(scheduledOccurrences.map { "\($0.payment.id)-\($0.scheduledDueDate)" })

        for override in overrides {
            guard override.state != .refunded else { continue }
            let effectiveDate = override.state == .confirmed ? override.actualDueDate : override.scheduledDueDate
            guard let payment = paymentsById[override.paymentId],
                  let effectiveDate,
                  FinanceEngine.isIsoDate(effectiveDate),
                  (effectiveDate >= startDate && effectiveDate <= endDate) || override.state == .awaitingPayment
            else { continue }

            let key = "\(payment.id)-\(override.scheduledDueDate)"
            guard !presentKeys.contains(key) else { continue }
            scheduledOccurrences.append(
                RecurringPaymentOccurrence(
                    payment: payment,
                    scheduledDueDate: override.scheduledDueDate,
                    dueDate: override.scheduledDueDate,
                    amountPence: payment.amountPence
                )
            )
            presentKeys.insert(key)
        }

        return scheduledOccurrences
            .compactMap { occurrence -> RecurringPaymentOccurrence? in
                let key = "\(occurrence.payment.id)-\(occurrence.scheduledDueDate)"
                guard let override = overridesByKey[key] else { return occurrence }

                var resolved = occurrence
                switch override.state {
                case .normal:
                    break
                case .awaitingPayment:
                    resolved.isAwaitingPayment = true
                case .confirmed:
                    guard let actualDueDate = override.actualDueDate, FinanceEngine.isIsoDate(actualDueDate) else { return occurrence }
                    resolved.dueDate = actualDueDate
                case .refunded:
                    return nil
                }
                if let amountPenceOverride = override.amountPenceOverride {
                    resolved.amountPence = max(0, amountPenceOverride)
                }
                return resolved
            }
            .filter { ($0.dueDate >= startDate && $0.dueDate <= endDate) || $0.isAwaitingPayment }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return priorityRank($0.payment.priority) < priorityRank($1.payment.priority)
                }
                return $0.dueDate < $1.dueDate
            }
    }

    /// Returns a bounded, globally sorted Upcoming list while limiting each
    /// recurring bill independently. Occurrence overrides remain authoritative,
    /// so an awaiting past occurrence consumes one of the bill's visible cycles.
    static func nextRecurringOccurrences(
        snapshot: PlannerSnapshot,
        payments: [RecurringPayment],
        asOfDate: String,
        limitPerPayment: Int
    ) -> [RecurringPaymentOccurrence] {
        guard FinanceEngine.isIsoDate(asOfDate), limitPerPayment > 0 else { return [] }

        let activePayments = payments.filter {
            $0.deletedAt == nil && $0.active
        }
        let recurringSearchEnd = addIsoMonthsClamped(
            date: asOfDate,
            months: max(36, (limitPerPayment + 1) * 12)
        )

        return activePayments
            .flatMap { payment -> [RecurringPaymentOccurrence] in
                let searchEnd: String
                if payment.frequency == .once {
                    let matchingOverrideDate = snapshot.recurringPaymentOccurrenceOverrides
                        .filter {
                            $0.deletedAt == nil &&
                            $0.paymentId == payment.id &&
                            $0.state != .refunded
                        }
                        .compactMap(\.actualDueDate)
                        .max()
                    searchEnd = max(
                        recurringSearchEnd,
                        payment.dueDate ?? asOfDate,
                        matchingOverrideDate ?? asOfDate
                    )
                } else {
                    searchEnd = recurringSearchEnd
                }

                return Array(
                    resolvedRecurringOccurrences(
                        snapshot: snapshot,
                        payments: [payment],
                        startDate: asOfDate,
                        endDate: searchEnd
                    )
                    .prefix(limitPerPayment)
                )
            }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                let nameOrder = lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name)
                if nameOrder != .orderedSame {
                    return nameOrder == .orderedAscending
                }
                if lhs.scheduledDueDate != rhs.scheduledDueDate {
                    return lhs.scheduledDueDate < rhs.scheduledDueDate
                }
                return lhs.id < rhs.id
            }
    }

    static func recurringBillCycleAdjustmentOccurrence(
        snapshot: PlannerSnapshot,
        payment: RecurringPayment,
        asOfDate: String
    ) -> RecurringPaymentOccurrence? {
        guard payment.deletedAt == nil,
              payment.active,
              FinanceEngine.isIsoDate(asOfDate)
        else { return nil }

        let startDate = addIsoMonthsClamped(date: asOfDate, months: -13)
        let endDate = addIsoMonthsClamped(date: asOfDate, months: 13)
        let occurrences = resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: [payment],
            startDate: startDate,
            endDate: endDate
        )

        if let awaiting = occurrences
            .filter(\.isAwaitingPayment)
            .sorted(by: { $0.scheduledDueDate > $1.scheduledDueDate })
            .first {
            return awaiting
        }

        let recentStartDate = FinanceEngine.addIsoDays(date: asOfDate, days: -7)
        if let recent = occurrences
            .filter({ $0.dueDate >= recentStartDate && $0.dueDate <= asOfDate })
            .sorted(by: { $0.dueDate > $1.dueDate })
            .first {
            return recent
        }

        if let upcoming = occurrences
            .filter({ $0.dueDate >= asOfDate })
            .sorted(by: { $0.dueDate < $1.dueDate })
            .first {
            return upcoming
        }

        guard payment.frequency == .once,
              let dueDate = payment.dueDate,
              FinanceEngine.isIsoDate(dueDate)
        else { return occurrences.last }

        return resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: [payment],
            startDate: min(dueDate, asOfDate),
            endDate: max(dueDate, asOfDate)
        ).last
    }

    static func cardBalance(card: CreditCard, snapshot: PlannerSnapshot) -> Int {
        let opening = card.openingBalancePence ?? 0
        let cardSpending = snapshot.transactions
            .filter { $0.deletedAt == nil && !$0.isRefunded && $0.creditCardId == card.id && $0.paymentMethod == .creditCard }
            .reduce(0) { $0 + abs($1.amountPence) }
        let repayments = snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && !$0.isRefunded && $0.creditCardId == card.id }
            .reduce(0) { $0 + $1.amountPence }

        return max(0, opening + cardSpending - repayments)
    }

    static func findPayPeriod(payPeriods: [PayPeriod], date: String) -> PayPeriod? {
        payPeriods
            .filter { date >= $0.startDate && date <= $0.endDate }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    static func projectedFundingPayPeriods(
        snapshot: PlannerSnapshot,
        startingAt payPeriod: PayPeriod?,
        count: Int = 12
    ) -> [PayPeriod] {
        guard var current = payPeriod, count > 0 else { return [] }

        let frequency = current.payFrequency ?? snapshot.settings.payFrequency
        let monthlyAnchorDay = frequency == .monthly
            ? current.monthlyAnchorDay ?? FinanceEngine.dayOfMonth(current.payday)
            : nil
        let savedPeriodsByPayday = snapshot.payPeriods
            .filter { $0.deletedAt == nil }
            .reduce(into: [String: PayPeriod]()) { result, period in
                result[period.payday] = period
            }
        var periods: [PayPeriod] = []

        for index in 0..<count {
            let dates = FinanceEngine.createNextPayPeriod(
                payday: current.payday,
                frequency: frequency,
                monthlyAnchorDay: monthlyAnchorDay
            )
            current.startDate = dates.startDate
            current.endDate = dates.endDate
            current.nextPayday = dates.nextPayday
            current.payFrequency = frequency
            current.monthlyAnchorDay = monthlyAnchorDay
            periods.append(current)

            guard index + 1 < count else { break }
            if var savedNext = savedPeriodsByPayday[dates.nextPayday] {
                savedNext.payFrequency = frequency
                savedNext.monthlyAnchorDay = monthlyAnchorDay
                current = savedNext
            } else {
                current = PayPeriod(
                    id: "pay-period-\(dates.nextPayday)",
                    startDate: dates.nextPayday,
                    endDate: dates.nextPayday,
                    payday: dates.nextPayday,
                    nextPayday: dates.nextPayday,
                    payFrequency: frequency,
                    incomePence: current.incomePence,
                    status: .planned,
                    createdAt: current.createdAt,
                    updatedAt: current.updatedAt,
                    deletedAt: nil,
                    monthlyAnchorDay: monthlyAnchorDay
                )
            }
        }

        return periods
    }

    static func payPeriodCostSummary(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String? = nil
    ) -> PayPeriodCostSummary {
        guard let payPeriod else { return emptyPayPeriodCostSummary }

        let recurringOccurrencesForPeriod = resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments.filter { $0.deletedAt == nil },
            startDate: payPeriod.startDate,
            endDate: payPeriod.endDate
        )
        let recurringItems = recurringOccurrencesForPeriod
        .map { occurrence in
            PeriodCostItem(
                id: "recurring-\(occurrence.payment.id)-\(occurrence.dueDate)",
                label: occurrence.payment.name,
                amountPence: occurrence.amountPence,
                date: occurrence.dueDate,
                source: .recurring,
                creditCardId: occurrence.payment.creditCardId,
                potId: occurrence.payment.potId,
                fundingPotId: nil
            )
        }
        let recurringFundingKeys = Set(
            recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                .map { recurringBillFundingKey(paymentId: $0.paymentId, dueDate: $0.dueDate) }
        )

        let directRecurringItems = applyLinkedPotBalances(
            to: recurringOccurrencesForPeriod
                .filter {
                    $0.payment.creditCardId == nil &&
                    !recurringFundingKeys.contains(recurringBillFundingKey(paymentId: $0.payment.id, dueDate: $0.dueDate))
                }
                .map { occurrence in
                    PeriodCostItem(
                        id: "recurring-\(occurrence.payment.id)-\(occurrence.dueDate)",
                        label: occurrence.payment.name,
                        amountPence: occurrence.amountPence,
                        date: occurrence.dueDate,
                        source: .recurring,
                        creditCardId: nil,
                        potId: occurrence.payment.potId,
                        fundingPotId: nil
                    )
                },
            pots: snapshot.pots
        )
        let creditCardRecurringItems = recurringItems.filter { $0.creditCardId != nil }

        let savedPaymentItems = snapshot.customPayments
            .filter { $0.deletedAt == nil && $0.status != .archived && isIsoDate($0.dueDate, in: payPeriod) }
            .map {
                PeriodCostItem(
                    id: "custom-\($0.id)",
                    label: $0.name,
                    amountPence: $0.amountPence,
                    date: $0.dueDate,
                    source: .savedPayment,
                    creditCardId: $0.creditCardId,
                    potId: nil,
                    fundingPotId: nil
                )
            }

        let manualSpendItems = snapshot.transactions
            .filter { $0.deletedAt == nil && !$0.isRefunded && $0.type == .spending && $0.recurringPaymentId == nil && isIsoDate($0.date, in: payPeriod) }
            .map {
                PeriodCostItem(
                    id: "transaction-\($0.id)",
                    label: $0.note.isEmpty ? "Manual spend" : $0.note,
                    amountPence: $0.amountPence,
                    date: $0.date,
                    source: .manualSpend,
                    creditCardId: $0.paymentMethod == .creditCard ? $0.creditCardId : nil,
                    potId: $0.potId,
                    fundingPotId: nil
                )
            }

        let potLookup = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }
        let potAllocationItems = snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.payPeriodId == payPeriod.id &&
                $0.amountPence > 0 &&
                $0.source != .recurring &&
                ($0.recurringPaymentId == nil || isRecurringBillFundingSource($0.source))
            }
            .map { allocation in
                let potName = potLookup[allocation.potId]?.name ?? "Pot"
                let label: String
                if allocation.source == .potAuto {
                    label = "\(potName) payday top-up"
                } else if allocation.source == .recurringBillFunding {
                    label = "\(potName) bill funding"
                } else if allocation.source == .cardBillFunding {
                    label = "\(potName) card bill funding"
                } else if allocation.source == .cardSpendFunding {
                    label = "\(potName) card spend funding"
                } else if allocation.source == .cardOpeningBalanceFunding {
                    label = "\(potName) card opening balance funding"
                } else if allocation.source == .debtFunding {
                    label = "\(potName) debt funding"
                } else {
                    label = "\(potName) allocation"
                }
                return PeriodCostItem(
                    id: "pot-allocation-\(allocation.id)",
                    label: label,
                    amountPence: allocation.amountPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: allocation.potId,
                    fundingPotId: allocation.fundingPotId
                )
            }
        let plannedFundingItems = plannedFundingCostItems(snapshot: snapshot, payPeriod: payPeriod, asOfDate: asOfDate)

        let debtReserveItems = snapshot.debtReserves
            .filter { $0.deletedAt == nil && $0.status == .planned && $0.amountPence > 0 && isDebtReserve($0, in: payPeriod) }
            .map { reserve in
                let debtName = snapshot.debts.first { $0.id == reserve.debtId }?.name ?? "Debt"
                return PeriodCostItem(
                    id: "debt-reserve-\(reserve.id)",
                    label: "\(debtName) reserve",
                    amountPence: reserve.amountPence,
                    date: reserve.payday,
                    source: .debtReserve,
                    creditCardId: nil,
                    potId: nil,
                    fundingPotId: nil
                )
            }

        let debtMinimumItems = debtScheduleItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.status != .paid &&
                $0.status != .cancelled &&
                $0.plannedAmountPence > 0 &&
                isIsoDate($0.dueDate, in: payPeriod)
            }
            .compactMap { item -> PeriodCostItem? in
                guard let debt = snapshot.debts.first(where: { $0.id == item.debtId && $0.status.isActiveLike && $0.currentBalancePence > 0 }),
                      activeLinkedDebtPots(snapshot: snapshot, debtId: debt.id).isEmpty
                else { return nil }
                return PeriodCostItem(
                    id: "debt-\(item.id)",
                    label: debt.name,
                    amountPence: max(0, item.plannedAmountPence - item.paidAmountPence),
                    date: item.dueDate,
                    source: .debtMinimum,
                    creditCardId: nil,
                    potId: nil,
                    fundingPotId: nil
                )
            }
            .filter { $0.amountPence > 0 }

        let creditCardPotItems = snapshot.creditCardPots
            .filter { $0.deletedAt == nil && $0.status == .active && $0.source == .paycheck && $0.amountPence > 0 && isCreditCardPot($0, in: payPeriod) }
            .map {
                PeriodCostItem(
                    id: "credit-card-pot-\($0.id)",
                    label: $0.name,
                    amountPence: $0.amountPence,
                    date: $0.payday ?? payPeriod.payday,
                    source: .creditCardPot,
                    creditCardId: $0.creditCardId,
                    potId: nil,
                    fundingPotId: nil
                )
            }

        let repaymentItems = snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && !$0.isRefunded && isIsoDate($0.date, in: payPeriod) }
            .map {
                let paycheckContributionPence = creditCardRepaymentPaycheckContribution($0)
                return PeriodCostItem(
                    id: "repayment-\($0.id)",
                    label: $0.note.isEmpty ? "Card repayment" : $0.note,
                    amountPence: paycheckContributionPence,
                    date: $0.date,
                    source: .creditCardRepayment,
                    creditCardId: $0.creditCardId,
                    potId: nil,
                    fundingPotId: nil
                )
            }

        var allItems = directRecurringItems
        allItems += creditCardRecurringItems
        allItems += savedPaymentItems
        allItems += manualSpendItems
        allItems += potAllocationItems
        allItems += plannedFundingItems
        allItems += debtReserveItems
        allItems += debtMinimumItems
        allItems += creditCardPotItems
        allItems += repaymentItems

        allItems = allItems
        .filter { $0.amountPence != 0 }
        .sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return eventRankForCostItem(lhs.source) < eventRankForCostItem(rhs.source)
            }
            return lhs.date < rhs.date
        }

        return createPayPeriodCostSummary(
            payReceivedPence: effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: payPeriod),
            plannedCostsPence: currentCycleOutgoingsPence(
                snapshot: snapshot,
                payPeriod: payPeriod,
                asOfDate: asOfDate
            ),
            items: allItems
        )
    }

    /// Adds every external outgoing in the selected pay cycle. Funding allocations,
    /// pot transfers, and reserves are deliberately excluded because the bill,
    /// purchase, debt payment, or card repayment they fund is counted separately.
    static func currentCycleOutgoingsPence(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod,
        asOfDate: String? = nil
    ) -> Int {
        let recurringPence = resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments.filter { $0.deletedAt == nil },
            startDate: payPeriod.startDate,
            endDate: payPeriod.endDate
        )
        .reduce(0) { $0 + max(0, $1.amountPence) }

        let savedPaymentsPence = snapshot.customPayments
            .filter {
                $0.deletedAt == nil &&
                $0.status != .archived &&
                isIsoDate($0.dueDate, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let manualSpendingPence = snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.recurringPaymentId == nil &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let activeDebtIds = Set(
            snapshot.debts
                .filter { $0.deletedAt == nil && $0.status.isActiveLike }
                .map(\.id)
        )
        let scheduledDebtPence = debtScheduleItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.deletedAt == nil &&
                $0.status != .paid &&
                $0.status != .cancelled &&
                activeDebtIds.contains($0.debtId) &&
                isIsoDate($0.dueDate, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.plannedAmountPence - $1.paidAmountPence) }
        let paidDebtPence = snapshot.debtPayments
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                activeDebtIds.contains($0.debtId) &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        let calculationDate = asOfDate ?? FinanceEngine.getAppTodayIso(settings: snapshot.settings)
        let openingCardPaymentPence = cardOpeningBalanceFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod
        )
        .reduce(0) { $0 + max(0, $1.amountPence) }
        let scheduledCardPaymentPence = snapshot.creditCards
            .filter { $0.deletedAt == nil && !$0.archived }
            .flatMap {
                creditCardStatementPayments(
                    card: $0,
                    snapshot: snapshot,
                    startDate: payPeriod.startDate,
                    endDate: payPeriod.endDate,
                    asOfDate: calculationDate
                )
            }
            .reduce(0) { $0 + max(0, $1.forecastDuePence) }
        let paidCardPence = snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                isIsoDate($0.date, in: payPeriod)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        return recurringPence +
            savedPaymentsPence +
            manualSpendingPence +
            scheduledDebtPence +
            paidDebtPence +
            openingCardPaymentPence +
            scheduledCardPaymentPence +
            paidCardPence
    }

    static func effectivePayPeriodIncomePence(snapshot: PlannerSnapshot, payPeriod: PayPeriod) -> Int {
        let paycheck = snapshot.paychecks.first { $0.deletedAt == nil && $0.payPeriodId == payPeriod.id }
        let sourceId = paycheck?.id ?? payPeriod.id
        let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .paycheck, sourceId: sourceId, scheduledDate: payPeriod.payday)
        let baseIncome: Int
        if override?.state == .cancelled {
            baseIncome = 0
        } else {
            baseIncome = max(0, override?.amountPenceOverride ?? payPeriod.incomePence)
        }
        return baseIncome + oneOffIncomePence(snapshot: snapshot, payPeriod: payPeriod)
    }

    static func oneOffIncomePence(snapshot: PlannerSnapshot, payPeriod: PayPeriod) -> Int {
        // The recorded date is the source of truth. The stored period ID is denormalized
        // metadata and can become stale when periods are edited or regenerated.
        snapshot.oneOffIncomes
            .filter {
                let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .oneOffIncome, sourceId: $0.id, scheduledDate: $0.date)
                let effectiveDate = effectiveIncomeDate(override: override, scheduledDate: $0.date)
                return $0.deletedAt == nil &&
                override?.state != .cancelled &&
                isIsoDate(effectiveDate, in: payPeriod)
            }
            .reduce(0) {
                let override = incomeOccurrenceOverride(snapshot: snapshot, kind: .oneOffIncome, sourceId: $1.id, scheduledDate: $1.date)
                return $0 + max(0, override?.amountPenceOverride ?? $1.amountPence)
            }
    }

    private static func incomeOccurrenceOverride(
        snapshot: PlannerSnapshot,
        kind: IncomeOccurrenceSourceKind,
        sourceId: String,
        scheduledDate: String
    ) -> IncomeOccurrenceOverride? {
        snapshot.incomeOccurrenceOverrides.first {
            $0.deletedAt == nil &&
            $0.sourceKind == kind &&
            $0.sourceId == sourceId &&
            $0.scheduledDate == scheduledDate
        }
    }

    private static func effectiveIncomeDate(override: IncomeOccurrenceOverride?, scheduledDate: String) -> String {
        guard override?.state == .confirmed,
              let actualDate = override?.actualDate,
              FinanceEngine.isIsoDate(actualDate)
        else { return scheduledDate }
        return actualDate
    }

    private static func plannedFundingCostItems(snapshot: PlannerSnapshot, payPeriod: PayPeriod, asOfDate: String?) -> [PeriodCostItem] {
        let fundingAsOfDate = asOfDate ?? FinanceEngine.getAppTodayIso(settings: snapshot.settings)
        let billItems = recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                !$0.isCompleted &&
                !isFundingChecklistExcluded(
                    snapshot: snapshot,
                    kind: $0.cardId == nil ? .recurringBill : .cardBill,
                    sourceId: $0.paymentId,
                    occurrenceDate: $0.dueDate,
                    payPeriodId: $0.payPeriodId
                )
            }
            .map {
                let label = $0.cardId == nil ? "\($0.potName) bill funding" : "\($0.potName) card bill funding"
                return PeriodCostItem(
                    id: "planned-recurring-bill-funding-\($0.id)",
                    label: label,
                    amountPence: $0.amountPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: $0.potId,
                    fundingPotId: nil,
                    isProjected: true
                )
            }

        let spendItems = cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                !$0.isCompleted &&
                !isFundingChecklistExcluded(
                    snapshot: snapshot,
                    kind: .cardSpend,
                    sourceId: $0.transactionId,
                    occurrenceDate: $0.transactionDate,
                    payPeriodId: $0.payPeriodId
                )
            }
            .map {
                PeriodCostItem(
                    id: "planned-card-spend-funding-\($0.id)",
                    label: "\($0.potName) card spend funding",
                    amountPence: $0.amountPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: $0.potId,
                    fundingPotId: nil,
                    isProjected: true
                )
            }

        let openingItems = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                !$0.isCompleted &&
                !isFundingChecklistExcluded(
                    snapshot: snapshot,
                    kind: .cardOpeningBalance,
                    sourceId: $0.cardId,
                    occurrenceDate: $0.directDebitDate,
                    payPeriodId: $0.payPeriodId
                )
            }
            .map {
                PeriodCostItem(
                    id: "planned-card-opening-funding-\($0.id)",
                    label: "\($0.potName) card opening balance funding",
                    amountPence: $0.amountPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: $0.potId,
                    fundingPotId: nil,
                    isProjected: true
                )
            }

        let debtItems = debtFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                !$0.isCompleted &&
                !isFundingChecklistExcluded(
                    snapshot: snapshot,
                    kind: .debt,
                    sourceId: $0.debtId,
                    occurrenceDate: $0.dueDate,
                    payPeriodId: $0.payPeriodId
                )
            }
            .map {
                PeriodCostItem(
                    id: "planned-debt-funding-\($0.id)",
                    label: "\($0.potName) debt funding",
                    amountPence: $0.amountPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: $0.potId,
                    fundingPotId: nil,
                    isProjected: true
                )
            }

        let cardPaymentItems = cardPaymentFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: fundingAsOfDate
        )
            .compactMap { item -> PeriodCostItem? in
                guard !item.isCompleted,
                      !isFundingChecklistExcluded(
                        snapshot: snapshot,
                        kind: .cardPayment,
                        sourceId: item.cardId,
                        occurrenceDate: item.directDebitDate,
                        payPeriodId: item.payPeriodId
                      )
                else { return nil }

                let fundedPence = snapshot.potAllocations
                    .filter {
                        $0.deletedAt == nil &&
                        $0.payPeriodId == item.payPeriodId &&
                        $0.potId == item.potId &&
                        $0.source == .cardPaymentFunding &&
                        $0.creditCardId == item.cardId &&
                        $0.creditCardDirectDebitDate == item.directDebitDate
                    }
                    .reduce(0) { $0 + max(0, $1.amountPence) }
                let remainingPence = max(0, item.amountPence - fundedPence)
                guard remainingPence > 0 else { return nil }

                return PeriodCostItem(
                    id: "planned-card-payment-funding-\(item.id)",
                    label: "\(item.potName) card payment funding",
                    amountPence: remainingPence,
                    date: payPeriod.payday,
                    source: .potAllocation,
                    creditCardId: nil,
                    potId: item.potId,
                    fundingPotId: nil,
                    isProjected: true
                )
            }

        return billItems + spendItems + openingItems + debtItems + cardPaymentItems
    }

    static func calendarEvents(snapshot: PlannerSnapshot, startDate: String, endDate: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        events += snapshot.payPeriods.flatMap { period in
            [
                CalendarEvent(id: "payday-\(period.id)", date: period.payday, title: "Payday", amountPence: period.incomePence, type: .payday, detail: "\(period.startDate) to \(period.endDate)"),
                CalendarEvent(id: "next-payday-\(period.id)", date: period.nextPayday, title: "Next payday", amountPence: nil, type: .payday, detail: "Next period starts"),
            ]
        }

        events += snapshot.oneOffIncomes
            .filter { $0.deletedAt == nil }
            .map {
                CalendarEvent(
                    id: "one-off-income-\($0.id)",
                    date: $0.date,
                    title: $0.name,
                    amountPence: $0.amountPence,
                    type: .payday,
                    detail: $0.note.isEmpty ? "One-off income" : $0.note
                )
            }

        events += resolvedRecurringOccurrences(snapshot: snapshot, payments: snapshot.recurringPayments, startDate: startDate, endDate: endDate).map {
            CalendarEvent(id: "recurring-\($0.id)", date: $0.dueDate, title: $0.payment.name, amountPence: $0.amountPence, type: .recurring, detail: "Recurring \($0.payment.frequency.rawValue)")
        }

        events += snapshot.customPayments.map {
            CalendarEvent(id: "custom-\($0.id)", date: $0.dueDate, title: $0.name, amountPence: $0.amountPence, type: .savedPayment, detail: $0.status.rawValue)
        }

        events += snapshot.transactions.map {
            CalendarEvent(id: "transaction-\($0.id)", date: $0.date, title: $0.note.isEmpty ? "Spending" : $0.note, amountPence: $0.amountPence, type: .spending, detail: $0.paymentMethod?.rawValue ?? $0.type.rawValue)
        }

        events += debtScheduleItems(snapshot: snapshot, payPeriod: nil)
            .filter { $0.status != .paid && $0.status != .cancelled }
            .compactMap { item -> CalendarEvent? in
                guard let debt = snapshot.debts.first(where: { $0.id == item.debtId && $0.status.isActiveLike }) else { return nil }
                return CalendarEvent(id: "debt-\(item.id)", date: item.dueDate, title: debt.name, amountPence: item.plannedAmountPence, type: .debtDue, detail: debt.lender)
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
            let sourceTitle = potAllocationCalendarTitle(
                allocation: allocation,
                potName: potName,
                snapshot: snapshot
            )
            return CalendarEvent(
                id: "allocation-\(allocation.id)",
                date: period.payday,
                title: sourceTitle,
                amountPence: allocation.amountPence,
                type: .allocation,
                detail: "Allocated to \(potName)"
            )
        }

        return events
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date == $1.date ? eventRank($0.type) < eventRank($1.type) : $0.date < $1.date }
    }

    /// Produces the compact Home notification window while keeping each edit
    /// attached to its immutable scheduled occurrence rather than its moved date.
    static func homeDueEvents(snapshot: PlannerSnapshot, asOfDate: String) -> [HomeDueEvent] {
        guard FinanceEngine.isIsoDate(asOfDate) else { return [] }
        let tomorrow = FinanceEngine.addIsoDays(date: asOfDate, days: 1)
        let validDates = Set([asOfDate, tomorrow])
        let activeIncomeOverrides = snapshot.incomeOccurrenceOverrides.filter { $0.deletedAt == nil }

        func incomeOverride(kind: IncomeOccurrenceSourceKind, id: String, scheduledDate: String) -> IncomeOccurrenceOverride? {
            activeIncomeOverrides.first {
                $0.sourceKind == kind && $0.sourceId == id && $0.scheduledDate == scheduledDate
            }
        }

        func incomeDate(_ override: IncomeOccurrenceOverride?, scheduledDate: String) -> String {
            guard override?.state == .confirmed,
                  let actualDate = override?.actualDate,
                  FinanceEngine.isIsoDate(actualDate)
            else { return scheduledDate }
            return actualDate
        }

        func incomeStatus(_ override: IncomeOccurrenceOverride?) -> HomeDueEventStatus {
            switch override?.state {
            case .awaiting: .awaiting
            case .confirmed: .completed
            case .normal, .cancelled, .none: .scheduled
            }
        }

        var events: [HomeDueEvent] = []
        for period in snapshot.payPeriods where period.deletedAt == nil {
            let paycheck = snapshot.paychecks.first { $0.deletedAt == nil && $0.payPeriodId == period.id }
            let sourceId = paycheck?.id ?? period.id
            let override = incomeOverride(kind: .paycheck, id: sourceId, scheduledDate: period.payday)
            guard override?.state != .cancelled else { continue }
            let date = incomeDate(override, scheduledDate: period.payday)
            guard validDates.contains(date) else { continue }
            let baseAmount = paycheck.map { $0.actualAmountPence ?? $0.calculatedAmountPence } ?? period.incomePence
            events.append(HomeDueEvent(
                id: "home-payday-\(sourceId)-\(period.payday)",
                scheduledDate: period.payday,
                date: date,
                title: "Payday",
                amountPence: max(0, override?.amountPenceOverride ?? baseAmount),
                direction: .incoming,
                status: incomeStatus(override),
                sourceLabel: paycheck == nil ? "Pay period" : "Paycheck",
                cycleLabel: "Scheduled \(period.payday)",
                source: .payday(payPeriodId: period.id, paycheckId: paycheck?.id)
            ))
        }

        for income in snapshot.oneOffIncomes where income.deletedAt == nil {
            let override = incomeOverride(kind: .oneOffIncome, id: income.id, scheduledDate: income.date)
            guard override?.state != .cancelled else { continue }
            let date = incomeDate(override, scheduledDate: income.date)
            guard validDates.contains(date) else { continue }
            events.append(HomeDueEvent(
                id: "home-one-off-\(income.id)-\(income.date)",
                scheduledDate: income.date,
                date: date,
                title: income.name,
                amountPence: max(0, override?.amountPenceOverride ?? income.amountPence),
                direction: .incoming,
                status: incomeStatus(override),
                sourceLabel: "One-off income",
                cycleLabel: "Scheduled \(income.date)",
                source: .oneOffIncome(incomeId: income.id)
            ))
        }

        for occurrence in resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments.filter { $0.deletedAt == nil },
            startDate: asOfDate,
            endDate: tomorrow
        ) where validDates.contains(occurrence.dueDate) {
            let occurrenceOverride = snapshot.recurringPaymentOccurrenceOverrides.first {
                $0.deletedAt == nil &&
                $0.paymentId == occurrence.payment.id &&
                $0.scheduledDueDate == occurrence.scheduledDueDate
            }
            events.append(HomeDueEvent(
                id: "home-recurring-\(occurrence.id)",
                scheduledDate: occurrence.scheduledDueDate,
                date: occurrence.dueDate,
                title: occurrence.payment.name,
                amountPence: occurrence.amountPence,
                direction: .outgoing,
                status: occurrence.isAwaitingPayment
                    ? .awaiting
                    : (occurrenceOverride?.state == .confirmed ? .completed : .scheduled),
                sourceLabel: "Recurring bill",
                cycleLabel: "\(occurrence.payment.frequency.rawValue.capitalized) · scheduled \(occurrence.scheduledDueDate)",
                source: .recurringBill(paymentId: occurrence.payment.id, scheduledDueDate: occurrence.scheduledDueDate)
            ))
        }

        for payment in snapshot.customPayments where payment.deletedAt == nil && payment.status != .archived && validDates.contains(payment.dueDate) {
            events.append(HomeDueEvent(
                id: "home-saved-\(payment.id)",
                scheduledDate: payment.dueDate,
                date: payment.dueDate,
                title: payment.name,
                amountPence: max(0, payment.amountPence),
                direction: .outgoing,
                status: payment.status == .paid ? .completed : .scheduled,
                sourceLabel: "Saved payment",
                cycleLabel: "One-off · \(payment.dueDate)",
                source: .savedPayment(paymentId: payment.id)
            ))
        }

        let debtsById = Dictionary(uniqueKeysWithValues: snapshot.debts.filter { $0.deletedAt == nil }.map { ($0.id, $0) })
        for item in debtScheduleItems(snapshot: snapshot, payPeriod: nil)
            where item.deletedAt == nil && item.status != .cancelled {
            guard let debt = debtsById[item.debtId], debt.status.isActiveLike || item.status == .paid else { continue }
            let effectiveDate = item.paidDate ?? item.dueDate
            guard validDates.contains(effectiveDate) else { continue }
            events.append(HomeDueEvent(
                id: "home-debt-\(item.id)",
                scheduledDate: item.dueDate,
                date: effectiveDate,
                title: debt.name,
                amountPence: max(0, item.plannedAmountPence),
                direction: .outgoing,
                status: item.status == .paid ? .completed : (item.status == .overdue || item.status == .missed ? .awaiting : .scheduled),
                sourceLabel: "Debt payment",
                cycleLabel: "Scheduled \(item.dueDate)",
                source: .debtPayment(scheduleItemId: item.id, debtId: item.debtId)
            ))
        }

        let reminderStart = FinanceEngine.addIsoDays(date: asOfDate, days: -45)
        for reminder in creditCardCycleReminders(snapshot: snapshot, asOfDate: reminderStart, months: 3) {
            let card = snapshot.creditCards.first { $0.id == reminder.cardId && !$0.archived && $0.deletedAt == nil }
            guard let card else { continue }
            let override = snapshot.creditCardCycleOverrides.first {
                $0.deletedAt == nil && $0.creditCardId == reminder.cardId && $0.scheduledStatementDate == reminder.scheduledStatementDate
            }
            let payment = creditCardStatementPayments(
                card: card,
                snapshot: snapshot,
                startDate: reminder.directDebitDate,
                endDate: reminder.directDebitDate,
                asOfDate: asOfDate
            ).first { $0.scheduledStatementDate == reminder.scheduledStatementDate }
            let amount = max(0, override?.amountPenceOverride ?? payment?.forecastDuePence ?? 0)

            if validDates.contains(reminder.statementDate) {
                events.append(HomeDueEvent(
                    id: "home-card-statement-\(card.id)-\(reminder.scheduledStatementDate)",
                    scheduledDate: reminder.scheduledStatementDate,
                    date: reminder.statementDate,
                    title: "\(card.name) statement",
                    amountPence: amount,
                    direction: .outgoing,
                    status: override?.statementState == .awaitingConfirmation ? .awaiting : (override?.statementState == .confirmed ? .completed : .scheduled),
                    sourceLabel: "Card statement",
                    cycleLabel: "Statement cycle \(reminder.scheduledStatementDate)",
                    source: .cardStatement(cardId: card.id, scheduledStatementDate: reminder.scheduledStatementDate)
                ))
            }
            if validDates.contains(reminder.directDebitDate) {
                events.append(HomeDueEvent(
                    id: "home-card-direct-debit-\(card.id)-\(reminder.scheduledStatementDate)",
                    scheduledDate: reminder.scheduledStatementDate,
                    date: reminder.directDebitDate,
                    title: "\(card.name) Direct Debit",
                    amountPence: amount,
                    direction: .outgoing,
                    status: override?.directDebitState == .awaitingPayment ? .awaiting : (override?.directDebitState == .confirmed ? .completed : .scheduled),
                    sourceLabel: "Card Direct Debit",
                    cycleLabel: "Statement cycle \(reminder.scheduledStatementDate)",
                    source: .cardDirectDebit(cardId: card.id, scheduledStatementDate: reminder.scheduledStatementDate)
                ))
            }
        }

        return events.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.direction != $1.direction { return $0.direction == .incoming }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private static func potAllocationCalendarTitle(
        allocation: PotAllocation,
        potName: String,
        snapshot: PlannerSnapshot
    ) -> String {
        switch allocation.source {
        case .recurring, .recurringBillFunding, .cardBillFunding:
            if let paymentName = allocation.recurringPaymentId.flatMap({ recurringPaymentId in
                snapshot.recurringPayments.first { $0.id == recurringPaymentId }?.name
            }) {
                return "\(paymentName) funding"
            }
        case .cardSpendFunding:
            if let transaction = allocation.transactionId.flatMap({ transactionId in
                snapshot.transactions.first { $0.id == transactionId }
            }) {
                return transaction.note.isEmpty ? "Card spend funding" : "\(transaction.note) funding"
            }
        case .cardOpeningBalanceFunding:
            if let cardName = allocation.creditCardId.flatMap({ creditCardId in
                snapshot.creditCards.first { $0.id == creditCardId }?.name
            }) {
                return "\(cardName) opening balance"
            }
        case .cardPaymentFunding:
            if let cardName = allocation.creditCardId.flatMap({ creditCardId in
                snapshot.creditCards.first { $0.id == creditCardId }?.name
            }) {
                return "\(cardName) card payment funding"
            }
        case .debtFunding:
            if let debtName = allocation.debtId.flatMap({ debtId in
                snapshot.debts.first { $0.id == debtId }?.name
            }) {
                return "\(debtName) payment funding"
            }
        case .potAuto:
            return "\(potName) payday top-up"
        case .manual, .none:
            break
        }

        return "\(potName) allocation"
    }

    private static func dueDates(for payment: RecurringPayment, startDate: String, endDate: String) -> [String] {
        let effectiveStartDate = max(startDate, payment.createdAt.prefixDate ?? startDate)
        guard effectiveStartDate <= endDate else { return [] }

        switch payment.frequency {
        case .once:
            guard let dueDate = payment.dueDate else { return [] }
            return dueDate >= effectiveStartDate && dueDate <= endDate ? [dueDate] : []
        case .monthly:
            guard let dueDay = payment.dueDay else { return [] }
            return monthlyDueDates(dueDay: dueDay, startDate: effectiveStartDate, endDate: endDate)
        case .yearly:
            guard let dueDate = payment.dueDate ?? payment.createdAt.prefixDate else { return [] }
            return yearlyDueDates(seedDate: dueDate, startDate: effectiveStartDate, endDate: endDate)
        case .weekly:
            return intervalDueDates(seedDate: payment.dueDate ?? payment.createdAt.prefixDate, intervalDays: 7, startDate: effectiveStartDate, endDate: endDate)
        case .biweekly:
            return intervalDueDates(seedDate: payment.dueDate ?? payment.createdAt.prefixDate, intervalDays: 14, startDate: effectiveStartDate, endDate: endDate)
        case .quarterly:
            return intervalMonthDueDates(seedDate: payment.dueDate ?? payment.createdAt.prefixDate, intervalMonths: 3, startDate: effectiveStartDate, endDate: endDate)
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

    private static func intervalMonthDueDates(seedDate: String?, intervalMonths: Int, startDate: String, endDate: String) -> [String] {
        guard let seedDate else { return [] }
        var cursor = seedDate

        while cursor < startDate {
            cursor = addIsoMonthsClamped(date: cursor, months: intervalMonths)
        }

        var dates: [String] = []
        while cursor <= endDate {
            dates.append(cursor)
            cursor = addIsoMonthsClamped(date: cursor, months: intervalMonths)
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

    private static var emptyPayPeriodCostSummary: PayPeriodCostSummary {
        PayPeriodCostSummary(
            payReceivedPence: 0,
            directRecurringPence: 0,
            savedPaymentsPence: 0,
            manualSpendingPence: 0,
            potAllocationsPence: 0,
            debtMinimumsPence: 0,
            debtReservesPence: 0,
            creditCardPotsPence: 0,
            creditCardChargesPence: 0,
            creditCardRepaymentsPence: 0,
            creditCardNetPence: 0,
            committedCostsPence: 0,
            unfundedChecklistPence: 0,
            projectedCostsPence: 0,
            currentMoneyLeftPence: 0,
            projectedMoneyLeftPence: 0,
            totalCostsPence: 0,
            moneyLeftPence: 0,
            isOverCommitted: false,
            items: []
        )
    }

    private static func createPayPeriodCostSummary(
        payReceivedPence: Int,
        plannedCostsPence: Int,
        items: [PeriodCostItem]
    ) -> PayPeriodCostSummary {
        func totalCosts(for scopedItems: [PeriodCostItem]) -> Int {
            let directRecurringPence = sumPositive(scopedItems.filter { $0.source == .recurring && $0.creditCardId == nil })
            let savedPaymentsPence = sumPositive(scopedItems.filter { $0.source == .savedPayment && $0.creditCardId == nil })
            let manualSpendingPence = sumPositive(scopedItems.filter { $0.source == .manualSpend && $0.creditCardId == nil })
            let potAllocationsPence = sumPositive(scopedItems.filter { $0.source == .potAllocation && $0.fundingPotId == nil })
            let debtMinimumsPence = sumPositive(scopedItems.filter { $0.source == .debtMinimum })
            let debtReservesPence = sumPositive(scopedItems.filter { $0.source == .debtReserve })
            let creditCardPotsPence = sumPositive(scopedItems.filter { $0.source == .creditCardPot })
            let creditCardRepaymentsPence = abs(scopedItems.filter { $0.source == .creditCardRepayment }.reduce(0) { $0 + $1.amountPence })
            return directRecurringPence + savedPaymentsPence + manualSpendingPence + potAllocationsPence + debtMinimumsPence + debtReservesPence + creditCardPotsPence + creditCardRepaymentsPence
        }

        let directRecurringPence = sumPositive(items.filter { $0.source == .recurring && $0.creditCardId == nil })
        let savedPaymentsPence = sumPositive(items.filter { $0.source == .savedPayment && $0.creditCardId == nil })
        let manualSpendingPence = sumPositive(items.filter { $0.source == .manualSpend && $0.creditCardId == nil })
        let potAllocationsPence = sumPositive(items.filter { $0.source == .potAllocation && $0.fundingPotId == nil })
        let debtMinimumsPence = sumPositive(items.filter { $0.source == .debtMinimum })
        let debtReservesPence = sumPositive(items.filter { $0.source == .debtReserve })
        let creditCardPotsPence = sumPositive(items.filter { $0.source == .creditCardPot })
        let creditCardChargesPence = sumPositive(
            items.filter {
                $0.creditCardId != nil &&
                ($0.source == .recurring || $0.source == .savedPayment || $0.source == .manualSpend)
            }
        )
        let creditCardRepaymentsPence = abs(items.filter { $0.source == .creditCardRepayment }.reduce(0) { $0 + $1.amountPence })
        let creditCardNetPence = creditCardRepaymentsPence
        let totalCostsPence = directRecurringPence + savedPaymentsPence + manualSpendingPence + potAllocationsPence + debtMinimumsPence + debtReservesPence + creditCardPotsPence + creditCardNetPence
        let moneyLeftPence = payReceivedPence - totalCostsPence
        let committedCostsPence = totalCosts(for: items.filter { !$0.isProjected })
        let unfundedChecklistPence = totalCosts(for: items.filter(\.isProjected))
        let projectedCostsPence = max(0, plannedCostsPence)
        let currentMoneyLeftPence = payReceivedPence - committedCostsPence
        let projectedMoneyLeftPence = payReceivedPence - projectedCostsPence

        return PayPeriodCostSummary(
            payReceivedPence: payReceivedPence,
            directRecurringPence: directRecurringPence,
            savedPaymentsPence: savedPaymentsPence,
            manualSpendingPence: manualSpendingPence,
            potAllocationsPence: potAllocationsPence,
            debtMinimumsPence: debtMinimumsPence,
            debtReservesPence: debtReservesPence,
            creditCardPotsPence: creditCardPotsPence,
            creditCardChargesPence: creditCardChargesPence,
            creditCardRepaymentsPence: creditCardRepaymentsPence,
            creditCardNetPence: creditCardNetPence,
            committedCostsPence: committedCostsPence,
            unfundedChecklistPence: unfundedChecklistPence,
            projectedCostsPence: projectedCostsPence,
            currentMoneyLeftPence: currentMoneyLeftPence,
            projectedMoneyLeftPence: projectedMoneyLeftPence,
            totalCostsPence: totalCostsPence,
            moneyLeftPence: moneyLeftPence,
            isOverCommitted: projectedMoneyLeftPence < 0,
            items: items
        )
    }

    private static func applyLinkedPotBalances(to items: [PeriodCostItem], pots: [Pot]) -> [PeriodCostItem] {
        var availableBalanceByPot = pots
            .filter { !$0.archived }
            .reduce(into: [String: Int]()) { result, pot in
                result[pot.id] = max(0, pot.balancePence)
            }

        return items.map { item in
            guard let potId = item.potId, item.amountPence > 0 else { return item }
            let availablePence = availableBalanceByPot[potId, default: 0]
            guard availablePence > 0 else { return item }

            let coveredPence = min(item.amountPence, availablePence)
            availableBalanceByPot[potId] = availablePence - coveredPence

            var copy = item
            copy.amountPence -= coveredPence
            return copy
        }
    }

    private static func activeLinkedDebtPots(snapshot: PlannerSnapshot, debtId: String) -> [Pot] {
        snapshot.pots
            .filter { !$0.archived && $0.linkedDebtId == debtId && $0.linkedCreditCardId == nil }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
    }

    private static func activeLinkedCreditCardPots(snapshot: PlannerSnapshot, creditCardId: String) -> [Pot] {
        snapshot.pots
            .filter { !$0.archived && $0.linkedCreditCardId == creditCardId }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name {
                    return lhs.id < rhs.id
                }
                return lhs.name < rhs.name
            }
    }

    private static func linkedCreditCardChecklistFundingPence(
        snapshot: PlannerSnapshot,
        payPeriodId: String?,
        linkedPotIds: Set<String>,
        excluding isExcluded: (PotAllocation) -> Bool
    ) -> Int {
        snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                (payPeriodId == nil || $0.payPeriodId == payPeriodId) &&
                linkedPotIds.contains($0.potId) &&
                isCreditCardChecklistFundingSource($0.source) &&
                !isExcluded($0)
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }
    }

    private static func recurringBillFundingKey(paymentId: String, dueDate: String) -> String {
        "\(paymentId)|\(dueDate)"
    }

    private static func isRecurringBillFundingSource(_ source: PotAllocationSource?) -> Bool {
        source == .recurringBillFunding || source == .cardBillFunding
    }

    private static func isCreditCardChecklistFundingSource(_ source: PotAllocationSource?) -> Bool {
        switch source {
        case .some(.recurringBillFunding), .some(.cardBillFunding), .some(.cardSpendFunding), .some(.cardOpeningBalanceFunding), .some(.cardPaymentFunding):
            return true
        default:
            return false
        }
    }

    private static func selectedCardRecurringBillTargetPence(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        today: String,
        potId: String
    ) -> Int {
        recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.potId == potId &&
                $0.cardId != nil &&
                $0.dueDate >= today &&
                paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }
    }

    private static func directRecurringBillTargetItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        today: String,
        potId: String
    ) -> [RecurringBillFundingChecklistItem] {
        if payPeriod != nil {
            let payPeriod = payPeriod
            return recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                .filter {
                    let paidDate = paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: today)
                    return $0.potId == potId &&
                    $0.cardId == nil &&
                    $0.dueDate >= today &&
                    (paidDate == nil || isUnfundedPaydayDirectRecurringBillAlreadyPaid(item: $0, paidDate: paidDate, payPeriod: payPeriod))
                }
        }

        guard let pot = snapshot.pots.first(where: { $0.id == potId && !$0.archived }) else {
            return []
        }

        return snapshot.recurringPayments
            .filter { $0.active && $0.potId == potId && $0.creditCardId == nil }
            .compactMap { payment -> RecurringBillFundingChecklistItem? in
                let dueDate = payment.dueDate ?? payment.dueDay.map { nextDueDayIso(dueDay: $0, today: today) }
                guard let dueDate, dueDate >= today else { return nil }

                let item = RecurringBillFundingChecklistItem(
                    id: recurringBillFundingChecklistId(paymentId: payment.id, dueDate: dueDate),
                    paymentId: payment.id,
                    paymentName: payment.name,
                    amountPence: payment.amountPence,
                    dueDate: dueDate,
                    fundingDueDate: dueDate,
                    payPeriodId: "",
                    cardId: nil,
                    cardName: nil,
                    potId: potId,
                    potName: pot.name,
                    isCompleted: false
                )

                return paidDateForRecurringBillFunding(item: item, snapshot: snapshot, asOfDate: today) == nil ? item : nil
            }
    }

    private static func selectedCardRecurringBillTargetPence(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        today: String,
        cardId: String,
        excludingPotId: String
    ) -> Int {
        recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.cardId == cardId &&
                $0.potId != excludingPotId &&
                $0.dueDate >= today &&
                paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }
    }

    private static func selectedCardRecurringBillDueDate(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        today: String,
        potId: String
    ) -> String? {
        recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.potId == potId &&
                $0.cardId != nil &&
                $0.dueDate >= today &&
                paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
            }
            .map(\.dueDate)
            .sorted()
            .first
    }

    private static func sumPositive(_ items: [PeriodCostItem]) -> Int {
        items.reduce(0) { total, item in
            item.amountPence > 0 ? total + item.amountPence : total
        }
    }

    private static func isIsoDate(_ date: String, in payPeriod: PayPeriod) -> Bool {
        date >= payPeriod.startDate && date <= payPeriod.endDate
    }

    private static func isDebtReserve(_ reserve: DebtReserve, in payPeriod: PayPeriod) -> Bool {
        reserve.payPeriodId == payPeriod.id ||
        reserve.payday == payPeriod.payday ||
        (reserve.periodStartDate == payPeriod.startDate && reserve.periodEndDate == payPeriod.endDate) ||
        isIsoDate(reserve.payday, in: payPeriod)
    }

    private static func isCreditCardPot(_ creditCardPot: CreditCardPot, in payPeriod: PayPeriod) -> Bool {
        creditCardPot.payPeriodId == payPeriod.id ||
        creditCardPot.payday == payPeriod.payday ||
        (creditCardPot.periodStartDate == payPeriod.startDate && creditCardPot.periodEndDate == payPeriod.endDate) ||
        (creditCardPot.payday.map { isIsoDate($0, in: payPeriod) } ?? false)
    }

    private static func creditCardRepaymentPaycheckContribution(_ repayment: CreditCardRepayment) -> Int {
        if let paycheckContributionPence = repayment.paycheckContributionPence {
            return max(0, paycheckContributionPence)
        }

        if repayment.source == .linkedPotStatement || repayment.id.hasPrefix("linked-card-pot-repayment-") {
            return 0
        }

        return max(0, repayment.amountPence)
    }

    private static func eventRankForCostItem(_ source: PeriodCostItemSource) -> Int {
        switch source {
        case .recurring: 0
        case .savedPayment: 1
        case .manualSpend: 2
        case .potAllocation: 3
        case .debtMinimum: 4
        case .debtReserve: 5
        case .creditCardPot: 6
        case .creditCardRepayment: 7
        }
    }
}

private enum CreditCardAllocationItemSource {
    case recurring
    case custom
    case spending
    case repayment
}

private struct CreditCardAllocationItem {
    var creditCardId: String?
    var amountPence: Int
    var date: String
    var source: CreditCardAllocationItemSource
}

private enum CreditCardStatementLineSource {
    case openingStatement
    case spending
    case recurring
    case custom
    case repayment
}

private struct CreditCardStatementLine {
    var amountPence: Int
    var date: String
    var source: CreditCardStatementLineSource
}

private struct CardPaymentBreakdownComponent {
    var id: String
    var title: String
    var detail: String
    var date: String
    var amountPence: Int
}

private extension PlannerDerivedData {
    static func cardPaymentFundingBreakdown(
        item: CreditCardPaymentFundingChecklistItem,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> [FundingChecklistBreakdownItem] {
        let fallback = [
            FundingChecklistBreakdownItem(
                id: "card-payment-\(item.id)",
                title: "\(item.cardName) statement payment",
                detail: "Direct debit due \(shortDate(item.directDebitDate))",
                amountPence: item.amountPence
            )
        ]

        guard let card = snapshot.creditCards.first(where: { $0.id == item.cardId && !$0.archived }),
              let payPeriod = snapshot.payPeriods.first(where: { $0.id == item.payPeriodId }),
              let pot = snapshot.pots.first(where: { $0.id == item.potId && !$0.archived })
        else { return fallback }

        let matchingCardPaymentFundingPence = snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.payPeriodId == item.payPeriodId &&
                $0.potId == item.potId &&
                $0.source == .cardPaymentFunding &&
                $0.creditCardId == item.cardId
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }
        let specificChecklistFundingPence = snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.payPeriodId == item.payPeriodId &&
                $0.potId == item.potId &&
                (
                    isRecurringBillFundingSource($0.source) ||
                    $0.source == .cardSpendFunding ||
                    $0.source == .cardOpeningBalanceFunding
                )
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }
        var availableGeneralPotPence = max(
            0,
            pot.balancePence - matchingCardPaymentFundingPence - specificChecklistFundingPence
        )

        let recurringItems = recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter { $0.cardId == item.cardId && $0.potId == item.potId }
        let recurringItemsByOccurrence = Dictionary(
            uniqueKeysWithValues: recurringItems.map { ("\($0.paymentId):\($0.dueDate)", $0) }
        )
        let cardSpendItems = cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter { $0.cardId == item.cardId && $0.potId == item.potId }
        let cardSpendItemsByTransaction = Dictionary(
            uniqueKeysWithValues: cardSpendItems.map { ($0.transactionId, $0) }
        )
        let openingItem = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .first { $0.cardId == item.cardId && $0.potId == item.potId }
        let recurringPaymentsById = Dictionary(
            uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) }
        )

        var components: [CardPaymentBreakdownComponent] = []
        let openingBalancePence = max(0, card.openingBalancePence ?? 0)
        if openingBalancePence > 0 {
            let separatelyFundedPence: Int
            if let openingItem,
               !isFundingChecklistExcluded(
                    snapshot: snapshot,
                    kind: .cardOpeningBalance,
                    sourceId: openingItem.cardId,
                    occurrenceDate: openingItem.directDebitDate,
                    payPeriodId: openingItem.payPeriodId
               ) {
                separatelyFundedPence = min(openingBalancePence, openingItem.amountPence)
            } else {
                separatelyFundedPence = 0
            }
            let includedPence = max(0, openingBalancePence - separatelyFundedPence)
            if includedPence > 0 {
                components.append(
                    CardPaymentBreakdownComponent(
                        id: "card-payment-opening-\(item.id)",
                        title: "Opening balance",
                        detail: breakdownDetail(
                            base: "Opening card balance",
                            separatelyFundedPence: separatelyFundedPence
                        ),
                        date: card.createdAt.prefixDate ?? payPeriod.startDate,
                        amountPence: includedPence
                    )
                )
            }
        }

        components += snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id &&
                $0.date <= asOfDate
            }
            .compactMap { transaction -> CardPaymentBreakdownComponent? in
                let transactionName = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = transaction.recurringPaymentId
                    .flatMap { recurringPaymentsById[$0]?.name }
                    ?? (transactionName.isEmpty ? "Card spend" : transactionName)
                let separatelyFundedPence: Int

                if let recurringPaymentId = transaction.recurringPaymentId,
                   let recurringItem = recurringItemsByOccurrence["\(recurringPaymentId):\(transaction.date)"] {
                    guard recurringPaymentsById[recurringPaymentId]?.potId == item.potId else { return nil }
                    let isExcluded = isFundingChecklistExcluded(
                        snapshot: snapshot,
                        kind: .cardBill,
                        sourceId: recurringItem.paymentId,
                        occurrenceDate: recurringItem.dueDate,
                        payPeriodId: recurringItem.payPeriodId
                    )
                    separatelyFundedPence = isExcluded ? 0 : min(transaction.amountPence, recurringItem.amountPence)
                } else if transaction.recurringPaymentId != nil {
                    separatelyFundedPence = 0
                } else if let spendItem = cardSpendItemsByTransaction[transaction.id] {
                    let isExcluded = isFundingChecklistExcluded(
                        snapshot: snapshot,
                        kind: .cardSpend,
                        sourceId: spendItem.transactionId,
                        occurrenceDate: spendItem.transactionDate,
                        payPeriodId: spendItem.payPeriodId
                    )
                    separatelyFundedPence = isExcluded ? 0 : min(transaction.amountPence, spendItem.amountPence)
                } else {
                    separatelyFundedPence = 0
                }

                let includedPence = max(0, transaction.amountPence - separatelyFundedPence)
                guard includedPence > 0 else { return nil }
                return CardPaymentBreakdownComponent(
                    id: "card-payment-transaction-\(item.id)-\(transaction.id)",
                    title: title,
                    detail: breakdownDetail(
                        base: "\(transaction.recurringPaymentId == nil ? "Card spend" : "Card bill") · \(shortDate(transaction.date))",
                        separatelyFundedPence: separatelyFundedPence
                    ),
                    date: transaction.date,
                    amountPence: includedPence
                )
            }

        components += resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments,
            startDate: payPeriod.startDate,
            endDate: payPeriod.endDate
        )
            .filter {
                $0.dueDate > asOfDate &&
                $0.payment.creditCardId == item.cardId &&
                $0.payment.potId == item.potId
            }
            .compactMap { occurrence -> CardPaymentBreakdownComponent? in
                let recurringItem = recurringItemsByOccurrence["\(occurrence.payment.id):\(occurrence.dueDate)"]
                let isExcluded = recurringItem.map {
                    isFundingChecklistExcluded(
                        snapshot: snapshot,
                        kind: .cardBill,
                        sourceId: $0.paymentId,
                        occurrenceDate: $0.dueDate,
                        payPeriodId: $0.payPeriodId
                    )
                } ?? true
                let separatelyFundedPence = isExcluded
                    ? 0
                    : min(occurrence.amountPence, recurringItem?.amountPence ?? 0)
                let includedPence = max(0, occurrence.amountPence - separatelyFundedPence)
                guard includedPence > 0 else { return nil }
                return CardPaymentBreakdownComponent(
                    id: "card-payment-recurring-\(item.id)-\(occurrence.payment.id)-\(occurrence.dueDate)",
                    title: occurrence.payment.name,
                    detail: breakdownDetail(
                        base: "Scheduled card bill · \(shortDate(occurrence.dueDate))",
                        separatelyFundedPence: separatelyFundedPence
                    ),
                    date: occurrence.dueDate,
                    amountPence: includedPence
                )
            }

        components += snapshot.customPayments
            .filter {
                $0.deletedAt == nil &&
                $0.status == .unpaid &&
                $0.creditCardId == item.cardId &&
                $0.dueDate > asOfDate &&
                $0.dueDate >= payPeriod.startDate &&
                $0.dueDate <= payPeriod.endDate
            }
            .map {
                CardPaymentBreakdownComponent(
                    id: "card-payment-custom-\(item.id)-\($0.id)",
                    title: $0.name,
                    detail: "Scheduled card payment · \(shortDate($0.dueDate))",
                    date: $0.dueDate,
                    amountPence: $0.amountPence
                )
            }

        components.sort {
            if $0.date == $1.date { return $0.title < $1.title }
            return $0.date < $1.date
        }
        applyCardPaymentCoverage(&components, coveragePence: &availableGeneralPotPence)

        let derivedTotalPence = components.reduce(0) { $0 + max(0, $1.amountPence) }
        if derivedTotalPence > item.amountPence {
            var extraCoveragePence = derivedTotalPence - item.amountPence
            applyCardPaymentCoverage(&components, coveragePence: &extraCoveragePence)
        } else if derivedTotalPence < item.amountPence {
            components.insert(
                CardPaymentBreakdownComponent(
                    id: "card-payment-existing-reserve-\(item.id)",
                    title: "Existing card payment reserve",
                    detail: "Previously included in this funding total",
                    date: payPeriod.startDate,
                    amountPence: item.amountPence - derivedTotalPence
                ),
                at: 0
            )
        }

        let breakdown = components
            .filter { $0.amountPence > 0 }
            .map {
                FundingChecklistBreakdownItem(
                    id: $0.id,
                    title: $0.title,
                    detail: $0.detail,
                    amountPence: $0.amountPence
                )
            }

        return breakdown.isEmpty ? fallback : breakdown
    }

    static func breakdownDetail(base: String, separatelyFundedPence: Int) -> String {
        guard separatelyFundedPence > 0 else { return base }
        return "\(base) · \(MoneyParser.formatPence(separatelyFundedPence)) shown separately"
    }

    static func applyCardPaymentCoverage(
        _ components: inout [CardPaymentBreakdownComponent],
        coveragePence: inout Int
    ) {
        guard coveragePence > 0 else { return }

        for index in components.indices where coveragePence > 0 {
            let coveredPence = min(components[index].amountPence, coveragePence)
            guard coveredPence > 0 else { continue }
            components[index].amountPence -= coveredPence
            coveragePence -= coveredPence
            components[index].detail += " · \(MoneyParser.formatPence(coveredPence)) already covered"
        }
    }

    static func paidOpeningBalanceFundingPresentationItems(
        snapshot: PlannerSnapshot,
        payPeriod: PayPeriod?,
        asOfDate: String,
        excludingIds: Set<String>
    ) -> [FundingChecklistPresentationItem] {
        guard let payPeriod else { return [] }

        let cardsById = snapshot.creditCards.reduce(into: [String: CreditCard]()) { result, card in
            result[card.id] = card
        }
        let potsById = snapshot.pots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }

        return snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.payPeriodId == payPeriod.id &&
                $0.source == .cardOpeningBalanceFunding &&
                $0.amountPence > 0
            }
            .compactMap { allocation -> FundingChecklistPresentationItem? in
                guard let cardId = allocation.creditCardId,
                      let directDebitDate = allocation.creditCardDirectDebitDate,
                      directDebitDate >= payPeriod.startDate,
                      directDebitDate <= payPeriod.endDate,
                      let card = cardsById[cardId],
                      let pot = potsById[allocation.potId]
                else { return nil }

                let checklistId = "card-opening-\(cardOpeningBalanceFundingChecklistId(cardId: cardId, directDebitDate: directDebitDate))"
                guard !excludingIds.contains(checklistId) else { return nil }

                let paidDate = snapshot.creditCardRepayments
                    .filter {
                        $0.deletedAt == nil &&
                        $0.creditCardId == cardId &&
                        ($0.directDebitDate ?? $0.date) == directDebitDate &&
                        $0.date <= asOfDate &&
                        $0.amountPence > 0
                    }
                    .map(\.date)
                    .sorted()
                    .first

                guard let paidDate else { return nil }

                return FundingChecklistPresentationItem(
                    id: checklistId,
                    name: "\(card.name) opening balance",
                    title: "Add \(MoneyParser.formatPence(allocation.amountPence)) to \(pot.name)",
                    detail: "\(card.name) opening balance · due \(shortDate(directDebitDate))",
                    amountPence: allocation.amountPence,
                    dueDate: directDebitDate,
                    breakdown: [
                        FundingChecklistBreakdownItem(
                            id: "opening-allocation-\(allocation.id)",
                            title: "Opening statement balance",
                            detail: "\(card.name) · due \(shortDate(directDebitDate))",
                            amountPence: allocation.amountPence
                        )
                    ],
                    isCompleted: true,
                    isExcluded: false,
                    status: .paidCompleted,
                    paidDate: paidDate,
                    action: .cardOpeningBalance(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriod.id)
                )
            }
    }

    static func potDueObligations(pot: Pot, snapshot: PlannerSnapshot, today: String) -> [PotDueObligation] {
        let payPeriod = currentOrLatestPayPeriod(snapshot.payPeriods, today: today)
        var obligations: [PotDueObligation] = []

        obligations += recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.potId == pot.id &&
                ($0.cardId == nil ? $0.dueDate >= today : $0.dueDate > today) &&
                paidDateForRecurringBillFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
            }
            .map {
                PotDueObligation(
                    amountPence: max(0, $0.amountPence),
                    dueIso: $0.dueDate,
                    label: $0.paymentName,
                    source: $0.cardId == nil ? .recurringBill : .cardBill
                )
            }

        if pot.linkedCreditCardId != nil {
            let cardSpendItems = cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                .filter {
                    $0.potId == pot.id &&
                    $0.dueDate >= today &&
                    paidDateForCardSpendFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
                }
                .map {
                    PotDueObligation(
                        amountPence: max(0, $0.amountPence),
                        dueIso: $0.dueDate,
                        label: $0.transactionName,
                        source: .cardSpend
                    )
                }

            let openingItems = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                .filter {
                    $0.potId == pot.id &&
                    $0.directDebitDate >= today &&
                    paidDateForOpeningBalanceFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
                }
                .map {
                    PotDueObligation(
                        amountPence: max(0, $0.amountPence),
                        dueIso: $0.directDebitDate,
                        label: "\($0.cardName) opening balance",
                        source: .cardOpeningBalance
                    )
                }

            obligations += cardSpendItems + openingItems
        }

        if pot.linkedDebtId != nil {
            obligations += debtFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                .filter {
                    $0.potId == pot.id &&
                    $0.dueDate >= today &&
                    paidDateForDebtFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
                }
                .map {
                    PotDueObligation(
                        amountPence: max(0, $0.amountPence),
                        dueIso: $0.dueDate,
                        label: $0.debtName,
                        source: .debt
                    )
                }
        }

        return obligations
            .filter { $0.amountPence > 0 }
            .sorted { lhs, rhs in
                if lhs.dueIso == rhs.dueIso {
                    if lhs.amountPence == rhs.amountPence {
                        return lhs.label < rhs.label
                    }
                    return lhs.amountPence > rhs.amountPence
                }
                return lhs.dueIso < rhs.dueIso
            }
    }

    static func linkedCreditCardPayments(pot: Pot, snapshot: PlannerSnapshot, today: String) -> [LinkedCardPaymentDue] {
        guard let cardId = pot.linkedCreditCardId,
              let card = snapshot.creditCards.first(where: { $0.id == cardId && !$0.archived })
        else { return [] }

        let endDate = addIsoMonthsClamped(date: today, months: 12)
        let statementRows = creditCardStatementPayments(
            card: card,
            snapshot: snapshot,
            startDate: today,
            endDate: endDate,
            asOfDate: today
        )
        .compactMap { payment -> LinkedCardPaymentDue? in
            let amountPence = max(payment.actualDuePence, payment.forecastDuePence)
            guard amountPence > 0 else { return nil }

            return LinkedCardPaymentDue(
                cardId: card.id,
                cardName: card.name,
                statementIso: payment.statementDate,
                dueIso: payment.directDebitDate,
                amountPence: amountPence
            )
        }

        let heldRows = creditCardStatementCycles(card: card, snapshot: snapshot, through: endDate)
            .filter { $0.isHeld && $0.directDebitDate >= today && $0.directDebitDate <= endDate }
            .compactMap { cycle -> LinkedCardPaymentDue? in
                let amountPence = creditCardHeldCycleReservePence(card: card, snapshot: snapshot, asOfDate: today)
                guard amountPence > 0 else { return nil }
                return LinkedCardPaymentDue(
                    cardId: card.id,
                    cardName: card.name,
                    statementIso: cycle.statementDate,
                    dueIso: cycle.directDebitDate,
                    amountPence: amountPence
                )
            }

        let payPeriod = currentOrLatestPayPeriod(snapshot.payPeriods, today: today)
        let openingRows = cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
            .filter {
                $0.cardId == card.id &&
                $0.potId == pot.id &&
                $0.directDebitDate >= today &&
                paidDateForOpeningBalanceFunding(item: $0, snapshot: snapshot, asOfDate: today) == nil
            }
            .map {
                LinkedCardPaymentDue(
                    cardId: card.id,
                    cardName: card.name,
                    statementIso: card.statementDate ?? $0.directDebitDate,
                    dueIso: $0.directDebitDate,
                    amountPence: $0.amountPence
                )
            }

        return mergeLinkedCardPaymentRows(statementRows + heldRows + openingRows)
        .prefix(2)
        .map { $0 }
    }

    private static func mergeLinkedCardPaymentRows(_ rows: [LinkedCardPaymentDue]) -> [LinkedCardPaymentDue] {
        var rowsByCardDueDateAndStatement: [String: LinkedCardPaymentDue] = [:]

        for row in rows where row.amountPence > 0 {
            let key = "\(row.cardId)-\(row.dueIso)-\(row.statementIso)"
            guard let existing = rowsByCardDueDateAndStatement[key] else {
                rowsByCardDueDateAndStatement[key] = row
                continue
            }

            if row.amountPence > existing.amountPence {
                rowsByCardDueDateAndStatement[key] = row
            }
        }

        var rowsByCardAndDueDate: [String: LinkedCardPaymentDue] = [:]

        for row in rowsByCardDueDateAndStatement.values {
            let key = "\(row.cardId)-\(row.dueIso)"
            guard let existing = rowsByCardAndDueDate[key] else {
                rowsByCardAndDueDate[key] = row
                continue
            }

            var merged = existing
            merged.amountPence += row.amountPence
            if row.statementIso < existing.statementIso {
                merged.statementIso = row.statementIso
            }
            rowsByCardAndDueDate[key] = merged
        }

        return rowsByCardAndDueDate.values.sorted {
            if $0.dueIso == $1.dueIso {
                if $0.amountPence == $1.amountPence {
                    return $0.statementIso < $1.statementIso
                }
                return $0.amountPence > $1.amountPence
            }
            return $0.dueIso < $1.dueIso
        }
    }

    static func activeLinkedCreditCardReserveTargetPence(
        potId: String,
        cardId: String,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> Int {
        snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.potId == potId &&
                (
                    $0.source == .recurringBillFunding ||
                    $0.source == .cardBillFunding ||
                    $0.source == .cardSpendFunding
                )
            }
            .reduce(0) { total, allocation in
                total + activeLinkedCreditCardReserveAmountPence(
                    allocation: allocation,
                    cardId: cardId,
                    snapshot: snapshot,
                    asOfDate: asOfDate
                )
            }
    }

    private static func activeLinkedCreditCardReserveAmountPence(
        allocation: PotAllocation,
        cardId: String,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> Int {
        switch allocation.source {
        case .recurringBillFunding, .cardBillFunding:
            guard let recurringPaymentId = allocation.recurringPaymentId,
                  let recurringDueDate = allocation.recurringDueDate
            else { return 0 }
            let recurringPayment = snapshot.recurringPayments.first { $0.id == recurringPaymentId }
            guard allocation.creditCardId == cardId || (allocation.creditCardId == nil && recurringPayment?.creditCardId == cardId) else {
                return 0
            }

            let hasConsumedTransaction = snapshot.transactions.contains {
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == cardId &&
                $0.potId == allocation.potId &&
                $0.recurringPaymentId == recurringPaymentId &&
                $0.date == recurringDueDate &&
                $0.date <= asOfDate
            }
            guard !hasConsumedTransaction else { return 0 }

            let sourceAmountPence = snapshot.recurringPayments
                .first { $0.id == recurringPaymentId }
                .map { max(0, $0.amountPence) } ?? 0
            return max(max(0, allocation.amountPence), sourceAmountPence)

        case .cardSpendFunding:
            guard let transactionId = allocation.transactionId,
                  let transaction = snapshot.transactions.first(where: {
                      $0.id == transactionId &&
                      $0.deletedAt == nil &&
                      $0.creditCardId == cardId
                  })
            else { return 0 }

            guard let card = snapshot.creditCards.first(where: { $0.id == cardId && !$0.archived }),
                  let statementDate = creditCardStatementDate(for: card, snapshot: snapshot, chargeDate: allocation.transactionDate ?? transaction.date)
            else { return max(0, allocation.amountPence) }

            let hasStatementRepayment = snapshot.creditCardRepayments.contains {
                $0.deletedAt == nil &&
                $0.creditCardId == cardId &&
                $0.date <= asOfDate &&
                $0.amountPence > 0 &&
                ($0.statementDate == statementDate || ($0.statementDate == nil && $0.directDebitDate == allocation.creditCardDirectDebitDate))
            }
            guard !hasStatementRepayment else { return 0 }

            return max(max(0, allocation.amountPence), max(0, transaction.amountPence))

        case .cardOpeningBalanceFunding:
            guard allocation.creditCardId == cardId,
                  let directDebitDate = allocation.creditCardDirectDebitDate
            else { return 0 }

            let hasOpeningRepayment = snapshot.creditCardRepayments.contains {
                $0.deletedAt == nil &&
                $0.creditCardId == cardId &&
                ($0.directDebitDate ?? $0.date) == directDebitDate &&
                $0.date <= asOfDate &&
                $0.amountPence > 0
            }
            guard !hasOpeningRepayment else { return 0 }

            let openingAmountPence = snapshot.creditCards
                .first { $0.id == cardId }
                .map { max(0, $0.openingStatementBalancePence ?? $0.openingBalancePence ?? 0) } ?? 0
            return max(max(0, allocation.amountPence), openingAmountPence)

        case .cardPaymentFunding:
            return 0

        default:
            return 0
        }
    }

    static func checklistStatus(isCompleted: Bool, paidDate: String?) -> FundingChecklistStatus {
        if paidDate != nil {
            return .paidCompleted
        }

        return isCompleted ? .activeReserved : .needsFunding
    }

    static func isFundingChecklistExcluded(
        snapshot: PlannerSnapshot,
        kind: FundingChecklistExclusionKind,
        sourceId: String,
        occurrenceDate: String,
        payPeriodId: String,
        matchAcrossPayPeriods: Bool = false
    ) -> Bool {
        snapshot.fundingChecklistExclusions.contains {
            $0.deletedAt == nil &&
            $0.kind == kind &&
            $0.sourceId == sourceId &&
            $0.occurrenceDate == occurrenceDate &&
            (matchAcrossPayPeriods || $0.payPeriodId == payPeriodId)
        }
    }

    private static func isUnfundedPaydayDirectRecurringBillAlreadyPaid(
        item: RecurringBillFundingChecklistItem,
        paidDate: String?,
        payPeriod: PayPeriod?
    ) -> Bool {
        guard let payPeriod,
              item.cardId == nil,
              !item.isCompleted,
              item.dueDate == payPeriod.payday,
              paidDate != nil
        else { return false }

        return true
    }

    private static func sortFundingChecklistPresentationItems(
        _ lhs: FundingChecklistPresentationItem,
        _ rhs: FundingChecklistPresentationItem
    ) -> Bool {
        if lhs.status == .paidCompleted || rhs.status == .paidCompleted {
            if lhs.status != rhs.status {
                return lhs.status != .paidCompleted
            }

            let lhsPaidDate = lhs.paidDate ?? lhs.dueDate
            let rhsPaidDate = rhs.paidDate ?? rhs.dueDate
            if lhsPaidDate == rhsPaidDate {
                return lhs.name < rhs.name
            }
            return lhsPaidDate > rhsPaidDate
        }

        if lhs.dueDate == rhs.dueDate {
            return lhs.title < rhs.title
        }
        return lhs.dueDate < rhs.dueDate
    }

    static func paidDateForRecurringBillFunding(item: RecurringBillFundingChecklistItem, snapshot: PlannerSnapshot, asOfDate: String) -> String? {
        snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                $0.type == .spending &&
                $0.paymentMethod == (item.cardId == nil ? .pot : .creditCard) &&
                $0.creditCardId == item.cardId &&
                $0.recurringPaymentId == item.paymentId &&
                $0.date == item.dueDate &&
                $0.date <= asOfDate &&
                $0.potId == item.potId
            }
            .map(\.date)
            .sorted()
            .first
    }

    static func paidDateForRecurringCardBillStatementRepayment(
        item: RecurringBillFundingChecklistItem,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> String? {
        guard let cardId = item.cardId,
              let card = snapshot.creditCards.first(where: { $0.id == cardId && !$0.archived }),
              let statementDate = creditCardStatementDate(for: card, snapshot: snapshot, chargeDate: item.dueDate),
              let directDebitDate = creditCardDirectDebitDate(for: card, snapshot: snapshot, chargeDate: item.dueDate)
        else { return nil }

        return snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                $0.creditCardId == cardId &&
                $0.date <= asOfDate &&
                $0.amountPence > 0 &&
                ($0.statementDate == statementDate ||
                    ($0.statementDate == nil && ($0.directDebitDate ?? $0.date) == directDebitDate))
            }
            .map(\.date)
            .sorted()
            .first
    }

    static func paidDateForCardBillFunding(item: CardBillFundingChecklistItem, snapshot: PlannerSnapshot, asOfDate: String) -> String? {
        paidDateForRecurringBillFunding(
            item: RecurringBillFundingChecklistItem(
                id: recurringBillFundingChecklistId(paymentId: item.paymentId, dueDate: item.dueDate),
                paymentId: item.paymentId,
                paymentName: item.paymentName,
                amountPence: item.amountPence,
                dueDate: item.dueDate,
                fundingDueDate: item.fundingDueDate,
                payPeriodId: item.payPeriodId,
                cardId: item.cardId,
                cardName: item.cardName,
                potId: item.potId,
                potName: item.potName,
                isCompleted: item.isCompleted
            ),
            snapshot: snapshot,
            asOfDate: asOfDate
        )
    }

    static func paidDateForOpeningBalanceFunding(item: CreditCardOpeningBalanceFundingChecklistItem, snapshot: PlannerSnapshot, asOfDate: String) -> String? {
        snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                $0.creditCardId == item.cardId &&
                ($0.directDebitDate ?? $0.date) == item.directDebitDate &&
                $0.date <= asOfDate &&
                $0.amountPence > 0
            }
            .map(\.date)
            .sorted()
            .first
    }

    static func paidDateForCardSpendFunding(item: CardSpendFundingChecklistItem, snapshot: PlannerSnapshot, asOfDate: String) -> String? {
        guard let card = snapshot.creditCards.first(where: { $0.id == item.cardId && !$0.archived }),
              let statementDate = creditCardStatementDate(for: card, snapshot: snapshot, chargeDate: item.transactionDate)
        else { return nil }

        return snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                $0.creditCardId == item.cardId &&
                $0.date <= asOfDate &&
                $0.amountPence > 0 &&
                ($0.statementDate == statementDate || ($0.statementDate == nil && ($0.directDebitDate ?? $0.date) == item.dueDate))
            }
            .map(\.date)
            .sorted()
            .first
    }

    static func paidDateForCardPaymentFunding(
        item: CreditCardPaymentFundingChecklistItem,
        snapshot: PlannerSnapshot,
        asOfDate: String
    ) -> String? {
        snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                $0.creditCardId == item.cardId &&
                ($0.directDebitDate ?? $0.date) == item.directDebitDate &&
                $0.date <= asOfDate &&
                $0.amountPence > 0
            }
            .map(\.date)
            .sorted()
            .first
    }

    static func paidDateForDebtFunding(item: DebtFundingChecklistItem, snapshot: PlannerSnapshot, asOfDate: String) -> String? {
        if let scheduleItem = snapshot.debtPaymentScheduleItems.first(where: { $0.id == item.scheduleItemId }),
           scheduleItem.status == .paid,
           let paidDate = scheduleItem.paidDate,
           paidDate <= asOfDate {
            return paidDate
        }

        let paymentDate = snapshot.debtPayments
            .filter {
                $0.deletedAt == nil &&
                $0.debtId == item.debtId &&
                ($0.scheduleItemId == item.scheduleItemId || ($0.scheduleItemId == nil && $0.date == item.dueDate)) &&
                $0.date <= asOfDate &&
                $0.amountPence > 0
            }
            .map(\.date)
            .sorted()
            .first

        if let paymentDate {
            return paymentDate
        }

        guard item.dueDate <= asOfDate,
              snapshot.debts.contains(where: { $0.id == item.debtId && $0.status.isPaidLike })
        else { return nil }

        return item.dueDate
    }

    static func creditCardStatementTransactions(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        cycleStart: String,
        statementDate: String,
        includesCycleStart: Bool,
        asOfDate: String
    ) -> [CreditCardStatementTransaction] {
        let recurringNames = snapshot.recurringPayments.reduce(into: [String: String]()) { result, payment in
            result[payment.id] = payment.name
        }
        var transactions = snapshot.transactions
            .filter {
                $0.deletedAt == nil &&
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id &&
                (includesCycleStart ? $0.date >= cycleStart : $0.date > cycleStart) &&
                $0.date <= statementDate &&
                $0.date <= asOfDate
            }
            .map { transaction in
                let trimmedNote = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                let recurringName = transaction.recurringPaymentId.flatMap { recurringNames[$0] }
                return CreditCardStatementTransaction(
                    id: transaction.id,
                    name: recurringName ?? (trimmedNote.isEmpty ? "Card spending" : trimmedNote),
                    date: transaction.date,
                    amountPence: transaction.amountPence,
                    source: transaction.recurringPaymentId == nil ? .spending : .recurring
                )
            }

        if statementDate == card.statementDate,
           statementDate <= asOfDate {
            let openingStatementPence = statementedOpeningBalancePence(card: card)
            if openingStatementPence > 0 {
                transactions.append(
                    CreditCardStatementTransaction(
                        id: "opening-statement-\(card.id)-\(statementDate)",
                        name: "Opening statement balance",
                        date: statementDate,
                        amountPence: openingStatementPence,
                        source: .openingStatement
                    )
                )
            }
        }

        if statementDate == card.statementDate,
           cardCreatedDateCanFeedFirstStatement(card: card, statementDate: statementDate),
           statementDate <= asOfDate {
            let unstatementedOpeningPence = unstatementedOpeningBalancePence(card: card)
            if unstatementedOpeningPence > 0 {
                transactions.append(
                    CreditCardStatementTransaction(
                        id: "opening-unstatemented-\(card.id)-\(statementDate)",
                        name: "\(card.name) opening balance",
                        date: statementDate,
                        amountPence: unstatementedOpeningPence,
                        source: .spending
                    )
                )
            }
        }

        return transactions.sorted {
            if $0.date == $1.date {
                return $0.name < $1.name
            }
            return $0.date < $1.date
        }
    }

    static func creditCardStatementDate(for card: CreditCard, chargeDate: String) -> String? {
        guard var statementDate = card.statementDate,
              FinanceEngine.isIsoDate(statementDate)
        else { return nil }

        for _ in 0..<240 {
            if statementDate >= chargeDate {
                return statementDate
            }

            statementDate = addIsoMonthsClamped(date: statementDate, months: 1)
        }

        return nil
    }

    static func creditCardStatementDate(for card: CreditCard, snapshot: PlannerSnapshot, chargeDate: String) -> String? {
        creditCardStatementCycles(
            card: card,
            snapshot: snapshot,
            through: addIsoMonthsClamped(date: chargeDate, months: 1)
        )
            .first { cycle in
                cycle.statementDate >= chargeDate ||
                (cycle.isStatementHeld && cycle.scheduledStatementDate <= chargeDate)
            }?
            .statementDate
    }

    static func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }

    static func currentOrLatestPayPeriod(_ payPeriods: [PayPeriod], today: String) -> PayPeriod? {
        if let currentPeriod = findPayPeriod(payPeriods: payPeriods, date: today) {
            return currentPeriod
        }

        if let activePeriod = payPeriods.first(where: { $0.status == .active }) {
            return activePeriod
        }

        let previousPeriods = payPeriods
            .filter { $0.startDate <= today }
            .sorted { $0.startDate > $1.startDate }

        if let previousPeriod = previousPeriods.first {
            return previousPeriod
        }

        return payPeriods.sorted { $0.startDate > $1.startDate }.first
    }

    static func earliestRecurringDueDate(payments: [RecurringPayment], today: String) -> String? {
        payments.reduce(nil) { earliest, payment in
            let dueDate = payment.dueDate ?? payment.dueDay.map { nextDueDayIso(dueDay: $0, today: today) }
            return minIsoDate(earliest, dueDate)
        }
    }

    static func creditCardDueIso(card: CreditCard, today: String) -> String? {
        card.dueDate ?? card.dueDay.map { nextDueDayIso(dueDay: $0, today: today) }
    }

    static func creditCardOpeningBalanceDirectDebitDateCore(card: CreditCard, today: String) -> String? {
        if let dueDate = card.dueDate, FinanceEngine.isIsoDate(dueDate) {
            return dueDate
        }

        return card.dueDay.map { nextDueDayIso(dueDay: $0, today: today) }
    }

    static func creditCardDirectDebitDate(for card: CreditCard, chargeDate: String) -> String? {
        guard var statementDate = card.statementDate,
              FinanceEngine.isIsoDate(statementDate),
              let dueDay = card.dueDay
        else { return nil }

        for _ in 0..<240 {
            if statementDate >= chargeDate {
                return creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
            }
            statementDate = addIsoMonthsClamped(date: statementDate, months: 1)
        }

        return nil
    }

    static func creditCardDirectDebitDate(for card: CreditCard, snapshot: PlannerSnapshot, chargeDate: String) -> String? {
        creditCardStatementCycles(
            card: card,
            snapshot: snapshot,
            through: addIsoMonthsClamped(date: chargeDate, months: 1)
        )
            .first { cycle in
                cycle.statementDate >= chargeDate ||
                (cycle.isStatementHeld && cycle.scheduledStatementDate <= chargeDate)
            }?
            .directDebitDate
    }

    static func nextDueDayIso(dueDay: Int, today: String) -> String {
        let calendar = utcCalendar
        let todayDate = FinanceEngine.parseDate(today)
        let todayComponents = calendar.dateComponents([.year, .month], from: todayDate)
        var year = todayComponents.year ?? 1970
        var month = todayComponents.month ?? 1
        var candidate = monthlyDateIso(year: year, month: month, dueDay: dueDay)

        if candidate < today {
            month += 1
            if month > 12 {
                month = 1
                year += 1
            }
            candidate = monthlyDateIso(year: year, month: month, dueDay: dueDay)
        }

        return candidate
    }

    static func minIsoDate(_ lhs: String?, _ rhs: String?) -> String? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return min(lhs, rhs)
    }

    static func creditCardAllocationItems(snapshot: PlannerSnapshot, rangeStart: String, rangeEnd: String) -> [CreditCardAllocationItem] {
        let recurring = resolvedRecurringOccurrences(snapshot: snapshot, payments: snapshot.recurringPayments, startDate: rangeStart, endDate: rangeEnd)
            .map {
                CreditCardAllocationItem(
                    creditCardId: $0.payment.creditCardId,
                    amountPence: $0.amountPence,
                    date: $0.dueDate,
                    source: .recurring
                )
            }

        let custom = snapshot.customPayments
            .filter { $0.status == .unpaid && $0.dueDate >= rangeStart && $0.dueDate <= rangeEnd }
            .map {
                CreditCardAllocationItem(
                    creditCardId: $0.creditCardId,
                    amountPence: $0.amountPence,
                    date: $0.dueDate,
                    source: .custom
                )
            }

        let transactions = snapshot.transactions
            .filter {
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.date >= rangeStart &&
                $0.date <= rangeEnd
            }
            .map {
                CreditCardAllocationItem(
                    creditCardId: $0.creditCardId,
                    amountPence: $0.amountPence,
                    date: $0.date,
                    source: .spending
                )
            }

        let repayments = snapshot.creditCardRepayments
            .filter { $0.date >= rangeStart && $0.date <= rangeEnd }
            .map {
                CreditCardAllocationItem(
                    creditCardId: $0.creditCardId,
                    amountPence: -$0.amountPence,
                    date: $0.date,
                    source: .repayment
                )
            }

        return (recurring + custom + transactions + repayments).sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.amountPence < rhs.amountPence
            }
            return lhs.date < rhs.date
        }
    }

    static func actualCreditCardBalanceItems(
        card: CreditCard,
        transactions: [Transaction],
        repayments: [CreditCardRepayment],
        asOfDate: String
    ) -> [CreditCardAllocationItem] {
        let transactions = transactions
            .filter {
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id &&
                $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.date <= asOfDate
            }
            .map {
                CreditCardAllocationItem(
                    creditCardId: card.id,
                    amountPence: $0.amountPence,
                    date: $0.date,
                    source: .spending
                )
            }

        let repayments = repayments
            .filter { $0.deletedAt == nil && !$0.isRefunded && $0.creditCardId == card.id && $0.date <= asOfDate }
            .map {
                CreditCardAllocationItem(
                    creditCardId: card.id,
                    amountPence: -$0.amountPence,
                    date: $0.date,
                    source: .repayment
                )
            }

        return (transactions + repayments).sorted { $0.date < $1.date }
    }

    static func forecastCreditCardItems(cardItems: [CreditCardAllocationItem], asOfDate: String) -> [CreditCardAllocationItem] {
        cardItems.filter { item in
            if item.source == .recurring || item.source == .custom {
                return item.date > asOfDate
            }

            return item.date > asOfDate
        }
    }

    static func creditCardStatementBreakdown(
        card: CreditCard,
        snapshot: PlannerSnapshot,
        statementDate: String,
        previousStatementDate: String?,
        nextStatementDate: String,
        directDebitDate: String,
        asOfDate: String
    ) -> [CreditCardStatementLine] {
        let actualLines: [CreditCardStatementLine]
        let cycleStart: String
        let includesCycleStart: Bool

        if let previousStatementDate {
            cycleStart = previousStatementDate
            includesCycleStart = false
            actualLines = creditCardSpendingStatementLines(
                card: card,
                transactions: snapshot.transactions,
                cycleStart: cycleStart,
                statementDate: statementDate,
                includesCycleStart: includesCycleStart,
                asOfDate: asOfDate
            )
        } else {
            cycleStart = card.createdAt.prefixDate ?? statementDate
            includesCycleStart = true
            var firstCycleLines = creditCardSpendingStatementLines(
                card: card,
                transactions: snapshot.transactions,
                cycleStart: cycleStart,
                statementDate: statementDate,
                includesCycleStart: includesCycleStart,
                asOfDate: asOfDate
            )
            let openingStatementPence = statementedOpeningBalancePence(card: card)
            let unstatementedOpeningPence = cardCreatedDateCanFeedFirstStatement(card: card, statementDate: statementDate)
                ? unstatementedOpeningBalancePence(card: card)
                : 0

            if openingStatementPence > 0 {
                firstCycleLines.insert(
                    CreditCardStatementLine(
                        amountPence: openingStatementPence,
                        date: statementDate,
                        source: .openingStatement
                    ),
                    at: 0
                )
            }
            if unstatementedOpeningPence > 0 {
                firstCycleLines.append(
                    CreditCardStatementLine(
                        amountPence: unstatementedOpeningPence,
                        date: statementDate,
                        source: .spending
                    )
                )
            }

            actualLines = firstCycleLines
        }

        let actualRecurringKeys = Set(snapshot.transactions
            .filter {
                $0.type == .spending &&
                !$0.isRefunded &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id &&
                $0.recurringPaymentId != nil &&
                (includesCycleStart ? $0.date >= cycleStart : $0.date > cycleStart) &&
                $0.date <= statementDate
            }
            .compactMap { transaction in
                transaction.recurringPaymentId.map { "\($0):\(transaction.date)" }
            })

        let forecastCycleStart = includesCycleStart ? cycleStart : FinanceEngine.addIsoDays(date: cycleStart, days: 1)
        let currentPayPeriod = currentOrLatestPayPeriod(snapshot.payPeriods, today: asOfDate)
        let recurringForecastStart = max(forecastCycleStart, currentPayPeriod?.startDate ?? forecastCycleStart)
        let recurringForecastEnd = min(statementDate, currentPayPeriod?.endDate ?? statementDate)
        let recurringLines: [CreditCardStatementLine]
        if recurringForecastStart <= recurringForecastEnd {
            recurringLines = resolvedRecurringOccurrences(
                snapshot: snapshot,
                payments: snapshot.recurringPayments,
                startDate: recurringForecastStart,
                endDate: recurringForecastEnd
            )
            .filter {
                $0.payment.creditCardId == card.id &&
                !actualRecurringKeys.contains("\($0.payment.id):\($0.dueDate)")
            }
            .map { CreditCardStatementLine(amountPence: $0.amountPence, date: $0.dueDate, source: .recurring) }
        } else {
            recurringLines = []
        }

        let customLines = snapshot.customPayments
            .filter {
                $0.status != .archived &&
                $0.creditCardId == card.id &&
                (includesCycleStart ? $0.dueDate >= cycleStart : $0.dueDate > cycleStart) &&
                $0.dueDate <= statementDate
            }
            .map { CreditCardStatementLine(amountPence: $0.amountPence, date: $0.dueDate, source: .custom) }

        let repaymentLines = snapshot.creditCardRepayments
            .filter {
                $0.deletedAt == nil &&
                $0.creditCardId == card.id &&
                $0.date <= directDebitDate &&
                (
                    $0.statementDate == statementDate ||
                    ($0.statementDate == nil && $0.date > statementDate)
                )
            }
            .map { CreditCardStatementLine(amountPence: -$0.amountPence, date: $0.date, source: .repayment) }

        return capStatementRepaymentsToStatementDue(actualLines + recurringLines + customLines + repaymentLines)
    }

    static func capStatementRepaymentsToStatementDue(_ lines: [CreditCardStatementLine]) -> [CreditCardStatementLine] {
        let sortedLines = lines.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.amountPence > rhs.amountPence
            }
            return lhs.date < rhs.date
        }
        var remainingStatementDuePence = sortedLines
            .filter { $0.source != .repayment && $0.amountPence > 0 }
            .reduce(0) { $0 + $1.amountPence }

        return sortedLines.map { line in
            guard line.source == .repayment, line.amountPence < 0 else { return line }

            let paidPence = abs(line.amountPence)
            let appliedPence = min(paidPence, remainingStatementDuePence)
            remainingStatementDuePence -= appliedPence

            var copy = line
            copy.amountPence = -appliedPence
            return copy
        }
    }

    private static func creditCardSpendingStatementLines(
        card: CreditCard,
        transactions: [Transaction],
        cycleStart: String,
        statementDate: String,
        includesCycleStart: Bool,
        asOfDate: String
    ) -> [CreditCardStatementLine] {
        transactions
            .filter {
                $0.type == .spending &&
                !$0.isRefunded &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == card.id &&
                (includesCycleStart ? $0.date >= cycleStart : $0.date > cycleStart) &&
                $0.date <= statementDate &&
                $0.date <= asOfDate
            }
            .map { CreditCardStatementLine(amountPence: $0.amountPence, date: $0.date, source: .spending) }
    }

    static func statementedOpeningBalancePence(card: CreditCard) -> Int {
        max(0, card.openingStatementBalancePence ?? card.openingBalancePence ?? 0)
    }

    static func unstatementedOpeningBalancePence(card: CreditCard) -> Int {
        max(0, (card.openingBalancePence ?? 0) - statementedOpeningBalancePence(card: card))
    }

    static func cardCreatedDateCanFeedFirstStatement(card: CreditCard, statementDate: String) -> Bool {
        (card.createdAt.prefixDate ?? statementDate) <= statementDate
    }

    static func creditCardDirectDebitDateCore(statementDate: String, dueDay: Int) -> String {
        let calendar = utcCalendar
        let statement = FinanceEngine.parseDate(statementDate)
        let components = calendar.dateComponents([.year, .month], from: statement)
        var candidate = monthlyDateIso(year: components.year ?? 1970, month: components.month ?? 1, dueDay: dueDay)

        if candidate < statementDate {
            let next = calendar.date(byAdding: .month, value: 1, to: statement) ?? statement
            let nextComponents = calendar.dateComponents([.year, .month], from: next)
            candidate = monthlyDateIso(year: nextComponents.year ?? 1970, month: nextComponents.month ?? 1, dueDay: dueDay)
        }

        return candidate
    }

    static func addIsoMonthsClampedCore(date: String, months: Int) -> String {
        let calendar = utcCalendar
        let parsed = FinanceEngine.parseDate(date)
        let target = calendar.date(byAdding: .month, value: months, to: parsed) ?? parsed
        let targetComponents = calendar.dateComponents([.year, .month], from: target)
        let originalDay = calendar.component(.day, from: parsed)

        return monthlyDateIso(year: targetComponents.year ?? 1970, month: targetComponents.month ?? 1, dueDay: originalDay)
    }

    static func monthlyDateIso(year: Int, month: Int, dueDay: Int) -> String {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.year = year
        components.month = month
        components.day = 1

        let firstOfMonth = utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let lastDay = utcCalendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 28
        components.day = min(max(1, dueDay), lastDay)

        return FinanceEngine.toIsoDate(utcCalendar.date(from: components) ?? firstOfMonth)
    }

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()
}

private extension String {
    var prefixDate: String? {
        let prefix = String(prefix(10))
        return FinanceEngine.isIsoDate(prefix) ? prefix : nil
    }
}
