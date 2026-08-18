#if DEBUG
import FirebaseFirestore
import Foundation

@MainActor
protocol PersonalJuly2026LiveRepairReading {
    func readCurrent(userID: String, source: PersonalJuly2026LiveRepairReadSource) async throws -> PersonalJuly2026LiveRepairReadRecord
    func readBackups(userID: String) async throws -> [PersonalJuly2026LiveRepairReadRecord]
}

@MainActor
enum PersonalJuly2026LiveRepairCoordinator {
    static func readAndPlan(
        reader: PersonalJuly2026LiveRepairReading,
        userID: String,
        proposedAtIso: String = DateUtilities.nowIsoString()
    ) async throws -> PersonalJuly2026LiveRepairPlan {
        let server = try await reader.readCurrent(userID: userID, source: .server)
        guard server.source == .server, !server.isFromCache else {
            throw PersonalJuly2026LiveRepairReadError.cacheReturnedForServerRead
        }

        let cache = try? await reader.readCurrent(userID: userID, source: .cache)
        let backups = try await reader.readBackups(userID: userID)
        return PersonalJuly2026LiveRepairPlanner.makePlan(server: server, cache: cache, backups: backups, proposedAtIso: proposedAtIso)
    }
}

@MainActor
enum PersonalJuly2026LiveRepairExecutionCoordinator {
    static func prepare(
        reader: PersonalJuly2026LiveRepairReading,
        userID: String,
        executionTimestampIso: String = DateUtilities.nowIsoString(),
        executionIdentifier: String = makeExecutionIdentifier()
    ) async throws -> PersonalJuly2026LiveRepairPreflight {
        let server = try await reader.readCurrent(userID: userID, source: .server)
        guard server.source == .server, !server.isFromCache else {
            throw PersonalJuly2026LiveRepairReadError.cacheReturnedForServerRead
        }
        let cache = try? await reader.readCurrent(userID: userID, source: .cache)
        let backups = try await reader.readBackups(userID: userID)
        let plan = PersonalJuly2026LiveRepairPlanner.makePlan(
            server: server,
            cache: cache,
            backups: backups,
            proposedAtIso: executionTimestampIso
        )
        guard plan.isValid else {
            throw PersonalJuly2026LiveRepairExecutionError.invalidPlan(
                plan.checks.filter { !$0.passed }.map { "\($0.name): \($0.actual)" }.joined(separator: "; ")
            )
        }
        guard server.rawDocument != nil, server.rawSHA256 != nil else {
            throw PersonalJuly2026LiveRepairExecutionError.missingRawDocument
        }
        guard server.serverVersionToken != nil else {
            throw PersonalJuly2026LiveRepairExecutionError.missingVersionToken
        }

        if plan.stateClassification == .approvedPreState {
            guard server.canonicalSHA256 == PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256 else {
                throw PersonalJuly2026LiveRepairExecutionError.approvedPreStateHashMismatch(
                    expected: PersonalJuly2026LiveRepairPlanner.approvedPreStateSHA256,
                    actual: server.canonicalSHA256
                )
            }
            guard server.decodedTargetFingerprints == .approved else {
                throw PersonalJuly2026LiveRepairExecutionError.decodedTargetFingerprintMismatch
            }
            guard server.rawTargetFingerprints != nil, plan.operations.count == 4 else {
                throw PersonalJuly2026LiveRepairExecutionError.rawTargetFingerprintMismatch
            }
        } else if plan.stateClassification != .approvedPostState {
            throw PersonalJuly2026LiveRepairExecutionError.invalidPlan("The server is neither the approved pre-state nor an already-repaired post-state.")
        }

        guard let provenance = backups.first(where: { backup in
            guard backup.source == .serverBackup,
                  !backup.isFromCache,
                  backup.serverVersionToken != nil,
                  backup.rawDocument != nil,
                  backup.documentID != nil,
                  let snapshot = backup.collection.activeAccount?.snapshot else { return false }
            return snapshot.pots.contains { pot in
                !pot.archived && pot.deletedAt == nil &&
                    pot.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "jaja" &&
                    pot.balancePence == 21_580
            }
        }) else {
            throw PersonalJuly2026LiveRepairExecutionError.backupProvenanceUnavailable
        }

        let expectedPostHash = PersonalJuly2026LiveRepairPlanner.sha256(
            try PersonalJuly2026LiveRepairPlanner.canonicalData(for: plan.proposedCollection)
        )
        return PersonalJuly2026LiveRepairPreflight(
            userID: userID,
            plan: plan,
            serverRecord: server,
            provenanceBackup: provenance,
            expectedPostSHA256: expectedPostHash,
            executionTimestampIso: executionTimestampIso,
            executionIdentifier: executionIdentifier
        )
    }

