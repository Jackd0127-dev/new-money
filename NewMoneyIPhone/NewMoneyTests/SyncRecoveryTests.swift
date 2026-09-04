import XCTest
@testable import NewMoneyIPhone

@MainActor
final class SyncRecoveryTests: XCTestCase {
    private let user = AuthUser(uid: "sync-user", email: nil, phoneNumber: nil, isEmailVerified: true, providerIDs: ["apple.com"])

    func testFailedUploadPersistsExactOutboxAndRetriesAfterRestart() async throws {
        let baseline = collection("Baseline")
        let local = collection("Local edit")
        let service = try SyncRecoveryCloudDouble(collection: baseline)
        let recovery = SyncRecoveryMemoryRepository()
        try await seed(recovery, baseline: baseline, cloud: service.cloud)
        service.failWrites = true
        let first = coordinator(service, recovery)
        do {
            _ = try await first.synchronize(local: local, hadPersistedLocalData: true, user: user)
            XCTFail("The fake write must fail")
        } catch SyncRecoveryDoubleError.offline {}
        let saved = try await recovery.loadCheckpoint(userID: user.uid)
        let pending = try XCTUnwrap(saved?.pendingUpload)
        XCTAssertEqual(pending.collection, local)
        XCTAssertEqual(service.cloud.collection, baseline)

        service.failWrites = false
        let restarted = coordinator(service, recovery)
        _ = try await restarted.synchronize(local: local, hadPersistedLocalData: true, user: user)
        XCTAssertEqual(service.cloud.collection, local)
        XCTAssertEqual(service.attempts.map(\.operationID), [pending.operationID, pending.operationID])
        let acknowledged = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(acknowledged?.pendingUpload)
        XCTAssertEqual(acknowledged?.acknowledgedLocalFingerprint, try PlannerCloudFingerprint.collection(local))
    }

    func testUnknownCommitOutcomeIsAcknowledgedWithoutAnotherWrite() async throws {
        let baseline = collection("Baseline")
        let local = collection("Local edit")
        let service = try SyncRecoveryCloudDouble(collection: baseline)
        let recovery = SyncRecoveryMemoryRepository()
        try await seed(recovery, baseline: baseline, cloud: service.cloud)
        service.failAfterCommit = true
        do {
            _ = try await coordinator(service, recovery).synchronize(local: local, hadPersistedLocalData: true, user: user)
            XCTFail("The fake response must fail after committing")
        } catch SyncRecoveryDoubleError.offline {}
        service.failAfterCommit = false
        _ = try await coordinator(service, recovery).synchronize(local: local, hadPersistedLocalData: true, user: user)
        XCTAssertEqual(service.attempts.count, 1)
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(checkpoint?.pendingUpload)
    }

    func testConflictKeepsBothCopiesAndDoesNotWriteCloud() async throws {
        let baseline = collection("Baseline")
        let local = collection("Local edit")
        let service = try SyncRecoveryCloudDouble(collection: baseline)
        let recovery = SyncRecoveryMemoryRepository()
        try await seed(recovery, baseline: baseline, cloud: service.cloud)
        try service.replaceCloud(collection("Remote edit"))
        let sync = coordinator(service, recovery)
        let result = try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user)
        guard case let .conflict(conflict) = result else { return XCTFail("Expected a conflict") }
        XCTAssertEqual(conflict.local, local)
        XCTAssertEqual(conflict.cloud.collection, collection("Remote edit"))
        XCTAssertNotNil(conflict.cloud.rawPayload)
        XCTAssertTrue(service.attempts.isEmpty)
        let archived = try await recovery.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(archived, conflict)

