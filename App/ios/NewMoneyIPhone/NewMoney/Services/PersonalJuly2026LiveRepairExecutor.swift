#if DEBUG
import FirebaseFirestore
import Foundation

struct PersonalJuly2026FirestoreRawDocument: @unchecked Sendable {
    var fields: [String: Any]
}

struct PersonalJuly2026FirestoreVersionToken: Codable, Equatable, Sendable {
    var seconds: Int64
    var nanoseconds: Int32

    init(timestamp: Timestamp) {
        seconds = timestamp.seconds
        nanoseconds = timestamp.nanoseconds
    }

    var timestamp: Timestamp {
        Timestamp(seconds: seconds, nanoseconds: nanoseconds)
    }

    var description: String {
        "seconds=\(seconds), nanoseconds=\(nanoseconds)"
    }
}

enum PersonalJuly2026LiveRepairExecutionError: Error, LocalizedError {
    case missingRawDocument
    case missingVersionToken
    case unsupportedRawValue(String)
    case malformedAccountCollection(String)
    case ambiguousTarget(String)
    case decodedTargetFingerprintMismatch
    case rawTargetFingerprintMismatch
    case approvedPreStateHashMismatch(expected: String, actual: String)
    case serverVersionChanged
    case invalidPlan(String)
    case backupProvenanceUnavailable
    case inconsistentRepairMarker
    case deterministicBackupAlreadyExists
    case proposedRawDecodeFailed
    case proposedHashMismatch(expected: String, actual: String)
    case postVerificationFailed(String)
    case confirmationGateFailed

    var errorDescription: String? {
        switch self {
        case .missingRawDocument:
            "The authoritative Firestore read did not contain its raw document representation."
        case .missingVersionToken:
            "The authoritative Firestore read did not contain an exact seconds/nanoseconds version token."
        case let .unsupportedRawValue(type):
            "The Firestore document contains an unsupported raw value type: \(type)."
        case let .malformedAccountCollection(detail):
            "The raw planner account collection is malformed: \(detail)."
        case let .ambiguousTarget(target):
            "The exact raw repair target is missing or ambiguous: \(target)."
        case .decodedTargetFingerprintMismatch:
            "The decoded repair targets do not match the approved canonical artifact."
        case .rawTargetFingerprintMismatch:
            "The transaction raw target fingerprints differ from the verified preflight backup."
        case let .approvedPreStateHashMismatch(expected, actual):
            "The authoritative canonical hash changed. Expected \(expected); found \(actual)."
        case .serverVersionChanged:
            "The exact Firestore server timestamp changed after preflight."
        case let .invalidPlan(detail):
            "The shared live-repair planner rejected the state: \(detail)."
        case .backupProvenanceUnavailable:
            "The transaction could not re-read the server backup that proves Jaja previously held £215.80."
        case .inconsistentRepairMarker:
            "The repair marker is missing, partial, or inconsistent with the current server state."
        case .deterministicBackupAlreadyExists:
            "The deterministic repair backup exists without a matching completed repair marker."
        case .proposedRawDecodeFailed:
            "The field-preserving raw proposal could not be decoded through PlannerCloudPayload."
        case let .proposedHashMismatch(expected, actual):
            "The proposed canonical post-state hash differs. Expected \(expected); found \(actual)."
        case let .postVerificationFailed(detail):
            "Authoritative post-commit verification failed: \(detail)."
        case .confirmationGateFailed:
            "The exact live-repair confirmation gate was not satisfied."
        }
    }
}

