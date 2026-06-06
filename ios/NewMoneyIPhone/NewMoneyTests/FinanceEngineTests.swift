import XCTest
@testable import NewMoneyIPhone

final class FinanceEngineTests: XCTestCase {
    func testParsesPoundsToIntegerPenceLikeTheWebApp() {
        XCTAssertEqual(MoneyParser.parsePoundsToPence("12.34"), 1234)
        XCTAssertEqual(MoneyParser.parsePoundsToPence("£1,200.99"), 120099)
        XCTAssertEqual(MoneyParser.parsePoundsToPence("bad input"), 0)
    }

    func testCalculatesPaycheckAmountFromHoursAndRateUnlessActualIsProvided() {
        XCTAssertEqual(FinanceEngine.calculatePaycheckAmount(hoursWorked: 72, hourlyRatePence: 1250, actualAmountPence: nil), 90000)
        XCTAssertEqual(FinanceEngine.calculatePaycheckAmount(hoursWorked: 72, hourlyRatePence: 1250, actualAmountPence: 87550), 87550)
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
}
