import Foundation

enum PlannerSaveState: Equatable {
    case saved
    case pending
    case failed
}

enum PlannerSavePayload: Equatable, Sendable {
    case snapshot(PlannerSnapshot)
    case accounts(PlannerAccountCollection)
}

/// Accepts mutations synchronously, then writes in order. Only pending, superseded
/// revisions are coalesced; an in-flight write always finishes before the next one.
@MainActor
final class PlannerSaveCoordinator {
    private let repository: PlannerRepository
    private let accountRepository: PlannerAccountRepository?
    private let stateChanged: (PlannerSaveState) -> Void
    private var nextRevision: UInt64 = 0
    private var committedRevision: UInt64 = 0
    private var latestPayload: PlannerSavePayload?
    private var pending: (revision: UInt64, payload: PlannerSavePayload)?
    private var worker: Task<Void, Never>?
    private var waiters: [(revision: UInt64, continuation: CheckedContinuation<Void, Error>)] = []

    init(repository: PlannerRepository, accountRepository: PlannerAccountRepository?, stateChanged: @escaping (PlannerSaveState) -> Void = { _ in }) {
        self.repository = repository
        self.accountRepository = accountRepository
        self.stateChanged = stateChanged
    }

    @discardableResult
    func enqueue(_ payload: PlannerSavePayload) -> UInt64 {
        if payload != latestPayload {
            nextRevision += 1
            latestPayload = payload
            pending = (nextRevision, payload)
        }
        startWorkerIfNeeded()
        return nextRevision
    }

    func save(_ payload: PlannerSavePayload) async throws {
        enqueue(payload)
        try await flush()
    }

    /// Retries a retained failed write and waits until the currently queued revision is durable.
    func flush() async throws {
        let target = nextRevision
        guard target > committedRevision else { return }
        startWorkerIfNeeded()
        try await withCheckedThrowingContinuation { continuation in
            waiters.append((target, continuation))
        }
    }

    private func startWorkerIfNeeded() {
        guard worker == nil, pending != nil else { return }
        stateChanged(.pending)
        worker = Task { await drain() }
    }

    private func drain() async {
        while let job = pending {
            pending = nil
            do {
                switch job.payload {
                case .snapshot(let snapshot):
                    try await repository.saveSnapshot(snapshot)
                case .accounts(let collection):
                    guard let accountRepository else { throw PlannerSaveError.missingAccountRepository }
                    try await accountRepository.saveAccountCollection(collection)
                }
                committedRevision = job.revision
                let ready = waiters.filter { $0.revision <= committedRevision }
                waiters.removeAll { $0.revision <= committedRevision }
                ready.forEach { $0.continuation.resume() }
            } catch {
                // A newer pending revision contains all preceding local edits.
                if pending == nil { pending = job }
                worker = nil
                stateChanged(.failed)
                let failed = waiters
                waiters.removeAll()
                failed.forEach { $0.continuation.resume(throwing: error) }
                return
            }
        }
        worker = nil
        stateChanged(.saved)
    }
}

private enum PlannerSaveError: Error {
    case missingAccountRepository
}