        try service.replaceCloud(collection("Remote edited again"))
        let changed = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user)
        guard case let .conflict(fresh) = changed else { return XCTFail("A stale choice must require another review") }
        XCTAssertNotEqual(fresh.id, conflict.id)
        XCTAssertTrue(service.attempts.isEmpty)
        let original = try await recovery.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(original, conflict)
    }

    func testExplicitCloudChoiceWaitsForDurableLocalReplacement() async throws {
        let local = collection("Legacy local")
        let remote = collection("Remote")
        let service = try SyncRecoveryCloudDouble(collection: remote)
        let recovery = SyncRecoveryMemoryRepository()
        let sync = coordinator(service, recovery)
        guard case let .conflict(conflict) = try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user) else {
            return XCTFail("Unowned legacy data must be reviewed")
        }
        guard case let .replaceLocal(replacement, cloud) = try await sync.chooseCloud(conflictID: conflict.id, currentLocal: local, user: user) else {
            return XCTFail("Expected explicit replacement")
        }
        XCTAssertEqual(replacement, remote)
        let beforeSave = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertEqual(beforeSave?.conflictID, conflict.id)
        try await sync.acknowledgeDownload(originalCollection: replacement, cloud: cloud, user: user)
        let afterSave = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(afterSave?.conflictID)
        let archived = try await recovery.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(archived?.local, local)
        XCTAssertTrue(service.attempts.isEmpty)
    }

    func testExplicitLocalChoiceConditionallyUploadsAndRetainsArchive() async throws {
        let local = collection("Legacy local")
        let service = try SyncRecoveryCloudDouble(collection: collection("Remote"))
        let recovery = SyncRecoveryMemoryRepository()
        let sync = coordinator(service, recovery)
        guard case let .conflict(conflict) = try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user) else {
            return XCTFail("Expected conflict")
        }
        _ = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user)
        XCTAssertEqual(service.cloud.collection, local)
        let archive = try await recovery.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(archive?.cloud.collection, collection("Remote"))
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(checkpoint?.conflictID)
    }

    func testLegacyLocalIsNotUploadedToMissingCloudWithoutOwnershipChoice() async throws {
        let service = try SyncRecoveryCloudDouble(collection: nil)
        let recovery = SyncRecoveryMemoryRepository()
        let result = try await coordinator(service, recovery).synchronize(local: collection("Personal"), hadPersistedLocalData: true, user: user)
        guard case let .conflict(conflict) = result else { return XCTFail("Missing cloud is not proof of local ownership") }
        XCTAssertTrue(conflict.requiresOwnershipConfirmation)
        XCTAssertEqual(conflict.cloud.revision, .missing)
        XCTAssertTrue(service.attempts.isEmpty)
    }

    func testFailedLocalChoiceRetainsReviewAndRetriesExactOperationAfterRestart() async throws {
        let local = collection("Legacy local")
        let service = try SyncRecoveryCloudDouble(collection: collection("Remote"))
        let recovery = SyncRecoveryMemoryRepository()
        let sync = coordinator(service, recovery)
        guard case let .conflict(conflict) = try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user) else {
            return XCTFail("Expected conflict")
        }
        service.failWrites = true
        do {
            _ = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user)
            XCTFail("Expected offline write")
        } catch SyncRecoveryDoubleError.offline {}
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        let pending = try XCTUnwrap(checkpoint?.pendingUpload)
        XCTAssertEqual(checkpoint?.conflictID, conflict.id)
        XCTAssertEqual(pending.resolutionConflictID, conflict.id)
        do {
            _ = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user)
            XCTFail("Repeated choice must retry, rather than lose the saved review")
        } catch SyncRecoveryDoubleError.offline {}
        service.failWrites = false
        _ = try await coordinator(service, recovery).synchronize(local: local, hadPersistedLocalData: true, user: user)
        XCTAssertEqual(service.cloud.collection, local)
        XCTAssertEqual(service.attempts.map(\.operationID), Array(repeating: pending.operationID, count: 3))
        let saved = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(saved?.conflictID)
        XCTAssertNil(saved?.pendingUpload)
        let archived = try await recovery.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(archived, conflict)
    }

    func testRepeatedLocalChoiceRecoversCommittedWriteWithLostResponse() async throws {
        let local = collection("Legacy local")
        let service = try SyncRecoveryCloudDouble(collection: collection("Remote"))
        let recovery = SyncRecoveryMemoryRepository()
        let sync = coordinator(service, recovery)
        guard case let .conflict(conflict) = try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user) else {
            return XCTFail("Expected conflict")
        }
        service.failAfterCommit = true
        do {
            _ = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user)
            XCTFail("Expected lost commit response")
        } catch SyncRecoveryDoubleError.offline {}
        guard case .acknowledged = try await sync.chooseLocal(conflictID: conflict.id, currentLocal: local, user: user) else {
            return XCTFail("The persisted choice must recognize the already committed content")
        }
        XCTAssertEqual(service.attempts.count, 1)
        let saved = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(saved?.conflictID)
    }

    func testOfflineOwnershipPreflightDoesNotTrustUnknownOrAnotherAccountsLocalData() async throws {
        let service = try SyncRecoveryCloudDouble(collection: nil)
        service.failReads = true
        let recovery = SyncRecoveryMemoryRepository()
        let sync = coordinator(service, recovery)
        try await sync.initializeLocalState(local: collection("Legacy"), hadPersistedLocalData: true, user: user)
        let unknown = try await sync.hasVerifiedLocalOwner(user: user)
        XCTAssertFalse(unknown)
        try await recovery.setLocalOwnerID("another-account")
        let otherAccount = try await sync.hasVerifiedLocalOwner(user: user)
        XCTAssertFalse(otherAccount)
        try await recovery.setLocalOwnerID(user.uid)
        let verified = try await sync.hasVerifiedLocalOwner(user: user)
        XCTAssertTrue(verified)
        XCTAssertTrue(service.attempts.isEmpty)
    }

    func testFirstLaunchOfflineDoesNotDiscardLaterEditsWhenCloudAppears() async throws {
        let initial = collection("Personal")
        let service = try SyncRecoveryCloudDouble(collection: nil)
        let recovery = SyncRecoveryMemoryRepository()
        let first = coordinator(service, recovery)
        try await first.initializeLocalState(local: initial, hadPersistedLocalData: false, user: user)
        let isFreshOwnedData = try await first.hasVerifiedLocalOwner(user: user)
        XCTAssertTrue(isFreshOwnedData)
        service.failReads = true
        do {
            _ = try await first.synchronize(local: initial, hadPersistedLocalData: false, user: user)
            XCTFail("Expected offline read")
        } catch SyncRecoveryDoubleError.offline {}
        service.failReads = false
        try service.replaceCloud(collection("Remote discovered later"))
        let local = collection("Edited offline")
        let result = try await coordinator(service, recovery).synchronize(local: local, hadPersistedLocalData: true, user: user)
        guard case let .conflict(conflict) = result else { return XCTFail("Fresh-install provenance must survive restart") }
        XCTAssertEqual(conflict.local, local)
        XCTAssertTrue(service.attempts.isEmpty)
    }

    func testConcurrentRequestsAreSerializedAndNewestDataWinsLocallyOrderedWrites() async throws {
        let baseline = collection("Baseline")
        let service = try SyncRecoveryCloudDouble(collection: baseline)
        let recovery = SyncRecoveryMemoryRepository()
        try await seed(recovery, baseline: baseline, cloud: service.cloud)
        let sync = coordinator(service, recovery)
        let entered = expectation(description: "First conditional write entered")
        service.writeEntered = entered
        service.pauseWrite = true
        let first = Task { try await sync.synchronize(local: collection("First"), hadPersistedLocalData: true, user: user) }
        let firstWriteWait = await XCTWaiter.fulfillment(of: [entered], timeout: 2)
        guard firstWriteWait == .completed else {
            service.resumeWrite()
            _ = try? await first.value
            return XCTFail("The first request did not reach its conditional write")
        }
        let second = Task { try await sync.synchronize(local: collection("Second"), hadPersistedLocalData: true, user: user) }
        service.resumeWrite()
        _ = try await first.value
        _ = try await second.value
        XCTAssertEqual(service.maximumConcurrentWrites, 1)
        XCTAssertEqual(service.cloud.collection, collection("Second"))
    }

    func testSuspendedGenerationCannotAcknowledgeAnInFlightWrite() async throws {
        let baseline = collection("Baseline")
        let local = collection("Local")
        let service = try SyncRecoveryCloudDouble(collection: baseline)
        let recovery = SyncRecoveryMemoryRepository()
        try await seed(recovery, baseline: baseline, cloud: service.cloud)
        let sync = coordinator(service, recovery)
        let entered = expectation(description: "Conditional write entered")
        service.writeEntered = entered
        service.pauseWrite = true
        let writing = Task { try await sync.synchronize(local: local, hadPersistedLocalData: true, user: user) }
        let writeWait = await XCTWaiter.fulfillment(of: [entered], timeout: 2)
        guard writeWait == .completed else {
            service.resumeWrite()
            _ = try? await writing.value
            return XCTFail("The request did not reach its conditional write")
        }
        Task { @MainActor in
            await Task.yield()
            service.resumeWrite()
        }
        await sync.suspendAndWait()
        do {
            _ = try await writing.value
            XCTFail("A suspended generation must not acknowledge")
        } catch PlannerSyncRecoveryError.staleSession {}
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNotNil(checkpoint?.pendingUpload)
        XCTAssertEqual(checkpoint?.acknowledgedLocalFingerprint, try PlannerCloudFingerprint.collection(baseline))
    }

    func testArchiveFailureStopsBeforeAnyReplacementOrCloudWrite() async throws {
        let service = try SyncRecoveryCloudDouble(collection: collection("Remote"))
        let recovery = SyncRecoveryMemoryRepository()
        await recovery.setArchiveFailure(true)
        do {
            _ = try await coordinator(service, recovery).synchronize(local: collection("Local"), hadPersistedLocalData: true, user: user)
            XCTFail("Preservation failure must stop the operation")
        } catch SyncRecoveryDoubleError.diskFull {}
        XCTAssertTrue(service.attempts.isEmpty)
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertNil(checkpoint)
    }

    func testFingerprintsArePureAndLegacyAccountIdentityIsStable() throws {
        let local = collection("Personal")
        XCTAssertEqual(try PlannerCloudFingerprint.collection(local), try PlannerCloudFingerprint.collection(local))
        let payload = try PlannerCloudPayload.current(snapshot: local.accounts[0].snapshot, updatedAtIso: "2026-01-01T00:00:00Z").firestoreData()
        let first = try PlannerCloudDocumentCodec.read(fields: payload)
        let second = try PlannerCloudDocumentCodec.read(fields: payload)
        XCTAssertEqual(first, second)
        var newer = payload
        newer["version"] = 99
        XCTAssertThrowsError(try PlannerCloudDocumentCodec.read(fields: newer))
    }

    func testRawPatchPreservesUnknownFieldsButRemovesDeletedKnownOptionalFields() throws {
        let raw: [String: Any] = ["id": "record", "note": "Old", "optional": "remove", "futureField": 42,
                                  "records": [["id": "a", "name": "Old", "futureNested": "keep"], ["id": "deleted", "name": "Gone"]]]
        let before: [String: Any] = ["id": "record", "note": "Old", "optional": "remove",
                                     "records": [["id": "a", "name": "Old"], ["id": "deleted", "name": "Gone"]]]
        let after: [String: Any] = ["id": "record", "note": "New", "records": [["id": "a", "name": "New"]]]
        let patched = try XCTUnwrap(PlannerCloudDocumentCodec.preservingUnknownFields(raw: raw, before: before, after: after) as? [String: Any])
        XCTAssertNil(patched["optional"])
        XCTAssertEqual(patched["futureField"] as? Int, 42)
        let records = try XCTUnwrap(patched["records"] as? [[String: Any]])
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0]["futureNested"] as? String, "keep")
        XCTAssertEqual(records[0]["name"] as? String, "New")
    }

    func testRecoveryFilesSurviveReopeningAndNeverOverwriteConflictVersions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = FilePlannerSyncRecoveryRepository(directory: directory)
        let local = collection("Local")
        let conflict = PlannerSyncConflict(id: "immutable", ownerUID: user.uid, capturedAtIso: "2026-01-01",
            local: local, cloud: try .collection(collection("Remote")), baselineRevision: nil, requiresOwnershipConfirmation: true)
        try await first.archive(conflict)
        try await first.saveCheckpoint(PlannerSyncCheckpoint(ownerUID: user.uid, conflictID: conflict.id))
        let reopened = FilePlannerSyncRecoveryRepository(directory: directory)
        let restored = try await reopened.conflict(id: conflict.id, userID: user.uid)
        XCTAssertEqual(restored, conflict)
        let otherUserCheckpoint = try await reopened.loadCheckpoint(userID: "someone-else")
        XCTAssertNil(otherUserCheckpoint)
        var changed = conflict
        changed.local = collection("Changed")
        do {
            try await reopened.archive(changed)
            XCTFail("An immutable conflict must not be overwritten")
        } catch PlannerSyncRecoveryError.invalidCheckpoint {}
    }

    private func collection(_ name: String) -> PlannerAccountCollection {
        let account = PlannerAccount(id: "planner", name: name, color: "#F97316", snapshot: DefaultData.emptySnapshot,
            createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
        return PlannerAccountCollection(activeAccountId: account.id, accounts: [account], updatedAt: account.updatedAt)
    }

    private func coordinator(_ service: SyncRecoveryCloudDouble, _ recovery: SyncRecoveryMemoryRepository) -> PlannerSyncCoordinator {
        let coordinator = PlannerSyncCoordinator(service: service, recovery: recovery)
        coordinator.activate(userID: user.uid)
        return coordinator
    }

    private func seed(_ recovery: SyncRecoveryMemoryRepository, baseline: PlannerAccountCollection, cloud: PlannerCloudRead) async throws {
        try await recovery.saveCheckpoint(PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: cloud.revision,
            acknowledgedLocalFingerprint: PlannerCloudFingerprint.collection(baseline)))
        try await recovery.setLocalOwnerID(user.uid)
    }
}