enum PersonalJuly2026FirestoreRawCodec {
    static func canonicalData(_ fields: [String: Any]) throws -> Data {
        let value = try jsonValue(fields)
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    static func sha256(_ fields: [String: Any]) throws -> String {
        PersonalJuly2026LiveRepairPlanner.sha256(try canonicalData(fields))
    }

    static func jsonValue(_ value: Any) throws -> Any {
        switch value {
        case let timestamp as Timestamp:
            return [
                "__firestoreType": "timestamp",
                "seconds": timestamp.seconds,
                "nanoseconds": timestamp.nanoseconds
            ]
        case let dictionary as [String: Any]:
            return try dictionary.reduce(into: [String: Any]()) { result, item in
                result[item.key] = try jsonValue(item.value)
            }
        case let array as [Any]:
            return try array.map(jsonValue)
        case is NSNull, is String, is NSNumber:
            return value
        default:
            throw PersonalJuly2026LiveRepairExecutionError.unsupportedRawValue(String(describing: type(of: value)))
        }
    }

    static func record(
        fields: [String: Any],
        source: PersonalJuly2026LiveRepairReadSource,
        isFromCache: Bool,
        redactedPath: String,
        documentID: String? = nil
    ) throws -> PersonalJuly2026LiveRepairReadRecord {
        guard let decoded = try PlannerCloudPayload.decodeAccountCollectionRecord(from: fields) else {
            throw PersonalJuly2026LiveRepairReadError.invalidPayload
        }
        let canonical = try PersonalJuly2026LiveRepairPlanner.canonicalData(for: decoded.collection)
        let timestamp = fields["updatedAt"] as? Timestamp
        if source != .cache, timestamp == nil {
            throw PersonalJuly2026LiveRepairReadError.missingServerUpdateToken
        }
        return PersonalJuly2026LiveRepairReadRecord(
            source: source,
            collection: decoded.collection,
            payloadUpdatedAtIso: decoded.updatedAtIso,
            serverUpdatedAtIso: timestamp.map { ISO8601DateFormatter().string(from: $0.dateValue()) },
            canonicalSHA256: PersonalJuly2026LiveRepairPlanner.sha256(canonical),
            redactedDocumentPath: redactedPath,
            isFromCache: isFromCache,
            rawDocument: PersonalJuly2026FirestoreRawDocument(fields: fields),
            serverVersionToken: timestamp.map(PersonalJuly2026FirestoreVersionToken.init),
            rawSHA256: try sha256(fields),
            decodedTargetFingerprints: decodedTargetFingerprints(decoded.collection),
            rawTargetFingerprints: try? PersonalJuly2026RawFirestorePatcher.targetFingerprints(in: fields),
            documentID: documentID
        )
    }

    static func decodedTargetFingerprints(_ collection: PlannerAccountCollection) -> PersonalJuly2026DecodedTargetFingerprints? {
        guard let snapshot = collection.activeAccount?.snapshot,
              let period = snapshot.payPeriods.first(where: {
                  $0.id == PersonalJuly2026LiveRepairPlanner.julyPayPeriodID &&
                      $0.status == .closed &&
                      $0.incomePence == 0 &&
                      $0.createdAt == "2026-07-09T21:05:39.709Z" &&
                      $0.updatedAt == "2026-07-09T21:06:44.845Z"
              }),
              let pot = snapshot.pots.first(where: { $0.id == PersonalJuly2026LiveRepairPlanner.jajaPotID }),
              let barclays = snapshot.creditCards.first(where: { $0.id == PersonalJuly2026LiveRepairPlanner.barclaysCardID }),
              let capitalOne = snapshot.creditCards.first(where: { $0.id == PersonalJuly2026LiveRepairPlanner.capitalOneCardID }) else {
            return nil
        }
        return PersonalJuly2026DecodedTargetFingerprints(
            closedPayPeriod: PersonalJuly2026LiveRepairPlanner.canonicalHash(period),
            jajaPot: PersonalJuly2026LiveRepairPlanner.canonicalHash(pot),
            barclaysCard: PersonalJuly2026LiveRepairPlanner.canonicalHash(barclays),
            capitalOneCard: PersonalJuly2026LiveRepairPlanner.canonicalHash(capitalOne)
        )
    }
}

enum PersonalJuly2026RawFirestorePatcher {
    static func targetFingerprints(in root: [String: Any]) throws -> PersonalJuly2026RawTargetFingerprints {
        let snapshot = try activeSnapshot(in: root)
        let period = try uniqueObject(
            named: "closed July pay period",
            in: try objectArray(snapshot["payPeriods"]),
            where: { object in
                string(object["id"]) == PersonalJuly2026LiveRepairPlanner.julyPayPeriodID &&
                    string(object["status"]) == "closed" &&
                    integer(object["incomePence"]) == 0 &&
                    string(object["startDate"]) == "2026-07-01" &&
                    string(object["endDate"]) == "2026-07-31" &&
                    string(object["createdAt"]) == "2026-07-09T21:05:39.709Z" &&
                    string(object["updatedAt"]) == "2026-07-09T21:06:44.845Z"
            }
        )
        let pot = try uniqueObject(named: "active Jaja pot", in: try objectArray(snapshot["pots"])) {
            string($0["id"]) == PersonalJuly2026LiveRepairPlanner.jajaPotID
        }
        let cards = try objectArray(snapshot["creditCards"])
        let barclays = try uniqueObject(named: "Barclays card", in: cards) {
            string($0["id"]) == PersonalJuly2026LiveRepairPlanner.barclaysCardID
        }
        let capitalOne = try uniqueObject(named: "Capital One card", in: cards) {
            string($0["id"]) == PersonalJuly2026LiveRepairPlanner.capitalOneCardID
        }
        return PersonalJuly2026RawTargetFingerprints(
            closedPayPeriod: try fingerprint(period),
            jajaPot: try fingerprint(pot),
            barclaysCard: try fingerprint(barclays),
            capitalOneCard: try fingerprint(capitalOne)
        )
    }

