import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

// Extensions keep one XCTest suite and its existing setup/teardown behavior.
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
}
