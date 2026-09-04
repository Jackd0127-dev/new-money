import Foundation

enum PlannerCloudSyncDecision: Equatable, Sendable {
    case uploadLocal
    case downloadCloud
    case alreadySynced
    case keepEmptyLocal
}

enum PlannerCloudSyncPolicy {
    static let prefersMeaningfulCloudByDefault = true
    static let treatsExistingCloudSnapshotAsAuthoritative = true
    static let promptsForConflicts = false
}

enum PlannerCloudResetPolicy {
    static let deletesCurrentPlannerDocument = true
    static let deletesPlannerBackups = true
    static let writesEmptyCurrentPlannerDocument = true
    static let deletesFirebaseAuthUser = false
}

struct CloudPlannerSnapshotRecord: Equatable, Sendable {
    var snapshot: PlannerSnapshot
    var updatedAtIso: String?
}

struct CloudPlannerAccountCollectionRecord: Equatable, Sendable {
    var collection: PlannerAccountCollection
    var updatedAtIso: String?
}

enum PlannerCloudPayload: Sendable {
    case current(snapshot: PlannerSnapshot, updatedAtIso: String)
    case backup(snapshot: PlannerSnapshot, updatedAtIso: String)
    case currentAccounts(collection: PlannerAccountCollection, updatedAtIso: String)
    case backupAccounts(collection: PlannerAccountCollection, updatedAtIso: String)

    func firestoreData() throws -> [String: Any] {
        switch self {
        case let .current(snapshot, updatedAtIso):
            return [
                "version": 1,
                "updatedAtIso": updatedAtIso,
                "snapshot": try Self.snapshotDictionary(snapshot)
            ]
        case let .backup(snapshot, updatedAtIso):
            return [
                "version": 1,
                "backupVersion": 1,
                "updatedAtIso": updatedAtIso,
                "snapshot": try Self.snapshotDictionary(snapshot)
            ]
        case let .currentAccounts(collection, updatedAtIso):
            return [
                "version": 2,
                "schema": "plannerAccountCollection",
                "updatedAtIso": updatedAtIso,
                "accountCollection": try Self.accountCollectionDictionary(collection)
            ]
        case let .backupAccounts(collection, updatedAtIso):
            return [
                "version": 2,
                "backupVersion": 2,
                "schema": "plannerAccountCollection",
                "updatedAtIso": updatedAtIso,
                "accountCollection": try Self.accountCollectionDictionary(collection)
            ]
        }
    }

    static func decodeSnapshot(from dictionary: [String: Any]) throws -> PlannerSnapshot {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try JSONDecoder().decode(PlannerSnapshot.self, from: data)
    }

    static func decodeAccountCollection(from dictionary: [String: Any]) throws -> PlannerAccountCollection {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try JSONDecoder().decode(PlannerAccountCollection.self, from: data)
    }

    static func decodeAccountCollectionRecord(from dictionary: [String: Any]) throws -> CloudPlannerAccountCollectionRecord? {
        let fallbackTimestamp = dictionary["updatedAtIso"] as? String ?? "1970-01-01T00:00:00.000Z"
        if var accountCollectionData = dictionary["accountCollection"] as? [String: Any] {
            if let accounts = accountCollectionData["accounts"] as? [[String: Any]] {
                accountCollectionData["accounts"] = accounts.map { account in
                    var normalized = account
                    if let snapshot = account["snapshot"] as? [String: Any] {
                        normalized["snapshot"] = stableLegacyTimestamps(snapshot, fallback: account["createdAt"] as? String ?? fallbackTimestamp)
                    }
                    return normalized
                }
            }
            return try CloudPlannerAccountCollectionRecord(
                collection: decodeAccountCollection(from: accountCollectionData),
                updatedAtIso: dictionary["updatedAtIso"] as? String
            )
        }

        if let snapshotData = dictionary["snapshot"] as? [String: Any] {
            let snapshot = try decodeSnapshot(from: stableLegacyTimestamps(snapshotData, fallback: fallbackTimestamp))
            let raw = try JSONSerialization.data(withJSONObject: snapshotData, options: [.sortedKeys, .withoutEscapingSlashes])
            let accountID = "legacy-planner-" + PlannerCloudFingerprint.data(raw)
            let timestamp = dictionary["updatedAtIso"] as? String ?? "1970-01-01T00:00:00.000Z"
            let account = PlannerAccount(id: accountID, name: "Personal", color: "#F97316", snapshot: snapshot,
                createdAt: timestamp, updatedAt: timestamp)
            return CloudPlannerAccountCollectionRecord(
                collection: PlannerAccountCollection(activeAccountId: accountID, accounts: [account], updatedAt: timestamp),
                updatedAtIso: dictionary["updatedAtIso"] as? String
            )
        }

        return nil
    }