    static func applying(
        plan: PersonalJuly2026LiveRepairPlan,
        to root: [String: Any],
        expectedRawFingerprints: PersonalJuly2026RawTargetFingerprints
    ) throws -> [String: Any] {
        guard plan.isValid,
              plan.stateClassification == .approvedPreState,
              plan.operations.count == 4 else {
            throw PersonalJuly2026LiveRepairExecutionError.invalidPlan("The approved pre-state must produce exactly four operations.")
        }
        guard try targetFingerprints(in: root) == expectedRawFingerprints else {
            throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
        }

        var result = root
        guard var accountCollection = result["accountCollection"] as? [String: Any],
              let activeAccountID = accountCollection["activeAccountId"] as? String,
              var accounts = accountCollection["accounts"] as? [[String: Any]] else {
            throw PersonalJuly2026LiveRepairExecutionError.malformedAccountCollection("missing accountCollection/accounts")
        }
        let accountIndices = accounts.indices.filter { string(accounts[$0]["id"]) == activeAccountID }
        guard accountIndices.count == 1, let accountIndex = accountIndices.first,
              var snapshot = accounts[accountIndex]["snapshot"] as? [String: Any] else {
            throw PersonalJuly2026LiveRepairExecutionError.malformedAccountCollection("active account is missing or ambiguous")
        }

        var periods = try objectArray(snapshot["payPeriods"])
        let periodIndices = try matchingIndices(in: periods, fingerprint: expectedRawFingerprints.closedPayPeriod) { object in
            string(object["id"]) == PersonalJuly2026LiveRepairPlanner.julyPayPeriodID &&
                string(object["status"]) == "closed" && integer(object["incomePence"]) == 0
        }
        guard periodIndices.count == 1, let periodIndex = periodIndices.first else {
            throw PersonalJuly2026LiveRepairExecutionError.ambiguousTarget("closed July pay period")
        }
        periods.remove(at: periodIndex)
        snapshot["payPeriods"] = periods

        var pots = try objectArray(snapshot["pots"])
        let potIndices = try matchingIndices(in: pots, fingerprint: expectedRawFingerprints.jajaPot) {
            string($0["id"]) == PersonalJuly2026LiveRepairPlanner.jajaPotID && integer($0["balancePence"]) == 0
        }
        guard potIndices.count == 1, let potIndex = potIndices.first else {
            throw PersonalJuly2026LiveRepairExecutionError.ambiguousTarget("active Jaja pot")
        }
        pots[potIndex]["balancePence"] = 21_580
        pots[potIndex]["updatedAt"] = plan.proposedAtIso
        snapshot["pots"] = pots

        var cards = try objectArray(snapshot["creditCards"])
        try updateCard(
            id: PersonalJuly2026LiveRepairPlanner.barclaysCardID,
            expectedFingerprint: expectedRawFingerprints.barclaysCard,
            before: "2026-07-10",
            after: "2026-07-11",
            timestamp: plan.proposedAtIso,
            cards: &cards
        )
        try updateCard(
            id: PersonalJuly2026LiveRepairPlanner.capitalOneCardID,
            expectedFingerprint: expectedRawFingerprints.capitalOneCard,
            before: "2026-07-10",
            after: "2026-07-09",
            timestamp: plan.proposedAtIso,
            cards: &cards
        )
        snapshot["creditCards"] = cards

        accounts[accountIndex]["snapshot"] = snapshot
        accounts[accountIndex]["updatedAt"] = plan.proposedAtIso
        accountCollection["accounts"] = accounts
        accountCollection["updatedAt"] = plan.proposedAtIso
        result["accountCollection"] = accountCollection
        result["updatedAtIso"] = plan.proposedAtIso

        guard let decoded = try PlannerCloudPayload.decodeAccountCollectionRecord(from: result) else {
            throw PersonalJuly2026LiveRepairExecutionError.proposedRawDecodeFailed
        }
        let actualHash = PersonalJuly2026LiveRepairPlanner.sha256(try PersonalJuly2026LiveRepairPlanner.canonicalData(for: decoded.collection))
        let expectedHash = PersonalJuly2026LiveRepairPlanner.sha256(try PersonalJuly2026LiveRepairPlanner.canonicalData(for: plan.proposedCollection))
        guard decoded.collection == plan.proposedCollection, actualHash == expectedHash else {
            throw PersonalJuly2026LiveRepairExecutionError.proposedHashMismatch(expected: expectedHash, actual: actualHash)
        }
        return result
    }

