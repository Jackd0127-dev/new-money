import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    @MainActor
    func testFundingAPotMovesMoneyOutOfItsLinkedBankAccountOnlyOnce() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(
            id: "period-june",
            startDate: "2026-06-01",
            endDate: "2026-06-30",
            payday: "2026-06-01",
            incomePence: 0
        )
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
            pots: [pot],
            payPeriods: [period]
        )))
        await store.load()

        XCTAssertTrue(store.addPotAllocation(potId: pot.id, amountPence: 25_000))
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 25_000)
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            75_000
        )

        let allocation = try! XCTUnwrap(store.snapshot.potAllocations.first)
        XCTAssertEqual(allocation.bankAccountId, account.id)
        XCTAssertTrue(store.deleteManualPotAllocation(id: allocation.id))
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            100_000
        )
    }

    @MainActor
    func testIncomeFundedSpendReducesMoneyLeftWithoutChangingPotsOrCreditCards() async throws {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 100000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, payPeriods: [period])))
        await store.load()

        store.recordTransaction(
            potId: nil,
            creditCardId: nil,
            paymentMethod: .income,
            amountPence: 5000,
            type: .spending,
            date: "2026-06-10",
            note: "Groceries"
        )

        let transaction = try XCTUnwrap(store.snapshot.transactions.first)
        XCTAssertEqual(transaction.paymentMethod, .income)
        XCTAssertNil(transaction.potId)
        XCTAssertNil(transaction.creditCardId)

        var summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(summary.manualSpendingPence, 5000)
        XCTAssertEqual(summary.currentMoneyLeftPence, 95000)

        store.updateTransaction(
            id: transaction.id,
            potId: nil,
            creditCardId: nil,
            paymentMethod: .income,
            amountPence: 7500,
            date: "2026-06-10",
            note: "Groceries"
        )

        summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(summary.manualSpendingPence, 7500)
        XCTAssertEqual(summary.currentMoneyLeftPence, 92500)
        XCTAssertTrue(store.snapshot.pots.isEmpty)
        XCTAssertTrue(store.snapshot.creditCards.isEmpty)
    }

    func testChargedLinkedCardRecurringBillStaysInFundingChecklistUntilPotIsFunded() {
        let settings = makeManualSettings(today: "2026-07-11")
        let period = makePayPeriod(
            id: "period-august",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 100000
        )
        let zablePot = makePot(
            id: "pot-zable",
            name: "Zable",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: "card-zable"
        )
        let zableCard = makeCreditCard(
            id: "card-zable",
            name: "Zable",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-20",
            dueDay: 3
        )
        let bill = makeRecurringPayment(
            id: "bill-zable-11th",
            name: "Monthly bill",
            amountPence: 2212,
            dueDay: 11,
            potId: zablePot.id,
            creditCardId: zableCard.id,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let chargedBill = Transaction(
            id: "charge-zable-11th",
            potId: zablePot.id,
            payPeriodId: nil,
            amountPence: 2212,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: zableCard.id,
            recurringPaymentId: bill.id,
            date: "2026-07-11",
            note: bill.name,
            createdAt: "2026-07-11T12:00:00.000Z",
            updatedAt: "2026-07-11T12:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [zablePot],
            recurringPayments: [bill],
            payPeriods: [period],
            transactions: [chargedBill],
            creditCards: [zableCard]
        )

        let checklistItem = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: "2026-07-11",
                groupByFundingDueDate: true
            )
            .first { $0.name == bill.name }
        )
        XCTAssertFalse(checklistItem.isCompleted)
        XCTAssertEqual(checklistItem.status, .needsFunding)
        XCTAssertNil(checklistItem.paidDate)
        XCTAssertEqual(checklistItem.amountPence, 2212)
        XCTAssertEqual(checklistItem.destinationKind, .pot)
        XCTAssertEqual(checklistItem.destinationId, zablePot.id)
        XCTAssertEqual(checklistItem.destinationName, zablePot.name)
    }

    func testFundingChecklistGroupsPaymentsByStableDestinationAndTotalsThem() throws {
        let jajaItems = [
            makeFundingPresentationItem(
                id: "jaja-streaming",
                name: "Streaming",
                destinationId: "pot-jaja",
                destinationName: "Jaja",
                amountPence: 599,
                dueDate: "2026-08-12",
                action: .recurringBill(paymentId: "bill-streaming", dueDate: "2026-08-12", payPeriodId: "period-august")
            ),
            makeFundingPresentationItem(
                id: "jaja-cloud",
                name: "Cloud storage",
                destinationId: "pot-jaja",
                destinationName: "Jaja",
                amountPence: 129,
                dueDate: "2026-08-02",
                action: .recurringBill(paymentId: "bill-cloud", dueDate: "2026-08-02", payPeriodId: "period-august")
            ),
            makeFundingPresentationItem(
                id: "jaja-coffee",
                name: "Coffee",
                destinationId: "pot-jaja",
                destinationName: "Jaja",
                amountPence: 235,
                dueDate: "2026-08-08",
                action: .cardSpend(transactionId: "spend-coffee", payPeriodId: "period-august")
            )
        ]
        let holidayItem = makeFundingPresentationItem(
            id: "holiday-hotel",
            name: "Hotel",
            destinationId: "pot-holiday",
            destinationName: "Holiday",
            amountPence: 10_000,
            dueDate: "2026-08-20",
            action: .debt(debtId: "debt-hotel", dueDate: "2026-08-20", payPeriodId: "period-august")
        )

        let groups = PlannerDerivedData.fundingChecklistDestinationGroups(
            items: [holidayItem] + jajaItems
        )
        let jaja = try XCTUnwrap(groups.first { $0.destinationId == "pot-jaja" })

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(jaja.destinationName, "Jaja")
        XCTAssertEqual(jaja.totalAmountPence, 963)
        XCTAssertEqual(jaja.items.map(\.name), ["Cloud storage", "Coffee", "Streaming"])
        XCTAssertEqual(jaja.items.map(\.action), [
            .recurringBill(paymentId: "bill-cloud", dueDate: "2026-08-02", payPeriodId: "period-august"),
            .cardSpend(transactionId: "spend-coffee", payPeriodId: "period-august"),
            .recurringBill(paymentId: "bill-streaming", dueDate: "2026-08-12", payPeriodId: "period-august")
        ])
        XCTAssertTrue(jaja.items[0].supportsCycleAdjustment)
        XCTAssertFalse(jaja.items[1].supportsCycleAdjustment)
    }

    func testFundingChecklistDoesNotMergeDifferentPotsWithTheSameName() {
        let first = makeFundingPresentationItem(
            id: "first",
            name: "First payment",
            destinationId: "pot-one",
            destinationName: "Everyday",
            amountPence: 100,
            dueDate: "2026-08-01",
            action: .cardSpend(transactionId: "spend-one", payPeriodId: "period-august")
        )
        let second = makeFundingPresentationItem(
            id: "second",
            name: "Second payment",
            destinationId: "pot-two",
            destinationName: "Everyday",
            amountPence: 200,
            dueDate: "2026-08-02",
            action: .cardSpend(transactionId: "spend-two", payPeriodId: "period-august")
        )

        let groups = PlannerDerivedData.fundingChecklistDestinationGroups(items: [first, second])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.destinationId)), ["pot-one", "pot-two"])
        XCTAssertEqual(groups.map(\.totalAmountPence).sorted(), [100, 200])
    }

    func testFundingDestinationGroupReportsPartialAndFullyAddedProgress() {
        func item(id: String, isCompleted: Bool) -> FundingChecklistPresentationItem {
            FundingChecklistPresentationItem(
                id: id,
                name: "Bill \(id)",
                destinationKind: .pot,
                destinationId: "pot-bills",
                destinationName: "Bills",
                title: "Fund bill",
                detail: "",
                amountPence: 1_000,
                dueDate: "2026-06-20",
                breakdown: [],
                isCompleted: isCompleted,
                isExcluded: false,
                status: isCompleted ? .activeReserved : .needsFunding,
                paidDate: nil,
                action: .recurringBill(paymentId: id, dueDate: "2026-06-20", payPeriodId: "period-june")
            )
        }

        var group = FundingChecklistDestinationGroup(
            id: "pot-bills",
            destinationKind: .pot,
            destinationId: "pot-bills",
            destinationName: "Bills",
            items: (1...7).map { item(id: "\($0)", isCompleted: $0 <= 4) }
        )

        XCTAssertEqual(group.completedItemCount, 4)
        XCTAssertEqual(group.fundingStatusLabel, "4/7")
        XCTAssertFalse(group.isFullyAdded)

        group.items = group.items.map { existing in
            item(id: existing.id, isCompleted: true)
        }
        XCTAssertEqual(group.fundingStatusLabel, "Added")
        XCTAssertTrue(group.isFullyAdded)
        XCTAssertTrue(group.items.allSatisfy { $0.status == .activeReserved })
    }

    func testCashDueGroupingRecognizesLegacyCardFundingAndExclusion() {
        let settings = makeManualSettings(today: "2026-07-21")
        let july = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        let august = makePayPeriod(
            id: "period-august",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 100000
        )
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
            balancePence: 2500,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let bill = makeRecurringPayment(
            id: "bill-phone",
            name: "Phone",
            amountPence: 2500,
            dueDay: 21,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        var allocation = makePotAllocation(
            id: "legacy-phone-funding",
            payPeriodId: july.id,
            potId: pot.id,
            amountPence: 2500,
            source: .recurringBillFunding,
            recurringPaymentId: bill.id,
            recurringDueDate: "2026-07-21"
        )
        allocation.creditCardId = card.id
        let exclusion = FundingChecklistExclusion(
            id: "legacy-phone-exclusion",
            kind: .cardBill,
            sourceId: bill.id,
            occurrenceDate: "2026-07-21",
            payPeriodId: july.id,
            createdAt: "2026-07-21T00:00:00.000Z",
            updatedAt: "2026-07-21T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [bill],
            payPeriods: [july, august],
            potAllocations: [allocation],
            creditCards: [card],
            fundingChecklistExclusions: [exclusion]
        )

        let julyItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: july,
            asOfDate: "2026-07-21",
            groupByFundingDueDate: true
        )
        let augustItem = try! XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: august,
            asOfDate: "2026-08-01",
            groupByFundingDueDate: true
        ).first { $0.name == bill.name })

        XCTAssertTrue(julyItems.isEmpty)
        XCTAssertEqual(augustItem.dueDate, "2026-08-05")
        XCTAssertTrue(augustItem.isCompleted)
        XCTAssertTrue(augustItem.isExcluded)
        XCTAssertEqual(snapshot.potAllocations.first?.payPeriodId, july.id)
        XCTAssertEqual(snapshot.fundingChecklistExclusions.first?.payPeriodId, july.id)
        XCTAssertEqual(snapshot.pots.first?.balancePence, 2500)
    }

    func testCardPaymentFundingBreakdownListsEveryStatementCharge() {
        let settings = makeManualSettings(today: "2026-07-10")
        let period = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        let card = makeCreditCard(
            id: "card-main",
            name: "Card 1",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-05",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Card 1", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let coffee = Transaction(
            id: "coffee",
            potId: nil,
            payPeriodId: nil,
            amountPence: 450,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: nil,
            date: "2026-06-12",
            note: "Coffee",
            createdAt: "2026-06-12T12:00:00.000Z",
            updatedAt: "2026-06-12T12:00:00.000Z",
            deletedAt: nil
        )
        let groceries = Transaction(
            id: "groceries",
            potId: nil,
            payPeriodId: nil,
            amountPence: 8250,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: nil,
            date: "2026-06-28",
            note: "Groceries",
            createdAt: "2026-06-28T12:00:00.000Z",
            updatedAt: "2026-06-28T12:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            transactions: [coffee, groceries],
            creditCards: [card]
        )

        let item = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: "2026-07-10"
            )
            .first {
                if case .cardPayment = $0.action { return true }
                return false
            }
        )

        XCTAssertEqual(item.title, "Add £87.00 to Card 1")
        XCTAssertEqual(item.breakdown.map(\.title), ["Coffee", "Groceries"])
        XCTAssertEqual(item.breakdown.map(\.amountPence), [450, 8250])
        XCTAssertTrue(item.breakdown.allSatisfy { !$0.detail.isEmpty })
    }

    func testAwaitingCardStatementDoesNotPullLaterChargesIntoAnEarlierFundingPeriod() {
        let settings = makeManualSettings(today: "2026-08-02")
        let julyToAugust = makePayPeriod(
            id: "period-july-august",
            startDate: "2026-07-31",
            endDate: "2026-08-30",
            payday: "2026-07-31",
            incomePence: 100000
        )
        let augustToSeptember = makePayPeriod(
            id: "period-august-september",
            startDate: "2026-08-31",
            endDate: "2026-09-30",
            payday: "2026-08-31",
            incomePence: 100000
        )
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-31",
            dueDay: 20,
            createdAt: "2026-07-01T08:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let amazonShop = makeTransaction(
            id: "transaction-amazon-shop",
            cardId: card.id,
            amountPence: 7767,
            date: "2026-07-31",
            note: "Amazon shop spend"
        )
        let chatGPT = makeRecurringPayment(
            id: "bill-chatgpt",
            name: "ChatGPT bill",
            amountPence: 20000,
            dueDay: 21,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let mma = makeRecurringPayment(
            id: "bill-mma",
            name: "MMA bill",
            amountPence: 6000,
            dueDay: 24,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let awaitingStatement = CreditCardCycleOverride(
            id: "card-aqua-cycle-2026-07-31",
            creditCardId: card.id,
            scheduledStatementDate: "2026-07-31",
            statementState: .awaitingConfirmation,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-02T00:00:00.000Z",
            updatedAt: "2026-08-02T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [chatGPT, mma],
            payPeriods: [julyToAugust, augustToSeptember],
            transactions: [amazonShop],
            creditCards: [card],
            creditCardCycleOverrides: [awaitingStatement]
        )

        let currentItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: julyToAugust,
            asOfDate: "2026-08-02",
            groupByFundingDueDate: true
        )
        let nextItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: augustToSeptember,
            asOfDate: "2026-08-31",
            groupByFundingDueDate: true
        )

        XCTAssertTrue(currentItems.contains { $0.name == "Amazon shop spend" && $0.dueDate == "2026-08-20" })
        XCTAssertFalse(currentItems.contains { $0.name == chatGPT.name || $0.name == mma.name })
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: nextItems
                .filter { $0.name == chatGPT.name || $0.name == mma.name }
                .map { ($0.name, $0.dueDate) }),
            [chatGPT.name: "2026-09-20", mma.name: "2026-09-20"]
        )
    }

    func testProjectedFundingPeriodsKeepAThirtyFirstAnchorAcrossShortMonths() {
        var july = makePayPeriod(
            id: "period-july-31",
            startDate: "2026-07-31",
            endDate: "2026-08-30",
            payday: "2026-07-31",
            incomePence: 100000
        )
        july.payFrequency = .monthly
        july.monthlyAnchorDay = 31
        let snapshot = makeSnapshot(payPeriods: [july])

        let periods = PlannerDerivedData.projectedFundingPayPeriods(
            snapshot: snapshot,
            startingAt: july,
            count: 4
        )

        XCTAssertEqual(periods.map(\.startDate), ["2026-07-31", "2026-08-31", "2026-09-30", "2026-10-31"])
        XCTAssertEqual(periods.map(\.endDate), ["2026-08-30", "2026-09-29", "2026-10-30", "2026-11-29"])
        XCTAssertEqual(periods.map(\.monthlyAnchorDay), [31, 31, 31, 31])
    }

    func testLinkedCreditCardPotTargetsOnlyTheNextRealStatementPayment() {
        let settings = makeManualSettings(today: "2026-08-01")
        let julyPeriod = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let augustPeriod = makePayPeriod(id: "period-august", startDate: "2026-08-01", endDate: "2026-08-31", payday: "2026-08-01", incomePence: 100000)
        let card = makeCreditCard(
            id: "card-cc2",
            name: "CC2",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-15",
            dueDay: 10,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-cc2", name: "Pot 2", balancePence: 3300, targetPence: nil, linkedCreditCardId: card.id)
        var insurance = makeTransaction(id: "card-recurring-rec-insurance-2026-07-01", cardId: card.id, amountPence: 10000, date: "2026-07-01", note: "Insurance")
        insurance.potId = pot.id
        insurance.recurringPaymentId = "rec-insurance"
        let manualSpend = makeTransaction(id: "txn-cc2-manual-2026-07-25", cardId: card.id, amountPence: 3300, date: "2026-07-25", note: "Manual CC2 spend")
        let insuranceAllocation = makePotAllocation(
            id: "alloc-insurance-july",
            payPeriodId: julyPeriod.id,
            potId: pot.id,
            amountPence: 10000,
            recurringPaymentId: "rec-insurance",
            recurringDueDate: "2026-07-01"
        )
        let futureRecurringCharge = makeRecurringPayment(
            id: "future-card-bill",
            name: "Later card bill",
            amountPence: 42_503,
            dueDay: 20,
            potId: pot.id,
            creditCardId: card.id
        )
        let futureRecurringAllocation = makePotAllocation(
            id: "alloc-future-card-bill",
            payPeriodId: augustPeriod.id,
            potId: pot.id,
            amountPence: 42_503,
            source: .recurringBillFunding,
            recurringPaymentId: futureRecurringCharge.id,
            recurringDueDate: "2026-08-20"
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [futureRecurringCharge],
            payPeriods: [julyPeriod, augustPeriod],
            potAllocations: [insuranceAllocation, futureRecurringAllocation],
            transactions: [insurance, manualSpend],
            creditCards: [card]
        )

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-08-01")

        XCTAssertEqual(progress.targetPence, 10000)
        XCTAssertEqual(progress.coveredPence, 3300)
        XCTAssertEqual(progress.shortfallPence, 6700)
        XCTAssertEqual(progress.percent, 33)
        XCTAssertFalse(progress.usesForecastTarget)
        XCTAssertEqual(progress.linkedCardPayments.map(\.dueIso), ["2026-08-10", "2026-09-10"])
        XCTAssertEqual(progress.linkedCardPayments.map(\.amountPence), [10000, 3300])
        XCTAssertEqual(progress.linkedCardPayments.map(\.statementIso), ["2026-07-15", "2026-08-15"])
    }

    func testLinkedCreditCardPotWithoutPostedPaymentDoesNotFallBackToManualTarget() {
        let card = makeCreditCard(
            id: "card-no-statement",
            name: "No statement",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-15",
            dueDay: 10,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-no-statement",
            name: "No statement",
            balancePence: 0,
            targetPence: 25_000,
            linkedCreditCardId: card.id
        )
        let snapshot = makeSnapshot(pots: [pot], creditCards: [card])

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-08-01")

        XCTAssertEqual(progress.targetPence, 0)
        XCTAssertEqual(progress.shortfallPence, 0)
        XCTAssertTrue(progress.linkedCardPayments.isEmpty)
    }

    @MainActor
    func testFundedLinkedCardSpendKeepsPotTargetUntilStatementRepaymentClears() async throws {
        let settings = makeManualSettings(today: "2026-07-25")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Main Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-15",
            dueDay: 10,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 1500, targetPence: nil, linkedCreditCardId: card.id)
        let spend = makeTransaction(id: "txn-manual-card-spend", cardId: card.id, amountPence: 6500, date: "2026-07-25", note: "Manual card spend")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], transactions: [spend], creditCards: [card])))

        await store.load()

        var progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first), snapshot: store.snapshot, today: "2026-07-25")
        XCTAssertEqual(progress.targetPence, 6500)
        XCTAssertEqual(progress.shortfallPence, 5000)

        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))

        progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first), snapshot: store.snapshot, today: "2026-07-25")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 6500)
        XCTAssertEqual(progress.targetPence, 6500)
        XCTAssertEqual(progress.coveredPence, 6500)
        XCTAssertEqual(progress.shortfallPence, 0)
        XCTAssertEqual(progress.percent, 100)

        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-09-10"
        store.updateSettings(dueSettings)

        progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first), snapshot: store.snapshot, today: "2026-09-10")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(progress.targetPence, 0)
    }

    @MainActor
    func testFundingSameDayCardBillAfterItPostedKeepsPotReserveAndTagsTransactionOnce() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 50000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Card 1",
            limitPence: 50000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-05",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Pot 1", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let bill = makeRecurringPayment(
            id: "rec-bill",
            name: "Bill 1",
            amountPence: 10000,
            dueDay: 1,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-06-30T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [bill], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-2026-07-01" }?.potId, nil)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: bill.id, dueDate: "2026-07-01", payPeriodId: period.id, completed: true))

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-2026-07-01" }?.potId, pot.id)
        XCTAssertEqual(store.snapshot.potAllocations.first?.userConfirmed, true)
        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.potAllocationsPence, 10000)
        XCTAssertEqual(summary.totalCostsPence, 10000)
        XCTAssertEqual(summary.moneyLeftPence, 40000)

        let fundedChecklistItem = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: "2026-07-01"
            )
            .first { $0.name == bill.name }
        )
        XCTAssertTrue(fundedChecklistItem.isCompleted)
        XCTAssertEqual(fundedChecklistItem.status, .activeReserved)
        XCTAssertNil(fundedChecklistItem.paidDate)

        var settledSnapshot = store.snapshot
        settledSnapshot.creditCardRepayments.append(
            CreditCardRepayment(
                id: "repayment-card-main-2026-08-01",
                creditCardId: card.id,
                amountPence: 10000,
                date: "2026-08-01",
                note: "Card 1 statement payment",
                statementDate: "2026-07-05",
                directDebitDate: "2026-08-01",
                source: .linkedPotStatement,
                potId: pot.id,
                potContributionPence: 10000,
                paycheckContributionPence: 0,
                createdAt: "2026-08-01T00:00:00.000Z",
                updatedAt: "2026-08-01T00:00:00.000Z",
                deletedAt: nil
            )
        )
        let settledChecklistItem = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: settledSnapshot,
                payPeriod: period,
                asOfDate: "2026-08-01"
            )
            .first { $0.name == bill.name }
        )
        XCTAssertEqual(settledChecklistItem.status, .paidCompleted)
        XCTAssertEqual(settledChecklistItem.paidDate, "2026-08-01")

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-bill-2026-07-01" }.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)

        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: bill.id, dueDate: "2026-07-01", payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-2026-07-01" }?.potId)
        let checklistItem = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: "2026-07-01"
            )
            .first { $0.name == bill.name }
        )
        XCTAssertFalse(checklistItem.isCompleted)
        XCTAssertEqual(checklistItem.status, .needsFunding)
        XCTAssertNil(checklistItem.paidDate)
    }

    func testPotProgressUsesLinkedRecurringBillTarget() {
        let pot = makePot(id: "pot-car", name: "Car Insurance", balancePence: 8711, targetPence: nil)
        let payment = makeRecurringPayment(id: "rec-car", name: "Car insurance", amountPence: 8711, dueDay: 9, potId: pot.id)
        let snapshot = makeSnapshot(pots: [pot], recurringPayments: [payment])

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-06-01")

        XCTAssertEqual(progress.targetPence, 8711)
        XCTAssertEqual(progress.coveredPence, 8711)
        XCTAssertEqual(progress.percent, 100)
        XCTAssertEqual(progress.sourceLabels, ["Recurring"])
        XCTAssertEqual(progress.dueIso, "2026-06-09")
    }

    func testPotProgressSumsMultipleLinkedRecurringBills() {
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 15000, targetPence: nil)
        let payments = [
            makeRecurringPayment(id: "rec-one", name: "One", amountPence: 10000, dueDay: 5, potId: pot.id),
            makeRecurringPayment(id: "rec-two", name: "Two", amountPence: 12000, dueDay: 9, potId: pot.id),
            makeRecurringPayment(id: "rec-three", name: "Three", amountPence: 8000, dueDay: 12, potId: pot.id),
        ]
        let snapshot = makeSnapshot(pots: [pot], recurringPayments: payments)

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-06-01")

        XCTAssertEqual(progress.targetPence, 30000)
        XCTAssertEqual(progress.percent, 50)
        XCTAssertEqual(progress.shortfallPence, 15000)
    }

    func testPotProgressFallsBackToManualTargetAndCapsReachedProgressAtOneHundredPercent() {
        let pot = makePot(id: "pot-holiday", name: "Holiday", balancePence: 15000, targetPence: 10000)
        let snapshot = makeSnapshot(pots: [pot])

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-06-01")

        XCTAssertEqual(progress.targetPence, 10000)
        XCTAssertEqual(progress.percent, 100)
        XCTAssertEqual(progress.sourceLabels, [])
    }

    @MainActor
    func testDueLinkedRecurringBillDeductsFromPotOnce() async {
        let settings = makeManualSettings(today: "2026-06-09")
        let pot = makePot(id: "pot-car", name: "Car Insurance", balancePence: 8711, targetPence: nil)
        let payment = makeRecurringPayment(id: "rec-car", name: "Car insurance", amountPence: 8711, dueDay: 9, potId: pot.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment])))

        await store.load()
        let transaction = store.snapshot.transactions.first

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(transaction?.id, "recurring-rec-car-2026-06-09")
        XCTAssertEqual(transaction?.amountPence, 8711)
        XCTAssertEqual(transaction?.date, "2026-06-09")
        XCTAssertEqual(transaction?.note, "Car insurance")
        XCTAssertEqual(transaction?.paymentMethod, .pot)
        XCTAssertEqual(transaction?.potId, pot.id)
        XCTAssertEqual(transaction?.recurringPaymentId, payment.id)
        XCTAssertEqual(transaction?.type, .spending)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-09"))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.recurringPaymentId == payment.id }.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testManualDateChangeTriggersLinkedRecurringBillDeduction() async {
        let settings = makeManualSettings(today: "2026-06-08")
        let pot = makePot(id: "pot-car", name: "Car Insurance", balancePence: 8711, targetPence: nil)
        let payment = makeRecurringPayment(id: "rec-car", name: "Car insurance", amountPence: 8711, dueDay: 9, potId: pot.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment])))

        await store.load()
        XCTAssertEqual(store.snapshot.transactions.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 8711)

        var updatedSettings = store.snapshot.settings
        updatedSettings.manualTodayIso = "2026-06-09"
        store.updateSettings(updatedSettings)

        XCTAssertEqual(store.snapshot.transactions.first?.id, "recurring-rec-car-2026-06-09")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testHeldRecurringPotBillRestoresPotThenSettlesOnConfirmedActualDate() async {
        let settings = makeManualSettings(today: "2026-06-15")
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 10_000, targetPence: nil)
        let payment = makeRecurringPayment(id: "rec-phone", name: "Phone", amountPence: 4_000, dueDay: 15, potId: pot.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment])))

        await store.load()
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 6_000)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)

        store.confirmRecurringBillOccurrence(
            paymentId: payment.id,
            scheduledDueDate: "2026-06-15",
            actualDueDate: "2026-06-18"
        )
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10_000)
        XCTAssertTrue(store.snapshot.transactions.first?.deletedAt != nil)

        var laterSettings = store.snapshot.settings
        laterSettings.manualTodayIso = "2026-06-19"
        store.updateSettings(laterSettings)

        let activeTransaction = store.snapshot.transactions.first { $0.deletedAt == nil }
        XCTAssertEqual(activeTransaction?.id, "recurring-rec-phone-2026-06-15")
        XCTAssertEqual(activeTransaction?.date, "2026-06-18")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 6_000)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)
    }

    func testFundingChecklistDoesNotAddOrphanedOpeningStatementToCardDestination() throws {
        let period = makePayPeriod(
            id: "period-capital-two",
            startDate: "2026-08-10",
            endDate: "2026-09-09",
            payday: "2026-08-10",
            incomePence: 200_000
        )
        let card = makeCreditCard(
            id: "card-capital-two",
            name: "Capital two",
            limitPence: 100_000,
            openingBalancePence: 0,
            openingStatementBalancePence: 80_000,
            statementDate: "2026-09-01",
            dueDay: 5,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-capital-two",
            name: "Capital two",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let chatGPT = makeRecurringPayment(
            id: "bill-chatgpt",
            name: "ChatGPT",
            amountPence: 20_000,
            dueDay: 21,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        var chatGPTCharge = makeTransaction(
            id: "capital-two-chatgpt",
            cardId: card.id,
            amountPence: 20_000,
            date: "2026-08-21",
            note: "ChatGPT"
        )
        chatGPTCharge.recurringPaymentId = chatGPT.id
        let tescoCharge = makeTransaction(
            id: "capital-two-tesco",
            cardId: card.id,
            amountPence: 8_623,
            date: "2026-08-22",
            note: "Tesco"
        )
        let snapshot = makeSnapshot(
            settings: makeManualSettings(today: "2026-08-29"),
            pots: [pot],
            recurringPayments: [chatGPT],
            payPeriods: [period],
            transactions: [chatGPTCharge, tescoCharge],
            creditCards: [card]
        )

        let group = try XCTUnwrap(
            PlannerDerivedData.fundingChecklistDestinationGroups(
                items: PlannerDerivedData.fundingChecklistPresentationItems(
                    snapshot: snapshot,
                    payPeriod: period,
                    asOfDate: "2026-08-29",
                    groupByFundingDueDate: true
                )
            ).first { $0.destinationId == pot.id }
        )

        XCTAssertEqual(group.totalAmountPence, 28_623)
        XCTAssertEqual(group.items.count, 2)
        XCTAssertFalse(group.items.contains { item in
            if case .cardPayment = item.action { return true }
            return false
        })
    }

    func testCardBillFundingChecklistDerivesOnlyCardPotBillsInCurrentPayPeriod() {
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 200000)
        let card = makeCreditCard(id: "card-main", name: "Main Card", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: nil, dueDay: 1)
        let linkedPot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let regularPot = makePot(id: "pot-regular", name: "Bills", balancePence: 0, targetPence: nil)
        let eligible = makeRecurringPayment(id: "rec-chatgpt", name: "ChatGPT", amountPence: 10000, dueDay: 10, potId: linkedPot.id, creditCardId: card.id)
        let cardOnly = makeRecurringPayment(id: "rec-card-only", name: "Card only", amountPence: 2000, dueDay: 11, potId: nil, creditCardId: card.id)
        let potOnly = makeRecurringPayment(id: "rec-pot-only", name: "Pot only", amountPence: 3000, dueDay: 12, potId: regularPot.id)
        let nextPeriod = makeRecurringPayment(id: "rec-next", name: "Next month", amountPence: 4000, dueDay: nil, potId: linkedPot.id, creditCardId: card.id, dueDate: "2026-07-01", frequency: .weekly)
        let allocation = makePotAllocation(id: "allocation-chatgpt", payPeriodId: period.id, potId: linkedPot.id, amountPence: 10000, recurringPaymentId: eligible.id, recurringDueDate: "2026-06-10")
        let snapshot = makeSnapshot(
            pots: [linkedPot, regularPot],
            recurringPayments: [eligible, cardOnly, potOnly, nextPeriod],
            payPeriods: [period],
            potAllocations: [allocation],
            creditCards: [card]
        )

        let items = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: snapshot, payPeriod: period)

        XCTAssertEqual(items.map(\.id), ["card-bill-funding-rec-chatgpt-2026-06-10"])
        XCTAssertEqual(items.first?.paymentName, "ChatGPT")
        XCTAssertEqual(items.first?.cardName, "Main Card")
        XCTAssertEqual(items.first?.potName, "Card Pot")
        XCTAssertEqual(items.first?.amountPence, 10000)
        XCTAssertEqual(items.first?.dueDate, "2026-06-10")
        XCTAssertEqual(items.first?.isCompleted, true)
    }

    func testOpeningBalanceFundingChecklistDerivesNextDirectDebitShortfall() {
        let settings = makeManualSettings(today: "2026-06-20")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-06-20", dueDay: 1)
        let linkedPot = makePot(id: "pot-card", name: "Card Pot", balancePence: 10000, targetPence: nil, linkedCreditCardId: card.id)
        let snapshot = makeSnapshot(settings: settings, pots: [linkedPot], payPeriods: [period], creditCards: [card])

        let items = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: period)

        XCTAssertEqual(items.map(\.id), ["card-opening-balance-funding-card-main-2026-07-01"])
        XCTAssertEqual(items.first?.cardName, "Barclays")
        XCTAssertEqual(items.first?.potName, "Card Pot")
        XCTAssertEqual(items.first?.amountPence, 40000)
        XCTAssertEqual(items.first?.directDebitDate, "2026-07-01")
        XCTAssertEqual(items.first?.isCompleted, false)
    }

    func testCardSpendFundingChecklistDerivesManualCardSpendsForLinkedCardPots() {
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 100000)
        let linkedCard = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let unlinkedCard = makeCreditCard(id: "card-other", name: "Other", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let linkedPot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: linkedCard.id)
        let eligibleSpend = makeTransaction(id: "txn-coffee", cardId: linkedCard.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let unlinkedSpend = makeTransaction(id: "txn-other", cardId: unlinkedCard.id, amountPence: 2500, date: "2026-06-11", note: "Other")
        let nextPeriodSpend = makeTransaction(id: "txn-next", cardId: linkedCard.id, amountPence: 3000, date: "2026-07-01", note: "Next")
        let snapshot = makeSnapshot(
            pots: [linkedPot],
            payPeriods: [period],
            transactions: [eligibleSpend, unlinkedSpend, nextPeriodSpend],
            creditCards: [linkedCard, unlinkedCard]
        )

        let items = PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: period)

        XCTAssertEqual(items.map(\.id), ["card-spend-funding-txn-coffee"])
        XCTAssertEqual(items.first?.transactionName, "Coffee")
        XCTAssertEqual(items.first?.cardName, "Barclays")
        XCTAssertEqual(items.first?.potName, "Barclays pot")
        XCTAssertEqual(items.first?.amountPence, 10000)
        XCTAssertEqual(items.first?.transactionDate, "2026-06-10")
        XCTAssertEqual(items.first?.dueDate, "2026-07-01")
        XCTAssertEqual(items.first?.isCompleted, false)
    }

    @MainActor
    func testTickingCardBillFundingChecklistTopsUpAndUntickingReversesPotAllocation() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(id: "card-main", name: "Main Card", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: nil, dueDay: 1)
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let payment = makeRecurringPayment(id: "rec-chatgpt", name: "ChatGPT", amountPence: 10000, dueDay: 10, potId: pot.id, creditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: payment.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))

        let allocation = store.snapshot.potAllocations.first
        XCTAssertEqual(allocation?.source, .recurringBillFunding)
        XCTAssertEqual(allocation?.recurringPaymentId, payment.id)
        XCTAssertEqual(allocation?.recurringDueDate, "2026-06-10")
        XCTAssertEqual(allocation?.amountPence, 10000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)

        let fundedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        XCTAssertEqual(fundedSummary.potAllocationsPence, 10000)
        XCTAssertEqual(fundedSummary.moneyLeftPence, 40000)

        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: payment.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.potAllocations.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testExcludingFundingChecklistItemKeepsItVisibleWithoutRemovingTheOutgoingFromPlannedCosts() async throws {
        let settings = makeManualSettings(today: "2026-06-01")
        let junePeriod = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let julyPeriod = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 50000)
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 0, targetPence: nil)
        let payment = makeRecurringPayment(id: "rec-phone", name: "Phone", amountPence: 2999, dueDay: 10, potId: pot.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment], payPeriods: [junePeriod, julyPeriod])))

        await store.load()
        let initialItem = try XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-06-01").first)
        let initialSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-06-01")
        XCTAssertEqual(initialSummary.unfundedChecklistPence, 2999)
        XCTAssertEqual(initialSummary.projectedMoneyLeftPence, 47001)

        XCTAssertTrue(store.setFundingChecklistExcluded(action: initialItem.action, excluded: true))

        let juneItem = try XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-06-01").first)
        XCTAssertTrue(juneItem.isExcluded)
        XCTAssertEqual(juneItem.status, .excluded)
        XCTAssertFalse(juneItem.isCompleted)
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)

        let excludedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-06-01")
        XCTAssertEqual(excludedSummary.unfundedChecklistPence, 0)
        XCTAssertEqual(excludedSummary.projectedCostsPence, 2999)
        XCTAssertEqual(excludedSummary.projectedMoneyLeftPence, 47001)

        let julyItem = try XCTUnwrap(PlannerDerivedData.fundingChecklistPresentationItems(snapshot: store.snapshot, payPeriod: julyPeriod, asOfDate: "2026-07-01").first)
        XCTAssertFalse(julyItem.isExcluded)
        XCTAssertEqual(julyItem.status, .needsFunding)
    }

    @MainActor
    func testExcludingFundedChecklistItemReversesAllocationAndCheckingAgainFundsIt() async throws {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(id: "card-main", name: "Main Card", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: nil, dueDay: 1)
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let payment = makeRecurringPayment(id: "rec-chatgpt", name: "ChatGPT", amountPence: 10000, dueDay: 10, potId: pot.id, creditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: payment.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))
        XCTAssertEqual(store.snapshot.potAllocations.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)

        let fundedItem = try XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: "2026-06-01"
            ).first { $0.name == payment.name }
        )
        XCTAssertTrue(store.setFundingChecklistExcluded(action: fundedItem.action, excluded: true))
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let excludedItem = try XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: "2026-06-01"
            ).first { $0.name == payment.name }
        )
        XCTAssertTrue(excludedItem.isExcluded)

        XCTAssertTrue(store.setFundingChecklistCompleted(action: excludedItem.action, completed: true))
        XCTAssertTrue(store.snapshot.fundingChecklistExclusions.isEmpty)
        XCTAssertEqual(store.snapshot.potAllocations.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)
    }

    @MainActor
    func testTickingCardSpendFundingChecklistTopsUpAndUntickingReversesPotAllocation() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let pot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], transactions: [spend], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))

        let allocation = store.snapshot.potAllocations.first
        XCTAssertEqual(allocation?.source, .cardSpendFunding)
        XCTAssertEqual(allocation?.transactionId, spend.id)
        XCTAssertEqual(allocation?.transactionDate, "2026-06-10")
        XCTAssertEqual(allocation?.amountPence, 10000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)

        let fundedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(fundedSummary.potAllocationsPence, 10000)
        XCTAssertEqual(fundedSummary.moneyLeftPence, 40000)

        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.potAllocations.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testFundedCardSpendRefusesUnsafeReverseEditAndDeleteWhenPotMoneyIsUnavailable() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let pot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], transactions: [spend], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))

        var externallyDrainedSnapshot = store.snapshot
        externallyDrainedSnapshot.pots[0].balancePence = 9999
        store.useSnapshotForSimulation(externallyDrainedSnapshot)

        XCTAssertFalse(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.potAllocations.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 9999)

        store.updateTransaction(
            id: spend.id,
            potId: nil,
            creditCardId: card.id,
            paymentMethod: .creditCard,
            amountPence: 12000,
            date: "2026-06-11",
            note: "Coffee bigger"
        )
        XCTAssertEqual(store.snapshot.transactions.first?.amountPence, 10000)
        XCTAssertEqual(store.snapshot.transactions.first?.date, "2026-06-10")
        XCTAssertEqual(store.snapshot.potAllocations.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 9999)

        store.deleteTransaction(id: spend.id)
        XCTAssertEqual(store.snapshot.transactions.count, 1)
        XCTAssertEqual(store.snapshot.potAllocations.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 9999)
    }

    @MainActor
    func testTickingOpeningBalanceFundingChecklistTopsUpAndUntickingReversesPotAllocation() async {
        let settings = makeManualSettings(today: "2026-06-20")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-06-20", dueDay: 1)
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: card.id, directDebitDate: "2026-07-01", payPeriodId: period.id, completed: true))

        let allocation = store.snapshot.potAllocations.first
        XCTAssertEqual(allocation?.source, .cardOpeningBalanceFunding)
        XCTAssertEqual(allocation?.creditCardId, card.id)
        XCTAssertEqual(allocation?.creditCardDirectDebitDate, "2026-07-01")
        XCTAssertEqual(allocation?.amountPence, 50000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 50000)

        let fundedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-20")
        XCTAssertEqual(fundedSummary.potAllocationsPence, 50000)
        XCTAssertEqual(fundedSummary.moneyLeftPence, 50000)

        XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: card.id, directDebitDate: "2026-07-01", payPeriodId: period.id, completed: false))
        XCTAssertEqual(store.snapshot.potAllocations.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testFundedOpeningBalanceRepaysFromLinkedPotOnDirectDebitDate() async {
        let settings = makeManualSettings(today: "2026-06-20")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-06-20", dueDay: 1)
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: card.id, directDebitDate: "2026-07-01", payPeriodId: period.id, completed: true))

        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-07-01"
        store.updateSettings(dueSettings)

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 50000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 50000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testCardBillPotCycleForecastsPostsKeepsFundedPotUntilRepayment() async {
        let settingsBeforeDue = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Main Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-12",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let payment = makeRecurringPayment(id: "rec-chatgpt", name: "ChatGPT", amountPence: 10000, dueDay: 10, potId: pot.id, creditCardId: card.id)
        let beforeSnapshot = makeSnapshot(settings: settingsBeforeDue, pots: [pot], recurringPayments: [payment], payPeriods: [period], creditCards: [card])

        let beforeDueAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: beforeSnapshot, payPeriod: period, asOfDate: "2026-06-01")
        XCTAssertEqual(beforeDueAvailability.actualAvailablePence, 80000)
        XCTAssertEqual(beforeDueAvailability.forecastAvailablePence, 70000)
        let beforeDueProgress = PlannerDerivedData.potProgress(pot: pot, snapshot: beforeSnapshot, today: "2026-06-01")
        XCTAssertEqual(beforeDueProgress.targetPence, 0)
        XCTAssertEqual(beforeDueProgress.shortfallPence, 0)

        let fundingStore = PlannerStore(repository: TestPlannerRepository(snapshot: beforeSnapshot))
        await fundingStore.load()
        XCTAssertTrue(fundingStore.setCardBillFundingCompleted(paymentId: payment.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))
        XCTAssertEqual(fundingStore.snapshot.pots.first?.balancePence, 10000)
        let fundedChecklist = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: fundingStore.snapshot, payPeriod: period)
        XCTAssertEqual(fundedChecklist.first?.isCompleted, true)
        let fundedAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: fundingStore.snapshot, payPeriod: period, asOfDate: "2026-06-01")
        XCTAssertEqual(fundedAvailability.actualAvailablePence, 80000)
        XCTAssertEqual(fundedAvailability.forecastAvailablePence, 70000)

        let settingsOnDueDate = makeManualSettings(today: "2026-06-10")
        var dueDateSnapshot = fundingStore.snapshot
        dueDateSnapshot.settings = settingsOnDueDate
        let dueDateStore = PlannerStore(repository: TestPlannerRepository(snapshot: dueDateSnapshot))

        await dueDateStore.load()

        let dueDateTransaction = dueDateStore.snapshot.transactions.first
        XCTAssertEqual(dueDateTransaction?.id, "card-recurring-rec-chatgpt-2026-06-10")
        XCTAssertEqual(dueDateTransaction?.paymentMethod, .creditCard)
        XCTAssertEqual(dueDateTransaction?.creditCardId, card.id)
        XCTAssertEqual(dueDateTransaction?.potId, pot.id)
        XCTAssertEqual(dueDateTransaction?.recurringPaymentId, payment.id)
        XCTAssertEqual(dueDateStore.snapshot.pots.first?.balancePence, 10000)
        XCTAssertFalse(dueDateStore.applyDueLinkedPotObligations(asOf: "2026-06-10"))

        let onDueAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: dueDateStore.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(onDueAvailability.actualAvailablePence, 70000)
        XCTAssertEqual(onDueAvailability.forecastAvailablePence, 70000)
        let onDueProgress = PlannerDerivedData.potProgress(pot: dueDateStore.snapshot.pots[0], snapshot: dueDateStore.snapshot, today: "2026-06-10")
        XCTAssertEqual(onDueProgress.targetPence, 10000)
        XCTAssertEqual(onDueProgress.shortfallPence, 0)

        var julySettings = dueDateStore.snapshot.settings
        julySettings.manualTodayIso = "2026-07-01"
        dueDateStore.updateSettings(julySettings)

        let repayment = dueDateStore.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 10000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(dueDateStore.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: dueDateStore.snapshot), 0)
        XCTAssertEqual(dueDateStore.snapshot.transactions.filter { $0.id == "card-recurring-rec-chatgpt-2026-06-10" }.count, 1)
    }

    @MainActor
    func testCardBillFundingDoesNotReduceOpeningBalanceChecklistForSameLinkedPot() async {
        let settingsBeforeDue = makeManualSettings(today: "2026-06-30")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Card 1",
            limitPence: 100000,
            openingBalancePence: 50000,
            openingStatementBalancePence: 50000,
            statementDate: "2026-07-05",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-card", name: "Pot 1", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let bill = makeRecurringPayment(
            id: "rec-bill",
            name: "Bill 1",
            amountPence: 7500,
            dueDay: 1,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-06-30T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settingsBeforeDue, pots: [pot], recurringPayments: [bill], payPeriods: [period], creditCards: [card])))

        await store.load()

        let billItems = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(billItems.first?.amountPence, 7500)
        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: bill.id, dueDate: "2026-07-01", payPeriodId: period.id, completed: true))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 7500)

        let openingItemsAfterBillFunding = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(openingItemsAfterBillFunding.first?.amountPence, 50000)
        XCTAssertEqual(openingItemsAfterBillFunding.first?.isCompleted, false)

        XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: card.id, directDebitDate: "2026-07-01", payPeriodId: period.id, completed: true))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 57500)

        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-07-01"
        store.updateSettings(dueSettings)

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 7500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 7500)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == "card-recurring-rec-bill-2026-07-01" })?.potId, pot.id)
        let repayment = store.snapshot.creditCardRepayments.first(where: { $0.id == "card-opening-balance-repayment-card-main-2026-07-01" })
        XCTAssertEqual(repayment?.amountPence, 50000)
        XCTAssertEqual(repayment?.potContributionPence, 50000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
    }

    @MainActor
    func testManualCardSpendFundingCycleDropsAvailabilityFundsPotAndRepaysFromPot() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let junePeriod = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let julyPeriod = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 50000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Barclays",
            limitPence: 50000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-20",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [junePeriod, julyPeriod], transactions: [spend], creditCards: [card])))

        await store.load()

        let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-06-10")
        XCTAssertEqual(availability.actualAvailablePence, 40000)
        let progress = PlannerDerivedData.potProgress(pot: store.snapshot.pots[0], snapshot: store.snapshot, today: "2026-06-10")
        XCTAssertEqual(progress.targetPence, 10000)
        XCTAssertEqual(progress.shortfallPence, 10000)

        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: junePeriod.id, completed: true))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10000)

        var julySettings = store.snapshot.settings
        julySettings.manualTodayIso = "2026-07-01"
        store.updateSettings(julySettings)

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 10000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let juneSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: junePeriod, asOfDate: "2026-07-01")
        XCTAssertEqual(juneSummary.potAllocationsPence, 10000)
        XCTAssertEqual(juneSummary.totalCostsPence, 10000)
        XCTAssertEqual(juneSummary.moneyLeftPence, 40000)
        let julySummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: julyPeriod, asOfDate: "2026-07-01")
        XCTAssertEqual(julySummary.creditCardRepaymentsPence, 0)
        XCTAssertEqual(julySummary.totalCostsPence, 0)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))
        XCTAssertEqual(store.snapshot.creditCardRepayments.count, 1)
    }

    @MainActor
    func testEditingFundedCardSpendReconcilesAllocationAndPotBalance() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let originalCard = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let newCard = makeCreditCard(id: "card-alt", name: "Amex", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let originalPot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: originalCard.id)
        let newPot = makePot(id: "pot-amex", name: "Amex pot", balancePence: 0, targetPence: nil, linkedCreditCardId: newCard.id)
        let spend = makeTransaction(id: "txn-coffee", cardId: originalCard.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [originalPot, newPot], payPeriods: [period], transactions: [spend], creditCards: [originalCard, newCard])))

        await store.load()
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))

        store.updateTransaction(
            id: spend.id,
            potId: nil,
            creditCardId: newCard.id,
            paymentMethod: .creditCard,
            amountPence: 12000,
            date: "2026-06-11",
            note: "Coffee bigger"
        )

        let allocation = store.snapshot.potAllocations.first
        XCTAssertEqual(allocation?.source, .cardSpendFunding)
        XCTAssertEqual(allocation?.transactionId, spend.id)
        XCTAssertEqual(allocation?.transactionDate, "2026-06-11")
        XCTAssertEqual(allocation?.potId, newPot.id)
        XCTAssertEqual(allocation?.amountPence, 12000)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == originalPot.id }?.balancePence, 0)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == newPot.id }?.balancePence, 12000)
    }
}
