import Foundation
import UserNotifications

struct PlannerReminderRequest: Equatable, Sendable {
    var id: String
    var date: String
    var title: String
    var body: String
}

@MainActor
protocol PlannerReminderCenter {
    func isAuthorized() async -> Bool
    func pending() async -> [PlannerReminderRequest]
    func remove(ids: [String])
    func add(_ request: PlannerReminderRequest) async throws
}

@MainActor
final class SystemPlannerReminderCenter: PlannerReminderCenter {
    private let center = UNUserNotificationCenter.current()

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    func pending() async -> [PlannerReminderRequest] {
        await center.pendingNotificationRequests().compactMap { request in
            guard request.identifier.hasPrefix(PlannerReminderScheduler.prefix) else { return nil }
            return PlannerReminderRequest(id: request.identifier,
                                          date: request.content.userInfo["plannerDate"] as? String ?? "",
                                          title: request.content.title, body: request.content.body)
        }
    }

    func remove(ids: [String]) { center.removePendingNotificationRequests(withIdentifiers: ids) }

    func add(_ request: PlannerReminderRequest) async throws {
        guard FinanceEngine.isIsoDate(request.date) else { return }
        let parts = request.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return }
        var components = DateComponents()
        components.calendar = Calendar.current
        components.timeZone = TimeZone.current
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 9
        guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo["plannerDate"] = request.date
        content.sound = .default
        try await center.add(UNNotificationRequest(identifier: request.id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }
}

/// Coalesces refreshes and diffs pending requests. A newer generation is always
/// reconciled after an already-dispatched system operation completes.
@MainActor
final class PlannerReminderScheduler {
    static let prefix = "newmoney-card-cycle-"
    private let center: PlannerReminderCenter
    private var generation = 0
    private var desired: [PlannerReminderRequest] = []
    private var worker: Task<Void, Never>?

    init(center: PlannerReminderCenter = SystemPlannerReminderCenter()) { self.center = center }

    func refresh(_ requests: [PlannerReminderRequest]) {
        generation += 1
        desired = Array(requests.filter { $0.id.hasPrefix(Self.prefix) }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }.prefix(60))
        guard worker == nil else { return }
        worker = Task { await reconcile() }
    }

    func flush() async { await worker?.value }

    private func reconcile() async {
        while true {
            let revision = generation
            let requests = desired
            let authorized = await center.isAuthorized()
            guard revision == generation else { continue }
            let existing = await center.pending().filter { $0.id.hasPrefix(Self.prefix) }
            guard revision == generation else { continue }
            let wanted = authorized ? requests : []
            let desiredIDs = Set(wanted.map(\.id))
            center.remove(ids: existing.filter { !desiredIDs.contains($0.id) }.map(\.id))
            for request in wanted {
                guard revision == generation else { break }
                guard !existing.contains(request) else { continue }
                do { try await center.add(request) } catch {
                    // A denied or unavailable notification service must not block saving.
                    // The next foreground/data refresh retries the desired request.
                }
            }
            if revision == generation { break }
        }
        worker = nil
    }
}
