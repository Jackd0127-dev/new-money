import CryptoKit
import Foundation

struct PlannerServerTimestamp: Codable, Equatable, Sendable {
    var seconds: Int64
    var nanoseconds: Int32
}

enum PlannerCloudRevision: Codable, Equatable, Sendable {
    case missing
    case document(payloadSHA256: String, updatedAt: PlannerServerTimestamp?)

    var payloadSHA256: String? {
        guard case let .document(hash, _) = self else { return nil }
        return hash
    }
}

struct PlannerCloudRead: Codable, Equatable, Sendable {
    var collection: PlannerAccountCollection?
    var revision: PlannerCloudRevision
    /// Original planner payload, including fields this version of the app does not understand.
    var rawPayload: Data?
    var updatedAtIso: String?

    static let missing = PlannerCloudRead(collection: nil, revision: .missing, rawPayload: nil, updatedAtIso: nil)

    static func collection(_ collection: PlannerAccountCollection) throws -> PlannerCloudRead {
        let fields = try PlannerCloudPayload.currentAccounts(collection: collection, updatedAtIso: collection.updatedAt).firestoreData()
        return try PlannerCloudDocumentCodec.read(fields: fields)
    }
}

struct PlannerPendingUpload: Codable, Equatable, Sendable {
    var operationID: String
    var expectedRevision: PlannerCloudRevision
    var collection: PlannerAccountCollection
    /// Records an explicit local choice so a failed attempt can resume without losing its review screen.
    var resolutionConflictID: String?

    init(collection: PlannerAccountCollection, expectedRevision: PlannerCloudRevision, resolutionConflictID: String? = nil) {
        operationID = UUID().uuidString.lowercased()
        self.expectedRevision = expectedRevision
        self.collection = collection
        self.resolutionConflictID = resolutionConflictID
    }
}

enum PlannerCloudWriteResult: Sendable {
    case committed(PlannerCloudRead)
    case conflict(PlannerCloudRead)
}

struct PlannerSyncCheckpoint: Codable, Equatable, Sendable {
    var formatVersion = 1
    var ownerUID: String
    var baselineRevision: PlannerCloudRevision?
    var acknowledgedLocalFingerprint: String?
    var pendingUpload: PlannerPendingUpload?
    var conflictID: String?
    /// Set before the first network request on a genuinely fresh local installation.
    var initialLocalFingerprint: String?
}

struct PlannerSyncConflict: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var ownerUID: String
    var capturedAtIso: String
    var local: PlannerAccountCollection
    var cloud: PlannerCloudRead
    var baselineRevision: PlannerCloudRevision?
    var requiresOwnershipConfirmation: Bool
}

enum PlannerSyncStatus: Equatable, Sendable {
    case fixture
    case savedLocally
    case syncing
    case synced
    case failed(String)
    case conflict

    var title: String {
        switch self {
        case .fixture: "Fixture data. Cloud sync off"
        case .savedLocally: "Saved on this iPhone. Sync pending"
        case .syncing: "Syncing"
        case .synced: "Synced"
        case .failed: "Sync failed"
        case .conflict: "Sync paused. Both copies preserved"
        }
    }
}

enum PlannerSyncResult: Sendable {
    case acknowledged(fingerprint: String)
    case replaceLocal(collection: PlannerAccountCollection, cloud: PlannerCloudRead)
    case conflict(PlannerSyncConflict)
}

enum PlannerSyncRecoveryError: Error, LocalizedError {
    case conditionalWritesUnavailable
    case unsupportedSchema
    case invalidPayload
    case staleSession
    case invalidCheckpoint
    case missingConflict
    case changedDuringDownload
    case unverifiedLocalOwner
    case fixtureCloudSyncDisabled

    var errorDescription: String? {
        switch self {
        case .conditionalWritesUnavailable: "This sync service does not support safe conditional writes. Your local data has not been replaced."
        case .unsupportedSchema: "The cloud planner uses an unsupported data format. Your local data has not been replaced."
        case .invalidPayload: "The cloud planner could not be read safely. Your local data has not been replaced."
        case .staleSession: "The planner sync session changed. Pending data is still saved on this iPhone."
        case .invalidCheckpoint: "The saved sync recovery state could not be verified. No planner data has been replaced."
        case .missingConflict: "The saved conflict could not be found. No planner data has been replaced."
        case .changedDuringDownload: "The local planner changed while syncing. The latest changes will be checked again."
        case .unverifiedLocalOwner: "Connect to the internet to verify which planner belongs to this account. The data on this iPhone has not been replaced."
        case .fixtureCloudSyncDisabled: "Cloud planner data cannot be reset from a fixture session. Your cloud data has not been changed."
        }
    }
}