    static func verifyOnlyAuthorizedChanges(
        preRaw: [String: Any],
        postRaw: [String: Any],
        plan: PersonalJuly2026LiveRepairPlan,
        expectedRawFingerprints: PersonalJuly2026RawTargetFingerprints
    ) throws -> Bool {
        let expected = try applying(plan: plan, to: preRaw, expectedRawFingerprints: expectedRawFingerprints)
        var normalizedPost = postRaw
        normalizedPost["updatedAt"] = expected["updatedAt"]
        return try PersonalJuly2026FirestoreRawCodec.canonicalData(expected) == PersonalJuly2026FirestoreRawCodec.canonicalData(normalizedPost)
    }

    private static func activeSnapshot(in root: [String: Any]) throws -> [String: Any] {
        guard let accountCollection = root["accountCollection"] as? [String: Any],
              let activeID = accountCollection["activeAccountId"] as? String,
              let accounts = accountCollection["accounts"] as? [[String: Any]] else {
            throw PersonalJuly2026LiveRepairExecutionError.malformedAccountCollection("missing active account collection")
        }
        let matches = accounts.filter { string($0["id"]) == activeID }
        guard matches.count == 1, let snapshot = matches[0]["snapshot"] as? [String: Any] else {
            throw PersonalJuly2026LiveRepairExecutionError.malformedAccountCollection("active snapshot is missing or ambiguous")
        }
        return snapshot
    }

    private static func updateCard(
        id: String,
        expectedFingerprint: String,
        before: String,
        after: String,
        timestamp: String,
        cards: inout [[String: Any]]
    ) throws {
        let indices = try matchingIndices(in: cards, fingerprint: expectedFingerprint) {
            string($0["id"]) == id && string($0["statementDate"]) == before
        }
        guard indices.count == 1, let index = indices.first else {
            throw PersonalJuly2026LiveRepairExecutionError.ambiguousTarget(id)
        }
        cards[index]["statementDate"] = after
        cards[index]["updatedAt"] = timestamp
    }

    private static func matchingIndices(
        in objects: [[String: Any]],
        fingerprint expected: String,
        where predicate: ([String: Any]) -> Bool
    ) throws -> [Int] {
        try objects.indices.filter { index in
            guard predicate(objects[index]) else { return false }
            return try fingerprint(objects[index]) == expected
        }
    }

    private static func uniqueObject(
        named name: String,
        in objects: [[String: Any]],
        where predicate: ([String: Any]) -> Bool
    ) throws -> [String: Any] {
        let matches = objects.filter(predicate)
        guard matches.count == 1, let match = matches.first else {
            throw PersonalJuly2026LiveRepairExecutionError.ambiguousTarget(name)
        }
        return match
    }

    private static func fingerprint(_ object: [String: Any]) throws -> String {
        try PersonalJuly2026FirestoreRawCodec.sha256(object)
    }

