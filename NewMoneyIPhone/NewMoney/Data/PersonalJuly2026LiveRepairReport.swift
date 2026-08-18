#if DEBUG
import Foundation

struct PersonalJuly2026LiveRepairArtifacts: Sendable {
    var directory: URL
    var reportURL: URL
    var serverExportURL: URL
    var backupsExportURL: URL
    var manifestURL: URL
}

enum PersonalJuly2026LiveRepairReport {
    static func write(
        plan: PersonalJuly2026LiveRepairPlan,
        checkpointIdentifier: String?,
        deviceDescription: String
    ) throws -> PersonalJuly2026LiveRepairArtifacts {
        let timestamp = artifactTimestamp()
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NewMoneyLiveRepair", isDirectory: true)
            .appendingPathComponent("personal-july-2026", isDirectory: true)
            .appendingPathComponent(timestamp, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let reportURL = base.appendingPathComponent("PersonalJuly2026LiveRepairDryRun.md")
        let serverURL = base.appendingPathComponent("authoritative-server-account.json")
        let backupsURL = base.appendingPathComponent("server-provenance-backups.json")
        let manifestURL = base.appendingPathComponent("SHA256SUMS.txt")

        let serverData = try PersonalJuly2026LiveRepairPlanner.canonicalData(for: plan.server.collection)
        let backupData = try encodeBackups(plan.backups)
        let reportData = Data(render(plan: plan, checkpointIdentifier: checkpointIdentifier, deviceDescription: deviceDescription).utf8)

        try serverData.write(to: serverURL, options: .atomic)
        try backupData.write(to: backupsURL, options: .atomic)
        try reportData.write(to: reportURL, options: .atomic)

        let manifest = [
            manifestLine(data: reportData, fileName: reportURL.lastPathComponent),
            manifestLine(data: serverData, fileName: serverURL.lastPathComponent),
            manifestLine(data: backupData, fileName: backupsURL.lastPathComponent)
        ].joined(separator: "\n") + "\n"
        try Data(manifest.utf8).write(to: manifestURL, options: .atomic)

        return PersonalJuly2026LiveRepairArtifacts(directory: base, reportURL: reportURL, serverExportURL: serverURL, backupsExportURL: backupsURL, manifestURL: manifestURL)
    }

    static func render(
        plan: PersonalJuly2026LiveRepairPlan,
        checkpointIdentifier: String?,
        deviceDescription: String
    ) -> String {
        let before = plan.beforeMetrics
        let after = plan.proposedMetrics
        let cacheMatch = plan.cache.map { $0.canonicalSHA256 == plan.server.canonicalSHA256 }
        let failures = plan.checks.filter { !$0.passed }
        var lines = [
            "# Personal July 2026 Live Repair Dry Run",
            "",
            "- Generated: \(plan.proposedAtIso)",
            "- Scenario: \(PersonalJuly2026LiveRepairPlanner.scenarioVersion)",
            "- Mode: dry-run only",
            "- Device/app: \(deviceDescription)",
            "- Git checkpoint: \(checkpointIdentifier ?? "not supplied")",
            "- Firestore writes: 0",
            "- Repository writes: 0",
            "- Direct LevelDB edits/compaction: none",
            "- Recommendation: **\(plan.recommendation)**",
            "",
            "## Server read status",
            "",
            "- Source: \(plan.server.source.rawValue)",
            "- Firebase `isFromCache`: \(plan.server.isFromCache)",
            "- Document path: \(plan.server.redactedDocumentPath)",
            "- Server update token: \(plan.server.serverUpdatedAtIso ?? "missing")",
            "- Payload update token: \(plan.server.payloadUpdatedAtIso ?? "missing")",
            "- Canonical SHA-256: \(plan.server.canonicalSHA256)",
            "",
            "## Server versus cache comparison",
            "",
            "| Entity | Server logical state | Cache logical state | Match? |",
            "| --- | --- | --- | --- |",
            "| Account collection | \(accountSummary(plan.server.collection)) | \(plan.cache.map { accountSummary($0.collection) } ?? "cache unavailable") | \(cacheMatch.map { $0 ? "Yes" : "No" } ?? "N/A") |",
            "| Canonical SHA-256 | \(plan.server.canonicalSHA256) | \(plan.cache?.canonicalSHA256 ?? "unavailable") | \(cacheMatch.map { $0 ? "Yes" : "No" } ?? "N/A") |",
            "",
            "The server document is authoritative. Cache mismatches are diagnostic only.",
            "",
            "## Account fingerprint and preconditions",
            "",
            "| Check | Expected | Actual | Result | Detail |",
            "| --- | --- | --- | --- | --- |"
        ]
        lines += plan.checks.map { "| \(escape($0.name)) | \(escape($0.expected)) | \(escape($0.actual)) | \($0.passed ? "PASS" : "FAIL") | \(escape($0.detail)) |" }
        lines += [
            "",
            "## Canonical pay-period analysis",
            "",
            plan.payPeriodClassification,
            "",
            payPeriodTable(plan.server.collection),
            "",
            "## Jaja pot provenance",
            "",
            "- Evidence: \(plan.jajaProvenance)",
            "- Transition assessment: \(plan.jajaLossExplanation)",
            "- Safe method: update the existing active linked `Pot.balancePence` in the cloned state only; create no allocation, transaction, expense, or obligation.",
            "",
            "## Persisted pot identities",
            "",
            potTable(plan.server.collection),
            "",
            "## Existing funding-allocation provenance",
            "",
            allocationTable(plan.server.collection),
            "",
            "## Statement-field semantics",
            "",
            "`CreditCard.statementDate` is the first generated statement-cycle anchor. The production recurrence advances it monthly and associates the opening/current statement amount with that cycle.",
            "",
            "- Barclays proposed anchor: 2026-07-11 → payment 2026-08-06",
            "- Capital One proposed anchor: 2026-07-09 → payment 2026-08-02",
            "- June dates are not proposed because this model would attach current opening balances to already-paid cycles.",
            "",
            "## Exact proposed operations",
            ""
        ]
        if plan.operations.isEmpty {
            lines.append("No operations are valid while any blocking check fails.")
        } else {
            lines += plan.operations.enumerated().map { "\($0.offset + 1). \($0.element.description)" }
        }
        lines += [
            "",
            "## Before / proposed-after values",
            "",
            metricsTable(before: before, after: after),
            "",
            "## Records that remain untouched",
            "",
            "- Income and current paycheck",
            "- Deleted onboarding-income tombstone",
            "- iCloud transaction and all other transactions",
            "- Four existing funding allocations",
            "- Insurance, Capital One, Zable, Barclays, and Aqua pot balances",
            "- Every card balance and limit",
            "- Bill templates, Aqua opening payment, and Jaja card settings",
            "",
            untouchedHashTable(plan: plan),
            "",
            "## Pot-total conservation",
            "",
            "The proposed £215.80 change restores historical persisted money. It must change total pots from £919.93 to £1,135.73 while leaving Money Left, income, spending, and allocation count unchanged.",
            "",
            "## Future concurrency and idempotency plan (not implemented)",
            "",
            "1. Force-quit the normal app and suspend normal cloud upload.",
            "2. In one separately authorised Firestore transaction, reread the document and compare both server update token `\(plan.server.serverUpdatedAtIso ?? "missing")` and canonical hash `\(plan.server.canonicalSHA256)`.",
            "3. Abort on any mismatch. Otherwise write an authoritative backup, repaired current snapshot, and repair marker `personal-july-2026-v1` atomically.",
            "4. A matching marker or already-repaired preconditions must return a no-op. No partial write is permitted.",
            "",
            "## Backup and restore plan",
            "",
            "- Export: current `users/<redacted>/planner/snapshot` and retained `backups` documents used for provenance.",
            "- Format: canonical sorted UTF-8 JSON plus SHA-256 manifest.",
            "- Storage: `~/Library/Application Support/NewMoneyLiveRepair/personal-july-2026/<timestamp>/` after read-only device copy; never Git.",
            "- Concurrency token: server timestamp plus canonical SHA-256 shown above.",
            "- Credentials/tokens: excluded.",
            "- Restore: only through a separately authorised Firestore transaction after matching the same account fingerprint; never by copying LevelDB.",
            "",
            "## Failures and unresolved questions",
            ""
        ]
        lines += failures.isEmpty ? ["None."] : failures.map { "- **\($0.name):** expected \($0.expected); actual \($0.actual). \($0.detail)" }
        lines += [
            "",
            "## Confirmation",
            "",
            "This run performed zero live Firestore writes, zero planner-repository writes, wrote no repair marker, and did not directly modify, rewrite, or compact the Firestore LevelDB cache. Firebase SDK reads may refresh Firebase-managed cache metadata.",
            ""
        ]
        return lines.joined(separator: "\n")
    }

    private static func metricsTable(before: PersonalJuly2026LiveRepairMetrics?, after: PersonalJuly2026LiveRepairMetrics?) -> String {
        guard let before, let after else { return "Metrics unavailable because authoritative preconditions failed." }
        let rows: [(String, String, String)] = [
            ("Active July periods", "\(before.activeJulyPeriodCount)", "\(after.activeJulyPeriodCount)"),
            ("Income", money(before.incomePence), money(after.incomePence)),
            ("Money Left", money(before.currentMoneyLeftPence), money(after.currentMoneyLeftPence)),
            ("Safe to spend", money(before.safeToSpendPence), money(after.safeToSpendPence)),
            ("Recorded spending", money(before.recordedSpendingPence), money(after.recordedSpendingPence)),
            ("Activity net", money(before.activityNetPence), money(after.activityNetPence)),
            ("Total pots", money(before.totalPotPence), money(after.totalPotPence)),
            ("Jaja pot", money(before.potBalances["jaja"] ?? 0), money(after.potBalances["jaja"] ?? 0)),
            ("Total owed", money(before.totalOwedPence), money(after.totalOwedPence)),
            ("Available credit", money(before.totalAvailableCreditPence), money(after.totalAvailableCreditPence)),
            ("Forecast availability", money(before.forecastAvailabilityPence), money(after.forecastAvailabilityPence)),
            ("Funding allocations", "\(before.activeAllocationCount)", "\(after.activeAllocationCount)"),
            ("iCloud transactions", "\(before.iCloudTransactionCount)", "\(after.iCloudTransactionCount)")
        ]
        return (["| Metric | Before | Proposed after |", "| --- | ---: | ---: |"] + rows.map { "| \($0.0) | \($0.1) | \($0.2) |" }).joined(separator: "\n")
    }

    private static func payPeriodTable(_ collection: PlannerAccountCollection) -> String {
        guard let snapshot = collection.activeAccount?.snapshot else { return "No active account." }
        let rows = snapshot.payPeriods.map { period in
            let paycheckIds = snapshot.paychecks.filter { $0.payPeriodId == period.id && $0.deletedAt == nil }.map(\.id).joined(separator: ", ")
            let allocationIds = snapshot.potAllocations.filter { $0.payPeriodId == period.id && $0.deletedAt == nil }.map(\.id).joined(separator: ", ")
            return "| \(period.id) | \(period.startDate) | \(period.endDate) | \(money(period.incomePence)) | \(period.status.rawValue) | \(period.createdAt) | \(period.updatedAt) | \(escape(paycheckIds)) | \(escape(allocationIds)) |"
        }
        return (["| ID | Start | End | Income | Status | Created | Updated | Paychecks | Allocations |", "| --- | --- | --- | ---: | --- | --- | --- | --- | --- |"] + rows).joined(separator: "\n")
    }

    private static func potTable(_ collection: PlannerAccountCollection) -> String {
        guard let snapshot = collection.activeAccount?.snapshot else { return "No active account." }
        let cardNames = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0.name.trimmingCharacters(in: .whitespacesAndNewlines)) })
        let rows = snapshot.pots.filter { !$0.archived && $0.deletedAt == nil }.map { pot in
            "| \(pot.id) | \(escape(pot.name)) | \(money(pot.balancePence)) | \(escape(pot.linkedCreditCardId.flatMap { cardNames[$0] } ?? "none")) |"
        }
        return (["| Pot ID | Persisted label | Balance | Linked card |", "| --- | --- | ---: | --- |"] + rows).joined(separator: "\n")
    }

    private static func allocationTable(_ collection: PlannerAccountCollection) -> String {
        guard let snapshot = collection.activeAccount?.snapshot else { return "No active account." }
        let billNames = Dictionary(uniqueKeysWithValues: snapshot.recurringPayments.map { ($0.id, $0.name) })
        let cardNames = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0.name) })
        let potNames = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0.name) })
        let rows = snapshot.potAllocations.filter { $0.deletedAt == nil }.map { allocation in
            let sourceID = allocation.recurringPaymentId ?? allocation.creditCardId ?? allocation.debtId ?? "none"
            let sourceName = allocation.recurringPaymentId.flatMap { billNames[$0] }
                ?? allocation.creditCardId.flatMap { cardNames[$0] }
                ?? "unresolved"
            let dueDate = allocation.recurringDueDate ?? allocation.creditCardDirectDebitDate ?? allocation.debtDueDate ?? "none"
            let potName = potNames[allocation.potId] ?? "unresolved"
            return "| \(escape(allocation.id)) | \(allocation.source?.rawValue ?? "nil") | \(escape(sourceName)) | \(escape(sourceID)) | \(dueDate) | \(money(allocation.amountPence)) | \(escape(allocation.potId)) | \(escape(potName)) | \(escape(allocation.payPeriodId)) |"
        }
        return ([
            "| Allocation ID | Workflow source | Obligation | Source obligation ID | Due date | Amount | Pot ID | Persisted pot label | Pay-period ID |",
            "| --- | --- | --- | --- | --- | ---: | --- | --- | --- |"
        ] + rows).joined(separator: "\n")
    }

    private static func untouchedHashTable(plan: PersonalJuly2026LiveRepairPlan) -> String {
        guard let before = plan.beforeCollection.activeAccount?.snapshot,
              let after = plan.proposedCollection.activeAccount?.snapshot else {
            return "Untouched-record hashes unavailable because the active account is missing."
        }
        let rows: [(String, String, String)] = [
            ("Settings", canonicalHash(before.settings), canonicalHash(after.settings)),
            ("Recurring bills", canonicalHash(before.recurringPayments), canonicalHash(after.recurringPayments)),
            ("Bill groups", canonicalHash(before.billGroups), canonicalHash(after.billGroups)),
            ("Paychecks", canonicalHash(before.paychecks), canonicalHash(after.paychecks)),
            ("Funding allocations", canonicalHash(before.potAllocations), canonicalHash(after.potAllocations)),
            ("Transactions", canonicalHash(before.transactions), canonicalHash(after.transactions)),
            ("Debts", canonicalHash(before.debts), canonicalHash(after.debts)),
            ("Debt payments", canonicalHash(before.debtPayments), canonicalHash(after.debtPayments)),
            ("Debt reserves", canonicalHash(before.debtReserves), canonicalHash(after.debtReserves)),
            ("Debt schedule", canonicalHash(before.debtPaymentScheduleItems), canonicalHash(after.debtPaymentScheduleItems)),
            ("Debt snapshots", canonicalHash(before.debtSnapshots), canonicalHash(after.debtSnapshots)),
            ("Custom payments", canonicalHash(before.customPayments), canonicalHash(after.customPayments)),
            ("Card repayments", canonicalHash(before.creditCardRepayments), canonicalHash(after.creditCardRepayments)),
            ("Legacy card pots", canonicalHash(before.creditCardPots), canonicalHash(after.creditCardPots)),
            ("Daily briefs", canonicalHash(before.dailyBriefs), canonicalHash(after.dailyBriefs)),
            ("One-off income/tombstones", canonicalHash(before.oneOffIncomes), canonicalHash(after.oneOffIncomes)),
            ("Funding exclusions", canonicalHash(before.fundingChecklistExclusions), canonicalHash(after.fundingChecklistExclusions))
        ]
        let tableRows = rows.map { name, beforeHash, afterHash in
            "| \(name) | \(beforeHash) | \(afterHash) | \(beforeHash == afterHash ? "PASS" : "FAIL") |"
        }
        return ([
            "### Untouched-record hashes",
            "",
            "| Record set | Server hash | Proposed hash | Result |",
            "| --- | --- | --- | --- |"
        ] + tableRows).joined(separator: "\n")
    }

    private static func accountSummary(_ collection: PlannerAccountCollection) -> String {
        guard let snapshot = collection.activeAccount?.snapshot else { return "no active account" }
        return "\(snapshot.creditCards.filter { !$0.archived && $0.deletedAt == nil }.count) cards; \(snapshot.recurringPayments.filter { $0.active && $0.deletedAt == nil }.count) bills; \(snapshot.payPeriods.count) pay periods; \(snapshot.pots.filter { !$0.archived && $0.deletedAt == nil }.count) pots"
    }

    private static func encodeBackups(_ backups: [PersonalJuly2026LiveRepairReadRecord]) throws -> Data {
        struct BackupExport: Encodable {
            var redactedDocumentPath: String
            var payloadUpdatedAtIso: String?
            var serverUpdatedAtIso: String?
            var canonicalSHA256: String
            var collection: PlannerAccountCollection
        }
        let exports = backups.map {
            BackupExport(redactedDocumentPath: $0.redactedDocumentPath, payloadUpdatedAtIso: $0.payloadUpdatedAtIso, serverUpdatedAtIso: $0.serverUpdatedAtIso, canonicalSHA256: $0.canonicalSHA256, collection: $0.collection)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(exports)
    }

    private static func manifestLine(data: Data, fileName: String) -> String {
        "\(PersonalJuly2026LiveRepairPlanner.sha256(data))  \(fileName)"
    }

    private static func canonicalHash<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)).map(PersonalJuly2026LiveRepairPlanner.sha256) ?? "encoding-failed"
    }

    private static func artifactTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: .now)
    }

    private static func money(_ pence: Int) -> String { MoneyParser.formatPence(pence) }

    private static func escape(_ value: String) -> String {
        value.replacing("|", with: "\\|").replacing("\n", with: " ")
    }
}
#endif
