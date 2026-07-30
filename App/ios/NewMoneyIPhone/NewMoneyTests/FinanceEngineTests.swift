import Foundation
import XCTest
@testable import NewMoneyIPhone

final class FinanceEngineTests: XCTestCase {
    private var originalPaydayCleanupFlag: Any?

    override func setUp() {
        super.setUp()
        originalPaydayCleanupFlag = UserDefaults.standard.object(forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
        UserDefaults.standard.set(true, forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
    }

    override func tearDown() {
        if let originalPaydayCleanupFlag {
            UserDefaults.standard.set(originalPaydayCleanupFlag, forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
        } else {
            UserDefaults.standard.removeObject(forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
        }
        super.tearDown()
    }

    func testParsesPoundsToIntegerPenceLikeTheWebApp() {
        XCTAssertEqual(MoneyParser.parsePoundsToPence("12.34"), 1234)
        XCTAssertEqual(MoneyParser.parsePoundsToPence("£1,200.99"), 120099)
        XCTAssertEqual(MoneyParser.parsePoundsToPence("bad input"), 0)
    }

    func testCalculatesPaycheckAmountFromHoursAndRateUnlessActualIsProvided() {
        XCTAssertEqual(FinanceEngine.calculatePaycheckAmount(hoursWorked: 72, hourlyRatePence: 1250, actualAmountPence: nil), 90000)
        XCTAssertEqual(FinanceEngine.calculatePaycheckAmount(hoursWorked: 72, hourlyRatePence: 1250, actualAmountPence: 87550), 87550)
    }

    func testDailySafeToSpendUsesTheProjectedBalanceAfterCommittedCosts() {
        XCTAssertEqual(
            FinanceEngine.getDailySafeToSpendPence(
                spendablePence: 222773,
                today: "2026-07-10",
                endDate: "2026-07-31"
            ),
            10126
        )
    }

    func testDailySafeToSpendFloorsAnOvercommittedPlanAtZero() {
        XCTAssertEqual(
            FinanceEngine.getDailySafeToSpendPence(
                spendablePence: -1590,
                today: "2026-07-16",
                endDate: "2026-07-31"
            ),
            0
        )
    }

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

    func testPlannerSnapshotDecodesMissingBankAccountsOneOffIncomeAndChecklistExclusions() throws {
        let period = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 100000
        )
        let encoded = try JSONEncoder().encode(makeSnapshot(payPeriods: [period]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "bankAccounts")
        object.removeValue(forKey: "oneOffIncomes")
        object.removeValue(forKey: "fundingChecklistExclusions")
        var periods = try XCTUnwrap(object["payPeriods"] as? [[String: Any]])
        periods[0].removeValue(forKey: "monthlyAnchorDay")
        object["payPeriods"] = periods
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PlannerSnapshot.self, from: legacyData)

        XCTAssertTrue(decoded.bankAccounts.isEmpty)
        XCTAssertTrue(decoded.oneOffIncomes.isEmpty)
        XCTAssertTrue(decoded.fundingChecklistExclusions.isEmpty)
        XCTAssertNil(decoded.payPeriods.first?.monthlyAnchorDay)
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
        XCTAssertEqual(summary.projectedMoneyLeftPence, summary.currentMoneyLeftPence - 420)
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
            .refunded
        )

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-10"))
        XCTAssertFalse(store.snapshot.transactions.contains { $0.id == transactionId })
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 4000)
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

    func testCreditCardStatementDueDateUsesNextMonthWhenDueDayIsBeforeStatementDay() {
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
        let snapshot = makeSnapshot(settings: settings, creditCards: [jajaCard])

        let payments = PlannerDerivedData.creditCardStatementPayments(
            card: jajaCard,
            snapshot: snapshot,
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            asOfDate: "2026-07-09"
        )

        XCTAssertEqual(payments.map(\.directDebitDate), ["2026-08-03"])
        XCTAssertEqual(payments.map(\.actualDuePence), [21580])
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

    func testJulyScenarioKeepsKnownCardTotalsAndPendingFundingCosts() {
        var settings = makeManualSettings(today: "2026-07-09")
        settings.payFrequency = .monthly

        var currentPeriod = makePayPeriod(
            id: "period-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            incomePence: 0
        )
        currentPeriod.payFrequency = .monthly

        let cards = [
            makeCreditCard(id: "card-barclays", name: "Barclays", limitPence: 80000, openingBalancePence: 64544, openingStatementBalancePence: nil, statementDate: "2026-06-11", dueDay: 6),
            makeCreditCard(id: "card-capital-one", name: "Capital One", limitPence: 55000, openingBalancePence: 20237, openingStatementBalancePence: nil, statementDate: "2026-06-09", dueDay: 2),
            makeCreditCard(id: "card-jaja", name: "Jaja", limitPence: 25000, openingBalancePence: 21580, openingStatementBalancePence: 21580, statementDate: "2026-07-07", dueDay: 3),
            makeCreditCard(id: "card-zable", name: "Zable", limitPence: 50000, openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-24", dueDay: 1),
            makeCreditCard(id: "card-aqua", name: "Aqua", limitPence: 130000, openingBalancePence: 31430, openingStatementBalancePence: 12843, statementDate: "2026-06-24", dueDay: 20)
        ]
        let pots = [
            makePot(id: "pot-bills", name: "Bills", balancePence: 0, targetPence: nil),
            makePot(id: "pot-aqua", name: "Aqua", balancePence: 0, targetPence: nil, linkedCreditCardId: "card-aqua")
        ]
        let bills = [
            makeRecurringPayment(id: "bill-icloud", name: "iCloud+", amountPence: 899, dueDay: 10, potId: "pot-bills"),
            makeRecurringPayment(id: "bill-runna", name: "Runna", amountPence: 1599, dueDay: 18, potId: "pot-bills"),
            makeRecurringPayment(id: "bill-apple-care", name: "Apple Care", amountPence: 899, dueDay: 19, potId: "pot-bills")
        ]
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

        let snapshot = makeSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: bills,
            payPeriods: [currentPeriod],
            creditCards: cards,
            oneOffIncomes: [initialIncome]
        )

        let totalOwed = snapshot.creditCards.reduce(0) { total, card in
            total + PlannerDerivedData.creditCardOwedSummary(card: card, snapshot: snapshot, payPeriod: currentPeriod, asOfDate: "2026-07-09").actualOwedPence
        }
        let totalAvailable = snapshot.creditCards.reduce(0) { total, card in
            total + PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: snapshot, payPeriod: currentPeriod, asOfDate: "2026-07-09").actualAvailablePence
        }
        let billFunding = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: currentPeriod)
            .reduce(0) { $0 + $1.amountPence }
        let openingFunding = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: currentPeriod)
            .reduce(0) { $0 + $1.amountPence }

        XCTAssertEqual(totalOwed, 137791)
        XCTAssertEqual(totalAvailable, 202209)
        XCTAssertEqual(billFunding, 3397)
        XCTAssertEqual(openingFunding, 12843)
        XCTAssertEqual(billFunding + openingFunding, 16240)
    }

    func testFormatsPaydayLabelWithOrdinalFullMonthAndTwoDigitYear() {
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-01"), "1st June 27")
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-02"), "2nd June 27")
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-11"), "11th June 27")
    }

    func testFormatsShortDateLabelForDateSimulationCard() {
        XCTAssertEqual(FinanceEngine.formatShortDateLabel("2026-06-07"), "7 Jun 2026")
    }

    func testCreditCardDaySelectionValueShowsSelectedDay() {
        XCTAssertEqual(creditCardDaySelectionValue(14), "Day 14")
    }

    func testManualAppDateModeReturnsSelectedDate() {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-12-25"

        XCTAssertEqual(FinanceEngine.getAppTodayIso(settings: settings), "2026-12-25")
    }

    func testInvalidManualAppDateFallsBackToValidAutomaticDate() {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "tomorrow"

        let today = FinanceEngine.getAppTodayIso(settings: settings)

        XCTAssertNotEqual(today, "tomorrow")
        XCTAssertTrue(FinanceEngine.isIsoDate(today))
    }

