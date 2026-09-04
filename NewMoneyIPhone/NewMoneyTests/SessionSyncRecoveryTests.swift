import Combine
import Foundation
import XCTest
@testable import NewMoneyIPhone

@MainActor
final class SessionSyncRecoveryTests: XCTestCase {
    private let user = AuthUser(uid: "session-sync-user", email: nil, phoneNumber: nil,
        isEmailVerified: true, providerIDs: ["apple.com"])

    func testFixtureStartupDoesNotConsumeExistingRealCloudOrPendingRecoveryState() async throws {
        let (store, _) = try await makeStore()
        var realCloudCollection = store.accountCollectionForCloudUpload()
        realCloudCollection.accounts[0].name = "Existing cloud planner"
        let cloud = SessionSyncCloudDouble(record: try .collection(realCloudCollection))
        var realPendingCollection = realCloudCollection
        realPendingCollection.accounts[0].name = "Existing unsynced planner"
        let pending = PlannerPendingUpload(collection: realPendingCollection, expectedRevision: cloud.record.revision)
        let checkpoint = PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: cloud.record.revision,
            acknowledgedLocalFingerprint: try PlannerCloudFingerprint.collection(realCloudCollection), pendingUpload: pending)
        let recovery = SessionSyncRecoveryDouble(owner: user.uid, checkpoint: checkpoint)
        let session = makeSession(cloud: cloud, recovery: recovery, isFixtureSession: true)

        await session.start(store: store)

