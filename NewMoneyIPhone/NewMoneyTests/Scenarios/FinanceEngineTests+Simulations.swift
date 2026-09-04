import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
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

    @MainActor
    func testFullAppLogicTortureJulSep2027SimulationExportsActualJSON() async throws {
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
        let data = try Data(contentsOf: URL(fileURLWithPath: result.actualJsonPath))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["rowCounts"] as? [String: Int], result.rowCounts)
        XCTAssertEqual(payload["startDate"] as? String, "2027-07-01")
        XCTAssertEqual(payload["endDate"] as? String, "2027-09-30")
    }

    @MainActor
    func testFullAppLogicTortureJulSep2027SimulationMatchesJulyCardAccountingCheckpoints() {
        let sheets = runFullAppLogicTortureJulSep2027SimulationSheets()
        let daily = try! XCTUnwrap(fullAppSheet(named: "Daily Actual", in: sheets))

        let julyFirst = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-01"))
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Income Remaining"), 124500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Pot Target"), 420000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Pot Balance"), 420000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Card Balance"), 193000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "Total Card Reserve"), 38500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC1 Reserve"), 7500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC2 Reserve"), 12500)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC3 Reserve"), 0)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC4 Reserve"), 14000)
        XCTAssertEqual(fullAppPence(julyFirst, in: daily, "CC5 Reserve"), 4500)

        let julySecond = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-02"))
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Income Remaining"), 118100)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Pot1 Target"), 26000)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Pot1 Balance"), 26000)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "CC1 Balance"), 13900)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "CC1 Reserve"), 13900)
        XCTAssertEqual(fullAppPence(julySecond, in: daily, "Total Card Reserve"), 44900)

        let julyFifth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-05"))
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "Pot1 Target"), 27850)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "Pot1 Balance"), 27850)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "CC1 Balance"), 19850)
        XCTAssertEqual(fullAppPence(julyFifth, in: daily, "CC1 Reserve"), 19850)

        let julyFifteenth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-15"))
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "Pot2 Target"), 41700)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "Pot2 Balance"), 41700)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "CC2 Balance"), 37000)
        XCTAssertEqual(fullAppPence(julyFifteenth, in: daily, "CC2 Reserve"), 37000)

        let julyTwentySeventh = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-27"))
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "Pot4 Target"), 41000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "Pot4 Balance"), 41000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "CC4 Balance"), 41000)
        XCTAssertEqual(fullAppPence(julyTwentySeventh, in: daily, "CC4 Reserve"), 41000)

        let julyTwentyEighth = try! XCTUnwrap(fullAppRow(in: daily, where: "Date", equals: "2027-07-28"))
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "Pot5 Target"), 42200)
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "Pot5 Balance"), 42200)
        XCTAssertEqual(fullAppPence(julyTwentyEighth, in: daily, "CC5 Balance"), 42200)
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
        XCTAssertEqual(fullAppPence(cc1AugustDd, in: ddPayments, "amount_paid"), 13900)
        XCTAssertEqual(
            fullAppText(cc1AugustDd, in: ddPayments, "source_breakdown"),
            "£139 from Pot1"
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
        XCTAssertEqual(beforeFundingItems.count, 25)
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
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc3"]), snapshot: store.snapshot), 44000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc4"]), snapshot: store.snapshot), 42500)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(cardsById["card-cc5"]), snapshot: store.snapshot), 33000)

        let februaryFifthSummary = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: februaryPeriod,
            asOfDate: "2027-02-05"
        )
        XCTAssertEqual(februaryFifthSummary.projectedCostsPence, 496600)

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
        XCTAssertEqual(potsAfterFunding["pot-pot2"]?.balancePence, 50800)

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
        XCTAssertEqual(carWorkPayments.first?.amountPence, 25500)
        XCTAssertEqual(carWorkPayments.filter { $0.dueIso == "2027-01-25" }.count, 1)

        let annualIrregularPayments = try linkedPayments(for: "Annual & Irregular")
        XCTAssertEqual(annualIrregularPayments.first?.dueIso, "2027-01-28")
        XCTAssertEqual(annualIrregularPayments.first?.amountPence, 18000)
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
        XCTAssertEqual(zableStatement.statementAmountPence, 33000)
        XCTAssertEqual(zableStatement.transactions.first { $0.name == "Zable opening balance" }?.amountPence, 33000)
        XCTAssertNil(zableStatement.transactions.first { $0.name == "Groceries Big Shop A" })
        XCTAssertNil(zableStatement.transactions.first { $0.name == "Fuel Fill A" })

        var january18Settings = store.snapshot.settings
        january18Settings.manualTodayIso = "2027-01-18"
        store.updateSettings(january18Settings)

        let zableRepayment = try XCTUnwrap(store.snapshot.creditCardRepayments.first {
            $0.creditCardId == "card-cc3" &&
            $0.statementDate == "2027-01-10" &&
            ($0.directDebitDate ?? $0.date) == "2027-01-18"
        })
        XCTAssertEqual(zableRepayment.amountPence, 33000)
        XCTAssertEqual(zableRepayment.date, "2027-01-18")

        let zable = try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc3" })
        let zableAvailability = PlannerDerivedData.creditCardAvailabilitySummary(
            card: zable,
            snapshot: store.snapshot,
            payPeriod: januaryPeriod,
            asOfDate: "2027-01-18"
        )
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: zable, snapshot: store.snapshot), 22000)
        XCTAssertEqual(zableAvailability.actualAvailablePence, 63000)
        XCTAssertEqual(zableAvailability.forecastAvailablePence, 41000)

        let cardBalanceTotal = store.snapshot.creditCards.reduce(0) {
            $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot)
        }
        XCTAssertEqual(cardBalanceTotal, 107500)

        let januarySpending = store.snapshot.transactions.filter {
            $0.deletedAt == nil &&
            $0.type == .spending &&
            $0.date >= januaryPeriod.startDate &&
            $0.date <= januaryPeriod.endDate
        }
        XCTAssertEqual(januarySpending.reduce(0) { $0 + $1.amountPence }, 157600)

        let foodFuelPot = try XCTUnwrap(store.snapshot.pots.first { $0.id == "pot-pot3" })
        let foodFuelProgress = PlannerDerivedData.potProgress(pot: foodFuelPot, snapshot: store.snapshot, today: "2027-01-18")
        XCTAssertEqual(foodFuelPot.balancePence, 44000)
        XCTAssertEqual(foodFuelProgress.targetPence, 44000)
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
    func testGroupedComplexJanMar2027StatementDayChargesStartTheFollowingCycle() async throws {
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
        XCTAssertEqual(cc3Statement.statementAmountPence, 33000)
        XCTAssertEqual(cc3Statement.transactions.map(\.amountPence).reduce(0, +), 33000)

        var january15Settings = store.snapshot.settings
        january15Settings.manualTodayIso = "2027-01-15"
        store.updateSettings(january15Settings)

        let cc2Statement = try statementSummary(in: store.snapshot, cardId: "card-cc2", statementDate: "2027-01-15", asOfDate: "2027-01-15")
        XCTAssertEqual(cc2Statement.directDebitDate, "2027-02-12")
        XCTAssertEqual(cc2Statement.statementAmountPence, 21000)

        var january20Settings = store.snapshot.settings
        january20Settings.manualTodayIso = "2027-01-20"
        store.updateSettings(january20Settings)

        let cc4Statement = try statementSummary(in: store.snapshot, cardId: "card-cc4", statementDate: "2027-01-20", asOfDate: "2027-01-20")
        XCTAssertEqual(cc4Statement.directDebitDate, "2027-01-25")
        XCTAssertEqual(cc4Statement.statementAmountPence, 13000)

        var january24Settings = store.snapshot.settings
        january24Settings.manualTodayIso = "2027-01-24"
        store.updateSettings(january24Settings)

        XCTAssertNil(
            PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: "2027-01-24")
                .first { $0.cardId == "card-cc5" && $0.statementDate == "2027-01-24" }
        )
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
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-01").map { $0.1 }, [43000, 7500])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-01").map { $0.0 }, ["2026-09-10", "2026-10-10"])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-01").map { $0.1 }, [16000, 11000])
        XCTAssertEqual(try linkedRows(for: "Annual & Work", today: "2026-09-01").map { $0.0 }, ["2026-09-27"])
        XCTAssertEqual(try linkedRows(for: "Annual & Work", today: "2026-09-01").map { $0.1 }, [9000])
        XCTAssertTrue(try linkedRows(for: "Emergency", today: "2026-09-01").isEmpty)

        var september3Settings = store.snapshot.settings
        september3Settings.manualTodayIso = "2026-09-03"
        store.updateSettings(september3Settings)
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-03").map { $0.0 }, ["2026-10-02"])
        XCTAssertEqual(try linkedRows(for: "Subscriptions", today: "2026-09-03").map { $0.1 }, [7500])

        var september11Settings = store.snapshot.settings
        september11Settings.manualTodayIso = "2026-09-11"
        store.updateSettings(september11Settings)
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-11").map { $0.0 }, ["2026-10-10"])
        XCTAssertEqual(try linkedRows(for: "Car & Insurance", today: "2026-09-11").map { $0.1 }, [11000])
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
        XCTAssertEqual(potProgressByName["Subscriptions"]?.targetPence, 61500)
        XCTAssertEqual(potsByName["Subscriptions"]?.balancePence, 61500)
        XCTAssertEqual(potProgressByName["Car & Insurance"]?.targetPence, 51400)
        XCTAssertEqual(potsByName["Car & Insurance"]?.balancePence, 51400)
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
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 62500)
        XCTAssertEqual(potsById["pot-cc2"]?.balancePence, 10000)
        XCTAssertEqual(potsById["pot-cc3"]?.balancePence, 20000)
        XCTAssertEqual(store.snapshot.pots.reduce(0) { $0 + max(0, $1.balancePence) }, 92500)

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
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name).sorted(), [])
        XCTAssertNil(items.first { $0.name == "ChatGPT" }?.paidDate)
        XCTAssertNil(items.first { $0.name == "Insurance" }?.paidDate)
        XCTAssertEqual(items.filter { $0.status == .activeReserved }.map(\.name).sorted(), ["CC1 opening balance", "ChatGPT", "Insurance", "Skincare", "Spending money"])
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
        XCTAssertEqual(items.first { $0.name == "Skincare" }?.status, .activeReserved)
        XCTAssertNil(items.first { $0.name == "Skincare" }?.paidDate)
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
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name).sorted(), ["CC1 opening balance", "ChatGPT"])
        XCTAssertEqual(items.filter { $0.status == .paidCompleted }.map(\.name), ["CC1 opening balance", "ChatGPT"])
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.paidDate, "2026-07-02")
        XCTAssertEqual(items.first { $0.name == "CC1 opening balance" }?.title, "Add £500.00 to Pot 1")
        XCTAssertEqual(items.filter { $0.status == .activeReserved }.map(\.name).sorted(), ["Insurance", "Skincare", "Spending money"])
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
        XCTAssertEqual(summary.projectedCostsPence, 80000)
        XCTAssertEqual(summary.currentMoneyLeftPence, 100000)
        XCTAssertEqual(summary.projectedMoneyLeftPence, 20000)

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
        XCTAssertEqual(fundedAugustSummary.projectedCostsPence, 80000)
        XCTAssertEqual(fundedAugustSummary.currentMoneyLeftPence, 57500)
        XCTAssertEqual(fundedAugustSummary.projectedMoneyLeftPence, 20000)

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
        XCTAssertEqual(cc1StatementRepayment.potContributionPence, 7500)

        let cardsById = Dictionary(uniqueKeysWithValues: store.snapshot.creditCards.map { ($0.id, $0) })
        let cc1 = try XCTUnwrap(cardsById["card-cc1"])
        let cc2 = try XCTUnwrap(cardsById["card-cc2"])
        let cc3 = try XCTUnwrap(cardsById["card-cc3"])
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc1, snapshot: store.snapshot), 14000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc2, snapshot: store.snapshot), 23300)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: cc3, snapshot: store.snapshot), 20000)
        XCTAssertEqual([cc1, cc2, cc3].reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot) }, 57300)

        let potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 19000)
        XCTAssertEqual(potsById["pot-cc2"]?.balancePence, 23300)
        XCTAssertEqual(potsById["pot-cc3"]?.balancePence, 40000)
        let pot1Progress = PlannerDerivedData.potProgress(pot: try XCTUnwrap(potsById["pot-cc1"]), snapshot: store.snapshot, today: "2026-08-02")
        XCTAssertEqual(pot1Progress.targetPence, 19000)
        XCTAssertEqual(pot1Progress.coveredPence, 19000)
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
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-cc1" }?.balancePence, 19000)
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
}