    /// Older debt payloads omitted timestamps. Wall-clock defaults would change sync identity on every read.
    private static func stableLegacyTimestamps(_ snapshot: [String: Any], fallback: String) -> [String: Any] {
        var normalized = snapshot
        for key in ["debts", "debtPayments"] {
            guard let records = snapshot[key] as? [[String: Any]] else { continue }
            normalized[key] = records.map { record in
                var value = record
                if value["createdAt"] == nil || value["createdAt"] is NSNull { value["createdAt"] = fallback }
                if value["updatedAt"] == nil || value["updatedAt"] is NSNull { value["updatedAt"] = value["createdAt"] }
                return value
            }
        }
        return normalized
    }

    static func snapshotDictionary(_ snapshot: PlannerSnapshot) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlannerCloudPayloadError.invalidSnapshotDictionary
        }
        return dictionary
    }

    static func accountCollectionDictionary(_ collection: PlannerAccountCollection) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(collection)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlannerCloudPayloadError.invalidAccountCollectionDictionary
        }
        return dictionary
    }

    static func signature(for snapshot: PlannerSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }

    static func signature(for collection: PlannerAccountCollection) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(collection)
        return String(decoding: data, as: UTF8.self)
    }
}

enum PlannerCloudPayloadError: Error {
    case invalidSnapshotDictionary
    case invalidAccountCollectionDictionary
}

enum PlannerCloudSyncResolver {
    static func decision(local: PlannerSnapshot, cloud: CloudPlannerSnapshotRecord?) -> PlannerCloudSyncDecision {
        guard let cloud else {
            return local.hasMeaningfulPlannerData ? .uploadLocal : .keepEmptyLocal
        }

        if (try? PlannerCloudPayload.signature(for: local)) == (try? PlannerCloudPayload.signature(for: cloud.snapshot)) {
            return .alreadySynced
        }

        return .downloadCloud
    }

    static func decision(local: PlannerAccountCollection, cloud: CloudPlannerAccountCollectionRecord?) -> PlannerCloudSyncDecision {
        guard let cloud else {
            return local.hasMeaningfulPlannerData ? .uploadLocal : .keepEmptyLocal
        }

        if (try? PlannerCloudPayload.signature(for: local)) == (try? PlannerCloudPayload.signature(for: cloud.collection)) {
            return .alreadySynced
        }

        return .downloadCloud
    }
}

extension PlannerSnapshot {
    var hasMeaningfulPlannerData: Bool {
        if !recurringPayments.isEmpty ||
            !payPeriods.isEmpty ||
            !paychecks.isEmpty ||
            !potAllocations.isEmpty ||
            !transactions.isEmpty ||
            !debts.isEmpty ||
            !debtPayments.isEmpty ||
            !debtReserves.isEmpty ||
            !debtPaymentScheduleItems.isEmpty ||
            !debtSnapshots.isEmpty ||
            !creditCards.isEmpty ||
            !customPayments.isEmpty ||
            !creditCardRepayments.isEmpty ||
            !creditCardPots.isEmpty ||
            !dailyBriefs.isEmpty {
            return true
        }

        return pots.contains { pot in
            pot.balancePence != 0 ||
                (pot.targetPence ?? 0) > 0 ||
                pot.linkedCreditCardId != nil ||
                pot.linkedDebtId != nil ||
                pot.archived
        }
    }
}

extension PlannerAccountCollection {
    var hasMeaningfulPlannerData: Bool {
        if let selectedThemePresetId,
           selectedThemePresetId != AppThemePreset.defaultPreset.rawValue {
            return true
        }

        if accounts.count > 1 {
            return true
        }

        if accounts.contains(where: { account in
            let cleanName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanName != "Personal" ||
                account.avatarImageName != nil ||
                account.avatarImageDataBase64 != nil ||
                account.snapshot.hasMeaningfulPlannerData
        }) {
            return true
        }

        return activeAccountId != accounts.first?.id
    }
}
