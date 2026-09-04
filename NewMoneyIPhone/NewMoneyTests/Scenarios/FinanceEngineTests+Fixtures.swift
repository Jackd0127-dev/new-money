import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
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
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 0)
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
}