        XCTAssertEqual(session.state, .ready(user))
        XCTAssertEqual(session.syncStatus, .fixture)
        XCTAssertEqual(session.cloudStatus, "Fixture data. Cloud sync off")
        XCTAssertEqual(store.activePlannerAccount?.name, "Local planner")
        XCTAssertEqual(cloud.readCount, 0)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
        let recoveryAccesses = await recovery.numberOfAccesses()
        XCTAssertEqual(recoveryAccesses, 0)
        let unchangedCheckpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertEqual(unchangedCheckpoint, checkpoint)
    }

    func testFixtureSyncEntryPointsAndResetNeverAccessCloudOrRecovery() async throws {
        let (store, _) = try await makeStore()
        let cloud = SessionSyncCloudDouble(record: .missing)
        let recovery = SessionSyncRecoveryDouble(owner: nil)
        let session = makeSession(cloud: cloud, recovery: recovery, isFixtureSession: true)
        await session.start(store: store)

        await session.uploadLatestPlannerData(from: store)
        await session.retryPlannerSync(store: store)
        await session.chooseLocalSyncConflict(store: store)
        await session.chooseCloudSyncConflict(store: store)
        await session.resetPlannerData(store: store)

        XCTAssertEqual(session.state, .ready(user))
        XCTAssertEqual(session.syncStatus, .fixture)
        XCTAssertEqual(session.errorMessage, PlannerSyncRecoveryError.fixtureCloudSyncDisabled.localizedDescription)
        XCTAssertEqual(store.activePlannerAccount?.name, "Local planner")
        XCTAssertEqual(cloud.readCount, 0)
        XCTAssertEqual(cloud.resetCount, 0)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
        let recoveryAccesses = await recovery.numberOfAccesses()
        XCTAssertEqual(recoveryAccesses, 0)
    }

    func testFixtureSessionPreservesEmailVerificationGate() async throws {
        let (store, accounts) = try await makeStore(load: false)
        await accounts.setLoadFailure(true)
        let unverified = AuthUser(uid: "unverified-fixture-user", email: "fixture@example.invalid", phoneNumber: nil,
            isEmailVerified: false, providerIDs: ["password"])
        let cloud = SessionSyncCloudDouble(record: .missing)
        let recovery = SessionSyncRecoveryDouble(owner: nil)
        let session = FirebaseAuthSession(authService: SessionSyncAuthDouble(user: unverified), cloudSyncService: cloud,
            syncRecoveryRepository: recovery, isFixtureSession: true)

        await session.start(store: store)

        XCTAssertEqual(session.state, .emailVerificationRequired(unverified))
        XCTAssertNil(store.loadError, "Verification must still run before any planner load")
        XCTAssertEqual(cloud.readCount, 0)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
        let recoveryAccesses = await recovery.numberOfAccesses()
        XCTAssertEqual(recoveryAccesses, 0)
    }

    func testFixtureLoadFailureStaysGatedWithoutCloudOrRecoveryAccess() async throws {
        let (store, accounts) = try await makeStore(load: false)
        await accounts.setLoadFailure(true)
        let cloud = SessionSyncCloudDouble(record: .missing)
        let recovery = SessionSyncRecoveryDouble(owner: nil)
        let session = makeSession(cloud: cloud, recovery: recovery, isFixtureSession: true)

        await session.start(store: store)

        guard case .failed = session.state else { return XCTFail("An unreadable fixture must not become ready") }
        XCTAssertNotNil(store.loadError)
        XCTAssertEqual(cloud.readCount, 0)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
        let recoveryAccesses = await recovery.numberOfAccesses()
        XCTAssertEqual(recoveryAccesses, 0)
    }

    func testSameOwnerCanKeepEditingLocallyWhileCloudIsOffline() async throws {
        let (store, accounts) = try await makeStore()
        let cloud = SessionSyncCloudDouble(record: .missing)
        cloud.failReads = true
        let recovery = SessionSyncRecoveryDouble(owner: user.uid)
        let session = makeSession(cloud: cloud, recovery: recovery)

        await session.start(store: store)

        XCTAssertEqual(session.state, .ready(user))
        guard case .failed = session.syncStatus else { return XCTFail("Offline sync must remain visibly failed") }
        try await store.renamePlannerAccount(id: "local-account", name: "Edited offline")
        let saved = try await accounts.loadAccountCollection()
        XCTAssertEqual(saved?.activeAccount?.name, "Edited offline")
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
    }

    func testUnknownLocalOwnerCannotReachReadyWhileCloudIsOffline() async throws {
        try await assertOfflineOwnerIsGated(nil)
    }

    func testAnotherAccountsLocalDataCannotReachReadyWhileCloudIsOffline() async throws {
        try await assertOfflineOwnerIsGated("another-account")
    }

    func testFailedLocalSaveStopsBeforeCloudReadOrUpload() async throws {
        let (store, accounts) = try await makeStore()
        let local = store.accountCollectionForCloudUpload()
        let cloud = SessionSyncCloudDouble(record: try .collection(local))
        let recovery = SessionSyncRecoveryDouble(owner: user.uid)
        try await recovery.saveCheckpoint(PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: cloud.record.revision,
            acknowledgedLocalFingerprint: PlannerCloudFingerprint.collection(local)))
        let session = makeSession(cloud: cloud, recovery: recovery)
        await session.start(store: store)
        XCTAssertEqual(session.state, .ready(user))
        let readCount = cloud.readCount

        await accounts.setSaveFailure(true)
        do {
            try await store.renamePlannerAccount(id: "local-account", name: "Unsaved edit")
            XCTFail("The fake local write must fail")
        } catch SessionSyncDoubleError.saveFailed {}
        await session.uploadLatestPlannerData(from: store)

        XCTAssertEqual(store.saveState, .failed)
        XCTAssertEqual(store.activePlannerAccount?.name, "Unsaved edit")
        let saved = try await accounts.loadAccountCollection()
        XCTAssertEqual(saved?.activeAccount?.name, "Local planner")
        XCTAssertEqual(cloud.readCount, readCount, "An undurable revision must not begin network sync")
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
        guard case .failed = session.syncStatus else { return XCTFail("The save failure must be visible") }
        XCTAssertEqual(session.cloudStatus, "Sync failed", "Do not claim the unsaved edit is durable")
    }

    func testSignOutFencesDelayedCloudReadBeforeLocalReplacement() async throws {
        let (store, accounts) = try await makeStore()
        let local = store.accountCollectionForCloudUpload()
        let baseline = try PlannerCloudRead.collection(local)
        var remote = local
        remote.accounts[0].name = "Remote planner"
        let cloud = SessionSyncCloudDouble(record: try .collection(remote))
        let entered = expectation(description: "Cloud read is awaiting a response")
        cloud.pauseNextRead = true
        cloud.readEntered = entered
        let recovery = SessionSyncRecoveryDouble(owner: user.uid)
        try await recovery.saveCheckpoint(PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: baseline.revision,
            acknowledgedLocalFingerprint: PlannerCloudFingerprint.collection(local)))
        let auth = SessionSyncAuthDouble(user: user)
        let session = FirebaseAuthSession(authService: auth, cloudSyncService: cloud, syncRecoveryRepository: recovery,
            isFixtureSession: false)
        let opening = Task { await session.start(store: store) }
        let readWait = await XCTWaiter.fulfillment(of: [entered], timeout: 2)
        guard readWait == .completed else {
            cloud.resumeRead()
            await opening.value
            return XCTFail("The session never reached its cloud read")
        }

        let signOutStarted = expectation(description: "Sign out started")
        let observation = session.$isWorking.dropFirst().filter { $0 }.prefix(1).sink { _ in signOutStarted.fulfill() }
        defer { observation.cancel() }
        let signingOut = Task { await session.signOut() }
        let signOutWait = await XCTWaiter.fulfillment(of: [signOutStarted], timeout: 2)
        cloud.resumeRead()
        await signingOut.value
        await opening.value

        XCTAssertEqual(signOutWait, .completed)
        XCTAssertEqual(auth.signOutCount, 1)
        XCTAssertEqual(session.state, .signedOut)
        XCTAssertEqual(store.activePlannerAccount?.name, "Local planner")
        let saved = try await accounts.loadAccountCollection()
        XCTAssertEqual(saved?.activeAccount?.name, "Local planner")
        let checkpoint = try await recovery.loadCheckpoint(userID: user.uid)
        XCTAssertEqual(checkpoint?.baselineRevision, baseline.revision)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
    }

    func testSignOutSupersedesStartupWaitingForAnEarlierSync() async throws {
        let (store, cloud, auth, session) = try await makeReadySession()
        let earlierSync = await startPausedSync(session: session, store: store, cloud: cloud)
        let startupWaiting = expectation(description: "Startup is waiting to suspend the earlier sync")
        let startupObservation = session.$cloudStatus.dropFirst().filter { $0 == "Checking cloud" }.prefix(1)
            .sink { _ in startupWaiting.fulfill() }
        defer { startupObservation.cancel() }
        let startup = Task { await session.start(store: store) }
        let startupWait = await XCTWaiter.fulfillment(of: [startupWaiting], timeout: 2)
        XCTAssertEqual(startupWait, .completed)

        let signOutStarted = expectation(description: "Newer sign out has started")
        let signOutObservation = session.$isWorking.dropFirst().filter { $0 }.prefix(1)
            .sink { _ in signOutStarted.fulfill() }
        defer { signOutObservation.cancel() }
        let signingOut = Task { await session.signOut() }
        let signOutWait = await XCTWaiter.fulfillment(of: [signOutStarted], timeout: 2)
        cloud.resumeRead()
        await earlierSync.value
        await startup.value
        await signingOut.value

        XCTAssertEqual(signOutWait, .completed)
        XCTAssertEqual(session.state, .signedOut)
        XCTAssertEqual(auth.signOutCount, 1)
        XCTAssertEqual(cloud.readCount, 2, "The superseded startup must not activate another sync stream")
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
    }

    func testSignOutSupersedesResetWaitingForAnEarlierSync() async throws {
        let (store, cloud, auth, session) = try await makeReadySession()
        let earlierSync = await startPausedSync(session: session, store: store, cloud: cloud)
        let resetWaiting = expectation(description: "Reset is waiting to suspend the earlier sync")
        let resetObservation = session.$cloudStatus.dropFirst().filter { $0 == "Resetting data" }.prefix(1)
            .sink { _ in resetWaiting.fulfill() }
        defer { resetObservation.cancel() }
        let resetting = Task { await session.resetPlannerData(store: store) }
        let resetWait = await XCTWaiter.fulfillment(of: [resetWaiting], timeout: 2)
        XCTAssertEqual(resetWait, .completed)

        let signOutStarted = expectation(description: "Newer sign out has started")
        let signOutObservation = session.$isWorking.dropFirst().filter { $0 }.prefix(1)
            .sink { _ in signOutStarted.fulfill() }
        defer { signOutObservation.cancel() }
        let signingOut = Task { await session.signOut() }
        let signOutWait = await XCTWaiter.fulfillment(of: [signOutStarted], timeout: 2)
        cloud.resumeRead()
        await earlierSync.value
        await resetting.value
        await signingOut.value

        XCTAssertEqual(signOutWait, .completed)
        XCTAssertEqual(session.state, .signedOut)
        XCTAssertEqual(auth.signOutCount, 1)
        XCTAssertEqual(cloud.resetCount, 0, "A superseded reset must not issue a destructive cloud request")
        XCTAssertEqual(cloud.readCount, 2)
    }

    func testNewerResetKeepsItsSyncGateWhenAnEarlierStartupFinishes() async throws {
        let (store, cloud, _, session) = try await makeReadySession()
        let earlierSync = await startPausedSync(session: session, store: store, cloud: cloud)
        let startupWaiting = expectation(description: "Startup is waiting to suspend the earlier sync")
        let startupObservation = session.$cloudStatus.dropFirst().filter { $0 == "Checking cloud" }.prefix(1)
            .sink { _ in startupWaiting.fulfill() }
        defer { startupObservation.cancel() }
        let startup = Task { await session.start(store: store) }
        let startupWait = await XCTWaiter.fulfillment(of: [startupWaiting], timeout: 2)
        XCTAssertEqual(startupWait, .completed)

        let resetWaiting = expectation(description: "Newer reset has started")
        let resetEntered = expectation(description: "Newer reset is awaiting its cloud response")
        let resetObservation = session.$cloudStatus.dropFirst().filter { $0 == "Resetting data" }.prefix(1)
            .sink { _ in resetWaiting.fulfill() }
        defer { resetObservation.cancel() }
        cloud.pauseReset = true
        cloud.resetEntered = resetEntered
        let resetting = Task { await session.resetPlannerData(store: store) }
        let resetWait = await XCTWaiter.fulfillment(of: [resetWaiting], timeout: 2)
        cloud.resumeRead()
        await earlierSync.value
        await startup.value
        let enteredWait = await XCTWaiter.fulfillment(of: [resetEntered], timeout: 2)

        let requestDeferred = expectation(description: "Upload is deferred while the newest reset is active")
        let additionalRequest = Task {
            await session.uploadLatestPlannerData(from: store)
            requestDeferred.fulfill()
        }
        let deferredWait = await XCTWaiter.fulfillment(of: [requestDeferred], timeout: 2)
        cloud.resumeReset()
        await resetting.value
        await additionalRequest.value

        XCTAssertEqual(resetWait, .completed)
        XCTAssertEqual(enteredWait, .completed)
        XCTAssertEqual(deferredWait, .completed, "Stale completion must not unlock the newer reset's sync gate")
        XCTAssertEqual(cloud.resetCount, 1)
        XCTAssertEqual(cloud.readCount, 2, "No stale startup or additional upload may create another sync stream")
    }

    private func makeReadySession() async throws -> (PlannerStore, SessionSyncCloudDouble, SessionSyncAuthDouble, FirebaseAuthSession) {
        let (store, _) = try await makeStore()
        let local = store.accountCollectionForCloudUpload()
        let cloud = SessionSyncCloudDouble(record: try .collection(local))
        let checkpoint = PlannerSyncCheckpoint(ownerUID: user.uid, baselineRevision: cloud.record.revision,
            acknowledgedLocalFingerprint: try PlannerCloudFingerprint.collection(local))
        let recovery = SessionSyncRecoveryDouble(owner: user.uid, checkpoint: checkpoint)
        let auth = SessionSyncAuthDouble(user: user)
        let session = FirebaseAuthSession(authService: auth, cloudSyncService: cloud, syncRecoveryRepository: recovery,
            isFixtureSession: false)
        await session.start(store: store)
        XCTAssertEqual(session.state, .ready(user))
        XCTAssertEqual(cloud.readCount, 1)
        return (store, cloud, auth, session)
    }

    private func startPausedSync(session: FirebaseAuthSession, store: PlannerStore, cloud: SessionSyncCloudDouble) async -> Task<Void, Never> {
        let entered = expectation(description: "Earlier sync is awaiting a cloud response")
        cloud.pauseNextRead = true
        cloud.readEntered = entered
        let task = Task { await session.uploadLatestPlannerData(from: store) }
        let readWait = await XCTWaiter.fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(readWait, .completed)
        if readWait != .completed { cloud.resumeRead() }
        return task
    }

    private func assertOfflineOwnerIsGated(_ owner: String?) async throws {
        let (store, accounts) = try await makeStore()
        let cloud = SessionSyncCloudDouble(record: .missing)
        cloud.failReads = true
        let recovery = SessionSyncRecoveryDouble(owner: owner)
        let session = makeSession(cloud: cloud, recovery: recovery)

        await session.start(store: store)

        guard case .failed = session.state else { return XCTFail("Unverified ownership must keep local data behind the gate") }
        XCTAssertNil(session.syncConflict, "A failed read must not invent a missing-cloud conflict")
        XCTAssertEqual(store.activePlannerAccount?.name, "Local planner")
        let saved = try await accounts.loadAccountCollection()
        XCTAssertEqual(saved?.activeAccount?.name, "Local planner")
        let ownerAfterFailure = try await recovery.localOwnerID()
        XCTAssertEqual(ownerAfterFailure, owner)
        XCTAssertTrue(cloud.writeAttempts.isEmpty)
    }

    private func makeStore(load: Bool = true) async throws -> (PlannerStore, SessionSyncAccountRepository) {
        let account = PlannerAccount(id: "local-account", name: "Local planner", color: "#F97316",
            snapshot: DefaultData.emptySnapshot, createdAt: "2026-01-01T00:00:00Z", updatedAt: "2026-01-01T00:00:00Z")
        let collection = PlannerAccountCollection(activeAccountId: account.id,
            selectedThemePresetId: AppTheme.selectedPreset.rawValue, accounts: [account], updatedAt: account.updatedAt)
        let accounts = SessionSyncAccountRepository(collection: collection)
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: DefaultData.emptySnapshot), accountRepository: accounts)
        if load {
            await store.load()
            XCTAssertNil(store.loadError)
            try await store.saveCurrentSnapshot()
        }
        return (store, accounts)
    }

    private func makeSession(cloud: SessionSyncCloudDouble, recovery: SessionSyncRecoveryDouble,
                             isFixtureSession: Bool = false) -> FirebaseAuthSession {
        FirebaseAuthSession(authService: SessionSyncAuthDouble(user: user), cloudSyncService: cloud,
            syncRecoveryRepository: recovery, isFixtureSession: isFixtureSession)
    }
}