    private static func objectArray(_ value: Any?) throws -> [[String: Any]] {
        guard let objects = value as? [[String: Any]] else {
            throw PersonalJuly2026LiveRepairExecutionError.malformedAccountCollection("expected an object array")
        }
        return objects
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }
}

struct PersonalJuly2026LiveRepairPreflight: @unchecked Sendable {
    var userID: String
    var plan: PersonalJuly2026LiveRepairPlan
    var serverRecord: PersonalJuly2026LiveRepairReadRecord
    var provenanceBackup: PersonalJuly2026LiveRepairReadRecord
    var expectedPostSHA256: String
    var executionTimestampIso: String
    var executionIdentifier: String
}

enum PersonalJuly2026LiveRepairCommitStatus: String, Sendable {
    case committed
    case alreadyApplied = "already-applied"
}

struct PersonalJuly2026LiveRepairExecutionResult: Sendable {
    var status: PersonalJuly2026LiveRepairCommitStatus
    var transactionAttemptCount: Int
    var preStateSHA256: String
    var postStateSHA256: String
    var postServerUpdatedAtIso: String
    var postServerVersionToken: PersonalJuly2026FirestoreVersionToken
    var markerPath: String
    var backupPath: String
    var postRecord: PersonalJuly2026LiveRepairReadRecord
}

protocol PersonalJuly2026LiveRepairExecuting {
    func execute(_ preflight: PersonalJuly2026LiveRepairPreflight) async throws -> PersonalJuly2026LiveRepairExecutionResult
}

private final class PersonalJuly2026TransactionAttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

final class FirebasePersonalJuly2026LiveRepairExecutor: PersonalJuly2026LiveRepairExecuting {
    static let markerDocumentID = PersonalJuly2026LiveRepairPlanner.scenarioVersion
    static let backupDocumentID = "repair-\(PersonalJuly2026LiveRepairPlanner.scenarioVersion)-\(PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256)"

    private struct FirestoreHandle: @unchecked Sendable {
        var value: Firestore
    }

    private let firestoreHandle: FirestoreHandle

    init(firestore: Firestore = Firestore.firestore()) {
        firestoreHandle = FirestoreHandle(value: firestore)
    }

