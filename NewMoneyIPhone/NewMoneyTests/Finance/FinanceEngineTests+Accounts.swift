import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    @MainActor
    func testFirstPaycheckDoesNotCreateOrRetainAnEmptyTodayPlaceholderPeriod() async {
        var settings = makeManualSettings(today: "2026-07-10")
        settings.payFrequency = .monthly

        let emptyStore = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings)))
        await emptyStore.load()
        XCTAssertTrue(emptyStore.snapshot.payPeriods.isEmpty)

        emptyStore.createPayPeriod(
            payday: "2026-07-01",
            hoursWorked: 2261.91,
            hourlyRatePence: 100,
            actualAmountPence: 226191,
            payFrequency: .monthly
        )
        XCTAssertEqual(emptyStore.snapshot.payPeriods.map(\.payday), ["2026-07-01"])
        XCTAssertEqual(emptyStore.selectedPayPeriod?.endDate, "2026-07-31")

        var realPeriod = makePayPeriod(
            id: "pay-period-2026-07-01",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 226191
        )
        realPeriod.status = .active
        var placeholder = makePayPeriod(
            id: "pay-period-2026-07-10",
            startDate: "2026-07-10",
            endDate: "2026-08-09",
            payday: "2026-07-10",
            incomePence: 0
        )
        placeholder.status = .closed
        let paycheck = Paycheck(
            id: "paycheck-july",
            payPeriodId: realPeriod.id,
            hoursWorked: 2261.91,
            hourlyRatePence: 100,
            calculatedAmountPence: 226191,
            actualAmountPence: 226191,
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z",
            deletedAt: nil
        )
        var legacySnapshot = makeSnapshot(
            settings: settings,
            payPeriods: [placeholder, realPeriod]
        )
        legacySnapshot.paychecks = [paycheck]
        let repairedStore = PlannerStore(repository: TestPlannerRepository(snapshot: legacySnapshot))
        await repairedStore.load()

        XCTAssertEqual(repairedStore.snapshot.payPeriods.map(\.payday), ["2026-07-01"])
        XCTAssertEqual(repairedStore.selectedPayPeriod?.id, realPeriod.id)
    }

    @MainActor
    func testOneOffIncomeAddsToCurrentPeriodWithoutCreatingPaycheck() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, payPeriods: [period])))

        await store.load()
        XCTAssertTrue(store.addOneOffIncome(name: "Birthday gift", amountPence: 25000, date: "2026-06-10", note: "Birthday gift"))

        XCTAssertEqual(store.snapshot.oneOffIncomes.map(\.name), ["Birthday gift"])
        XCTAssertTrue(store.snapshot.paychecks.isEmpty)
        XCTAssertEqual(store.snapshot.payPeriods.map(\.id), [period.id])

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(summary.payReceivedPence, 75000)
        XCTAssertEqual(summary.moneyLeftPence, 75000)
    }

    @MainActor
    func testCurrentTotalMoneyCountsLinkedBalancesAndUnlinkedIncomeExactlyOnce() async throws {
        let settings = makeManualSettings(today: "2026-06-10")
        let account = makeBankAccount(id: "bank-main", openingBalancePence: 100_000)
        let pot = makePot(
            id: "pot-bills",
            name: "Bills",
            balancePence: 0,
            targetPence: nil,
            fundingBankAccountId: account.id
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            bankAccounts: [account],
            pots: [pot]
        )))
        await store.load()

        store.createPayPeriod(
            payday: "2026-06-01",
            hoursWorked: 2_000,
            hourlyRatePence: 100,
            actualAmountPence: 200_000,
            payFrequency: .monthly,
            bankAccountId: account.id
        )
        XCTAssertTrue(
            store.addOneOffIncome(
                name: "Cash income",
                amountPence: 50_000,
                date: "2026-06-10",
                note: "",
                bankAccountId: nil
            )
        )
        XCTAssertTrue(store.addPotAllocation(potId: pot.id, amountPence: 25_000))
        store.recordTransaction(
            potId: nil,
            creditCardId: nil,
            bankAccountId: account.id,
            paymentMethod: .bankAccount,
            amountPence: 2_500,
            type: .spending,
            date: "2026-06-10",
            note: "Groceries"
        )
        store.recordTransaction(
            potId: nil,
            creditCardId: nil,
            paymentMethod: .income,
            amountPence: 5_000,
            type: .spending,
            date: "2026-06-10",
            note: "Cash spend"
        )

        let currentPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let currentAccount = try XCTUnwrap(store.activeBankAccounts.first)
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: currentAccount, snapshot: store.snapshot),
            272_500
        )
        XCTAssertEqual(store.activePots.first?.balancePence, 25_000)
        XCTAssertEqual(
            PlannerDerivedData.currentTotalMoneyPence(
                snapshot: store.snapshot,
                payPeriod: currentPeriod
            ),
            342_500
        )

        let includedBreakdown = PlannerDerivedData.currentMoneyBreakdown(
            snapshot: store.snapshot,
            payPeriod: currentPeriod
        )
        XCTAssertTrue(includedBreakdown.includesPots)
        XCTAssertEqual(includedBreakdown.totalPence, 342_500)
        XCTAssertEqual(includedBreakdown.components.reduce(0) { $0 + $1.amountPence }, 342_500)
        XCTAssertTrue(includedBreakdown.components.contains { $0.kind == .pot && $0.amountPence == 25_000 })

        var potsExcludedSettings = store.snapshot.settings
        potsExcludedSettings.includePotsInMoneyLeft = false
        store.updateSettings(potsExcludedSettings)

        let excludedBreakdown = PlannerDerivedData.currentMoneyBreakdown(
            snapshot: store.snapshot,
            payPeriod: currentPeriod
        )
        XCTAssertFalse(excludedBreakdown.includesPots)
        XCTAssertFalse(excludedBreakdown.components.contains { $0.kind == .pot || $0.kind == .cardReserve })
        XCTAssertEqual(excludedBreakdown.totalPence, 317_500)
        XCTAssertEqual(
            PlannerDerivedData.currentTotalMoneyPence(
                snapshot: store.snapshot,
                payPeriod: currentPeriod
            ),
            317_500
        )
    }

    @MainActor
    func testDirectDebitLinkedToBankAccountPostsOnceOnItsDueDate() async {
        var settings = makeManualSettings(today: "2026-06-09")
        settings.lastProcessedDateIso = "2026-06-09"
        let account = makeBankAccount(id: "bank-main", openingBalancePence: 100_000)
        let bill = makeRecurringPayment(
            id: "bill-phone",
            name: "Phone",
            amountPence: 2_999,
            dueDay: 10,
            potId: nil,
            bankAccountId: account.id
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            bankAccounts: [account],
            recurringPayments: [bill]
        )))
        await store.load()
        store.setManualTodayForSimulation("2026-06-10")

        XCTAssertTrue(store.applyDueScheduledPaymentsForSimulation(asOf: "2026-06-10"))
        XCTAssertFalse(store.applyDueScheduledPaymentsForSimulation(asOf: "2026-06-10"))
        let transaction = try! XCTUnwrap(store.snapshot.transactions.first { $0.recurringPaymentId == bill.id })
        XCTAssertEqual(transaction.paymentMethod, .bankAccount)
        XCTAssertEqual(transaction.bankAccountId, account.id)
        XCTAssertEqual(transaction.date, "2026-06-10")
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            97_001
        )
    }

    func testOneOffIncomeDateKeepsItInCurrentMoneyLeftWhenStoredPeriodIdIsStale() {
        let currentPeriod = makePayPeriod(
            id: "period-july-current",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        let stalePeriod = makePayPeriod(
            id: "period-july-stale",
            startDate: "2026-06-01",
            endDate: "2026-06-30",
            payday: "2026-06-01",
            incomePence: 50000
        )
        let oneOffIncome = OneOffIncome(
            id: "one-off-income-bonus",
            payPeriodId: stalePeriod.id,
            name: "Bonus",
            amountPence: 25000,
            date: "2026-07-21",
            note: "",
            createdAt: "2026-07-21T10:00:00Z",
            updatedAt: "2026-07-21T10:00:00Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            payPeriods: [currentPeriod, stalePeriod],
            oneOffIncomes: [oneOffIncome]
        )

        let currentSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: currentPeriod,
            asOfDate: "2026-07-21"
        )
        XCTAssertEqual(currentSummary.payReceivedPence, 125000)
        XCTAssertEqual(currentSummary.currentMoneyLeftPence, 125000)
        XCTAssertEqual(currentSummary.projectedMoneyLeftPence, 125000)

        let staleSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: stalePeriod,
            asOfDate: "2026-07-21"
        )
        XCTAssertEqual(staleSummary.payReceivedPence, 50000)
    }

    @MainActor
    func testProjectedCashDuePeriodChecklistCanBeTickedAndUnticked() async throws {
        var settings = makeManualSettings(today: "2026-07-20")
        settings.payFrequency = .monthly
        var july = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        july.payFrequency = .monthly
        let card = makeCreditCard(
            id: "card-main",
            name: "Main card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-25",
            dueDay: 5
        )
        let pot = makePot(
            id: "pot-main-card",
            name: "Main card",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let bill = makeRecurringPayment(
            id: "bill-mobile",
            name: "Mobile",
            amountPence: 2500,
            dueDay: 21,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [bill],
            payPeriods: [july],
            creditCards: [card]
        )))

        await store.load()
        let august = try XCTUnwrap(PlannerDerivedData.projectedFundingPayPeriods(
            snapshot: store.snapshot,
            startingAt: store.selectedPayPeriod,
            count: 2
        ).last)
        XCTAssertEqual(august.id, "pay-period-2026-08-01")
        XCTAssertEqual(august.startDate, "2026-08-01")
        XCTAssertEqual(august.endDate, "2026-08-31")
        let dueItems = PlannerDerivedData.recurringBillFundingChecklistItems(
            snapshot: store.snapshot,
            payPeriod: august,
            groupByFundingDueDate: true
        )
        XCTAssertEqual(dueItems.map(\.paymentName), [bill.name])
        let item = try XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: august,
            asOfDate: "2026-08-01",
            groupByFundingDueDate: true
        ).first { $0.name == bill.name })

        XCTAssertEqual(item.dueDate, "2026-08-05")
        XCTAssertTrue(store.setFundingChecklistCompleted(action: item.action, completed: true))
        XCTAssertEqual(store.snapshot.potAllocations.first?.payPeriodId, august.id)
        XCTAssertEqual(store.snapshot.potAllocations.first?.creditCardDirectDebitDate, "2026-08-05")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 2500)

        let completedItem = try XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: august,
            asOfDate: "2026-08-01",
            groupByFundingDueDate: true
        ).first { $0.name == bill.name })
        XCTAssertTrue(completedItem.isCompleted)

        XCTAssertTrue(store.setFundingChecklistCompleted(action: completedItem.action, completed: false))
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testOneOffIncomeCanBeUpdatedAndDeletedForCorrections() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let junePeriod = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let julyPeriod = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, payPeriods: [junePeriod, julyPeriod])))

        await store.load()
        XCTAssertTrue(store.addOneOffIncome(name: "Gift", amountPence: 25000, date: "2026-06-10", note: "Original"))
        let incomeId = try! XCTUnwrap(store.snapshot.oneOffIncomes.first?.id)

        XCTAssertTrue(store.updateOneOffIncome(id: incomeId, name: "Bonus", amountPence: 30000, date: "2026-07-05", note: "Corrected"))

        let updatedIncome = try! XCTUnwrap(store.snapshot.oneOffIncomes.first { $0.id == incomeId })
        XCTAssertEqual(updatedIncome.name, "Bonus")
        XCTAssertEqual(updatedIncome.amountPence, 30000)
        XCTAssertEqual(updatedIncome.date, "2026-07-05")
        XCTAssertEqual(updatedIncome.note, "Corrected")
        XCTAssertEqual(updatedIncome.payPeriodId, julyPeriod.id)

        let juneSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-07-05")
        let julySummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: julyPeriod, asOfDate: "2026-07-05")
        XCTAssertEqual(juneSummary.payReceivedPence, 50000)
        XCTAssertEqual(julySummary.payReceivedPence, 80000)

        XCTAssertTrue(store.deleteOneOffIncome(id: incomeId))
        let deletedIncome = try! XCTUnwrap(store.snapshot.oneOffIncomes.first { $0.id == incomeId })
        XCTAssertNotNil(deletedIncome.deletedAt)
        let deletedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: julyPeriod, asOfDate: "2026-07-05")
        XCTAssertEqual(deletedSummary.payReceivedPence, 50000)
    }

    @MainActor
    func testBackfilledCurrentMonthlyPeriodDoesNotCopyFutureIncomeOrCreateGeneratedPaycheck() async {
        var settings = makeManualSettings(today: "2026-07-09")
        settings.payFrequency = .monthly

        var augustPeriod = makePayPeriod(
            id: "period-august",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 169600
        )
        augustPeriod.status = .planned
        augustPeriod.payFrequency = .monthly

        let initialIncome = OneOffIncome(
            id: "one-off-initial-income",
            payPeriodId: nil,
            name: "Initial income",
            amountPence: 340663,
            date: "2026-07-09",
            note: "",
            createdAt: "2026-07-09T09:00:00.000Z",
            updatedAt: "2026-07-09T09:00:00.000Z",
            deletedAt: nil
        )

        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            payPeriods: [augustPeriod],
            oneOffIncomes: [initialIncome]
        )))

        await store.load()

        let currentPeriod = try! XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(currentPeriod.startDate, "2026-07-01")
        XCTAssertEqual(currentPeriod.endDate, "2026-07-31")
        XCTAssertEqual(currentPeriod.incomePence, 0)
        XCTAssertTrue(store.snapshot.paychecks.isEmpty)

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: currentPeriod, asOfDate: "2026-07-09")
        XCTAssertEqual(summary.payReceivedPence, 340663)
        XCTAssertEqual(summary.moneyLeftPence, 340663)
        XCTAssertEqual(FinanceEngine.getDailySafeToSpendPence(spendablePence: summary.moneyLeftPence, today: "2026-07-09", endDate: currentPeriod.endDate), 14811)
    }

    @MainActor
    func testJajaOpeningBalanceCatchUpKeepsTheOriginalAugustDueDate() async throws {
        let settings = makeManualSettings(today: "2026-07-09")
        let jajaCard = makeCreditCard(
            id: "card-jaja",
            name: "Jaja",
            limitPence: 25000,
            openingBalancePence: 21580,
            openingStatementBalancePence: 21580,
            statementDate: "2026-07-07",
            dueDay: 3
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, creditCards: [jajaCard])))

        await store.load()

        var septemberSettings = store.snapshot.settings
        septemberSettings.manualTodayIso = "2026-09-03"
        store.updateSettings(septemberSettings)

        let repayments = store.snapshot.creditCardRepayments.filter { $0.creditCardId == jajaCard.id }
        XCTAssertEqual(repayments.count, 1)
        XCTAssertEqual(repayments.first?.statementDate, "2026-07-07")
        XCTAssertEqual(repayments.first?.directDebitDate, "2026-08-03")
        XCTAssertEqual(repayments.first?.amountPence, 21580)
    }

    func testLinkedBillPotDoesNotAdoptAnUpcomingBillOutsideTheCurrentPayPeriod() {
        let settings = makeManualSettings(today: "2026-07-09")
        let period = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        let pot = makePot(id: "pot-insurance", name: "Insurance", balancePence: 0, targetPence: nil)
        let insurance = makeRecurringPayment(
            id: "bill-car-insurance",
            name: "Car insurance",
            amountPence: 8711,
            dueDay: 1,
            potId: pot.id
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [insurance],
            payPeriods: [period]
        )

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-07-09")

        XCTAssertEqual(progress.targetPence, 0)
        XCTAssertEqual(progress.targetLabel, "No target yet")
    }

    @MainActor
    func testDirectDateSkipMatchesDayByDayProcessingAndIsIdempotent() async throws {
        let steppedStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))
        let skippedStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await steppedStore.load()
        await skippedStore.load()
        let steppedJuly = try XCTUnwrap(steppedStore.selectedPayPeriod)
        let skippedJuly = try XCTUnwrap(skippedStore.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: steppedStore, payPeriod: steppedJuly))
        XCTAssertTrue(fundBasicDataJulyChecklist(in: skippedStore, payPeriod: skippedJuly))

        var cursor = "2026-07-02"
        while cursor <= "2026-08-05" {
            var settings = steppedStore.snapshot.settings
            settings.manualTodayIso = cursor
            steppedStore.updateSettings(settings)
            cursor = FinanceEngine.addIsoDays(date: cursor, days: 1)
        }

        var skipSettings = skippedStore.snapshot.settings
        skipSettings.manualTodayIso = "2026-08-05"
        skippedStore.updateSettings(skipSettings)

        XCTAssertEqual(ledgerSignature(for: skippedStore.snapshot, asOfDate: "2026-08-05"), ledgerSignature(for: steppedStore.snapshot, asOfDate: "2026-08-05"))

        let transactionCount = skippedStore.snapshot.transactions.count
        let repaymentCount = skippedStore.snapshot.creditCardRepayments.count
        skippedStore.updateSettings(skipSettings)
        XCTAssertEqual(skippedStore.snapshot.transactions.count, transactionCount)
        XCTAssertEqual(skippedStore.snapshot.creditCardRepayments.count, repaymentCount)

        var backwardSettings = skippedStore.snapshot.settings
        backwardSettings.manualTodayIso = "2026-07-20"
        skippedStore.updateSettings(backwardSettings)
        XCTAssertEqual(skippedStore.snapshot.transactions.count, transactionCount)
        XCTAssertEqual(skippedStore.snapshot.creditCardRepayments.count, repaymentCount)
        XCTAssertEqual(skippedStore.snapshot.settings.lastProcessedDateIso, "2026-08-05")
    }

    @MainActor
    func testRescheduledBankAccountBillRestoresBalanceUntilConfirmedDate() async {
        let settings = makeManualSettings(today: "2026-08-01")
        let account = makeBankAccount(id: "bank-main", openingBalancePence: 100_000)
        let payment = makeRecurringPayment(
            id: "rec-broadband",
            name: "Broadband",
            amountPence: 12_345,
            dueDay: 1,
            potId: nil,
            bankAccountId: account.id,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            bankAccounts: [account],
            recurringPayments: [payment]
        )))

        await store.load()
        XCTAssertEqual(PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot), 87_655)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)

        store.confirmRecurringBillOccurrence(
            paymentId: payment.id,
            scheduledDueDate: "2026-08-01",
            actualDueDate: "2026-08-03"
        )

        XCTAssertEqual(PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot), 100_000)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 0)

        var augustSecondSettings = store.snapshot.settings
        augustSecondSettings.manualTodayIso = "2026-08-02"
        store.updateSettings(augustSecondSettings)
        XCTAssertEqual(PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot), 100_000)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 0)

        var augustThirdSettings = store.snapshot.settings
        augustThirdSettings.manualTodayIso = "2026-08-03"
        store.updateSettings(augustThirdSettings)

        let activeTransaction = store.snapshot.transactions.first { $0.deletedAt == nil }
        XCTAssertEqual(activeTransaction?.date, "2026-08-03")
        XCTAssertEqual(activeTransaction?.bankAccountId, account.id)
        XCTAssertEqual(PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot), 87_655)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)
    }

    @MainActor
    func testLoadRepairsGeneratedBillTransactionLeftOnItsOldExpectedDate() async {
        let settings = makeManualSettings(today: "2026-08-01")
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 10_000, targetPence: nil)
        let payment = makeRecurringPayment(
            id: "rec-phone",
            name: "Phone",
            amountPence: 4_000,
            dueDay: 1,
            potId: pot.id,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let originalStore = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [payment]
        )))

        await originalStore.load()
        XCTAssertEqual(originalStore.snapshot.pots.first?.balancePence, 6_000)

        var staleSnapshot = originalStore.snapshot
        staleSnapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(
                id: "recurring-occurrence-override-rec-phone-2026-08-01",
                paymentId: payment.id,
                scheduledDueDate: "2026-08-01",
                state: .confirmed,
                actualDueDate: "2026-08-03",
                reversedGeneratedTransactionIds: [],
                createdAt: "2026-08-01T00:00:00.000Z",
                updatedAt: "2026-08-01T00:00:00.000Z",
                deletedAt: nil
            )
        ]
        let repairedStore = PlannerStore(repository: TestPlannerRepository(snapshot: staleSnapshot))

        await repairedStore.load()

        XCTAssertEqual(repairedStore.snapshot.pots.first?.balancePence, 10_000)
        XCTAssertEqual(repairedStore.snapshot.transactions.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(
            repairedStore.snapshot.recurringPaymentOccurrenceOverrides.first?.reversedGeneratedTransactionIds,
            ["recurring-rec-phone-2026-08-01"]
        )

        var augustThirdSettings = repairedStore.snapshot.settings
        augustThirdSettings.manualTodayIso = "2026-08-03"
        repairedStore.updateSettings(augustThirdSettings)

        let activeTransaction = repairedStore.snapshot.transactions.first { $0.deletedAt == nil }
        XCTAssertEqual(activeTransaction?.id, "recurring-rec-phone-2026-08-01")
        XCTAssertEqual(activeTransaction?.date, "2026-08-03")
        XCTAssertEqual(repairedStore.snapshot.pots.first?.balancePence, 6_000)
        XCTAssertEqual(repairedStore.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)
    }

    @MainActor
    func testHeldDirectDebitVoidsOnlyAutomaticRepaymentAndRestoresLinkedPot() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let card = makeCreditCard(
            id: "card-main",
            name: "Main Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-10",
            dueDay: 10,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Card pot", balancePence: 20_000, targetPence: nil, linkedCreditCardId: card.id)
        let transaction = makeTransaction(id: "charge", cardId: card.id, amountPence: 10_000, date: "2026-06-09", note: "Charge")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], transactions: [transaction], creditCards: [card])))

        await store.load()
        XCTAssertEqual(store.snapshot.creditCardRepayments.first?.amountPence, 10_000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10_000)

        store.markCreditCardDirectDebitAwaiting(cardId: card.id, scheduledStatementDate: "2026-06-10")
        XCTAssertEqual(store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 20_000)

        store.confirmCreditCardDirectDebit(cardId: card.id, scheduledStatementDate: "2026-06-10", actualDirectDebitDate: "2026-06-12")
        var laterSettings = store.snapshot.settings
        laterSettings.manualTodayIso = "2026-06-12"
        store.updateSettings(laterSettings)

        let activeRepayments = store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }
        XCTAssertEqual(activeRepayments.count, 1)
        XCTAssertEqual(activeRepayments.first?.directDebitDate, "2026-06-12")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10_000)
    }

    @MainActor
    func testRescheduledDirectDebitImmediatelyReversesAutomaticRepaymentUntilNewDate() async {
        let settings = makeManualSettings(today: "2026-08-01")
        let card = makeCreditCard(
            id: "card-capital-one",
            name: "Capital One",
            openingBalancePence: 20_237,
            openingStatementBalancePence: 20_237,
            statementDate: "2026-07-09",
            dueDay: 1,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-capital-one",
            name: "Capital One",
            balancePence: 20_237,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            creditCards: [card]
        )))

        await store.load()
        XCTAssertEqual(store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)

        store.confirmCreditCardDirectDebit(
            cardId: card.id,
            scheduledStatementDate: "2026-07-09",
            actualDirectDebitDate: "2026-08-03"
        )

        XCTAssertEqual(store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 20_237)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 20_237)

        var augustSecondSettings = store.snapshot.settings
        augustSecondSettings.manualTodayIso = "2026-08-02"
        store.updateSettings(augustSecondSettings)
        XCTAssertEqual(store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 20_237)

        var augustThirdSettings = store.snapshot.settings
        augustThirdSettings.manualTodayIso = "2026-08-03"
        store.updateSettings(augustThirdSettings)

        let activeRepayments = store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }
        XCTAssertEqual(activeRepayments.count, 1)
        XCTAssertEqual(activeRepayments.first?.directDebitDate, "2026-08-03")
        XCTAssertEqual(activeRepayments.first?.amountPence, 20_237)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)
    }

    @MainActor
    func testLoadRepairsAutomaticRepaymentLeftBehindByPreviouslyRescheduledDirectDebit() async {
        let settings = makeManualSettings(today: "2026-08-01")
        let card = makeCreditCard(
            id: "card-capital-one",
            name: "Capital One",
            openingBalancePence: 20_237,
            openingStatementBalancePence: 20_237,
            statementDate: "2026-07-09",
            dueDay: 1,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-capital-one",
            name: "Capital One",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let staleRepayment = CreditCardRepayment(
            id: "card-statement-repayment-card-capital-one-2026-07-09-2026-08-01",
            creditCardId: card.id,
            amountPence: 20_237,
            date: "2026-08-01",
            note: "Automatic Capital One statement payment from Capital One pot",
            statementDate: "2026-07-09",
            directDebitDate: "2026-08-01",
            source: .linkedPotStatement,
            potId: pot.id,
            potContributionPence: 20_237,
            potContributions: [CreditCardPotContribution(potId: pot.id, amountPence: 20_237)],
            paycheckContributionPence: 0,
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let cycleOverride = CreditCardCycleOverride(
            id: "card-cycle-override-card-capital-one-2026-07-09",
            creditCardId: card.id,
            scheduledStatementDate: "2026-07-09",
            statementState: .normal,
            actualStatementDate: nil,
            directDebitState: .confirmed,
            actualDirectDebitDate: "2026-08-03",
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            creditCards: [card],
            creditCardRepayments: [staleRepayment],
            creditCardCycleOverrides: [cycleOverride]
        )))

        await store.load()

        XCTAssertEqual(store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 20_237)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 20_237)
        XCTAssertEqual(store.snapshot.creditCardCycleOverrides.first?.reversedAutomaticRepaymentIds, [staleRepayment.id])

        var augustThirdSettings = store.snapshot.settings
        augustThirdSettings.manualTodayIso = "2026-08-03"
        store.updateSettings(augustThirdSettings)

        let activeRepayments = store.snapshot.creditCardRepayments.filter { $0.deletedAt == nil }
        XCTAssertEqual(activeRepayments.count, 1)
        XCTAssertEqual(activeRepayments.first?.directDebitDate, "2026-08-03")
        XCTAssertEqual(activeRepayments.first?.amountPence, 20_237)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)
    }

    @MainActor
    func testOpeningBalanceDueThisPaycheckAppearsWhenFuturePlannedPeriodExists() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let currentPeriod = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        var futurePeriod = makePayPeriod(id: "period-august", startDate: "2026-08-01", endDate: "2026-08-31", payday: "2026-08-01", incomePence: 100000)
        futurePeriod.status = .planned
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-07-01", dueDay: 2)
        let linkedPot = makePot(id: "pot-card", name: "Pot 1", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [linkedPot], payPeriods: [currentPeriod, futurePeriod], creditCards: [card])))

        await store.load()

        XCTAssertEqual(store.selectedPayPeriod?.id, currentPeriod.id)
        let items = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: store.selectedPayPeriod)
        XCTAssertEqual(items.map(\.id), ["card-opening-balance-funding-card-main-2026-07-02"])
        XCTAssertEqual(items.first?.amountPence, 50000)
        XCTAssertEqual(items.first?.potName, "Pot 1")
        XCTAssertEqual(items.first?.directDebitDate, "2026-07-02")
    }

    func testConfirmedBankCycleAmountsReconcileAquaAndJajaAcrossDerivedSurfaces() throws {
        let settings = makeManualSettings(today: "2026-08-08")
        let augustPeriod = makePayPeriod(
            id: "period-august",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 200_000
        )
        let aqua = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            limitPence: 130_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-03",
            dueDay: 20,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let jaja = makeCreditCard(
            id: "card-jaja",
            name: "Jaja",
            limitPence: 25_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-07",
            dueDay: 3,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let aquaPot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: aqua.id
        )
        let jajaPot = makePot(
            id: "pot-jaja",
            name: "Jaja",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: jaja.id
        )
        let aquaTransaction = makeTransaction(
            id: "transaction-aqua-tracked",
            cardId: aqua.id,
            amountPence: 8_216,
            date: "2026-08-02",
            note: "Tracked Aqua spending"
        )
        let jajaTransaction = makeTransaction(
            id: "transaction-jaja-tracked",
            cardId: jaja.id,
            amountPence: 129,
            date: "2026-08-06",
            note: "Tracked Jaja spending"
        )
        let aquaOverride = CreditCardCycleOverride(
            id: "override-aqua-2026-08-03",
            creditCardId: aqua.id,
            scheduledStatementDate: "2026-08-03",
            statementState: .normal,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 69_588,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-03T00:00:00.000Z",
            updatedAt: "2026-08-03T00:00:00.000Z",
            deletedAt: nil
        )
        let jajaOverride = CreditCardCycleOverride(
            id: "override-jaja-2026-08-07",
            creditCardId: jaja.id,
            scheduledStatementDate: "2026-08-07",
            statementState: .normal,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 2_428,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-07T00:00:00.000Z",
            updatedAt: "2026-08-07T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [aquaPot, jajaPot],
            payPeriods: [augustPeriod],
            transactions: [aquaTransaction, jajaTransaction],
            creditCards: [aqua, jaja],
            creditCardCycleOverrides: [aquaOverride, jajaOverride]
        )

        let summaries = PlannerDerivedData.creditCardStatementSummaries(
            snapshot: snapshot,
            asOfDate: "2026-08-08"
        )
        let aquaSummary = try XCTUnwrap(summaries.first { $0.cardId == aqua.id })
        let jajaSummary = try XCTUnwrap(summaries.first { $0.cardId == jaja.id })

        XCTAssertEqual(aquaSummary.scheduledStatementDate, "2026-08-03")
        XCTAssertEqual(aquaSummary.calculatedAmountPence, 8_216)
        XCTAssertEqual(aquaSummary.confirmedAmountPence, 69_588)
        XCTAssertEqual(aquaSummary.statementAmountPence, 69_588)
        XCTAssertEqual(aquaSummary.unpaidAmountPence, 69_588)
        XCTAssertEqual(aquaSummary.reconciliationAdjustmentPence, 61_372)
        XCTAssertEqual(aquaSummary.amountSource, .confirmedBankAmount)

        XCTAssertEqual(jajaSummary.scheduledStatementDate, "2026-08-07")
        XCTAssertEqual(jajaSummary.calculatedAmountPence, 129)
        XCTAssertEqual(jajaSummary.confirmedAmountPence, 2_428)
        XCTAssertEqual(jajaSummary.statementAmountPence, 2_428)
        XCTAssertEqual(jajaSummary.unpaidAmountPence, 2_428)
        XCTAssertEqual(jajaSummary.reconciliationAdjustmentPence, 2_299)
        XCTAssertEqual(jajaSummary.amountSource, .confirmedBankAmount)

        let aquaPayment = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementPayments(
                card: aqua,
                snapshot: snapshot,
                startDate: "2026-08-08",
                endDate: "2026-08-31",
                asOfDate: "2026-08-08"
            ).first
        )
        let jajaPayment = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementPayments(
                card: jaja,
                snapshot: snapshot,
                startDate: "2026-08-08",
                endDate: "2026-09-30",
                asOfDate: "2026-08-08"
            ).first
        )
        XCTAssertEqual(aquaPayment.actualDuePence, 69_588)
        XCTAssertEqual(aquaPayment.forecastDuePence, 69_588)
        XCTAssertEqual(aquaPayment.amountSource, .confirmedBankAmount)
        XCTAssertEqual(jajaPayment.actualDuePence, 2_428)
        XCTAssertEqual(jajaPayment.forecastDuePence, 2_428)
        XCTAssertEqual(jajaPayment.amountSource, .confirmedBankAmount)

        XCTAssertEqual(
            PlannerDerivedData.potProgress(
                pot: aquaPot,
                snapshot: snapshot,
                today: "2026-08-08"
            ).linkedCardPayments.first?.amountPence,
            69_588
        )
        let aquaFunding = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: augustPeriod,
            asOfDate: "2026-08-08",
            groupByFundingDueDate: true
        )
        .filter { item in
            switch item.action {
            case .cardSpend(let transactionId, _):
                transactionId == aquaTransaction.id
            case .cardPayment(let cardId, _, _, _):
                cardId == aqua.id
            default:
                false
            }
        }
        XCTAssertEqual(aquaFunding.reduce(0) { $0 + $1.amountPence }, 69_588)

        let aquaDueEvent = PlannerDerivedData.homeDueEvents(
            snapshot: snapshot,
            asOfDate: "2026-08-20"
        ).first { event in
            if case .cardDirectDebit(let cardId, _) = event.source {
                return cardId == aqua.id
            }
            return false
        }
        let jajaDueEvent = PlannerDerivedData.homeDueEvents(
            snapshot: snapshot,
            asOfDate: "2026-09-03"
        ).first { event in
            if case .cardDirectDebit(let cardId, _) = event.source {
                return cardId == jaja.id
            }
            return false
        }
        XCTAssertEqual(aquaDueEvent?.amountPence, 69_588)
        XCTAssertEqual(jajaDueEvent?.amountPence, 2_428)
    }

    @MainActor
    func testConfirmedBankCycleBelowTrackedTransactionsPaysOnlyConfirmedAmount() throws {
        let settings = makeManualSettings(today: "2026-08-20")
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-03",
            dueDay: 20,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let trackedSpend = makeTransaction(
            id: "transaction-aqua-tracked",
            cardId: card.id,
            amountPence: 5_000,
            date: "2026-08-02",
            note: "Tracked Aqua spending"
        )
        let cycleOverride = CreditCardCycleOverride(
            id: "override-aqua-2026-08-03",
            creditCardId: card.id,
            scheduledStatementDate: "2026-08-03",
            statementState: .normal,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 3_000,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-03T00:00:00.000Z",
            updatedAt: "2026-08-03T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            transactions: [trackedSpend],
            creditCards: [card],
            creditCardCycleOverrides: [cycleOverride]
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)

        let beforeSummary = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementSummaries(
                snapshot: snapshot,
                asOfDate: "2026-08-20"
            ).first
        )
        XCTAssertEqual(beforeSummary.calculatedAmountPence, 5_000)
        XCTAssertEqual(beforeSummary.statementAmountPence, 3_000)
        XCTAssertEqual(beforeSummary.reconciliationAdjustmentPence, -2_000)

        XCTAssertTrue(store.applyDueCreditCardPaymentsForSimulation(asOf: "2026-08-20"))
        let repayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first)
        XCTAssertEqual(repayment.amountPence, 3_000)
        XCTAssertEqual(repayment.paycheckContributionPence, 3_000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 2_000)
    }

    func testPlannedCostsAddEveryCurrentCycleOutgoingAndProjectedEndSubtractsThatExactTotal() {
        let period = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100_000
        )
        let directBill = makeRecurringPayment(
            id: "direct-bill",
            name: "Direct bill",
            amountPence: 1_000,
            dueDay: 10,
            potId: nil
        )
        let cardBill = makeRecurringPayment(
            id: "card-bill",
            name: "Card bill",
            amountPence: 2_000,
            dueDay: 11,
            potId: nil,
            creditCardId: "card"
        )
        let savedPayment = CustomPayment(
            id: "saved",
            name: "Saved payment",
            amountPence: 3_000,
            dueDate: "2026-07-12",
            creditCardId: nil,
            status: .unpaid,
            createdAt: "2026-07-01",
            updatedAt: "2026-07-01",
            deletedAt: nil
        )
        let cashSpend = Transaction(
            id: "cash-spend",
            potId: nil,
            payPeriodId: period.id,
            amountPence: 4_000,
            type: .spending,
            paymentMethod: .income,
            creditCardId: nil,
            recurringPaymentId: nil,
            date: "2026-07-13",
            note: "Cash spend",
            createdAt: "2026-07-13",
            updatedAt: "2026-07-13",
            deletedAt: nil
        )
        let cardSpend = Transaction(
            id: "card-spend",
            potId: nil,
            payPeriodId: period.id,
            amountPence: 5_000,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: "card",
            recurringPaymentId: nil,
            date: "2026-07-14",
            note: "Card spend",
            createdAt: "2026-07-14",
            updatedAt: "2026-07-14",
            deletedAt: nil
        )
        let allocation = makePotAllocation(
            id: "allocation",
            payPeriodId: period.id,
            potId: "pot",
            amountPence: 6_000,
            source: .manual,
            recurringPaymentId: nil,
            recurringDueDate: nil
        )
        let snapshot = makeSnapshot(
            recurringPayments: [directBill, cardBill],
            payPeriods: [period],
            potAllocations: [allocation],
            transactions: [cashSpend, cardSpend],
            customPayments: [savedPayment]
        )

        let summary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: period,
            asOfDate: "2026-07-15"
        )

        XCTAssertEqual(summary.items.map(\.amountPence).reduce(0, +), 21_000)
        XCTAssertEqual(
            PlannerDerivedData.currentCycleOutgoingsPence(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: "2026-07-15"
            ),
            15_000
        )
        XCTAssertEqual(summary.projectedCostsPence, 15_000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, 85_000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, summary.payReceivedPence - summary.projectedCostsPence)
        XCTAssertEqual(summary.projectedCostsPence, summary.totalCostsPence + 1_000)
    }
}