enum PlannerCloudFingerprint {
    static func collection(_ collection: PlannerAccountCollection) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return data(try encoder.encode(collection))
    }

    static func data(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Cloud revisions come from the original payload, before decoding, repair or migration.
enum PlannerCloudDocumentCodec {
    static func read(fields: [String: Any], updatedAt: PlannerServerTimestamp? = nil) throws -> PlannerCloudRead {
        if let value = fields["version"] {
            guard let version = value as? Int, version == 1 || version == 2 else {
                throw PlannerSyncRecoveryError.unsupportedSchema
            }
        }
        let payload: [String: Any]
        if let collection = fields["accountCollection"] as? [String: Any] {
            if let schema = fields["schema"], (schema as? String) != "plannerAccountCollection" {
                throw PlannerSyncRecoveryError.unsupportedSchema
            }
            payload = ["version": fields["version"] ?? 2, "schema": fields["schema"] ?? "plannerAccountCollection", "accountCollection": collection]
        } else if let snapshot = fields["snapshot"] as? [String: Any] {
            payload = ["version": fields["version"] ?? 1, "snapshot": snapshot]
        } else {
            throw PlannerSyncRecoveryError.invalidPayload
        }
        guard JSONSerialization.isValidJSONObject(payload) else { throw PlannerSyncRecoveryError.invalidPayload }
        let raw = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .withoutEscapingSlashes])
        guard let record = try PlannerCloudPayload.decodeAccountCollectionRecord(from: fields) else {
            throw PlannerSyncRecoveryError.invalidPayload
        }
        return PlannerCloudRead(
            collection: record.collection,
            revision: .document(payloadSHA256: PlannerCloudFingerprint.data(raw), updatedAt: updatedAt),
            rawPayload: raw,
            updatedAtIso: record.updatedAtIso
        )
    }

    /// Apply changes to known fields while retaining unknown fields on matching records.
    static func preservingUnknownFields(raw: Any, before: Any, after: Any) -> Any {
        if let raw = raw as? [String: Any], let before = before as? [String: Any], let after = after as? [String: Any] {
            var result = raw
            for key in Set(before.keys).union(after.keys) {
                guard let newValue = after[key] else {
                    result.removeValue(forKey: key)
                    continue
                }
                if let rawValue = raw[key], let oldValue = before[key] {
                    result[key] = preservingUnknownFields(raw: rawValue, before: oldValue, after: newValue)
                } else {
                    result[key] = newValue
                }
            }
            return result
        }
        if let raw = raw as? [[String: Any]], let before = before as? [[String: Any]], let after = after as? [[String: Any]],
           raw.allSatisfy({ $0["id"] is String }), before.allSatisfy({ $0["id"] is String }), after.allSatisfy({ $0["id"] is String }) {
            let rawByID = Dictionary(raw.map { ($0["id"] as! String, $0) }, uniquingKeysWith: { first, _ in first })
            let beforeByID = Dictionary(before.map { ($0["id"] as! String, $0) }, uniquingKeysWith: { first, _ in first })
            return after.map { item -> Any in
                guard let id = item["id"] as? String, let rawItem = rawByID[id], let oldItem = beforeByID[id] else { return item }
                return preservingUnknownFields(raw: rawItem, before: oldItem, after: item)
            }
        }
        return after
    }
}

protocol PlannerSyncRecoveryRepository: Sendable {
    func loadCheckpoint(userID: String) async throws -> PlannerSyncCheckpoint?
    func saveCheckpoint(_ checkpoint: PlannerSyncCheckpoint) async throws
    func localOwnerID() async throws -> String?
    func setLocalOwnerID(_ userID: String) async throws
    func archive(_ conflict: PlannerSyncConflict) async throws
    func conflict(id: String, userID: String) async throws -> PlannerSyncConflict?
}

actor FilePlannerSyncRecoveryRepository: PlannerSyncRecoveryRepository {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NewMoneyIPhone", isDirectory: true)
            .appendingPathComponent("SyncRecovery", isDirectory: true)
    }

    func loadCheckpoint(userID: String) async throws -> PlannerSyncCheckpoint? {
        let value: PlannerSyncCheckpoint? = try read(userDirectory(userID).appendingPathComponent("checkpoint.json"))
        if let value, value.formatVersion != 1 || value.ownerUID != userID {
            throw PlannerSyncRecoveryError.invalidCheckpoint
        }
        return value
    }

    func saveCheckpoint(_ checkpoint: PlannerSyncCheckpoint) async throws {
        try write(checkpoint, to: userDirectory(checkpoint.ownerUID).appendingPathComponent("checkpoint.json"))
    }

    func localOwnerID() async throws -> String? {
        try read(directory.appendingPathComponent("local-owner.json")) as String?
    }

    func setLocalOwnerID(_ userID: String) async throws {
        try write(userID, to: directory.appendingPathComponent("local-owner.json"))
    }

    func archive(_ conflict: PlannerSyncConflict) async throws {
        let url = conflictURL(id: conflict.id, userID: conflict.ownerUID)
        if FileManager.default.fileExists(atPath: url.path) {
            let existing: PlannerSyncConflict? = try read(url)
            guard existing == conflict else { throw PlannerSyncRecoveryError.invalidCheckpoint }
            return
        }
        try write(conflict, to: url)
    }

    func conflict(id: String, userID: String) async throws -> PlannerSyncConflict? {
        let value: PlannerSyncConflict? = try read(conflictURL(id: id, userID: userID))
        if let value, value.id != id || value.ownerUID != userID { throw PlannerSyncRecoveryError.invalidCheckpoint }
        return value
    }

    private func userDirectory(_ userID: String) -> URL {
        directory.appendingPathComponent(PlannerCloudFingerprint.data(Data(userID.utf8)), isDirectory: true)
    }

    private func conflictURL(id: String, userID: String) -> URL {
        userDirectory(userID).appendingPathComponent("Conflicts", isDirectory: true)
            .appendingPathComponent(PlannerCloudFingerprint.data(Data(id.utf8)) + ".json")
    }

    private func read<T: Decodable>(_ url: URL) throws -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