private enum SessionSyncDoubleError: Error { case offline, saveFailed, loadFailed, unexpectedAuthPath }

private actor SessionSyncAccountRepository: PlannerAccountRepository {
    private var collection: PlannerAccountCollection
    private var failSaves = false
    private var failLoads = false

    init(collection: PlannerAccountCollection) { self.collection = collection }
    func hasPersistedAccountCollection() async -> Bool { true }
    func loadAccountCollection() async throws -> PlannerAccountCollection? {
        if failLoads { throw SessionSyncDoubleError.loadFailed }
        return collection
    }
    func saveAccountCollection(_ collection: PlannerAccountCollection) async throws {
        if failSaves { throw SessionSyncDoubleError.saveFailed }
        self.collection = collection
    }
    func resetAccountCollection() async throws { throw SessionSyncDoubleError.unexpectedAuthPath }
    func setSaveFailure(_ value: Bool) { failSaves = value }
    func setLoadFailure(_ value: Bool) { failLoads = value }
}

private actor SessionSyncRecoveryDouble: PlannerSyncRecoveryRepository {
    private var owner: String?
    private var checkpoints: [String: PlannerSyncCheckpoint] = [:]
    private var conflicts: [String: PlannerSyncConflict] = [:]
    private var accessCount = 0

    init(owner: String?, checkpoint: PlannerSyncCheckpoint? = nil) {
        self.owner = owner
        if let checkpoint { checkpoints[checkpoint.ownerUID] = checkpoint }
    }
    func numberOfAccesses() -> Int { accessCount }
    func loadCheckpoint(userID: String) async throws -> PlannerSyncCheckpoint? {
        accessCount += 1
        return checkpoints[userID]
    }
    func saveCheckpoint(_ checkpoint: PlannerSyncCheckpoint) async throws {
        accessCount += 1
        checkpoints[checkpoint.ownerUID] = checkpoint
    }
    func localOwnerID() async throws -> String? {
        accessCount += 1
        return owner
    }
    func setLocalOwnerID(_ userID: String) async throws {
        accessCount += 1
        owner = userID
    }
    func archive(_ conflict: PlannerSyncConflict) async throws {
        accessCount += 1
        conflicts[conflict.id] = conflict
    }
    func conflict(id: String, userID: String) async throws -> PlannerSyncConflict? {
        accessCount += 1
        guard conflicts[id]?.ownerUID == userID else { return nil }
        return conflicts[id]
    }
}

