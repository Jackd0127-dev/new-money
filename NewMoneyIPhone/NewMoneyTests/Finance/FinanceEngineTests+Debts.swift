import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    @MainActor
    func testAddingDebtWithLinkedPotLinksPotAndRaisesPotTargetToDebtBalance() async throws {
        let settings = makeManualSettings(today: "2026-06-01")
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 0, targetPence: nil)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot])))

        await store.load()
        store.addDebt(
            name: "Personal loan",
            lender: "Loan Provider",
            currentBalancePence: 50000,
            minimumPaymentPence: 0,
            dueDate: "2026-06-10",
            apr: nil,
            note: "",
            linkedPotId: pot.id
        )

        let debt = try XCTUnwrap(store.snapshot.debts.first)
        let linkedPot = try XCTUnwrap(store.snapshot.pots.first { $0.id == pot.id })
        let progress = PlannerDerivedData.potProgress(pot: linkedPot, snapshot: store.snapshot, today: "2026-06-01")

        XCTAssertEqual(linkedPot.linkedDebtId, debt.id)
        XCTAssertEqual(progress.targetPence, 50000)
        XCTAssertEqual(progress.shortfallPence, 50000)
        XCTAssertEqual(progress.sourceLabels, ["Personal loan debt"])
    }

    @MainActor
    func testDueLinkedDebtPotPaysDebtOnce() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let debt = makeDebt(id: "debt-loan", name: "Personal loan", currentBalancePence: 50000, dueDate: "2026-06-10")
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 50000, targetPence: nil, linkedDebtId: debt.id)
        let scheduleItem = makeDebtScheduleItem(
            id: "debt-schedule-debt-loan-2026-06-10",
            debtId: debt.id,
            dueDate: "2026-06-10",
            amountPence: 50000,
            fundedAmountPence: 50000,
            status: .funded
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], debts: [debt], debtPaymentScheduleItems: [scheduleItem])))

        await store.load()
        let payment = store.snapshot.debtPayments.first

        XCTAssertEqual(payment?.id, "linked-debt-pot-payment-debt-loan-2026-06-10")
        XCTAssertEqual(payment?.amountPence, 50000)
        XCTAssertEqual(payment?.date, "2026-06-10")
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 0)
        XCTAssertEqual(store.snapshot.debts.first?.status, .paidOff)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-10"))
        XCTAssertEqual(store.snapshot.debtPayments.count, 1)
    }

    func testDeletedDuplicateCardChargesDoNotBecomeStatementOrFundingDebt() throws {
        let period = makePayPeriod(
            id: "period-card", startDate: "2026-08-10", endDate: "2026-09-09",
            payday: "2026-08-10", incomePence: 200_000
        )
        let card = makeCreditCard(
            id: "card-main", name: "Card", limitPence: 100_000,
            openingBalancePence: 0, openingStatementBalancePence: 0,
            statementDate: "2026-09-01", dueDay: 5,
            createdAt: "2026-08-09T19:20:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Card", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let bill = makeRecurringPayment(
            id: "bill-subscription", name: "Subscription", amountPence: 20_000,
            dueDay: 21, potId: pot.id, creditCardId: card.id,
            createdAt: "2026-08-09T19:20:00.000Z"
        )
        var charge = makeTransaction(id: "recurring-charge", cardId: card.id, amountPence: 20_000, date: "2026-08-21", note: "Subscription")
        charge.recurringPaymentId = bill.id
        let groceries = makeTransaction(id: "groceries", cardId: card.id, amountPence: 8_623, date: "2026-08-22", note: "Groceries")
        // Re-recording an occurrence can retain multiple tombstones with the same ID.
        let deletedDuplicates = (0..<4).map { index in
            var deleted = charge
            deleted.deletedAt = "2026-08-24T08:51:1\(index).000Z"
            return deleted
        }
        let snapshot = makeSnapshot(
            settings: makeManualSettings(today: "2026-08-30"), pots: [pot],
            recurringPayments: [bill], payPeriods: [period],
            transactions: deletedDuplicates + [charge, groceries], creditCards: [card]
        )
        // Exercise persisted state, not just an in-memory clean fixture.
        let restored = try JSONDecoder().decode(PlannerSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(restored.transactions.count, 6)

        for asOfDate in ["2026-08-30", "2026-09-01"] {
            let payment = try XCTUnwrap(PlannerDerivedData.creditCardStatementPayments(
                card: card, snapshot: restored, startDate: asOfDate,
                endDate: "2026-09-05", asOfDate: asOfDate
            ).first)
            XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: restored), 28_623)
            XCTAssertEqual(payment.actualDuePence, 28_623)
            XCTAssertEqual(payment.forecastDuePence, 28_623)
            let group = try XCTUnwrap(PlannerDerivedData.fundingChecklistDestinationGroups(
                items: PlannerDerivedData.fundingChecklistPresentationItems(
                    snapshot: restored, payPeriod: period, asOfDate: asOfDate, groupByFundingDueDate: true
                )
            ).first { $0.destinationId == pot.id })
            XCTAssertEqual(group.totalAmountPence, 28_623)
            XCTAssertEqual(group.items.count, 2)
            XCTAssertFalse(group.items.contains { if case .cardPayment = $0.action { return true }; return false })
        }
        let statement = try XCTUnwrap(PlannerDerivedData.creditCardStatementSummaries(snapshot: restored, asOfDate: "2026-09-01").first)
        XCTAssertEqual(statement.statementAmountPence, 28_623)
        XCTAssertEqual(statement.transactions.count, 2)
    }

    func testDebtFundingChecklistDerivesCurrentPeriodLinkedDebtShortfall() {
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 100000)
        let eligible = makeDebt(id: "debt-loan", name: "Personal loan", currentBalancePence: 50000, dueDate: "2026-06-10")
        let unlinked = makeDebt(id: "debt-unlinked", name: "Unlinked", currentBalancePence: 25000, dueDate: "2026-06-11")
        let nextPeriod = makeDebt(id: "debt-next", name: "Next period", currentBalancePence: 30000, dueDate: "2026-07-01")
        let linkedPot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 10000, targetPence: nil, linkedDebtId: eligible.id)
        let nextPeriodPot = makePot(id: "pot-next", name: "Next pot", balancePence: 0, targetPence: nil, linkedDebtId: nextPeriod.id)
        let scheduleItems = [
            makeDebtScheduleItem(id: "debt-schedule-debt-loan-2026-06-10", debtId: eligible.id, dueDate: "2026-06-10", amountPence: 50000),
            makeDebtScheduleItem(id: "debt-schedule-debt-unlinked-2026-06-11", debtId: unlinked.id, dueDate: "2026-06-11", amountPence: 25000),
            makeDebtScheduleItem(id: "debt-schedule-debt-next-2026-07-01", debtId: nextPeriod.id, dueDate: "2026-07-01", amountPence: 30000)
        ]
        let snapshot = makeSnapshot(pots: [linkedPot, nextPeriodPot], payPeriods: [period], debts: [eligible, unlinked, nextPeriod], debtPaymentScheduleItems: scheduleItems)

        let items = PlannerDerivedData.debtFundingChecklistItems(snapshot: snapshot, payPeriod: period)

        XCTAssertEqual(items.map(\.id), ["debt-funding-debt-loan-2026-06-10"])
        XCTAssertEqual(items.first?.debtName, "Personal loan")
        XCTAssertEqual(items.first?.lenderName, "Loan Provider")
        XCTAssertEqual(items.first?.potName, "Loan pot")
        XCTAssertEqual(items.first?.amountPence, 40000)
        XCTAssertEqual(items.first?.dueDate, "2026-06-10")
        XCTAssertEqual(items.first?.isCompleted, false)
    }

    @MainActor
    func testTickingDebtFundingChecklistTopsUpAndUntickingReversesPotAllocation() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let debt = makeDebt(id: "debt-loan", name: "Personal loan", currentBalancePence: 50000, dueDate: "2026-06-10")
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 10000, targetPence: nil, linkedDebtId: debt.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], debts: [debt])))

        await store.load()
        XCTAssertTrue(store.setDebtFundingCompleted(debtId: debt.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))

        let allocation = store.snapshot.potAllocations.first
        XCTAssertEqual(allocation?.source, .debtFunding)
        XCTAssertEqual(allocation?.debtId, debt.id)
        XCTAssertEqual(allocation?.debtDueDate, "2026-06-10")
        XCTAssertEqual(allocation?.amountPence, 40000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 50000)

        let fundedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        XCTAssertEqual(fundedSummary.potAllocationsPence, 40000)
        XCTAssertEqual(fundedSummary.debtMinimumsPence, 0)
        XCTAssertEqual(fundedSummary.moneyLeftPence, 10000)

        XCTAssertTrue(store.setDebtFundingCompleted(debtId: debt.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.potAllocations.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)
    }

    @MainActor
    func testDebtPotFundingCyclePaysDebtFromPotWithoutSecondPaycheckCost() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let debt = makeDebt(id: "debt-loan", name: "Personal loan", currentBalancePence: 50000, dueDate: "2026-06-10")
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 0, targetPence: nil, linkedDebtId: debt.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], debts: [debt])))

        await store.load()
        XCTAssertTrue(store.setDebtFundingCompleted(debtId: debt.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))

        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-06-10"
        store.updateSettings(dueSettings)

        let payment = store.snapshot.debtPayments.first
        XCTAssertEqual(payment?.id, "linked-debt-pot-payment-debt-loan-2026-06-10")
        XCTAssertEqual(payment?.amountPence, 50000)
        XCTAssertEqual(payment?.date, "2026-06-10")
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 0)
        XCTAssertEqual(store.snapshot.debts.first?.status, .paidOff)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let dueSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(dueSummary.potAllocationsPence, 50000)
        XCTAssertEqual(dueSummary.debtMinimumsPence, 0)
        XCTAssertEqual(dueSummary.totalCostsPence, 50000)
        XCTAssertEqual(dueSummary.moneyLeftPence, 0)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-10"))
        XCTAssertEqual(store.snapshot.debtPayments.count, 1)
    }

    func testDebtAutoSpreadNoInterestScheduleClearsByDueDate() {
        let debt = makePlannerDebt(
            id: "debt-family",
            name: "Family loan",
            startingBalancePence: 100000,
            targetPayoffDate: "2026-09-01",
            repaymentStrategy: .autoSpreadUntilDueDate,
            paymentFrequency: .monthly,
            paymentDay: 1
        )

        let schedule = DebtPlannerEngine.generateSchedule(for: debt, payPeriods: [], today: "2026-07-01")

        XCTAssertEqual(schedule.map(\.plannedAmountPence), [33334, 33333, 33333])
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.principalAmountPence }, 100000)
        XCTAssertEqual(schedule.last?.dueDate, "2026-09-01")
        XCTAssertEqual(schedule.map(\.interestAmountPence), [0, 0, 0])
    }

    func testDebtPayIn4SplitsPenniesAndExtraPaymentLowersFinalPayment() {
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let debt = makePlannerDebt(
            id: "debt-bnpl",
            name: "BNPL sofa",
            startingBalancePence: 40001,
            targetPayoffDate: "2026-10-01",
            repaymentStrategy: .payIn4,
            paymentFrequency: .monthly,
            payFirstTiming: .nextPayday
        )

        let schedule = DebtPlannerEngine.generateSchedule(for: debt, payPeriods: [period], today: "2026-07-01")
        XCTAssertEqual(schedule.count, 4)
        XCTAssertEqual(schedule.map(\.plannedAmountPence), [10001, 10000, 10000, 10000])

        let recalculated = DebtPlannerEngine.recalculateSchedule(
            afterExtraPaymentPence: 5000,
            debt: debt,
            scheduleItems: schedule,
            mode: .lowerFuturePayments,
            payPeriods: [period],
            today: "2026-07-01"
        )

        XCTAssertEqual(recalculated.dropLast().map(\.plannedAmountPence), [10001, 10000, 10000])
        XCTAssertEqual(recalculated.last?.plannedAmountPence, 5000)
        XCTAssertEqual(recalculated.reduce(0) { $0 + $1.plannedAmountPence }, 35001)
    }

    func testDebtFixedPaymentAndMinimumPlusExtraEstimatePayoff() {
        let fixed = makePlannerDebt(
            id: "debt-fixed",
            name: "Fixed loan",
            startingBalancePence: 45000,
            targetPayoffDate: nil,
            minimumPaymentPence: 15000,
            repaymentStrategy: .fixedPayment,
            paymentFrequency: .monthly,
            paymentDay: 5
        )
        let minimumPlusExtra = makePlannerDebt(
            id: "debt-min-extra",
            name: "APR loan",
            startingBalancePence: 45000,
            targetPayoffDate: nil,
            minimumPaymentPence: 10000,
            extraPaymentPence: 5000,
            repaymentStrategy: .minimumPlusExtra,
            paymentFrequency: .monthly,
            paymentDay: 5
        )

        XCTAssertEqual(DebtPlannerEngine.generateSchedule(for: fixed, payPeriods: [], today: "2026-07-01").map(\.plannedAmountPence), [15000, 15000, 15000])
        XCTAssertEqual(DebtPlannerEngine.generateSchedule(for: minimumPlusExtra, payPeriods: [], today: "2026-07-01").map(\.plannedAmountPence), [15000, 15000, 15000])
    }

    func testDebtManualOnlyAndNoDueDateStrategyRules() {
        let manual = makePlannerDebt(
            id: "debt-manual",
            name: "Manual IOU",
            startingBalancePence: 25000,
            targetPayoffDate: nil,
            repaymentStrategy: .manualOnly,
            paymentFrequency: .monthly
        )
        var autoSpreadNoDueDate = manual
        autoSpreadNoDueDate.repaymentStrategy = .autoSpreadUntilDueDate
        var fixedNoDueDate = manual
        fixedNoDueDate.repaymentStrategy = .fixedPayment
        fixedNoDueDate.minimumPaymentPence = 5000

        XCTAssertTrue(DebtPlannerEngine.generateSchedule(for: manual, payPeriods: [], today: "2026-07-01").isEmpty)
        XCTAssertTrue(DebtPlannerEngine.generateSchedule(for: autoSpreadNoDueDate, payPeriods: [], today: "2026-07-01").isEmpty)
        XCTAssertFalse(DebtPlannerEngine.generateSchedule(for: fixedNoDueDate, payPeriods: [], today: "2026-07-01").isEmpty)
    }

    func testDebtAprInterestPaymentAllocationAndRiskWarning() {
        let debt = makePlannerDebt(
            id: "debt-apr",
            name: "APR debt",
            startingBalancePence: 120000,
            targetPayoffDate: nil,
            interestType: .apr,
            aprBasisPoints: 2490,
            minimumPaymentPence: 1000,
            repaymentStrategy: .minimumPlusExtra,
            paymentFrequency: .monthly,
            paymentDay: 1
        )

        let interest = DebtPlannerEngine.estimatedInterestPence(balancePence: 120000, aprBasisPoints: 2490, days: 30)
        XCTAssertGreaterThan(interest, 0)

        let scheduleItem = DebtPaymentScheduleItem(
            id: "schedule-apr-1",
            debtId: debt.id,
            dueDate: "2026-08-01",
            plannedAmountPence: interest + 500,
            principalAmountPence: 500,
            interestAmountPence: interest,
            feeAmountPence: 0,
            fundedAmountPence: interest + 500,
            paidAmountPence: 0,
            paidDate: nil,
            status: .funded,
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z",
            deletedAt: nil
        )

        let application = DebtPlannerEngine.applyPayment(
            debt: debt,
            scheduleItem: scheduleItem,
            amountPence: interest + 500,
            date: "2026-08-01",
            sourcePotId: "pot-apr",
            paymentType: .scheduled
        )

        XCTAssertEqual(application.payment.interestPaidPence, interest)
        XCTAssertEqual(application.payment.principalPaidPence, 500)
        XCTAssertEqual(application.debt.currentBalancePence, 119500)
        XCTAssertTrue(DebtPlannerEngine.hasInterestRisk(debt: debt, paymentAmountPence: max(0, interest - 1), days: 30))
    }

    @MainActor
    func testDebtDueBeforeNextPaydayDueTodayAndAddedAfterPaydayAppearInChecklist() async {
        let settings = makeManualSettings(today: "2026-07-10")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let dueToday = makePlannerDebt(id: "debt-today", name: "Due today", startingBalancePence: 20000, targetPayoffDate: "2026-07-10", repaymentStrategy: .autoSpreadUntilDueDate, paymentFrequency: .monthly, paymentDay: 10)
        let dueBeforeNextPayday = makePlannerDebt(id: "debt-before-next", name: "Due before next", startingBalancePence: 15000, targetPayoffDate: "2026-07-20", repaymentStrategy: .autoSpreadUntilDueDate, paymentFrequency: .monthly, paymentDay: 20)
        let potToday = makePot(id: "pot-today", name: "Today pot", balancePence: 0, targetPence: nil, linkedDebtId: dueToday.id)
        let potBefore = makePot(id: "pot-before", name: "Before pot", balancePence: 0, targetPence: nil, linkedDebtId: dueBeforeNextPayday.id)
        let snapshot = makeSnapshot(settings: settings, pots: [potToday, potBefore], payPeriods: [period], debts: [dueToday, dueBeforeNextPayday])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()

        let items = PlannerDerivedData.debtFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(Set(items.map(\.debtId)), [dueToday.id, dueBeforeNextPayday.id])
        XCTAssertEqual(items.first(where: { $0.debtId == dueToday.id })?.dueDate, "2026-07-10")
        XCTAssertEqual(items.first(where: { $0.debtId == dueBeforeNextPayday.id })?.dueDate, "2026-07-20")
    }

    @MainActor
    func testDebtMissedAndPartFundedPaymentsDoNotReduceBalance() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let debt = makePlannerDebt(id: "debt-loan", name: "Loan", startingBalancePence: 50000, targetPayoffDate: "2026-06-10", repaymentStrategy: .autoSpreadUntilDueDate, paymentFrequency: .monthly, paymentDay: 10)
        let scheduleItem = makeDebtScheduleItem(id: "debt-schedule-debt-loan-2026-06-10", debtId: debt.id, dueDate: "2026-06-10", amountPence: 50000, fundedAmountPence: 25000)
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 25000, targetPence: nil, linkedDebtId: debt.id)
        let snapshot = makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], debts: [debt], debtPaymentScheduleItems: [scheduleItem])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-06-10"
        store.updateSettings(dueSettings)

        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 50000)
        XCTAssertTrue([.partFunded, .overdue].contains(store.snapshot.debtPaymentScheduleItems.first?.status))
        XCTAssertTrue(store.snapshot.debtPayments.isEmpty)
    }

    @MainActor
    func testDebtOverpaymentPaidOffCancelsFutureItemsAndLeavesPotSurplus() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 100000)
        let debt = makePlannerDebt(id: "debt-loan", name: "Loan", startingBalancePence: 30000, targetPayoffDate: "2026-08-01", minimumPaymentPence: 10000, repaymentStrategy: .fixedPayment, paymentFrequency: .monthly, paymentDay: 1)
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 5000, targetPence: nil, linkedDebtId: debt.id)
        let snapshot = makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], debts: [debt])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        store.recordManualDebtPayment(
            debtId: debt.id,
            amountPence: 50000,
            date: "2026-06-01",
            paymentType: DebtPaymentType.manualPayNow,
            recalculationMode: DebtRecalculationMode.finishEarlier,
            note: "Clear balance"
        )

        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 0)
        XCTAssertEqual(store.snapshot.debts.first?.status, .paidOff)
        XCTAssertEqual(store.snapshot.debtPayments.first?.amountPence, 30000)
        XCTAssertFalse(store.snapshot.pots.first?.balancePence ?? 0 < 0)
        XCTAssertTrue(store.snapshot.debtPaymentScheduleItems.filter { $0.status != DebtPaymentScheduleStatus.cancelled && $0.status != DebtPaymentScheduleStatus.paid }.isEmpty)
    }

    func testDebtExtraPaymentsCanLowerFuturePaymentsOrFinishEarlier() {
        let debt = makePlannerDebt(
            id: "debt-loan",
            name: "Loan",
            startingBalancePence: 40000,
            targetPayoffDate: "2026-10-01",
            repaymentStrategy: .autoSpreadUntilDueDate,
            paymentFrequency: .monthly,
            paymentDay: 1
        )
        let schedule = DebtPlannerEngine.generateSchedule(for: debt, payPeriods: [], today: "2026-07-01")

        let lowerFuture = DebtPlannerEngine.recalculateSchedule(afterExtraPaymentPence: 10000, debt: debt, scheduleItems: schedule, mode: .lowerFuturePayments, payPeriods: [], today: "2026-07-01")
        let finishEarlier = DebtPlannerEngine.recalculateSchedule(afterExtraPaymentPence: 10000, debt: debt, scheduleItems: schedule, mode: .finishEarlier, payPeriods: [], today: "2026-07-01")

        XCTAssertEqual(lowerFuture.count, schedule.count)
        XCTAssertEqual(lowerFuture.reduce(0) { $0 + $1.plannedAmountPence }, 30000)
        XCTAssertLessThan(finishEarlier.count, schedule.count)
        XCTAssertEqual(finishEarlier.reduce(0) { $0 + $1.plannedAmountPence }, 30000)
    }

    @MainActor
    func testDebtPaymentsAffectChecklistPotTotalsAndDoNotAffectCreditCards() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 100000)
        let debt = makePlannerDebt(id: "debt-loan", name: "Loan", startingBalancePence: 30000, targetPayoffDate: "2026-06-10", repaymentStrategy: .autoSpreadUntilDueDate, paymentFrequency: .monthly, paymentDay: 10)
        let debtPot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 0, targetPence: nil, linkedDebtId: debt.id)
        let card = makeCreditCard(id: "card-main", name: "Main Card", openingBalancePence: 10000, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let cardPot = makePot(id: "pot-card", name: "Card pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let snapshot = makeSnapshot(settings: settings, pots: [debtPot, cardPot], payPeriods: [period], debts: [debt], creditCards: [card])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        let beforeAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        let beforeStatements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-06-01")
        let beforeSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")

        XCTAssertTrue(store.setDebtFundingCompleted(debtId: debt.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        XCTAssertEqual(summary.committedCostsPence, beforeSummary.committedCostsPence + 30000)
        XCTAssertEqual(summary.unfundedChecklistPence, beforeSummary.unfundedChecklistPence - 30000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, beforeSummary.projectedMoneyLeftPence)
        XCTAssertEqual(summary.currentMoneyLeftPence, beforeSummary.currentMoneyLeftPence - 30000)
        XCTAssertEqual(store.snapshot.pots.first(where: { $0.id == debtPot.id })?.balancePence, 30000)

        let afterAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        let afterStatements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-06-01")
        XCTAssertEqual(afterAvailability, beforeAvailability)
        XCTAssertEqual(afterStatements, beforeStatements)
    }

    func testDebtLegacyCodableDefaultsNewPlanningFields() throws {
        let json = """
        {
          "id": "debt-legacy",
          "name": "Legacy debt",
          "lender": "Legacy lender",
          "originalAmountPence": 90000,
          "currentBalancePence": 90000,
          "minimumPaymentPence": 30000,
          "dueDate": "2026-09-01",
          "interestRateApr": 24.9,
          "note": "",
          "status": "active",
          "createdAt": "2026-06-01T00:00:00.000Z",
          "updatedAt": "2026-06-01T00:00:00.000Z",
          "deletedAt": null
        }
        """.data(using: .utf8)!

        let debt = try JSONDecoder().decode(Debt.self, from: json)

        XCTAssertEqual(debt.type, .other)
        XCTAssertEqual(debt.startingBalancePence, 90000)
        XCTAssertEqual(debt.targetPayoffDate, "2026-09-01")
        XCTAssertEqual(debt.interestType, .apr)
        XCTAssertEqual(debt.aprBasisPoints, 2490)
        XCTAssertEqual(debt.repaymentStrategy, .fixedPayment)
        XCTAssertEqual(debt.status, .active)
    }
}
