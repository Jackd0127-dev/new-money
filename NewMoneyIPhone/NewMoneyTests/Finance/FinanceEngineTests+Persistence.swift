import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    func testPlannerSnapshotDecodesMissingNewCollectionsAndOptionalCycleAmounts() throws {
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
        object.removeValue(forKey: "incomeOccurrenceOverrides")
        var periods = try XCTUnwrap(object["payPeriods"] as? [[String: Any]])
        periods[0].removeValue(forKey: "monthlyAnchorDay")
        object["payPeriods"] = periods
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(PlannerSnapshot.self, from: legacyData)

        XCTAssertTrue(decoded.bankAccounts.isEmpty)
        XCTAssertTrue(decoded.oneOffIncomes.isEmpty)
        XCTAssertTrue(decoded.fundingChecklistExclusions.isEmpty)
        XCTAssertTrue(decoded.incomeOccurrenceOverrides.isEmpty)
        XCTAssertNil(decoded.payPeriods.first?.monthlyAnchorDay)

        let recurringOverride = RecurringPaymentOccurrenceOverride(
            id: "recurring-override",
            paymentId: "bill",
            scheduledDueDate: "2026-07-02",
            state: .normal,
            reversedGeneratedTransactionIds: [],
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z"
        )
        let cardOverride = CreditCardCycleOverride(
            id: "card-override",
            creditCardId: "card",
            scheduledStatementDate: "2026-07-20",
            statementState: .normal,
            directDebitState: .normal,
            reversedAutomaticRepaymentIds: [],
            createdAt: "2026-07-01T00:00:00.000Z",
            updatedAt: "2026-07-01T00:00:00.000Z"
        )
        XCTAssertNil(recurringOverride.amountPenceOverride)
        XCTAssertNil(cardOverride.amountPenceOverride)
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

    func testMigrationReanchorsLegacyPaidOpeningStatementBeforeFundingChecklistCalculation() throws {
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
            openingBalancePence: 80_000,
            openingStatementBalancePence: 80_000,
            statementDate: "2026-09-01",
            dueDay: 5,
            createdAt: "2026-08-10T00:00:00.000Z"
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
            createdAt: "2026-08-10T00:00:00.000Z"
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
        let openingStatementRepayment = CreditCardRepayment(
            id: "capital-two-opening-statement-payment",
            creditCardId: card.id,
            amountPence: 80_000,
            date: "2026-08-05",
            note: "Capital two direct debit",
            statementDate: nil,
            directDebitDate: "2026-08-05",
            source: .manual,
            potId: nil,
            potContributionPence: 0,
            paycheckContributionPence: 80_000,
            createdAt: "2026-08-05T00:00:00.000Z",
            updatedAt: "2026-08-05T00:00:00.000Z",
            deletedAt: nil
        )
        let legacySnapshot = makeSnapshot(
            settings: makeManualSettings(today: "2026-08-30"),
            pots: [pot],
            recurringPayments: [chatGPT],
            payPeriods: [period],
            transactions: [chatGPTCharge, tescoCharge],
            creditCards: [card],
            creditCardRepayments: [openingStatementRepayment]
        )

        let migrated = DefaultData.migratedSnapshot(legacySnapshot).snapshot
        let migratedCard = try XCTUnwrap(migrated.creditCards.first)
        let statementPayments = PlannerDerivedData.creditCardStatementPayments(
            card: migratedCard,
            snapshot: migrated,
            startDate: period.startDate,
            endDate: period.endDate,
            asOfDate: "2026-08-30"
        )
        let group = try XCTUnwrap(
            PlannerDerivedData.fundingChecklistDestinationGroups(
                items: PlannerDerivedData.fundingChecklistPresentationItems(
                    snapshot: migrated,
                    payPeriod: period,
                    asOfDate: "2026-08-30",
                    groupByFundingDueDate: true
                )
            ).first { $0.destinationId == pot.id }
        )

        XCTAssertEqual(migratedCard.statementDate, "2026-08-01")
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: migratedCard, snapshot: migrated), 28_623)
        XCTAssertEqual(migrated.creditCardRepayments.first?.statementDate, "2026-08-01")
        XCTAssertEqual(migrated.creditCardRepayments.first?.directDebitDate, "2026-08-05")
        XCTAssertEqual(statementPayments.map(\.forecastDuePence), [28_623])
        XCTAssertEqual(group.totalAmountPence, 28_623)
        XCTAssertEqual(group.items.count, 2)
        XCTAssertFalse(group.items.contains { item in
            if case .cardPayment = item.action { return true }
            return false
        })

        let rerun = DefaultData.migratedSnapshot(migrated)
        XCTAssertFalse(rerun.didChange)
        XCTAssertEqual(rerun.snapshot, migrated)
        XCTAssertEqual(migrated.settings.creditCardOpeningStatementCycleMigrationVersion, 1)
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

    func testLegacySnapshotWithoutAuditEventsDecodesAsEmptyHistory() throws {
        let data = try JSONEncoder().encode(DefaultData.basicDataSnapshot)
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        dictionary.removeValue(forKey: "auditEvents")
        let legacyData = try JSONSerialization.data(withJSONObject: dictionary)

        let decoded = try JSONDecoder().decode(PlannerSnapshot.self, from: legacyData)

        XCTAssertTrue(decoded.auditEvents.isEmpty)
    }
}