@MainActor
private final class SessionSyncCloudDouble: CloudSyncService {
    let record: PlannerCloudRead
    var failReads = false
    var pauseNextRead = false
    var readEntered: XCTestExpectation?
    var pauseReset = false
    var resetEntered: XCTestExpectation?
    private(set) var readCount = 0
    private(set) var resetCount = 0
    private(set) var writeAttempts: [PlannerPendingUpload] = []
    private var readContinuation: CheckedContinuation<Void, Never>?
    private var resetContinuation: CheckedContinuation<Void, Never>?

    init(record: PlannerCloudRead) { self.record = record }
    func readAuthoritative(for user: AuthUser) async throws -> PlannerCloudRead {
        readCount += 1
        if pauseNextRead {
            pauseNextRead = false
            await withCheckedContinuation { continuation in
                readContinuation = continuation
                readEntered?.fulfill()
            }
        }
        if failReads { throw SessionSyncDoubleError.offline }
        return record
    }
    func compareAndSet(_ pending: PlannerPendingUpload, for user: AuthUser) async throws -> PlannerCloudWriteResult {
        writeAttempts.append(pending)
        return .conflict(record)
    }
    func pullAccountCollection(for user: AuthUser) async throws -> CloudPlannerAccountCollectionRecord? {
        throw SessionSyncDoubleError.unexpectedAuthPath
    }
    func pushAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        XCTFail("Session sync must never use the legacy unconditional write")
    }
    func resetAccountCollection(_ collection: PlannerAccountCollection, for user: AuthUser) async throws {
        resetCount += 1
        if pauseReset {
            await withCheckedContinuation { continuation in
                resetContinuation = continuation
                resetEntered?.fulfill()
            }
        }
        throw SessionSyncDoubleError.unexpectedAuthPath
    }
    func resumeRead() {
        readContinuation?.resume()
        readContinuation = nil
    }
    func resumeReset() {
        pauseReset = false
        resetContinuation?.resume()
        resetContinuation = nil
    }
}