private enum SyncRecoveryDoubleError: Error { case offline, diskFull }

private actor SyncRecoveryMemoryRepository: PlannerSyncRecoveryRepository {
    var checkpoints: [String: PlannerSyncCheckpoint] = [:]
    var archives: [String: PlannerSyncConflict] = [:]
    var owner: String?
    var archiveFailure = false

    func loadCheckpoint(userID: String) async throws -> PlannerSyncCheckpoint? { checkpoints[userID] }
    func saveCheckpoint(_ checkpoint: PlannerSyncCheckpoint) async throws { checkpoints[checkpoint.ownerUID] = checkpoint }
    func localOwnerID() async throws -> String? { owner }
    func setLocalOwnerID(_ userID: String) async throws { owner = userID }
    func setArchiveFailure(_ enabled: Bool) { archiveFailure = enabled }
    func archive(_ conflict: PlannerSyncConflict) async throws {
        if archiveFailure { throw SyncRecoveryDoubleError.diskFull }
        archives[conflict.id] = conflict
    }
    func conflict(id: String, userID: String) async throws -> PlannerSyncConflict? {
        guard archives[id]?.ownerUID == userID else { return nil }
        return archives[id]
    }
}

@MainActor
private final class SyncRecoveryCloudDouble: CloudSyncService {
    var cloud: PlannerCloudRead
    var failReads = false
    var failWrites = false
    var failAfterCommit = false
    var pauseWrite = false
    var writeEntered: XCTestExpectation?
    var attempts: [PlannerPendingUpload] = []
    var maximumConcurrentWrites = 0
    private var concurrentWrites = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var revision: Int64 = 1