    private static func makeExecutionIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: .now)
    }
}

enum PersonalJuly2026LiveRepairReadError: Error, LocalizedError {
    case unsupportedSource
    case missingDocument
    case cacheReturnedForServerRead
    case invalidPayload
    case missingServerUpdateToken

    var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            "The requested repair read source is not supported."
        case .missingDocument:
            "The signed-in account has no planner snapshot document."
        case .cacheReturnedForServerRead:
            "Firestore returned cached data for a required authoritative server read."
        case .invalidPayload:
            "The planner snapshot could not be decoded through the production cloud payload model."
        case .missingServerUpdateToken:
            "The server document is missing its authoritative updatedAt timestamp."
        }
    }
}

@MainActor
final class FirebasePersonalJuly2026LiveRepairReader: PersonalJuly2026LiveRepairReading {
    private let firestore: Firestore

    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }

    func readCurrent(userID: String, source: PersonalJuly2026LiveRepairReadSource) async throws -> PersonalJuly2026LiveRepairReadRecord {
        let firestoreSource: FirestoreSource
        switch source {
        case .server:
            firestoreSource = .server
        case .cache:
            firestoreSource = .cache
        case .serverBackup:
            throw PersonalJuly2026LiveRepairReadError.unsupportedSource
        }

        let snapshot = try await snapshotDocument(userID: userID).getDocument(source: firestoreSource)
        guard snapshot.exists, let data = snapshot.data() else {
            throw PersonalJuly2026LiveRepairReadError.missingDocument
        }
        if source == .server, snapshot.metadata.isFromCache {
            throw PersonalJuly2026LiveRepairReadError.cacheReturnedForServerRead
        }
        return try makeRecord(data: data, source: source, isFromCache: snapshot.metadata.isFromCache, redactedPath: "users/<redacted>/planner/snapshot")
    }

    func readBackups(userID: String) async throws -> [PersonalJuly2026LiveRepairReadRecord] {
        let query = snapshotDocument(userID: userID)
            .collection("backups")
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)
        let result = try await query.getDocuments(source: .server)
        return try result.documents.enumerated().map { index, snapshot in
            if snapshot.metadata.isFromCache {
                throw PersonalJuly2026LiveRepairReadError.cacheReturnedForServerRead
            }
            return try makeRecord(
                data: snapshot.data(),
                source: .serverBackup,
                isFromCache: false,
                redactedPath: "users/<redacted>/planner/snapshot/backups/<redacted-\(index + 1)>",
                documentID: snapshot.documentID
            )
        }
    }

    private func makeRecord(
        data: [String: Any],
        source: PersonalJuly2026LiveRepairReadSource,
        isFromCache: Bool,
        redactedPath: String,
        documentID: String? = nil
    ) throws -> PersonalJuly2026LiveRepairReadRecord {
        try PersonalJuly2026FirestoreRawCodec.record(
            fields: data,
            source: source,
            isFromCache: isFromCache,
            redactedPath: redactedPath,
            documentID: documentID
        )
    }

    private func snapshotDocument(userID: String) -> DocumentReference {
        firestore.collection("users").document(userID).collection("planner").document("snapshot")
    }
}
#endif
