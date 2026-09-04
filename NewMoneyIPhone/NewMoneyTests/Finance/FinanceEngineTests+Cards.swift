import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    func testTotalCreditAddsEveryActiveCardLimit() {
        let activeCards = (1...5).map { index in
            makeCreditCard(
                id: "card-\(index)",
                name: "Card \(index)",
                limitPence: 50_000,
                openingBalancePence: 0,
                openingStatementBalancePence: nil,
                statementDate: nil,
                dueDay: 1
            )
        }
        var archivedCard = makeCreditCard(
            id: "card-archived",
            name: "Archived card",
            limitPence: 50_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: nil,
            dueDay: 1
        )
        archivedCard.archived = true

        XCTAssertEqual(
            PlannerDerivedData.totalCreditLimitPence(cards: activeCards + [archivedCard]),
            250_000
        )
    }

    func testCardChargesAreGroupedInTheIncomePeriodContainingTheirDirectDebitDate() {
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
        let cardSpend = makeTransaction(
            id: "transaction-groceries",
            cardId: card.id,
            amountPence: 4200,
            date: "2026-07-21",
            note: "Groceries"
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [bill],
            payPeriods: [july, august],
            transactions: [cardSpend],
            creditCards: [card]
        )

        XCTAssertTrue(PlannerDerivedData.recurringBillFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: july,
            groupByFundingDueDate: true
        ).isEmpty)
        XCTAssertTrue(PlannerDerivedData.cardSpendFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: july,
            groupByFundingDueDate: true
        ).isEmpty)

        let augustBill = try! XCTUnwrap(
            PlannerDerivedData.recurringBillFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: august,
                groupByFundingDueDate: true
            )
                .first { $0.paymentId == bill.id }
        )
        let augustSpend = try! XCTUnwrap(
            PlannerDerivedData.cardSpendFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: august,
                groupByFundingDueDate: true
            )
                .first { $0.transactionId == cardSpend.id }
        )
        XCTAssertEqual(augustBill.dueDate, "2026-07-21")
        XCTAssertEqual(augustBill.fundingDueDate, "2026-08-05")
        XCTAssertEqual(augustSpend.transactionDate, "2026-07-21")
        XCTAssertEqual(augustSpend.dueDate, "2026-08-05")

        let augustPresentation = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: august,
            asOfDate: "2026-08-01",
            groupByFundingDueDate: true
        )
        let presentedBill = try! XCTUnwrap(augustPresentation.first { $0.name == bill.name })
        let presentedSpend = try! XCTUnwrap(augustPresentation.first { $0.name == cardSpend.note })
        XCTAssertEqual(presentedBill.dueDate, "2026-08-05")
        XCTAssertTrue(presentedBill.detail.contains("charged 21 Jul"))
        XCTAssertTrue(presentedBill.detail.contains("due 5 Aug"))
        XCTAssertEqual(presentedSpend.dueDate, "2026-08-05")
    }

    func testStatementDayCardSpendIsReservedForFollowingCycleInsteadOfOpeningBalance() {
        let settings = makeManualSettings(today: "2026-07-31")
        let period = makePayPeriod(
            id: "period-july-august",
            startDate: "2026-07-31",
            endDate: "2026-08-30",
            payday: "2026-07-31",
            incomePence: 100000
        )
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            openingBalancePence: 61372,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-31",
            dueDay: 20,
            createdAt: "2026-07-31T08:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 61372,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        var openingFunding = makePotAllocation(
            id: "allocation-aqua-opening",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 60587,
            source: .cardOpeningBalanceFunding,
            recurringPaymentId: nil,
            recurringDueDate: nil
        )
        openingFunding.creditCardId = card.id
        openingFunding.creditCardDirectDebitDate = "2026-08-20"
        let amazonShop = makeTransaction(
            id: "transaction-amazon-shop",
            cardId: card.id,
            amountPence: 7767,
            date: "2026-07-31",
            note: "Amazon shop"
        )
        let amazonPrime = makeTransaction(
            id: "transaction-amazon-prime",
            cardId: card.id,
            amountPence: 449,
            date: "2026-07-31",
            note: "Amazon prime student"
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            potAllocations: [openingFunding],
            transactions: [amazonShop, amazonPrime],
            creditCards: [card]
        )

        let items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: period,
            asOfDate: "2026-07-31",
            groupByFundingDueDate: true
        )
        let cardSpends = items.filter {
            if case .cardSpend = $0.action { return true }
            return false
        }

        XCTAssertTrue(cardSpends.isEmpty)
        XCTAssertFalse(items.contains {
            if case .cardPayment = $0.action { return true }
            return false
        })
        XCTAssertEqual(cardSpends.reduce(0) { $0 + $1.amountPence }, 0)
    }

    func testBarclaysCardPaymentBreakdownReconcilesOpeningBalanceICloudAndTemu() {
        let settings = makeManualSettings(today: "2026-07-16")
        let period = makePayPeriod(
            id: "pay-period-2026-07-01",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 226191
        )
        let card = makeCreditCard(
            id: "card-barclays",
            name: "Barclaycard",
            openingBalancePence: 65443,
            openingStatementBalancePence: 65443,
            statementDate: "2026-07-13",
            dueDay: 6,
            createdAt: "2026-07-10T20:41:58.377Z"
        )
        let pot = makePot(
            id: "pot-barclays",
            name: "Barclays",
            balancePence: 68840,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let iCloud = makeRecurringPayment(
            id: "rec-icloud",
            name: "iCloud+",
            amountPence: 899,
            dueDay: 10,
            potId: pot.id,
            creditCardId: card.id
        )
        let runna = makeRecurringPayment(
            id: "rec-runna",
            name: "Runna",
            amountPence: 1599,
            dueDay: 18,
            potId: pot.id,
            creditCardId: card.id
        )
        let appleCare = makeRecurringPayment(
            id: "rec-applecare",
            name: "AppleCare",
            amountPence: 899,
            dueDay: 19,
            potId: pot.id,
            creditCardId: card.id
        )
        let iCloudTransaction = Transaction(
            id: "transaction-icloud",
            potId: nil,
            payPeriodId: period.id,
            amountPence: 899,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: iCloud.id,
            date: "2026-07-10",
            note: "iCloud+",
            createdAt: "2026-07-10T21:11:55.570Z",
            updatedAt: "2026-07-10T21:11:55.570Z",
            deletedAt: nil
        )
        let temuTransaction = Transaction(
            id: "transaction-temu",
            potId: nil,
            payPeriodId: period.id,
            amountPence: 420,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: nil,
            date: "2026-07-15",
            note: "Temu",
            createdAt: "2026-07-16T03:34:44.300Z",
            updatedAt: "2026-07-16T03:34:44.300Z",
            deletedAt: nil
        )
        var cardPaymentAllocation = makePotAllocation(
            id: "allocation-card-payment",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 12260,
            source: .cardPaymentFunding,
            recurringPaymentId: nil,
            recurringDueDate: nil
        )
        cardPaymentAllocation.creditCardId = card.id
        cardPaymentAllocation.creditCardDirectDebitDate = "2026-08-06"
        var runnaAllocation = makePotAllocation(
            id: "allocation-runna",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 1599,
            source: .recurringBillFunding,
            recurringPaymentId: runna.id,
            recurringDueDate: "2026-07-18"
        )
        runnaAllocation.creditCardId = card.id
        var appleCareAllocation = makePotAllocation(
            id: "allocation-applecare",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 899,
            source: .recurringBillFunding,
            recurringPaymentId: appleCare.id,
            recurringDueDate: "2026-07-19"
        )
        appleCareAllocation.creditCardId = card.id
        let iCloudExclusion = FundingChecklistExclusion(
            id: "exclude-icloud",
            kind: .cardBill,
            sourceId: iCloud.id,
            occurrenceDate: "2026-07-10",
            payPeriodId: period.id,
            createdAt: "2026-07-10T21:29:13.806Z",
            updatedAt: "2026-07-10T21:29:13.806Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [iCloud, runna, appleCare],
            payPeriods: [period],
            potAllocations: [cardPaymentAllocation, runnaAllocation, appleCareAllocation],
            transactions: [iCloudTransaction, temuTransaction],
            creditCards: [card],
            fundingChecklistExclusions: [iCloudExclusion]
        )

        let item = try! XCTUnwrap(
            PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: "2026-07-16"
            )
            .first {
                if case .cardPayment = $0.action { return true }
                return false
            }
        )

        XCTAssertEqual(item.title, "Add £126.80 to Barclays")
        XCTAssertEqual(item.breakdown.map(\.title), ["Opening balance", "iCloud+", "Temu"])
        XCTAssertEqual(item.breakdown.map(\.amountPence), [11361, 899, 420])
        XCTAssertEqual(item.breakdown.reduce(0) { $0 + $1.amountPence }, 12680)
        XCTAssertTrue(item.breakdown.last?.detail.contains("15 Jul") == true)

        let summary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: period,
            asOfDate: "2026-07-16"
        )
        XCTAssertEqual(summary.unfundedChecklistPence, 420)
        XCTAssertEqual(
            summary.projectedMoneyLeftPence,
            summary.payReceivedPence - summary.projectedCostsPence
        )
    }

    @MainActor
    func testStatementDayChargesMoveToTheFollowingCycleAndRepayOnlyOnce() async throws {
        let settings = makeManualSettings(today: "2026-06-01")
        let period = makePayPeriod(id: "period-summer", startDate: "2026-06-01", endDate: "2026-07-31", payday: "2026-06-01", incomePence: 150000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-10", dueDay: 15, createdAt: "2026-06-01T00:00:00.000Z")
        let pot = makePot(id: "pot-card", name: "Card Pot", balancePence: 30000, targetPence: nil, linkedCreditCardId: card.id)
        let previousStatementDayBill = makeRecurringPayment(id: "rec-previous-statement-day", name: "Previous statement day", amountPence: 20000, dueDay: nil, potId: pot.id, creditCardId: card.id, dueDate: "2026-06-10", frequency: .once, createdAt: "2026-06-01T00:00:00.000Z")
        let currentStatementDayBill = makeRecurringPayment(id: "rec-current-statement-day", name: "Current statement day", amountPence: 30000, dueDay: nil, potId: pot.id, creditCardId: card.id, dueDate: "2026-07-10", frequency: .once, createdAt: "2026-06-01T00:00:00.000Z")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [previousStatementDayBill, currentStatementDayBill],
            payPeriods: [period],
            creditCards: [card]
        )))

        await store.load()
        XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: previousStatementDayBill.id, dueDate: "2026-06-10", payPeriodId: period.id, completed: true))

        var june10Settings = store.snapshot.settings
        june10Settings.manualTodayIso = "2026-06-10"
        store.updateSettings(june10Settings)
        XCTAssertEqual(store.snapshot.transactions.first { $0.recurringPaymentId == previousStatementDayBill.id }?.potId, pot.id)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 50000)

        var june15Settings = store.snapshot.settings
        june15Settings.manualTodayIso = "2026-06-15"
        store.updateSettings(june15Settings)
        let juneRepayment = store.snapshot.creditCardRepayments.first {
            $0.creditCardId == card.id && $0.statementDate == "2026-06-10"
        }
        XCTAssertNil(juneRepayment)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 50000)

        var july10Settings = store.snapshot.settings
        july10Settings.manualTodayIso = "2026-07-10"
        store.updateSettings(july10Settings)
        XCTAssertNil(store.snapshot.transactions.first { $0.recurringPaymentId == currentStatementDayBill.id }?.potId)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 50000)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)
        let julyRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == card.id && $0.statementDate == "2026-07-10"
        })
        XCTAssertEqual(julyRepayment.amountPence, 20000)
        XCTAssertEqual(julyRepayment.potContributionPence, 20000)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 30000)
    }

    func testCreditCardAvailabilityPreservesNegativeOverLimitAmounts() {
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(
            id: "card-over-limit",
            name: "Over Limit",
            limitPence: 20000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-15",
            dueDay: 10
        )
        let postedSpend = makeTransaction(id: "txn-posted", cardId: card.id, amountPence: 23300, date: "2026-07-01", note: "Posted spend")
        let futureSpend = makeTransaction(id: "txn-future", cardId: card.id, amountPence: 2000, date: "2026-07-20", note: "Future spend")
        let snapshot = makeSnapshot(payPeriods: [period], transactions: [postedSpend, futureSpend], creditCards: [card])

        let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: snapshot, payPeriod: period, asOfDate: "2026-07-10")

        XCTAssertEqual(availability.actualAvailablePence, -3300)
        XCTAssertEqual(availability.forecastAvailablePence, -5300)
    }

    @MainActor
    func testEditingCardRepaymentRecalculatesCardAndLinkedPotFromCanonicalRecord() async throws {
        let settings = makeManualSettings(today: "2026-08-25")
        let card = makeCreditCard(
            id: "card-edit-repayment",
            name: "Editable Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-09-15",
            dueDay: 20
        )
        let spend = makeTransaction(
            id: "txn-edit-repayment",
            cardId: card.id,
            amountPence: 5_000,
            date: "2026-08-10",
            note: "Card spend"
        )
        let pot = makePot(
            id: "pot-edit-repayment",
            name: "Card pot",
            balancePence: 9_000,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let repayment = CreditCardRepayment(
            id: "repayment-editable",
            creditCardId: card.id,
            amountPence: 1_000,
            date: "2026-08-20",
            note: "Original payment",
            source: .linkedPotStatement,
            potId: pot.id,
            potContributionPence: 1_000,
            potContributions: [CreditCardPotContribution(potId: pot.id, amountPence: 1_000)],
            paycheckContributionPence: 0,
            createdAt: "2026-08-20T00:00:00.000Z",
            updatedAt: "2026-08-20T00:00:00.000Z",
            deletedAt: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            transactions: [spend],
            creditCards: [card],
            creditCardRepayments: [repayment]
        )))

        await store.load()
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 4_000)

        store.updateCardRepayment(
            id: repayment.id,
            amountPence: 1_500,
            date: "2026-08-21",
            note: "Updated payment"
        )

        let updated = try XCTUnwrap(store.snapshot.creditCardRepayments.first { $0.id == repayment.id })
        XCTAssertEqual(updated.amountPence, 1_500)
        XCTAssertEqual(updated.date, "2026-08-21")
        XCTAssertEqual(updated.note, "Updated payment")
        XCTAssertEqual(updated.potContributionPence, 1_500)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 8_500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 3_500)
    }

    func testConfirmedStatementIncreaseReconcilesLiveCardBalance() throws {
        let card = makeCreditCard(
            id: "card-processed-statement",
            name: "Barclays",
            openingBalancePence: 7_018,
            openingStatementBalancePence: 0,
            statementDate: "2026-08-13",
            dueDay: 5,
            createdAt: "2026-08-25T00:00:00.000Z"
        )
        let currentSpend = makeTransaction(
            id: "txn-after-statement",
            cardId: card.id,
            amountPence: 15_531,
            date: "2026-08-19",
            note: "Current activity"
        )
        let confirmedStatement = CreditCardCycleOverride(
            id: "override-processed-statement",
            creditCardId: card.id,
            scheduledStatementDate: "2026-08-13",
            statementState: .normal,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 7_917,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-13T00:00:00.000Z",
            updatedAt: "2026-08-13T00:00:00.000Z",
            deletedAt: nil
        )
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-08-25"
        let snapshot = makeSnapshot(
            settings: settings,
            transactions: [currentSpend],
            creditCards: [card],
            creditCardCycleOverrides: [confirmedStatement]
        )

        let summary = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementSummaries(
                snapshot: snapshot,
                asOfDate: "2026-08-25"
            ).first
        )
        let owed = PlannerDerivedData.creditCardOwedSummary(
            card: card,
            snapshot: snapshot,
            payPeriod: nil,
            asOfDate: "2026-08-25"
        )

        XCTAssertEqual(summary.statementAmountPence, 7_917)
        XCTAssertEqual(summary.calculatedAmountPence, 0)
        XCTAssertEqual(summary.reconciliationAdjustmentPence, 7_917)
        XCTAssertEqual(
            summary.reconciliationAdjustmentPence,
            summary.statementAmountPence - summary.calculatedAmountPence
        )
        XCTAssertEqual(summary.statementAmountPence - (card.openingBalancePence ?? 0), 899)
        XCTAssertEqual(owed.actualOwedPence, 23_448)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: snapshot), 23_448)

        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: snapshot,
            asOfDate: "2026-08-25"
        )
        let statement = try XCTUnwrap(history.statementSections.first)

        XCTAssertEqual(history.currentBalancePence, 23_448)
        XCTAssertEqual(history.currentSection.balancePence, 15_531)
        XCTAssertFalse(history.currentSection.entries.contains { $0.kind == .statementBalance })
        XCTAssertEqual(history.currentSection.entries.reduce(0) { $0 + $1.amountPence }, 15_531)
        XCTAssertEqual(statement.balancePence, 7_917)
        XCTAssertTrue(statement.entries.contains {
            $0.kind == .reconciliationAdjustment &&
                $0.title == "Unitemised statement amount" &&
                $0.editTarget == .statement(cardId: card.id, scheduledStatementDate: "2026-08-13")
        })
        XCTAssertEqual(statement.title, "13 August processed")
        XCTAssertEqual(statement.directDebitDate, "2026-09-05")
    }

    func testUnstatementedOpeningBalanceRollsIntoFirstStatementAfterCardImport() throws {
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            limitPence: 130_000,
            openingBalancePence: 107_091,
            openingStatementBalancePence: 69_588,
            statementDate: "2026-08-02",
            dueDay: 20,
            createdAt: "2026-08-29T09:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 19_982,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        var statementPurchases = makeTransaction(
            id: "aqua-statement-purchases",
            cardId: card.id,
            amountPence: 21_213,
            date: "2026-08-28",
            note: "Recorded statement purchases"
        )
        statementPurchases.refundedAt = "2026-08-29T10:00:00.000Z"
        statementPurchases.refundedAmountPence = 1_231
        let costa = makeTransaction(
            id: "aqua-costa",
            cardId: card.id,
            amountPence: 415,
            date: "2026-09-03",
            note: "Costa"
        )
        let augustPayment = CreditCardRepayment(
            id: "aqua-august-payment",
            creditCardId: card.id,
            amountPence: 69_588,
            date: "2026-08-20",
            note: "Automatic Aqua statement payment",
            statementDate: "2026-08-02",
            directDebitDate: "2026-08-20",
            source: .linkedPotStatement,
            potId: pot.id,
            potContributionPence: 69_588,
            paycheckContributionPence: 0,
            createdAt: "2026-08-20T00:00:00.000Z",
            updatedAt: "2026-08-20T00:00:00.000Z",
            deletedAt: nil
        )
        var settings = makeManualSettings(today: "2026-09-03")
        settings.lastProcessedDateIso = "2026-09-03"
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            transactions: [statementPurchases, costa],
            creditCards: [card],
            creditCardRepayments: [augustPayment]
        )

        let statements = PlannerDerivedData.creditCardStatementSummaries(
            snapshot: snapshot,
            asOfDate: "2026-09-03"
        )
        let september = try XCTUnwrap(statements.first { $0.statementDate == "2026-09-02" })
        let august = try XCTUnwrap(statements.first { $0.statementDate == "2026-08-02" })
        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: snapshot,
            asOfDate: "2026-09-03"
        )
        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-09-03")

        XCTAssertEqual(august.statementAmountPence, 69_588)
        XCTAssertEqual(august.unpaidAmountPence, 0)
        XCTAssertEqual(september.statementAmountPence, 57_485)
        XCTAssertEqual(september.transactions.reduce(0) { $0 + $1.amountPence }, 57_485)
        XCTAssertTrue(september.transactions.contains {
            $0.id == "opening-unstatemented-card-aqua-2026-09-02" && $0.amountPence == 37_503
        })
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: snapshot), 57_900)
        XCTAssertEqual(history.currentBalancePence, 57_900)
        XCTAssertEqual(history.currentSection.balancePence, 415)
        XCTAssertEqual(history.currentSection.entries.map(\.title), ["Costa"])
        XCTAssertEqual(progress.targetPence, 57_485)
        XCTAssertEqual(progress.coveredPence, 19_982)
        XCTAssertEqual(progress.shortfallPence, 37_503)
    }

    @MainActor
    func testRecurringCardBillsNormalizeToCardsLinkedPotWhenSaved() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 50000)
        let card = makeCreditCard(
            id: "card-main",
            name: "Main Card",
            limitPence: 50000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-05",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let linkedPot = makePot(id: "pot-card", name: "Card Pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let otherPot = makePot(id: "pot-other", name: "Other Pot", balancePence: 0, targetPence: nil)
        let existingPayment = makeRecurringPayment(
            id: "rec-existing",
            name: "Existing",
            amountPence: 10000,
            dueDay: 10,
            potId: linkedPot.id,
            creditCardId: card.id
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [otherPot, linkedPot], recurringPayments: [existingPayment], payPeriods: [period], creditCards: [card])))

        await store.load()
        store.addRecurringPayment(
            name: "New Bill",
            amountPence: 12000,
            dueDay: 12,
            frequency: .monthly,
            potId: otherPot.id,
            creditCardId: card.id,
            priority: .essential
        )

        let addedPayment = store.snapshot.recurringPayments.first { $0.name == "New Bill" }
        XCTAssertEqual(addedPayment?.creditCardId, card.id)
        XCTAssertEqual(addedPayment?.potId, linkedPot.id)

        var updatedPayment = existingPayment
        updatedPayment.potId = otherPot.id
        updatedPayment.creditCardId = card.id
        store.updateRecurringPayment(updatedPayment)

        let savedExistingPayment = store.snapshot.recurringPayments.first { $0.id == existingPayment.id }
        XCTAssertEqual(savedExistingPayment?.creditCardId, card.id)
        XCTAssertEqual(savedExistingPayment?.potId, linkedPot.id)
    }

    @MainActor
    func testConfirmedRecurringCardBillMovesGeneratedChargeToActualDate() async {
        let settings = makeManualSettings(today: "2026-06-15")
        let card = makeCreditCard(id: "card-main", name: "Main card", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let payment = makeRecurringPayment(id: "rec-streaming", name: "Streaming", amountPence: 1_500, dueDay: 15, potId: nil, creditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, recurringPayments: [payment], creditCards: [card])))

        await store.load()
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 1_500)

        store.confirmRecurringBillOccurrence(
            paymentId: payment.id,
            scheduledDueDate: "2026-06-15",
            actualDueDate: "2026-06-18"
        )
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)

        var laterSettings = store.snapshot.settings
        laterSettings.manualTodayIso = "2026-06-19"
        store.updateSettings(laterSettings)

        let charge = store.snapshot.transactions.first { $0.deletedAt == nil && $0.recurringPaymentId == payment.id }
        XCTAssertEqual(charge?.id, "card-recurring-rec-streaming-2026-06-15")
        XCTAssertEqual(charge?.date, "2026-06-18")
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 1_500)
    }

    @MainActor
    func testLinkedCreditCardPotWaitsForStatementSetupThenRepaysOnDirectDebitDate() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let card = makeCreditCard(
            id: "card-barclays",
            name: "Barclays",
            openingBalancePence: 68005,
            openingStatementBalancePence: 60000,
            statementDate: nil,
            dueDay: 1
        )
        let pot = makePot(id: "pot-barclays", name: "Barclays", balancePence: 77505, targetPence: nil, linkedCreditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], creditCards: [card])))

        await store.load()
        XCTAssertEqual(store.snapshot.creditCardRepayments.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 77505)

        var updatedCard = card
        updatedCard.statementDate = "2026-05-14"
        store.updateCreditCard(updatedCard)

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.id, "card-statement-repayment-card-barclays-2026-05-14-2026-06-01")
        XCTAssertEqual(repayment?.amountPence, 60000)
        XCTAssertEqual(repayment?.date, "2026-06-01")
        XCTAssertEqual(repayment?.note, "Automatic Barclays statement payment from Barclays pot")
        XCTAssertEqual(repayment?.statementDate, "2026-05-14")
        XCTAssertEqual(repayment?.directDebitDate, "2026-06-01")
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potId, pot.id)
        XCTAssertEqual(repayment?.potContributionPence, 60000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 17505)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-01"))
        XCTAssertEqual(store.snapshot.creditCardRepayments.count, 1)
    }

    @MainActor
    func testDelayedCardStatementReassignsSpendingToConfirmedActualStatementDate() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let card = makeCreditCard(
            id: "card-main",
            name: "Main Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-10",
            dueDay: 15,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let transactions = [
            makeTransaction(id: "before", cardId: card.id, amountPence: 10_000, date: "2026-06-09", note: "Before"),
            makeTransaction(id: "during-delay", cardId: card.id, amountPence: 5_000, date: "2026-06-11", note: "During delay")
        ]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, transactions: transactions, creditCards: [card])))

        await store.load()
        store.markCreditCardStatementAwaiting(cardId: card.id, scheduledStatementDate: "2026-06-10")

        XCTAssertTrue(
            PlannerDerivedData.creditCardStatementPayments(
                card: card,
                snapshot: store.snapshot,
                startDate: "2026-06-01",
                endDate: "2026-06-30",
                asOfDate: "2026-06-11"
            ).isEmpty
        )
        XCTAssertEqual(
            PlannerDerivedData.creditCardHeldCycleReservePence(card: card, snapshot: store.snapshot, asOfDate: "2026-06-11"),
            15_000
        )

        store.confirmCreditCardStatement(cardId: card.id, scheduledStatementDate: "2026-06-10", actualStatementDate: "2026-06-13")
        let payment = PlannerDerivedData.creditCardStatementPayments(
            card: card,
            snapshot: store.snapshot,
            startDate: "2026-06-01",
            endDate: "2026-06-30",
            asOfDate: "2026-06-13"
        ).first

        XCTAssertEqual(payment?.statementDate, "2026-06-13")
        XCTAssertEqual(payment?.directDebitDate, "2026-06-15")
        XCTAssertEqual(payment?.actualDuePence, 15_000)
    }

    func testNextCreditCardStatementDateSkipsAnAlreadyClosedStatement() {
        let card = makeCreditCard(
            id: "card-capital-one",
            name: "Capital one",
            openingBalancePence: 20_237,
            openingStatementBalancePence: 20_237,
            statementDate: "2026-07-09",
            dueDay: 4,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let snapshot = makeSnapshot(creditCards: [card])

        let activeCycle = PlannerDerivedData.creditCardCycleAdjustmentSummary(
            card: card,
            snapshot: snapshot,
            asOfDate: "2026-07-16"
        )

        XCTAssertEqual(activeCycle?.statementDate, "2026-07-09")
        XCTAssertEqual(activeCycle?.directDebitDate, "2026-08-04")
        XCTAssertEqual(
            PlannerDerivedData.creditCardNextStatementDate(
                card: card,
                snapshot: snapshot,
                asOfDate: "2026-07-16"
            ),
            "2026-08-09"
        )
    }

    func testNextCreditCardStatementDateUsesTheFirstFutureStatementBeforeCycleClose() {
        let card = makeCreditCard(
            id: "card-capital-one",
            name: "Capital one",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-09",
            dueDay: 4,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let snapshot = makeSnapshot(creditCards: [card])

        XCTAssertEqual(
            PlannerDerivedData.creditCardNextStatementDate(
                card: card,
                snapshot: snapshot,
                asOfDate: "2026-07-08"
            ),
            "2026-07-09"
        )
        XCTAssertEqual(
            PlannerDerivedData.creditCardNextStatementDate(
                card: card,
                snapshot: snapshot,
                asOfDate: "2026-07-09"
            ),
            "2026-08-09"
        )
    }

    @MainActor
    func testAddingCreditCardDerivesFirstStatementDateFromStatementDayAndToday() async {
        let settings = makeManualSettings(today: "2026-06-05")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings)))

        await store.load()
        store.addCreditCard(
            name: "Everyday",
            provider: "Test Bank",
            limitPence: 50000,
            openingBalancePence: 10000,
            openingStatementBalancePence: nil,
            statementDay: 12,
            dueDay: 1,
            dueDate: nil,
            color: "#2563eb"
        )

        XCTAssertEqual(store.snapshot.creditCards.first?.statementDate, "2026-06-12")
        XCTAssertEqual(store.snapshot.creditCards.first?.dueDay, 1)
        XCTAssertEqual(store.snapshot.creditCards.first?.openingStatementBalancePence, 10000)
    }

    @MainActor
    func testAddingCreditCardWithExistingStatementDueUsesTheMostRecentStatementCycle() async {
        let settings = makeManualSettings(today: "2026-07-09")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings)))

        await store.load()
        store.addCreditCard(
            name: "Jaja",
            provider: "Jaja",
            limitPence: 25000,
            openingBalancePence: 21580,
            openingStatementBalancePence: 21580,
            statementDay: 7,
            dueDay: 3,
            dueDate: nil,
            color: "#000000"
        )

        let card = try! XCTUnwrap(store.snapshot.creditCards.first)
        XCTAssertEqual(card.statementDate, "2026-07-07")
        XCTAssertEqual(
            PlannerDerivedData.creditCardOpeningBalanceDirectDebitDate(card: card, today: "2026-07-09"),
            "2026-08-03"
        )

        let payments = PlannerDerivedData.creditCardStatementPayments(
            card: card,
            snapshot: store.snapshot,
            startDate: "2026-07-09",
            endDate: "2026-08-31",
            asOfDate: "2026-07-09"
        )
        XCTAssertEqual(payments.first?.statementDate, "2026-07-07")
        XCTAssertEqual(payments.first?.directDebitDate, "2026-08-03")
        XCTAssertEqual(payments.first?.actualDuePence, 21580)
    }

    func testLinkedCardUpcomingPaymentsRollFromFrozenStatementToLiveNextCycleSpend() {
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-03",
            dueDay: 20,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 55_000,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let postStatementSpend = makeTransaction(
            id: "aqua-post-statement-spend",
            cardId: card.id,
            amountPence: 5_000,
            date: "2026-08-04",
            note: "Post-statement spend"
        )
        let plannedCharge = CustomPayment(
            id: "aqua-future-charge",
            name: "Future card charge",
            amountPence: 7_000,
            dueDate: "2026-08-15",
            creditCardId: card.id,
            status: .unpaid,
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let augustCycle = CreditCardCycleOverride(
            id: "aqua-august-cycle",
            creditCardId: card.id,
            scheduledStatementDate: "2026-08-03",
            statementState: .confirmed,
            actualStatementDate: "2026-08-03",
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 50_000,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-03T00:00:00.000Z",
            updatedAt: "2026-08-03T00:00:00.000Z",
            deletedAt: nil
        )
        var snapshot = makeSnapshot(
            pots: [pot],
            transactions: [postStatementSpend],
            creditCards: [card],
            customPayments: [plannedCharge],
            creditCardCycleOverrides: [augustCycle]
        )

        XCTAssertEqual(
            PlannerDerivedData.potProgress(
                pot: pot,
                snapshot: snapshot,
                today: "2026-08-10"
            ).linkedCardPayments,
            [
                LinkedCardPaymentDue(
                    cardId: card.id,
                    cardName: card.name,
                    statementIso: "2026-08-03",
                    dueIso: "2026-08-20",
                    amountPence: 50_000
                ),
                LinkedCardPaymentDue(
                    cardId: card.id,
                    cardName: card.name,
                    statementIso: "2026-09-03",
                    dueIso: "2026-09-20",
                    amountPence: 5_000
                )
            ]
        )

        snapshot.creditCardRepayments = [
            CreditCardRepayment(
                id: "aqua-august-repayment",
                creditCardId: card.id,
                amountPence: 50_000,
                date: "2026-08-20",
                note: "Aqua statement payment",
                statementDate: "2026-08-03",
                directDebitDate: "2026-08-20",
                source: .linkedPotStatement,
                potId: pot.id,
                potContributionPence: 50_000,
                paycheckContributionPence: 0,
                createdAt: "2026-08-20T00:00:00.000Z",
                updatedAt: "2026-08-20T00:00:00.000Z",
                deletedAt: nil
            )
        ]

        XCTAssertEqual(
            PlannerDerivedData.potProgress(
                pot: pot,
                snapshot: snapshot,
                today: "2026-08-20"
            ).linkedCardPayments,
            [
                LinkedCardPaymentDue(
                    cardId: card.id,
                    cardName: card.name,
                    statementIso: "2026-09-03",
                    dueIso: "2026-09-20",
                    amountPence: 5_000
                )
            ]
        )

        snapshot.creditCardCycleOverrides.append(
            CreditCardCycleOverride(
                id: "aqua-september-cycle",
                creditCardId: card.id,
                scheduledStatementDate: "2026-09-03",
                statementState: .confirmed,
                actualStatementDate: "2026-09-05",
                directDebitState: .confirmed,
                actualDirectDebitDate: "2026-09-22",
                amountPenceOverride: 5_000,
                reversedAutomaticRepaymentIds: [],
                createdAt: "2026-09-05T00:00:00.000Z",
                updatedAt: "2026-09-05T00:00:00.000Z",
                deletedAt: nil
            )
        )

        XCTAssertEqual(
            PlannerDerivedData.potProgress(
                pot: pot,
                snapshot: snapshot,
                today: "2026-08-21"
            ).linkedCardPayments.first,
            LinkedCardPaymentDue(
                cardId: card.id,
                cardName: card.name,
                statementIso: "2026-09-05",
                dueIso: "2026-09-22",
                amountPence: 5_000
            )
        )
    }

    func testStatementDueSubtractsRepaymentsAlreadyAssignedToThatStatement() {
        let card = makeCreditCard(
            id: "card-main",
            name: "CC1",
            limitPence: 100000,
            openingBalancePence: 50000,
            openingStatementBalancePence: 50000,
            statementDate: "2026-07-05",
            dueDay: 2,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let chatGPT = makeTransaction(
            id: "card-recurring-rec-chatgpt-2026-07-01",
            cardId: card.id,
            amountPence: 7500,
            date: "2026-07-01",
            note: "ChatGPT"
        )
        let openingRepayment = CreditCardRepayment(
            id: "card-opening-balance-repayment-card-main-2026-07-02",
            creditCardId: card.id,
            amountPence: 50000,
            date: "2026-07-02",
            note: "CC1 direct debit",
            statementDate: "2026-07-05",
            directDebitDate: "2026-07-02",
            source: .linkedPotStatement,
            potId: "pot-card",
            potContributionPence: 50000,
            paycheckContributionPence: 0,
            createdAt: "2026-07-02T00:00:00.000Z",
            updatedAt: "2026-07-02T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(transactions: [chatGPT], creditCards: [card], creditCardRepayments: [openingRepayment])

        let payments = PlannerDerivedData.creditCardStatementPayments(
            card: card,
            snapshot: snapshot,
            startDate: "2026-07-01",
            endDate: "2026-08-02",
            asOfDate: "2026-08-02"
        )

        let julyStatement = payments.first { $0.statementDate == "2026-07-05" }
        XCTAssertEqual(julyStatement?.directDebitDate, "2026-08-02")
        XCTAssertEqual(julyStatement?.actualDuePence, 7500)
    }

    func testDeletedCardChargeDoesNotSuppressReplacementRecurringForecast() throws {
        let card = makeCreditCard(
            id: "card-main", name: "Card", openingBalancePence: 0, openingStatementBalancePence: 0,
            statementDate: "2026-09-01", dueDay: 5, createdAt: "2026-08-01T00:00:00.000Z"
        )
        let bill = makeRecurringPayment(id: "bill", name: "Subscription", amountPence: 20_000, dueDay: 21, potId: nil, creditCardId: card.id)
        var deleted = makeTransaction(id: "deleted", cardId: card.id, amountPence: 20_000, date: "2026-08-21", note: "Subscription")
        deleted.recurringPaymentId = bill.id
        deleted.deletedAt = "2026-08-19T00:00:00.000Z"
        let snapshot = makeSnapshot(recurringPayments: [bill], transactions: [deleted], creditCards: [card])
        let payment = try XCTUnwrap(PlannerDerivedData.creditCardStatementPayments(
            card: card, snapshot: snapshot, startDate: "2026-08-20", endDate: "2026-09-05", asOfDate: "2026-08-20"
        ).first)
        XCTAssertEqual(payment.actualDuePence, 0)
        XCTAssertEqual(payment.forecastDuePence, 20_000)
    }

    func testForecastStatementDoesNotReviveOpeningStatementAboveLiveOpeningBalance() throws {
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
        let transactions = [
            makeTransaction(
                id: "capital-two-chatgpt",
                cardId: card.id,
                amountPence: 20_000,
                date: "2026-08-21",
                note: "ChatGPT"
            ),
            makeTransaction(
                id: "capital-two-tesco",
                cardId: card.id,
                amountPence: 8_623,
                date: "2026-08-22",
                note: "Tesco"
            )
        ]
        let snapshot = makeSnapshot(
            settings: makeManualSettings(today: "2026-08-29"),
            transactions: transactions,
            creditCards: [card]
        )

        let payment = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementPayments(
                card: card,
                snapshot: snapshot,
                startDate: "2026-08-29",
                endDate: "2026-09-05",
                asOfDate: "2026-08-29"
            ).first
        )

        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: snapshot), 28_623)
        XCTAssertEqual(payment.forecastDuePence, 28_623)
    }

    @MainActor
    func testCreatedCreditCardStatementSummariesIncludeTransactionsAndStatuses() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))

        XCTAssertTrue(PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-07-04").isEmpty)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)

        var statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-07-15")
        let cc1Statement = try XCTUnwrap(statements.first { $0.cardId == "card-cc1" && $0.statementDate == "2026-07-05" })
        XCTAssertEqual(cc1Statement.cardName, "CC1")
        XCTAssertEqual(cc1Statement.directDebitDate, "2026-08-02")
        XCTAssertEqual(cc1Statement.statementAmountPence, 57500)
        XCTAssertEqual(cc1Statement.paidAmountPence, 50000)
        XCTAssertEqual(cc1Statement.unpaidAmountPence, 7500)
        XCTAssertEqual(cc1Statement.status, .upcoming)
        XCTAssertEqual(cc1Statement.transactions.map(\.name), ["ChatGPT", "Opening statement balance"])
        XCTAssertEqual(cc1Statement.transactions.map(\.date), ["2026-07-01", "2026-07-05"])
        XCTAssertEqual(cc1Statement.transactions.map(\.amountPence), [7500, 50000])
        XCTAssertEqual(cc1Statement.transactions.map(\.source), [.recurring, .openingStatement])

        let cc2Statement = try XCTUnwrap(statements.first { $0.cardId == "card-cc2" && $0.statementDate == "2026-07-15" })
        XCTAssertEqual(cc2Statement.directDebitDate, "2026-08-10")
        XCTAssertEqual(cc2Statement.statementAmountPence, 10000)
        XCTAssertEqual(cc2Statement.status, .upcoming)
        XCTAssertEqual(cc2Statement.transactions.map(\.name), ["Insurance"])

        let repayment = CreditCardRepayment(
            id: "repay-cc1-july",
            creditCardId: "card-cc1",
            amountPence: 57500,
            date: "2026-08-02",
            note: "CC1 direct debit",
            statementDate: "2026-07-05",
            directDebitDate: "2026-08-02",
            source: .automaticStatement,
            potId: nil,
            potContributionPence: 0,
            paycheckContributionPence: 57500,
            createdAt: "2026-08-02T00:00:00.000Z",
            updatedAt: "2026-08-02T00:00:00.000Z",
            deletedAt: nil
        )
        var paidSnapshot = store.snapshot
        paidSnapshot.creditCardRepayments.append(repayment)
        statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: paidSnapshot, asOfDate: "2026-08-02")
        XCTAssertEqual(statements.first { $0.cardId == "card-cc1" && $0.statementDate == "2026-07-05" }?.status, .paid)

        statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-08-11")
        XCTAssertEqual(statements.first { $0.cardId == "card-cc2" && $0.statementDate == "2026-07-15" }?.status, .overdue)
    }

    func testStatementSummaryIncludesSavedOpeningStatementBalanceAfterCardWasCreated() {
        let card = makeCreditCard(
            id: "card-barclaycard",
            name: "Barclaycard",
            limitPence: 80_000,
            openingBalancePence: 65_443,
            openingStatementBalancePence: 65_443,
            statementDate: "2026-07-13",
            dueDay: 6,
            createdAt: "2026-07-10T20:41:58.377Z"
        )
        let iCloud = makeTransaction(
            id: "transaction-icloud",
            cardId: card.id,
            amountPence: 899,
            date: "2026-07-10",
            note: "iCloud+"
        )
        let snapshot = makeSnapshot(transactions: [iCloud], creditCards: [card])

        let statement = PlannerDerivedData.creditCardStatementSummaries(
            snapshot: snapshot,
            asOfDate: "2026-07-13"
        ).first

        XCTAssertEqual(statement?.statementAmountPence, 66_342)
        XCTAssertEqual(statement?.unpaidAmountPence, 66_342)
        XCTAssertEqual(statement?.directDebitDate, "2026-08-06")
        XCTAssertEqual(statement?.transactions.map(\.name), ["iCloud+", "Opening statement balance"])
        XCTAssertEqual(statement?.transactions.map(\.amountPence), [899, 65_443])
        XCTAssertEqual(statement?.transactions.map(\.source), [.spending, .openingStatement])
    }

    func testCreditCardDirectDebitCanFallOnStatementDay() {
        XCTAssertEqual(
            PlannerDerivedData.creditCardDirectDebitDate(statementDate: "2026-07-02", dueDay: 2),
            "2026-07-02"
        )
    }

    @MainActor
    func testAutomaticCardStatementRepaymentWithoutLinkedPotChargesDirectDebitPayPeriod() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let card = makeCreditCard(
            id: "card-everyday",
            name: "Everyday",
            openingBalancePence: 10000,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-12",
            dueDay: 1,
            createdAt: "2026-06-05T09:00:00.000Z"
        )
        let period = makePayPeriod(id: "period-july", startDate: "2026-06-26", endDate: "2026-07-09", payday: "2026-06-26", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, payPeriods: [period], creditCards: [card])))

        await store.load()

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.id, "card-statement-repayment-card-everyday-2026-06-12-2026-07-01")
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.date, "2026-07-01")
        XCTAssertEqual(repayment?.source, .automaticStatement)
        XCTAssertEqual(repayment?.potContributionPence, 0)
        XCTAssertEqual(repayment?.paycheckContributionPence, 10000)

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.creditCardRepaymentsPence, 10000)
        XCTAssertEqual(summary.totalCostsPence, 10000)
        XCTAssertEqual(summary.moneyLeftPence, 40000)
    }

    @MainActor
    func testLinkedCreditCardPotFullyCoversStatementRepaymentWithoutPaycheckCost() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let card = makeCreditCard(
            id: "card-everyday",
            name: "Everyday",
            openingBalancePence: 10000,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-12",
            dueDay: 1,
            createdAt: "2026-06-05T09:00:00.000Z"
        )
        let pot = makePot(id: "pot-everyday", name: "Everyday", balancePence: 10000, targetPence: nil, linkedCreditCardId: card.id)
        let period = makePayPeriod(id: "period-july", startDate: "2026-06-26", endDate: "2026-07-09", payday: "2026-06-26", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], creditCards: [card])))

        await store.load()

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potId, pot.id)
        XCTAssertEqual(repayment?.potContributionPence, 10000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.creditCardRepaymentsPence, 0)
        XCTAssertEqual(summary.totalCostsPence, 0)
        XCTAssertEqual(summary.moneyLeftPence, 50000)
    }

    @MainActor
    func testLinkedCreditCardPotPartialCoverSplitsPotAndPaycheckContributionsWithoutDuplicates() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let card = makeCreditCard(
            id: "card-everyday",
            name: "Everyday",
            openingBalancePence: 10000,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-12",
            dueDay: 1,
            createdAt: "2026-06-05T09:00:00.000Z"
        )
        let pot = makePot(id: "pot-everyday", name: "Everyday", balancePence: 4000, targetPence: nil, linkedCreditCardId: card.id)
        let period = makePayPeriod(id: "period-july", startDate: "2026-06-26", endDate: "2026-07-09", payday: "2026-06-26", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], creditCards: [card])))

        await store.load()
        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 4000)
        XCTAssertEqual(repayment?.paycheckContributionPence, 6000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(store.snapshot.creditCardRepayments.count, 1)

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.creditCardRepaymentsPence, 6000)
        XCTAssertEqual(summary.totalCostsPence, 6000)
        XCTAssertEqual(summary.moneyLeftPence, 44000)
    }

    func testPostStatementOpeningBalanceDifferenceUsesTheFollowingStatementCycle() {
        let settings = makeManualSettings(today: "2026-07-10")
        let period = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 226191
        )
        let card = makeCreditCard(
            id: "card-aqua",
            name: "Aqua",
            openingBalancePence: 31430,
            openingStatementBalancePence: 30731,
            statementDate: "2026-07-02",
            dueDay: 20
        )
        let pot = makePot(
            id: "pot-aqua",
            name: "Aqua",
            balancePence: 30710,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            creditCards: [card]
        )

        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: period)
        let paymentItems = PlannerDerivedData.cardPaymentFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: period,
            asOfDate: "2026-07-10"
        )

        XCTAssertEqual(openingItems.first?.amountPence, 21)
        XCTAssertEqual(openingItems.first?.directDebitDate, "2026-07-20")
        XCTAssertEqual(paymentItems.first?.amountPence, 699)
        XCTAssertEqual(paymentItems.first?.directDebitDate, "2026-08-20")

        let presentationItem = try! XCTUnwrap(
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
        XCTAssertEqual(presentationItem.breakdown.reduce(0) { $0 + $1.amountPence }, 699)
    }

    @MainActor
    func testExistingStatementDueUsesNextDueDayRatherThanNextStatementCycle() async {
        let settings = makeManualSettings(today: "2026-07-01")
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(id: "card-main", name: "CC1", openingBalancePence: 57500, openingStatementBalancePence: 57500, statementDate: "2026-07-05", dueDay: 2)
        let linkedPot = makePot(id: "pot-card", name: "1", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [linkedPot], payPeriods: [period], creditCards: [card])))

        await store.load()

        let items = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: store.selectedPayPeriod)
        XCTAssertEqual(items.map(\.id), ["card-opening-balance-funding-card-main-2026-07-02"])
        XCTAssertEqual(items.first?.amountPence, 57500)
        XCTAssertEqual(items.first?.potName, "1")
        XCTAssertEqual(items.first?.directDebitDate, "2026-07-02")

        XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: card.id, directDebitDate: "2026-07-02", payPeriodId: period.id, completed: true))
        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-07-02"
        store.updateSettings(dueSettings)

        let repayment = store.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 57500)
        XCTAssertEqual(repayment?.date, "2026-07-02")
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 57500)
        XCTAssertEqual(repayment?.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testVitaminsCardBillKeepsReserveUntilStatementDirectDebit() async {
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let card = makeCreditCard(
            id: "card-zable",
            name: "Zable",
            limitPence: 50000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-07-24",
            dueDay: 1,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(id: "pot-zable", name: "Zable", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let vitamins = makeRecurringPayment(
            id: "rec-vitamins",
            name: "Vitamins",
            amountPence: 2212,
            dueDay: 11,
            potId: pot.id,
            creditCardId: card.id,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: makeManualSettings(today: "2026-07-10"),
            pots: [pot],
            recurringPayments: [vitamins],
            payPeriods: [period],
            creditCards: [card]
        )))

        await store.load()
        XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: vitamins.id, dueDate: "2026-07-11", payPeriodId: period.id, completed: true))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 2212)

        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-07-11"
        store.updateSettings(dueSettings)

        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 2212)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 2212)
        let progress = PlannerDerivedData.potProgress(pot: try! XCTUnwrap(store.snapshot.pots.first), snapshot: store.snapshot, today: "2026-07-11")
        XCTAssertEqual(progress.targetPence, 2212)
        XCTAssertEqual(progress.shortfallPence, 0)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-vitamins-2026-07-11" }.count, 1)

        var statementSettings = store.snapshot.settings
        statementSettings.manualTodayIso = "2026-07-24"
        store.updateSettings(statementSettings)
        XCTAssertTrue(store.snapshot.creditCardRepayments.isEmpty)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 2212)

        var directDebitSettings = store.snapshot.settings
        directDebitSettings.manualTodayIso = "2026-08-01"
        store.updateSettings(directDebitSettings)

        let repayment = try! XCTUnwrap(store.snapshot.creditCardRepayments.first)
        XCTAssertEqual(repayment.amountPence, 2212)
        XCTAssertEqual(repayment.statementDate, "2026-07-24")
        XCTAssertEqual(repayment.directDebitDate, "2026-08-01")
        XCTAssertEqual(repayment.potContributionPence, 2212)
        XCTAssertEqual(repayment.paycheckContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-08-01"))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-vitamins-2026-07-11" }.count, 1)
        XCTAssertEqual(store.snapshot.creditCardRepayments.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    @MainActor
    func testUnfundedCardBillPostsAndKeepsLinkedPotShortfallOpen() async {
        let settingsBeforeDue = makeManualSettings(today: "2026-06-30")
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
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settingsBeforeDue, pots: [pot], recurringPayments: [bill], payPeriods: [period], creditCards: [card])))

        await store.load()
        var dueSettings = store.snapshot.settings
        dueSettings.manualTodayIso = "2026-07-01"
        store.updateSettings(dueSettings)

        let transaction = store.snapshot.transactions.first(where: { $0.id == "card-recurring-rec-bill-2026-07-01" })
        XCTAssertEqual(transaction?.paymentMethod, .creditCard)
        XCTAssertEqual(transaction?.potId, nil)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(availability.actualAvailablePence, 40000)
        let progress = PlannerDerivedData.potProgress(pot: store.snapshot.pots[0], snapshot: store.snapshot, today: "2026-07-01")
        XCTAssertEqual(progress.shortfallPence, 10000)
        let checklist = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(checklist.first?.isCompleted, false)
    }

    func testRecurringAndCardAmountOverridesApplyOnlyToSelectedScheduledCycle() {
        var snapshot = makeSnapshot(
            recurringPayments: [makeRecurringPayment(id: "bill", name: "Energy", amountPence: 4000, dueDay: 10, potId: nil)],
            creditCards: [makeCreditCard(id: "card", name: "Main", openingBalancePence: 20000, openingStatementBalancePence: 20000, statementDate: "2026-07-10", dueDay: 11)]
        )
        snapshot.recurringPaymentOccurrenceOverrides = [RecurringPaymentOccurrenceOverride(id: "bill-override", paymentId: "bill", scheduledDueDate: "2026-07-10", state: .confirmed, actualDueDate: "2026-07-11", amountPenceOverride: 5500, reversedGeneratedTransactionIds: [], createdAt: "2026-07-01", updatedAt: "2026-07-01", deletedAt: nil)]
        snapshot.creditCardCycleOverrides = [CreditCardCycleOverride(id: "card-override", creditCardId: "card", scheduledStatementDate: "2026-07-10", statementState: .normal, actualStatementDate: nil, directDebitState: .normal, actualDirectDebitDate: nil, amountPenceOverride: 12345, reversedAutomaticRepaymentIds: [], createdAt: "2026-07-01", updatedAt: "2026-07-01", deletedAt: nil)]

        let bills = PlannerDerivedData.resolvedRecurringOccurrences(snapshot: snapshot, payments: snapshot.recurringPayments, startDate: "2026-07-01", endDate: "2026-08-31")
        XCTAssertEqual(bills.first { $0.scheduledDueDate == "2026-07-10" }?.dueDate, "2026-07-11")
        XCTAssertEqual(bills.first { $0.scheduledDueDate == "2026-07-10" }?.amountPence, 5500)
        XCTAssertEqual(bills.first { $0.scheduledDueDate == "2026-08-10" }?.amountPence, 4000)

        let card = snapshot.creditCards[0]
        let cardPayments = PlannerDerivedData.creditCardStatementPayments(card: card, snapshot: snapshot, startDate: "2026-07-01", endDate: "2026-09-30", asOfDate: "2026-07-01")
        XCTAssertEqual(cardPayments.first { $0.scheduledStatementDate == "2026-07-10" }?.actualDuePence, 12345)
        XCTAssertEqual(cardPayments.first { $0.scheduledStatementDate == "2026-07-10" }?.forecastDuePence, 12345)
        XCTAssertNotEqual(cardPayments.first { $0.scheduledStatementDate == "2026-08-10" }?.forecastDuePence, 12345)
    }

    @MainActor
    func testConfirmedAquaAndJajaCreditScreensRenderAtNormalAndAccessibilitySizes() throws {
        let settings = makeManualSettings(today: "2026-08-08")
        let augustPeriod = makePayPeriod(
            id: "period-august-visual",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 200_000
        )
        let aqua = makeCreditCard(
            id: "card-aqua-visual",
            name: "AQUA",
            limitPence: 130_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-02",
            dueDay: 20,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let jaja = makeCreditCard(
            id: "card-jaja-visual",
            name: "JAJA",
            limitPence: 25_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-07",
            dueDay: 3,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let aquaPot = makePot(
            id: "pot-aqua-visual",
            name: "Aqua payment",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: aqua.id
        )
        let jajaPot = makePot(
            id: "pot-jaja-visual",
            name: "Jaja payment",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: jaja.id
        )
        let aquaTransaction = makeTransaction(
            id: "transaction-aqua-visual",
            cardId: aqua.id,
            amountPence: 8_216,
            date: "2026-08-02",
            note: "Tracked Aqua spending"
        )
        let jajaTransaction = makeTransaction(
            id: "transaction-jaja-visual",
            cardId: jaja.id,
            amountPence: 129,
            date: "2026-08-07",
            note: "Tracked Jaja spending"
        )
        let aquaPostStatementTransaction = makeTransaction(
            id: "transaction-aqua-next-cycle-visual",
            cardId: aqua.id,
            amountPence: 87_305,
            date: "2026-08-04",
            note: "Aqua next-cycle spending"
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [aquaPot, jajaPot],
            payPeriods: [augustPeriod],
            transactions: [aquaTransaction, aquaPostStatementTransaction, jajaTransaction],
            creditCards: [aqua, jaja],
            creditCardCycleOverrides: [
                CreditCardCycleOverride(
                    id: "override-aqua-visual",
                    creditCardId: aqua.id,
                    scheduledStatementDate: "2026-08-02",
                    statementState: .confirmed,
                    actualStatementDate: "2026-08-03",
                    directDebitState: .normal,
                    actualDirectDebitDate: nil,
                    amountPenceOverride: 69_588,
                    reversedAutomaticRepaymentIds: [],
                    createdAt: "2026-08-03T00:00:00.000Z",
                    updatedAt: "2026-08-03T00:00:00.000Z",
                    deletedAt: nil
                ),
                CreditCardCycleOverride(
                    id: "override-jaja-visual",
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
            ]
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)
        let summaries = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: "2026-08-08")
        let aquaSummary = try XCTUnwrap(summaries.first { $0.cardId == aqua.id })
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: aqua, snapshot: snapshot), 156_893)
        XCTAssertEqual(aquaSummary.calculatedAmountPence, 8_216)
        XCTAssertEqual(aquaSummary.statementAmountPence, 69_588)
        let aquaNextStatementDate = try XCTUnwrap(
            PlannerDerivedData.creditCardNextStatementDate(
                card: aqua,
                snapshot: snapshot,
                asOfDate: "2026-08-08"
            )
        )
        let originalTheme = UserDefaults.standard.string(forKey: AppTheme.selectedPresetStorageKey)
        defer {
            if let originalTheme {
                UserDefaults.standard.set(originalTheme, forKey: AppTheme.selectedPresetStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: AppTheme.selectedPresetStorageKey)
            }
        }

        for preset in AppThemePreset.allCases {
            UserDefaults.standard.set(preset.rawValue, forKey: AppTheme.selectedPresetStorageKey)
            for configuration in [
                (name: "normal", size: DynamicTypeSize.large),
                (name: "accessibility", size: DynamicTypeSize.accessibility3)
            ] {
                let suffix = "\(preset.rawValue)-\(configuration.name)"
                attachCreditRender(
                    CardDetailView(store: store, card: aqua),
                    name: "credit-card-\(suffix)",
                    dynamicTypeSize: configuration.size,
                    colorScheme: preset.palette.preferredColorScheme
                )
                attachCreditRender(
                    NavigationStack {
                        CreditScheduleDetailView(store: store, schedule: .directDebits)
                    },
                    name: "credit-direct-debits-\(suffix)",
                    dynamicTypeSize: configuration.size,
                    colorScheme: preset.palette.preferredColorScheme
                )
                attachCreditRender(
                    NavigationStack {
                        CreditScheduleDetailView(store: store, schedule: .statements)
                    },
                    name: "credit-statements-\(suffix)",
                    dynamicTypeSize: configuration.size,
                    colorScheme: preset.palette.preferredColorScheme
                )
                attachCreditRender(
                    NavigationStack {
                        CreditStatementLedgerDetailView(
                            store: store,
                            identity: .init(cardId: aqua.id, scheduledStatementDate: aquaNextStatementDate),
                            mode: .currentStatement
                        )
                    },
                    name: "credit-current-statement-\(suffix)",
                    dynamicTypeSize: configuration.size,
                    colorScheme: preset.palette.preferredColorScheme
                )
                attachCreditRender(
                    NavigationStack {
                        CreditStatementLedgerDetailView(
                            store: store,
                            identity: .init(cardId: aqua.id, scheduledStatementDate: aquaSummary.scheduledStatementDate),
                            mode: .previousStatement
                        )
                    },
                    name: "credit-previous-statement-\(suffix)",
                    dynamicTypeSize: configuration.size,
                    colorScheme: preset.palette.preferredColorScheme
                )
            }
        }
    }

    @MainActor
    func testConfirmedBankCycleRepaysFullRemainingCashObligationBeyondTrackedCardBalance() throws {
        let settings = makeManualSettings(today: "2026-09-03")
        let septemberPeriod = makePayPeriod(
            id: "period-september",
            startDate: "2026-09-01",
            endDate: "2026-09-30",
            payday: "2026-09-01",
            incomePence: 100_000
        )
        let card = makeCreditCard(
            id: "card-jaja",
            name: "Jaja",
            limitPence: 25_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-07",
            dueDay: 3,
            createdAt: "2026-07-01T00:00:00.000Z"
        )
        let pot = makePot(
            id: "pot-jaja",
            name: "Jaja",
            balancePence: 1_000,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let trackedSpend = makeTransaction(
            id: "transaction-jaja-tracked",
            cardId: card.id,
            amountPence: 129,
            date: "2026-08-07",
            note: "Tracked Jaja spending"
        )
        let partialPayment = CreditCardRepayment(
            id: "manual-jaja-partial",
            creditCardId: card.id,
            amountPence: 500,
            date: "2026-08-20",
            note: "Partial payment",
            source: .manual,
            paycheckContributionPence: 500,
            createdAt: "2026-08-20T00:00:00.000Z",
            updatedAt: "2026-08-20T00:00:00.000Z",
            deletedAt: nil
        )
        let refundedPayment = CreditCardRepayment(
            id: "manual-jaja-refunded",
            creditCardId: card.id,
            amountPence: 700,
            date: "2026-08-21",
            note: "Refunded payment",
            source: .manual,
            paycheckContributionPence: 700,
            refundedAt: "2026-08-22T00:00:00.000Z",
            createdAt: "2026-08-21T00:00:00.000Z",
            updatedAt: "2026-08-22T00:00:00.000Z",
            deletedAt: nil
        )
        let cycleOverride = CreditCardCycleOverride(
            id: "override-jaja-2026-08-07",
            creditCardId: card.id,
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
            pots: [pot],
            payPeriods: [septemberPeriod],
            transactions: [trackedSpend],
            creditCards: [card],
            creditCardRepayments: [partialPayment, refundedPayment],
            creditCardCycleOverrides: [cycleOverride]
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)
        let cashBeforePayment = PlannerDerivedData.currentTotalMoneyPence(
            snapshot: store.snapshot,
            payPeriod: septemberPeriod
        )

        let beforePayment = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementPayments(
                card: card,
                snapshot: store.snapshot,
                startDate: "2026-09-03",
                endDate: "2026-09-03",
                asOfDate: "2026-09-03"
            ).first
        )
        XCTAssertEqual(beforePayment.actualDuePence, 1_928)
        XCTAssertEqual(
            PlannerDerivedData.homeDueEvents(snapshot: store.snapshot, asOfDate: "2026-09-03")
                .first { event in
                    if case .cardDirectDebit(let cardId, _) = event.source {
                        return cardId == card.id
                    }
                    return false
                }?
                .amountPence,
            1_928
        )

        XCTAssertTrue(store.applyDueCreditCardPaymentsForSimulation(asOf: "2026-09-03"))
        XCTAssertFalse(store.applyDueCreditCardPaymentsForSimulation(asOf: "2026-09-03"))

        let automaticPayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.source == .linkedPotStatement || $0.source == .automaticStatement
        })
        XCTAssertEqual(automaticPayment.amountPence, 1_928)
        XCTAssertEqual(automaticPayment.potContributionPence, 1_000)
        XCTAssertEqual(automaticPayment.paycheckContributionPence, 928)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 0)
        XCTAssertEqual(
            PlannerDerivedData.currentTotalMoneyPence(snapshot: store.snapshot, payPeriod: septemberPeriod),
            cashBeforePayment - 1_928
        )

        let summary = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementSummaries(
                snapshot: store.snapshot,
                asOfDate: "2026-09-03"
            ).first
        )
        XCTAssertEqual(summary.statementAmountPence, 2_428)
        XCTAssertEqual(summary.paidAmountPence, 2_428)
        XCTAssertEqual(summary.unpaidAmountPence, 0)
        XCTAssertEqual(summary.status, .paid)
    }

    @MainActor
    func testStoreRecordsAndReversesAnEditedCardPayment() async {
        let card = makeCreditCard(
            id: "audit-card",
            name: "Barclays",
            limitPence: 100_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-13",
            dueDay: 19
        )
        let original = makeTransaction(id: "audit-payment", cardId: card.id, amountPence: 3_500, date: "2026-08-24", note: "MMA Gear")
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: makeSnapshot(transactions: [original], creditCards: [card])))
        await store.load()

        store.updateTransaction(
            id: original.id,
            potId: nil,
            creditCardId: card.id,
            paymentMethod: .creditCard,
            amountPence: 3_747,
            date: original.date,
            note: original.note
        )

        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == original.id })?.amountPence, 3_747)
        XCTAssertEqual(store.auditAction(for: .transaction, id: original.id), .edited)
        XCTAssertTrue(store.reverseLatestEdit(for: .transaction, id: original.id))
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == original.id })?.amountPence, 3_500)
        XCTAssertEqual(store.auditAction(for: .transaction, id: original.id), .reverted)
    }

    func testCreditScheduleModelsUseStableCardAndScheduledStatementIdentity() {
        let directDebit = CreditDueItem(
            id: "statement-card-aqua-2026-09-03",
            title: "Aqua direct debit",
            date: "2026-09-20",
            amountPence: 69_588,
            isOverdue: false,
            cardId: "card-aqua",
            scheduledStatementDate: "2026-09-03"
        )
        let current = CreditNextStatementItem(
            cardId: "card-aqua",
            scheduledStatementDate: "2026-10-03",
            cardName: "Aqua",
            statementDate: "2026-10-03",
            amountPence: 7_699,
            movementCount: 3
        )

        XCTAssertEqual(directDebit.cardId, "card-aqua")
        XCTAssertEqual(directDebit.scheduledStatementDate, "2026-09-03")
        XCTAssertEqual(current.id, "card-aqua-2026-10-03")
        XCTAssertEqual(current.amountPence, 7_699)
        XCTAssertEqual(current.movementCount, 3)
    }

    func testStatementReconciliationBalancesTrackedAdjustmentsPaymentsAndOutstanding() throws {
        let card = makeCreditCard(
            id: "card-reconcile",
            name: "Aqua",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-03",
            dueDay: 20
        )
        let transaction = makeTransaction(
            id: "reconcile-spend",
            cardId: card.id,
            amountPence: 8_216,
            date: "2026-08-02",
            note: "Tracked"
        )
        let override = CreditCardCycleOverride(
            id: "reconcile-cycle",
            creditCardId: card.id,
            scheduledStatementDate: "2026-08-03",
            statementState: .confirmed,
            actualStatementDate: "2026-08-03",
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 69_588,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-03T00:00:00.000Z",
            updatedAt: "2026-08-03T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(transactions: [transaction], creditCards: [card], creditCardCycleOverrides: [override])
        let statement = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: "2026-08-08").first
        )

        XCTAssertEqual(statement.calculatedAmountPence + statement.reconciliationAdjustmentPence, statement.statementAmountPence)
        XCTAssertEqual(statement.statementAmountPence - statement.paidAmountPence, statement.unpaidAmountPence)
    }
}