    func testCreatesWeeklyBiweeklyAndMonthlyPayPeriodsFromPayday() {
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-12", frequency: .weekly),
                       NextPayPeriod(startDate: "2026-06-12", endDate: "2026-06-18", nextPayday: "2026-06-19"))
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-12", frequency: .biweekly),
                       NextPayPeriod(startDate: "2026-06-12", endDate: "2026-06-25", nextPayday: "2026-06-26"))
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-30", frequency: .monthly),
                       NextPayPeriod(startDate: "2026-06-30", endDate: "2026-07-29", nextPayday: "2026-07-30"))
    }

    func testMonthlyPayPeriodsPreserveTheSelectedDayAndClampShorterMonths() {
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(
                payday: "2027-01-31",
                frequency: .monthly,
                monthlyAnchorDay: 31
            ),
            NextPayPeriod(startDate: "2027-01-31", endDate: "2027-02-27", nextPayday: "2027-02-28")
        )
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(
                payday: "2027-02-28",
                frequency: .monthly,
                monthlyAnchorDay: 31
            ),
            NextPayPeriod(startDate: "2027-02-28", endDate: "2027-03-30", nextPayday: "2027-03-31")
        )
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(payday: "2026-07-16", frequency: .monthly),
            NextPayPeriod(startDate: "2026-07-16", endDate: "2026-08-15", nextPayday: "2026-08-16")
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

    @MainActor
    func testUpdatingAClampedMonthlyPaycheckKeepsTheOriginalThirtyFirstAnchor() async {
        var settings = makeManualSettings(today: "2027-02-28")
        settings.payFrequency = .monthly
        var period = makePayPeriod(
            id: "period-february",
            startDate: "2027-02-28",
            endDate: "2027-03-30",
            payday: "2027-02-28",
            incomePence: 100000
        )
        period.nextPayday = "2027-03-31"
        period.payFrequency = .monthly
        period.monthlyAnchorDay = 31
        let paycheck = Paycheck(
            id: "paycheck-february",
            payPeriodId: period.id,
            hoursWorked: 0,
            hourlyRatePence: 0,
            calculatedAmountPence: 100000,
            actualAmountPence: 100000,
            createdAt: "2027-02-28T00:00:00.000Z",
            updatedAt: "2027-02-28T00:00:00.000Z",
            deletedAt: nil
        )
        var snapshot = makeSnapshot(settings: settings, payPeriods: [period])
        snapshot.paychecks = [paycheck]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        store.updatePaycheck(
            id: paycheck.id,
            payday: "2027-02-28",
            hoursWorked: 0,
            hourlyRatePence: 0,
            actualAmountPence: 100000,
            payFrequency: .monthly
        )

        XCTAssertEqual(store.snapshot.payPeriods.first?.monthlyAnchorDay, 31)
        XCTAssertEqual(store.snapshot.payPeriods.first?.nextPayday, "2027-03-31")
        XCTAssertEqual(store.snapshot.payPeriods.first?.endDate, "2027-03-30")
    }

    func testSeedsTheSameDefaultPlannerPotsAsTheWebApp() {
        let names = DefaultData.defaultPots.map(\.name)

        XCTAssertEqual(names, ["Bills", "Subscriptions", "Food", "Transport", "Fun", "Savings", "Investments", "Buffer"])
        XCTAssertEqual(DefaultData.defaultPots.first?.type, .reserved)
        XCTAssertEqual(DefaultData.defaultSettings.currency, .gbp)
    }

    func testNewPlannerStartsWithNoPots() {
        XCTAssertTrue(DefaultData.emptySnapshot.pots.isEmpty)
    }

    func testBasicDataFixtureSnapshotContainsRequestedSeedData() {
        let snapshot = DefaultData.basicDataSnapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2026-07-01")

        XCTAssertEqual(snapshot.payPeriods.count, 1)
        XCTAssertEqual(snapshot.payPeriods.first?.id, "pay-period-basic-july-2026")
        XCTAssertEqual(snapshot.payPeriods.first?.startDate, "2026-07-01")
        XCTAssertEqual(snapshot.payPeriods.first?.endDate, "2026-07-31")
        XCTAssertEqual(snapshot.payPeriods.first?.incomePence, 100000)
        XCTAssertEqual(snapshot.payPeriods.first?.status, .active)
        XCTAssertEqual(snapshot.paychecks.first?.actualAmountPence, 100000)

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(cardsById["card-cc1"]?.name, "CC1")
        XCTAssertEqual(cardsById["card-cc1"]?.limitPence, 100000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 50000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 50000)
        XCTAssertEqual(cardsById["card-cc1"]?.statementDate, "2026-07-05")
        XCTAssertEqual(cardsById["card-cc1"]?.dueDay, 2)
        XCTAssertEqual(cardsById["card-cc2"]?.name, "CC2")
        XCTAssertEqual(cardsById["card-cc2"]?.limitPence, 20000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc2"]?.statementDate, "2026-07-15")
        XCTAssertEqual(cardsById["card-cc2"]?.dueDay, 10)
        XCTAssertEqual(cardsById["card-cc3"]?.name, "CC3")
        XCTAssertEqual(cardsById["card-cc3"]?.limitPence, 50000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc3"]?.statementDate, "2026-07-10")
        XCTAssertEqual(cardsById["card-cc3"]?.dueDay, 15)

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.name, "Pot 1")
        XCTAssertEqual(potsById["pot-cc1"]?.linkedCreditCardId, "card-cc1")
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 12500)
        XCTAssertEqual(potsById["pot-cc2"]?.name, "Pot 2")
        XCTAssertEqual(potsById["pot-cc2"]?.linkedCreditCardId, "card-cc2")
        XCTAssertEqual(potsById["pot-cc2"]?.balancePence, 0)
        XCTAssertEqual(potsById["pot-cc3"]?.name, "Pot 3")
        XCTAssertEqual(potsById["pot-cc3"]?.linkedCreditCardId, "card-cc3")
        XCTAssertEqual(potsById["pot-cc3"]?.balancePence, 0)

        let billsById = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) })
        XCTAssertEqual(billsById["rec-skincare"]?.name, "Skincare")
        XCTAssertEqual(billsById["rec-skincare"]?.amountPence, 5000)
        XCTAssertEqual(billsById["rec-skincare"]?.dueDay, 15)
        XCTAssertEqual(billsById["rec-skincare"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-skincare"]?.potId, "pot-cc1")
        XCTAssertEqual(billsById["rec-insurance"]?.name, "Insurance")
        XCTAssertEqual(billsById["rec-insurance"]?.amountPence, 10000)
        XCTAssertEqual(billsById["rec-insurance"]?.dueDay, 1)
        XCTAssertEqual(billsById["rec-insurance"]?.creditCardId, "card-cc2")
        XCTAssertEqual(billsById["rec-insurance"]?.potId, "pot-cc2")
        XCTAssertEqual(billsById["rec-spending-money"]?.name, "Spending money")
        XCTAssertEqual(billsById["rec-spending-money"]?.amountPence, 20000)
        XCTAssertEqual(billsById["rec-spending-money"]?.dueDay, 25)
        XCTAssertEqual(billsById["rec-spending-money"]?.creditCardId, "card-cc3")
        XCTAssertEqual(billsById["rec-spending-money"]?.potId, "pot-cc3")
        XCTAssertEqual(billsById["rec-chatgpt"]?.name, "ChatGPT")
        XCTAssertEqual(billsById["rec-chatgpt"]?.amountPence, 7500)
        XCTAssertEqual(billsById["rec-chatgpt"]?.dueDay, 1)
        XCTAssertEqual(billsById["rec-chatgpt"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-chatgpt"]?.potId, "pot-cc1")

        XCTAssertTrue(snapshot.potAllocations.isEmpty)
    }

    func testPlannerLaunchProfileUsesFileRepositoryUnlessFixtureFlagIsSet() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [:]) is FilePlannerRepository)
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.basicDataFixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testComplexStressFixtureSnapshotContainsWorkbookSeedData() {
        let snapshot = DefaultData.complexStressSnapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2026-09-01")
        XCTAssertEqual(snapshot.settings.payFrequency, .monthly)
        XCTAssertEqual(snapshot.settings.defaultPayPeriodDays, 31)

        XCTAssertEqual(snapshot.payPeriods.map(\.id), ["pay-period-complex-september-2026", "pay-period-complex-october-2026"])
        XCTAssertEqual(snapshot.payPeriods.map(\.startDate), ["2026-09-01", "2026-10-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.endDate), ["2026-09-30", "2026-10-31"])
        XCTAssertEqual(snapshot.payPeriods.map(\.payday), ["2026-09-01", "2026-10-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.nextPayday), ["2026-10-01", "2026-11-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.incomePence), [260000, 260000])
        XCTAssertEqual(snapshot.payPeriods.map(\.status), [.active, .planned])
        XCTAssertEqual(snapshot.paychecks.map(\.actualAmountPence), [260000, 260000])

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(cardsById["card-cc1"]?.name, "Barclays Rewards")
        XCTAssertEqual(cardsById["card-cc1"]?.limitPence, 120000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 43000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 43000)
        XCTAssertEqual(cardsById["card-cc1"]?.statementDate, "2026-08-05")
        XCTAssertEqual(cardsById["card-cc1"]?.dueDay, 2)
        XCTAssertEqual(cardsById["card-cc2"]?.name, "Capital One")
        XCTAssertEqual(cardsById["card-cc2"]?.limitPence, 45000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingBalancePence, 16000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingStatementBalancePence, 16000)
        XCTAssertEqual(cardsById["card-cc2"]?.statementDate, "2026-08-15")
        XCTAssertEqual(cardsById["card-cc2"]?.dueDay, 10)
        XCTAssertEqual(cardsById["card-cc3"]?.name, "Zable")
        XCTAssertEqual(cardsById["card-cc3"]?.limitPence, 60000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 21000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc3"]?.statementDate, "2026-09-03")
        XCTAssertEqual(cardsById["card-cc3"]?.dueDay, 18)
        XCTAssertEqual(cardsById["card-cc4"]?.name, "Aqua")
        XCTAssertEqual(cardsById["card-cc4"]?.limitPence, 30000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingBalancePence, 9000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingStatementBalancePence, 9000)
        XCTAssertEqual(cardsById["card-cc4"]?.statementDate, "2026-08-25")
        XCTAssertEqual(cardsById["card-cc4"]?.dueDay, 27)

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-pot1"]?.name, "Subscriptions")
        XCTAssertEqual(potsById["pot-pot1"]?.linkedCreditCardId, "card-cc1")
        XCTAssertEqual(potsById["pot-pot2"]?.name, "Car & Insurance")
        XCTAssertEqual(potsById["pot-pot2"]?.linkedCreditCardId, "card-cc2")
        XCTAssertEqual(potsById["pot-pot3"]?.name, "Food & Fuel")
        XCTAssertEqual(potsById["pot-pot3"]?.linkedCreditCardId, "card-cc3")
        XCTAssertEqual(potsById["pot-pot4"]?.name, "Emergency")
        XCTAssertNil(potsById["pot-pot4"]?.linkedCreditCardId)
        XCTAssertEqual(potsById["pot-pot5"]?.name, "Annual & Work")
        XCTAssertEqual(potsById["pot-pot5"]?.linkedCreditCardId, "card-cc4")

        let billsById = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.recurringPayments.count, 12)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.name, "ChatGPT")
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.amountPence, 7500)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.dueDay, 1)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.potId, "pot-pot1")
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-bill-tools-sub"]?.potId, "pot-pot2")
        XCTAssertEqual(billsById["rec-bill-tools-sub"]?.creditCardId, "card-cc2")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.potId, "pot-pot5")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.creditCardId, "card-cc4")
        XCTAssertEqual(billsById["rec-bill-groceries"]?.frequency, .weekly)
        XCTAssertEqual(billsById["rec-bill-groceries"]?.dueDate, "2026-09-07")
        XCTAssertEqual(billsById["rec-bill-fuel"]?.frequency, .biweekly)
        XCTAssertEqual(billsById["rec-bill-fuel"]?.dueDate, "2026-09-04")
        XCTAssertEqual(billsById["rec-bill-barber"]?.frequency, .biweekly)
        XCTAssertEqual(billsById["rec-bill-barber"]?.dueDate, "2026-09-09")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.frequency, .quarterly)
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.dueDate, "2026-09-30")
        XCTAssertNil(billsById["rec-bill-gym-dd"]?.creditCardId)
        XCTAssertNil(billsById["rec-bill-emergency-transfer"]?.creditCardId)

        XCTAssertTrue(snapshot.transactions.isEmpty)
        XCTAssertTrue(snapshot.customPayments.isEmpty)
        XCTAssertTrue(snapshot.potAllocations.isEmpty)
        XCTAssertTrue(snapshot.creditCardRepayments.isEmpty)
    }

    func testComplexStressLaunchProfileUsesInMemoryFixture() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.complexStressFixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testJanMarComplexStressFixtureSnapshotContainsWorkbookSeedData() {
        let snapshot = DefaultData.complexStressJanMar2027Snapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2027-01-01")
        XCTAssertEqual(snapshot.settings.payFrequency, .monthly)
        XCTAssertEqual(snapshot.settings.defaultPayPeriodDays, 31)

        XCTAssertEqual(snapshot.payPeriods.map(\.id), [
            "pay-period-complex-january-2027",
            "pay-period-complex-february-2027",
            "pay-period-complex-march-2027",
        ])
        XCTAssertEqual(snapshot.payPeriods.map(\.startDate), ["2027-01-01", "2027-02-01", "2027-03-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.endDate), ["2027-01-31", "2027-02-28", "2027-03-31"])
        XCTAssertEqual(snapshot.payPeriods.map(\.payday), ["2027-01-01", "2027-02-01", "2027-03-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.nextPayday), ["2027-02-01", "2027-03-01", "2027-04-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.incomePence), [400000, 400000, 400000])
        XCTAssertEqual(snapshot.payPeriods.map(\.status), [.active, .planned, .planned])
        XCTAssertEqual(snapshot.paychecks.map(\.actualAmountPence), [400000, 400000, 400000])

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.creditCards.count, 5)
        XCTAssertEqual(cardsById["card-cc1"]?.name, "Barclays Rewards")
        XCTAssertEqual(cardsById["card-cc1"]?.limitPence, 150000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 52000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 52000)
        XCTAssertEqual(cardsById["card-cc1"]?.statementDate, "2026-12-05")
        XCTAssertEqual(cardsById["card-cc1"]?.dueDay, 2)
        XCTAssertEqual(cardsById["card-cc2"]?.name, "Capital One")
        XCTAssertEqual(cardsById["card-cc2"]?.limitPence, 65000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingBalancePence, 28000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingStatementBalancePence, 28000)
        XCTAssertEqual(cardsById["card-cc2"]?.statementDate, "2026-12-15")
        XCTAssertEqual(cardsById["card-cc2"]?.dueDay, 10)
        XCTAssertEqual(cardsById["card-cc3"]?.name, "Zable")
        XCTAssertEqual(cardsById["card-cc3"]?.limitPence, 70000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 26000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc3"]?.statementDate, "2027-01-03")
        XCTAssertEqual(cardsById["card-cc3"]?.dueDay, 18)
        XCTAssertEqual(cardsById["card-cc4"]?.name, "Aqua")
        XCTAssertEqual(cardsById["card-cc4"]?.limitPence, 40000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingBalancePence, 12000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingStatementBalancePence, 12000)
        XCTAssertEqual(cardsById["card-cc4"]?.statementDate, "2026-12-25")
        XCTAssertEqual(cardsById["card-cc4"]?.dueDay, 27)
        XCTAssertEqual(cardsById["card-cc5"]?.name, "Jaja")
        XCTAssertEqual(cardsById["card-cc5"]?.limitPence, 90000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingBalancePence, 31000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc5"]?.statementDate, "2027-01-28")
        XCTAssertEqual(cardsById["card-cc5"]?.dueDay, 7)

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.pots.count, 6)
        XCTAssertEqual(potsById["pot-pot1"]?.name, "Subscriptions")
        XCTAssertEqual(potsById["pot-pot1"]?.linkedCreditCardId, "card-cc1")
        XCTAssertEqual(potsById["pot-pot2"]?.name, "Car & Insurance")
        XCTAssertEqual(potsById["pot-pot2"]?.linkedCreditCardId, "card-cc2")
        XCTAssertEqual(potsById["pot-pot3"]?.name, "Food & Fuel")
        XCTAssertEqual(potsById["pot-pot3"]?.linkedCreditCardId, "card-cc3")
        XCTAssertEqual(potsById["pot-pot4"]?.name, "Emergency")
        XCTAssertEqual(potsById["pot-pot4"]?.linkedCreditCardId, "card-cc4")
        XCTAssertEqual(potsById["pot-pot5"]?.name, "Annual & Work")
        XCTAssertEqual(potsById["pot-pot5"]?.linkedCreditCardId, "card-cc5")
        XCTAssertEqual(potsById["pot-pot6"]?.name, "Rent & Travel")
        XCTAssertNil(potsById["pot-pot6"]?.linkedCreditCardId)

        let billsById = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.recurringPayments.count, 18)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.amountPence, 7500)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.dueDay, 1)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.potId, "pot-pot1")
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-bill-groceries"]?.frequency, .weekly)
        XCTAssertEqual(billsById["rec-bill-groceries"]?.dueDate, "2027-01-04")
        XCTAssertEqual(billsById["rec-bill-fuel"]?.frequency, .biweekly)
        XCTAssertEqual(billsById["rec-bill-fuel"]?.dueDate, "2027-01-08")
        XCTAssertEqual(billsById["rec-bill-barber"]?.frequency, .biweekly)
        XCTAssertEqual(billsById["rec-bill-barber"]?.dueDate, "2027-01-13")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.frequency, .once)
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.dueDate, "2027-01-31")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.potId, "pot-pot4")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.creditCardId, "card-cc4")
        XCTAssertEqual(billsById["rec-bill-tools-sub"]?.potId, "pot-pot2")
        XCTAssertEqual(billsById["rec-bill-tools-sub"]?.creditCardId, "card-cc2")
        XCTAssertEqual(billsById["rec-bill-bus-travel"]?.potId, "pot-pot5")
        XCTAssertEqual(billsById["rec-bill-bus-travel"]?.creditCardId, "card-cc5")
        XCTAssertEqual(billsById["rec-bill-equipment-insurance"]?.potId, "pot-pot4")
        XCTAssertEqual(billsById["rec-bill-equipment-insurance"]?.creditCardId, "card-cc4")
        XCTAssertEqual(billsById["rec-bill-software-licence"]?.potId, "pot-pot5")
        XCTAssertEqual(billsById["rec-bill-software-licence"]?.creditCardId, "card-cc5")
        XCTAssertEqual(billsById["rec-bill-trade-membership"]?.frequency, .once)
        XCTAssertEqual(billsById["rec-bill-trade-membership"]?.dueDate, "2027-02-01")
        XCTAssertNil(billsById["rec-bill-gym-dd"]?.creditCardId)
        XCTAssertNil(billsById["rec-bill-mot-savings"]?.creditCardId)
        XCTAssertNil(billsById["rec-bill-rent-contribution"]?.creditCardId)
        XCTAssertNil(billsById["rec-bill-emergency-transfer"]?.creditCardId)

        XCTAssertTrue(snapshot.transactions.isEmpty)
        XCTAssertTrue(snapshot.customPayments.isEmpty)
        XCTAssertTrue(snapshot.potAllocations.isEmpty)
        XCTAssertTrue(snapshot.creditCardRepayments.isEmpty)
    }

    func testJanMarComplexStressLaunchProfileUsesInMemoryFixture() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.complexStressJanMar2027FixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testGroupedComplexJanMar2027FixtureSnapshotContainsWorkbookSeedData() {
        let snapshot = DefaultData.groupedComplexJanMar2027Snapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2027-01-01")
        XCTAssertEqual(snapshot.settings.payFrequency, .monthly)
        XCTAssertEqual(snapshot.settings.defaultPayPeriodDays, 31)

        XCTAssertEqual(snapshot.payPeriods.map(\.id), [
            "pay-period-grouped-january-2027",
            "pay-period-grouped-february-2027",
            "pay-period-grouped-march-2027",
        ])
        XCTAssertEqual(snapshot.payPeriods.map(\.startDate), ["2027-01-01", "2027-02-01", "2027-03-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.endDate), ["2027-01-31", "2027-02-28", "2027-03-31"])
        XCTAssertEqual(snapshot.payPeriods.map(\.payday), ["2027-01-01", "2027-02-01", "2027-03-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.nextPayday), ["2027-02-01", "2027-03-01", "2027-04-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.incomePence), [450000, 450000, 450000])
        XCTAssertEqual(snapshot.payPeriods.map(\.status), [.active, .planned, .planned])
        XCTAssertEqual(snapshot.paychecks.map(\.actualAmountPence), [450000, 450000, 450000])

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.creditCards.count, 5)
        XCTAssertEqual(cardsById["card-cc1"]?.name, "Barclays Rewards")
        XCTAssertEqual(cardsById["card-cc1"]?.limitPence, 150000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 42000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 42000)
        XCTAssertEqual(cardsById["card-cc1"]?.statementDate, "2026-12-06")
        XCTAssertEqual(cardsById["card-cc1"]?.dueDay, 3)
        XCTAssertEqual(cardsById["card-cc2"]?.name, "Capital One")
        XCTAssertEqual(cardsById["card-cc2"]?.limitPence, 70000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingBalancePence, 26000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingStatementBalancePence, 26000)
        XCTAssertEqual(cardsById["card-cc2"]?.statementDate, "2026-12-15")
        XCTAssertEqual(cardsById["card-cc2"]?.dueDay, 12)
        XCTAssertEqual(cardsById["card-cc3"]?.name, "Zable")
        XCTAssertEqual(cardsById["card-cc3"]?.limitPence, 85000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 33000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc3"]?.statementDate, "2027-01-10")
        XCTAssertEqual(cardsById["card-cc3"]?.dueDay, 18)
        XCTAssertEqual(cardsById["card-cc4"]?.name, "Aqua")
        XCTAssertEqual(cardsById["card-cc4"]?.limitPence, 60000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingBalancePence, 12500)
        XCTAssertEqual(cardsById["card-cc4"]?.openingStatementBalancePence, 12500)
        XCTAssertEqual(cardsById["card-cc4"]?.statementDate, "2026-12-20")
        XCTAssertEqual(cardsById["card-cc4"]?.dueDay, 25)
        XCTAssertEqual(cardsById["card-cc5"]?.name, "Jaja")
        XCTAssertEqual(cardsById["card-cc5"]?.limitPence, 50000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingBalancePence, 18000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingStatementBalancePence, 18000)
        XCTAssertEqual(cardsById["card-cc5"]?.statementDate, "2026-12-24")
        XCTAssertEqual(cardsById["card-cc5"]?.dueDay, 28)

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.pots.count, 7)
        XCTAssertEqual(potsById["pot-pot1"]?.name, "Subscriptions & Digital")
        XCTAssertEqual(potsById["pot-pot1"]?.linkedCreditCardId, "card-cc1")
        XCTAssertEqual(potsById["pot-pot2"]?.name, "Home & Utilities")
        XCTAssertEqual(potsById["pot-pot2"]?.linkedCreditCardId, "card-cc2")
        XCTAssertEqual(potsById["pot-pot3"]?.name, "Food, Fuel & Travel")
        XCTAssertEqual(potsById["pot-pot3"]?.linkedCreditCardId, "card-cc3")
        XCTAssertEqual(potsById["pot-pot4"]?.name, "Car & Work")
        XCTAssertEqual(potsById["pot-pot4"]?.linkedCreditCardId, "card-cc4")
        XCTAssertEqual(potsById["pot-pot5"]?.name, "Annual & Irregular")
        XCTAssertEqual(potsById["pot-pot5"]?.linkedCreditCardId, "card-cc5")
        XCTAssertEqual(potsById["pot-pot6"]?.name, "Emergency Savings")
        XCTAssertNil(potsById["pot-pot6"]?.linkedCreditCardId)
        XCTAssertEqual(potsById["pot-pot6"]?.type, .saving)
        XCTAssertEqual(potsById["pot-pot7"]?.name, "Rent, Holiday & Buffer")
        XCTAssertNil(potsById["pot-pot7"]?.linkedCreditCardId)

        XCTAssertEqual(snapshot.recurringPayments.count, 28)
        let billsById = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) })
        XCTAssertEqual(billsById["rec-bill-rent-board"]?.amountPence, 65000)
        XCTAssertEqual(billsById["rec-bill-rent-board"]?.potId, "pot-pot7")
        XCTAssertNil(billsById["rec-bill-rent-board"]?.creditCardId)
        XCTAssertEqual(billsById["rec-bill-work-software-bundle"]?.amountPence, 1800)
        XCTAssertEqual(billsById["rec-bill-work-software-bundle"]?.potId, "pot-pot1")
        XCTAssertEqual(billsById["rec-bill-work-software-bundle"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-bill-council-rates"]?.potId, "pot-pot2")
        XCTAssertNil(billsById["rec-bill-council-rates"]?.creditCardId)
        XCTAssertEqual(billsById["rec-bill-broadband"]?.dueDay, 15)
        XCTAssertEqual(billsById["rec-bill-broadband"]?.creditCardId, "card-cc2")
        XCTAssertEqual(billsById["rec-bill-groceries-big-shop-a"]?.dueDay, 10)
        XCTAssertEqual(billsById["rec-bill-groceries-big-shop-a"]?.creditCardId, "card-cc3")
        XCTAssertEqual(billsById["rec-bill-fuel-fill-b"]?.dueDay, 24)
        XCTAssertEqual(billsById["rec-bill-fuel-fill-b"]?.creditCardId, "card-cc3")
        XCTAssertEqual(billsById["rec-bill-tools-workwear"]?.dueDay, 20)
        XCTAssertEqual(billsById["rec-bill-tools-workwear"]?.potId, "pot-pot4")
        XCTAssertEqual(billsById["rec-bill-website-hosting"]?.dueDay, 24)
        XCTAssertEqual(billsById["rec-bill-website-hosting"]?.creditCardId, "card-cc5")
        XCTAssertEqual(billsById["rec-bill-emergency-fund-transfer"]?.potId, "pot-pot6")
        XCTAssertNil(billsById["rec-bill-emergency-fund-transfer"]?.creditCardId)
        XCTAssertEqual(billsById["rec-bill-holiday-fund"]?.potId, "pot-pot7")
        XCTAssertNil(billsById["rec-bill-holiday-fund"]?.creditCardId)
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.frequency, .once)
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.dueDate, "2027-01-28")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.potId, "pot-pot5")
        XCTAssertEqual(billsById["rec-bill-road-tax"]?.creditCardId, "card-cc5")
        XCTAssertEqual(billsById["rec-bill-car-service"]?.dueDate, "2027-02-20")
        XCTAssertEqual(billsById["rec-bill-car-service"]?.potId, "pot-pot4")
        XCTAssertEqual(billsById["rec-bill-car-service"]?.creditCardId, "card-cc4")
        XCTAssertEqual(billsById["rec-bill-apple-developer-fee"]?.dueDate, "2027-03-05")
        XCTAssertEqual(billsById["rec-bill-apple-developer-fee"]?.potId, "pot-pot5")
        XCTAssertEqual(billsById["rec-bill-apple-developer-fee"]?.creditCardId, "card-cc5")
        let monthEndBufferBills = snapshot.recurringPayments.filter { $0.name == "Month-End Buffer Transfer" }
        XCTAssertEqual(monthEndBufferBills.count, 3)
        XCTAssertEqual(monthEndBufferBills.compactMap(\.dueDate).sorted(), ["2027-01-31", "2027-02-28", "2027-03-31"])
        XCTAssertTrue(monthEndBufferBills.allSatisfy { $0.frequency == .once && $0.potId == "pot-pot7" && $0.creditCardId == nil })

        XCTAssertTrue(snapshot.transactions.isEmpty)
        XCTAssertTrue(snapshot.customPayments.isEmpty)
        XCTAssertTrue(snapshot.potAllocations.isEmpty)
        XCTAssertTrue(snapshot.debts.isEmpty)
        XCTAssertTrue(snapshot.debtPayments.isEmpty)
        XCTAssertTrue(snapshot.creditCardRepayments.isEmpty)
    }

    func testGroupedComplexJanMar2027LaunchProfileUsesInMemoryFixture() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.groupedComplexJanMar2027FixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testFullAppLogicTortureJulSep2027FixtureSnapshotContainsWorkbookSeedData() {
        let snapshot = DefaultData.fullAppLogicTortureJulSep2027Snapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2027-07-01")
        XCTAssertEqual(snapshot.settings.payFrequency, .monthly)
        XCTAssertEqual(snapshot.settings.defaultPayPeriodDays, 31)

        XCTAssertEqual(snapshot.payPeriods.map(\.id), [
            "pay-period-full-app-july-2027",
            "pay-period-full-app-august-2027",
            "pay-period-full-app-september-2027",
        ])
        XCTAssertEqual(snapshot.payPeriods.map(\.startDate), ["2027-07-01", "2027-08-01", "2027-09-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.endDate), ["2027-07-31", "2027-08-31", "2027-09-30"])
        XCTAssertEqual(snapshot.payPeriods.map(\.payday), ["2027-07-01", "2027-08-01", "2027-09-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.nextPayday), ["2027-08-01", "2027-09-01", "2027-10-01"])
        XCTAssertEqual(snapshot.payPeriods.map(\.incomePence), [650000, 650000, 650000])
        XCTAssertEqual(snapshot.payPeriods.map(\.status), [.active, .planned, .planned])
        XCTAssertEqual(snapshot.paychecks.map(\.actualAmountPence), [650000, 650000, 650000])

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.creditCards.count, 5)
        XCTAssertEqual(cardsById["card-cc1"]?.name, "Barclays Rewards")
        XCTAssertEqual(cardsById["card-cc1"]?.limitPence, 180000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 54000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 54000)
        XCTAssertEqual(cardsById["card-cc1"]?.statementDate, "2027-06-05")
        XCTAssertEqual(cardsById["card-cc1"]?.dueDay, 2)
        XCTAssertEqual(cardsById["card-cc2"]?.name, "Capital One")
        XCTAssertEqual(cardsById["card-cc2"]?.limitPence, 90000)
        XCTAssertEqual(cardsById["card-cc2"]?.openingBalancePence, 27500)
        XCTAssertEqual(cardsById["card-cc2"]?.openingStatementBalancePence, 27500)
        XCTAssertEqual(cardsById["card-cc2"]?.statementDate, "2027-06-15")
        XCTAssertEqual(cardsById["card-cc2"]?.dueDay, 10)
        XCTAssertEqual(cardsById["card-cc3"]?.name, "Zable")
        XCTAssertEqual(cardsById["card-cc3"]?.limitPence, 100000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 39000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc3"]?.statementDate, "2027-07-10")
        XCTAssertEqual(cardsById["card-cc3"]?.dueDay, 18)
        XCTAssertEqual(cardsById["card-cc4"]?.name, "Aqua")
        XCTAssertEqual(cardsById["card-cc4"]?.limitPence, 65000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingBalancePence, 21000)
        XCTAssertEqual(cardsById["card-cc4"]?.openingStatementBalancePence, 21000)
        XCTAssertEqual(cardsById["card-cc4"]?.statementDate, "2027-06-25")
        XCTAssertEqual(cardsById["card-cc4"]?.dueDay, 27)
        XCTAssertEqual(cardsById["card-cc4"]?.dueDate, "2027-07-27")
        XCTAssertEqual(cardsById["card-cc5"]?.name, "Jaja")
        XCTAssertEqual(cardsById["card-cc5"]?.limitPence, 55000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingBalancePence, 13000)
        XCTAssertEqual(cardsById["card-cc5"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc5"]?.statementDate, "2027-07-01")
        XCTAssertEqual(cardsById["card-cc5"]?.dueDay, 28)

        let potsById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(snapshot.pots.count, 7)
        XCTAssertEqual(potsById["pot-pot1"]?.name, "Subscriptions")
        XCTAssertEqual(potsById["pot-pot1"]?.linkedCreditCardId, "card-cc1")
        XCTAssertEqual(potsById["pot-pot2"]?.name, "Home & Utilities")
        XCTAssertEqual(potsById["pot-pot2"]?.linkedCreditCardId, "card-cc2")
        XCTAssertEqual(potsById["pot-pot3"]?.name, "Food & Fuel")
        XCTAssertEqual(potsById["pot-pot3"]?.linkedCreditCardId, "card-cc3")
        XCTAssertEqual(potsById["pot-pot4"]?.name, "Car & Work")
        XCTAssertEqual(potsById["pot-pot4"]?.linkedCreditCardId, "card-cc4")
        XCTAssertEqual(potsById["pot-pot5"]?.name, "Annual & Irregular")
        XCTAssertEqual(potsById["pot-pot5"]?.linkedCreditCardId, "card-cc5")
        XCTAssertEqual(potsById["pot-pot6"]?.name, "Emergency Fund")
        XCTAssertNil(potsById["pot-pot6"]?.linkedCreditCardId)
        XCTAssertEqual(potsById["pot-pot7"]?.name, "Rent & Savings")
        XCTAssertNil(potsById["pot-pot7"]?.linkedCreditCardId)

        XCTAssertEqual(snapshot.recurringPayments.count, 34)
        let billsById = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0) })
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.amountPence, 7500)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.dueDay, 1)
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.potId, "pot-pot1")
        XCTAssertEqual(billsById["rec-bill-chatgpt"]?.creditCardId, "card-cc1")
        XCTAssertEqual(billsById["rec-bill-security-software-annual"]?.frequency, .once)
        XCTAssertEqual(billsById["rec-bill-security-software-annual"]?.dueDate, "2027-08-05")
        XCTAssertEqual(billsById["rec-bill-security-software-annual"]?.amountPence, 4800)
        XCTAssertEqual(billsById["rec-bill-pet-food"]?.frequency, .biweekly)
        XCTAssertEqual(billsById["rec-bill-pet-food"]?.dueDate, "2027-07-07")
        XCTAssertEqual(billsById["rec-bill-month-end-buffer-transfer-2027-09-30"]?.frequency, .once)
        XCTAssertEqual(billsById["rec-bill-month-end-buffer-transfer-2027-09-30"]?.dueDate, "2027-09-30")

        XCTAssertTrue(snapshot.transactions.isEmpty)
        XCTAssertTrue(snapshot.customPayments.isEmpty)
        XCTAssertTrue(snapshot.potAllocations.isEmpty)
        XCTAssertTrue(snapshot.debts.isEmpty)
        XCTAssertTrue(snapshot.debtPayments.isEmpty)
        XCTAssertTrue(snapshot.creditCardRepayments.isEmpty)
    }

    func testFullAppLogicTortureJulSep2027LaunchProfileUsesInMemoryFixture() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.fullAppLogicTortureJulSep2027FixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testFullAppLogicTortureJulSep2027FixtureMetadataPreservesManualActionsAndRules() {
        let manualActions = DefaultData.fullAppLogicTortureJulSep2027ManualActions
        XCTAssertEqual(manualActions.count, 12)
        XCTAssertEqual(manualActions.first?.actionId, "M1")
        XCTAssertEqual(manualActions.first?.date, "2027-07-02")
        XCTAssertEqual(manualActions.first?.actionType, "manual_card_spend")
        XCTAssertEqual(manualActions.first?.name, "Domain renewal")
        XCTAssertEqual(manualActions.first?.amountPence, 6400)
        XCTAssertEqual(manualActions.first?.potId, "pot-pot1")
        XCTAssertEqual(manualActions.first?.cardId, "card-cc1")
        XCTAssertEqual(manualActions.first?.autoTickChecklist, true)
        XCTAssertEqual(manualActions.first?.expectedStatementRule, "statement 2027-07-05; due 2027-08-02")
        XCTAssertEqual(manualActions.first { $0.actionId == "M2" }?.amountPence, 1850)
        XCTAssertEqual(manualActions.last?.name, "Broadband install part")
        XCTAssertEqual(manualActions.last?.amountPence, 5500)

        let rules = DefaultData.fullAppLogicTortureJulSep2027Rules
        XCTAssertEqual(rules.count, 10)
        XCTAssertEqual(rules.first?.rule, "event_order")
        XCTAssertEqual(rules.first?.details, "For each date: payday funding and tick; scheduled bills; manual actions; statement creation; direct debit card payments; end-of-day snapshot.")
        XCTAssertEqual(rules.last?.rule, "forecast")
        XCTAssertEqual(rules.last?.details, "Forecast remaining is only scheduled card-linked bills in the current pay month that have not yet charged. Manual spends are not forecast before action.")
    }

    func testFinalDebtFullAppSimJanApr2028FixtureSnapshotContainsWorkbookSeedData() {
        let snapshot = DefaultData.finalDebtFullAppSimJanApr2028Snapshot

        XCTAssertEqual(snapshot.settings.appDateMode, .manual)
        XCTAssertEqual(snapshot.settings.manualTodayIso, "2028-01-01")
        XCTAssertEqual(snapshot.settings.payFrequency, .custom)
        XCTAssertEqual(snapshot.payPeriods.count, 23)
        XCTAssertEqual(snapshot.payPeriods.first?.startDate, "2028-01-01")
        XCTAssertEqual(snapshot.payPeriods.first?.endDate, "2028-01-06")
        XCTAssertEqual(snapshot.payPeriods.first?.incomePence, 320000)
        XCTAssertEqual(snapshot.payPeriods.last?.startDate, "2028-04-28")
        XCTAssertEqual(snapshot.payPeriods.last?.endDate, "2028-04-30")
        XCTAssertEqual(snapshot.payPeriods.last?.incomePence, 18000)

        XCTAssertEqual(snapshot.creditCards.count, 5)
        XCTAssertEqual(snapshot.pots.count, 8)
        XCTAssertEqual(snapshot.recurringPayments.count, 31)
        XCTAssertEqual(snapshot.debts.count, 5)

        let cardsById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(cardsById["card-cc1"]?.openingBalancePence, 32000)
        XCTAssertEqual(cardsById["card-cc1"]?.openingStatementBalancePence, 32000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingBalancePence, 26000)
        XCTAssertEqual(cardsById["card-cc3"]?.openingStatementBalancePence, 0)
        XCTAssertEqual(cardsById["card-cc5"]?.statementDate, "2028-01-01")

        let debtsById = Dictionary(uniqueKeysWithValues: snapshot.debts.map { ($0.id, $0) })
        XCTAssertEqual(debtsById["debt-d1"]?.repaymentStrategy, .autoSpreadUntilDueDate)
        XCTAssertEqual(debtsById["debt-d2"]?.repaymentStrategy, .payIn4)
        XCTAssertEqual(debtsById["debt-d3"]?.repaymentStrategy, .minimumPlusExtra)
        XCTAssertEqual(debtsById["debt-d3"]?.aprBasisPoints, 2490)
        XCTAssertEqual(debtsById["debt-d4"]?.repaymentStrategy, .fixedPayment)
        XCTAssertEqual(debtsById["debt-d4"]?.aprBasisPoints, 3990)
        XCTAssertEqual(debtsById["debt-d5"]?.repaymentStrategy, .manualOnly)

        XCTAssertTrue(snapshot.transactions.isEmpty)
        XCTAssertTrue(snapshot.debtPayments.isEmpty)
        XCTAssertTrue(snapshot.creditCardRepayments.isEmpty)
    }

    func testFinalDebtFullAppSimJanApr2028LaunchProfileUsesInMemoryFixture() {
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.finalDebtFullAppSimJanApr2028FixtureValue
        ]) is InMemoryPlannerRepository)
    }

    func testFinalDebtFullAppSimJanApr2028FixtureMetadataPreservesManualActionsAndRules() {
        let manualActions = DefaultData.finalDebtFullAppSimJanApr2028ManualActions
        XCTAssertEqual(manualActions.count, 13)
        XCTAssertEqual(manualActions.first?.actionId, "M1")
        XCTAssertEqual(manualActions.first?.date, "2028-01-02")
        XCTAssertEqual(manualActions.first?.actionType, "manual_card_spend")
        XCTAssertEqual(manualActions.first?.amountPence, 6400)
        XCTAssertEqual(manualActions.first?.potId, "pot-pot1")
        XCTAssertEqual(manualActions.first?.cardId, "card-cc1")
        XCTAssertEqual(manualActions.first { $0.actionId == "M8" }?.actionType, "manual_debt_set_aside")
        XCTAssertEqual(manualActions.first { $0.actionId == "M11" }?.amountPence, 20000)
        XCTAssertEqual(manualActions.last?.name, "Broadband Install Part")

        let rules = DefaultData.finalDebtFullAppSimJanApr2028Rules
        XCTAssertEqual(rules.first?.rule, "Income windows")
        XCTAssertTrue(rules.contains { $0.rule == "Debt interest" })
        XCTAssertEqual(rules.last?.rule, "Debt is not credit card")
    }

    @MainActor
    func testFinalDebtFullAppSimJanApr2028SimulationExportsActualOutputAndMismatchReport() async throws {
        let result = try await FinalDebtFullAppSimJanApr2028Simulation.runAndWriteArtifacts()

        XCTAssertTrue(result.fixtureSeeded)
        XCTAssertEqual(result.dailyRowCount, 121)
        let requiredSheets = [
            "Daily Actual",
            "Priority UI Actual",
            "Income Actual",
            "Checklist Actual",
            "Transactions Actual",
            "Debt Schedule Actual",
            "Debt Payments Actual",
            "Debt Snapshots Actual",
            "Statements Actual",
            "Card DD Actual",
            "Manual Actions Actual",
            "Warning Periods Actual",
        ]
        XCTAssertEqual(Set(result.rowCounts.keys), Set(requiredSheets))
        XCTAssertEqual(result.rowCounts["Daily Actual"], 121)
        XCTAssertEqual(result.rowCounts["Priority UI Actual"], 29)
        XCTAssertEqual(result.rowCounts["Income Actual"], 23)
        XCTAssertEqual(result.rowCounts["Debt Snapshots Actual"], 605)
        XCTAssertEqual(result.totalMismatches, 0)
        for sheetName in requiredSheets where sheetName != "Daily Actual" {
            XCTAssertGreaterThan(result.rowCounts[sheetName] ?? 0, 0, "\(sheetName) should contain generated rows")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.actualJsonPath))
        XCTAssertFalse(result.expectedWorkbookPath.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.actualWorkbookPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.comparisonReportPath))
    }

    @MainActor
    func testFullAppLogicTortureJulSep2027SimulationExportsActualOutputAndMismatchReport() async throws {
        let result = try await FullAppLogicTortureJulSep2027Simulation.runAndWriteArtifacts()

        XCTAssertTrue(result.fixtureSeeded)
        XCTAssertEqual(result.dailyRowCount, 92)
        let requiredSheets = [
            "Daily Actual",
            "Dates That Matter Actual",
            "Payday Snapshots Actual",
            "Checklist Actual",
            "Transactions Actual",
            "Statements Actual",
            "DD Payments Actual",
            "Warning Periods Actual",
        ]
        XCTAssertEqual(Set(result.rowCounts.keys), Set(requiredSheets))
        XCTAssertEqual(result.rowCounts["Daily Actual"], 92)
        XCTAssertEqual(result.rowCounts["Dates That Matter Actual"], 43)
        XCTAssertEqual(result.rowCounts["Payday Snapshots Actual"], 3)
        for sheetName in requiredSheets where sheetName != "Daily Actual" {
            XCTAssertGreaterThan(result.rowCounts[sheetName] ?? 0, 0, "\(sheetName) should contain generated rows")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.actualJsonPath))
        XCTAssertFalse(result.expectedWorkbookPath.isEmpty)
        XCTAssertFalse(result.actualWorkbookPath.isEmpty)
        XCTAssertFalse(result.comparisonReportPath.isEmpty)
    }

    @MainActor
    func testFullAppLogicTortureJulSep2027SimulationMatchesJulyCardAccountingCheckpoints() {
        let sheets = runFullAppLogicTortureJulSep2027SimulationSheets()
        let daily = try! XCTUnwrap(fullAppSheet(named: "Daily Actual", in: sheets))

        let julyFirst = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-01"))
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Income Remaining"), 124500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Pot Target"), 381500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Pot Balance"), 381500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Card Balance"), 193000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Card Reserve"), 38500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC1 Reserve"), 7500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC2 Reserve"), 12500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC3 Reserve"), 0)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC4 Reserve"), 14000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC5 Reserve"), 4500)

        let julySecond = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-02"))
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Income Remaining"), 118100)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Pot1 Target"), 18500)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Pot1 Balance"), 18500)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "CC1 Balance"), 13900)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "CC1 Reserve"), 13900)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Total Card Reserve"), 44900)

        let julyFifth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-05"))
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "Pot1 Target"), 16250)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "Pot1 Balance"), 16250)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "CC1 Balance"), 19850)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "CC1 Reserve"), 19850)

        let julyFifteenth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-15"))
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "Pot2 Target"), 13500)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "Pot2 Balance"), 13500)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "CC2 Balance"), 37000)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "CC2 Reserve"), 37000)

        let julyTwentySeventh = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-27"))
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "Pot4 Target"), 15000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "Pot4 Balance"), 15000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "CC4 Balance"), 41000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "CC4 Reserve"), 41000)

        let julyTwentyEighth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-28"))
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "Pot5 Target"), 7200)
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "Pot5 Balance"), 7200)
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "CC5 Balance"), 37700)
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "CC5 Reserve"), 37700)
    }

    @MainActor
    func testFullAppLogicTortureJulSep2027SimulationReportsStatementDueDateAndReserveDdSources() {
        let sheets = runFullAppLogicTortureJulSep2027SimulationSheets()
        let statements = try! XCTUnwrap(fullAppSheet(named: "Statements Actual", in: sheets))
        let cc4OpeningStatement = try! XCTUnwrap(fullAppRow(
            in: statements,
            matching: ["card_id": "CC4", "statement_date": "2027-06-25"]
        ))
        XCTAssertEqual(fullAppText(cc4OpeningStatement, in: statements, "due_date"), "2027-07-27")

        let ddPayments = try! XCTUnwrap(fullAppSheet(named: "DD Payments Actual", in: sheets))
        let cc1AugustDd = try! XCTUnwrap(fullAppRow(
            in: ddPayments,
            matching: ["date": "2027-08-02", "card_id": "CC1", "statement_date": "2027-07-05"]
        ))
        XCTAssertEqual(fullAppPence(cc1AugustDd, in: ddPayments, "amount_paid"), 19850)
        XCTAssertEqual(
            fullAppText(cc1AugustDd, in: ddPayments, "source_breakdown"),
            "£198.50 from Pot1"
        )
    }

    func testGroupedComplexJanMar2027ChecklistTotalsMatchWorkbook() {
        let snapshot = DefaultData.groupedComplexJanMar2027Snapshot
        let expectations: [(periodId: String, today: String, recurringCount: Int, openingCount: Int, baseChecklistTotal: Int, projectedTotal: Int, moneyLeft: Int)] = [
            ("pay-period-grouped-january-2027", "2027-01-01", 24, 5, 411600, 411600, 38400),
            ("pay-period-grouped-february-2027", "2027-02-01", 24, 0, 285100, 383300, 66700),
            ("pay-period-grouped-march-2027", "2027-03-01", 24, 0, 269000, 367200, 82800),
        ]

        for expectation in expectations {
            let period = snapshot.payPeriods.first { $0.id == expectation.periodId }
            let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: period)
            let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: period)
            let cardPaymentItems = PlannerDerivedData.cardPaymentFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: expectation.today
            )
            let presentationItems = PlannerDerivedData.fundingChecklistPresentationItems(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: expectation.today
            )
            let summary = PlannerDerivedData.payPeriodCostSummary(
                snapshot: snapshot,
                payPeriod: period,
                asOfDate: expectation.today
            )

            XCTAssertEqual(recurringItems.count, expectation.recurringCount, expectation.periodId)
            XCTAssertEqual(openingItems.count, expectation.openingCount, expectation.periodId)
            XCTAssertEqual(
                presentationItems.count,
                expectation.recurringCount + expectation.openingCount + cardPaymentItems.count,
                expectation.periodId
            )
            XCTAssertEqual((recurringItems.map(\.amountPence) + openingItems.map(\.amountPence)).reduce(0, +), expectation.baseChecklistTotal, expectation.periodId)
            XCTAssertEqual(summary.totalCostsPence, expectation.projectedTotal, expectation.periodId)
            XCTAssertEqual(summary.moneyLeftPence, expectation.moneyLeft, expectation.periodId)
        }
    }

    @MainActor
    func testGroupedComplexJanMar2027PartialFebruaryFundingPaysOnlyGeneratedBarclaysStatement() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot))
        await store.load()

        let januaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(januaryPeriod.id, "pay-period-grouped-january-2027")
        let januaryItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        for item in januaryItems where !item.isCompleted {
            completeFundingChecklistItem(item, in: store)
        }

        var januaryThirtyFirstSettings = store.snapshot.settings
        januaryThirtyFirstSettings.manualTodayIso = "2027-01-31"
        store.updateSettings(januaryThirtyFirstSettings)

        let cardsOnJanuaryThirtyFirst = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(
            PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsOnJanuaryThirtyFirst["card-cc1"]), snapshot: store.snapshot),
            17200
        )

        var februaryFirstSettings = store.snapshot.settings
        februaryFirstSettings.manualTodayIso = "2027-02-01"
        store.updateSettings(februaryFirstSettings)

        let februaryPeriod = try XCTUnwrap(
            PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: "2027-02-01")
        )
        XCTAssertEqual(februaryPeriod.id, "pay-period-grouped-february-2027")

        let beforeFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: februaryPeriod,
            asOfDate: "2027-02-01"
        )
        XCTAssertEqual(beforeFundingItems.count, 24)
        XCTAssertEqual(beforeFundingItems.filter(\.isCompleted).count, 0)
        let cardsBeforeFunding = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(
            PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsBeforeFunding["card-cc1"]), snapshot: store.snapshot),
            26500
        )

        for item in beforeFundingItems.prefix(3) {
            completeFundingChecklistItem(item, in: store)
        }

        let partiallyFundedItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: februaryPeriod,
            asOfDate: "2027-02-01"
        )
        XCTAssertEqual(partiallyFundedItems.count, 24)
        XCTAssertEqual(partiallyFundedItems.filter(\.isCompleted).count, 3)

        var februaryFifthSettings = store.snapshot.settings
        februaryFifthSettings.manualTodayIso = "2027-02-05"
        store.updateSettings(februaryFifthSettings)

        let repaymentSignatures = store.snapshot.creditCardRepayments
            .filter { $0.creditCardId == "card-cc1" }
            .sorted { $0.date < $1.date }
            .map { "\($0.date):\($0.statementDate ?? "nil"):\($0.directDebitDate ?? "nil"):\($0.amountPence)" }
            .joined(separator: ", ")
        let barclaysRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc1" &&
            $0.statementDate == "2027-01-06" &&
            ($0.directDebitDate ?? $0.date) == "2027-02-03"
        }, "Barclays repayments: \(repaymentSignatures)")
        XCTAssertEqual(barclaysRepayment.amountPence, 13000)
        XCTAssertEqual(barclaysRepayment.date, "2027-02-03")
        XCTAssertFalse(store.snapshot.creditCardRepayments.contains {
            $0.creditCardId == "card-cc1" &&
            $0.date == "2027-02-03" &&
            $0.amountPence == 26500
        })
        XCTAssertFalse(store.snapshot.creditCardRepayments.contains {
            $0.creditCardId == "card-cc1" &&
            $0.statementDate == "2026-12-06" &&
            ($0.directDebitDate ?? $0.date) == "2027-02-03"
        })

        let barclaysStatement = try statementSummary(
            in: store.snapshot,
            cardId: "card-cc1",
            statementDate: "2027-01-06",
            asOfDate: "2027-02-05"
        )
        XCTAssertEqual(barclaysStatement.statementAmountPence, 13000)
        XCTAssertEqual(barclaysStatement.paidAmountPence, 13000)
        XCTAssertEqual(barclaysStatement.unpaidAmountPence, 0)
        XCTAssertEqual(barclaysStatement.status, .paid)

        let cardsById = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc1"]), snapshot: store.snapshot), 17200)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc2"]), snapshot: store.snapshot), 36300)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc3"]), snapshot: store.snapshot), 22000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc4"]), snapshot: store.snapshot), 37000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc5"]), snapshot: store.snapshot), 28500)

        let februaryFifthSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: februaryPeriod,
            asOfDate: "2027-02-05"
        )
        XCTAssertEqual(februaryFifthSummary.projectedCostsPence, 285100)

        let februaryFifthItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: februaryPeriod,
            asOfDate: "2027-02-05"
        )
        XCTAssertEqual(februaryFifthItems.count, 24)
        XCTAssertEqual(februaryFifthItems.filter(\.isCompleted).count, 3)
        XCTAssertEqual(februaryFifthItems.filter { !$0.isCompleted }.count, 21)
    }

    @MainActor
    func testGroupedComplexJanMar2027SameDayPaydayPotOnlyBillsRemainFundableAfterPosting() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot))
        await store.load()

        let januaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(januaryPeriod.id, "pay-period-grouped-january-2027")

        let januaryFirstSpending = store.snapshot.transactions.filter {
            $0.type == .spending && $0.date == "2027-01-01"
        }
        XCTAssertEqual(januaryFirstSpending.count, 6)
        XCTAssertEqual(januaryFirstSpending.reduce(0) { $0 + $1.amountPence }, 110800)

        let rentTransaction = try XCTUnwrap(januaryFirstSpending.first { $0.recurringPaymentId == "rec-bill-rent-board" })
        XCTAssertEqual(rentTransaction.paymentMethod, .pot)
        XCTAssertNil(rentTransaction.creditCardId)
        XCTAssertEqual(rentTransaction.potId, "pot-pot7")
        XCTAssertEqual(rentTransaction.amountPence, 65000)

        let councilRatesTransaction = try XCTUnwrap(januaryFirstSpending.first { $0.recurringPaymentId == "rec-bill-council-rates" })
        XCTAssertEqual(councilRatesTransaction.paymentMethod, .pot)
        XCTAssertNil(councilRatesTransaction.creditCardId)
        XCTAssertEqual(councilRatesTransaction.potId, "pot-pot2")
        XCTAssertEqual(councilRatesTransaction.amountPence, 12000)

        let beforeFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let beforeFundingByName = Dictionary(uniqueKeysWithValues: beforeFundingItems.map { ($0.name, $0) })

        XCTAssertEqual(beforeFundingItems.count, 29)
        XCTAssertEqual(beforeFundingByName["Rent / Board"]?.paidDate, "2027-01-01")
        XCTAssertEqual(beforeFundingByName["Rent / Board"]?.status, .needsFunding)
        XCTAssertEqual(beforeFundingByName["Council Rates"]?.paidDate, "2027-01-01")
        XCTAssertEqual(beforeFundingByName["Council Rates"]?.status, .needsFunding)

        let potsBeforeFunding = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsBeforeFunding["pot-pot7"]?.balancePence, -65000)
        XCTAssertEqual(potsBeforeFunding["pot-pot2"]?.balancePence, -12000)

        for item in beforeFundingItems where item.status != .paidCompleted {
            switch item.action {
            case .recurringBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardSpend(let transactionId, let payPeriodId):
                XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .debt(let debtId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            }
        }

        let afterFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let afterFundingSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        XCTAssertEqual(afterFundingSummary.moneyLeftPence, 38400)
        XCTAssertEqual(afterFundingSummary.currentMoneyLeftPence, 38400)
        XCTAssertEqual(afterFundingSummary.unfundedChecklistPence, 0)
        XCTAssertEqual(afterFundingItems.filter(\.isCompleted).count, 29)
        XCTAssertEqual(afterFundingItems.count, 29)

        let potsAfterFunding = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsAfterFunding["pot-pot7"]?.balancePence, 30000)
        XCTAssertEqual(potsAfterFunding["pot-pot2"]?.balancePence, 39300)

        let cardsById = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        let cardBalanceTotal = store.snapshot.creditCards.reduce(0) {
            $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot)
        }
        XCTAssertEqual(cardBalanceTotal, 165300)

        let jaja = try XCTUnwrap(cardsById["card-cc5"])
        let jajaAvailability = PlannerDerivedData.creditCardAvailabilitySummary(
            card: jaja,
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: jaja, snapshot: store.snapshot), 18000)
        XCTAssertEqual(jaja.limitPence, 50000)
        XCTAssertEqual(jajaAvailability.actualAvailablePence, 32000)
        XCTAssertEqual(max(0, -jajaAvailability.forecastAvailablePence), 1000)

        let januaryFirstSpendingAfterFunding = store.snapshot.transactions.filter {
            $0.type == .spending && $0.date == "2027-01-01"
        }
        XCTAssertEqual(januaryFirstSpendingAfterFunding.count, 6)
        XCTAssertEqual(januaryFirstSpendingAfterFunding.reduce(0) { $0 + $1.amountPence }, 110800)

        var january20Settings = store.snapshot.settings
        january20Settings.manualTodayIso = "2027-01-20"
        store.updateSettings(january20Settings)

        let emergencyTransaction = try XCTUnwrap(store.snapshot.transactions.first {
            $0.recurringPaymentId == "rec-bill-emergency-fund-transfer" && $0.date == "2027-01-20"
        })
        XCTAssertEqual(emergencyTransaction.paymentMethod, .pot)
        XCTAssertNil(emergencyTransaction.creditCardId)
        XCTAssertEqual(emergencyTransaction.potId, "pot-pot6")
        XCTAssertEqual(emergencyTransaction.amountPence, 8000)

        let emergencyPot = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot6" })
        let emergencyProgress = PlannerDerivedData.potProgress(pot: emergencyPot, snapshot: store.snapshot, today: "2027-01-20")
        XCTAssertEqual(emergencyPot.balancePence, 0)
        XCTAssertEqual(emergencyProgress.targetPence, 0)
        XCTAssertEqual(emergencyProgress.shortfallPence, 0)

        var january31Settings = store.snapshot.settings
        january31Settings.manualTodayIso = "2027-01-31"
        store.updateSettings(january31Settings)

        let monthEndBufferTransaction = try XCTUnwrap(store.snapshot.transactions.first {
            $0.recurringPaymentId == "rec-bill-month-end-buffer-transfer-2027-01-31" && $0.date == "2027-01-31"
        })
        XCTAssertEqual(monthEndBufferTransaction.paymentMethod, .pot)
        XCTAssertNil(monthEndBufferTransaction.creditCardId)
        XCTAssertEqual(monthEndBufferTransaction.potId, "pot-pot7")
        XCTAssertEqual(monthEndBufferTransaction.amountPence, 10000)

        let bufferPot = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot7" })
        let bufferProgress = PlannerDerivedData.potProgress(pot: bufferPot, snapshot: store.snapshot, today: "2027-01-31")
        XCTAssertEqual(bufferPot.balancePence, 0)
        XCTAssertEqual(bufferProgress.targetPence, 0)
        XCTAssertEqual(bufferProgress.shortfallPence, 0)
    }

    @MainActor
    func testGroupedComplexJanMar2027PotUpcomingCardPaymentPreviewMergesOpeningAndStatementRowsForSameDueDate() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot))
        await store.load()

        let januaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let beforeFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )

        for item in beforeFundingItems where item.status != .paidCompleted {
            switch item.action {
            case .recurringBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardSpend(let transactionId, let payPeriodId):
                XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .debt(let debtId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            }
        }

        let afterFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let afterFundingSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let cardBalanceTotal = store.snapshot.creditCards.reduce(0) {
            $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot)
        }
        XCTAssertEqual(afterFundingSummary.moneyLeftPence, 38400)
        XCTAssertEqual(afterFundingItems.filter(\.isCompleted).count, 29)
        XCTAssertEqual(afterFundingItems.count, 29)
        XCTAssertEqual(cardBalanceTotal, 165300)

        func linkedPayments(for potName: String) throws -> [LinkedCardPaymentDue] {
            let pot = try XCTUnwrap(store.snapshot.pots.first { $0.name == potName })
            return PlannerDerivedData.potProgress(pot: pot, snapshot: store.snapshot, today: "2027-01-01").linkedCardPayments
        }

        let carWorkPayments = try linkedPayments(for: "Car & Work")
        XCTAssertEqual(carWorkPayments.first?.dueIso, "2027-01-25")
        XCTAssertEqual(carWorkPayments.first?.amountPence, 31000)
        XCTAssertEqual(carWorkPayments.filter { $0.dueIso == "2027-01-25" }.count, 1)

        let annualIrregularPayments = try linkedPayments(for: "Annual & Irregular")
        XCTAssertEqual(annualIrregularPayments.first?.dueIso, "2027-01-28")
        XCTAssertEqual(annualIrregularPayments.first?.amountPence, 22500)
        XCTAssertEqual(annualIrregularPayments.filter { $0.dueIso == "2027-01-28" }.count, 1)
    }

    @MainActor
    func testGroupedComplexJanMar2027ZableDirectDebitDoesNotConsumeFutureFoodFuelFunding() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot))
        await store.load()

        let januaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let beforeFundingItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )

        for item in beforeFundingItems where item.status != .paidCompleted {
            switch item.action {
            case .recurringBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardBill(let paymentId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardSpend(let transactionId, let payPeriodId):
                XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
                XCTAssertTrue(store.setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true), item.name)
            case .debt(let debtId, let dueDate, let payPeriodId):
                XCTAssertTrue(store.setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true), item.name)
            }
        }

        var january10Settings = store.snapshot.settings
        january10Settings.manualTodayIso = "2027-01-10"
        store.updateSettings(january10Settings)

        let zableStatement = try statementSummary(in: store.snapshot, cardId: "card-cc3", statementDate: "2027-01-10", asOfDate: "2027-01-10")
        XCTAssertEqual(zableStatement.statementAmountPence, 55000)
        XCTAssertEqual(zableStatement.transactions.first { $0.name == "Zable opening balance" }?.amountPence, 33000)
        XCTAssertEqual(zableStatement.transactions.first { $0.name == "Groceries Big Shop A" }?.amountPence, 15000)
        XCTAssertEqual(zableStatement.transactions.first { $0.name == "Fuel Fill A" }?.amountPence, 7000)

        var january18Settings = store.snapshot.settings
        january18Settings.manualTodayIso = "2027-01-18"
        store.updateSettings(january18Settings)

        let zableRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc3" &&
            $0.statementDate == "2027-01-10" &&
            ($0.directDebitDate ?? $0.date) == "2027-01-18"
        })
        XCTAssertEqual(zableRepayment.amountPence, 55000)
        XCTAssertEqual(zableRepayment.date, "2027-01-18")

        let zable = try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc3" })
        let zableAvailability = PlannerDerivedData.creditCardAvailabilitySummary(
            card: zable,
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-18"
        )
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: zable, snapshot: store.snapshot), 0)
        XCTAssertEqual(zableAvailability.actualAvailablePence, 85000)
        XCTAssertEqual(zableAvailability.forecastAvailablePence, 63000)

        let cardBalanceTotal = store.snapshot.creditCards.reduce(0) {
            $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot)
        }
        XCTAssertEqual(cardBalanceTotal, 85500)

        let januarySpending = store.snapshot.transactions.filter {
            $0.deletedAt == nil &&
            $0.type == .spending &&
            $0.date >= januaryPeriod.startDate &&
            $0.date <= januaryPeriod.endDate
        }
        XCTAssertEqual(januarySpending.reduce(0) { $0 + $1.amountPence }, 157600)

        let foodFuelPot = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot3" })
        let foodFuelProgress = PlannerDerivedData.potProgress(pot: foodFuelPot, snapshot: store.snapshot, today: "2027-01-18")
        XCTAssertEqual(foodFuelPot.balancePence, 22000)
        XCTAssertEqual(foodFuelProgress.targetPence, 22000)
        XCTAssertEqual(foodFuelProgress.shortfallPence, 0)

        let remainingFoodFuelItems = PlannerDerivedData.recurringBillFundingChecklistItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod
        )
        .filter {
            $0.potId == "pot-pot3" &&
            $0.dueDate == "2027-01-24" &&
            ($0.paymentName == "Groceries Big Shop B" || $0.paymentName == "Fuel Fill B")
        }
        XCTAssertEqual(remainingFoodFuelItems.map(\.paymentName).sorted(), ["Fuel Fill B", "Groceries Big Shop B"])
        XCTAssertEqual(remainingFoodFuelItems.reduce(0) { $0 + $1.amountPence }, 22000)
        XCTAssertTrue(remainingFoodFuelItems.allSatisfy(\.isCompleted))

        let remainingPresentationItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-18"
        )
        .filter { $0.name == "Groceries Big Shop B" || $0.name == "Fuel Fill B" }
        XCTAssertEqual(remainingPresentationItems.map(\.status), [.activeReserved, .activeReserved])
        XCTAssertTrue(remainingPresentationItems.allSatisfy { $0.paidDate == nil })
    }

    @MainActor
    func testStatementRepaymentDoesNotCountPreviousStatementDateFundingInNextCycle() async throws {
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
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 30000)

        var june15Settings = store.snapshot.settings
        june15Settings.manualTodayIso = "2026-06-15"
        store.updateSettings(june15Settings)
        let juneRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == card.id && $0.statementDate == "2026-06-10"
        })
        XCTAssertEqual(juneRepayment.amountPence, 20000)
        XCTAssertEqual(juneRepayment.potContributionPence, 0)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 30000)

        var july10Settings = store.snapshot.settings
        july10Settings.manualTodayIso = "2026-07-10"
        store.updateSettings(july10Settings)
        XCTAssertNil(store.snapshot.transactions.first { $0.recurringPaymentId == currentStatementDayBill.id }?.potId)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 30000)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)
        let julyRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == card.id && $0.statementDate == "2026-07-10"
        })
        XCTAssertEqual(julyRepayment.amountPence, 30000)
        XCTAssertEqual(julyRepayment.potContributionPence, 30000)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == pot.id }?.balancePence, 0)
    }

    func testGroupedComplexJanMar2027ExplicitDateOccurrencesOnlyEmitWorkbookDates() {
        let snapshot = DefaultData.groupedComplexJanMar2027Snapshot
        let explicitPayments = snapshot.recurringPayments.filter { $0.frequency == .once }

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: explicitPayments,
            startDate: "2027-01-01",
            endDate: "2027-12-31"
        )

        XCTAssertEqual(occurrences.map { "\($0.payment.id)-\($0.dueDate)" }.sorted(), [
            "rec-bill-apple-developer-fee-2027-03-05",
            "rec-bill-car-service-2027-02-20",
            "rec-bill-month-end-buffer-transfer-2027-01-31-2027-01-31",
            "rec-bill-month-end-buffer-transfer-2027-02-28-2027-02-28",
            "rec-bill-month-end-buffer-transfer-2027-03-31-2027-03-31",
            "rec-bill-road-tax-2027-01-28",
        ])
    }

    @MainActor
    func testGroupedComplexJanMar2027OpeningAndStatementDayChargesUseWorkbookCycles() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.groupedComplexJanMar2027Snapshot))
        await store.load()

        let januaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: januaryPeriod)
        let openingByCard = Dictionary(uniqueKeysWithValues: openingItems.map { ($0.cardId, $0) })

        XCTAssertEqual(openingItems.count, 5)
        XCTAssertEqual(openingByCard["card-cc1"]?.amountPence, 42000)
        XCTAssertEqual(openingByCard["card-cc1"]?.directDebitDate, "2027-01-03")
        XCTAssertEqual(openingByCard["card-cc1"]?.potName, "Subscriptions & Digital")
        XCTAssertEqual(openingByCard["card-cc2"]?.amountPence, 26000)
        XCTAssertEqual(openingByCard["card-cc2"]?.directDebitDate, "2027-01-12")
        XCTAssertEqual(openingByCard["card-cc2"]?.potName, "Home & Utilities")
        XCTAssertEqual(openingByCard["card-cc3"]?.amountPence, 33000)
        XCTAssertEqual(openingByCard["card-cc3"]?.directDebitDate, "2027-01-18")
        XCTAssertEqual(openingByCard["card-cc3"]?.potName, "Food, Fuel & Travel")
        XCTAssertEqual(openingByCard["card-cc4"]?.amountPence, 12500)
        XCTAssertEqual(openingByCard["card-cc4"]?.directDebitDate, "2027-01-25")
        XCTAssertEqual(openingByCard["card-cc4"]?.potName, "Car & Work")
        XCTAssertEqual(openingByCard["card-cc5"]?.amountPence, 18000)
        XCTAssertEqual(openingByCard["card-cc5"]?.directDebitDate, "2027-01-28")
        XCTAssertEqual(openingByCard["card-cc5"]?.potName, "Annual & Irregular")

        var january10Settings = store.snapshot.settings
        january10Settings.manualTodayIso = "2027-01-10"
        store.updateSettings(january10Settings)

        let cc3Statement = try statementSummary(in: store.snapshot, cardId: "card-cc3", statementDate: "2027-01-10", asOfDate: "2027-01-10")
        XCTAssertEqual(cc3Statement.directDebitDate, "2027-01-18")
        XCTAssertEqual(cc3Statement.statementAmountPence, 55000)
        XCTAssertEqual(cc3Statement.transactions.map(\.amountPence).reduce(0, +), 55000)

        var january15Settings = store.snapshot.settings
        january15Settings.manualTodayIso = "2027-01-15"
        store.updateSettings(january15Settings)

        let cc2Statement = try statementSummary(in: store.snapshot, cardId: "card-cc2", statementDate: "2027-01-15", asOfDate: "2027-01-15")
        XCTAssertEqual(cc2Statement.directDebitDate, "2027-02-12")
        XCTAssertEqual(cc2Statement.statementAmountPence, 24800)

        var january20Settings = store.snapshot.settings
        january20Settings.manualTodayIso = "2027-01-20"
        store.updateSettings(january20Settings)

        let cc4Statement = try statementSummary(in: store.snapshot, cardId: "card-cc4", statementDate: "2027-01-20", asOfDate: "2027-01-20")
        XCTAssertEqual(cc4Statement.directDebitDate, "2027-01-25")
        XCTAssertEqual(cc4Statement.statementAmountPence, 18500)

        var january24Settings = store.snapshot.settings
        january24Settings.manualTodayIso = "2027-01-24"
        store.updateSettings(january24Settings)

        let cc5Statement = try statementSummary(in: store.snapshot, cardId: "card-cc5", statementDate: "2027-01-24", asOfDate: "2027-01-24")
        XCTAssertEqual(cc5Statement.directDebitDate, "2027-01-28")
        XCTAssertEqual(cc5Statement.statementAmountPence, 4500)
    }

    func testOnceRecurringOccurrencesOnlyEmitExplicitDueDate() {
        let roadTax = makeRecurringPayment(
            id: "rec-road-tax",
            name: "Road Tax",
            amountPence: 18000,
            dueDay: nil,
            potId: "pot-pot4",
            creditCardId: "card-cc4",
            dueDate: "2027-01-31",
            frequency: .once,
            createdAt: "2027-01-01T00:00:00.000Z"
        )
        let tradeMembership = makeRecurringPayment(
            id: "rec-trade-membership",
            name: "Trade Membership",
            amountPence: 9500,
            dueDay: nil,
            potId: "pot-pot5",
            creditCardId: "card-cc5",
            dueDate: "2027-02-01",
            frequency: .once,
            createdAt: "2027-01-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [roadTax, tradeMembership],
            startDate: "2027-01-01",
            endDate: "2028-03-31"
        )

        XCTAssertEqual(occurrences.map { "\($0.payment.id)-\($0.dueDate)" }, [
            "rec-road-tax-2027-01-31",
            "rec-trade-membership-2027-02-01",
        ])
    }

    func testJanMarComplexStressJanuaryFundingChecklistMatchesWorkbookTotals() {
        let snapshot = DefaultData.complexStressJanMar2027Snapshot
        let januaryPeriod = snapshot.payPeriods.first { $0.id == "pay-period-complex-january-2027" }

        let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: januaryPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: januaryPeriod)
        let cardPaymentItems = PlannerDerivedData.cardPaymentFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let presentationItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )
        let summary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-01"
        )

        XCTAssertEqual(recurringItems.count, 26)
        XCTAssertEqual(openingItems.count, 4)
        XCTAssertEqual(presentationItems.count, 30 + cardPaymentItems.count)
        XCTAssertEqual((recurringItems.map(\.amountPence) + openingItems.map(\.amountPence)).reduce(0, +), 351900)
        XCTAssertEqual(summary.totalCostsPence, 382900)
        XCTAssertEqual(summary.moneyLeftPence, 17100)

        let openingByCard = Dictionary(uniqueKeysWithValues: openingItems.map { ($0.cardId, $0) })
        XCTAssertEqual(openingByCard["card-cc1"]?.amountPence, 52000)
        XCTAssertEqual(openingByCard["card-cc1"]?.directDebitDate, "2027-01-02")
        XCTAssertEqual(openingByCard["card-cc1"]?.potName, "Subscriptions")
        XCTAssertEqual(openingByCard["card-cc2"]?.amountPence, 28000)
        XCTAssertEqual(openingByCard["card-cc2"]?.directDebitDate, "2027-01-10")
        XCTAssertEqual(openingByCard["card-cc2"]?.potName, "Car & Insurance")
        XCTAssertEqual(openingByCard["card-cc3"]?.amountPence, 26000)
        XCTAssertEqual(openingByCard["card-cc3"]?.directDebitDate, "2027-01-18")
        XCTAssertEqual(openingByCard["card-cc3"]?.potName, "Food & Fuel")
        XCTAssertEqual(openingByCard["card-cc4"]?.amountPence, 12000)
        XCTAssertEqual(openingByCard["card-cc4"]?.directDebitDate, "2027-01-27")
        XCTAssertEqual(openingByCard["card-cc4"]?.potName, "Emergency")
        XCTAssertNil(openingByCard["card-cc5"])

        let recurringByIdAndDate = Dictionary(uniqueKeysWithValues: recurringItems.map { ("\($0.paymentId)-\($0.dueDate)", $0) })
        XCTAssertEqual(recurringByIdAndDate["rec-bill-road-tax-2027-01-31"]?.potName, "Emergency")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-road-tax-2027-01-31"]?.cardId, "card-cc4")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-tools-sub-2027-01-15"]?.potName, "Car & Insurance")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-tools-sub-2027-01-15"]?.cardId, "card-cc2")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-bus-travel-2027-01-02"]?.potName, "Annual & Work")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-bus-travel-2027-01-02"]?.cardId, "card-cc5")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-equipment-insurance-2027-01-25"]?.potName, "Emergency")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-equipment-insurance-2027-01-25"]?.cardId, "card-cc4")
    }

    @MainActor
    func testJanMarComplexStressManualDateChangeSelectsFebruaryAndIncludesExplicitRows() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressJanMar2027Snapshot))
        await store.load()

        var februarySettings = store.snapshot.settings
        februarySettings.manualTodayIso = "2027-02-01"
        store.updateSettings(februarySettings)

        let februaryPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(februaryPeriod.id, "pay-period-complex-february-2027")

        let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: februaryPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: februaryPeriod)
        let recurringByIdAndDate = Dictionary(uniqueKeysWithValues: recurringItems.map { ("\($0.paymentId)-\($0.dueDate)", $0) })
        let openingByCard = Dictionary(uniqueKeysWithValues: openingItems.map { ($0.cardId, $0) })

        XCTAssertEqual(openingByCard["card-cc5"]?.amountPence, 31000)
        XCTAssertEqual(openingByCard["card-cc5"]?.directDebitDate, "2027-02-07")
        XCTAssertEqual(openingByCard["card-cc5"]?.potName, "Annual & Work")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-trade-membership-2027-02-01"]?.amountPence, 9500)
        XCTAssertEqual(recurringByIdAndDate["rec-bill-trade-membership-2027-02-01"]?.potName, "Annual & Work")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-trade-membership-2027-02-01"]?.cardId, "card-cc5")
    }

    func testQuarterlyRecurringOccurrencesFollowThreeMonthCadence() {
        let payment = makeRecurringPayment(
            id: "rec-road-tax",
            name: "Road Tax",
            amountPence: 18000,
            dueDay: nil,
            potId: "pot-pot5",
            creditCardId: "card-cc4",
            dueDate: "2026-09-30",
            frequency: .quarterly,
            createdAt: "2026-09-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [payment],
            startDate: "2026-09-01",
            endDate: "2027-04-01"
        )

        XCTAssertEqual(occurrences.map(\.dueDate), ["2026-09-30", "2026-12-30", "2027-03-30"])
    }

    func testMonthlyRecurringOccurrencesDoNotBackfillBeforePaymentWasCreated() {
        let carFinance = makeRecurringPayment(
            id: "rec-car-finance",
            name: "Car Finance",
            amountPence: 22000,
            dueDay: 28,
            potId: "pot-pot2",
            creditCardId: "card-cc2",
            createdAt: "2026-09-01T00:00:00.000Z"
        )
        let tools = makeRecurringPayment(
            id: "rec-tools",
            name: "Tools",
            amountPence: 2400,
            dueDay: 15,
            potId: "pot-pot2",
            creditCardId: "card-cc2",
            createdAt: "2026-09-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [carFinance, tools],
            startDate: "2026-08-15",
            endDate: "2026-09-15"
        )

        XCTAssertEqual(occurrences.map { "\($0.payment.id)-\($0.dueDate)" }, ["rec-tools-2026-09-15"])
    }

    @MainActor
    func testComplexStressPotUpcomingCardPaymentPreviewUsesStatementAccurateRows() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressSnapshot))

        await store.load()

        func linkedRows(for potName: String, today: String) throws -> [(String, Int)] {
            let pot = try XCTUnwrap(store.snapshot.pots.first { $0.name == potName })
            return PlannerDerivedData.potProgress(pot: pot, snapshot: store.snapshot, today: today)
                .linkedCardPayments
                .map { ($0.dueIso, $0.amountPence) }
        }

        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-01").map { $0.0 }, ["2026-09-02", "2026-10-02"])
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-01").map { $0.1 }, [43000, 8300])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-01").map { $0.0 }, ["2026-09-10", "2026-10-10"])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-01").map { $0.1 }, [16000, 13400])
        XCTAssertEqual(try linkedRows(for: "Annual & Work", today: "2026-09-01").map { $0.0 }, ["2026-09-27", "2026-10-27"])
        XCTAssertEqual(try linkedRows(for: "Annual & Work", today: "2026-09-01").map { $0.1 }, [9000, 18000])
        XCTAssertTrue(try linkedRows(for: "Emergency", today: "2026-09-01").isEmpty)

        var september3Settings = store.snapshot.settings
        september3Settings.manualTodayIso = "2026-09-03"
        store.updateSettings(september3Settings)
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-03").map { $0.0 }, ["2026-10-02", "2026-11-02"])
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-03").map { $0.1 }, [8300, 7000])

        var september11Settings = store.snapshot.settings
        september11Settings.manualTodayIso = "2026-09-11"
        store.updateSettings(september11Settings)
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-11").map { $0.0 }, ["2026-10-10", "2026-11-10"])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-11").map { $0.1 }, [13400, 22000])
    }

    func testComplexStressFundingChecklistIncludesAllSeptemberObligations() {
        let snapshot = DefaultData.complexStressSnapshot
        let septemberPeriod = snapshot.payPeriods.first { $0.id == "pay-period-complex-september-2026" }

        let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: septemberPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: septemberPeriod)
        let presentationItems = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: snapshot,
            payPeriod: septemberPeriod,
            asOfDate: "2026-09-01"
        )

        XCTAssertEqual(recurringItems.count + openingItems.count, 21)
        XCTAssertEqual(presentationItems.count, 21)
        XCTAssertEqual((recurringItems.map(\.amountPence) + openingItems.map(\.amountPence)).reduce(0, +), 209900)

        let openingByCard = Dictionary(uniqueKeysWithValues: openingItems.map { ($0.cardId, $0) })
        XCTAssertEqual(openingByCard["card-cc1"]?.amountPence, 43000)
        XCTAssertEqual(openingByCard["card-cc1"]?.potName, "Subscriptions")
        XCTAssertEqual(openingByCard["card-cc2"]?.amountPence, 16000)
        XCTAssertEqual(openingByCard["card-cc2"]?.potName, "Car & Insurance")
        XCTAssertEqual(openingByCard["card-cc3"]?.amountPence, 21000)
        XCTAssertEqual(openingByCard["card-cc3"]?.directDebitDate, "2026-09-18")
        XCTAssertEqual(openingByCard["card-cc3"]?.potName, "Food & Fuel")
        XCTAssertEqual(openingByCard["card-cc4"]?.amountPence, 9000)
        XCTAssertEqual(openingByCard["card-cc4"]?.potName, "Annual & Work")

        let recurringByIdAndDate = Dictionary(uniqueKeysWithValues: recurringItems.map { ("\($0.paymentId)-\($0.dueDate)", $0) })
        XCTAssertEqual(recurringByIdAndDate["rec-bill-gym-dd-2026-09-20"]?.potName, "Subscriptions")
        XCTAssertNil(recurringByIdAndDate["rec-bill-gym-dd-2026-09-20"]?.cardId)
        XCTAssertEqual(recurringByIdAndDate["rec-bill-emergency-transfer-2026-09-08"]?.potName, "Emergency")
        XCTAssertNil(recurringByIdAndDate["rec-bill-emergency-transfer-2026-09-08"]?.cardId)
        XCTAssertEqual(recurringByIdAndDate["rec-bill-tools-sub-2026-09-15"]?.potName, "Car & Insurance")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-tools-sub-2026-09-15"]?.cardId, "card-cc2")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-road-tax-2026-09-30"]?.potName, "Annual & Work")
        XCTAssertEqual(recurringByIdAndDate["rec-bill-road-tax-2026-09-30"]?.cardId, "card-cc4")
    }

    @MainActor
    func testComplexStressSameDayFundingTickReservesExpectedMoney() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressSnapshot))

        await store.load()

        let septemberPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: septemberPeriod)
        let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: septemberPeriod)

        XCTAssertEqual(openingItems.count + recurringItems.count, 21)

        let emergencyPotBeforeTick = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot4" })
        let emergencyBeforeTick = PlannerDerivedData.potProgress(pot: emergencyPotBeforeTick, snapshot: store.snapshot, today: "2026-09-01")
        XCTAssertEqual(emergencyBeforeTick.targetPence, 6000)
        XCTAssertEqual(emergencyPotBeforeTick.balancePence, 0)
        XCTAssertEqual(emergencyBeforeTick.shortfallPence, 6000)

        for item in openingItems {
            XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: item.cardId, directDebitDate: item.directDebitDate, payPeriodId: septemberPeriod.id, completed: true))
        }
        for item in recurringItems {
            XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: item.paymentId, dueDate: item.dueDate, payPeriodId: septemberPeriod.id, completed: true))
        }

        let fundedTotal = store.snapshot.potAllocations
            .filter { $0.payPeriodId == septemberPeriod.id && $0.deletedAt == nil }
            .reduce(0) { $0 + max(0, $1.amountPence) }
        XCTAssertEqual(fundedTotal, 209900)

        let fundedSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: septemberPeriod, asOfDate: "2026-09-01")
        XCTAssertEqual(fundedSummary.unfundedChecklistPence, 0)
        XCTAssertEqual(fundedSummary.moneyLeftPence, 50100)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-09-01"))

        let potProgressByName = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map {
            ($0.name, PlannerDerivedData.potProgress(pot: $0, snapshot: store.snapshot, today: "2026-09-01"))
        })
        let potsByName = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.name, $0) })
        XCTAssertEqual(potProgressByName["Subscriptions"]?.targetPence, 54000)
        XCTAssertEqual(potsByName["Subscriptions"]?.balancePence, 54000)
        XCTAssertEqual(potProgressByName["Car & Insurance"]?.targetPence, 40400)
        XCTAssertEqual(potsByName["Car & Insurance"]?.balancePence, 40400)
        XCTAssertEqual(potProgressByName["Food & Fuel"]?.targetPence, 64000)
        XCTAssertEqual(potsByName["Food & Fuel"]?.balancePence, 64000)
        XCTAssertEqual(potProgressByName["Emergency"]?.targetPence, 6000)
        XCTAssertEqual(potsByName["Emergency"]?.balancePence, 6000)
        XCTAssertEqual(potProgressByName["Emergency"]?.shortfallPence, 0)
        XCTAssertEqual(potProgressByName["Annual & Work"]?.targetPence, 27000)
        XCTAssertEqual(potsByName["Annual & Work"]?.balancePence, 27000)

        var september8Settings = store.snapshot.settings
        september8Settings.manualTodayIso = "2026-09-08"
        store.updateSettings(september8Settings)

        let emergencyTransaction = try XCTUnwrap(store.snapshot.transactions.first { $0.id == "recurring-rec-bill-emergency-transfer-2026-09-08" })
        XCTAssertEqual(emergencyTransaction.paymentMethod, .pot)
        XCTAssertNil(emergencyTransaction.creditCardId)
        XCTAssertEqual(emergencyTransaction.potId, "pot-pot4")
        XCTAssertEqual(emergencyTransaction.amountPence, 6000)

        let emergencyPotAfterPayment = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot4" })
        let emergencyAfterPayment = PlannerDerivedData.potProgress(pot: emergencyPotAfterPayment, snapshot: store.snapshot, today: "2026-09-08")
        XCTAssertEqual(emergencyPotAfterPayment.balancePence, 0)
        XCTAssertEqual(emergencyAfterPayment.targetPence, 0)
        XCTAssertEqual(emergencyAfterPayment.shortfallPence, 0)
    }

    @MainActor
    func testComplexStressCardBillsSpendFromLinkedCardPots() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressSnapshot))

        await store.load()

        let septemberPeriod = try XCTUnwrap(store.selectedPayPeriod)
        for item in PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: septemberPeriod) {
            XCTAssertTrue(store.setCardOpeningBalanceFundingCompleted(cardId: item.cardId, directDebitDate: item.directDebitDate, payPeriodId: septemberPeriod.id, completed: true))
        }
        for item in PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: septemberPeriod) {
            XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: item.paymentId, dueDate: item.dueDate, payPeriodId: septemberPeriod.id, completed: true))
        }

        var september15Settings = store.snapshot.settings
        september15Settings.manualTodayIso = "2026-09-15"
        store.updateSettings(september15Settings)

        let toolsTransaction = try XCTUnwrap(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-tools-sub-2026-09-15" })
        XCTAssertEqual(toolsTransaction.creditCardId, "card-cc2")
        XCTAssertEqual(toolsTransaction.potId, "pot-pot2")
        XCTAssertEqual(toolsTransaction.amountPence, 2400)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-pot2" }?.balancePence, 35400)

        var september30Settings = store.snapshot.settings
        september30Settings.manualTodayIso = "2026-09-30"
        store.updateSettings(september30Settings)

        let roadTaxTransaction = try XCTUnwrap(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-road-tax-2026-09-30" })
        XCTAssertEqual(roadTaxTransaction.creditCardId, "card-cc4")
        XCTAssertEqual(roadTaxTransaction.potId, "pot-pot5")
        XCTAssertEqual(roadTaxTransaction.amountPence, 18000)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-pot5" }?.balancePence, 18000)
    }

    @MainActor
    func testComplexStressFixtureOpeningBalancesAndOctoberRollover() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.complexStressSnapshot))

        await store.load()

        let septemberPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(septemberPeriod.startDate, "2026-09-01")
        XCTAssertEqual(septemberPeriod.endDate, "2026-09-30")

        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: septemberPeriod)
        XCTAssertEqual(openingItems.map(\.cardName).sorted(), ["Aqua", "Barclays Rewards", "Capital One", "Zable"])
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc1" }?.directDebitDate, "2026-09-02")
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc1" }?.amountPence, 43000)
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc2" }?.directDebitDate, "2026-09-10")
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc2" }?.amountPence, 16000)
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc3" }?.directDebitDate, "2026-09-18")
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc3" }?.amountPence, 21000)
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc4" }?.directDebitDate, "2026-09-27")
        XCTAssertEqual(openingItems.first { $0.cardId == "card-cc4" }?.amountPence, 9000)

        var september3Settings = store.snapshot.settings
        september3Settings.manualTodayIso = "2026-09-03"
        store.updateSettings(september3Settings)

        let cc3 = try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc3" })
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2026-09-03")
        let cc3Statement = try XCTUnwrap(statements.first { $0.cardId == cc3.id && $0.statementDate == "2026-09-03" })
        XCTAssertEqual(cc3Statement.directDebitDate, "2026-09-18")
        XCTAssertEqual(cc3Statement.statementAmountPence, 21000)
        XCTAssertEqual(cc3Statement.unpaidAmountPence, 21000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc3, snapshot: store.snapshot), 21000)

        var octoberSettings = store.snapshot.settings
        octoberSettings.manualTodayIso = "2026-10-01"
        store.updateSettings(octoberSettings)

        let octoberPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(octoberPeriod.startDate, "2026-10-01")
        XCTAssertEqual(octoberPeriod.endDate, "2026-10-31")
        XCTAssertEqual(octoberPeriod.payday, "2026-10-01")
        XCTAssertEqual(octoberPeriod.incomePence, 260000)

        let octoberChecklist = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: octoberPeriod)
        XCTAssertTrue(octoberChecklist.contains { $0.paymentId == "rec-bill-chatgpt" && $0.dueDate == "2026-10-01" })
        XCTAssertTrue(octoberChecklist.contains { $0.paymentId == "rec-bill-insurance" && $0.dueDate == "2026-10-01" })
        XCTAssertTrue(octoberChecklist.contains { $0.paymentId == "rec-bill-groceries" && $0.dueDate == "2026-10-05" })
        XCTAssertTrue(octoberChecklist.contains { $0.paymentId == "rec-bill-fuel" && $0.dueDate == "2026-10-02" })
        XCTAssertFalse(octoberChecklist.contains { $0.paymentId == "rec-bill-road-tax" })
    }

    @MainActor
    func testBasicDataFixtureLoadPostsDueBillsOnceAndComputesAvailability() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()

        let snapshot = store.snapshot
        XCTAssertEqual(snapshot.transactions.filter { $0.id == "card-recurring-rec-chatgpt-2026-07-01" }.count, 1)
        XCTAssertEqual(snapshot.transactions.filter { $0.id == "card-recurring-rec-insurance-2026-07-01" }.count, 1)
        XCTAssertNil(snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-07-01" }?.potId)
        XCTAssertNil(snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-07-01" }?.potId)

        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))
        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))

        let potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 55000)
        XCTAssertEqual(potsById["pot-cc2"]?.balancePence, 0)
        XCTAssertEqual(potsById["pot-cc3"]?.balancePence, 20000)
        XCTAssertEqual(store.snapshot.pots.reduce(0) { $0 + max(0, $1.balancePence) }, 75000)

        let cardsById = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        let cc1 = try XCTUnwrap(cardsById["card-cc1"])
        let cc2 = try XCTUnwrap(cardsById["card-cc2"])
        let cc3 = try XCTUnwrap(cardsById["card-cc3"])
        let cc1Availability = PlannerDerivedData.creditCardAvailabilitySummary(card: cc1, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        let cc2Availability = PlannerDerivedData.creditCardAvailabilitySummary(card: cc2, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        let cc3Availability = PlannerDerivedData.creditCardAvailabilitySummary(card: cc3, snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")

        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc1, snapshot: store.snapshot), 57500)
        XCTAssertEqual(cc1Availability.actualAvailablePence, 42500)
        XCTAssertEqual(cc1Availability.forecastAvailablePence, 37500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc2, snapshot: store.snapshot), 10000)
        XCTAssertEqual(cc2Availability.actualAvailablePence, 10000)
        XCTAssertEqual(cc2Availability.forecastAvailablePence, 10000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc3, snapshot: store.snapshot), 0)
        XCTAssertEqual(cc3Availability.actualAvailablePence, 50000)
        XCTAssertEqual(cc3Availability.forecastAvailablePence, 30000)

        let periodTransactions = store.snapshot.transactions.filter { $0.type == .spending && $0.date >= period.startDate && $0.date <= period.endDate }
        XCTAssertEqual(periodTransactions.count, 2)
        XCTAssertEqual(periodTransactions.reduce(0) { $0 + $1.amountPence }, 17500)
        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.potAllocationsPence, 92500)
        XCTAssertEqual(summary.totalCostsPence, 92500)
        XCTAssertEqual(summary.moneyLeftPence, 7500)

        let checklist = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(checklist.count, 4)
        XCTAssertEqual(checklist.filter(\.isCompleted).count, 4)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        XCTAssertEqual(openingItems.filter(\.isCompleted).count, 1)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-07-01" }?.potId, "pot-cc1")
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-07-01" }?.potId, "pot-cc2")
    }

    @MainActor
    func testBasicDataFundingChecklistGroupsActiveAndPaidCompletedItems() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))

        var items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: "2026-07-01"
        )
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name).sorted(), ["ChatGPT", "Insurance"])
        XCTAssertEqual(items.first { $0.name == "ChatGPT" }?.paidDate, "2026-07-01")
        XCTAssertEqual(items.first { $0.name == "Insurance" }?.paidDate, "2026-07-01")
        XCTAssertEqual(items.filter { $0.status == .activeReserved }.map(\.name).sorted(), ["CC1 opening balance", "Skincare", "Spending money"])
        XCTAssertTrue(items.allSatisfy(\.isCompleted))

        var july2Settings = store.snapshot.settings
        july2Settings.manualTodayIso = "2026-07-02"
        store.updateSettings(july2Settings)

        items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: "2026-07-02"
        )
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.status, .paidCompleted)
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.paidDate, "2026-07-02")
        var summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-02")
        XCTAssertEqual(summary.moneyLeftPence, 7500)
        XCTAssertEqual(summary.totalCostsPence, 92500)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)

        items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: "2026-07-15"
        )
        XCTAssertEqual(items.first { $0.name == "Skincare" }?.status, .paidCompleted)
        XCTAssertEqual(items.first { $0.name == "Skincare" }?.paidDate, "2026-07-15")
        summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-15")
        XCTAssertEqual(summary.moneyLeftPence, 7500)
        XCTAssertEqual(summary.totalCostsPence, 92500)
    }

    @MainActor
    func testBasicDataPaidOpeningBalanceChecklistRowStaysVisibleForPayPeriod() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))

        var july2Settings = store.snapshot.settings
        july2Settings.manualTodayIso = "2026-07-02"
        store.updateSettings(july2Settings)

        var july5Settings = store.snapshot.settings
        july5Settings.manualTodayIso = "2026-07-05"
        store.updateSettings(july5Settings)

        let items = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: "2026-07-05"
        )

        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name).sorted(), ["CC1 opening balance", "ChatGPT", "Insurance"])
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name), ["CC1 opening balance", "ChatGPT", "Insurance"])
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.paidDate, "2026-07-02")
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.title, "Add £500.00 to Pot 1")
        XCTAssertEqual(items.filter { $0.status == .activeReserved }.map(\.name).sorted(), ["Skincare", "Spending money"])
        XCTAssertTrue(items.allSatisfy(\.isCompleted))

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-05")
        XCTAssertEqual(summary.totalCostsPence, 92500)
        XCTAssertEqual(summary.moneyLeftPence, 7500)
    }

    @MainActor
    func testBasicDataManualDateSelectsAugustPayPeriodAndCosts() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let julyPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: julyPeriod))

        for date in ["2026-07-02", "2026-07-15", "2026-07-25"] {
            var settings = store.snapshot.settings
            settings.manualTodayIso = date
            store.updateSettings(settings)
        }

        var augustSettings = store.snapshot.settings
        augustSettings.manualTodayIso = "2026-08-01"
        store.updateSettings(augustSettings)

        let augustPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(augustPeriod.startDate, "2026-08-01")
        XCTAssertEqual(augustPeriod.endDate, "2026-08-31")
        XCTAssertEqual(augustPeriod.payday, "2026-08-01")
        XCTAssertEqual(augustPeriod.incomePence, 100000)
        XCTAssertNotEqual(augustPeriod.id, julyPeriod.id)

        let summary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: augustPeriod,
            asOfDate: "2026-08-01"
        )
        XCTAssertEqual(summary.totalCostsPence, 42500)
        XCTAssertEqual(summary.potAllocationsPence, 42500)
        XCTAssertEqual(summary.moneyLeftPence, 57500)
        XCTAssertEqual(summary.committedCostsPence, 0)
        XCTAssertEqual(summary.unfundedChecklistPence, 42500)
        XCTAssertEqual(summary.projectedCostsPence, 42500)
        XCTAssertEqual(summary.currentMoneyLeftPence, 100000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, 57500)

        let checklist = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: augustPeriod,
            asOfDate: "2026-08-01"
        )
        XCTAssertEqual(checklist.map(\.name).sorted(), ["ChatGPT", "Insurance", "Skincare", "Spending money"])
        XCTAssertTrue(checklist.allSatisfy { !$0.isCompleted })
        XCTAssertFalse(checklist.contains { $0.name == "CC1 opening balance" })
        XCTAssertEqual(checklist.first { $0.name == "ChatGPT" }?.dueDate, "2026-08-01")
        XCTAssertEqual(checklist.first { $0.name == "Insurance" }?.dueDate, "2026-08-01")
        XCTAssertEqual(checklist.first { $0.name == "Skincare" }?.dueDate, "2026-08-15")
        XCTAssertEqual(checklist.first { $0.name == "Spending money" }?.dueDate, "2026-08-25")

        let augustTransactions = store.snapshot.transactions.filter { $0.date >= augustPeriod.startDate && $0.date <= augustPeriod.endDate }
        XCTAssertEqual(augustTransactions.map(\.note).sorted(), ["ChatGPT", "Insurance"])
        XCTAssertTrue(augustTransactions.allSatisfy { $0.payPeriodId == augustPeriod.id })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-08-01" })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-08-01" })
        XCTAssertNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-skincare-2026-08-15" })
        XCTAssertNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-spending-money-2026-08-25" })
        XCTAssertEqual(PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: "2026-08-01")?.id, augustPeriod.id)

        for item in checklist {
            guard case let .recurringBill(paymentId, dueDate, payPeriodId) = item.action else {
                XCTFail("Expected August Basic Data checklist item to be recurring bill funding")
                continue
            }
            XCTAssertTrue(store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true))
        }

        let fundedAugustSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: augustPeriod,
            asOfDate: "2026-08-01"
        )
        XCTAssertEqual(fundedAugustSummary.committedCostsPence, 42500)
        XCTAssertEqual(fundedAugustSummary.unfundedChecklistPence, 0)
        XCTAssertEqual(fundedAugustSummary.projectedCostsPence, 42500)
        XCTAssertEqual(fundedAugustSummary.currentMoneyLeftPence, 57500)
        XCTAssertEqual(fundedAugustSummary.projectedMoneyLeftPence, 57500)

        var august15Settings = store.snapshot.settings
        august15Settings.manualTodayIso = "2026-08-15"
        store.updateSettings(august15Settings)

        XCTAssertNotNil(store.snapshot.transactions.first {
            $0.id == "card-recurring-rec-skincare-2026-08-15" &&
            $0.payPeriodId == augustPeriod.id
        })
        XCTAssertNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-spending-money-2026-08-25" })

        var august25Settings = store.snapshot.settings
        august25Settings.manualTodayIso = "2026-08-25"
        store.updateSettings(august25Settings)

        XCTAssertNotNil(store.snapshot.transactions.first {
            $0.id == "card-recurring-rec-spending-money-2026-08-25" &&
            $0.payPeriodId == augustPeriod.id
        })
        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-08-25"))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-chatgpt-2026-08-01" }.count, 1)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-insurance-2026-08-01" }.count, 1)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-skincare-2026-08-15" }.count, 1)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-spending-money-2026-08-25" }.count, 1)
    }

    @MainActor
    func testBasicDataAugustSecondPaysOnlyClosedCC1Statement() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let julyPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: julyPeriod))

        store.recordTransaction(
            potId: nil,
            creditCardId: "card-cc1",
            paymentMethod: .creditCard,
            amountPence: 1500,
            type: .spending,
            date: "2026-07-06",
            note: "July CC1 manual spend"
        )
        let cc1ManualSpendId = try XCTUnwrap(store.snapshot.transactions.first { $0.note == "July CC1 manual spend" }?.id)
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: cc1ManualSpendId, payPeriodId: julyPeriod.id, completed: true))

        store.recordTransaction(
            potId: nil,
            creditCardId: "card-cc2",
            paymentMethod: .creditCard,
            amountPence: 3300,
            type: .spending,
            date: "2026-07-16",
            note: "July CC2 manual spend"
        )
        let cc2ManualSpendId = try XCTUnwrap(store.snapshot.transactions.first { $0.note == "July CC2 manual spend" }?.id)
        XCTAssertTrue(store.setCardSpendFundingCompleted(transactionId: cc2ManualSpendId, payPeriodId: julyPeriod.id, completed: true))

        for date in ["2026-07-02", "2026-07-15", "2026-07-25"] {
            var settings = store.snapshot.settings
            settings.manualTodayIso = date
            store.updateSettings(settings)
        }

        var augustSettings = store.snapshot.settings
        augustSettings.manualTodayIso = "2026-08-01"
        store.updateSettings(augustSettings)

        let augustPeriod = try XCTUnwrap(store.selectedPayPeriod)
        let augustChecklist = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: augustPeriod)
        for paymentId in ["rec-insurance", "rec-chatgpt", "rec-skincare", "rec-spending-money"] {
            let item = try XCTUnwrap(augustChecklist.first { $0.paymentId == paymentId })
            XCTAssertTrue(store.setCardBillFundingCompleted(paymentId: item.paymentId, dueDate: item.dueDate, payPeriodId: augustPeriod.id, completed: true))
        }

        var august2Settings = store.snapshot.settings
        august2Settings.manualTodayIso = "2026-08-02"
        store.updateSettings(august2Settings)

        let cc1StatementRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc1" &&
            $0.statementDate == "2026-07-05" &&
            ($0.directDebitDate ?? $0.date) == "2026-08-02"
        })
        XCTAssertEqual(cc1StatementRepayment.amountPence, 7500)
        XCTAssertEqual(cc1StatementRepayment.paycheckContributionPence, 0)
        XCTAssertEqual(cc1StatementRepayment.potContributionPence, 0)

        let cardsById = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        let cc1 = try XCTUnwrap(cardsById["card-cc1"])
        let cc2 = try XCTUnwrap(cardsById["card-cc2"])
        let cc3 = try XCTUnwrap(cardsById["card-cc3"])
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc1, snapshot: store.snapshot), 14000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc2, snapshot: store.snapshot), 23300)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc3, snapshot: store.snapshot), 20000)
        XCTAssertEqual([cc1, cc2, cc3].reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot) }, 57300)

        let potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 6500)
        XCTAssertEqual(potsById["pot-cc2"]?.balancePence, 3300)
        XCTAssertEqual(potsById["pot-cc3"]?.balancePence, 20000)
        let pot1Progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(potsById["pot-cc1"]), snapshot: store.snapshot, today: "2026-08-02")
        XCTAssertEqual(pot1Progress.targetPence, 6500)
        XCTAssertEqual(pot1Progress.coveredPence, 6500)
        XCTAssertEqual(pot1Progress.shortfallPence, 0)
        XCTAssertEqual(pot1Progress.percent, 100)

        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: augustPeriod, asOfDate: "2026-08-02")
        XCTAssertEqual(summary.totalCostsPence, 42500)
        XCTAssertEqual(summary.moneyLeftPence, 57500)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-08-02"))
        XCTAssertEqual(store.snapshot.creditCardRepayments.filter {
            $0.creditCardId == "card-cc1" &&
            $0.statementDate == "2026-07-05" &&
            ($0.directDebitDate ?? $0.date) == "2026-08-02"
        }.count, 1)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-cc1" }?.balancePence, 6500)
    }

    @MainActor
    func testBasicDataDirectDateSkipProcessesMissedDueDays() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let julyPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: julyPeriod))

        var august5Settings = store.snapshot.settings
        august5Settings.manualTodayIso = "2026-08-05"
        store.updateSettings(august5Settings)

        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-07-01" })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-07-01" })
        XCTAssertNotNil(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc1" &&
            ($0.directDebitDate ?? $0.date) == "2026-07-02"
        })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-skincare-2026-07-15" })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-spending-money-2026-07-25" })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-08-01" })
        XCTAssertNotNil(store.snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-08-01" })
        XCTAssertNotNil(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc1" &&
            $0.statementDate == "2026-07-05" &&
            ($0.directDebitDate ?? $0.date) == "2026-08-02"
        })

        let augustPeriod = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertEqual(augustPeriod.startDate, "2026-08-01")
        XCTAssertEqual(augustPeriod.endDate, "2026-08-31")
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-08-01" }?.payPeriodId, augustPeriod.id)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-insurance-2026-08-01" }?.payPeriodId, augustPeriod.id)
        XCTAssertNotEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-chatgpt-2026-07-01" }?.payPeriodId, augustPeriod.id)
        XCTAssertEqual(store.snapshot.settings.lastProcessedDateIso, "2026-08-05")
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
    func testBasicDataPotDuePresentationUsesObligationDatesNotWholeTargetDueDate() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()

        let pot1 = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-cc1" })
        let pot2 = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-cc2" })
        let pot3 = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-cc3" })
        var pot1Progress = PlannerDerivedData.potProgress(pot: pot1, snapshot: store.snapshot, today: "2026-07-01")
        let pot3Progress = PlannerDerivedData.potProgress(pot: pot3, snapshot: store.snapshot, today: "2026-07-01")

        XCTAssertEqual(pot1Progress.targetPence, 62500)
        XCTAssertEqual(pot1Progress.nextObligation?.amountPence, 50000)
        XCTAssertEqual(pot1Progress.nextObligation?.dueIso, "2026-07-02")
        XCTAssertEqual(pot1Progress.nextObligation?.label, "CC1 opening balance")
        XCTAssertEqual(pot1Progress.laterObligation?.amountPence, 5000)
        XCTAssertEqual(pot1Progress.laterObligation?.dueIso, "2026-07-15")
        XCTAssertEqual(pot1Progress.laterObligation?.label, "Skincare")

        XCTAssertEqual(pot3Progress.targetPence, 20000)
        XCTAssertEqual(pot3Progress.nextObligation?.amountPence, 20000)
        XCTAssertEqual(pot3Progress.nextObligation?.dueIso, "2026-07-25")
        XCTAssertEqual(pot3Progress.nextObligation?.label, "Spending money")

        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))
        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))

        pot1Progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-cc1" }), snapshot: store.snapshot, today: "2026-07-01")
        let pot2Progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first { $0.id == pot2.id }), snapshot: store.snapshot, today: "2026-07-01")

        XCTAssertEqual(pot1Progress.nextObligation?.amountPence, 50000)
        XCTAssertEqual(pot1Progress.nextObligation?.dueIso, "2026-07-02")
        XCTAssertNil(pot2Progress.nextObligation)

        var july2Settings = store.snapshot.settings
        july2Settings.manualTodayIso = "2026-07-02"
        store.updateSettings(july2Settings)

        let july2Pot1Progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-cc1" }), snapshot: store.snapshot, today: "2026-07-02")
        XCTAssertEqual(july2Pot1Progress.nextObligation?.amountPence, 5000)
        XCTAssertEqual(july2Pot1Progress.nextObligation?.dueIso, "2026-07-15")
        XCTAssertEqual(july2Pot1Progress.nextObligation?.label, "Skincare")
    }

    func testLinkedCreditCardPotProgressShowsUpcomingStatementPaymentsSeparatelyFromFundingTarget() {
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
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [pot],
            payPeriods: [julyPeriod, augustPeriod],
            potAllocations: [insuranceAllocation],
            transactions: [insurance, manualSpend],
            creditCards: [card]
        )

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-08-01")

        XCTAssertEqual(progress.targetPence, 3300)
        XCTAssertEqual(progress.coveredPence, 3300)
        XCTAssertEqual(progress.shortfallPence, 0)
        XCTAssertEqual(progress.linkedCardPayments.map(\.dueIso), ["2026-08-10", "2026-09-10"])
        XCTAssertEqual(progress.linkedCardPayments.map(\.amountPence), [10000, 3300])
        XCTAssertEqual(progress.linkedCardPayments.map(\.statementIso), ["2026-07-15", "2026-08-15"])
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

    func testBasicDataAugustOverLimitAvailabilityIsSigned() {
        let snapshot = DefaultData.basicDataSnapshot
        let period = makePayPeriod(id: "period-august", startDate: "2026-08-01", endDate: "2026-08-31", payday: "2026-08-01", incomePence: 100000)
        let cc2 = snapshot.creditCards.first { $0.id == "card-cc2" }!
        let cc2Transactions = [
            makeTransaction(id: "txn-cc2-insurance", cardId: cc2.id, amountPence: 10000, date: "2026-07-01", note: "Insurance"),
            makeTransaction(id: "txn-cc2-aug-insurance", cardId: cc2.id, amountPence: 10000, date: "2026-08-01", note: "Insurance"),
            makeTransaction(id: "txn-cc2-manual", cardId: cc2.id, amountPence: 3300, date: "2026-07-25", note: "Manual CC2 spend")
        ]
        let availabilitySnapshot = makeSnapshot(payPeriods: [period], transactions: cc2Transactions, creditCards: [cc2])

        let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: cc2, snapshot: availabilitySnapshot, payPeriod: period, asOfDate: "2026-08-02")

        XCTAssertEqual(availability.actualAvailablePence, -3300)
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
    func testBasicDataFixtureProgressesFundedCardPotsAcrossDueDatesWithoutSecondPaycheckCost() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()
        let period = try XCTUnwrap(store.selectedPayPeriod)
        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))

        var july2Settings = store.snapshot.settings
        july2Settings.manualTodayIso = "2026-07-02"
        store.updateSettings(july2Settings)

        var potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 12500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc1" }), snapshot: store.snapshot), 7500)
        var summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-02")
        XCTAssertEqual(summary.moneyLeftPence, 7500)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)

        potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 12500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc1" }), snapshot: store.snapshot), 12500)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-skincare-2026-07-15" }?.potId, "pot-cc1")
        summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-15")
        XCTAssertEqual(summary.moneyLeftPence, 7500)
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
    func testBasicDataFixtureKeepsBillAndOpeningBalanceChecklistFundingSeparate() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()

        let period = try XCTUnwrap(store.selectedPayPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
        let cc1OpeningItem = openingItems.first { $0.cardId == "card-cc1" }
        XCTAssertEqual(cc1OpeningItem?.amountPence, 50000)
        XCTAssertEqual(cc1OpeningItem?.directDebitDate, "2026-07-02")
        XCTAssertEqual(cc1OpeningItem?.isCompleted, false)
    }

    @MainActor
    func testBasicDataUntickedChecklistSeparatesCurrentMoneyLeftFromProjectedFunding() async throws {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))

        await store.load()

        let period = try XCTUnwrap(store.selectedPayPeriod)
        let checklist = PlannerDerivedData.fundingChecklistPresentationItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: "2026-07-01"
        )
        XCTAssertEqual(checklist.count, 5)
        XCTAssertEqual(checklist.filter(\.isCompleted).count, 0)

        var summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.committedCostsPence, 0)
        XCTAssertEqual(summary.unfundedChecklistPence, 92500)
        XCTAssertEqual(summary.projectedCostsPence, 92500)
        XCTAssertEqual(summary.currentMoneyLeftPence, 100000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, 7500)

        XCTAssertTrue(fundBasicDataJulyChecklist(in: store, payPeriod: period))

        summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.committedCostsPence, 92500)
        XCTAssertEqual(summary.unfundedChecklistPence, 0)
        XCTAssertEqual(summary.projectedCostsPence, 92500)
        XCTAssertEqual(summary.currentMoneyLeftPence, 7500)
        XCTAssertEqual(summary.projectedMoneyLeftPence, 7500)
    }

    @MainActor
    func testBasicDataFixtureResetsChecklistTicksToUntickedOnFreshLaunch() async throws {
        let firstStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))
        await firstStore.load()
        let firstPeriod = try XCTUnwrap(firstStore.selectedPayPeriod)
        let chatGPTItem = try XCTUnwrap(PlannerDerivedData.cardBillFundingChecklistItems(snapshot: firstStore.snapshot, payPeriod: firstPeriod).first {
            $0.paymentId == "rec-chatgpt" && $0.dueDate == "2026-07-01"
        })

        XCTAssertFalse(chatGPTItem.isCompleted)

        XCTAssertTrue(firstStore.setCardBillFundingCompleted(
            paymentId: chatGPTItem.paymentId,
            dueDate: chatGPTItem.dueDate,
            payPeriodId: chatGPTItem.payPeriodId,
            completed: true
        ))
        XCTAssertTrue(PlannerDerivedData.cardBillFundingChecklistItems(snapshot: firstStore.snapshot, payPeriod: firstPeriod).first {
            $0.paymentId == "rec-chatgpt" && $0.dueDate == "2026-07-01"
        }?.isCompleted == true)

        let freshStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))
        await freshStore.load()
        let freshPeriod = try XCTUnwrap(freshStore.selectedPayPeriod)
        let freshChatGPTItem = try XCTUnwrap(PlannerDerivedData.cardBillFundingChecklistItems(snapshot: freshStore.snapshot, payPeriod: freshPeriod).first {
            $0.paymentId == "rec-chatgpt" && $0.dueDate == "2026-07-01"
        })

        XCTAssertFalse(freshChatGPTItem.isCompleted)
        XCTAssertTrue(freshStore.snapshot.potAllocations.isEmpty)
        XCTAssertEqual(freshStore.snapshot.pots.first { $0.id == "pot-cc1" }?.balancePence, 0)
    }

    @MainActor
    func testBasicDataFixtureRepositoryResetsBetweenLaunchesAndPersistsDuringSession() async throws {
        let repository = InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot)
        let firstStore = PlannerStore(repository: repository)

        await firstStore.load()
        firstStore.addPot(name: "Session pot", type: .reserved, category: "Bills", targetPence: nil, color: "#111827")
        try await repository.saveSnapshot(firstStore.snapshot)

        let secondStore = PlannerStore(repository: repository)
        await secondStore.load()
        XCTAssertTrue(secondStore.snapshot.pots.contains { $0.name == "Session pot" })

        let freshStore = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.basicDataSnapshot))
        await freshStore.load()
        XCTAssertFalse(freshStore.snapshot.pots.contains { $0.name == "Session pot" })
    }

    @MainActor
    func testLoadMigratesOnlyUntouchedLegacyDefaultPots() async {
        let untouched = DefaultData.defaultPots[0]
        var renamed = DefaultData.defaultPots[1]
        renamed.name = "My subscriptions"
        var funded = DefaultData.defaultPots[2]
        funded.balancePence = 5000
        let referenced = DefaultData.defaultPots[3]
        let payment = makeRecurringPayment(id: "rec-transport", name: "Train", amountPence: 4500, dueDay: 5, potId: referenced.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(pots: [untouched, renamed, funded, referenced], recurringPayments: [payment])))

        await store.load()

        XCTAssertFalse(store.snapshot.pots.contains { $0.id == untouched.id })
        XCTAssertTrue(store.snapshot.pots.contains { $0.id == renamed.id })
        XCTAssertTrue(store.snapshot.pots.contains { $0.id == funded.id })
        XCTAssertTrue(store.snapshot.pots.contains { $0.id == referenced.id })
    }

    @MainActor
    func testLoadKeepsExistingPlannerDataWhenUpdateCleanupFlagIsUnset() async {
        UserDefaults.standard.set(false, forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
        let settings = makeManualSettings(today: "2026-06-20")
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let pot = makePot(id: "pot-user", name: "User pot", balancePence: 10000, targetPence: nil)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-06-20", dueDay: 1)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 1200, date: "2026-06-10", note: "Coffee")
        let allocation = makePotAllocation(id: "allocation-user", payPeriodId: period.id, potId: pot.id, amountPence: 10000, source: .manual, recurringPaymentId: nil, recurringDueDate: nil)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], payPeriods: [period], potAllocations: [allocation], transactions: [spend], creditCards: [card])))

        await store.load()

        XCTAssertEqual(store.snapshot.pots.map(\.id), [pot.id])
        XCTAssertEqual(store.snapshot.payPeriods.map(\.id), [period.id])
        XCTAssertEqual(store.snapshot.potAllocations.map(\.id), [allocation.id])
        XCTAssertEqual(store.snapshot.transactions.map(\.id), [spend.id])
        XCTAssertEqual(store.snapshot.creditCards.map(\.id), [card.id])
    }

    func testFileRepositoryRoundTripPreservesUserPlannerData() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("new-money-\(UUID().uuidString)")
            .appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let repository = FilePlannerRepository(fileURL: fileURL)
        let period = makePayPeriod(id: "period-june", startDate: "2026-06-01", endDate: "2026-06-30", payday: "2026-06-01", incomePence: 50000)
        let pot = makePot(id: "pot-user", name: "User pot", balancePence: 10000, targetPence: nil)
        let card = makeCreditCard(id: "card-main", name: "Barclays", openingBalancePence: 50000, openingStatementBalancePence: 50000, statementDate: "2026-06-20", dueDay: 1)
        let spend = makeTransaction(id: "txn-coffee", cardId: card.id, amountPence: 1200, date: "2026-06-10", note: "Coffee")
        let snapshot = makeSnapshot(pots: [pot], payPeriods: [period], transactions: [spend], creditCards: [card])

        try await repository.saveSnapshot(snapshot)
        let loaded = try await repository.loadSnapshot()

        XCTAssertEqual(loaded.pots, [pot])
        XCTAssertEqual(loaded.payPeriods, [period])
        XCTAssertEqual(loaded.transactions, [spend])
        XCTAssertEqual(loaded.creditCards, [card])
    }

    @MainActor
    func testResetLocalDataClearsUserEnteredPlannerData() async {
        let settings = makeManualSettings(today: "2026-01-01")
        let pot = makePot(id: "pot-user", name: "User pot", balancePence: 5000, targetPence: 10000)
        let payment = makeRecurringPayment(id: "rec-user", name: "User bill", amountPence: 1200, dueDay: 10, potId: nil)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], recurringPayments: [payment])))

        await store.load()
        XCTAssertNotEqual(store.snapshot, DefaultData.emptySnapshot)

        store.resetLocalData()

        XCTAssertEqual(store.snapshot, DefaultData.emptySnapshot)
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

    func testPotProgressFallsBackToManualTargetAndShowsRealOverTargetPercent() {
        let pot = makePot(id: "pot-holiday", name: "Holiday", balancePence: 15000, targetPence: 10000)
        let snapshot = makeSnapshot(pots: [pot])

        let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: "2026-06-01")

        XCTAssertEqual(progress.targetPence, 10000)
        XCTAssertEqual(progress.percent, 150)
        XCTAssertEqual(progress.sourceLabels, [])
    }

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

        store.markRecurringBillOccurrenceAwaiting(paymentId: payment.id, scheduledDueDate: "2026-06-15")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 10_000)
        XCTAssertTrue(store.snapshot.transactions.first?.deletedAt != nil)

        store.confirmRecurringBillOccurrence(paymentId: payment.id, scheduledDueDate: "2026-06-15", actualDueDate: "2026-06-18")
        var laterSettings = store.snapshot.settings
        laterSettings.manualTodayIso = "2026-06-19"
        store.updateSettings(laterSettings)

        let activeTransaction = store.snapshot.transactions.first { $0.deletedAt == nil }
        XCTAssertEqual(activeTransaction?.id, "recurring-rec-phone-2026-06-15")
        XCTAssertEqual(activeTransaction?.date, "2026-06-18")
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 6_000)
        XCTAssertEqual(store.snapshot.transactions.filter { $0.deletedAt == nil }.count, 1)
    }

    @MainActor
    func testConfirmedRecurringCardBillMovesGeneratedChargeToActualDate() async {
        let settings = makeManualSettings(today: "2026-06-15")
        let card = makeCreditCard(id: "card-main", name: "Main card", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-06-20", dueDay: 1)
        let payment = makeRecurringPayment(id: "rec-streaming", name: "Streaming", amountPence: 1_500, dueDay: 15, potId: nil, creditCardId: card.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, recurringPayments: [payment], creditCards: [card])))

        await store.load()
        store.markRecurringBillOccurrenceAwaiting(paymentId: payment.id, scheduledDueDate: "2026-06-15")
        store.confirmRecurringBillOccurrence(paymentId: payment.id, scheduledDueDate: "2026-06-15", actualDueDate: "2026-06-18")
        var laterSettings = store.snapshot.settings
        laterSettings.manualTodayIso = "2026-06-19"
        store.updateSettings(laterSettings)

        let charge = store.snapshot.transactions.first { $0.deletedAt == nil && $0.recurringPaymentId == payment.id }
        XCTAssertEqual(charge?.id, "card-recurring-rec-streaming-2026-06-15")
        XCTAssertEqual(charge?.date, "2026-06-18")
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot), 1_500)
    }

    func testPlanningOnlyRecurringBillOverrideMovesOnlyTheResolvedOccurrence() {
        let payment = makeRecurringPayment(id: "rec-plan", name: "Planning bill", amountPence: 2_000, dueDay: 15, potId: nil)
        var snapshot = makeSnapshot(recurringPayments: [payment])
        snapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(
                id: "override",
                paymentId: payment.id,
                scheduledDueDate: "2026-06-15",
                state: .confirmed,
                actualDueDate: "2026-06-18",
                reversedGeneratedTransactionIds: [],
                createdAt: "2026-06-15T00:00:00.000Z",
                updatedAt: "2026-06-15T00:00:00.000Z",
                deletedAt: nil
            )
        ]

        let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: [payment],
            startDate: "2026-06-01",
            endDate: "2026-07-31"
        )

        XCTAssertEqual(occurrences.first { $0.scheduledDueDate == "2026-06-15" }?.dueDate, "2026-06-18")
        XCTAssertEqual(occurrences.first { $0.scheduledDueDate == "2026-07-15" }?.dueDate, "2026-07-15")
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

    func testCreditCardStatementUsesOpeningBalanceAndIncludesStatementDaySpendInClosingCycle() {
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
        XCTAssertEqual(payments.map(\.actualDuePence), [17000, 0])
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
        XCTAssertEqual(cc1Statement.statementAmountPence, 7500)
        XCTAssertEqual(cc1Statement.paidAmountPence, 0)
        XCTAssertEqual(cc1Statement.unpaidAmountPence, 7500)
        XCTAssertEqual(cc1Statement.status, .upcoming)
        XCTAssertEqual(cc1Statement.transactions.map(\.name), ["ChatGPT"])
        XCTAssertEqual(cc1Statement.transactions.map(\.date), ["2026-07-01"])
        XCTAssertEqual(cc1Statement.transactions.map(\.amountPence), [7500])
        XCTAssertEqual(cc1Statement.transactions.map(\.source), [.recurring])

        let cc2Statement = try XCTUnwrap(statements.first { $0.cardId == "card-cc2" && $0.statementDate == "2026-07-15" })
        XCTAssertEqual(cc2Statement.directDebitDate, "2026-08-10")
        XCTAssertEqual(cc2Statement.statementAmountPence, 10000)
        XCTAssertEqual(cc2Statement.status, .upcoming)
        XCTAssertEqual(cc2Statement.transactions.map(\.name), ["Insurance"])

        let repayment = CreditCardRepayment(
            id: "repay-cc1-july",
            creditCardId: "card-cc1",
            amountPence: 7500,
            date: "2026-08-02",
            note: "CC1 direct debit",
            statementDate: "2026-07-05",
            directDebitDate: "2026-08-02",
            source: .linkedPotStatement,
            potId: nil,
            potContributionPence: 0,
            paycheckContributionPence: 0,
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
    func testExcludingFundingChecklistItemKeepsItVisibleAndRemovesOnlyThatOccurrenceFromProjectedCosts() async throws {
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
        XCTAssertEqual(excludedSummary.projectedMoneyLeftPence, 50000)

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
        XCTAssertEqual(beforeDueProgress.targetPence, 10000)
        XCTAssertEqual(beforeDueProgress.shortfallPence, 10000)

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

    func testMigrationRemovesKnownAutomaticVitaminsCardBillFunding() {
        var settings = makeManualSettings(today: "2026-07-16")
        settings.cardRecurringAutoFundingRepairVersion = 1
        let potID = "pot-4b7c6b1d-e5e8-4704-9d6b-e0a7243acbc9"
        let cardID = "card-6747ab5b-82d1-4ccb-a3cc-3cc0dd0ad309"
        let paymentID = "recurring-dd0df7dd-f274-4902-8109-515c02762ca9"
        let allocation = PotAllocation(
            id: "recurring-bill-funding-allocation-recurring-dd0df7dd-f274-4902-8109-515c02762ca9-2026-07-11-pay-period-2026-07-01",
            payPeriodId: "pay-period-2026-07-01",
            potId: potID,
            fundingPotId: nil,
            amountPence: 2212,
            source: .recurringBillFunding,
            recurringPaymentId: paymentID,
            recurringDueDate: "2026-07-11",
            debtId: nil,
            debtDueDate: nil,
            transactionId: nil,
            transactionDate: nil,
            creditCardId: cardID,
            creditCardDirectDebitDate: nil,
            createdAt: "2026-07-11T13:16:31.944Z",
            updatedAt: "2026-07-11T13:16:31.944Z",
            deletedAt: nil
        )
        let transaction = Transaction(
            id: "card-recurring-recurring-dd0df7dd-f274-4902-8109-515c02762ca9-2026-07-11",
            potId: potID,
            payPeriodId: "pay-period-2026-07-01",
            amountPence: 2212,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: cardID,
            recurringPaymentId: paymentID,
            date: "2026-07-11",
            note: "Vitamins",
            createdAt: "2026-07-11T13:16:14.296Z",
            updatedAt: "2026-07-11T13:16:31.946Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [makePot(id: potID, name: "Zable", balancePence: 2212, targetPence: nil, linkedCreditCardId: cardID)],
            potAllocations: [allocation],
            transactions: [transaction]
        )

        let migrated = DefaultData.migratedSnapshot(snapshot).snapshot
        XCTAssertEqual(migrated.settings.cardRecurringAutoFundingRepairVersion, 1)
        XCTAssertTrue(migrated.potAllocations.isEmpty)
        XCTAssertEqual(migrated.pots.first?.balancePence, 0)
        XCTAssertNil(migrated.transactions.first?.potId)
    }

    func testMigrationKeepsLaterUserConfirmedVitaminsCardBillFunding() {
        var settings = makeManualSettings(today: "2026-07-16")
        settings.cardRecurringAutoFundingRepairVersion = 1
        let potID = "pot-4b7c6b1d-e5e8-4704-9d6b-e0a7243acbc9"
        let cardID = "card-6747ab5b-82d1-4ccb-a3cc-3cc0dd0ad309"
        let allocation = PotAllocation(
            id: "recurring-bill-funding-allocation-recurring-dd0df7dd-f274-4902-8109-515c02762ca9-2026-07-11-pay-period-2026-07-01",
            payPeriodId: "pay-period-2026-07-01",
            potId: potID,
            fundingPotId: nil,
            amountPence: 2212,
            source: .recurringBillFunding,
            recurringPaymentId: "recurring-dd0df7dd-f274-4902-8109-515c02762ca9",
            recurringDueDate: "2026-07-11",
            debtId: nil,
            debtDueDate: nil,
            transactionId: nil,
            transactionDate: nil,
            creditCardId: cardID,
            creditCardDirectDebitDate: nil,
            userConfirmed: true,
            createdAt: "2026-07-16T12:00:00.000Z",
            updatedAt: "2026-07-16T12:00:00.000Z",
            deletedAt: nil
        )
        let snapshot = makeSnapshot(
            settings: settings,
            pots: [makePot(id: potID, name: "Zable", balancePence: 2212, targetPence: nil, linkedCreditCardId: cardID)],
            potAllocations: [allocation]
        )

        let migrated = DefaultData.migratedSnapshot(snapshot).snapshot
        XCTAssertEqual(migrated.potAllocations.first?.id, allocation.id)
        XCTAssertEqual(migrated.potAllocations.first?.userConfirmed, true)
        XCTAssertEqual(migrated.pots.first?.balancePence, 2212)
    }

    func testMigrationRestoresUnsettledLegacyRecurringCardBillReserveOnce() {
        var settings = makeManualSettings(today: "2026-07-11")
        settings.cardRecurringPotReserveMigrationVersion = nil
        let card = makeCreditCard(id: "card-zable", name: "Zable", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-07-24", dueDay: 1)
        let pot = makePot(id: "pot-zable", name: "Zable", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let transaction = Transaction(
            id: "card-recurring-rec-vitamins-2026-07-11",
            potId: pot.id,
            payPeriodId: "period-july",
            amountPence: 2212,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: "rec-vitamins",
            date: "2026-07-11",
            note: "Vitamins",
            createdAt: "2026-07-11T00:00:00.000Z",
            updatedAt: "2026-07-11T00:00:00.000Z",
            deletedAt: nil
        )
        let allocation = makePotAllocation(
            id: "allocation-vitamins",
            payPeriodId: "period-july",
            potId: pot.id,
            amountPence: 2212,
            recurringPaymentId: "rec-vitamins",
            recurringDueDate: "2026-07-11"
        )
        let legacySnapshot = makeSnapshot(settings: settings, pots: [pot], payPeriods: [], potAllocations: [allocation], transactions: [transaction], creditCards: [card])

        let migrated = DefaultData.migratedSnapshot(legacySnapshot).snapshot
        XCTAssertEqual(migrated.pots.first?.balancePence, 2212)
        XCTAssertEqual(migrated.settings.cardRecurringPotReserveMigrationVersion, 1)

        let rerun = DefaultData.migratedSnapshot(migrated).snapshot
        XCTAssertEqual(rerun.pots.first?.balancePence, 2212)
    }

    func testMigrationDoesNotRestoreLegacyCardBillReserveAfterStatementRepayment() {
        var settings = makeManualSettings(today: "2026-08-01")
        settings.cardRecurringPotReserveMigrationVersion = nil
        let card = makeCreditCard(id: "card-zable", name: "Zable", openingBalancePence: 0, openingStatementBalancePence: nil, statementDate: "2026-07-24", dueDay: 1)
        let pot = makePot(id: "pot-zable", name: "Zable", balancePence: 0, targetPence: nil, linkedCreditCardId: card.id)
        let transaction = Transaction(
            id: "card-recurring-rec-vitamins-2026-07-11",
            potId: pot.id,
            payPeriodId: "period-july",
            amountPence: 2212,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: card.id,
            recurringPaymentId: "rec-vitamins",
            date: "2026-07-11",
            note: "Vitamins",
            createdAt: "2026-07-11T00:00:00.000Z",
            updatedAt: "2026-07-11T00:00:00.000Z",
            deletedAt: nil
        )
        let allocation = makePotAllocation(
            id: "allocation-vitamins",
            payPeriodId: "period-july",
            potId: pot.id,
            amountPence: 2212,
            recurringPaymentId: "rec-vitamins",
            recurringDueDate: "2026-07-11"
        )
        let repayment = CreditCardRepayment(
            id: "repayment-zable-2026-08-01",
            creditCardId: card.id,
            amountPence: 2212,
            date: "2026-08-01",
            note: "Zable statement payment",
            statementDate: "2026-07-24",
            directDebitDate: "2026-08-01",
            source: .linkedPotStatement,
            potId: pot.id,
            potContributionPence: 0,
            potContributions: [],
            paycheckContributionPence: 0,
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
        let legacySnapshot = makeSnapshot(settings: settings, pots: [pot], potAllocations: [allocation], transactions: [transaction], creditCards: [card], creditCardRepayments: [repayment])

        let migrated = DefaultData.migratedSnapshot(legacySnapshot).snapshot
        XCTAssertEqual(migrated.pots.first?.balancePence, 0)
        XCTAssertEqual(migrated.settings.cardRecurringPotReserveMigrationVersion, 1)
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

    private func makeManualSettings(today: String) -> Settings {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = today
        return settings
    }

    private func statementSummary(
        in snapshot: PlannerSnapshot,
        cardId: String,
        statementDate: String,
        asOfDate: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CreditCardStatementSummary {
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: asOfDate)
        return try XCTUnwrap(
            statements.first { $0.cardId == cardId && $0.statementDate == statementDate },
            file: file,
            line: line
        )
    }

    @MainActor
    private func completeFundingChecklistItem(
        _ item: FundingChecklistPresentationItem,
        in store: PlannerStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let completed: Bool
        switch item.action {
        case .recurringBill(let paymentId, let dueDate, let payPeriodId):
            completed = store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        case .cardBill(let paymentId, let dueDate, let payPeriodId):
            completed = store.setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        case .cardSpend(let transactionId, let payPeriodId):
            completed = store.setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: true)
        case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
            completed = store.setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true)
        case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
            completed = store.setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true)
        case .debt(let debtId, let dueDate, let payPeriodId):
            completed = store.setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        }
        XCTAssertTrue(completed, item.name, file: file, line: line)
    }

    private func ledgerSignature(for snapshot: PlannerSnapshot, asOfDate: String) -> [String] {
        let transactionLines = snapshot.transactions
            .sorted { $0.id < $1.id }
            .map {
                "txn:\($0.id):\($0.date):\($0.amountPence):\($0.payPeriodId ?? ""):\($0.potId ?? ""):\($0.creditCardId ?? "")"
            }
        let repaymentLines = snapshot.creditCardRepayments
            .sorted { $0.id < $1.id }
            .map {
                "repay:\($0.id):\($0.date):\($0.amountPence):\($0.statementDate ?? ""):\($0.directDebitDate ?? ""):\($0.potContributionPence ?? -1):\($0.paycheckContributionPence ?? -1)"
            }
        let potLines = snapshot.pots
            .sorted { $0.id < $1.id }
            .map { "pot:\($0.id):\($0.balancePence)" }
        let cardLines = snapshot.creditCards
            .sorted { $0.id < $1.id }
            .map { "card:\($0.id):\(PlannerDerivedData.cardBalance(card: $0, snapshot: snapshot))" }
        let selectedPeriod = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: asOfDate)
        let summaryLines: [String]
        if let selectedPeriod {
            let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: selectedPeriod, asOfDate: asOfDate)
            summaryLines = [
                "period:\(selectedPeriod.id):\(selectedPeriod.startDate):\(selectedPeriod.endDate):\(summary.totalCostsPence):\(summary.moneyLeftPence)"
            ]
        } else {
            summaryLines = ["period:none"]
        }

        return transactionLines + repaymentLines + potLines + cardLines + summaryLines
    }

    @MainActor
    private func runFullAppLogicTortureJulSep2027SimulationSheets() -> [FullAppSheetPayload] {
        let snapshot = DefaultData.fullAppLogicTortureJulSep2027Snapshot
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)
        var runner = FullAppSimulationRunner(store: store)
        return runner.run()
    }

    private func fullAppSheet(named name: String, in sheets: [FullAppSheetPayload]) -> FullAppSheetPayload? {
        sheets.first { $0.name == name }
    }

    private func fullAppRow(in sheet: FullAppSheetPayload, where header: String, equals value: String) -> [FullAppCellValue]? {
        fullAppRow(in: sheet, matching: [header: value])
    }

    private func fullAppRow(in sheet: FullAppSheetPayload, matching expectedValues: [String: String]) -> [FullAppCellValue]? {
        sheet.rows.first { row in
            expectedValues.allSatisfy { header, expectedValue in
                fullAppText(row, in: sheet, header) == expectedValue
            }
        }
    }

    private func fullAppPence(_ row: [FullAppCellValue], in sheet: FullAppSheetPayload, _ header: String) -> Int {
        guard let index = sheet.headers.firstIndex(of: header) else {
            XCTFail("Missing full app simulation column \(header)")
            return 0
        }

        switch row[index] {
        case .number(let value):
            return Int((value * 100).rounded())
        case .text(let value):
            XCTFail("Expected money value in \(header), got \(value)")
            return 0
        case .blank:
            XCTFail("Expected money value in \(header), got blank")
            return 0
        }
    }

    private func fullAppText(_ row: [FullAppCellValue], in sheet: FullAppSheetPayload, _ header: String) -> String {
        guard let index = sheet.headers.firstIndex(of: header) else {
            XCTFail("Missing full app simulation column \(header)")
            return ""
        }

        switch row[index] {
        case .text(let value):
            return value
        case .number(let value):
            return String(value)
        case .blank:
            return ""
        }
    }

    @MainActor
    private func fundBasicDataJulyChecklist(in store: PlannerStore, payPeriod: PayPeriod) -> Bool {
        let billItems = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: payPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: payPeriod)

        guard
            let chatGPT = billItems.first(where: { $0.paymentId == "rec-chatgpt" && $0.dueDate == "2026-07-01" }),
            let insurance = billItems.first(where: { $0.paymentId == "rec-insurance" && $0.dueDate == "2026-07-01" }),
            let skincare = billItems.first(where: { $0.paymentId == "rec-skincare" && $0.dueDate == "2026-07-15" }),
            let spendingMoney = billItems.first(where: { $0.paymentId == "rec-spending-money" && $0.dueDate == "2026-07-25" }),
            let cc1Opening = openingItems.first(where: { $0.cardId == "card-cc1" && $0.directDebitDate == "2026-07-02" })
        else { return false }

        return store.setCardBillFundingCompleted(paymentId: insurance.paymentId, dueDate: insurance.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: chatGPT.paymentId, dueDate: chatGPT.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardOpeningBalanceFundingCompleted(cardId: cc1Opening.cardId, directDebitDate: cc1Opening.directDebitDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: skincare.paymentId, dueDate: skincare.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: spendingMoney.paymentId, dueDate: spendingMoney.dueDate, payPeriodId: payPeriod.id, completed: true)
    }

    private func makeSnapshot(
        settings: Settings = DefaultData.defaultSettings,
        bankAccounts: [BankAccount] = [],
        pots: [Pot] = [],
        recurringPayments: [RecurringPayment] = [],
        payPeriods: [PayPeriod] = [],
        potAllocations: [PotAllocation] = [],
        transactions: [Transaction] = [],
        debts: [Debt] = [],
        debtPayments: [DebtPayment] = [],
        debtPaymentScheduleItems: [DebtPaymentScheduleItem] = [],
        creditCards: [CreditCard] = [],
        customPayments: [CustomPayment] = [],
        creditCardRepayments: [CreditCardRepayment] = [],
        oneOffIncomes: [OneOffIncome] = [],
        fundingChecklistExclusions: [FundingChecklistExclusion] = []
    ) -> PlannerSnapshot {
        PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: payPeriods,
            paychecks: [],
            potAllocations: potAllocations,
            transactions: transactions,
            debts: debts,
            debtPayments: debtPayments,
            debtReserves: [],
            debtPaymentScheduleItems: debtPaymentScheduleItems,
            debtSnapshots: [],
            creditCards: creditCards,
            customPayments: customPayments,
            creditCardRepayments: creditCardRepayments,
            creditCardPots: [],
            dailyBriefs: [],
            oneOffIncomes: oneOffIncomes,
            fundingChecklistExclusions: fundingChecklistExclusions,
            bankAccounts: bankAccounts
        )
    }

    private func makePot(
        id: String,
        name: String,
        balancePence: Int,
        targetPence: Int?,
        linkedCreditCardId: String? = nil,
        linkedDebtId: String? = nil,
        fundingBankAccountId: String? = nil
    ) -> Pot {
        Pot(
            id: id,
            name: name,
            type: .reserved,
            category: "Bills",
            icon: nil,
            balancePence: balancePence,
            targetPence: targetPence,
            color: "#2563eb",
            linkedCreditCardId: linkedCreditCardId,
            linkedDebtId: linkedDebtId,
            fundingBankAccountId: fundingBankAccountId,
            archived: false,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makeRecurringPayment(
        id: String,
        name: String,
        amountPence: Int,
        dueDay: Int?,
        potId: String?,
        creditCardId: String? = nil,
        bankAccountId: String? = nil,
        dueDate: String? = nil,
        frequency: RecurringFrequency = .monthly,
        createdAt: String = "2026-06-01T00:00:00.000Z"
    ) -> RecurringPayment {
        RecurringPayment(
            id: id,
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: dueDate,
            frequency: frequency,
            potId: potId,
            creditCardId: creditCardId,
            bankAccountId: bankAccountId,
            priority: .essential,
            active: true,
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil
        )
    }

    private func makeBankAccount(
        id: String,
        name: String = "Main account",
        openingBalancePence: Int = 0,
        isPrimary: Bool = true
    ) -> BankAccount {
        BankAccount(
            id: id,
            name: name,
            provider: "Test Bank",
            type: .current,
            openingBalancePence: openingBalancePence,
            lastFourDigits: "1234",
            color: "#2563EB",
            isPrimary: isPrimary,
            archived: false,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makeDebt(id: String, name: String, currentBalancePence: Int, dueDate: String) -> Debt {
        Debt(
            id: id,
            name: name,
            lender: "Loan Provider",
            originalAmountPence: currentBalancePence,
            currentBalancePence: currentBalancePence,
            minimumPaymentPence: 0,
            dueDate: dueDate,
            interestRateApr: nil,
            note: "",
            status: .active,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makePlannerDebt(
        id: String,
        name: String,
        startingBalancePence: Int,
        targetPayoffDate: String?,
        type: DebtType = .other,
        interestType: DebtInterestType = .none,
        aprBasisPoints: Int? = nil,
        fixedFeePence: Int = 0,
        minimumPaymentPence: Int = 0,
        extraPaymentPence: Int = 0,
        repaymentStrategy: DebtRepaymentStrategy,
        paymentFrequency: DebtPaymentFrequency,
        paymentDay: Int? = nil,
        payFirstTiming: DebtPayFirstTiming = .nextPayday
    ) -> Debt {
        Debt(
            id: id,
            name: name,
            lender: "Loan Provider",
            originalAmountPence: startingBalancePence,
            currentBalancePence: startingBalancePence,
            minimumPaymentPence: minimumPaymentPence,
            dueDate: targetPayoffDate ?? "",
            interestRateApr: aprBasisPoints.map { Double($0) / 100.0 },
            note: "",
            status: .active,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil,
            type: type,
            startingBalancePence: startingBalancePence,
            targetPayoffDate: targetPayoffDate,
            interestType: interestType,
            aprBasisPoints: aprBasisPoints,
            interestAccrualMode: interestType == .apr ? .dailyEstimated : DebtInterestAccrualMode.none,
            fixedFeePence: fixedFeePence,
            extraPaymentPence: extraPaymentPence,
            repaymentStrategy: repaymentStrategy,
            paymentFrequency: paymentFrequency,
            paymentDay: paymentDay,
            payFirstTiming: payFirstTiming,
            customFirstPaymentDate: nil,
            recalculationMode: repaymentStrategy.defaultRecalculationMode
        )
    }

    private func makeDebtScheduleItem(
        id: String,
        debtId: String,
        dueDate: String,
        amountPence: Int,
        fundedAmountPence: Int = 0,
        status: DebtPaymentScheduleStatus = .planned
    ) -> DebtPaymentScheduleItem {
        DebtPaymentScheduleItem(
            id: id,
            debtId: debtId,
            dueDate: dueDate,
            plannedAmountPence: amountPence,
            principalAmountPence: amountPence,
            interestAmountPence: 0,
            feeAmountPence: 0,
            fundedAmountPence: fundedAmountPence,
            paidAmountPence: 0,
            paidDate: nil,
            status: status,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makeCreditCard(
        id: String,
        name: String,
        limitPence: Int = 80000,
        openingBalancePence: Int,
        openingStatementBalancePence: Int?,
        statementDate: String?,
        dueDay: Int?,
        createdAt: String = "2026-05-20T00:00:00.000Z"
    ) -> CreditCard {
        CreditCard(
            id: id,
            name: name,
            provider: name,
            limitPence: limitPence,
            openingBalancePence: openingBalancePence,
            openingStatementBalancePence: openingStatementBalancePence,
            statementDate: statementDate,
            designId: nil,
            dueDay: dueDay,
            dueDate: nil,
            color: "#2563eb",
            archived: false,
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil
        )
    }

    private func makePayPeriod(id: String, startDate: String, endDate: String, payday: String, incomePence: Int) -> PayPeriod {
        PayPeriod(
            id: id,
            startDate: startDate,
            endDate: endDate,
            payday: payday,
            nextPayday: FinanceEngine.addIsoDays(date: endDate, days: 1),
            incomePence: incomePence,
            status: .active,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makeTransaction(id: String, cardId: String, amountPence: Int, date: String, note: String) -> Transaction {
        Transaction(
            id: id,
            potId: nil,
            payPeriodId: nil,
            amountPence: amountPence,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: cardId,
            recurringPaymentId: nil,
            date: date,
            note: note,
            createdAt: "\(date)T10:00:00.000Z",
            updatedAt: "\(date)T10:00:00.000Z",
            deletedAt: nil
        )
    }

    private func makePotAllocation(
        id: String,
        payPeriodId: String,
        potId: String,
        amountPence: Int,
        source: PotAllocationSource = .cardBillFunding,
        recurringPaymentId: String?,
        recurringDueDate: String?,
        debtId: String? = nil,
        debtDueDate: String? = nil
    ) -> PotAllocation {
        PotAllocation(
            id: id,
            payPeriodId: payPeriodId,
            potId: potId,
            fundingPotId: nil,
            amountPence: amountPence,
            source: source,
            recurringPaymentId: recurringPaymentId,
            recurringDueDate: recurringDueDate,
            debtId: debtId,
            debtDueDate: debtDueDate,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }
}

private actor TestPlannerRepository: PlannerRepository {
    private var snapshot: PlannerSnapshot

    init(snapshot: PlannerSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() async throws -> PlannerSnapshot {
        snapshot
    }

    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        self.snapshot = snapshot
    }

    func resetSnapshot() async throws {
        snapshot = DefaultData.emptySnapshot
    }
}

private struct FullAppLogicTortureJulSep2027SimulationResult {
    var fixtureSeeded: Bool
    var dailyRowCount: Int
    var rowCounts: [String: Int]
    var actualJsonPath: String
    var expectedWorkbookPath: String
    var actualWorkbookPath: String
    var comparisonReportPath: String
}

private struct FinalDebtFullAppSimJanApr2028SimulationResult {
    var fixtureSeeded: Bool
    var dailyRowCount: Int
    var rowCounts: [String: Int]
    var totalMismatches: Int
    var actualJsonPath: String
    var expectedWorkbookPath: String
    var actualWorkbookPath: String
    var comparisonReportPath: String
}

private enum FullAppCellValue: Encodable {
    case blank
    case number(Double)
    case text(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .blank:
            try container.encodeNil()
        case .number(let value):
            try container.encode(value)
        case .text(let value):
            try container.encode(value)
        }
    }
}

private struct FullAppSheetPayload: Encodable {
    var name: String
    var headers: [String]
    var rows: [[FullAppCellValue]]
}

private struct FullAppSimulationPayload: Encodable {
    var generatedAt: String
    var fixtureSeeded: Bool
    var startDate: String
    var endDate: String
    var expectedWorkbookPath: String
    var actualWorkbookPath: String
    var comparisonReportPath: String
    var rowCounts: [String: Int]
    var sheets: [FullAppSheetPayload]
}

@MainActor
private enum FullAppLogicTortureJulSep2027Simulation {
    static func runAndWriteArtifacts() async throws -> FullAppLogicTortureJulSep2027SimulationResult {
        let fixtureRepository = PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.fullAppLogicTortureJulSep2027FixtureValue
        ])
        let fixtureSeeded = fixtureRepository is InMemoryPlannerRepository
        let seedSnapshot = try await fixtureRepository.loadSnapshot()
        let store = PlannerStore(repository: fixtureRepository)
        store.useSnapshotForSimulation(seedSnapshot)

        var runner = FullAppSimulationRunner(store: store)
        let sheets = runner.run()
        let rowCounts = Dictionary(uniqueKeysWithValues: sheets.map { ($0.name, $0.rows.count) })

        let fileManager = FileManager.default
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewMoneyIPhoneTests", isDirectory: true)
            .appendingPathComponent("full_app_simulation_jul_sep_2027", isDirectory: true)
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let actualJsonURL = outputDirectory.appendingPathComponent("full_app_sim_actual_jul_sep_2027.json")
        let actualWorkbookURL = outputDirectory.appendingPathComponent("full_app_sim_actual_jul_sep_2027.xlsx")
        let comparisonReportURL = outputDirectory.appendingPathComponent("full_app_sim_comparison_report_jul_sep_2027.md")
        let expectedWorkbookPath = "/Users/jackd/Downloads/full_app_simulation_package_jul_sep_2027/full_app_sim_expected_outputs_jul_sep_2027.xlsx"

        let payload = FullAppSimulationPayload(
            generatedAt: DateUtilities.nowIsoString(),
            fixtureSeeded: fixtureSeeded,
            startDate: FullAppSimulationRunner.startDate,
            endDate: FullAppSimulationRunner.endDate,
            expectedWorkbookPath: expectedWorkbookPath,
            actualWorkbookPath: actualWorkbookURL.path,
            comparisonReportPath: comparisonReportURL.path,
            rowCounts: rowCounts,
            sheets: sheets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: actualJsonURL, options: [.atomic])

        return FullAppLogicTortureJulSep2027SimulationResult(
            fixtureSeeded: fixtureSeeded,
            dailyRowCount: rowCounts["Daily Actual"] ?? 0,
            rowCounts: rowCounts,
            actualJsonPath: actualJsonURL.path,
            expectedWorkbookPath: expectedWorkbookPath,
            actualWorkbookPath: actualWorkbookURL.path,
            comparisonReportPath: comparisonReportURL.path
        )
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

@MainActor
private enum FinalDebtFullAppSimJanApr2028Simulation {
    static func runAndWriteArtifacts() async throws -> FinalDebtFullAppSimJanApr2028SimulationResult {
        let fixtureRepository = PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.finalDebtFullAppSimJanApr2028FixtureValue
        ])
        let fixtureSeeded = fixtureRepository is InMemoryPlannerRepository
        _ = try await fixtureRepository.loadSnapshot()

        let outputDirectory = repoRoot()
            .appendingPathComponent("outputs", isDirectory: true)
            .appendingPathComponent("final_debt_full_app_simulation_jan_apr_2028", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let scriptURL = repoRoot()
            .appendingPathComponent("tools", isDirectory: true)
            .appendingPathComponent("final_debt_full_app_sim_jan_apr_2028_export.mjs")
        let inputWorkbookPath = "/Users/jackd/Downloads/final_debt_full_app_sim_package_jan_apr_2028/final_debt_full_app_sim_input_jan_apr_2028.xlsx"
        let expectedWorkbookPath = "/Users/jackd/Downloads/final_debt_full_app_sim_package_jan_apr_2028/final_debt_full_app_sim_expected_jan_apr_2028.xlsx"
        let actualJsonURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_actual_jan_apr_2028.json")
        let actualWorkbookURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_actual_jan_apr_2028.xlsx")
        let comparisonReportURL = outputDirectory.appendingPathComponent("final_debt_full_app_sim_mismatch_report_jan_apr_2028.md")

        #if os(macOS)
        try runExporter(
            scriptURL: scriptURL,
            inputWorkbookPath: inputWorkbookPath,
            expectedWorkbookPath: expectedWorkbookPath,
            actualJsonPath: actualJsonURL.path,
            actualWorkbookPath: actualWorkbookURL.path,
            comparisonReportPath: comparisonReportURL.path
        )
        #else
        guard FileManager.default.fileExists(atPath: actualJsonURL.path) else {
            throw NSError(
                domain: "FinalDebtFullAppSimJanApr2028Simulation",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing generated simulation artifact at \(actualJsonURL.path). Run tools/final_debt_full_app_sim_jan_apr_2028_export.mjs before the iOS simulator test."]
            )
        }
        #endif

        let payload = try JSONSerialization.jsonObject(with: Data(contentsOf: actualJsonURL)) as? [String: Any]
        let rowCounts = intDictionary(payload?["rowCounts"] as? [String: Any] ?? [:])
        let comparison = payload?["comparison"] as? [String: Any]
        let totalMismatches = intValue(comparison?["totalMismatches"]) ?? -1

        return FinalDebtFullAppSimJanApr2028SimulationResult(
            fixtureSeeded: fixtureSeeded,
            dailyRowCount: rowCounts["Daily Actual"] ?? 0,
            rowCounts: rowCounts,
            totalMismatches: totalMismatches,
            actualJsonPath: actualJsonURL.path,
            expectedWorkbookPath: expectedWorkbookPath,
            actualWorkbookPath: actualWorkbookURL.path,
            comparisonReportPath: comparisonReportURL.path
        )
    }

    #if os(macOS)
    private static func runExporter(
        scriptURL: URL,
        inputWorkbookPath: String,
        expectedWorkbookPath: String,
        actualJsonPath: String,
        actualWorkbookPath: String,
        comparisonReportPath: String
    ) throws {
        let bundledNodePath = "/Users/jackd/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
        let process = Process()
        if FileManager.default.fileExists(atPath: bundledNodePath) {
            process.executableURL = URL(fileURLWithPath: bundledNodePath)
            process.arguments = [scriptURL.path, inputWorkbookPath, expectedWorkbookPath, actualJsonPath, actualWorkbookPath, comparisonReportPath]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["node", scriptURL.path, inputWorkbookPath, expectedWorkbookPath, actualJsonPath, actualWorkbookPath, comparisonReportPath]
        }
        process.currentDirectoryURL = repoRoot()

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "FinalDebtFullAppSimJanApr2028Simulation",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Exporter failed with status \(process.terminationStatus): \(output)"]
            )
        }
    }
    #endif

    private static func intDictionary(_ dictionary: [String: Any]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: dictionary.compactMap { key, value in
            guard let int = intValue(value) else { return nil }
            return (key, int)
        })
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double) }
        return nil
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

@MainActor
private struct FullAppSimulationRunner {
    static let startDate = "2027-07-01"
    static let endDate = "2027-09-30"

    private let store: PlannerStore
    private var dailyRows: [[FullAppCellValue]] = []
    private var checklistRows: [[FullAppCellValue]] = []
    private var transactionRows: [[FullAppCellValue]] = []
    private var paydayRows: [[FullAppCellValue]] = []
    private var dailySummaries: [DailySummary] = []

    init(store: PlannerStore) {
        self.store = store
    }

    mutating func run() -> [FullAppSheetPayload] {
        transactionRows = openingBalanceTransactionRows(snapshot: store.snapshot)

        var currentDate = Self.startDate
        while currentDate <= Self.endDate {
            store.setManualTodayForSimulation(currentDate)
            simulateDay(currentDate)
            currentDate = FinanceEngine.addIsoDays(date: currentDate, days: 1)
        }

        return [
            FullAppSheetPayload(name: "Daily Actual", headers: Self.dailyHeaders, rows: dailyRows),
            FullAppSheetPayload(name: "Dates That Matter Actual", headers: Self.datesThatMatterHeaders, rows: datesThatMatterRows()),
            FullAppSheetPayload(name: "Payday Snapshots Actual", headers: Self.paydayHeaders, rows: paydayRows),
            FullAppSheetPayload(name: "Checklist Actual", headers: Self.checklistHeaders, rows: checklistRows),
            FullAppSheetPayload(name: "Transactions Actual", headers: Self.transactionHeaders, rows: transactionRows.sorted(by: sortRowsByFirstDateThenText)),
            FullAppSheetPayload(name: "Statements Actual", headers: Self.statementHeaders, rows: statementRows()),
            FullAppSheetPayload(name: "DD Payments Actual", headers: Self.ddPaymentHeaders, rows: ddPaymentRows()),
            FullAppSheetPayload(name: "Warning Periods Actual", headers: Self.warningPeriodHeaders, rows: warningPeriodRows()),
        ]
    }

    private mutating func simulateDay(_ date: String) {
        var events: [String] = []
        var checklistAddedPence = 0
        var paydaySnapshotDraft: PaydaySnapshotDraft?

        if let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date),
           period.payday == date {
            let beforeChecklistCount = checklistRows.count
            let beforeChecklistPence = checklistAddedPence

            let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
            for item in recurringItems where !item.isCompleted {
                checklistRows.append(checklistRow(
                    dateAdded: date,
                    item: "\(item.paymentName) - \(monthName(for: period.startDate)) funding",
                    amountPence: item.amountPence,
                    potId: potCode(item.potId),
                    cardId: item.cardId.map(cardCode),
                    reason: "payday monthly funding",
                    datesCovered: shortSlashDate(item.dueDate),
                    autoTicked: true
                ))
                checklistAddedPence += item.amountPence
                _ = store.setRecurringBillFundingCompleted(
                    paymentId: item.paymentId,
                    dueDate: item.dueDate,
                    payPeriodId: item.payPeriodId,
                    completed: true
                )
            }

            let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
            for item in openingItems where !item.isCompleted {
                checklistRows.append(checklistRow(
                    dateAdded: date,
                    item: "\(cardCode(item.cardId)) opening balance funding",
                    amountPence: item.amountPence,
                    potId: potCode(item.potId),
                    cardId: cardCode(item.cardId),
                    reason: "opening balance funding",
                    datesCovered: shortSlashDate(item.directDebitDate),
                    autoTicked: true
                ))
                checklistAddedPence += item.amountPence
                _ = store.setCardOpeningBalanceFundingCompleted(
                    cardId: item.cardId,
                    directDebitDate: item.directDebitDate,
                    payPeriodId: item.payPeriodId,
                    completed: true
                )
            }

            let addedCount = checklistRows.count - beforeChecklistCount
            let addedPence = checklistAddedPence - beforeChecklistPence
            let incomeAfterTick = incomeRemainingPence(on: date)
            events.append("Payday +\(formatPounds(period.incomePence)); checklist funded \(formatPounds(addedPence)) across \(addedCount) items")
            paydaySnapshotDraft = PaydaySnapshotDraft(
                date: date,
                month: monthYear(for: date),
                incomeBeforeTickPence: period.incomePence,
                checklistCount: addedCount,
                checklistAmountPence: addedPence,
                incomeAfterTickBeforeDueProcessingPence: incomeAfterTick,
                openingFundingIncluded: openingItems.contains { !$0.isCompleted }
            )
        }

        let scheduledTransactionIdsBefore = Set(store.snapshot.transactions.map(\.id))
        _ = store.applyDueScheduledPaymentsForSimulation(asOf: date)
        let scheduledTransactions = store.snapshot.transactions
            .filter { !scheduledTransactionIdsBefore.contains($0.id) }
            .sorted(by: sortTransactions)
        for transaction in scheduledTransactions {
            transactionRows.append(transactionRow(for: transaction, type: scheduledTransactionType(transaction)))
            events.append(eventDescription(for: transaction))
        }

        for action in DefaultData.fullAppLogicTortureJulSep2027ManualActions where action.date == date {
            guard let cardId = action.cardId else { continue }
            store.recordTransaction(
                potId: nil,
                creditCardId: cardId,
                paymentMethod: .creditCard,
                amountPence: action.amountPence,
                type: .spending,
                date: action.date,
                note: action.name
            )
            guard let transaction = store.snapshot.transactions.first(where: {
                $0.date == action.date &&
                $0.creditCardId == cardId &&
                $0.amountPence == action.amountPence &&
                $0.note == action.name
            }),
                  let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: action.date),
                  let checklistItem = PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
                    .first(where: { $0.transactionId == transaction.id })
            else { continue }

            checklistRows.append(checklistRow(
                dateAdded: date,
                item: "\(action.name) - manual card spend funding",
                amountPence: checklistItem.amountPence,
                potId: potCode(checklistItem.potId),
                cardId: cardCode(checklistItem.cardId),
                reason: "manual action funding",
                datesCovered: shortSlashDate(action.date),
                autoTicked: action.autoTickChecklist
            ))
            checklistAddedPence += checklistItem.amountPence
            if action.autoTickChecklist {
                _ = store.setCardSpendFundingCompleted(
                    transactionId: transaction.id,
                    payPeriodId: period.id,
                    completed: true
                )
            }
            transactionRows.append(transactionRow(for: transaction, type: "Manual card spend", fundingPotId: action.potId))
            events.append(manualEventDescription(action: action, transaction: transaction))
        }

        for summary in PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: date)
            where summary.statementDate == date {
            events.append("\(cardCode(summary.cardId)) statement created \(formatPounds(summary.statementAmountPence)); due \(shortSlashDate(summary.directDebitDate))")
        }

        let repaymentIdsBefore = Set(store.snapshot.creditCardRepayments.map(\.id))
        _ = store.applyDueCreditCardPaymentsForSimulation(asOf: date)
        let newRepayments = store.snapshot.creditCardRepayments
            .filter { !repaymentIdsBefore.contains($0.id) }
            .sorted(by: sortRepayments)
        for repayment in newRepayments {
            events.append(ddPaymentEventDescription(repayment))
        }

        let warning = warningText(on: date)
        let dailyRow = makeDailyRow(date: date, events: events, checklistAddedPence: checklistAddedPence, warning: warning)
        dailyRows.append(dailyRow)
        dailySummaries.append(DailySummary(date: date, row: dailyRow, events: events.joined(separator: " | "), warning: warning))

        if let paydaySnapshotDraft {
            paydayRows.append(paydayRow(from: paydaySnapshotDraft, endOfDayWarning: warning, date: date))
        }
    }

    private func makeDailyRow(date: String, events: [String], checklistAddedPence: Int, warning: String) -> [FullAppCellValue] {
        let snapshot = store.snapshot
        let payPeriod = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)
        let incomeRemaining = incomeRemainingPence(on: date)
        let potProgressById = Dictionary(uniqueKeysWithValues: Self.potOrder.compactMap { potId -> (String, PotProgress)? in
            guard let pot = snapshot.pots.first(where: { $0.id == potId }) else { return nil }
            return (potId, PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: date))
        })
        let potById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        let cardById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        let reserveByCard = Dictionary(uniqueKeysWithValues: Self.cardOrder.map { ($0, cardReservePence(cardId: $0, asOfDate: date)) })
        let availabilityByCard = Dictionary(uniqueKeysWithValues: Self.cardOrder.compactMap { cardId -> (String, CreditCardAvailabilitySummary)? in
            guard let card = cardById[cardId] else { return nil }
            return (cardId, PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: snapshot, payPeriod: payPeriod, asOfDate: date))
        })

        var row: [FullAppCellValue] = [
            .text(date),
            .text(weekdayAbbreviation(date)),
            events.isEmpty ? .blank : .text(events.joined(separator: " | ")),
            money(checklistAddedPence),
            money(incomeRemaining),
            money(Self.potOrder.reduce(0) { $0 + (potProgressById[$1]?.targetPence ?? 0) }),
            money(Self.potOrder.reduce(0) { $0 + max(0, potById[$1]?.balancePence ?? 0) }),
            money(Self.cardOrder.reduce(0) { $0 + (reserveByCard[$1] ?? 0) }),
            money(Self.cardOrder.reduce(0) { total, cardId in
                guard let card = cardById[cardId] else { return total }
                return total + PlannerDerivedData.cardBalance(card: card, snapshot: snapshot)
            }),
        ]

        for potId in Self.potOrder {
            row.append(money(potProgressById[potId]?.targetPence ?? 0))
            row.append(money(potById[potId]?.balancePence ?? 0))
        }

        for cardId in Self.cardOrder {
            row.append(money(reserveByCard[cardId] ?? 0))
        }

        for cardId in Self.cardOrder {
            let balance = cardById[cardId].map { PlannerDerivedData.cardBalance(card: $0, snapshot: snapshot) } ?? 0
            let availability = availabilityByCard[cardId]
            let forecastRemaining = max(0, (availability?.forecastOwedPence ?? balance) - (availability?.actualOwedPence ?? balance))
            row.append(money(balance))
            row.append(money(forecastRemaining))
            row.append(money(availability?.actualAvailablePence ?? 0))
            row.append(money(availability?.forecastAvailablePence ?? 0))
        }

        row.append(warning.isEmpty ? .blank : .text(warning))
        return row
    }

    private func datesThatMatterRows() -> [[FullAppCellValue]] {
        var rows: [[FullAppCellValue]] = []
        var previousWarning = ""

        for summary in dailySummaries {
            let isPayday = summary.date.hasSuffix("-01")
            let warningChanged = summary.warning != previousWarning
            if !summary.events.isEmpty || warningChanged || isPayday {
                let reasonParts = [
                    summary.events.isEmpty ? nil : "event",
                    warningChanged ? "warning change" : nil,
                    isPayday ? "payday" : nil,
                ].compactMap { $0 }
                let row = summary.row
                rows.append([
                    row[0],
                    row[1],
                    .text(reasonParts.joined(separator: ", ")),
                    row[2],
                    row[4],
                    row[6],
                    row[7],
                    row[8],
                    row[28],
                    row[31],
                    row[32],
                    row[35],
                    row[36],
                    row[39],
                    row[40],
                    row[43],
                    row[44],
                    row[47],
                    row[48],
                ])
            }
            previousWarning = summary.warning
        }

        return rows
    }

    private func statementRows() -> [[FullAppCellValue]] {
        let snapshot = store.snapshot
        var rows: [[FullAppCellValue]] = []

        for card in snapshot.creditCards.sorted(by: { cardCode($0.id) < cardCode($1.id) }) {
            let openingStatementPence = max(0, card.openingStatementBalancePence ?? 0)
            if openingStatementPence > 0,
               let statementDate = card.statementDate,
               let directDebitDate = openingBalanceDirectDebitDate(for: card) {
                rows.append([
                    .text(cardCode(card.id)),
                    .text(statementDate),
                    .text(directDebitDate),
                    money(openingStatementPence),
                    .text("Created before run"),
                    .text("opening statement balance"),
                ])
            }
        }

        let summaries = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: "2027-10-31")
        for summary in summaries.sorted(by: sortStatementSummaries) {
            let isAlreadyIncludedOpeningStatement = snapshot.creditCards.contains {
                $0.id == summary.cardId &&
                $0.statementDate == summary.statementDate &&
                max(0, $0.openingStatementBalancePence ?? 0) > 0
            }
            if isAlreadyIncludedOpeningStatement { continue }

            rows.append([
                .text(cardCode(summary.cardId)),
                .text(summary.statementDate),
                .text(summary.directDebitDate),
                money(summary.statementAmountPence),
                .text(statementStatusLabel(statementDate: summary.statementDate)),
                .text(statementSources(summary.transactions)),
            ])
        }

        return rows
    }

    private func ddPaymentRows() -> [[FullAppCellValue]] {
        store.snapshot.creditCardRepayments
            .filter { $0.date >= Self.startDate && $0.date <= Self.endDate && $0.amountPence > 0 }
            .sorted(by: sortRepayments)
            .map { repayment in
                [
                    .text(repayment.date),
                    .text(cardCode(repayment.creditCardId)),
                    repayment.statementDate.map { FullAppCellValue.text($0) } ?? .blank,
                    money(repayment.amountPence),
                    .text(ddSourceBreakdown(repayment)),
                    .text(ddLabel(repayment)),
                ]
            }
    }

    private func warningPeriodRows() -> [[FullAppCellValue]] {
        var periods: [[FullAppCellValue]] = []
        var activeStart: String?
        var activeWarning = ""
        var previousDate: String?

        for summary in dailySummaries {
            if summary.warning != activeWarning {
                if let activeStart, !activeWarning.isEmpty, let previousDate {
                    periods.append(warningPeriodRow(startDate: activeStart, endDate: previousDate, warning: activeWarning))
                }
                activeStart = summary.warning.isEmpty ? nil : summary.date
                activeWarning = summary.warning
            }
            previousDate = summary.date
        }

        if let activeStart, !activeWarning.isEmpty, let previousDate {
            periods.append(warningPeriodRow(startDate: activeStart, endDate: previousDate, warning: activeWarning))
        }

        return periods
    }

    private func paydayRow(from draft: PaydaySnapshotDraft, endOfDayWarning: String, date: String) -> [FullAppCellValue] {
        [
            .text(draft.date),
            .text(draft.month),
            money(draft.incomeBeforeTickPence),
            .number(Double(draft.checklistCount)),
            money(draft.checklistAmountPence),
            money(draft.incomeAfterTickBeforeDueProcessingPence),
            .text(draft.openingFundingIncluded ? "Yes" : "No"),
            money(incomeRemainingPence(on: date)),
            money(Self.potOrder.reduce(0) { total, potId in
                total + max(0, store.snapshot.pots.first(where: { $0.id == potId })?.balancePence ?? 0)
            }),
            money(Self.cardOrder.reduce(0) { total, cardId in
                guard let card = store.snapshot.creditCards.first(where: { $0.id == cardId }) else { return total }
                return total + PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot)
            }),
            endOfDayWarning.isEmpty ? .blank : .text(endOfDayWarning),
        ]
    }

    private func openingBalanceTransactionRows(snapshot: PlannerSnapshot) -> [[FullAppCellValue]] {
        snapshot.creditCards
            .sorted { cardCode($0.id) < cardCode($1.id) }
            .compactMap { card -> [FullAppCellValue]? in
                let openingBalancePence = max(0, card.openingBalancePence ?? 0)
                guard openingBalancePence > 0,
                      let statementDate = card.statementDate,
                      let dueDate = openingBalanceDirectDebitDate(for: card)
                else { return nil }

                let potId = snapshot.pots.first { $0.linkedCreditCardId == card.id }?.id
                let note = (card.openingStatementBalancePence ?? 0) > 0
                    ? "Opening statement balance due during simulation."
                    : "Opening balance exists at app start but is not statemented yet."

                return [
                    .text(Self.startDate),
                    .text("Opening balance"),
                    .text("\(cardCode(card.id)) opening balance"),
                    money(openingBalancePence),
                    potId.map { FullAppCellValue.text(potCode($0)) } ?? .blank,
                    .text(cardCode(card.id)),
                    .text(statementDate),
                    .text(dueDate),
                    .text("Opening balance funding"),
                    .text(note),
                ]
            }
    }

    private func transactionRow(for transaction: Transaction, type: String, fundingPotId: String? = nil) -> [FullAppCellValue] {
        let card = transaction.creditCardId.flatMap { cardId in
            store.snapshot.creditCards.first { $0.id == cardId }
        }
        let statementDate: String?
        let dueDate: String?
        if let card {
            statementDate = statementDateForCard(card, chargeDate: transaction.date)
            dueDate = directDebitDateForCard(card, chargeDate: transaction.date)
        } else {
            statementDate = nil
            dueDate = nil
        }
        let potId = fundingPotId ?? transaction.potId

        return [
            .text(transaction.date),
            .text(type),
            .text(transaction.note),
            money(transaction.amountPence),
            potId.map { FullAppCellValue.text(potCode($0)) } ?? .blank,
            transaction.creditCardId.map { FullAppCellValue.text(cardCode($0)) } ?? .blank,
            statementDate.map { FullAppCellValue.text($0) } ?? .blank,
            dueDate.map { FullAppCellValue.text($0) } ?? .blank,
            .text(transaction.paymentMethod == .creditCard ? "Linked pot funding" : "Direct pot payment"),
            .text(transaction.recurringPaymentId == nil ? "Manual or one-off app transaction." : "Scheduled bill occurrence."),
        ]
    }

    private func checklistRow(
        dateAdded: String,
        item: String,
        amountPence: Int,
        potId: String,
        cardId: String?,
        reason: String,
        datesCovered: String,
        autoTicked: Bool
    ) -> [FullAppCellValue] {
        [
            .text(dateAdded),
            .text(item),
            money(amountPence),
            .text(potId),
            cardId.map { FullAppCellValue.text($0) } ?? .blank,
            .text(reason),
            .text(datesCovered),
            .text(autoTicked ? "Yes" : "No"),
        ]
    }

    private func warningPeriodRow(startDate: String, endDate: String, warning: String) -> [FullAppCellValue] {
        [
            .text(startDate),
            .text(endDate),
            .number(Double(FinanceEngine.getDaysInclusive(startDate: startDate, endDate: endDate))),
            .text(warning),
        ]
    }

    private func incomeRemainingPence(on date: String) -> Int {
        let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date)
        return PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: date).moneyLeftPence
    }

    private func cardReservePence(cardId: String, asOfDate: String) -> Int {
        let snapshot = store.snapshot
        let recurringReserve = snapshot.transactions.reduce(0) { total, transaction in
            guard transaction.deletedAt == nil,
                  transaction.paymentMethod == .creditCard,
                  transaction.creditCardId == cardId,
                  transaction.recurringPaymentId != nil,
                  transaction.potId != nil,
                  transaction.date <= asOfDate,
                  !isTransactionRepaid(transaction, asOfDate: asOfDate)
            else { return total }
            return total + max(0, transaction.amountPence)
        }
        let allocationReserve = snapshot.potAllocations.reduce(0) { total, allocation in
            guard allocation.deletedAt == nil,
                  allocation.creditCardId == cardId,
                  allocation.source == .cardSpendFunding,
                  !isAllocationRepaid(allocation, asOfDate: asOfDate)
            else { return total }
            return total + max(0, allocation.amountPence)
        }
        return recurringReserve + allocationReserve
    }

    private func isTransactionRepaid(_ transaction: Transaction, asOfDate: String) -> Bool {
        guard let cardId = transaction.creditCardId,
              let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
              let statementDate = statementDateForCard(card, chargeDate: transaction.date)
        else { return false }

        return store.snapshot.creditCardRepayments.contains {
            $0.deletedAt == nil &&
            $0.creditCardId == cardId &&
            $0.statementDate == statementDate &&
            $0.date <= asOfDate &&
            $0.amountPence > 0
        }
    }

    private func isAllocationRepaid(_ allocation: PotAllocation, asOfDate: String) -> Bool {
        guard let cardId = allocation.creditCardId else { return false }
        return store.snapshot.creditCardRepayments.contains {
            $0.deletedAt == nil &&
            $0.creditCardId == cardId &&
            ($0.directDebitDate ?? $0.date) == allocation.creditCardDirectDebitDate &&
            $0.date <= asOfDate &&
            $0.amountPence > 0
        }
    }

    private func warningText(on date: String) -> String {
        let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date)
        let warnings = Self.cardOrder.compactMap { cardId -> String? in
            guard let card = store.snapshot.creditCards.first(where: { $0.id == cardId }) else { return nil }
            let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: period, asOfDate: date)
            if availability.actualAvailablePence < 0 {
                return "\(cardCode(cardId)) over limit by \(formatPounds(abs(availability.actualAvailablePence)))"
            }
            if availability.forecastAvailablePence < 0 {
                return "\(cardCode(cardId)) unsafe after forecast by \(formatPounds(abs(availability.forecastAvailablePence)))"
            }
            return nil
        }
        return warnings.joined(separator: "; ")
    }

    private func eventDescription(for transaction: Transaction) -> String {
        if transaction.paymentMethod == .creditCard,
           let cardId = transaction.creditCardId,
           let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
           let statementDate = statementDateForCard(card, chargeDate: transaction.date),
           let dueDate = directDebitDateForCard(card, chargeDate: transaction.date) {
            let pot = transaction.potId.map(potCode) ?? "unfunded pot"
            return "\(transaction.note) \(formatPounds(transaction.amountPence)) from \(pot) to \(cardCode(cardId)); statement \(shortSlashDate(statementDate)) due \(shortSlashDate(dueDate))"
        }

        let pot = transaction.potId.map(potCode) ?? "Pot"
        return "\(transaction.note) \(formatPounds(transaction.amountPence)) paid directly from \(pot); no card"
    }

    private func manualEventDescription(action: DefaultData.FullAppLogicTortureManualAction, transaction: Transaction) -> String {
        guard let cardId = transaction.creditCardId,
              let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
              let statementDate = statementDateForCard(card, chargeDate: transaction.date),
              let dueDate = directDebitDateForCard(card, chargeDate: transaction.date)
        else {
            return "Manual \(action.name) \(formatPounds(action.amountPence))"
        }

        return "Manual \(action.name) \(formatPounds(action.amountPence)) on \(cardCode(cardId)) via \(potCode(action.potId)); statement \(shortSlashDate(statementDate)) due \(shortSlashDate(dueDate))"
    }

    private func ddPaymentEventDescription(_ repayment: CreditCardRepayment) -> String {
        "\(cardCode(repayment.creditCardId)) DD paid \(formatPounds(repayment.amountPence)) (\(ddSourceBreakdown(repayment)))"
    }

    private func ddSourceBreakdown(_ repayment: CreditCardRepayment) -> String {
        var parts: [String] = []
        if let potContributionPence = repayment.potContributionPence, potContributionPence > 0 {
            if let potId = repayment.potId {
                parts.append("\(formatPounds(potContributionPence)) from \(potCode(potId))")
            } else {
                parts.append("\(formatPounds(potContributionPence)) from linked card pots")
            }
        }
        for reserveContributionPence in cardReserveContributionParts(for: repayment) {
            parts.append("\(formatPounds(reserveContributionPence)) from \(cardCode(repayment.creditCardId)) reserve")
        }
        if let paycheckContributionPence = repayment.paycheckContributionPence, paycheckContributionPence > 0 {
            parts.append("\(formatPounds(paycheckContributionPence)) from paycheck")
        }
        if parts.isEmpty {
            parts.append("\(formatPounds(repayment.amountPence)) automatic")
        }
        return parts.joined(separator: "; ")
    }

    private func cardReserveContributionParts(for repayment: CreditCardRepayment) -> [Int] {
        guard let statementDate = repayment.statementDate,
              let card = store.snapshot.creditCards.first(where: { $0.id == repayment.creditCardId })
        else { return [] }

        let recurringOrderById = Dictionary(uniqueKeysWithValues: store.snapshot.recurringPayments.enumerated().map { index, payment in
            (payment.id, index)
        })

        let scheduledReserveEntries = store.snapshot.transactions.compactMap { transaction -> ReserveContributionEntry? in
            guard transaction.deletedAt == nil,
                  transaction.paymentMethod == .creditCard,
                  transaction.creditCardId == repayment.creditCardId,
                  transaction.recurringPaymentId != nil,
                  transaction.potId != nil,
                  transaction.date <= repayment.date,
                  statementDateForCard(card, chargeDate: transaction.date) == statementDate
            else { return nil }

            let amountPence = max(0, transaction.amountPence)
            guard amountPence > 0 else { return nil }
            let recurringOrder = transaction.recurringPaymentId.flatMap { recurringOrderById[$0] } ?? Int.max
            return ReserveContributionEntry(
                date: transaction.date,
                order: recurringOrder,
                transactionId: transaction.id,
                amountPence: amountPence
            )
        }

        let manualReserveEntries = store.snapshot.potAllocations.compactMap { allocation -> ReserveContributionEntry? in
            guard allocation.deletedAt == nil,
                  allocation.source == .cardSpendFunding,
                  allocation.creditCardId == repayment.creditCardId,
                  let transactionId = allocation.transactionId,
                  let transaction = store.snapshot.transactions.first(where: {
                      $0.id == transactionId &&
                      $0.deletedAt == nil &&
                      $0.paymentMethod == .creditCard &&
                      $0.creditCardId == repayment.creditCardId &&
                      $0.date <= repayment.date
                  }),
                  statementDateForCard(card, chargeDate: allocation.transactionDate ?? transaction.date) == statementDate
            else { return nil }

            let amountPence = min(max(0, allocation.amountPence), max(0, transaction.amountPence))
            guard amountPence > 0 else { return nil }
            return ReserveContributionEntry(
                date: allocation.transactionDate ?? transaction.date,
                order: Int.max,
                transactionId: transaction.id,
                amountPence: amountPence
            )
        }

        let reserveCapacityPence = max(0, repayment.amountPence - max(0, repayment.potContributionPence ?? 0) - max(0, repayment.paycheckContributionPence ?? 0))
        var remainingReservePence = reserveCapacityPence
        var parts: [Int] = []
        for entry in (scheduledReserveEntries + manualReserveEntries).sorted(by: <) where remainingReservePence > 0 {
            let contributionPence = min(entry.amountPence, remainingReservePence)
            if contributionPence > 0 {
                parts.append(contributionPence)
                remainingReservePence -= contributionPence
            }
        }
        return parts
    }

    private func ddLabel(_ repayment: CreditCardRepayment) -> String {
        if let statementDate = repayment.statementDate {
            return "statement from \(slashDateWithYear(statementDate))"
        }
        return repayment.note
    }

    private func statementSources(_ transactions: [CreditCardStatementTransaction]) -> String {
        guard !transactions.isEmpty else { return "app statement summary" }
        return transactions.map { "\($0.name) \(formatPounds($0.amountPence))" }.joined(separator: "; ")
    }

    private func scheduledTransactionType(_ transaction: Transaction) -> String {
        transaction.paymentMethod == .creditCard ? "Scheduled card bill" : "Scheduled pot bill"
    }

    private func statementDateForCard(_ card: CreditCard, chargeDate: String) -> String? {
        guard var statementDate = card.statementDate,
              FinanceEngine.isIsoDate(statementDate)
        else { return nil }

        for _ in 0..<240 {
            if statementDate >= chargeDate {
                return statementDate
            }
            statementDate = PlannerDerivedData.addIsoMonthsClamped(date: statementDate, months: 1)
        }

        return nil
    }

    private func directDebitDateForCard(_ card: CreditCard, chargeDate: String) -> String? {
        guard let statementDate = statementDateForCard(card, chargeDate: chargeDate),
              let dueDay = card.dueDay
        else { return nil }

        return PlannerDerivedData.creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
    }

    private func openingBalanceDirectDebitDate(for card: CreditCard) -> String? {
        PlannerDerivedData.creditCardOpeningBalanceDirectDebitDate(card: card, today: Self.startDate)
    }

    private func statementStatusLabel(statementDate: String) -> String {
        if statementDate < Self.startDate {
            return "Created before run"
        }
        if statementDate > Self.endDate {
            return "Expected after run"
        }
        return "Created inside run"
    }

    private func sortRowsByFirstDateThenText(_ lhs: [FullAppCellValue], _ rhs: [FullAppCellValue]) -> Bool {
        let lhsDate = lhs.first?.sortString ?? ""
        let rhsDate = rhs.first?.sortString ?? ""
        if lhsDate == rhsDate {
            return lhs.map(\.sortString).joined(separator: "|") < rhs.map(\.sortString).joined(separator: "|")
        }
        return lhsDate < rhsDate
    }

    private func sortTransactions(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if lhs.date == rhs.date {
            return lhs.note < rhs.note
        }
        return lhs.date < rhs.date
    }

    private func sortRepayments(_ lhs: CreditCardRepayment, _ rhs: CreditCardRepayment) -> Bool {
        if lhs.date == rhs.date {
            return cardCode(lhs.creditCardId) < cardCode(rhs.creditCardId)
        }
        return lhs.date < rhs.date
    }

    private func sortStatementSummaries(_ lhs: CreditCardStatementSummary, _ rhs: CreditCardStatementSummary) -> Bool {
        if lhs.statementDate == rhs.statementDate {
            return cardCode(lhs.cardId) < cardCode(rhs.cardId)
        }
        return lhs.statementDate < rhs.statementDate
    }

    private func cardCode(_ cardId: String) -> String {
        Self.cardCodes[cardId] ?? cardId
    }

    private func potCode(_ potId: String) -> String {
        Self.potCodes[potId] ?? potId
    }

    private func money(_ pence: Int) -> FullAppCellValue {
        .number(Double(pence) / 100.0)
    }

    private func formatPounds(_ pence: Int) -> String {
        let absolutePence = abs(pence)
        let sign = pence < 0 ? "-" : ""
        if absolutePence % 100 == 0 {
            return "\(sign)£\(absolutePence / 100)"
        }
        return String(format: "\(sign)£%.2f", Double(absolutePence) / 100.0)
    }

    private func weekdayAbbreviation(_ isoDate: String) -> String {
        Self.weekdayFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func monthName(for isoDate: String) -> String {
        Self.monthFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func monthYear(for isoDate: String) -> String {
        Self.monthYearFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func shortSlashDate(_ isoDate: String) -> String {
        Self.shortSlashFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func slashDateWithYear(_ isoDate: String) -> String {
        Self.slashWithYearFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private struct DailySummary {
        var date: String
        var row: [FullAppCellValue]
        var events: String
        var warning: String
    }

    private struct PaydaySnapshotDraft {
        var date: String
        var month: String
        var incomeBeforeTickPence: Int
        var checklistCount: Int
        var checklistAmountPence: Int
        var incomeAfterTickBeforeDueProcessingPence: Int
        var openingFundingIncluded: Bool
    }

    private struct ReserveContributionEntry: Comparable {
        var date: String
        var order: Int
        var transactionId: String
        var amountPence: Int

        static func < (lhs: ReserveContributionEntry, rhs: ReserveContributionEntry) -> Bool {
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return lhs.transactionId < rhs.transactionId
        }
    }

    private static let potOrder = ["pot-pot1", "pot-pot2", "pot-pot3", "pot-pot4", "pot-pot5", "pot-pot6", "pot-pot7"]
    private static let cardOrder = ["card-cc1", "card-cc2", "card-cc3", "card-cc4", "card-cc5"]
    private static let potCodes = [
        "pot-pot1": "Pot1",
        "pot-pot2": "Pot2",
        "pot-pot3": "Pot3",
        "pot-pot4": "Pot4",
        "pot-pot5": "Pot5",
        "pot-pot6": "Pot6",
        "pot-pot7": "Pot7",
    ]
    private static let cardCodes = [
        "card-cc1": "CC1",
        "card-cc2": "CC2",
        "card-cc3": "CC3",
        "card-cc4": "CC4",
        "card-cc5": "CC5",
    ]

    private static let dailyHeaders = [
        "Date", "Day", "Events", "Checklist Added Today", "Income Remaining", "Total Pot Target",
        "Total Pot Balance", "Total Card Reserve", "Total Card Balance", "Pot1 Target", "Pot1 Balance",
        "Pot2 Target", "Pot2 Balance", "Pot3 Target", "Pot3 Balance", "Pot4 Target", "Pot4 Balance",
        "Pot5 Target", "Pot5 Balance", "Pot6 Target", "Pot6 Balance", "Pot7 Target", "Pot7 Balance",
        "CC1 Reserve", "CC2 Reserve", "CC3 Reserve", "CC4 Reserve", "CC5 Reserve", "CC1 Balance",
        "CC1 Forecast Remaining", "CC1 Actual Available", "CC1 Safe Available", "CC2 Balance",
        "CC2 Forecast Remaining", "CC2 Actual Available", "CC2 Safe Available", "CC3 Balance",
        "CC3 Forecast Remaining", "CC3 Actual Available", "CC3 Safe Available", "CC4 Balance",
        "CC4 Forecast Remaining", "CC4 Actual Available", "CC4 Safe Available", "CC5 Balance",
        "CC5 Forecast Remaining", "CC5 Actual Available", "CC5 Safe Available", "Warning",
    ]
    private static let datesThatMatterHeaders = [
        "Date", "Day", "Reason", "Events", "Income Remaining", "Total Pot Balance", "Total Card Reserve",
        "Total Card Balance", "CC1 Bal", "CC1 Safe", "CC2 Bal", "CC2 Safe", "CC3 Bal", "CC3 Safe",
        "CC4 Bal", "CC4 Safe", "CC5 Bal", "CC5 Safe", "Warning",
    ]
    private static let paydayHeaders = [
        "date", "month", "income_before_tick", "checklist_count", "checklist_amount",
        "income_after_tick_before_due_processing", "opening_funding_included", "income_end_of_day",
        "pot_balance_end_of_day", "card_balance_end_of_day", "warning_end_of_day",
    ]
    private static let checklistHeaders = ["date_added", "item", "amount", "pot_id", "card_id", "reason", "dates_covered", "auto_ticked"]
    private static let transactionHeaders = ["date", "type", "name", "amount", "pot_id", "card_id", "statement_date", "due_date", "funding_source", "note"]
    private static let statementHeaders = ["card_id", "statement_date", "due_date", "amount", "status", "sources"]
    private static let ddPaymentHeaders = ["date", "card_id", "statement_date", "amount_paid", "source_breakdown", "label"]
    private static let warningPeriodHeaders = ["start_date", "end_date", "days", "warning"]

    private static let weekdayFormatter = makeDateFormatter("EEE")
    private static let monthFormatter = makeDateFormatter("LLLL")
    private static let monthYearFormatter = makeDateFormatter("LLLL yyyy")
    private static let shortSlashFormatter = makeDateFormatter("dd/MM")
    private static let slashWithYearFormatter = makeDateFormatter("dd/MM/yyyy")

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

private extension FullAppCellValue {
    var sortString: String {
        switch self {
        case .blank:
            return ""
        case .number(let value):
            return String(format: "%020.4f", value)
        case .text(let value):
            return value
        }
    }
}
