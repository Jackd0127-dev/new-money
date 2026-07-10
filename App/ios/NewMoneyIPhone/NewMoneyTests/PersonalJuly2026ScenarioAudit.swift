import Foundation
@testable import NewMoneyIPhone

enum PersonalJuly2026ScenarioAudit {
    static func write(snapshot: PlannerSnapshot, date: String) throws -> URL {
        let period = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)
        let costs = PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: period, asOfDate: date)
        let activeAllocations = snapshot.potAllocations.filter { $0.deletedAt == nil }.sorted { $0.id < $1.id }
        let transactions = snapshot.transactions.filter { $0.deletedAt == nil }.sorted { $0.id < $1.id }
        let occurrences = PlannerDerivedData.recurringOccurrences(payments: snapshot.recurringPayments, startDate: "2026-07-01", endDate: "2026-08-19")
        let pounds: (Int) -> String = { String(format: "£%.2f", Double($0) / 100) }
        let homeSafe = FinanceEngine.getDailySafeToSpendPence(spendablePence: costs.currentMoneyLeftPence, today: date, endDate: period?.endDate ?? date)
        let projectedSafe = FinanceEngine.getDailySafeToSpendPence(spendablePence: costs.moneyLeftPence, today: date, endDate: period?.endDate ?? date)
        let potById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        let cardById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        let totalOwed = snapshot.creditCards.reduce(0) { $0 + PlannerDerivedData.creditCardOwedSummary(card: $1, snapshot: snapshot, payPeriod: period, asOfDate: date).actualOwedPence }
        let totalAvailable = snapshot.creditCards.reduce(0) { $0 + PlannerDerivedData.creditCardAvailabilitySummary(card: $1, snapshot: snapshot, payPeriod: period, asOfDate: date).actualAvailablePence }
        let duplicateOccurrenceIDs = Dictionary(grouping: occurrences, by: \.id).filter { $0.value.count > 1 }.keys.sorted()
        let cardGaps = snapshot.pots.compactMap { pot -> (String, Int, String)? in
            guard let cardId = pot.linkedCreditCardId else { return nil }
            let progress = PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: date)
            return (pot.id, progress.shortfallPence, cardId)
        }.filter { $0.1 > 0 }
        let expectedHomeSafe = date == PersonalJuly2026ExpectedResults.baselineDate ? PersonalJuly2026ExpectedResults.baselineSafeToSpendPence : PersonalJuly2026ExpectedResults.afterICloudSafeToSpendPence
        let check: (String, Int, Int, String) -> String = { label, expected, actual, category in
            "- \(expected == actual ? "PASS" : "FAIL") [\(category)] \(label): expected \(pounds(expected)); actual \(pounds(actual))"
        }

        var lines = [
            "# Personal July 2026 Scenario Audit", "",
            "- Fixed current date: \(date) 12:00 Europe/London", "- Calendar: Gregorian; locale: en_GB; currency: GBP", "- Store: isolated InMemoryPlannerRepository; cloud/account sync disabled", "",
            "## Fixture construction timeline",
            "1. Seed opening pots totalling £982.32.",
            "2. Complete iCloud+, Runna, Apple Care and Aqua opening-balance funding through PlannerStore checklist commands.",
            "3. Resulting pot balances total £1,144.72.",
            "4. On 10 July only, run the existing due recurring-card-payment path after funding is complete.", "",
            "## Opening pot ledger",
            "| Pot ID | Pot | Opening |", "| --- | --- | ---: |",
            "| pot-insurance | Insurance | £0.00 |", "| pot-jaja | Jaja | £215.80 |", "| pot-capital-one | Capital One | £80.79 |", "| pot-zable | Zable | £0.00 |", "| pot-barclays | Barclays | £506.85 |", "| pot-aqua | Aqua | £178.88 |", "| total |  | £982.32 |", "",
            "## Funding actions ledger", "| Allocation ID | Source obligation | Pot | Amount | Link |", "| --- | --- | --- | ---: | --- |"
        ]
        lines += activeAllocations.map { allocation in
            let source: String
            if let paymentId = allocation.recurringPaymentId {
                source = "\(paymentId) / \(allocation.recurringDueDate ?? "unknown")"
            } else if let cardId = allocation.creditCardId {
                source = "\(cardId) / \(allocation.creditCardDirectDebitDate ?? "unknown")"
            } else { source = "unlinked" }
            return "| \(allocation.id) | \(source) | \(potById[allocation.potId]?.name ?? allocation.potId) | \(pounds(allocation.amountPence)) | \(allocation.source?.rawValue ?? "none") |"
        }
        lines += ["", "## Final pot ledger", "| Pot ID | Pot | Final balance |", "| --- | --- | ---: |"]
        lines += snapshot.pots.map { "| \($0.id) | \($0.name) | \(pounds($0.balancePence)) |" }
        lines += ["| total |  | \(pounds(snapshot.pots.reduce(0) { $0 + $1.balancePence })) |", "",
            "## Stable bill occurrence IDs", "| Occurrence ID | Status | Transaction ID |", "| --- | --- | --- |"]
        lines += occurrences.map { occurrence in
            let linked = transactions.first { $0.recurringPaymentId == occurrence.payment.id && $0.date == occurrence.dueDate }
            return "| \(occurrence.id) | \(linked == nil ? "funded/planned" : "recorded") | \(linked?.id ?? "none") |"
        }
        lines += ["- Duplicate occurrence IDs: \(duplicateOccurrenceIDs.isEmpty ? "none" : duplicateOccurrenceIDs.joined(separator: ", "))", "",
            "## Money Left calculation", "Starting income: \(pounds(costs.payReceivedPence))", "", "Included deductions for Home/current Money Left:", "| Record ID | Type | Description | Amount | Date | Linked pot/card | Reason |", "| --- | --- | --- | ---: | --- | --- | --- |"]
        let included = costs.items.filter { !$0.isProjected }
        lines += included.map { item in
            "| \(item.id) | \(item.source.rawValue) | \(item.label) | \(pounds(item.amountPence)) | \(item.date) | \(potById[item.potId ?? ""]?.name ?? "-") / \(cardById[item.creditCardId ?? ""]?.name ?? "-") | completed/non-projected cost-summary item |"
        }
        lines += ["", "Excluded candidates from Home/current Money Left:", "| Record ID | Type | Description | Amount | Reason |", "| --- | --- | --- | ---: | --- |"]
        lines += costs.items.filter(\.isProjected).map { "| \($0.id) | \($0.source.rawValue) | \($0.label) | \(pounds($0.amountPence)) | projected/unfunded checklist item; excluded from currentMoneyLeftPence |" }
        lines += ["", "- Home/current total deductions: \(pounds(costs.committedCostsPence))", "- Home/current Money Left: \(pounds(costs.currentMoneyLeftPence))", "- Projected total deductions: \(pounds(costs.projectedCostsPence))", "- Projected Money Left (audit legacy field moneyLeftPence): \(pounds(costs.moneyLeftPence))", "",
            "## Planned-cost field comparison", "- Funding checklist completed allocations: \(pounds(activeAllocations.reduce(0) { $0 + $1.amountPence }))", "- Committed costs (non-projected): \(pounds(costs.committedCostsPence))", "- Outstanding/projected checklist costs: \(pounds(costs.unfundedChecklistPence))", "- All projected costs: \(pounds(costs.projectedCostsPence))", "- Value used by Home Money Left card: currentMoneyLeftPence = \(pounds(costs.currentMoneyLeftPence))", "- Value previously inspected by the audit: moneyLeftPence = \(pounds(costs.moneyLeftPence))", "",
            "## Card-funding-gap inclusion report"]
        lines += cardGaps.map { potId, gap, cardId in
            let includedProjected = costs.items.contains { $0.isProjected && $0.amountPence == gap && $0.potId == potId }
            return "- \(cardById[cardId]?.name ?? cardId) gap \(pounds(gap)): \(includedProjected ? "included in projected Money Left only" : "not represented as an exact projected cost item")"
        }
        lines += ["", "## Safe-to-spend numerator and denominator", "- Home/current: numerator \(pounds(costs.currentMoneyLeftPence)); denominator \(date == "2026-07-09" ? "23" : "22") inclusive days; result \(pounds(homeSafe))", "- Projected: numerator \(pounds(costs.moneyLeftPence)); denominator \(date == "2026-07-09" ? "23" : "22") inclusive days; result \(pounds(projectedSafe))", "",
            "## Specification checks",
            check("Card balance", date == PersonalJuly2026ExpectedResults.baselineDate ? PersonalJuly2026ExpectedResults.baselineCardBalancePence : PersonalJuly2026ExpectedResults.afterICloudCardBalancePence, totalOwed, "calculation discrepancy"),
            check("Available credit", date == PersonalJuly2026ExpectedResults.baselineDate ? PersonalJuly2026ExpectedResults.baselineAvailableCreditPence : PersonalJuly2026ExpectedResults.afterICloudAvailableCreditPence, totalAvailable, "calculation discrepancy"),
            check("Committed costs", PersonalJuly2026ExpectedResults.baselineCommittedPence, costs.committedCostsPence, "calculation provenance"),
            check("Home Money Left", PersonalJuly2026ExpectedResults.baselineMoneyLeftPence, costs.currentMoneyLeftPence, "calculation provenance"),
            check("Home safe to spend", expectedHomeSafe, homeSafe, "calculation provenance"),
            check("Final pot total", date == PersonalJuly2026ExpectedResults.baselineDate ? PersonalJuly2026ExpectedResults.potTotalPence : PersonalJuly2026ExpectedResults.afterICloudPotTotalPence, snapshot.pots.reduce(0) { $0 + $1.balancePence }, "fixture loading"), "",
            "## Final classification",
            costs.currentMoneyLeftPence == PersonalJuly2026ExpectedResults.baselineMoneyLeftPence ? "Fixture problem resolved: final balances had previously been seeded without completed funding history; projected Money Left remains a distinct metric." : "Production calculation problem or mixed result: completed funding history did not restore Home/current Money Left.", "",
            "## Out-of-scope policy questions", "- Insurance pot target behaviour", "- Barclays statement recurrence", "- Aqua opening-balance overlap", "- Home All Outgoings presentation", "- Jaja due-date production repair", "- UI screenshot coverage", ""]

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = root.appendingPathComponent("outputs/personal_july_2026", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let destination = output.appendingPathComponent("PersonalJuly2026ScenarioAudit-\(date).md")
        try lines.joined(separator: "\n").write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }
}
