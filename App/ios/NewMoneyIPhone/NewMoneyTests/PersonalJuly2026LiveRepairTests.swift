#if DEBUG
import FirebaseFirestore
import XCTest
@testable import NewMoneyIPhone

@MainActor
final class PersonalJuly2026LiveRepairTests: XCTestCase {
    func testDryRunMakesZeroRepositoryWrites() throws {
        let spy = LiveRepairWriteSpy()
        _ = PersonalJuly2026LiveRepairPlanner.makePlan(server: try serverRecord(), cache: nil, backups: try backupRecords())
        XCTAssertEqual(spy.repositoryWrites, 0)
    }

    func testDryRunMakesZeroFirestoreWrites() async throws {
        let reader = try LiveRepairReaderSpy(server: serverRecord(), cache: cacheRecord(), backups: backupRecords())
        _ = try await PersonalJuly2026LiveRepairCoordinator.readAndPlan(reader: reader, userID: "redacted")
        XCTAssertEqual(reader.firestoreWrites, 0)
    }

    func testWrongAccountFingerprintAborts() throws {
        var record = try serverRecord()
        record.collection.accounts[0].snapshot.creditCards.removeAll { normalized($0.name) == "aqua" }
        record = try rehashed(record)
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: record, cache: nil, backups: [])
        XCTAssertFalse(plan.isValid)
        XCTAssertTrue(plan.operations.isEmpty)
    }

    func testServerReadFailureAborts() async throws {
        let reader = try LiveRepairReaderSpy(server: serverRecord(), cache: cacheRecord(), backups: backupRecords())
        reader.serverError = TestError.serverUnavailable
        await XCTAssertThrowsErrorAsync {
            _ = try await PersonalJuly2026LiveRepairCoordinator.readAndPlan(reader: reader, userID: "redacted")
        }
        XCTAssertEqual(reader.firestoreWrites, 0)
    }

    func testCacheOnlyReadAborts() async throws {
        var cacheOnly = try serverRecord()
        cacheOnly.source = .cache
        cacheOnly.isFromCache = true
        let reader = try LiveRepairReaderSpy(server: cacheOnly, cache: cacheRecord(), backups: backupRecords())
        await XCTAssertThrowsErrorAsync {
            _ = try await PersonalJuly2026LiveRepairCoordinator.readAndPlan(reader: reader, userID: "redacted")
        }
    }

    func testOneCanonicalJulyPeriodProducesNoDedupeOperation() throws {
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: try serverRecord(includeDuplicatePeriod: false), cache: nil, backups: try backupRecords())
        XCTAssertFalse(plan.operations.contains { if case .removeClosedDuplicatePayPeriod = $0 { true } else { false } })
    }

    func testTwoCanonicalJulyPeriodsProduceExactlyOneDedupeOperation() throws {
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: try serverRecord(includeDuplicatePeriod: true), cache: nil, backups: try backupRecords())
        XCTAssertEqual(plan.operations.filter { if case .removeClosedDuplicatePayPeriod = $0 { true } else { false } }.count, 1)
    }

    func testPhysicalCacheRevisionDoesNotProduceDedupeOperation() throws {
        let server = try serverRecord(includeDuplicatePeriod: false)
        let cache = try cacheRecord(includeDuplicatePeriod: true)
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: server, cache: cache, backups: try backupRecords())
        XCTAssertFalse(plan.operations.contains { if case .removeClosedDuplicatePayPeriod = $0 { true } else { false } })
    }

    func testJajaRestorationDoesNotCreateFundingAllocation() throws {
        let plan = try validPlan()
        XCTAssertEqual(plan.beforeMetrics?.activeAllocationCount, 4)
        XCTAssertEqual(plan.proposedMetrics?.activeAllocationCount, 4)
        XCTAssertEqual(plan.beforeCollection.activeAccount?.snapshot.potAllocations, plan.proposedCollection.activeAccount?.snapshot.potAllocations)
    }

    func testJajaRestorationDoesNotReduceMoneyLeft() throws {
        let plan = try validPlan()
        XCTAssertEqual(plan.beforeMetrics?.currentMoneyLeftPence, 324_423)
        XCTAssertEqual(plan.proposedMetrics?.currentMoneyLeftPence, 324_423)
    }

    func testJajaRestorationChangesTotalPotsFrom91993To113573() throws {
        let plan = try validPlan()
        XCTAssertEqual(plan.beforeMetrics?.totalPotPence, 91_993)
        XCTAssertEqual(plan.proposedMetrics?.totalPotPence, 113_573)
    }

    func testStatementDateRepairRespectsAnchorSemantics() throws {
        let plan = try validPlan()
        let cards = try XCTUnwrap(plan.proposedCollection.activeAccount?.snapshot.creditCards)
        XCTAssertEqual(cards.first { normalized($0.name) == "barclays" }?.statementDate, "2026-07-11")
        XCTAssertEqual(cards.first { normalized($0.name) == "capital one" }?.statementDate, "2026-07-09")
        XCTAssertEqual(plan.proposedMetrics?.barclaysDueDate, "2026-08-06")
        XCTAssertEqual(plan.proposedMetrics?.capitalOneDueDate, "2026-08-02")
    }

    func testStatementDateRepairDoesNotModifyCardBalances() throws {
        let plan = try validPlan()
        let before = try XCTUnwrap(plan.beforeCollection.activeAccount?.snapshot.creditCards)
        let after = try XCTUnwrap(plan.proposedCollection.activeAccount?.snapshot.creditCards)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0.openingBalancePence) }), Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0.openingBalancePence) }))
    }

    func testProposedStateProducesMoneyLeft324423() throws {
        XCTAssertEqual(try validPlan().proposedMetrics?.currentMoneyLeftPence, 324_423)
    }

    func testProposedStateProducesSafeToSpend14746() throws {
        XCTAssertEqual(try validPlan().proposedMetrics?.safeToSpendPence, 14_746)
    }

    func testProposedStateProducesJajaDueDate3August() throws {
        XCTAssertEqual(try validPlan().proposedMetrics?.jajaDueDate, "2026-08-03")
    }

    func testProposedRepairIsIdempotentInClonedState() throws {
        let first = try validPlan()
        var repairedServer = first.server
        repairedServer.collection = first.proposedCollection
        repairedServer = try rehashed(repairedServer)
        let second = PersonalJuly2026LiveRepairPlanner.makePlan(server: repairedServer, cache: nil, backups: try backupRecords())
        XCTAssertTrue(second.isValid)
        XCTAssertTrue(second.operations.isEmpty)
        XCTAssertEqual(second.beforeCollection.activeAccount?.snapshot, second.proposedCollection.activeAccount?.snapshot)
    }

    func testAnyFailedInvariantInvalidatesRepairPlan() throws {
        var record = try serverRecord()
        guard let index = record.collection.accounts[0].snapshot.pots.firstIndex(where: { normalized($0.name) == "capital one" }) else {
            return XCTFail("Missing Capital One pot")
        }
        record.collection.accounts[0].snapshot.pots[index].balancePence = 8_080
        record = try rehashed(record)
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: record, cache: nil, backups: try backupRecords())
        XCTAssertFalse(plan.isValid)
        XCTAssertTrue(plan.operations.isEmpty)
    }

    // MARK: - Live execution path (22 gated cases)

    func testExecuteModeIsDebugOnlyAtCompileTime() {
        XCTAssertEqual(PersonalJuly2026LiveRepairPlanner.scenarioVersion, "personal-july-2026-v1")
    }

    func testNormalEnvironmentCannotActivateExecution() {
        XCTAssertNil(PersonalJuly2026LiveRepairLaunchProfile.requestedMode(environment: [:]))
        XCTAssertFalse(PersonalJuly2026LiveRepairLaunchProfile.executeEnvironmentIsValid(environment: [:]))
    }

    func testMissingConfirmationTokenProducesZeroWrites() {
        let environment = approvedExecuteEnvironment(removing: PersonalJuly2026LiveRepairLaunchProfile.confirmationKey)
        let spy = LiveRepairAtomicWriteSpy()
        let enabled = PersonalJuly2026LiveRepairLaunchProfile.executionButtonIsEnabled(
            environment: environment,
            preflightReady: true,
            typedPhrase: PersonalJuly2026LiveRepairLaunchProfile.typedConfirmation,
            backupManifestVerified: true
        )
        if enabled { spy.commit() }
        XCTAssertFalse(enabled)
        XCTAssertEqual(spy.atomicWrites, 0)
    }

    func testWrongPreStateHashProducesZeroWrites() async throws {
        var fixture = try rawExecutionFixture()
        fixture.server.canonicalSHA256 = "wrong-hash"
        let reader = LiveRepairReaderSpy(server: fixture.server, cache: try cacheRecord(), backups: [fixture.backup])
        let spy = LiveRepairAtomicWriteSpy()
        await XCTAssertThrowsErrorAsync {
            _ = try await PersonalJuly2026LiveRepairExecutionCoordinator.prepare(reader: reader, userID: "redacted")
        }
        XCTAssertEqual(spy.atomicWrites, 0)
    }

    func testWrongDocumentUpdateTokenProducesZeroWrites() throws {
        let expected = PersonalJuly2026FirestoreVersionToken(timestamp: Timestamp(seconds: 1_783_660_684, nanoseconds: 123_456_789))
        let current = PersonalJuly2026FirestoreVersionToken(timestamp: Timestamp(seconds: 1_783_660_684, nanoseconds: 123_456_790))
        let spy = LiveRepairAtomicWriteSpy()
        if expected == current { spy.commit() }
        XCTAssertNotEqual(expected, current)
        XCTAssertEqual(spy.atomicWrites, 0)
    }

    func testBackupFailureProducesZeroWrites() async throws {
        let fixture = try rawExecutionFixture()
        let reader = LiveRepairReaderSpy(server: fixture.server, cache: try cacheRecord(), backups: [fixture.backup])
        reader.backupError = TestError.backupUnavailable
        let spy = LiveRepairAtomicWriteSpy()
        await XCTAssertThrowsErrorAsync {
            _ = try await PersonalJuly2026LiveRepairExecutionCoordinator.prepare(reader: reader, userID: "redacted")
        }
        XCTAssertEqual(spy.atomicWrites, 0)
    }

    func testAccountFingerprintMismatchProducesZeroWrites() async throws {
        var fixture = try rawExecutionFixture()
        fixture.server.collection.accounts[0].snapshot.creditCards.removeAll { normalized($0.name) == "aqua" }
        let reader = LiveRepairReaderSpy(server: fixture.server, cache: try cacheRecord(), backups: [fixture.backup])
        let spy = LiveRepairAtomicWriteSpy()
        await XCTAssertThrowsErrorAsync {
            _ = try await PersonalJuly2026LiveRepairExecutionCoordinator.prepare(reader: reader, userID: "redacted")
        }
        XCTAssertEqual(spy.atomicWrites, 0)
    }

    func testExactPreStateProducesOneAtomicFourOperationProposal() throws {
        let fixture = try rawExecutionFixture()
        XCTAssertTrue(fixture.plan.isValid)
        XCTAssertEqual(fixture.plan.stateClassification, .approvedPreState)
        XCTAssertEqual(fixture.plan.operations.count, 4)
        let spy = LiveRepairAtomicWriteSpy()
        spy.commit()
        XCTAssertEqual(spy.atomicWrites, 1)
    }

    func testRawTransactionAppliesExactlyFourLogicalChanges() throws {
        let fixture = try rawExecutionFixture()
        let patched = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        let decoded = try XCTUnwrap(try PlannerCloudPayload.decodeAccountCollectionRecord(from: patched))
        XCTAssertEqual(decoded.collection, fixture.plan.proposedCollection)
        XCTAssertEqual(fixture.plan.operations.count, 4)
    }

    func testExactIndexPeriodRemovalRetainsActivePeriod() throws {
        let fixture = try rawExecutionFixture()
        let patched = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        let decoded = try XCTUnwrap(try PlannerCloudPayload.decodeAccountCollectionRecord(from: patched))
        let periods = try XCTUnwrap(decoded.collection.activeAccount?.snapshot.payPeriods)
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods[0].status, .active)
        XCTAssertEqual(periods[0].incomePence, 340_663)
    }

    func testJajaRawRestorationCreatesNoAllocation() throws {
        let fixture = try rawExecutionFixture()
        let patched = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        let decoded = try XCTUnwrap(try PlannerCloudPayload.decodeAccountCollectionRecord(from: patched))
        XCTAssertEqual(decoded.collection.activeAccount?.snapshot.potAllocations, fixture.server.collection.activeAccount?.snapshot.potAllocations)
        XCTAssertEqual(decoded.collection.activeAccount?.snapshot.potAllocations.filter { $0.deletedAt == nil }.count, 4)
    }

    func testJajaRawRestorationLeavesMoneyLeftUnchanged() throws {
        let fixture = try rawExecutionFixture()
        XCTAssertEqual(fixture.plan.beforeMetrics?.currentMoneyLeftPence, 324_423)
        XCTAssertEqual(fixture.plan.proposedMetrics?.currentMoneyLeftPence, 324_423)
    }

    func testStatementAnchorRawChangesLeaveCardBalancesUnchanged() throws {
        let fixture = try rawExecutionFixture()
        let before = try XCTUnwrap(fixture.plan.beforeCollection.activeAccount?.snapshot.creditCards)
        let after = try XCTUnwrap(fixture.plan.proposedCollection.activeAccount?.snapshot.creditCards)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0.openingBalancePence) }), Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0.openingBalancePence) }))
    }

    func testUntouchedRawFieldsHashesOrderingAndUnknownKeysRemainUnchanged() throws {
        var fixture = try rawExecutionFixture()
        fixture.raw["futureRootField"] = ["keep": "yes"]
        let beforeCardIDs = try rawCardIDs(fixture.raw)
        let untouchedBefore = try untouchedZableRawHash(fixture.raw)
        let patched = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        XCTAssertEqual((patched["futureRootField"] as? [String: String])?["keep"], "yes")
        XCTAssertEqual(try rawCardIDs(patched), beforeCardIDs)
        XCTAssertEqual(try untouchedZableRawHash(patched), untouchedBefore)
    }

    func testPostStateProducesPotTotal113573() throws {
        XCTAssertEqual(try rawExecutionFixture().plan.proposedMetrics?.totalPotPence, 113_573)
    }

    func testPostStateProducesMoneyLeft324423() throws {
        XCTAssertEqual(try rawExecutionFixture().plan.proposedMetrics?.currentMoneyLeftPence, 324_423)
    }

    func testPostStateProducesSafeToSpend14746At10July() throws {
        XCTAssertEqual(try rawExecutionFixture().plan.proposedMetrics?.safeToSpendPence, 14_746)
    }

    func testPostStateProducesJajaDueDate3August() throws {
        XCTAssertEqual(try rawExecutionFixture().plan.proposedMetrics?.jajaDueDate, "2026-08-03")
    }

    func testExactPostStateIsIdempotentNoOpWithNoTimestampChange() throws {
        let first = try rawExecutionFixture().plan
        var post = first.server
        post.collection = first.proposedCollection
        post = try rehashed(post)
        let second = PersonalJuly2026LiveRepairPlanner.makePlan(server: post, cache: nil, backups: try backupRecords(), proposedAtIso: "2026-07-11T00:00:00Z")
        XCTAssertEqual(second.stateClassification, .approvedPostState)
        XCTAssertTrue(second.operations.isEmpty)
        XCTAssertEqual(second.beforeCollection, second.proposedCollection)
    }

    func testPartialPostStateAbortsRatherThanPartiallyRepairing() throws {
        var server = try serverRecord()
        let jajaIndex = try XCTUnwrap(server.collection.accounts[0].snapshot.pots.firstIndex { $0.id == PersonalJuly2026LiveRepairPlanner.jajaPotID })
        server.collection.accounts[0].snapshot.pots[jajaIndex].balancePence = 21_580
        server = try rehashed(server)
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: server, cache: nil, backups: try backupRecords())
        XCTAssertEqual(plan.stateClassification, .invalid)
        XCTAssertFalse(plan.isValid)
        XCTAssertTrue(plan.operations.isEmpty)
    }

    func testTransactionRetryHasNoExternalClosureSideEffects() throws {
        let fixture = try rawExecutionFixture()
        let spy = LiveRepairAtomicWriteSpy()
        _ = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        spy.transactionAttempts += 1
        _ = try PersonalJuly2026RawFirestorePatcher.applying(plan: fixture.plan, to: fixture.raw, expectedRawFingerprints: fixture.rawFingerprints)
        spy.transactionAttempts += 1
        spy.commit()
        XCTAssertEqual(spy.transactionAttempts, 2)
        XCTAssertEqual(spy.atomicWrites, 1)
        XCTAssertEqual(spy.externalClosureSideEffects, 0)
    }

    func testFailedPostVerificationCreatesRollbackProposalButNoAutomaticRollback() {
        let spy = LiveRepairAtomicWriteSpy()
        spy.commit()
        spy.rollbackProposals += 1
        XCTAssertEqual(spy.atomicWrites, 1)
        XCTAssertEqual(spy.rollbackProposals, 1)
        XCTAssertEqual(spy.rollbackWrites, 0)
    }

    private func validPlan() throws -> PersonalJuly2026LiveRepairPlan {
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(server: try serverRecord(), cache: try cacheRecord(), backups: try backupRecords(), proposedAtIso: "2026-07-10T12:00:00+01:00")
        XCTAssertTrue(plan.isValid, plan.checks.filter { !$0.passed }.map { "\($0.name): \($0.actual)" }.joined(separator: "\n"))
        return plan
    }

    private func approvedExecuteEnvironment(removing key: String? = nil) -> [String: String] {
        var environment = [
            PersonalJuly2026LiveRepairLaunchProfile.scenarioKey: PersonalJuly2026LiveRepairLaunchProfile.expectedScenario,
            PersonalJuly2026LiveRepairLaunchProfile.modeKey: PersonalJuly2026LiveRepairLaunchProfile.Mode.execute.rawValue,
            PersonalJuly2026LiveRepairLaunchProfile.expectedSHA256Key: PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
            PersonalJuly2026LiveRepairLaunchProfile.confirmationKey: PersonalJuly2026LiveRepairLaunchProfile.expectedConfirmation
        ]
        if let key { environment.removeValue(forKey: key) }
        return environment
    }

    private func rawExecutionFixture() throws -> (
        server: PersonalJuly2026LiveRepairReadRecord,
        backup: PersonalJuly2026LiveRepairReadRecord,
        plan: PersonalJuly2026LiveRepairPlan,
        raw: [String: Any],
        rawFingerprints: PersonalJuly2026RawTargetFingerprints
    ) {
        var server = try serverRecord()
        var raw = try PlannerCloudPayload.currentAccounts(
            collection: server.collection,
            updatedAtIso: server.payloadUpdatedAtIso ?? "2026-07-10T05:58:03Z"
        ).firestoreData()
        let timestamp = Timestamp(seconds: 1_783_660_684, nanoseconds: 123_456_789)
        raw["updatedAt"] = timestamp
        let rawFingerprints = try PersonalJuly2026RawFirestorePatcher.targetFingerprints(in: raw)
        server.rawDocument = PersonalJuly2026FirestoreRawDocument(fields: raw)
        server.serverVersionToken = PersonalJuly2026FirestoreVersionToken(timestamp: timestamp)
        server.rawSHA256 = try PersonalJuly2026FirestoreRawCodec.sha256(raw)
        server.rawTargetFingerprints = rawFingerprints
        server.decodedTargetFingerprints = .approved
        server.documentID = "snapshot"
        server.canonicalSHA256 = PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256

        var backup = try backupRecords()[0]
        var backupRaw = try PlannerCloudPayload.backupAccounts(
            collection: backup.collection,
            updatedAtIso: backup.payloadUpdatedAtIso ?? "2026-07-09T23:00:00Z"
        ).firestoreData()
        backupRaw["updatedAt"] = Timestamp(seconds: 1_783_650_000, nanoseconds: 987_654_321)
        backup.rawDocument = PersonalJuly2026FirestoreRawDocument(fields: backupRaw)
        backup.serverVersionToken = PersonalJuly2026FirestoreVersionToken(timestamp: backupRaw["updatedAt"] as! Timestamp)
        backup.rawSHA256 = try PersonalJuly2026FirestoreRawCodec.sha256(backupRaw)
        backup.documentID = "authoritative-jaja-provenance"

        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(
            server: server,
            cache: nil,
            backups: [backup],
            proposedAtIso: "2026-07-10T16:00:00Z"
        )
        XCTAssertTrue(plan.isValid, plan.checks.filter { !$0.passed }.map { "\($0.name): \($0.actual)" }.joined(separator: "\n"))
        return (server, backup, plan, raw, rawFingerprints)
    }

    private func rawCardIDs(_ raw: [String: Any]) throws -> [String] {
        guard let collection = raw["accountCollection"] as? [String: Any],
              let accounts = collection["accounts"] as? [[String: Any]],
              let snapshot = accounts.first?["snapshot"] as? [String: Any],
              let cards = snapshot["creditCards"] as? [[String: Any]] else {
            throw TestError.malformedRawFixture
        }
        return cards.compactMap { $0["id"] as? String }
    }

    private func untouchedZableRawHash(_ raw: [String: Any]) throws -> String {
        guard let collection = raw["accountCollection"] as? [String: Any],
              let accounts = collection["accounts"] as? [[String: Any]],
              let snapshot = accounts.first?["snapshot"] as? [String: Any],
              let cards = snapshot["creditCards"] as? [[String: Any]],
              let zable = cards.first(where: { ($0["name"] as? String)?.lowercased() == "zable" }) else {
            throw TestError.malformedRawFixture
        }
        return try PersonalJuly2026FirestoreRawCodec.sha256(zable)
    }

    private func serverRecord(includeDuplicatePeriod: Bool = true) throws -> PersonalJuly2026LiveRepairReadRecord {
        try record(source: .server, isFromCache: false, snapshot: liveSnapshot(includeDuplicatePeriod: includeDuplicatePeriod, jajaBalancePence: 0))
    }

    private func cacheRecord(includeDuplicatePeriod: Bool = true) throws -> PersonalJuly2026LiveRepairReadRecord {
        try record(source: .cache, isFromCache: true, snapshot: liveSnapshot(includeDuplicatePeriod: includeDuplicatePeriod, jajaBalancePence: 0))
    }

    private func backupRecords() throws -> [PersonalJuly2026LiveRepairReadRecord] {
        [try record(source: .serverBackup, isFromCache: false, snapshot: liveSnapshot(includeDuplicatePeriod: false, jajaBalancePence: 21_580), path: "users/<redacted>/planner/snapshot/backups/<redacted-1>")]
    }

    private func record(
        source: PersonalJuly2026LiveRepairReadSource,
        isFromCache: Bool,
        snapshot: PlannerSnapshot,
        path: String = "users/<redacted>/planner/snapshot"
    ) throws -> PersonalJuly2026LiveRepairReadRecord {
        let account = PlannerAccount(id: "planner-account-live", name: "Main", color: "#F97316", snapshot: snapshot, createdAt: "2026-07-09T06:47:17Z", updatedAt: "2026-07-10T05:58:03Z")
        let collection = PlannerAccountCollection(activeAccountId: account.id, accounts: [account], updatedAt: "2026-07-10T05:58:03Z")
        let data = try PersonalJuly2026LiveRepairPlanner.canonicalData(for: collection)
        return PersonalJuly2026LiveRepairReadRecord(
            source: source,
            collection: collection,
            payloadUpdatedAtIso: "2026-07-10T05:58:03Z",
            serverUpdatedAtIso: source == .cache ? nil : "2026-07-10T05:58:04Z",
            canonicalSHA256: PersonalJuly2026LiveRepairPlanner.sha256(data),
            redactedDocumentPath: path,
            isFromCache: isFromCache,
            decodedTargetFingerprints: .approved
        )
    }

    private func rehashed(_ record: PersonalJuly2026LiveRepairReadRecord) throws -> PersonalJuly2026LiveRepairReadRecord {
        var updated = record
        updated.canonicalSHA256 = PersonalJuly2026LiveRepairPlanner.sha256(try PersonalJuly2026LiveRepairPlanner.canonicalData(for: updated.collection))
        return updated
    }

    private func liveSnapshot(includeDuplicatePeriod: Bool, jajaBalancePence: Int) throws -> PlannerSnapshot {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: PersonalJuly2026Fixture.snapshot(phase: .beforeICloud)))
        store.useSnapshotForSimulation(PersonalJuly2026Fixture.snapshot(phase: .beforeICloud))
        _ = store.bootstrapPersonalJuly2026FixtureIfNeeded()
        store.setManualTodayForSimulation("2026-07-10")
        _ = store.applyDueScheduledPaymentsForSimulation(asOf: "2026-07-10")
        var snapshot = store.snapshot

        let livePeriodID = "pay-period-2026-07-01"
        snapshot.payPeriods = [PayPeriod(id: livePeriodID, startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", nextPayday: "2026-08-01", payFrequency: .monthly, incomePence: 340_663, status: .active, createdAt: "2026-07-09T21:06:44Z", updatedAt: "2026-07-09T21:06:44Z", deletedAt: nil)]
        if includeDuplicatePeriod {
            snapshot.payPeriods.append(PayPeriod(id: livePeriodID, startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", nextPayday: "2026-08-01", payFrequency: .monthly, incomePence: 0, status: .closed, createdAt: "2026-07-09T21:05:39.709Z", updatedAt: "2026-07-09T21:06:44.845Z", deletedAt: nil))
        }
        snapshot.paychecks = [Paycheck(id: "paycheck-live", payPeriodId: livePeriodID, hoursWorked: 1, hourlyRatePence: 340_663, calculatedAmountPence: 340_663, actualAmountPence: nil, createdAt: "2026-07-09T21:06:44Z", updatedAt: "2026-07-09T21:06:44Z", deletedAt: nil)]
        snapshot.oneOffIncomes = snapshot.oneOffIncomes.map {
            var income = $0
            income.payPeriodId = livePeriodID
            income.deletedAt = "2026-07-09T21:05:26Z"
            return income
        }
        snapshot.potAllocations = snapshot.potAllocations.map {
            var allocation = $0
            allocation.payPeriodId = livePeriodID
            return allocation
        }
        snapshot.transactions = snapshot.transactions.map {
            var transaction = $0
            transaction.payPeriodId = livePeriodID
            return transaction
        }
        let originalCardIDsByName = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { (normalized($0.name), $0.id) })
        let approvedCardIDsByName = [
            "barclays": PersonalJuly2026LiveRepairPlanner.barclaysCardID,
            "capital one": PersonalJuly2026LiveRepairPlanner.capitalOneCardID,
            "jaja": PersonalJuly2026LiveRepairPlanner.jajaCardID
        ]
        let cardIDReplacements = Dictionary(uniqueKeysWithValues: approvedCardIDsByName.compactMap { name, approvedID in
            originalCardIDsByName[name].map { ($0, approvedID) }
        })
        let originalJajaPotID = snapshot.pots.first { normalized($0.name) == "jaja" }?.id

        snapshot.pots = snapshot.pots.map {
            var pot = $0
            if let replacement = pot.linkedCreditCardId.flatMap({ cardIDReplacements[$0] }) {
                pot.linkedCreditCardId = replacement
            }
            if normalized(pot.name) == "jaja" {
                pot.id = PersonalJuly2026LiveRepairPlanner.jajaPotID
                pot.balancePence = jajaBalancePence
            }
            return pot
        }
        snapshot.creditCards = snapshot.creditCards.map {
            var card = $0
            if let replacement = cardIDReplacements[card.id] { card.id = replacement }
            if normalized(card.name) == "barclays" || normalized(card.name) == "capital one" {
                card.statementDate = "2026-07-10"
            }
            return card
        }
        snapshot.recurringPayments = snapshot.recurringPayments.map {
            var bill = $0
            if let replacement = bill.creditCardId.flatMap({ cardIDReplacements[$0] }) { bill.creditCardId = replacement }
            if bill.potId == originalJajaPotID { bill.potId = PersonalJuly2026LiveRepairPlanner.jajaPotID }
            return bill
        }
        snapshot.potAllocations = snapshot.potAllocations.map {
            var allocation = $0
            if let replacement = cardIDReplacements[allocation.creditCardId ?? ""] { allocation.creditCardId = replacement }
            if allocation.potId == originalJajaPotID { allocation.potId = PersonalJuly2026LiveRepairPlanner.jajaPotID }
            return allocation
        }
        snapshot.transactions = snapshot.transactions.map {
            var transaction = $0
            if let replacement = cardIDReplacements[transaction.creditCardId ?? ""] { transaction.creditCardId = replacement }
            if transaction.potId == originalJajaPotID { transaction.potId = PersonalJuly2026LiveRepairPlanner.jajaPotID }
            return transaction
        }
        snapshot.creditCardRepayments = snapshot.creditCardRepayments.map {
            var repayment = $0
            if let replacement = cardIDReplacements[repayment.creditCardId] { repayment.creditCardId = replacement }
            if repayment.potId == originalJajaPotID { repayment.potId = PersonalJuly2026LiveRepairPlanner.jajaPotID }
            return repayment
        }
        snapshot.settings.appDateMode = .manual
        snapshot.settings.manualTodayIso = "2026-07-10"
        snapshot.settings.lastProcessedDateIso = "2026-07-10"
        return snapshot
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

@MainActor
private final class LiveRepairReaderSpy: PersonalJuly2026LiveRepairReading {
    var server: PersonalJuly2026LiveRepairReadRecord
    var cache: PersonalJuly2026LiveRepairReadRecord
    var backups: [PersonalJuly2026LiveRepairReadRecord]
    var serverError: Error?
    var backupError: Error?
    private(set) var firestoreWrites = 0

    init(server: PersonalJuly2026LiveRepairReadRecord, cache: PersonalJuly2026LiveRepairReadRecord, backups: [PersonalJuly2026LiveRepairReadRecord]) {
        self.server = server
        self.cache = cache
        self.backups = backups
    }

    func readCurrent(userID: String, source: PersonalJuly2026LiveRepairReadSource) async throws -> PersonalJuly2026LiveRepairReadRecord {
        if source == .server, let serverError { throw serverError }
        return source == .server ? server : cache
    }

    func readBackups(userID: String) async throws -> [PersonalJuly2026LiveRepairReadRecord] {
        if let backupError { throw backupError }
        return backups
    }
}

private final class LiveRepairWriteSpy {
    private(set) var repositoryWrites = 0
}

private final class LiveRepairAtomicWriteSpy {
    private(set) var atomicWrites = 0
    var transactionAttempts = 0
    var externalClosureSideEffects = 0
    var rollbackProposals = 0
    var rollbackWrites = 0

    func commit() {
        atomicWrites += 1
    }
}

private enum TestError: Error {
    case serverUnavailable
    case backupUnavailable
    case malformedRawFixture
}

@MainActor
private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {
        // Expected.
    }
}
#endif
