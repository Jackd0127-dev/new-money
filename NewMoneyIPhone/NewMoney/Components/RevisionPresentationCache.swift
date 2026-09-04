import Foundation

/// A bounded, view-owned cache for derived presentation data. Local UI state
/// changes can reuse the value without publishing another SwiftUI update.
@MainActor
final class RevisionPresentationCache<Key: Equatable, Value> {
    private var entry: (key: Key, value: Value)?

    func value(for key: Key, build: () -> Value) -> Value {
        if let entry, entry.key == key {
            return entry.value
        }
        let value = build()
        entry = (key, value)
        return value
    }
}

/// Account and effective date are explicit so cached values cannot cross
/// planner accounts or survive a date simulation change.
struct PlannerPresentationRevision: Equatable {
    var accountId: String?
    var snapshotRevision: Int
    var todayIso: String
    var selectedPayPeriodId: String?
}