    init(collection: PlannerAccountCollection?) throws {
        cloud = try collection.map(PlannerCloudRead.collection) ?? .missing
    }

    func replaceCloud(_ collection: PlannerAccountCollection) throws {
        revision += 1
        cloud = try .collection(collection)
        if let hash = cloud.revision.payloadSHA256 {
            cloud.revision = .document(payloadSHA256: hash, updatedAt: PlannerServerTimestamp(seconds: revision, nanoseconds: 0))
        }
    }

    func pullAccountCollection(for user: AuthUser) async throws -> CloudPlannerAccountCollectionRecord? {
        guard let collection = cloud.collection else { return nil }
        return CloudPlannerAccountCollectionRecord(collection: collection, updatedAtIso: nil)
    }
    func pushAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        XCTFail("Unconditional legacy writes must never be used")
    }
    func readAuthoritative(for user: AuthUser) async throws -> PlannerCloudRead {
        if failReads { throw SyncRecoveryDoubleError.offline }
        return cloud
    }
    func compareAndSet(_ pending: PlannerPendingUpload, for user: AuthUser) async throws -> PlannerCloudWriteResult {
        attempts.append(pending)
        concurrentWrites += 1
        maximumConcurrentWrites = max(maximumConcurrentWrites, concurrentWrites)
        defer { concurrentWrites -= 1 }
        if pauseWrite {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                writeEntered?.fulfill()
            }
        } else {
            await Task.yield()
        }
        if failWrites { throw SyncRecoveryDoubleError.offline }
        guard cloud.revision == pending.expectedRevision else { return .conflict(cloud) }
        try replaceCloud(pending.collection)
        if failAfterCommit { throw SyncRecoveryDoubleError.offline }
        return .committed(cloud)
    }
    func resetAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        try replaceCloud(collection)
    }
    func resumeWrite() {
        pauseWrite = false
        continuation?.resume()
        continuation = nil
    }
}
