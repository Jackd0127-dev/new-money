import XCTest
@testable import NewMoneyIPhone

final class AppShellNavigationTests: XCTestCase {
    func testPrimaryTabOrderMatchesMainNavigationRestructure() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Home", "Plan", "Activity", "Pots", "Credit"])
        XCTAssertEqual(AppTab.allCases.map(\.symbol), ["house", "calendar.badge.clock", "list.bullet.rectangle.portrait", "wallet.pass", "creditcard.trianglebadge.exclamationmark"])
    }

    func testUniversalAddMenuIncludesSupportedAddFlows() {
        XCTAssertEqual(AppAddAction.allCases.map(\.title), ["Add Spend", "Add Income", "Add Bill", "Add Pot", "Add Card", "Add Card Payment", "Add Debt"])
        XCTAssertEqual(AppAddAction.allCases.map(\.symbol), ["receipt", "sterlingsign.circle", "calendar.badge.plus", "wallet.pass", "creditcard", "creditcard.and.123", "exclamationmark.shield"])
    }

    func testToolbarActionsHideRequestedTabExtras() {
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .home), ["add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .plan), ["add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .activity), ["add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .pots), ["pot-history-toolbar-action", "add-menu-toolbar-action"])
        XCTAssertEqual(AppToolbarPolicy.actionIds(for: .credit), ["add-menu-toolbar-action"])
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .home).contains("calendar-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .plan).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .activity).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .activity).contains("spending-history-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .pots).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .credit).contains("settings-toolbar-action"))
        XCTAssertFalse(AppToolbarPolicy.actionIds(for: .credit).contains("card-payments-toolbar-action"))
    }

    func testEditToolbarActionUsesTextButton() {
        let action = AppToolbarAction.edit()

        XCTAssertEqual(action.id, "edit-toolbar-action")
        XCTAssertEqual(action.title, "Edit")
        XCTAssertEqual(action.accessibilityLabel, "Edit")
    }

    func testCreditRoutesHideCardPaymentsAndStatements() {
        XCTAssertEqual(CreditRoute.allCases.map(\.title), ["Cards", "Debts"])
        XCTAssertFalse(CreditRoute.allCases.map(\.title).contains("Card payments"))
        XCTAssertFalse(CreditRoute.allCases.map(\.title).contains("Statements"))
    }

    func testSettingsRoutesIncludeCreditStatements() {
        XCTAssertEqual(SettingsRoute.allCases.map(\.title), ["History", "Credit Statements"])
    }

    func testCreditSecondaryScreenToolbarActionsMatchRequestedButtons() {
        XCTAssertEqual(CardsLayoutPolicy.toolbarActionId, "add")
        XCTAssertEqual(DebtsLayoutPolicy.toolbarActionId, "add")
        XCTAssertEqual(StatementsLayoutPolicy.toolbarActionId, "edit-toolbar-action")
    }

    func testCreditSecondaryScreensHideInlineAddAndAllocationCards() {
        XCTAssertEqual(CardsLayoutPolicy.sections, [.summary, .activeCards])
        XCTAssertFalse(CardsLayoutPolicy.sections.contains(.paymentAllocation))
        XCTAssertEqual(DebtsLayoutPolicy.sections, [.summary, .activeDebts])
        XCTAssertFalse(DebtsLayoutPolicy.sections.contains(.addDebt))
    }
}

final class DashboardSpendingChartTests: XCTestCase {
    func testHomeLayoutMovesSpendingSnapshotIntoMoneyLeftDetails() {
        XCTAssertEqual(
            DashboardHomeLayoutPolicy.homeSections,
            [
                .hero,
                .accounts,
                .monthlySpendChart,
                .upcomingBeforePayday,
                .alerts,
                .fundingChecklist,
                .recentActivity
            ]
        )
        XCTAssertFalse(DashboardHomeLayoutPolicy.homeSections.contains(.paydayPlanning))
        XCTAssertFalse(DashboardHomeLayoutPolicy.homeSections.contains(.spendingSnapshot))
        XCTAssertTrue(DashboardHomeLayoutPolicy.moneyLeftDetailSections.contains(.spendingSnapshot))
        XCTAssertEqual(DashboardHomeLayoutPolicy.moneyLeftDetailPresentation, .navigationPush)
    }

    func testMonthlySpendingChartUsesCurrentMonthSpendingThroughTodayOnly() {
        let transactions = [
            makeTransaction(id: "coffee", amountPence: 450, type: .spending, date: "2026-07-01"),
            makeTransaction(id: "groceries", amountPence: 2550, type: .spending, date: "2026-07-03"),
            makeTransaction(id: "future", amountPence: 9999, type: .spending, date: "2026-07-20"),
            makeTransaction(id: "last-month", amountPence: 8000, type: .spending, date: "2026-06-30"),
            makeTransaction(id: "allocation", amountPence: 1200, type: .allocation, date: "2026-07-03")
        ]

        let chartData = DashboardMonthlySpendChartData.make(transactions: transactions, todayIso: "2026-07-03")

        XCTAssertEqual(chartData.totalPence, 3000)
        XCTAssertEqual(chartData.daysElapsed, 3)
        XCTAssertEqual(chartData.daysInMonth, 31)
        XCTAssertEqual(chartData.points[0].amountPence, 450)
        XCTAssertEqual(chartData.points[1].amountPence, 0)
        XCTAssertEqual(chartData.points[2].amountPence, 2550)
        XCTAssertTrue(chartData.points[19].isFuture)
    }

    private func makeTransaction(
        id: String,
        amountPence: Int,
        type: TransactionType,
        date: String
    ) -> Transaction {
        Transaction(
            id: id,
            potId: nil,
            payPeriodId: nil,
            amountPence: amountPence,
            type: type,
            paymentMethod: .pot,
            creditCardId: nil,
            recurringPaymentId: nil,
            date: date,
            note: id,
            createdAt: date,
            updatedAt: date,
            deletedAt: nil
        )
    }
}

final class PlanLayoutTests: XCTestCase {
    func testPlanUsesCompactSwipeCalendarAndMinimalCards() {
        XCTAssertEqual(PlanLayoutPolicy.sections, [.calendar, .upcomingBills, .recurringPayments])
        XCTAssertFalse(PlanLayoutPolicy.sections.contains(.incomeSchedule))
        XCTAssertFalse(PlanLayoutPolicy.calendarElements.contains(.monthHeaderCard))
        XCTAssertTrue(PlanLayoutPolicy.calendarElements.contains(.swipeMonthGrid))
        XCTAssertFalse(PlanLayoutPolicy.showsCalendarSectionTitle)
        XCTAssertEqual(PlanLayoutPolicy.monthSwipeTransition, .horizontalSlide)
        XCTAssertLessThanOrEqual(PlanLayoutPolicy.dayCellHeight, 44)
        XCTAssertEqual(PlanLayoutPolicy.emptySelectedDayMessage, "No money events are scheduled for this day.")
        XCTAssertEqual(PlanLayoutPolicy.emptyUpcomingBillsSubtitle, "Upcoming bills will appear here.")
        XCTAssertEqual(PlanLayoutPolicy.emptyRecurringPaymentsSubtitle, "Recurring payments will appear here.")
    }
}

final class ActivityLayoutTests: XCTestCase {
    func testActivityLayoutShowsRecentActivityBeforeIncomeAndSpending() {
        XCTAssertEqual(ActivityLayoutPolicy.sections, [.recentActivity, .income, .spending])
    }
}