    func execute(_ preflight: PersonalJuly2026LiveRepairPreflight) async throws -> PersonalJuly2026LiveRepairExecutionResult {
        let isApprovedPreState = preflight.plan.stateClassification == .approvedPreState
        let isApprovedPostState = preflight.plan.stateClassification == .approvedPostState
        guard isApprovedPreState || isApprovedPostState else {
            throw PersonalJuly2026LiveRepairExecutionError.invalidPlan("Prepared state is neither approved pre-state nor approved post-state.")
        }
        if isApprovedPreState, preflight.serverRecord.canonicalSHA256 != PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256 {
            throw PersonalJuly2026LiveRepairExecutionError.approvedPreStateHashMismatch(
                expected: PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
                actual: preflight.serverRecord.canonicalSHA256
            )
        }
        guard let preRaw = preflight.serverRecord.rawDocument?.fields,
              let preToken = preflight.serverRecord.serverVersionToken,
              let provenanceID = preflight.provenanceBackup.documentID else {
            throw PersonalJuly2026LiveRepairExecutionError.missingRawDocument
        }
        let preRawFingerprints = preflight.serverRecord.rawTargetFingerprints
        if isApprovedPreState, preRawFingerprints == nil {
            throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
        }

        let snapshotReference = snapshotDocument(userID: preflight.userID)
        let markerReference = snapshotReference.collection("repairs").document(Self.markerDocumentID)
        let backupReference = snapshotReference.collection("backups").document(Self.backupDocumentID)
        let provenanceReference = snapshotReference.collection("backups").document(provenanceID)
        let attempts = PersonalJuly2026TransactionAttemptCounter()
        let markerDocumentID = Self.markerDocumentID
        let backupDocumentID = Self.backupDocumentID

        let transactionValue = try await firestoreHandle.value.runTransaction { (transaction: FirebaseFirestore.Transaction, errorPointer) -> Any? in
            attempts.increment()
            do {
                let currentSnapshot = try transaction.getDocument(snapshotReference)
                let markerSnapshot = try transaction.getDocument(markerReference)
                let provenanceSnapshot = try transaction.getDocument(provenanceReference)
                let existingBackupSnapshot = try transaction.getDocument(backupReference)

                guard currentSnapshot.exists, let currentRaw = currentSnapshot.data() else {
                    throw PersonalJuly2026LiveRepairReadError.missingDocument
                }
                let currentRecord = try PersonalJuly2026FirestoreRawCodec.record(
                    fields: currentRaw,
                    source: .server,
                    isFromCache: false,
                    redactedPath: "users/<redacted>/planner/snapshot"
                )

                if markerSnapshot.exists {
                    guard let marker = markerSnapshot.data(),
                          marker["repairIdentifier"] as? String == PersonalJuly2026LiveRepairPlanner.scenarioVersion,
                          marker["preStateCanonicalSHA256"] as? String == PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
                          let markerPostHash = marker["postStateCanonicalSHA256"] as? String,
                          currentRecord.canonicalSHA256 == markerPostHash else {
                        throw PersonalJuly2026LiveRepairExecutionError.inconsistentRepairMarker
                    }
                    let postPlan = PersonalJuly2026LiveRepairPlanner.makePlan(
                        server: currentRecord,
                        cache: nil,
                        backups: [preflight.provenanceBackup],
                        proposedAtIso: preflight.executionTimestampIso
                    )
                    guard postPlan.isValid, postPlan.stateClassification == .approvedPostState, postPlan.operations.isEmpty else {
                        throw PersonalJuly2026LiveRepairExecutionError.inconsistentRepairMarker
                    }
                    return ["status": PersonalJuly2026LiveRepairCommitStatus.alreadyApplied.rawValue, "postHash": markerPostHash]
                }

                guard !existingBackupSnapshot.exists else {
                    throw PersonalJuly2026LiveRepairExecutionError.deterministicBackupAlreadyExists
                }
                guard currentRecord.canonicalSHA256 == PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256 else {
                    throw PersonalJuly2026LiveRepairExecutionError.approvedPreStateHashMismatch(
                        expected: PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
                        actual: currentRecord.canonicalSHA256
                    )
                }
                guard currentRecord.serverVersionToken == preToken else {
                    throw PersonalJuly2026LiveRepairExecutionError.serverVersionChanged
                }
                guard currentRecord.decodedTargetFingerprints == .approved else {
                    throw PersonalJuly2026LiveRepairExecutionError.decodedTargetFingerprintMismatch
                }
                guard let preRawFingerprints else {
                    throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
                }
                guard currentRecord.rawTargetFingerprints == preRawFingerprints else {
                    throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
                }
                guard provenanceSnapshot.exists, let provenanceRaw = provenanceSnapshot.data() else {
                    throw PersonalJuly2026LiveRepairExecutionError.backupProvenanceUnavailable
                }
                let transactionProvenance = try PersonalJuly2026FirestoreRawCodec.record(
                    fields: provenanceRaw,
                    source: .serverBackup,
                    isFromCache: false,
                    redactedPath: preflight.provenanceBackup.redactedDocumentPath,
                    documentID: provenanceID
                )
                guard transactionProvenance.canonicalSHA256 == preflight.provenanceBackup.canonicalSHA256 else {
                    throw PersonalJuly2026LiveRepairExecutionError.backupProvenanceUnavailable
                }

                let transactionPlan = PersonalJuly2026LiveRepairPlanner.makePlan(
                    server: currentRecord,
                    cache: nil,
                    backups: [transactionProvenance],
                    proposedAtIso: preflight.executionTimestampIso
                )
                guard transactionPlan.isValid,
                      transactionPlan.stateClassification == .approvedPreState,
                      transactionPlan.operations.count == 4 else {
                    throw PersonalJuly2026LiveRepairExecutionError.invalidPlan(
                        transactionPlan.checks.filter { !$0.passed }.map(\.name).joined(separator: ", ")
                    )
                }
                var proposedRaw = try PersonalJuly2026RawFirestorePatcher.applying(
                    plan: transactionPlan,
                    to: currentRaw,
                    expectedRawFingerprints: preRawFingerprints
                )
                guard let proposedDecoded = try PlannerCloudPayload.decodeAccountCollectionRecord(from: proposedRaw) else {
                    throw PersonalJuly2026LiveRepairExecutionError.proposedRawDecodeFailed
                }
                let proposedHash = PersonalJuly2026LiveRepairPlanner.sha256(
                    try PersonalJuly2026LiveRepairPlanner.canonicalData(for: proposedDecoded.collection)
                )
                guard proposedHash == preflight.expectedPostSHA256 else {
                    throw PersonalJuly2026LiveRepairExecutionError.proposedHashMismatch(expected: preflight.expectedPostSHA256, actual: proposedHash)
                }

                var backupRaw = currentRaw
                backupRaw["backupVersion"] = 2
                backupRaw["repairIdentifier"] = PersonalJuly2026LiveRepairPlanner.scenarioVersion
                backupRaw["repairPreStateCanonicalSHA256"] = PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256
                backupRaw["repairSourceUpdatedAt"] = preToken.timestamp
                backupRaw["updatedAtIso"] = preflight.executionTimestampIso
                backupRaw["updatedAt"] = FieldValue.serverTimestamp()

                proposedRaw["updatedAt"] = FieldValue.serverTimestamp()
                let markerData: [String: Any] = [
                    "repairIdentifier": PersonalJuly2026LiveRepairPlanner.scenarioVersion,
                    "preStateCanonicalSHA256": PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
                    "postStateCanonicalSHA256": proposedHash,
                    "preStateUpdatedAtSeconds": preToken.seconds,
                    "preStateUpdatedAtNanoseconds": preToken.nanoseconds,
                    "executionTimestampIso": preflight.executionTimestampIso,
                    "backupDocumentID": backupDocumentID,
                    "appliedAt": FieldValue.serverTimestamp()
                ]

                transaction.setData(backupRaw, forDocument: backupReference)
                transaction.setData(proposedRaw, forDocument: snapshotReference)
                transaction.setData(markerData, forDocument: markerReference)
                return ["status": PersonalJuly2026LiveRepairCommitStatus.committed.rawValue, "postHash": proposedHash]
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }

        guard let transactionResult = transactionValue as? [String: Any],
              let statusRaw = transactionResult["status"] as? String,
              let status = PersonalJuly2026LiveRepairCommitStatus(rawValue: statusRaw),
              let transactionPostHash = transactionResult["postHash"] as? String else {
            throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("transaction result was malformed")
        }

        let postSnapshot = try await snapshotReference.getDocument(source: .server)
        guard postSnapshot.exists, let postRaw = postSnapshot.data(), !postSnapshot.metadata.isFromCache else {
            throw PersonalJuly2026LiveRepairReadError.cacheReturnedForServerRead
        }
        let postRecord = try PersonalJuly2026FirestoreRawCodec.record(
            fields: postRaw,
            source: .server,
            isFromCache: false,
            redactedPath: "users/<redacted>/planner/snapshot"
        )
        guard postRecord.canonicalSHA256 == transactionPostHash,
              postRecord.canonicalSHA256 == preflight.expectedPostSHA256 else {
            throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("canonical post-state hash mismatch")
        }
        let postPlan = PersonalJuly2026LiveRepairPlanner.makePlan(
            server: postRecord,
            cache: nil,
            backups: [preflight.provenanceBackup],
            proposedAtIso: preflight.executionTimestampIso
        )
        guard postPlan.isValid,
              postPlan.stateClassification == .approvedPostState,
              postPlan.operations.isEmpty else {
            throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("shared planner rejected the committed server state")
        }
        if status == .committed {
            guard let preRawFingerprints else {
                throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
            }
            guard try PersonalJuly2026RawFirestorePatcher.verifyOnlyAuthorizedChanges(
                preRaw: preRaw,
                postRaw: postRaw,
                plan: preflight.plan,
                expectedRawFingerprints: preRawFingerprints
            ) else {
                throw PersonalJuly2026LiveRepairExecutionError.postVerificationFailed("an unrelated raw field changed")
            }
        }
        guard let postToken = postRecord.serverVersionToken,
              let postIso = postRecord.serverUpdatedAtIso else {
            throw PersonalJuly2026LiveRepairExecutionError.missingVersionToken
        }

        return PersonalJuly2026LiveRepairExecutionResult(
            status: status,
            transactionAttemptCount: attempts.value,
            preStateSHA256: preflight.serverRecord.canonicalSHA256,
            postStateSHA256: postRecord.canonicalSHA256,
            postServerUpdatedAtIso: postIso,
            postServerVersionToken: postToken,
            markerPath: "users/<redacted>/planner/snapshot/repairs/\(markerDocumentID)",
            backupPath: "users/<redacted>/planner/snapshot/backups/\(backupDocumentID)",
            postRecord: postRecord
        )
    }

    private func snapshotDocument(userID: String) -> DocumentReference {
        firestoreHandle.value.collection("users").document(userID).collection("planner").document("snapshot")
    }
}
#endif
