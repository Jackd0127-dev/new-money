import Foundation
import XCTest
@testable import NewMoneyIPhone

final class FinanceCorrectnessTests: XCTestCase {
    func testMoneyParserRejectsMalformedAndOverflowingAmounts() {
        for value in ["--1", "1.-2", "1.+2", "££1", "£-£1", "1,20", "1.234", "nan", "inf", ".", "92233720368547759", "92233720368547758.08"] {
            XCTAssertNil(MoneyParser.pence(from: value), value)
            XCTAssertEqual(MoneyParser.parsePoundsToPence(value), 0, value)
        }
        let cases: [(String, Int)] = [("£1,200.99", 120099), ("-.5", -50), ("-£1.25", -125), ("£-1.25", -125), ("0", 0), ("1.", 100), ("92233720368547758.07", Int.max)]
        for (value, expected) in cases { XCTAssertEqual(MoneyParser.pence(from: value), expected, value) }
        XCTAssertNil(MoneyParser.pence(from: ""))
    }

    func testPaycheckConversionRejectsNonfiniteAndUnrepresentableValues() {
        for hours in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude] {
            XCTAssertNil(FinanceEngine.validatedPaycheckAmount(hoursWorked: hours, hourlyRatePence: 1250, actualAmountPence: nil))
            XCTAssertEqual(FinanceEngine.calculatePaycheckAmount(hoursWorked: hours, hourlyRatePence: 1250, actualAmountPence: nil), 0)
        }
        XCTAssertEqual(FinanceEngine.validatedPaycheckAmount(hoursWorked: 7.5, hourlyRatePence: 1234, actualAmountPence: nil), 9255)
        XCTAssertEqual(FinanceEngine.validatedPaycheckAmount(hoursWorked: .nan, hourlyRatePence: 0, actualAmountPence: 4000), 4000)
    }

    func testDatesRequireRealGregorianDaysAndInvalidSchedulesStayEmpty() {
        for value in ["2026-02-30", "2026-02-29", "2026-99-99", "2026-1-01", "2026-00-01", "2026-01-00"] {
            XCTAssertFalse(FinanceEngine.isIsoDate(value), value)
            XCTAssertNil(FinanceEngine.validatedDate(value), value)
            XCTAssertEqual(FinanceEngine.addIsoDays(date: value, days: 1), value)
            XCTAssertTrue(PlannerDerivedData.recurringOccurrences(payments: [quarterlyBill()], startDate: value, endDate: "2026-12-31").isEmpty)
            XCTAssertTrue(DebtPlannerEngine.generateSchedule(for: debt(), payPeriods: [], today: value).isEmpty)
        }
        XCTAssertTrue(FinanceEngine.isIsoDate("2028-02-29"))
        XCTAssertEqual(FinanceEngine.addIsoDays(date: "2028-02-29", days: 1), "2028-03-01")
        var invalidBill = quarterlyBill()
        invalidBill.dueDate = "2026-02-30"
        XCTAssertTrue(PlannerDerivedData.recurringOccurrences(payments: [invalidBill], startDate: "2026-01-01", endDate: "2026-12-31").isEmpty)
    }

    func testPartialDebtRefundComponentsConserveEveryPenny() {
        for (principal, interest, fee) in [(99, 1, 0), (67, 22, 11), (0, 50, 50)] {
            var payment = debtPayment(amount: 100, principal: principal, interest: interest, fee: fee)
            for refund in 0...100 {
                payment.refundedAt = refund > 0 ? timestamp : nil
                payment.refundedAmountPence = refund > 0 ? refund : nil
                let components = payment.effectiveComponents
                XCTAssertEqual(components.totalPence, 100 - refund)
                XCTAssertGreaterThanOrEqual(components.principalPence, 0)
                XCTAssertLessThanOrEqual(components.principalPence, principal)
                XCTAssertLessThanOrEqual(components.interestPence, interest)
                XCTAssertLessThanOrEqual(components.feePence, fee)
            }
        }
        var payment = debtPayment(amount: 100, principal: 99, interest: 1)
        payment.refundedAt = timestamp
        payment.refundedAmountPence = 50
        XCTAssertEqual(payment.effectiveComponents, DebtPaymentComponents(principalPence: 50, interestPence: 0, feePence: 0))
    }

    func testDebtRefundScalingUsesExactArithmeticAtIntegerLimits() {
        var payment = debtPayment(amount: Int.max, principal: Int.max - 2, interest: 1, fee: 1)
        payment.refundedAt = timestamp
        payment.refundedAmountPence = 1
        XCTAssertEqual(payment.effectiveComponents.totalPence, Int.max - 1)
        XCTAssertEqual(payment.effectiveComponents.principalPence, Int.max - 3)
        payment.refundedAmountPence = Int.max
        XCTAssertEqual(payment.effectiveComponents.totalPence, 0)
    }

    func testDebtRefundComponentsConservePenniesAndRemainMonotonicForEverySmallSplit() {
        for principal in 0...8 {
            for interest in 0...8 {
                for fee in 0...8 {
                    let original = DebtPaymentComponents(principalPence: principal, interestPence: interest, feePence: fee)
                    var previous = DebtPaymentComponents(principalPence: 0, interestPence: 0, feePence: 0)
                    for net in 0...original.totalPence {
                        let retained = original.scaled(to: net)
                        let detail = "principal=\(principal), interest=\(interest), fee=\(fee), net=\(net)"
                        XCTAssertEqual(retained.totalPence, net, detail)
                        XCTAssertGreaterThanOrEqual(retained.principalPence, previous.principalPence, detail)
                        XCTAssertGreaterThanOrEqual(retained.interestPence, previous.interestPence, detail)
                        XCTAssertGreaterThanOrEqual(retained.feePence, previous.feePence, detail)
                        XCTAssertLessThanOrEqual(retained.principalPence, principal, detail)
                        XCTAssertLessThanOrEqual(retained.interestPence, interest, detail)
                        XCTAssertLessThanOrEqual(retained.feePence, fee, detail)
                        previous = retained
                    }
                    XCTAssertEqual(previous, original)
                }
            }
        }
    }

    func testDebtPaymentPotContributionsRoundTripAndLegacyMissingFieldDecodes() throws {
        var payment = debtPayment(amount: 1000, principal: 900, interest: 100)
        payment.potContributions = [DebtPaymentPotContribution(potId: "first", amountPence: 600), DebtPaymentPotContribution(potId: "second", amountPence: 400)]
        let data = try JSONEncoder().encode(payment)
        XCTAssertEqual(try JSONDecoder().decode(DebtPayment.self, from: data), payment)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "potContributions")
        let decoded = try JSONDecoder().decode(DebtPayment.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(decoded.potContributions)
        XCTAssertEqual(decoded.effectivePrincipalPaidPence, 900)
    }

    func testSplitDebtPaymentsChargeScheduledInterestAndFeesOnlyOnce() throws {
        let original = debt()
        let schedule = scheduleItem()
        let once = DebtPlannerEngine.applyPayment(debt: original, scheduleItem: schedule, amountPence: 1150, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        var currentDebt = original
        var currentSchedule = schedule
        var payments: [DebtPayment] = []
        for amount in [25, 75, 100, 950] {
            let application = DebtPlannerEngine.applyPayment(debt: currentDebt, scheduleItem: currentSchedule, priorPayments: payments, amountPence: amount, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
            currentDebt = application.debt
            currentSchedule = try XCTUnwrap(application.scheduleItem)
            var payment = application.payment
            payment.id = "payment-\(payments.count)"
            payments.append(payment)
        }
        XCTAssertEqual(currentDebt.currentBalancePence, once.debt.currentBalancePence)
        XCTAssertEqual(currentSchedule.paidAmountPence, 1150)
        XCTAssertEqual(payments.reduce(0) { $0 + $1.interestPaidPence }, 100)
        XCTAssertEqual(payments.reduce(0) { $0 + $1.feePaidPence }, 50)
        XCTAssertEqual(payments.reduce(0) { $0 + $1.principalPaidPence }, 1000)
    }

    func testLegacyPartPaidScheduleUsesAggregateAllocationWithoutRechargingInterest() throws {
        let first = DebtPlannerEngine.applyPayment(debt: debt(), scheduleItem: scheduleItem(), amountPence: 150, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        let second = DebtPlannerEngine.applyPayment(debt: first.debt, scheduleItem: try XCTUnwrap(first.scheduleItem), amountPence: 1000, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        XCTAssertEqual(second.payment.interestPaidPence, 0)
        XCTAssertEqual(second.payment.feePaidPence, 0)
        XCTAssertEqual(second.payment.principalPaidPence, 1000)
    }

    func testFinalPayoffSettlesStaleScheduleAndRetainsReversiblePrincipalBudget() throws {
        var stale = scheduleItem()
        stale.plannedAmountPence = 10000
        stale.principalAmountPence = 10000
        stale.interestAmountPence = 0
        stale.feeAmountPence = 0
        stale.fundedAmountPence = 10000
        let application = DebtPlannerEngine.applyPayment(debt: debt(), scheduleItem: stale, amountPence: 10000, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        let settled = try XCTUnwrap(application.scheduleItem)
        XCTAssertEqual(application.debt.currentBalancePence, 0)
        XCTAssertEqual(application.payment.amountPence, 5000)
        XCTAssertEqual(settled.status, .paid)
        XCTAssertEqual(settled.plannedAmountPence, 5000)
        XCTAssertEqual(settled.paidAmountPence, 5000)
        XCTAssertEqual(settled.principalAmountPence, 5000)
        XCTAssertEqual(settled.fundedAmountPence, 0)

        var refunded = application.payment
        refunded.refundedAt = timestamp
        refunded.refundedAmountPence = 5000
        XCTAssertEqual(settled.plannedAmountPence - refunded.netAmountPence, 5000)
        XCTAssertEqual(settled.principalAmountPence - refunded.effectivePrincipalPaidPence, 5000)

        stale.paidAmountPence = 3000
        let legacy = DebtPlannerEngine.applyPayment(debt: debt(), scheduleItem: stale, amountPence: 10000, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        XCTAssertEqual(legacy.scheduleItem?.status, .paid)
        XCTAssertEqual(legacy.scheduleItem?.principalAmountPence, 8000)
        XCTAssertEqual(legacy.scheduleItem?.paidAmountPence, 8000)
        XCTAssertEqual(legacy.payment.principalPaidPence, 5000)
    }

    func testFinalPayoffKeepsActualLinkedPriorComponentsIncludingRefunds() throws {
        for (refund, expectedBudget, expectedPrincipal) in [(0, 8200, 8000), (1600, 6700, 6500), (3200, 5200, 5000)] {
            var prior = debtPayment(amount: 3200, principal: 3000, interest: 150, fee: 50)
            prior.refundedAt = refund > 0 ? timestamp : nil
            prior.refundedAmountPence = refund > 0 ? refund : nil
            var stale = scheduleItem()
            stale.plannedAmountPence = 10000
            stale.principalAmountPence = 9800
            stale.interestAmountPence = 150
            stale.feeAmountPence = 50
            stale.paidAmountPence = 3200
            stale.fundedAmountPence = 10000
            let application = DebtPlannerEngine.applyPayment(debt: debt(), scheduleItem: stale, priorPayments: [prior], amountPence: 10000, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
            let settled = try XCTUnwrap(application.scheduleItem)
            XCTAssertEqual(settled.status, .paid)
            XCTAssertEqual(settled.plannedAmountPence, expectedBudget)
            XCTAssertEqual(settled.paidAmountPence, prior.netAmountPence + application.payment.amountPence)
            XCTAssertEqual(settled.principalAmountPence, expectedPrincipal)
            XCTAssertEqual(settled.interestAmountPence, 150)
            XCTAssertEqual(settled.feeAmountPence, 50)

            var reversed = application.payment
            reversed.refundedAt = timestamp
            reversed.refundedAmountPence = reversed.amountPence
            XCTAssertEqual(settled.principalAmountPence - prior.effectivePrincipalPaidPence - reversed.effectivePrincipalPaidPence, 5000)
            XCTAssertEqual(settled.plannedAmountPence - prior.netAmountPence - reversed.netAmountPence, application.payment.amountPence)
        }
    }

    func testRefundedAndDeletedPriorPaymentsDoNotConsumeOutstandingComponents() {
        var refunded = debtPayment(amount: 150, principal: 0, interest: 100, fee: 50)
        refunded.refundedAt = timestamp
        refunded.refundedAmountPence = 150
        var deleted = refunded
        deleted.id = "deleted"
        deleted.refundedAt = nil
        deleted.refundedAmountPence = nil
        deleted.deletedAt = timestamp
        let application = DebtPlannerEngine.applyPayment(debt: debt(), scheduleItem: scheduleItem(), priorPayments: [refunded, deleted], amountPence: 150, date: "2026-01-31", sourcePotId: nil, paymentType: .scheduled)
        XCTAssertEqual(application.payment.interestPaidPence, 100)
        XCTAssertEqual(application.payment.feePaidPence, 50)
        XCTAssertEqual(application.payment.principalPaidPence, 0)
    }

    func testQuarterlyDatesRecoverOriginalAnchorAfterShortMonths() {
        let dates = PlannerDerivedData.recurringOccurrences(payments: [quarterlyBill()], startDate: "2026-01-01", endDate: "2026-12-31").map(\.dueDate)
        XCTAssertEqual(dates, ["2026-01-31", "2026-04-30", "2026-07-31", "2026-10-31"])
    }

    func testQuarterlySavedOccurrenceKeepsIdentityBeforeFutureAnchorRecovery() {
        let bill = quarterlyBill()
        var state = snapshot()
        state.recurringPayments = [bill]
        state.recurringPaymentOccurrenceOverrides = [RecurringPaymentOccurrenceOverride(id: "saved", paymentId: bill.id, scheduledDueDate: "2026-07-30", state: .confirmed, actualDueDate: "2026-07-29", reversedGeneratedTransactionIds: [], createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(snapshot: state, payments: [bill], startDate: "2026-01-01", endDate: "2026-12-31")
        XCTAssertEqual(occurrences.map(\.scheduledDueDate), ["2026-01-31", "2026-04-30", "2026-07-30", "2026-10-31"])
        XCTAssertEqual(occurrences[2].dueDate, "2026-07-29")
        state.recurringPaymentOccurrenceOverrides = []
        state.transactions = [Transaction(id: "card-recurring-bill-2026-07-30", potId: nil, payPeriodId: nil, amountPence: 1000, type: .spending, paymentMethod: .creditCard, creditCardId: nil, recurringPaymentId: bill.id, date: "2026-07-29", note: "", createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        let retained = PlannerDerivedData.resolvedRecurringOccurrences(snapshot: state, payments: [bill], startDate: "2026-01-01", endDate: "2026-12-31")
        XCTAssertEqual(retained.map(\.scheduledDueDate), ["2026-01-31", "2026-04-30", "2026-07-30", "2026-10-31"])
    }

    func testCardStatementDatesRecoverMonthEndAnchorIncludingLeapYears() {
        for (anchor, expected) in [("2026-01-31", ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30"]), ("2028-01-31", ["2028-01-31", "2028-02-29", "2028-03-31", "2028-04-30"])] {
            var state = snapshot()
            state.creditCards[0].statementDate = anchor
            let start = String(anchor.prefix(4)) + "-01-01"
            let dates = PlannerDerivedData.creditCardCycleReminders(snapshot: state, asOfDate: start, months: 4).map(\.scheduledStatementDate)
            XCTAssertEqual(dates, expected)
        }
    }

    func testSavedCardCycleAndRepaymentStayAttachedWhenFutureAnchorRecovers() {
        var state = snapshot()
        state.creditCardCycleOverrides = [CreditCardCycleOverride(id: "saved-cycle", creditCardId: "card", scheduledStatementDate: "2026-03-28", statementState: .confirmed, actualStatementDate: "2026-03-29", directDebitState: .confirmed, actualDirectDebitDate: "2026-04-11", amountPenceOverride: 1000, reversedAutomaticRepaymentIds: [], createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        state.creditCardRepayments = [CreditCardRepayment(id: "repayment", creditCardId: "card", amountPence: 1000, date: "2026-04-11", note: "", statementDate: "2026-03-28", directDebitDate: "2026-04-11", createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        let cycles = PlannerDerivedData.creditCardCycleReminders(snapshot: state, asOfDate: "2026-01-01", months: 4)
        XCTAssertEqual(cycles.map(\.scheduledStatementDate), ["2026-01-31", "2026-02-28", "2026-03-28", "2026-04-30"])
        XCTAssertEqual(cycles[2].statementDate, "2026-03-29")
        XCTAssertEqual(cycles[2].directDebitDate, "2026-04-11")
        let saved = PlannerDerivedData.creditCardStatementSummaries(snapshot: state, asOfDate: "2026-04-15").first { $0.scheduledStatementDate == "2026-03-28" }
        XCTAssertEqual(saved?.paidAmountPence, 1000)
        XCTAssertEqual(saved?.unpaidAmountPence, 0)
    }

    func testStatementInclusionPredicateReceivesActualMovedCycleDates() {
        var state = snapshot()
        state.creditCardCycleOverrides = [CreditCardCycleOverride(id: "moved", creditCardId: "card", scheduledStatementDate: "2026-01-31", statementState: .confirmed, actualStatementDate: "2026-02-01", directDebitState: .confirmed, actualDirectDebitDate: "2026-02-11", amountPenceOverride: 1000, reversedAutomaticRepaymentIds: [], createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        var visited: [String] = []
        let payments = PlannerDerivedData.creditCardStatementPayments(card: state.creditCards[0], snapshot: state, startDate: "2026-01-01", endDate: "2026-02-15", asOfDate: "2026-02-15", includeCycle: { statement, directDebit in
            visited.append("\(statement)/\(directDebit)")
            return false
        })
        XCTAssertEqual(visited, ["2026-02-01/2026-02-11"])
        XCTAssertTrue(payments.isEmpty)
    }

    func testRecordedCardChargeRetainsItsLegacyStatementBoundary() {
        var state = snapshot()
        state.transactions = [Transaction(id: "saved-charge", potId: nil, payPeriodId: nil, amountPence: 1000, type: .spending, paymentMethod: .creditCard, creditCardId: "card", recurringPaymentId: nil, date: "2026-03-29", note: "", createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
        let cycles = PlannerDerivedData.creditCardCycleReminders(snapshot: state, asOfDate: "2026-01-01", months: 6)
        XCTAssertEqual(cycles.map(\.scheduledStatementDate), ["2026-01-31", "2026-02-28", "2026-03-28", "2026-04-28", "2026-05-31", "2026-06-30"])
        let containing = PlannerDerivedData.creditCardStatementPayments(card: state.creditCards[0], snapshot: state, startDate: "2026-04-01", endDate: "2026-05-15", asOfDate: "2026-05-01").first { $0.actualDuePence > 0 }
        XCTAssertEqual(containing?.scheduledStatementDate, "2026-04-28")
        XCTAssertEqual(containing?.actualDuePence, 1000)
    }

    func testLegacyRepaymentWithOnlyDebitDatePreservesItsCycle() {
        for date in ["2026-04-10", "2026-04-11"] {
            var state = snapshot()
            state.creditCardRepayments = [CreditCardRepayment(id: "legacy-repayment", creditCardId: "card", amountPence: 1000, date: date, note: "", directDebitDate: date, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)]
            let cycles = PlannerDerivedData.creditCardCycleReminders(snapshot: state, asOfDate: "2026-01-01", months: 4)
            XCTAssertEqual(cycles.map(\.scheduledStatementDate), ["2026-01-31", "2026-02-28", "2026-03-28", "2026-04-30"])
        }
    }

    private let timestamp = "2026-01-01T00:00:00.000Z"

    private func debt() -> Debt {
        Debt(id: "debt", name: "Debt", lender: "", originalAmountPence: 10000, currentBalancePence: 5000, minimumPaymentPence: 1150, dueDate: "2026-01-31", interestRateApr: nil, note: "", status: .active, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)
    }

    private func scheduleItem() -> DebtPaymentScheduleItem {
        DebtPaymentScheduleItem(id: "schedule", debtId: "debt", dueDate: "2026-01-31", plannedAmountPence: 1150, principalAmountPence: 1000, interestAmountPence: 100, feeAmountPence: 50, fundedAmountPence: 1150, paidAmountPence: 0, paidDate: nil, status: .funded, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)
    }

    private func debtPayment(amount: Int, principal: Int, interest: Int, fee: Int = 0) -> DebtPayment {
        DebtPayment(id: "payment", debtId: "debt", amountPence: amount, date: "2026-01-31", note: "", createdAt: timestamp, updatedAt: timestamp, deletedAt: nil, scheduleItemId: "schedule", principalPaidPence: principal, interestPaidPence: interest, feePaidPence: fee)
    }

    private func quarterlyBill() -> RecurringPayment {
        RecurringPayment(id: "bill", name: "Quarterly bill", amountPence: 1000, dueDay: nil, dueDate: "2026-01-31", frequency: .quarterly, potId: nil, creditCardId: nil, priority: .essential, active: true, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)
    }

    private func snapshot() -> PlannerSnapshot {
        let settings = Settings(id: "settings", currency: .gbp, payFrequency: .monthly, defaultPayPeriodDays: 31, hourlyRatePence: 1250, defaultHoursWorked: 40, appDateMode: .manual, manualTodayIso: "2026-01-01", aiInstructions: "", aiProvider: .gemini, assistantName: nil, assistantResponseStyle: nil, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)
        let card = CreditCard(id: "card", name: "Card", provider: "", limitPence: 100000, openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-01-31", designId: nil, dueDay: 10, dueDate: nil, color: "#000000", archived: false, createdAt: timestamp, updatedAt: timestamp, deletedAt: nil)
        return PlannerSnapshot(settings: settings, pots: [], recurringPayments: [], payPeriods: [], paychecks: [], potAllocations: [], transactions: [], debts: [], debtPayments: [], debtReserves: [], creditCards: [card], customPayments: [], creditCardRepayments: [], creditCardPots: [], dailyBriefs: [])
    }
}
