import Foundation
import XCTest
@testable import NewMoneyIPhone

@MainActor
final class PlannerSaveCoordinatorTests: XCTestCase {
    func testInFlightSaveFinishesBeforeCoalescedLatestRevision() async throws {
        let repository = ControlledSaveRepository()
        let coordinator = PlannerSaveCoordinator(repository: repository, accountRepository: nil)
        var first = DefaultData.emptySnapshot
        first.settings.assistantName = "First"
        coordinator.enqueue(.snapshot(first))
        await repository.waitForFirstWrite()
        var middle = first
        middle.settings.assistantName = "Middle"
        coordinator.enqueue(.snapshot(middle))
        var latest = first
        latest.settings.assistantName = "Latest"
        coordinator.enqueue(.snapshot(latest))
        await repository.releaseFirstWrite()
        try await coordinator.flush()
        let saved = await repository.savedNames
        let simultaneous = await repository.maximumSimultaneousWrites
        XCTAssertEqual(saved, ["First", "Latest"])
        XCTAssertEqual(simultaneous, 1)
    }

    func testFailedWriteRetainsLatestRevisionForRetry() async throws {
        let repository = FailingOnceRepository()
        var states: [PlannerSaveState] = []
        let coordinator = PlannerSaveCoordinator(repository: repository, accountRepository: nil) { states.append($0) }
        var snapshot = DefaultData.emptySnapshot
        snapshot.settings.assistantName = "Preserved"
        do {
            try await coordinator.save(.snapshot(snapshot))
            XCTFail("Expected write failure")
        } catch { }
        XCTAssertEqual(states.last, .failed)
        try await coordinator.flush()
        let stored = await repository.value
        XCTAssertEqual(stored?.settings.assistantName, "Preserved")
        XCTAssertEqual(states.last, .saved)
    }

    func testIdenticalPayloadDoesNotWriteAgain() async throws {
        let repository = FailingOnceRepository(failNext: false)
        let coordinator = PlannerSaveCoordinator(repository: repository, accountRepository: nil)
        let snapshot = DefaultData.emptySnapshot
        try await coordinator.save(.snapshot(snapshot))
        try await coordinator.save(.snapshot(snapshot))
        let count = await repository.writeCount
        XCTAssertEqual(count, 1)
    }
}

private actor ControlledSaveRepository: PlannerRepository {
    var savedNames: [String?] = []
    var maximumSimultaneousWrites = 0
    private var simultaneous = 0
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?

    func waitForFirstWrite() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func releaseFirstWrite() { release?.resume(); release = nil }
    func loadSnapshot() async throws -> PlannerSnapshot { DefaultData.emptySnapshot }
    func resetSnapshot() async throws { }
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        simultaneous += 1
        maximumSimultaneousWrites = max(maximumSimultaneousWrites, simultaneous)
        if !started {
            started = true
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation { release = $0 }
        }
        savedNames.append(snapshot.settings.assistantName)
        simultaneous -= 1
    }
}

private actor FailingOnceRepository: PlannerRepository {
    var value: PlannerSnapshot?
    var writeCount = 0
    private var failNext: Bool
    init(failNext: Bool = true) { self.failNext = failNext }
    func loadSnapshot() async throws -> PlannerSnapshot { value ?? DefaultData.emptySnapshot }
    func resetSnapshot() async throws { }
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        writeCount += 1
        if failNext { failNext = false; throw CocoaError(.fileWriteUnknown) }
        value = snapshot
    }
}