@MainActor
private final class SessionSyncAuthDouble: AuthService {
    let isConfigured = true
    private var user: AuthUser?
    private(set) var signOutCount = 0

    init(user: AuthUser) { self.user = user }
    func currentUser() async -> AuthUser? { user }
    func refreshCurrentUser() async throws -> AuthUser? { user }
    func signOut() async throws { signOutCount += 1; user = nil }
    func signInWithEmail(email: String, password: String) async throws -> AuthUser { throw SessionSyncDoubleError.unexpectedAuthPath }
    func createEmailAccount(email: String, password: String) async throws -> AuthUser { throw SessionSyncDoubleError.unexpectedAuthPath }
    func sendEmailVerification() async throws { throw SessionSyncDoubleError.unexpectedAuthPath }
    func startPhoneSignIn(phoneNumber: String) async throws -> String { throw SessionSyncDoubleError.unexpectedAuthPath }
    func confirmPhoneCode(verificationID: String, code: String) async throws -> AuthUser { throw SessionSyncDoubleError.unexpectedAuthPath }
    func signInWithGoogle() async throws -> AuthUser { throw SessionSyncDoubleError.unexpectedAuthPath }
    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async throws -> AuthUser { throw SessionSyncDoubleError.unexpectedAuthPath }
    func idToken(forceRefresh: Bool) async throws -> String { throw SessionSyncDoubleError.unexpectedAuthPath }
    func deleteAccount(idToken: String) async throws { throw SessionSyncDoubleError.unexpectedAuthPath }
}
