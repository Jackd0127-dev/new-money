import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    @MainActor
    func testBankAccountBalanceTracksLinkedIncomeSpendingRefundsAndReconciliation() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings)))
        await store.load()

        XCTAssertTrue(
            store.addBankAccount(
                name: "Main account",
                provider: "Test Bank",
                type: .current,
                currentBalancePence: 100_000,
                lastFourDigits: "1234",
                color: "#2563EB",
                isPrimary: true
            )
        )
        let account = try! XCTUnwrap(store.activeBankAccounts.first)

        store.createPayPeriod(
            payday: "2026-06-01",
            hoursWorked: 2000,
            hourlyRatePence: 100,
            actualAmountPence: 200_000,
            payFrequency: .monthly,
            bankAccountId: account.id
        )
        XCTAssertTrue(store.addOneOffIncome(name: "Refund", amountPence: 5_000, date: "2026-06-01", note: "", bankAccountId: account.id))
        store.recordTransaction(
            potId: nil,
            creditCardId: nil,
            bankAccountId: account.id,
            paymentMethod: .bankAccount,
            amountPence: 2_500,
            type: .spending,
            date: "2026-06-01",
            note: "Groceries"
        )

        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            302_500
        )

        let spend = try! XCTUnwrap(store.snapshot.transactions.first { $0.paymentMethod == .bankAccount })
        store.setTransactionRefundAmount(id: spend.id, amountPence: 1_000)
        let partiallyRefundedSpend = try! XCTUnwrap(store.snapshot.transactions.first { $0.id == spend.id })
        XCTAssertTrue(partiallyRefundedSpend.isPartiallyRefunded)
        XCTAssertEqual(partiallyRefundedSpend.effectiveRefundedAmountPence, 1_000)
        XCTAssertEqual(partiallyRefundedSpend.netAmountPence, 1_500)
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            303_500
        )

        store.setTransactionRefunded(id: spend.id, refunded: true)
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot),
            305_000
        )

        var edited = try! XCTUnwrap(store.snapshot.bankAccounts.first { $0.id == account.id })
        edited.name = "Everyday account"
        XCTAssertTrue(store.updateBankAccount(edited, currentBalancePence: 400_000))
        let reconciled = try! XCTUnwrap(store.snapshot.bankAccounts.first { $0.id == account.id })
        XCTAssertEqual(
            PlannerDerivedData.bankAccountBalance(account: reconciled, snapshot: store.snapshot),
            400_000
        )
    }

    @MainActor
    func testPartialCardRepaymentRefundRestoresOnlyTheReturnedPotAmount() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let card = makeCreditCard(
            id: "card-partial-refund",
            name: "Everyday card",
            openingBalancePence: 5_000,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-20",
            dueDay: 1
        )
        let pot = makePot(id: "pot-card-refund", name: "Card pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let repayment = CreditCardRepayment(
            id: "repayment-partial-refund",
            creditCardId: card.id,
            amountPence: 1_000,
            date: "2026-06-01",
            note: "Card payment",
            source: .manual,
            potId: pot.id,
            potContributionPence: 1_000,
            potContributions: [CreditCardPotContribution(potId: pot.id, amountPence: 1_000)],
            paycheckContributionPence: 0,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            creditCards: [card],
            creditCardRepayments: [repayment]
        )))

        await store.load()
        store.setCardRepaymentRefundAmount(id: repayment.id, amountPence: 400)

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 400)
        XCTAssertEqual(store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id })?.netAmountPence, 600)
        XCTAssertTrue(store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id })?.isPartiallyRefunded == true)

        store.setCardRepaymentRefunded(id: repayment.id, refunded: true)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 1_000)
        XCTAssertTrue(store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id })?.isRefunded == true)

        store.setCardRepaymentRefunded(id: repayment.id, refunded: false)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertFalse(store.snapshot.creditCardRepayments.first(where: { $0.id == repayment.id })?.hasRefund == true)
    }

    @MainActor
    func testPartialDebtPaymentRefundRestoresOnlyTheReturnedDebtBalance() async {
        let settings = makeManualSettings(today: "2026-06-01")
        let debt = makeDebt(id: "debt-partial-refund", name: "Loan", currentBalancePence: 10_000, dueDate: "2026-06-30")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, debts: [debt])))

        await store.load()
        store.recordDebtPayment(debtId: debt.id, amountPence: 4_000, date: "2026-06-01", note: "Payment")
        let payment = try! XCTUnwrap(store.snapshot.debtPayments.first)
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 6_000)

        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 1_500)
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 7_500)
        XCTAssertEqual(store.snapshot.debtPayments.first?.netAmountPence, 2_500)
        XCTAssertTrue(store.snapshot.debtPayments.first?.isPartiallyRefunded == true)

        store.setDebtPaymentRefunded(id: payment.id, refunded: true)
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 10_000)
        XCTAssertTrue(store.snapshot.debtPayments.first?.isRefunded == true)

        store.setDebtPaymentRefunded(id: payment.id, refunded: false)
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 6_000)
        XCTAssertFalse(store.snapshot.debtPayments.first?.hasRefund == true)
    }

    @MainActor
    func testActivityPermanentlyDeletesOneOffIncomeInsteadOfLeavingATombstone() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, payPeriods: [period])))

        await store.load()
        XCTAssertTrue(store.addOneOffIncome(name: "Gift", amountPence: 25000, date: "2026-06-10", note: ""))
        let incomeId = try! XCTUnwrap(store.snapshot.oneOffIncomes.first?.id)

        XCTAssertTrue(store.permanentlyDeleteOneOffIncome(id: incomeId))
        XCTAssertFalse(store.snapshot.oneOffIncomes.contains { $0.id == incomeId })
        XCTAssertFalse(store.permanentlyDeleteOneOffIncome(id: incomeId))
    }

    @MainActor
    func testPotsHistoryDeletesOnlyManualAllocationAndReversesItsBalance() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 15000, targetPence: nil)
        let manualAllocation = makePotAllocation(
            id: "allocation-manual",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 10000,
            source: .manual,
            recurringPaymentId: nil,
            recurringDueDate: nil
        )
        let automaticAllocation = makePotAllocation(
            id: "allocation-recurring",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 5000,
            source: .recurring,
            recurringPaymentId: "bill-rent",
            recurringDueDate: "2026-06-10"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            potAllocations: [manualAllocation, automaticAllocation]
        )))

        await store.load()

        XCTAssertTrue(store.deleteManualPotAllocation(id: manualAllocation.id))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 5000)
        XCTAssertEqual(store.snapshot.potAllocations.map(\.id), [automaticAllocation.id])
        XCTAssertFalse(store.deleteManualPotAllocation(id: automaticAllocation.id))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 5000)
    }

    @MainActor
    func testActivityDeletingRecurringBillOccurrenceRestoresPotAndPreventsRegeneration() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 4000, targetPence: nil)
        let bill = makeRecurringPayment(
            id: "bill-streaming",
            name: "Streaming",
            amountPence: 1000,
            dueDay: 10,
            potId: pot.id,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let transactionId = "recurring-\(bill.id)-2026-06-10"
        let fundingAllocation = makePotAllocation(
            id: "allocation-streaming",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: bill.amountPence,
            source: .recurringBillFunding,
            recurringPaymentId: bill.id,
            recurringDueDate: "2026-06-10"
        )
        let transaction = Transaction(
            id: transactionId,
            potId: pot.id,
            payPeriodId: period.id,
            amountPence: bill.amountPence,
            type: .spending,
            paymentMethod: .pot,
            creditCardId: nil,
            recurringPaymentId: bill.id,
            date: "2026-06-10",
            note: bill.name,
            createdAt: "2026-06-10T09:00:00.000Z",
            updatedAt: "2026-06-10T09:00:00.000Z",
            deletedAt: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [bill],
            payPeriods: [period],
            potAllocations: [fundingAllocation],
            transactions: [transaction]
        )))

        await store.load()
        store.permanentlyDeleteActivityTransaction(id: transactionId)

        XCTAssertFalse(store.snapshot.transactions.contains { $0.id == transactionId })
        XCTAssertFalse(store.snapshot.potAllocations.contains { $0.id == fundingAllocation.id })
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 4000)
        XCTAssertEqual(
            store.snapshot.recurringPaymentOccurrenceOverrides.first(where: {
                $0.paymentId == bill.id && $0.scheduledDueDate == "2026-06-10"
            })?.state,
            .cancelled
        )

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-10"))
        XCTAssertFalse(store.snapshot.transactions.contains { $0.id == transactionId })
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 4000)
    }

    @MainActor
    func testRecurringBillPartialRefundRestoresOnlyReturnedAmountAndCanFollowFullRefund() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50_000)
        let pot = makePot(id: "pot-bill-refund", name: "Bills", balancePence: 3_000, targetPence: nil)
        let bill = makeRecurringPayment(
            id: "bill-partial-refund",
            name: "Broadband",
            amountPence: 1_000,
            dueDay: 10,
            potId: pot.id,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let transaction = Transaction(
            id: "recurring-\(bill.id)-2026-06-10",
            potId: pot.id,
            payPeriodId: period.id,
            amountPence: bill.amountPence,
            type: .spending,
            paymentMethod: .pot,
            creditCardId: nil,
            recurringPaymentId: bill.id,
            date: "2026-06-10",
            note: bill.name,
            createdAt: "2026-06-10T09:00:00.000Z",
            updatedAt: "2026-06-10T09:00:00.000Z",
            deletedAt: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            recurringPayments: [bill],
            payPeriods: [period],
            transactions: [transaction]
        )))

        await store.load()
        store.setRecurringBillOccurrenceRefundAmount(paymentId: bill.id, scheduledDueDate: "2026-06-10", amountPence: 400)

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 3_400)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id })?.netAmountPence, 600)
        XCTAssertEqual(
            PlannerDerivedData.resolvedRecurringOccurrences(
                snapshot: store.snapshot,
                payments: [bill],
                startDate: "2026-06-10",
                endDate: "2026-06-10"
            ).first?.amountPence,
            600
        )

        store.setRecurringBillOccurrenceRefunded(paymentId: bill.id, scheduledDueDate: "2026-06-10", refunded: true)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 4_000)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.amountPence, 1_000)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.refundedAmountPence, 1_000)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.netAmountPence, 0)

        store.setRecurringBillOccurrenceRefundAmount(paymentId: bill.id, scheduledDueDate: "2026-06-10", amountPence: 250)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 3_250)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.amountPence, 1_000)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.netAmountPence, 750)
        XCTAssertEqual(
            store.snapshot.recurringPaymentOccurrenceOverrides.first(where: {
                $0.paymentId == bill.id && $0.scheduledDueDate == "2026-06-10"
            })?.refundedAmountPence,
            250
        )

        store.clearRecurringBillOccurrenceAdjustment(paymentId: bill.id, scheduledDueDate: "2026-06-10")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 3_000)
        XCTAssertEqual(store.snapshot.transactions.first(where: { $0.id == transaction.id && $0.deletedAt == nil })?.amountPence, 1_000)
        XCTAssertNil(
            store.snapshot.recurringPaymentOccurrenceOverrides.first(where: {
                $0.paymentId == bill.id && $0.scheduledDueDate == "2026-06-10"
            })?.refundedAmountPence
        )
    }

    @MainActor
    func testRecurringCreditCardBillPartialRefundCreatesCreditAndUpdatesRunningBalance() async throws {
        let today = FinanceEngine.toIsoDate(Date())
        let statementDate = FinanceEngine.addIsoDays(date: today, days: 5)
        let nextCycleDate = FinanceEngine.monthlyDate(
            onOrAfter: FinanceEngine.addIsoDays(date: today, days: 1),
            day: FinanceEngine.dayOfMonth(today)
        )
        let settings = makeManualSettings(today: today)
        let card = makeCreditCard(
            id: "card-barclays-refund",
            name: "Barclays",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: statementDate,
            dueDay: 1,
            createdAt: "\(FinanceEngine.addIsoDays(date: today, days: -14))T00:00:00.000Z"
        )
        let bill = makeRecurringPayment(
            id: "recurring-barclays-refund",
            name: "Recurring card bill",
            amountPence: 1_000,
            dueDay: FinanceEngine.dayOfMonth(today),
            potId: nil,
            creditCardId: card.id,
            createdAt: "\(FinanceEngine.addIsoDays(date: today, days: -14))T00:00:00.000Z"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            recurringPayments: [bill],
            creditCards: [card]
        )))

        await store.load()
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 1_000)

        let generatedTransactionId = "card-recurring-\(bill.id)-\(today)"
        store.setTransactionRefundAmount(id: generatedTransactionId, amountPence: 145)

        let charge = try XCTUnwrap(store.snapshot.transactions.first {
            $0.deletedAt == nil && $0.id == generatedTransactionId
        })
        XCTAssertEqual(charge.amountPence, 1_000)
        XCTAssertEqual(charge.refundedAmountPence, 145)
        XCTAssertEqual(charge.netAmountPence, 855)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 855)
        XCTAssertEqual(
            store.snapshot.recurringPaymentOccurrenceOverrides.first {
                $0.paymentId == bill.id && $0.scheduledDueDate == today
            }?.refundedAmountPence,
            145
        )

        _ = store.applyDueLinkedPotObligations(asOf: today)
        XCTAssertEqual(
            store.snapshot.transactions.first { $0.deletedAt == nil && $0.id == generatedTransactionId }?.refundedAmountPence,
            145,
            "Recurring reconciliation must not erase a refund saved from Edit spending."
        )
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 855)
        XCTAssertEqual(
            PlannerDerivedData.creditCardOwedSummary(
                card: card,
                snapshot: store.snapshot,
                payPeriod: nil,
                asOfDate: today
            ).actualOwedPence,
            855
        )

        let statement = try XCTUnwrap(
            PlannerDerivedData.creditCardStatementSummaries(
                snapshot: store.snapshot,
                asOfDate: statementDate
            ).first { $0.cardId == card.id }
        )
        XCTAssertEqual(statement.calculatedAmountPence, 855)
        XCTAssertTrue(statement.transactions.contains {
            $0.source == .recurring && $0.amountPence == 1_000
        })
        XCTAssertTrue(statement.transactions.contains {
            $0.source == .refund && $0.amountPence == -145 && $0.name == "Recurring card bill refund"
        })

        let nextCycle = PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: store.snapshot,
            payments: [bill],
            startDate: nextCycleDate,
            endDate: nextCycleDate
        )
        XCTAssertEqual(nextCycle.first?.amountPence, 1_000)
    }

    @MainActor
    func testDeletingPayPeriodAlsoRemovesLinkedPaycheckAndReversesAllocations() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(
            id: "period-june",
            startDate: "2026-06-01",
            endDate: "2026-06-30",
            payday: "2026-06-01",
            incomePence: 50000
        )
        let pot = makePot(id: "pot-bills", name: "Bills", balancePence: 10000, targetPence: nil)
        let allocation = makePotAllocation(
            id: "allocation-june",
            payPeriodId: period.id,
            potId: pot.id,
            amountPence: 10000,
            source: .manual,
            recurringPaymentId: nil,
            recurringDueDate: nil
        )
        var snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            potAllocations: [allocation]
        )
        snapshot.paychecks = [
            Paycheck(
                id: "paycheck-june",
                payPeriodId: period.id,
                hoursWorked: 40,
                hourlyRatePence: 1250,
                calculatedAmountPence: 50000,
                actualAmountPence: nil,
                createdAt: "2026-06-01T00:00:00.000Z",
                updatedAt: "2026-06-01T00:00:00.000Z",
                deletedAt: nil
            )
        ]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        store.deletePayPeriod(id: period.id)

        XCTAssertTrue(store.snapshot.payPeriods.isEmpty)
        XCTAssertTrue(store.snapshot.paychecks.isEmpty)
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    func testCreditCardBalanceHistoryCurrentGroupReconcilesExactBalance() throws {
        let card = makeCreditCard(
            id: "card-ledger",
            name: "Ledger Card",
            openingBalancePence: 5_000,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-20",
            dueDay: 15,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        var spend = makeTransaction(
            id: "txn-ledger-spend",
            cardId: card.id,
            amountPence: 3_000,
            date: "2026-08-10",
            note: "Card spend"
        )
        spend.refundedAt = "2026-08-12T10:00:00.000Z"
        spend.refundedAmountPence = 500
        let repayment = CreditCardRepayment(
            id: "repayment-ledger",
            creditCardId: card.id,
            amountPence: 1_000,
            date: "2026-08-15",
            note: "Card payment",
            refundedAt: "2026-08-16T10:00:00.000Z",
            refundedAmountPence: 200,
            createdAt: "2026-08-15T10:00:00.000Z",
            updatedAt: "2026-08-16T10:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            transactions: [spend],
            creditCards: [card],
            creditCardRepayments: [repayment]
        )

        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: snapshot,
            asOfDate: "2026-08-19"
        )

        XCTAssertEqual(history.currentBalancePence, 6_700)
        XCTAssertEqual(history.currentSection.balancePence, history.currentBalancePence)
        XCTAssertEqual(history.currentSection.entries.reduce(0) { $0 + $1.amountPence }, history.currentBalancePence)
        XCTAssertEqual(history.currentSection.entries.map(\.kind), [.openingBalance, .charge, .refund, .repayment, .repaymentRefund])
        XCTAssertEqual(history.currentSection.entries.map(\.amountPence), [5_000, 3_000, -500, -1_000, 200])
        XCTAssertEqual(history.currentSection.entries.map(\.editTarget), [
            .card(card.id),
            .transaction(spend.id),
            .transaction(spend.id),
            .repayment(repayment.id),
            .repayment(repayment.id),
        ])
    }

    func testCreditCardBalanceHistoryShowsCurrentRefundForAStatementedPurchase() throws {
        let card = makeCreditCard(
            id: "card-ledger-old-refund",
            name: "Ledger Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-13",
            dueDay: 5,
            createdAt: "2026-07-13T00:00:00.000Z"
        )
        var spend = makeTransaction(
            id: "txn-ledger-old-refund",
            cardId: card.id,
            amountPence: 1_000,
            date: "2026-08-01",
            note: "Earlier purchase"
        )
        spend.refundedAt = "2026-08-20T10:00:00.000Z"
        spend.refundedAmountPence = 300

        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: makeSnapshot(transactions: [spend], creditCards: [card]),
            asOfDate: "2026-08-25"
        )

        XCTAssertEqual(history.currentBalancePence, 700)
        XCTAssertEqual(history.statementSections.first?.balancePence, 1_000)
        XCTAssertEqual(history.currentSection.balancePence, -300)
        XCTAssertEqual(history.currentSection.entries.map(\.kind), [.refund])
        XCTAssertEqual(history.currentSection.entries.map(\.amountPence), [-300])
        XCTAssertEqual(history.currentSection.entries.first?.editTarget, .transaction(spend.id))
    }

    func testCreditCardBalanceHistoryRoutesGeneratedBillToOccurrenceEditor() throws {
        let card = makeCreditCard(
            id: "card-ledger-recurring",
            name: "Ledger Card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-09-20",
            dueDay: 15,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        var transaction = makeTransaction(
            id: "card-recurring-bill-skin-2026-08-15",
            cardId: card.id,
            amountPence: 2_000,
            date: "2026-08-15",
            note: "Skin"
        )
        transaction.recurringPaymentId = "bill-skin"
        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: makeSnapshot(transactions: [transaction], creditCards: [card]),
            asOfDate: "2026-08-25"
        )

        let charge = try XCTUnwrap(history.currentSection.entries.first { $0.kind == .charge })
        XCTAssertEqual(
            charge.editTarget,
            .recurring(paymentId: "bill-skin", scheduledDueDate: "2026-08-15")
        )
    }

    func testCreditCardBalanceHistoryGroupsPaymentWithMatchingStatement() throws {
        let card = makeCreditCard(
            id: "card-statement-ledger",
            name: "Statement Ledger",
            openingBalancePence: 10_000,
            openingStatementBalancePence: 10_000,
            statementDate: "2026-06-20",
            dueDay: 1,
            createdAt: "2026-06-01T00:00:00.000Z"
        )
        let statementSpend = makeTransaction(
            id: "txn-statement-spend",
            cardId: card.id,
            amountPence: 2_000,
            date: "2026-06-10",
            note: "Statement spend"
        )
        let currentSpend = makeTransaction(
            id: "txn-current-spend",
            cardId: card.id,
            amountPence: 3_000,
            date: "2026-06-25",
            note: "Current spend"
        )
        let repayment = CreditCardRepayment(
            id: "repayment-statement-ledger",
            creditCardId: card.id,
            amountPence: 12_000,
            date: "2026-07-01",
            note: "June statement payment",
            statementDate: "2026-06-20",
            directDebitDate: "2026-07-01",
            createdAt: "2026-07-01T10:00:00.000Z",
            updatedAt: "2026-07-01T10:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            transactions: [statementSpend, currentSpend],
            creditCards: [card],
            creditCardRepayments: [repayment]
        )

        let history = CreditCardBalanceHistoryData.make(
            card: card,
            snapshot: snapshot,
            asOfDate: "2026-07-05"
        )
        let juneStatement = try XCTUnwrap(history.statementSections.first)

        XCTAssertEqual(history.currentBalancePence, 3_000)
        XCTAssertEqual(history.currentSection.entries.reduce(0) { $0 + $1.amountPence }, 3_000)
        XCTAssertEqual(history.currentSection.entries.map(\.kind), [.charge])
        XCTAssertEqual(juneStatement.statementDate, "2026-06-20")
        XCTAssertEqual(juneStatement.balancePence, 12_000)
        XCTAssertTrue(juneStatement.entries.contains { $0.editTarget == .transaction(statementSpend.id) })
        XCTAssertTrue(juneStatement.entries.contains { $0.kind == .repayment && $0.amountPence == -12_000 })
        XCTAssertTrue(juneStatement.entries.contains { $0.editTarget == .repayment(repayment.id) })
        XCTAssertEqual(juneStatement.entries.reduce(0) { $0 + $1.amountPence }, 0)
    }

    func testCreditCardStatementLocksActivityBeforeStatementDayAndStartsNewCycleOnStatementDay() {
        let card = makeCreditCard(
            id: "card-everyday",
            name: "Everyday",
            openingBalancePence: 10000,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-12",
            dueDay: 1,
            createdAt: "2026-06-05T09:00:00.000Z"
        )
        let transactions = [
            makeTransaction(id: "txn-before", cardId: card.id, amountPence: 2000, date: "2026-06-10", note: "Before statement"),
            makeTransaction(id: "txn-on-statement", cardId: card.id, amountPence: 5000, date: "2026-06-12", note: "Statement day spend"),
        ]
        let snapshot = makeSnapshot(transactions: transactions, creditCards: [card])

        let payments = PlannerDerivedData.creditCardStatementPayments(
            card: card,
            snapshot: snapshot,
            startDate: "2026-07-01",
            endDate: "2026-08-01",
            asOfDate: "2026-08-01"
        )

        XCTAssertEqual(payments.map(\.statementDate), ["2026-06-12", "2026-07-12"])
        XCTAssertEqual(payments.map(\.directDebitDate), ["2026-07-01", "2026-08-01"])
        XCTAssertEqual(payments.map(\.actualDuePence), [12000, 5000])
    }

    func testDeletedCardActivityDoesNotAffectStatementOrAvailabilityForecasts() throws {
        let card = makeCreditCard(
            id: "card-main", name: "Card", limitPence: 100_000,
            openingBalancePence: 0, openingStatementBalancePence: 0,
            statementDate: "2026-09-01", dueDay: 5, createdAt: "2026-08-01T00:00:00.000Z"
        )
        let period = makePayPeriod(id: "period", startDate: "2026-08-01", endDate: "2026-09-09", payday: "2026-08-01", incomePence: 200_000)
        let live = makeTransaction(id: "live", cardId: card.id, amountPence: 10_000, date: "2026-08-10", note: "Live")
        var deleted = makeTransaction(id: "deleted", cardId: card.id, amountPence: 20_000, date: "2026-08-25", note: "Deleted")
        deleted.deletedAt = "2026-08-19T00:00:00.000Z"
        var deletedRefund = makeTransaction(id: "deleted-refund", cardId: card.id, amountPence: 5_000, date: "2026-07-10", note: "Deleted refund")
        deletedRefund.deletedAt = deleted.deletedAt
        deletedRefund.refundedAt = "2026-08-15T00:00:00.000Z"
        deletedRefund.refundedAmountPence = 5_000
        let deletedCustom = CustomPayment(
            id: "deleted-custom", name: "Deleted custom", amountPence: 30_000, dueDate: "2026-08-26",
            creditCardId: card.id, status: .unpaid, createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: deleted.deletedAt!, deletedAt: deleted.deletedAt
        )
        let deletedRepayment = CreditCardRepayment(
            id: "deleted-repayment", creditCardId: card.id, amountPence: 4_000, date: "2026-09-05", note: "Deleted",
            statementDate: "2026-09-01", directDebitDate: "2026-09-05", source: .manual,
            potId: nil, potContributionPence: 0, paycheckContributionPence: 4_000,
            createdAt: "2026-08-01T00:00:00.000Z", updatedAt: deleted.deletedAt!, deletedAt: deleted.deletedAt
        )
        let snapshot = makeSnapshot(
            settings: makeManualSettings(today: "2026-08-20"), payPeriods: [period],
            transactions: [live, deleted, deletedRefund], creditCards: [card],
            customPayments: [deletedCustom], creditCardRepayments: [deletedRepayment]
        )
        for asOfDate in ["2026-08-20", "2026-08-30"] {
            let payment = try XCTUnwrap(PlannerDerivedData.creditCardStatementPayments(
                card: card, snapshot: snapshot, startDate: asOfDate, endDate: "2026-09-05", asOfDate: asOfDate
            ).first)
            XCTAssertEqual(payment.actualDuePence, 10_000)
            XCTAssertEqual(payment.forecastDuePence, 10_000)
            let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: snapshot, payPeriod: period, asOfDate: asOfDate)
            XCTAssertEqual(availability.actualAvailablePence, 90_000)
            XCTAssertEqual(availability.forecastAvailablePence, 90_000)
        }
    }

    @MainActor
    func testPartialCardSpendRefundKeepsOnlyTheNetAmountFunded() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(
            id: "period-june",
            startDate: "2026-06-01",
            endDate: "2026-06-30",
            payday: "2026-06-01",
            incomePence: 50_000
        )
        let card = makeCreditCard(
            id: "card-partial-spend-refund",
            name: "Everyday card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-06-20",
            dueDay: 1
        )
        let pot = makePot(
            id: "pot-partial-spend-refund",
            name: "Everyday card pot",
            balancePence: 0,
            targetPence: nil,
            linkedCreditCardId: card.id
        )
        let spend = makeTransaction(
            id: "txn-partial-spend-refund",
            cardId: card.id,
            amountPence: 1_000,
            date: "2026-06-10",
            note: "Returned order"
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [period],
            transactions: [spend],
            creditCards: [card]
        )))

        await store.load()
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 1_000)

        store.setTransactionRefundAmount(id: spend.id, amountPence: 400)
        XCTAssertEqual(store.snapshot.transactions.first?.netAmountPence, 600)
        XCTAssertEqual(store.snapshot.potAllocations.first?.amountPence, 600)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 600)

        store.setTransactionRefunded(id: spend.id, refunded: true)
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        store.setTransactionRefundAmount(id: spend.id, amountPence: 250)
        XCTAssertEqual(store.snapshot.potAllocations.first?.amountPence, 750)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 750)

        store.setTransactionRefunded(id: spend.id, refunded: false)
        XCTAssertEqual(store.snapshot.potAllocations.first?.amountPence, 1_000)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 1_000)
    }

    @MainActor
    func testDeletingFundedCardSpendReversesAllocationAndPotBalance() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let pot = makePot(id: "pot-barclays", name: "Barclays pot", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 10000, date: "2026-06-10", note: "Coffee")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], transactions: [spend], creditCards: [card])))

        await store.load()
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: spend.id, payPeriodId: period.id, completed: true))

        store.deleteTransaction(id: spend.id)

        XCTAssertEqual(store.snapshot.transactions.count, 0)
        XCTAssertEqual(store.snapshot.potAllocations.count, 0)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
    }

    func testHomeDueEventsRetainsCancelledDebtAndFullyRefundedRecurringBill() {
        let today = "2026-07-10"
        let debt = makeDebt(id: "cancelled-debt", name: "Cancelled loan payment", currentBalancePence: 50_000, dueDate: today)
        let debtCycle = makeDebtScheduleItem(
            id: "cancelled-debt-cycle",
            debtId: debt.id,
            dueDate: today,
            amountPence: 3_000,
            status: .cancelled
        )
        let bill = makeRecurringPayment(
            id: "refunded-banner-bill",
            name: "Refunded subscription",
            amountPence: 1_000,
            dueDay: 10,
            potId: nil
        )
        let refundedCharge = Transaction(
            id: "recurring-\(bill.id)-\(today)",
            potId: nil,
            payPeriodId: nil,
            amountPence: 1_000,
            type: .spending,
            paymentMethod: .income,
            creditCardId: nil,
            recurringPaymentId: bill.id,
            date: today,
            note: bill.name,
            refundedAt: "2026-07-10T12:00:00.000Z",
            refundedAmountPence: 1_000,
            createdAt: "2026-07-10T09:00:00.000Z",
            updatedAt: "2026-07-10T12:00:00.000Z",
            deletedAt: nil
        )
        var snapshot = makeSnapshot(
            recurringPayments: [bill],
            transactions: [refundedCharge],
            debts: [debt],
            debtPaymentScheduleItems: [debtCycle]
        )
        snapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(
                id: "refunded-banner-override",
                paymentId: bill.id,
                scheduledDueDate: today,
                state: .refunded,
                actualDueDate: nil,
                amountPenceOverride: nil,
                refundedAmountPence: 1_000,
                reversedGeneratedTransactionIds: [],
                createdAt: today,
                updatedAt: today,
                deletedAt: nil
            )
        ]

        let events = PlannerDerivedData.homeDueEvents(snapshot: snapshot, asOfDate: today)

        XCTAssertEqual(events.first { $0.title == debt.name }?.status, .cancelled)
        XCTAssertEqual(events.first { $0.title == bill.name }?.status, .refunded)
    }

    func testHomeDueEventsTreatsLegacyRecurringCancellationAsCancelledNotRefunded() {
        let today = "2026-08-15"
        let bill = makeRecurringPayment(
            id: "legacy-capcut",
            name: "Capcut",
            amountPence: 1_099,
            dueDay: 15,
            potId: nil
        )
        var snapshot = makeSnapshot(recurringPayments: [bill])
        snapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(
                id: "legacy-capcut-cancelled",
                paymentId: bill.id,
                scheduledDueDate: today,
                state: .refunded,
                actualDueDate: nil,
                amountPenceOverride: nil,
                reversedGeneratedTransactionIds: ["recurring-\(bill.id)-\(today)"],
                createdAt: today,
                updatedAt: today,
                deletedAt: nil
            )
        ]

        let event = PlannerDerivedData.homeDueEvents(snapshot: snapshot, asOfDate: today)
            .first { $0.title == bill.name }

        XCTAssertEqual(event?.status, .cancelled)
        XCTAssertFalse(snapshot.transactions.contains(where: \.hasRefund))
    }

    @MainActor
    func testCancellingRecurringOccurrenceDoesNotCreateRefundMetadata() async {
        let today = "2026-08-15"
        let bill = makeRecurringPayment(
            id: "cancelled-capcut",
            name: "Capcut",
            amountPence: 1_099,
            dueDay: 17,
            potId: nil
        )
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: makeManualSettings(today: today),
            recurringPayments: [bill]
        )))

        await store.load()
        store.setRecurringBillOccurrenceRefundAmount(
            paymentId: bill.id,
            scheduledDueDate: "2026-08-17",
            amountPence: 1_099
        )
        XCTAssertFalse(store.snapshot.recurringPaymentOccurrenceOverrides.contains {
            $0.paymentId == bill.id && $0.scheduledDueDate == "2026-08-17"
        })
        XCTAssertEqual(store.errorMessage, "A refund can only be logged after this bill has been charged.")

        store.cancelRecurringBillOccurrence(paymentId: bill.id, scheduledDueDate: "2026-08-17")

        let occurrenceOverride = store.snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.paymentId == bill.id && $0.scheduledDueDate == "2026-08-17"
        }
        XCTAssertEqual(occurrenceOverride?.state, .cancelled)
        XCTAssertNil(occurrenceOverride?.refundedAmountPence)
        XCTAssertFalse(store.snapshot.transactions.contains(where: \.hasRefund))
        XCTAssertEqual(
            PlannerDerivedData.homeDueEvents(snapshot: store.snapshot, asOfDate: today)
                .first { $0.title == bill.name }?.status,
            .cancelled
        )
    }

    func testNextRecurringOccurrencesCountsAwaitingAndMovedCyclesAndExcludesRefundedInactiveOrDeletedBills() {
        let recurring = makeRecurringPayment(
            id: "bill",
            name: "Energy",
            amountPence: 4000,
            dueDay: nil,
            potId: nil,
            dueDate: "2026-07-03",
            frequency: .weekly
        )
        var inactive = makeRecurringPayment(id: "inactive", name: "Inactive", amountPence: 1000, dueDay: 10, potId: nil)
        inactive.active = false
        var deleted = makeRecurringPayment(id: "deleted", name: "Deleted", amountPence: 1000, dueDay: 10, potId: nil)
        deleted.deletedAt = "2026-07-01T00:00:00.000Z"
        let refundedOnce = makeRecurringPayment(id: "refunded-once", name: "Refunded", amountPence: 1000, dueDay: nil, potId: nil, dueDate: "2026-07-11", frequency: .once)

        var snapshot = makeSnapshot(recurringPayments: [recurring, inactive, deleted, refundedOnce])
        snapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(id: "awaiting", paymentId: recurring.id, scheduledDueDate: "2026-07-03", state: .awaitingPayment, actualDueDate: nil, amountPenceOverride: nil, reversedGeneratedTransactionIds: [], createdAt: "2026-07-03", updatedAt: "2026-07-03", deletedAt: nil),
            RecurringPaymentOccurrenceOverride(id: "moved", paymentId: recurring.id, scheduledDueDate: "2026-07-10", state: .confirmed, actualDueDate: "2026-07-12", amountPenceOverride: 5500, reversedGeneratedTransactionIds: [], createdAt: "2026-07-10", updatedAt: "2026-07-10", deletedAt: nil),
            RecurringPaymentOccurrenceOverride(id: "refund", paymentId: recurring.id, scheduledDueDate: "2026-07-17", state: .refunded, actualDueDate: nil, amountPenceOverride: nil, reversedGeneratedTransactionIds: [], createdAt: "2026-07-10", updatedAt: "2026-07-10", deletedAt: nil),
            RecurringPaymentOccurrenceOverride(id: "partial-refund", paymentId: recurring.id, scheduledDueDate: "2026-07-24", state: .normal, actualDueDate: nil, amountPenceOverride: nil, refundedAmountPence: 1_500, reversedGeneratedTransactionIds: [], createdAt: "2026-07-10", updatedAt: "2026-07-10", deletedAt: nil),
            RecurringPaymentOccurrenceOverride(id: "refund-once", paymentId: refundedOnce.id, scheduledDueDate: "2026-07-11", state: .refunded, actualDueDate: nil, amountPenceOverride: nil, reversedGeneratedTransactionIds: [], createdAt: "2026-07-10", updatedAt: "2026-07-10", deletedAt: nil)
        ]

        let occurrences = PlannerDerivedData.nextRecurringOccurrences(
            snapshot: snapshot,
            payments: snapshot.recurringPayments,
            asOfDate: "2026-07-10",
            limitPerPayment: 3
        )

        XCTAssertEqual(occurrences.map(\.payment.id), ["bill", "bill", "bill"])
        XCTAssertEqual(occurrences.map(\.scheduledDueDate), ["2026-07-03", "2026-07-10", "2026-07-24"])
        XCTAssertEqual(occurrences.map(\.dueDate), ["2026-07-03", "2026-07-12", "2026-07-24"])
        XCTAssertEqual(occurrences.map(\.amountPence), [4000, 5500, 2500])
        XCTAssertTrue(occurrences[0].isAwaitingPayment)
        XCTAssertFalse(occurrences.contains { $0.scheduledDueDate == "2026-07-17" })
    }

    func testActivityYearlyNetDataDeduplicatesIncomeAndUsesOnlyActualYearToDateMovement() {
        let januaryPeriod = makePayPeriod(id: "period-january", startDate: "2026-01-01", endDate: "2026-01-31", payday: "2026-01-15", incomePence: 100_000)
        let marchPeriod = makePayPeriod(id: "period-march", startDate: "2026-03-01", endDate: "2026-03-31", payday: "2026-03-15", incomePence: 200_000)
        let futurePeriod = makePayPeriod(id: "period-september", startDate: "2026-09-01", endDate: "2026-09-30", payday: "2026-09-15", incomePence: 900_000)
        let januaryPaycheck = Paycheck(
            id: "paycheck-january",
            payPeriodId: januaryPeriod.id,
            hoursWorked: 0,
            hourlyRatePence: 0,
            calculatedAmountPence: 120_000,
            actualAmountPence: 125_000,
            createdAt: "2026-01-15T00:00:00.000Z",
            updatedAt: "2026-01-15T00:00:00.000Z",
            deletedAt: nil
        )
        let oneOffs = [
            OneOffIncome(id: "confirmed", payPeriodId: januaryPeriod.id, name: "Confirmed bonus", amountPence: 5_000, date: "2026-01-20", note: "", createdAt: "2026-01-20", updatedAt: "2026-01-20", deletedAt: nil),
            OneOffIncome(id: "awaiting", payPeriodId: nil, name: "Awaiting", amountPence: 90_000, date: "2026-05-01", note: "", createdAt: "2026-05-01", updatedAt: "2026-05-01", deletedAt: nil),
            OneOffIncome(id: "cancelled", payPeriodId: nil, name: "Cancelled", amountPence: 80_000, date: "2026-06-01", note: "", createdAt: "2026-06-01", updatedAt: "2026-06-01", deletedAt: nil)
        ]

        func transaction(
            id: String,
            amountPence: Int,
            type: TransactionType = .spending,
            date: String,
            refundedAt: String? = nil,
            deletedAt: String? = nil
        ) -> Transaction {
            Transaction(
                id: id,
                potId: nil,
                payPeriodId: nil,
                amountPence: amountPence,
                type: type,
                paymentMethod: .income,
                creditCardId: nil,
                recurringPaymentId: nil,
                date: date,
                note: id,
                refundedAt: refundedAt,
                createdAt: "\(date)T00:00:00.000Z",
                updatedAt: "\(date)T00:00:00.000Z",
                deletedAt: deletedAt
            )
        }

        var snapshot = makeSnapshot(
            payPeriods: [januaryPeriod, marchPeriod, futurePeriod],
            transactions: [
                transaction(id: "january-spend", amountPence: 20_000, date: "2026-01-10"),
                transaction(id: "march-spend", amountPence: 350_000, date: "2026-03-20"),
                transaction(id: "future-spend", amountPence: 999_000, date: "2026-09-01"),
                transaction(id: "refunded", amountPence: 500_000, date: "2026-04-01", refundedAt: "2026-04-02"),
                transaction(id: "allocation", amountPence: 400_000, type: .allocation, date: "2026-02-01"),
                transaction(id: "deleted", amountPence: 300_000, date: "2026-02-02", deletedAt: "2026-02-03")
            ],
            oneOffIncomes: oneOffs
        )
        snapshot.paychecks = [januaryPaycheck]
        snapshot.incomeOccurrenceOverrides = [
            IncomeOccurrenceOverride(id: "move-paycheck", sourceKind: .paycheck, sourceId: januaryPaycheck.id, scheduledDate: januaryPeriod.payday, state: .confirmed, actualDate: "2026-02-02", amountPenceOverride: 130_000, createdAt: "2026-01-15", updatedAt: "2026-01-15", deletedAt: nil),
            IncomeOccurrenceOverride(id: "move-bonus", sourceKind: .oneOffIncome, sourceId: "confirmed", scheduledDate: "2026-01-20", state: .confirmed, actualDate: "2026-04-01", amountPenceOverride: 7_000, createdAt: "2026-01-20", updatedAt: "2026-01-20", deletedAt: nil),
            IncomeOccurrenceOverride(id: "await", sourceKind: .oneOffIncome, sourceId: "awaiting", scheduledDate: "2026-05-01", state: .awaiting, actualDate: nil, amountPenceOverride: 100_000, createdAt: "2026-05-01", updatedAt: "2026-05-01", deletedAt: nil),
            IncomeOccurrenceOverride(id: "cancel", sourceKind: .oneOffIncome, sourceId: "cancelled", scheduledDate: "2026-06-01", state: .cancelled, actualDate: nil, amountPenceOverride: nil, createdAt: "2026-06-01", updatedAt: "2026-06-01", deletedAt: nil)
        ]

        let data = ActivityYearlyNetChartData.make(snapshot: snapshot, todayIso: "2026-08-02")

        XCTAssertEqual(data.year, 2026)
        XCTAssertEqual(data.currentMonth, 8)
        XCTAssertEqual(data.points.count, 12)
        XCTAssertEqual(data.totalIncomePence, 337_000)
        XCTAssertEqual(data.totalSpentPence, 370_000)
        XCTAssertEqual(data.currentNetPence, -33_000)
        XCTAssertEqual(data.points[0].incomePence, 0)
        XCTAssertEqual(data.points[0].spentPence, 20_000)
        XCTAssertEqual(data.points[0].cumulativeNetPence, -20_000)
        XCTAssertEqual(data.points[1].incomePence, 130_000)
        XCTAssertEqual(data.points[1].cumulativeNetPence, 110_000)
        XCTAssertEqual(data.points[2].incomePence, 200_000)
        XCTAssertEqual(data.points[2].spentPence, 350_000)
        XCTAssertEqual(data.points[2].cumulativeNetPence, -40_000)
        XCTAssertEqual(data.points[3].incomePence, 7_000)
        XCTAssertEqual(data.points[3].cumulativeNetPence, -33_000)
        XCTAssertTrue(data.points[7].isCurrentMonth)
        XCTAssertTrue(data.points[8].isFuture)
        XCTAssertEqual(data.points[8].incomePence, 0)
        XCTAssertEqual(data.points[8].spentPence, 0)
        XCTAssertEqual(data.activePoints.count, 8)
    }

    func testAuditBaselineUsesTheRecordsRealEffectiveDate() {
        let card = makeCreditCard(
            id: "audit-card",
            name: "Barclays",
            limitPence: 100_000,
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-13",
            dueDay: 19
        )
        let transaction = makeTransaction(
            id: "audit-payment",
            cardId: card.id,
            amountPence: 3_747,
            date: "2026-08-24",
            note: "MMA Gear"
        )
        let events = PlannerAuditEngine.baselineEvents(
            for: makeSnapshot(transactions: [transaction], creditCards: [card])
        )

        let paymentEvent = events.first { $0.changes.first?.recordId == transaction.id }
        XCTAssertEqual(paymentEvent?.effectiveDate, "2026-08-24")
        XCTAssertEqual(paymentEvent?.action, .baseline)
        XCTAssertEqual(paymentEvent?.amountPence, 3_747)
    }

    func testAuditEventCapturesCanonicalEditAndAffectedCardTotal() {
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
        var edited = original
        edited.amountPence = 3_747
        edited.updatedAt = "2026-08-24T18:42:00.000Z"
        let before = makeSnapshot(transactions: [original], creditCards: [card])
        let after = makeSnapshot(transactions: [edited], creditCards: [card])

        let event = PlannerAuditEngine.event(before: before, after: after, origin: .user)

        XCTAssertEqual(event?.action, .edited)
        XCTAssertEqual(event?.changes.first?.recordId, original.id)
        XCTAssertEqual(event?.effects.first(where: { $0.label == "Card owed" })?.deltaPence, 247)
        XCTAssertNotNil(event?.changes.first?.beforeJSON)
        XCTAssertNotNil(event?.changes.first?.afterJSON)
    }

    func testAuditRefundActivityClassifiesEveryTransactionTransition() throws {
        let card = makeCreditCard(
            id: "refund-card",
            name: "Refund card",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-13",
            dueDay: 19
        )
        let original = makeTransaction(
            id: "refund-transaction",
            cardId: card.id,
            amountPence: 2_000,
            date: "2026-08-24",
            note: "MMA Gear"
        )

        func activity(from before: Transaction, to after: Transaction) throws -> PlannerAuditRefundActivity {
            let event = try XCTUnwrap(PlannerAuditEngine.event(
                before: makeSnapshot(transactions: [before], creditCards: [card]),
                after: makeSnapshot(transactions: [after], creditCards: [card]),
                origin: .user
            ))
            return try XCTUnwrap(PlannerAuditEngine.refundActivity(
                for: event,
                snapshot: makeSnapshot(transactions: [after], creditCards: [card])
            ))
        }

        var applied = original
        applied.refundedAt = "2026-08-25T10:00:00.000Z"
        applied.refundedAmountPence = 500
        XCTAssertEqual(try activity(from: original, to: applied).transition, .applied)

        var increased = applied
        increased.refundedAmountPence = 1_500
        XCTAssertEqual(try activity(from: applied, to: increased).transition, .increased)

        var decreased = increased
        decreased.refundedAmountPence = 250
        XCTAssertEqual(try activity(from: increased, to: decreased).transition, .decreased)

        var removed = decreased
        removed.refundedAt = nil
        removed.refundedAmountPence = nil
        let removedActivity = try activity(from: decreased, to: removed)
        XCTAssertEqual(removedActivity.transition, .removed)
        XCTAssertEqual(removedActivity.displayAmountPence, 250)

        var ordinaryEdit = original
        ordinaryEdit.note = "Updated name"
        let ordinaryEvent = try XCTUnwrap(PlannerAuditEngine.event(
            before: makeSnapshot(transactions: [original], creditCards: [card]),
            after: makeSnapshot(transactions: [ordinaryEdit], creditCards: [card]),
            origin: .user
        ))
        XCTAssertNil(PlannerAuditEngine.refundActivity(
            for: ordinaryEvent,
            snapshot: makeSnapshot(transactions: [ordinaryEdit], creditCards: [card])
        ))
    }

    func testAuditRefundActivityIncludesEveryRefundableSourceAndStableRelationship() throws {
        let card = makeCreditCard(
            id: "history-card",
            name: "Barclays",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-13",
            dueDay: 19
        )
        var transaction = makeTransaction(
            id: "history-transaction",
            cardId: card.id,
            amountPence: 2_000,
            date: "2026-08-24",
            note: "MMA Gear"
        )
        transaction.refundedAt = "2026-08-25T10:00:00.000Z"
        transaction.refundedAmountPence = 500

        let repayment = CreditCardRepayment(
            id: "history-repayment",
            creditCardId: card.id,
            amountPence: 1_000,
            date: "2026-08-20",
            note: "Statement payment",
            refundedAt: "2026-08-25T10:00:00.000Z",
            refundedAmountPence: 1_000,
            createdAt: "2026-08-20T10:00:00.000Z",
            updatedAt: "2026-08-25T10:00:00.000Z",
            deletedAt: nil
        )
        let debt = makeDebt(id: "history-debt", name: "Loan", currentBalancePence: 5_000, dueDate: "2026-09-01")
        var debtPayment = DebtPlannerEngine.applyPayment(
            debt: debt,
            scheduleItem: nil,
            amountPence: 2_000,
            date: "2026-08-21",
            sourcePotId: nil,
            paymentType: .manualPayNow,
            note: "Loan payment"
        ).payment
        debtPayment.refundedAt = "2026-08-25T10:00:00.000Z"
        debtPayment.refundedAmountPence = 750

        let bill = makeRecurringPayment(
            id: "history-bill",
            name: "MMA",
            amountPence: 5_000,
            dueDay: 24,
            potId: nil,
            creditCardId: card.id
        )
        let occurrence = RecurringPaymentOccurrenceOverride(
            id: "history-occurrence",
            paymentId: bill.id,
            scheduledDueDate: "2026-08-24",
            state: .normal,
            actualDueDate: nil,
            amountPenceOverride: nil,
            refundedAmountPence: 900,
            reversedGeneratedTransactionIds: [],
            createdAt: "2026-08-24T10:00:00.000Z",
            updatedAt: "2026-08-25T10:00:00.000Z",
            deletedAt: nil
        )
        var generatedBillTransaction = makeTransaction(
            id: "card-recurring-\(bill.id)-2026-08-24",
            cardId: card.id,
            amountPence: bill.amountPence,
            date: "2026-08-24",
            note: bill.name
        )
        generatedBillTransaction.recurringPaymentId = bill.id
        let snapshot = makeSnapshot(
            recurringPayments: [bill],
            recurringPaymentOccurrenceOverrides: [occurrence],
            transactions: [transaction, generatedBillTransaction],
            debts: [debt],
            debtPayments: [debtPayment],
            creditCards: [card],
            creditCardRepayments: [repayment]
        )
        let events = PlannerAuditEngine.baselineEvents(for: snapshot)

        let expected: [(PlannerAuditRecordKind, String, Int)] = [
            (.transaction, transaction.id, 500),
            (.creditCardRepayment, repayment.id, 1_000),
            (.debtPayment, debtPayment.id, 750),
            (.recurringOccurrence, occurrence.id, 900)
        ]
        for (kind, id, amountPence) in expected {
            let event = try XCTUnwrap(events.first {
                $0.changes.contains { $0.recordKind == kind && $0.recordId == id }
            })
            let activity = try XCTUnwrap(PlannerAuditEngine.refundActivity(for: event, snapshot: snapshot))
            XCTAssertEqual(activity.transition, .applied)
            XCTAssertEqual(activity.currentAmountPence, amountPence)
        }

        let transactionEvent = try XCTUnwrap(events.first { $0.changes.contains { $0.recordId == transaction.id } })
        let repaymentEvent = try XCTUnwrap(events.first { $0.changes.contains { $0.recordId == repayment.id } })
        XCTAssertEqual(PlannerAuditEngine.relationshipKey(for: transactionEvent, snapshot: snapshot), "card:\(card.id)")
        XCTAssertEqual(PlannerAuditEngine.relationshipKey(for: repaymentEvent, snapshot: snapshot), "card:\(card.id)")

        let billEvent = try XCTUnwrap(events.first { $0.changes.contains { $0.recordId == bill.id } })
        let occurrenceEvent = try XCTUnwrap(events.first { $0.changes.contains { $0.recordId == occurrence.id } })
        let generatedEvent = try XCTUnwrap(events.first { $0.changes.contains { $0.recordId == generatedBillTransaction.id } })
        XCTAssertEqual(PlannerAuditEngine.relationshipKey(for: billEvent, snapshot: snapshot), "bill:\(bill.id)")
        XCTAssertEqual(PlannerAuditEngine.relationshipKey(for: occurrenceEvent, snapshot: snapshot), "bill:\(bill.id)")
        XCTAssertEqual(PlannerAuditEngine.relationshipKey(for: generatedEvent, snapshot: snapshot), "bill:\(bill.id)")
        XCTAssertEqual(
            PlannerAuditEngine.stableRelationshipHash("bill:\(bill.id)"),
            PlannerAuditEngine.stableRelationshipHash("bill:\(bill.id)")
        )
    }

    func testHistoryEditTargetsResolveCurrentCanonicalRecords() throws {
        let card = makeCreditCard(
            id: "edit-card",
            name: "Aqua",
            openingBalancePence: 0,
            openingStatementBalancePence: nil,
            statementDate: "2026-08-02",
            dueDay: 20
        )
        let bill = makeRecurringPayment(
            id: "edit-bill",
            name: "MMA",
            amountPence: 5_000,
            dueDay: 24,
            potId: nil,
            creditCardId: card.id
        )
        var generated = makeTransaction(
            id: "card-recurring-\(bill.id)-2026-08-24",
            cardId: card.id,
            amountPence: bill.amountPence,
            date: "2026-08-24",
            note: bill.name
        )
        generated.recurringPaymentId = bill.id
        let standalone = makeTransaction(
            id: "edit-transaction",
            cardId: card.id,
            amountPence: 2_848,
            date: "2026-08-24",
            note: "MMA Gear"
        )
        let occurrence = RecurringPaymentOccurrenceOverride(
            id: "edit-occurrence",
            paymentId: bill.id,
            scheduledDueDate: "2026-08-24",
            state: .normal,
            actualDueDate: nil,
            amountPenceOverride: nil,
            reversedGeneratedTransactionIds: [],
            createdAt: "2026-08-24T10:00:00.000Z",
            updatedAt: "2026-08-24T10:00:00.000Z",
            deletedAt: nil
        )
        let repayment = CreditCardRepayment(
            id: "edit-repayment",
            creditCardId: card.id,
            amountPence: 5_000,
            date: "2026-08-20",
            note: "Automatic Aqua statement payment from Aqua pot",
            createdAt: "2026-08-20T10:00:00.000Z",
            updatedAt: "2026-08-20T10:00:00.000Z",
            deletedAt: nil
        )
        let cycle = CreditCardCycleOverride(
            id: "edit-statement",
            creditCardId: card.id,
            scheduledStatementDate: "2026-08-02",
            statementState: .confirmed,
            actualStatementDate: nil,
            directDebitState: .normal,
            actualDirectDebitDate: nil,
            amountPenceOverride: 6_958,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-08-02T10:00:00.000Z",
            updatedAt: "2026-08-02T10:00:00.000Z",
            deletedAt: nil
        )
        let debt = makeDebt(id: "edit-debt", name: "Loan", currentBalancePence: 10_000, dueDate: "2026-09-01")
        let debtPayment = DebtPlannerEngine.applyPayment(
            debt: debt,
            scheduleItem: nil,
            amountPence: 1_000,
            date: "2026-08-21",
            sourcePotId: nil,
            paymentType: .manualPayNow
        ).payment
        let pot = makePot(id: "edit-pot", name: "Bills", balancePence: 5_000, targetPence: 10_000)
        let bank = makeBankAccount(id: "edit-bank")
        let payPeriod = makePayPeriod(
            id: "system-pay-period",
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            payday: "2026-08-01",
            incomePence: 100_000
        )
        let snapshot = makeSnapshot(
            bankAccounts: [bank],
            pots: [pot],
            recurringPayments: [bill],
            recurringPaymentOccurrenceOverrides: [occurrence],
            payPeriods: [payPeriod],
            transactions: [standalone, generated],
            debts: [debt],
            debtPayments: [debtPayment],
            creditCards: [card],
            creditCardRepayments: [repayment],
            creditCardCycleOverrides: [cycle]
        )
        let events = PlannerAuditEngine.baselineEvents(for: snapshot)

        func target(kind: PlannerAuditRecordKind, id: String) throws -> HistoryAuditEditTarget? {
            let event = try XCTUnwrap(events.first {
                $0.changes.contains { $0.recordKind == kind && $0.recordId == id }
            })
            return HistoryAuditEditTarget.make(event: event, snapshot: snapshot)
        }

        XCTAssertEqual(try target(kind: .transaction, id: standalone.id), .card(.transaction(standalone.id)))
        XCTAssertEqual(
            try target(kind: .transaction, id: generated.id),
            .card(.recurring(paymentId: bill.id, scheduledDueDate: "2026-08-24"))
        )
        XCTAssertEqual(
            try target(kind: .recurringOccurrence, id: occurrence.id),
            .card(.recurring(paymentId: bill.id, scheduledDueDate: occurrence.scheduledDueDate))
        )
        XCTAssertEqual(try target(kind: .recurringPayment, id: bill.id), .recurringBill(bill.id))
        XCTAssertEqual(try target(kind: .creditCardRepayment, id: repayment.id), .card(.repayment(repayment.id)))
        XCTAssertEqual(
            try target(kind: .creditCardCycle, id: cycle.id),
            .card(.statement(cardId: card.id, scheduledStatementDate: cycle.scheduledStatementDate))
        )
        XCTAssertEqual(try target(kind: .creditCard, id: card.id), .card(.card(card.id)))
        XCTAssertEqual(try target(kind: .debtPayment, id: debtPayment.id), .debtPayment(debtPayment.id))
        XCTAssertEqual(try target(kind: .debt, id: debt.id), .debt(debt.id))
        XCTAssertEqual(try target(kind: .pot, id: pot.id), .pot(pot.id))
        XCTAssertEqual(try target(kind: .bankAccount, id: bank.id), .bankAccount(bank.id))
        XCTAssertNil(try target(kind: .payPeriod, id: payPeriod.id))
    }

    @MainActor
    func testEditableOneOffCardPaymentUpdatesAndSoftDeletesByStableIdentity() throws {
        let payment = CustomPayment(
            id: "custom-aqua",
            name: "Original payment",
            amountPence: 2_500,
            dueDate: "2026-09-01",
            creditCardId: "card-aqua",
            status: .unpaid,
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(customPayments: [payment])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)

        store.updateCustomPayment(
            id: payment.id,
            name: "Updated payment",
            amountPence: 3_750,
            dueDate: "2026-09-03",
            creditCardId: payment.creditCardId,
            status: .paid
        )

        let updated = try XCTUnwrap(store.snapshot.customPayments.first { $0.id == payment.id })
        XCTAssertEqual(updated.name, "Updated payment")
        XCTAssertEqual(updated.amountPence, 3_750)
        XCTAssertEqual(updated.dueDate, "2026-09-03")
        XCTAssertEqual(updated.status, .paid)

        store.deleteCustomPayment(id: payment.id)
        XCTAssertNotNil(store.snapshot.customPayments.first { $0.id == payment.id }?.deletedAt)
    }

    @MainActor
    func testEditableCreditCardCoverPotRefreshesAmountAndSoftDeletes() throws {
        let cover = CreditCardPot(
            id: "cover-aqua",
            creditCardId: "card-aqua",
            payPeriodId: nil,
            payday: nil,
            periodStartDate: "2026-08-01",
            periodEndDate: "2026-08-31",
            name: "Aqua cover",
            amountPence: 5_000,
            source: .paycheck,
            status: .active,
            note: "",
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(creditCardPots: [cover])
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)

        store.updateCreditCardPot(
            id: cover.id,
            name: "Aqua reserve",
            amountPence: 7_500,
            source: .external,
            status: .active,
            note: "Adjusted"
        )

        let updated = try XCTUnwrap(store.snapshot.creditCardPots.first { $0.id == cover.id })
        XCTAssertEqual(updated.name, "Aqua reserve")
        XCTAssertEqual(updated.amountPence, 7_500)
        XCTAssertEqual(updated.source, .external)
        XCTAssertEqual(updated.note, "Adjusted")

        store.deleteCreditCardPot(id: cover.id)
        XCTAssertNotNil(store.snapshot.creditCardPots.first { $0.id == cover.id }?.deletedAt)
    }
}
