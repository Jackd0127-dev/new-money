import Foundation

enum PlannerCloudSyncDecision: Equatable, Sendable {
    case uploadLocal
    case downloadCloud
    case alreadySynced
    case needsUserChoice
    case keepEmptyLocal
}

struct CloudPlannerSnapshotRecord: Equatable, Sendable {
    var snapshot: PlannerSnapshot
    var updatedAtIso: String?
}

enum PlannerCloudPayload: Sendable {
    case current(snapshot: PlannerSnapshot, updatedAtIso: String)
    case backup(snapshot: PlannerSnapshot, updatedAtIso: String)

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
        }
    }

    static func decodeSnapshot(from dictionary: [String: Any]) throws -> PlannerSnapshot {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try JSONDecoder().decode(PlannerSnapshot.self, from: data)
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

    static func signature(for snapshot: PlannerSnapshot) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }
}

enum PlannerCloudPayloadError: Error {
    case invalidSnapshotDictionary
}

enum PlannerCloudSyncResolver {
    static func decision(local: PlannerSnapshot, cloud: CloudPlannerSnapshotRecord?) -> PlannerCloudSyncDecision {
        guard let cloud else {
            return local.hasMeaningfulPlannerData ? .uploadLocal : .keepEmptyLocal
        }

        if (try? PlannerCloudPayload.signature(for: local)) == (try? PlannerCloudPayload.signature(for: cloud.snapshot)) {
            return .alreadySynced
        }

        let localHasData = local.hasMeaningfulPlannerData
        let cloudHasData = cloud.snapshot.hasMeaningfulPlannerData

        switch (localHasData, cloudHasData) {
        case (true, false):
            return .uploadLocal
        case (false, true):
            return .downloadCloud
        case (false, false):
            return .alreadySynced
        case (true, true):
            return .needsUserChoice
        }
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
