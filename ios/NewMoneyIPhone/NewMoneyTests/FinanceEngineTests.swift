import XCTest
@testable import NewMoneyIPhone

final class FinanceEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(true, forKey: "NewMoneyIPhone.didClearPaydayActivityV1")
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
                       NextPayPeriod(startDate: "2026-06-30", endDate: "2026-07-30", nextPayday: "2026-07-31"))
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

    func testGroupedComplexJanMar2027ChecklistTotalsMatchWorkbook() {
        let snapshot = DefaultData.groupedComplexJanMar2027Snapshot
        let expectations: [(periodId: String, today: String, recurringCount: Int, openingCount: Int, total: Int, moneyLeft: Int)] = [
            ("pay-period-grouped-january-2027", "2027-01-01", 24, 5, 411600, 38400),
            ("pay-period-grouped-february-2027", "2027-02-01", 24, 0, 285100, 164900),
            ("pay-period-grouped-march-2027", "2027-03-01", 24, 0, 269000, 181000),
        ]

        for expectation in expectations {
            let period = snapshot.payPeriods.first { $0.id == expectation.periodId }
            let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: period)
            let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: period)
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
            XCTAssertEqual(presentationItems.count, expectation.recurringCount + expectation.openingCount, expectation.periodId)
            XCTAssertEqual((recurringItems.map(\.amountPence) + openingItems.map(\.amountPence)).reduce(0, +), expectation.total, expectation.periodId)
            XCTAssertEqual(summary.totalCostsPence, expectation.total, expectation.periodId)
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
        XCTAssertEqual(presentationItems.count, 30)
        XCTAssertEqual((recurringItems.map(\.amountPence) + openingItems.map(\.amountPence)).reduce(0, +), 351900)
        XCTAssertEqual(summary.totalCostsPence, 351900)
        XCTAssertEqual(summary.moneyLeftPence, 48100)

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
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-pot2" }?.balancePence, 22000)

        var september30Settings = store.snapshot.settings
        september30Settings.manualTodayIso = "2026-09-30"
        store.updateSettings(september30Settings)

        let roadTaxTransaction = try XCTUnwrap(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-road-tax-2026-09-30" })
        XCTAssertEqual(roadTaxTransaction.creditCardId, "card-cc4")
        XCTAssertEqual(roadTaxTransaction.potId, "pot-pot5")
        XCTAssertEqual(roadTaxTransaction.amountPence, 18000)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-pot5" }?.balancePence, 0)
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
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 5000)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc1" }), snapshot: store.snapshot), 7500)
        var summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-02")
        XCTAssertEqual(summary.moneyLeftPence, 7500)

        var july15Settings = store.snapshot.settings
        july15Settings.manualTodayIso = "2026-07-15"
        store.updateSettings(july15Settings)

        potsById = Dictionary(uniqueKeysWithValues: store.snapshot.pots.map { ($0.id, $0) })
        XCTAssertEqual(potsById["pot-cc1"]?.balancePence, 0)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-cc1" }), snapshot: store.snapshot), 12500)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-skincare-2026-07-15" }?.potId, "pot-cc1")
        summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-15")
        XCTAssertEqual(summary.moneyLeftPence, 7500)
    }

    @MainActor
    func testFundingSameDayCardBillAfterItPostedConsumesPotAndTagsTransactionOnce() async {
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

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == "card-recurring-rec-bill-2026-07-01" }?.potId, pot.id)
        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-07-01")
        XCTAssertEqual(summary.potAllocationsPence, 10000)
        XCTAssertEqual(summary.totalCostsPence, 10000)
        XCTAssertEqual(summary.moneyLeftPence, 40000)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-07-01"))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == "card-recurring-rec-bill-2026-07-01" }.count, 1)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
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
    func testDueLinkedDebtPotPaysDebtOnce() async {
        let settings = makeManualSettings(today: "2026-06-10")
        let debt = makeDebt(id: "debt-loan", name: "Personal loan", currentBalancePence: 50000, dueDate: "2026-06-10")
        let pot = makePot(id: "pot-loan", name: "Loan pot", balancePence: 50000, targetPence: nil, linkedDebtId: debt.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings, pots: [pot], debts: [debt])))

        await store.load()
        let payment = store.snapshot.debtPayments.first

        XCTAssertEqual(payment?.id, "linked-debt-pot-payment-debt-loan-2026-06-10")
        XCTAssertEqual(payment?.amountPence, 50000)
        XCTAssertEqual(payment?.date, "2026-06-10")
        XCTAssertEqual(store.snapshot.debts.first?.currentBalancePence, 0)
        XCTAssertEqual(store.snapshot.debts.first?.status, .paid)
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
        let snapshot = makeSnapshot(pots: [linkedPot, nextPeriodPot], payPeriods: [period], debts: [eligible, unlinked, nextPeriod])

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
    func testCardBillPotCycleForecastsPostsConsumesFundedPotAndRepaysWithoutSecondCost() async {
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
        XCTAssertEqual(dueDateStore.snapshot.pots.first?.balancePence, 0)
        XCTAssertFalse(dueDateStore.applyDueLinkedPotObligations(asOf: "2026-06-10"))

        let onDueAvailability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: dueDateStore.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(onDueAvailability.actualAvailablePence, 70000)
        XCTAssertEqual(onDueAvailability.forecastAvailablePence, 70000)
        let onDueProgress = PlannerDerivedData.potProgress(pot: dueDateStore.snapshot.pots[0], snapshot: dueDateStore.snapshot, today: "2026-06-10")
        XCTAssertEqual(onDueProgress.targetPence, 0)
        XCTAssertEqual(onDueProgress.shortfallPence, 0)

        var julySettings = dueDateStore.snapshot.settings
        julySettings.manualTodayIso = "2026-07-01"
        dueDateStore.updateSettings(julySettings)

        let repayment = dueDateStore.snapshot.creditCardRepayments.first
        XCTAssertEqual(repayment?.amountPence, 10000)
        XCTAssertEqual(repayment?.source, .linkedPotStatement)
        XCTAssertEqual(repayment?.potContributionPence, 0)
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

        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)
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
        XCTAssertEqual(store.snapshot.debts.first?.status, .paid)
        XCTAssertEqual(store.snapshot.pots.first?.balancePence, 0)

        let dueSummary = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: "2026-06-10")
        XCTAssertEqual(dueSummary.potAllocationsPence, 50000)
        XCTAssertEqual(dueSummary.debtMinimumsPence, 0)
        XCTAssertEqual(dueSummary.totalCostsPence, 50000)
        XCTAssertEqual(dueSummary.moneyLeftPence, 0)

        XCTAssertFalse(store.applyDueLinkedPotObligations(asOf: "2026-06-10"))
        XCTAssertEqual(store.snapshot.debtPayments.count, 1)
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
        pots: [Pot] = [],
        recurringPayments: [RecurringPayment] = [],
        payPeriods: [PayPeriod] = [],
        potAllocations: [PotAllocation] = [],
        transactions: [Transaction] = [],
        debts: [Debt] = [],
        debtPayments: [DebtPayment] = [],
        creditCards: [CreditCard] = [],
        customPayments: [CustomPayment] = [],
        creditCardRepayments: [CreditCardRepayment] = []
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
            creditCards: creditCards,
            customPayments: customPayments,
            creditCardRepayments: creditCardRepayments,
            creditCardPots: [],
            dailyBriefs: []
        )
    }

    private func makePot(
        id: String,
        name: String,
        balancePence: Int,
        targetPence: Int?,
        linkedCreditCardId: String? = nil,
        linkedDebtId: String? = nil
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
            priority: .essential,
            active: true,
            createdAt: createdAt,
            updatedAt: createdAt,
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
