import XCTest
@testable import NewMoneyIPhone

final class PresentationCacheTests: XCTestCase {
    @MainActor
    func testCalendarCellLookupsReuseProjectionAndChangesInvalidateIt() {
        let cache = RevisionPresentationCache<CalendarMonthPresentationKey, Int>()
        var key = CalendarMonthPresentationKey(
            revision: PlannerPresentationRevision(
                accountId: "personal",
                snapshotRevision: 1,
                todayIso: "2026-08-31",
                selectedPayPeriodId: "august"
            ),
            startDate: "2026-08-01",
            endDate: "2026-08-31"
        )
        var builds = 0
        func read() -> Int {
            cache.value(for: key) {
                builds += 1
                return builds
            }
        }

        // All day markers and repeated drag/selection renders share a month.
        for _ in 0..<100 {
            XCTAssertEqual(read(), 1)
        }
        key.revision.snapshotRevision += 1
        XCTAssertEqual(read(), 2)
        key.revision.accountId = "household"
        XCTAssertEqual(read(), 3)
        key.revision.todayIso = "2026-09-01"
        XCTAssertEqual(read(), 4)
        key.revision.selectedPayPeriodId = "september"
        XCTAssertEqual(read(), 5)
        key.startDate = "2026-09-01"
        key.endDate = "2026-09-30"
        XCTAssertEqual(read(), 6)
        XCTAssertEqual(read(), 6)
    }

    func testCalendarPresentationGroupsOnlyVisibleMonthWithoutChangingAmounts() {
        var snapshot = DefaultData.emptySnapshot
        snapshot.oneOffIncomes = [
            income(id: "august-one", date: "2026-08-01", amount: 1_025),
            income(id: "august-two", date: "2026-08-01", amount: 2_030),
            income(id: "august-end", date: "2026-08-31", amount: 4_050),
            income(id: "september", date: "2026-09-01", amount: 8_090)
        ]
        let august = CalendarMonthPresentation.make(
            snapshot: snapshot,
            startDate: "2026-08-01",
            endDate: "2026-08-31"
        )

        XCTAssertEqual(august.eventDates, ["2026-08-01", "2026-08-31"])
        XCTAssertEqual(august.eventsByDate["2026-08-01"]?.compactMap(\.amountPence).sorted(), [1_025, 2_030])
        XCTAssertEqual(august.eventsByDate["2026-08-31"]?.first?.amountPence, 4_050)
        XCTAssertNil(august.eventsByDate["2026-09-01"])
    }

    func testAssistantRoutesSpecificBalancesBeforeGenericMoneyKeywords() {
        let snapshot = DefaultData.emptySnapshot
        let cards = AssistantLocalResponseBuilder.response(to: "What is my card balance?", snapshot: snapshot, selectedPayPeriod: nil)
        let debts = AssistantLocalResponseBuilder.response(to: "What is my debt balance?", snapshot: snapshot, selectedPayPeriod: nil)
        let bills = AssistantLocalResponseBuilder.response(to: "Show unpaid bills", snapshot: snapshot, selectedPayPeriod: nil)

        XCTAssertTrue(cards.contains("active cards"))
        XCTAssertTrue(debts.contains("active debts"))
        XCTAssertTrue(bills.contains("active bills"))
        XCTAssertFalse(bills.contains("pay period"))
    }

    private func income(id: String, date: String, amount: Int) -> OneOffIncome {
        OneOffIncome(
            id: id,
            payPeriodId: nil,
            name: id,
            amountPence: amount,
            date: date,
            note: "",
            createdAt: "2026-08-01T00:00:00.000Z",
            updatedAt: "2026-08-01T00:00:00.000Z",
            deletedAt: nil
        )
    }
}
