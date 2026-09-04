import Foundation
import XCTest
@testable import NewMoneyIPhone

@MainActor
final class PlannerReminderSchedulerTests: XCTestCase {
    func testRefreshWhilePendingReadIsSuspendedSchedulesOnlyNewestGeneration() async {
        let existing = request("existing")
        let obsolete = request("obsolete")
        let intermediate = request("intermediate")
        let latest = request("latest")
        let gate = ReminderTestGate("First pending read started")
        let center = ReminderTestCenter(requests: [existing])
        center.firstPendingGate = gate
        let scheduler = PlannerReminderScheduler(center: center)

        scheduler.refresh([obsolete])
        defer { gate.open() }
        guard await waitForGate(gate) else { return }
        scheduler.refresh([intermediate])
        scheduler.refresh([latest])
        gate.open()
        await scheduler.flush()

        XCTAssertEqual(center.pendingReadCount, 2)
        XCTAssertEqual(center.addedRequests, [latest])
        XCTAssertEqual(center.removedIDs, [existing.id])
        XCTAssertEqual(center.requests, [latest])
    }

    func testRefreshWhileAddIsSuspendedReconcilesItsCompletionWithNewestGeneration() async {
        let firstDispatched = request("first", date: "2028-01-01")
        let obsoleteSecond = request("second", date: "2028-01-02")
        let intermediate = request("intermediate")
        let latest = request("latest")
        let gate = ReminderTestGate("First add started")
        let center = ReminderTestCenter()
        center.firstAddGate = gate
        let scheduler = PlannerReminderScheduler(center: center)

        scheduler.refresh([obsoleteSecond, firstDispatched])
        defer { gate.open() }
        guard await waitForGate(gate) else { return }
        scheduler.refresh([intermediate])
        scheduler.refresh([latest])
        gate.open()
        await scheduler.flush()

        XCTAssertEqual(center.addedRequests, [firstDispatched, latest])
        XCTAssertEqual(center.removedIDs, [firstDispatched.id])
        XCTAssertEqual(center.requests, [latest])
    }

    func testUnchangedRequestsAreNotAddedAgainAcrossRefreshes() async {
        let unchanged = request("unchanged")
        let stale = request("stale")
        let center = ReminderTestCenter(requests: [unchanged, stale])
        let scheduler = PlannerReminderScheduler(center: center)

        scheduler.refresh([unchanged])
        await scheduler.flush()
        scheduler.refresh([unchanged])
        await scheduler.flush()

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(center.removedIDs, [stale.id])
        XCTAssertEqual(center.requests, [unchanged])
    }

    func testDeniedPermissionRemovesManagedRequestsAndPreservesUnrelatedRequests() async {
        let managed = request("managed")
        let otherManaged = request("other-managed")
        let unrelated = PlannerReminderRequest(
            id: "unrelated-reminder", date: "2028-01-01", title: "Unrelated", body: "Keep this request"
        )
        let center = ReminderTestCenter(requests: [managed, unrelated, otherManaged])
        center.authorized = false
        let scheduler = PlannerReminderScheduler(center: center)

        scheduler.refresh([managed])
        await scheduler.flush()

        XCTAssertTrue(center.addedRequests.isEmpty)
        XCTAssertEqual(Set(center.removedIDs), Set([managed.id, otherManaged.id]))
        XCTAssertEqual(center.requests, [unrelated])
    }

    func testRequestsAreLimitedToSixtyAndOrderedByDateThenIdentifier() async {
        let requests = (0..<65).map { index in
            request(String(format: "%03d", index), date: index < 35 ? "2028-02-01" : "2028-01-01")
        }
        let center = ReminderTestCenter()
        let scheduler = PlannerReminderScheduler(center: center)

        scheduler.refresh(Array(requests.reversed()))
        await scheduler.flush()

        // January's 30 requests precede February's first 30 identifiers.
        let expected = (35..<65).map { requests[$0] } + (0..<30).map { requests[$0] }
        XCTAssertEqual(center.addedRequests, expected)
        XCTAssertEqual(center.requests, expected)
        XCTAssertEqual(center.requests.count, 60)
    }

    private func request(_ suffix: String, date: String = "2028-01-01") -> PlannerReminderRequest {
        PlannerReminderRequest(
            id: PlannerReminderScheduler.prefix + suffix,
            date: date,
            title: "Card payment",
            body: "Upcoming statement payment"
        )
    }

    private func waitForGate(
        _ gate: ReminderTestGate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Bool {
        let result = await XCTWaiter.fulfillment(of: [gate.entered], timeout: 2)
        guard result == .completed else {
            XCTFail("Scheduler did not reach the gated operation", file: file, line: line)
            return false
        }
        return true
    }
}

@MainActor
private final class ReminderTestCenter: PlannerReminderCenter {
    var authorized = true
    var requests: [PlannerReminderRequest]
    var firstPendingGate: ReminderTestGate?
    var firstAddGate: ReminderTestGate?
    private(set) var pendingReadCount = 0
    private(set) var addedRequests: [PlannerReminderRequest] = []
    private(set) var removedIDs: [String] = []

    init(requests: [PlannerReminderRequest] = []) {
        self.requests = requests
    }

    func isAuthorized() async -> Bool { authorized }

    func pending() async -> [PlannerReminderRequest] {
        pendingReadCount += 1
        let captured = requests
        if pendingReadCount == 1, let firstPendingGate {
            await firstPendingGate.pause()
        }
        // Return all records so the scheduler's ownership boundary is exercised.
        return captured
    }

    func remove(ids: [String]) {
        removedIDs.append(contentsOf: ids)
        requests.removeAll { ids.contains($0.id) }
    }

    func add(_ request: PlannerReminderRequest) async throws {
        addedRequests.append(request)
        if addedRequests.count == 1, let firstAddGate {
            await firstAddGate.pause()
        }
        requests.removeAll { $0.id == request.id }
        requests.append(request)
    }
}

@MainActor
private final class ReminderTestGate {
    let entered: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    init(_ description: String) {
        entered = XCTestExpectation(description: description)
    }

    func pause() async {
        entered.fulfill()
        guard !isOpen else { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
