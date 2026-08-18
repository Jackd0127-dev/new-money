#if DEBUG
import CryptoKit
import Foundation

enum PersonalJuly2026LiveRepairReadSource: String, Sendable {
    case server
    case cache
    case serverBackup = "server-backup"
}

struct PersonalJuly2026LiveRepairReadRecord: Sendable {
    var source: PersonalJuly2026LiveRepairReadSource
    var collection: PlannerAccountCollection
    var payloadUpdatedAtIso: String?
    var serverUpdatedAtIso: String?
    var canonicalSHA256: String
    var redactedDocumentPath: String
    var isFromCache: Bool
    var rawDocument: PersonalJuly2026FirestoreRawDocument? = nil
    var serverVersionToken: PersonalJuly2026FirestoreVersionToken? = nil
    var rawSHA256: String? = nil
    var decodedTargetFingerprints: PersonalJuly2026DecodedTargetFingerprints? = nil
    var rawTargetFingerprints: PersonalJuly2026RawTargetFingerprints? = nil
    var documentID: String? = nil
}

enum PersonalJuly2026LiveRepairStateClassification: String, Equatable, Sendable {
    case approvedPreState = "approved-pre-state"
    case approvedPostState = "approved-post-state"
    case invalid
}

struct PersonalJuly2026DecodedTargetFingerprints: Equatable, Sendable {
    var closedPayPeriod: String
    var jajaPot: String
    var barclaysCard: String
    var capitalOneCard: String

    static let approved = PersonalJuly2026DecodedTargetFingerprints(
        closedPayPeriod: "50df3dbc4cefd63cbfe69861f680b0f2a051d729c655b8a4217b05857026df8c",
        jajaPot: "4bcc2d92810d7903accf9309e08049610759ab3052c3f0172c2ce6a7c7398aca",
        barclaysCard: "66fc3ad40bc0f594d4147fdf430a4843b85c37ab1d02ee890d6b9ed57af5d255",
        capitalOneCard: "759bb15e94cff550f5c494f4f8f664dca61108407e2875d562d331d5124e58b6"
    )
}

struct PersonalJuly2026RawTargetFingerprints: Codable, Equatable, Sendable {
    var closedPayPeriod: String
    var jajaPot: String
    var barclaysCard: String
    var capitalOneCard: String
}

enum PersonalJuly2026LiveRepairOperation: Equatable, Sendable {
    case removeClosedDuplicatePayPeriod(id: String, createdAt: String)
    case restoreJajaPot(id: String, fromPence: Int, toPence: Int)
    case setStatementAnchor(cardId: String, cardName: String, from: String?, to: String)

    var description: String {
        switch self {
        case let .removeClosedDuplicatePayPeriod(id, createdAt):
            "Remove closed £0.00 pay period \(id) created \(createdAt)"
        case let .restoreJajaPot(id, fromPence, toPence):
            "Restore Jaja pot \(id) from \(MoneyParser.formatPence(fromPence)) to \(MoneyParser.formatPence(toPence))"
        case let .setStatementAnchor(_, cardName, from, to):
            "Set \(cardName) statement-cycle anchor from \(from ?? "nil") to \(to)"
        }
    }
}

struct PersonalJuly2026LiveRepairCheck: Equatable, Sendable {
    var name: String
    var expected: String
    var actual: String
    var passed: Bool
    var detail: String
}

struct PersonalJuly2026LiveRepairMetrics: Equatable, Sendable {
    var activeJulyPeriodCount: Int
    var incomePence: Int
    var currentPaycheckCount: Int
    var zeroPaycheckCount: Int
    var unexpected1696PaycheckCount: Int
    var currentMoneyLeftPence: Int
    var safeToSpendPence: Int
    var recordedSpendingPence: Int
    var activityNetPence: Int
    var potBalances: [String: Int]
    var totalPotPence: Int
    var totalOwedPence: Int
    var totalAvailableCreditPence: Int
    var forecastAvailabilityPence: Int
    var jajaDueDate: String?
    var capitalOneDueDate: String?
    var barclaysDueDate: String?
    var iCloudTransactionCount: Int
    var activeAllocationCount: Int
    var duplicateRepaymentIdCount: Int
}

struct PersonalJuly2026LiveRepairPlan: Sendable {
    var server: PersonalJuly2026LiveRepairReadRecord
    var cache: PersonalJuly2026LiveRepairReadRecord?
    var backups: [PersonalJuly2026LiveRepairReadRecord]
    var proposedAtIso: String
    var operations: [PersonalJuly2026LiveRepairOperation]
    var checks: [PersonalJuly2026LiveRepairCheck]
    var beforeCollection: PlannerAccountCollection
    var proposedCollection: PlannerAccountCollection
    var beforeMetrics: PersonalJuly2026LiveRepairMetrics?
    var proposedMetrics: PersonalJuly2026LiveRepairMetrics?
    var payPeriodClassification: String
    var jajaProvenance: String
    var jajaLossExplanation: String
    var stateClassification: PersonalJuly2026LiveRepairStateClassification

    var isValid: Bool {
        !checks.contains { !$0.passed }
    }

    var recommendation: String {
        if !isValid {
            "Do not proceed. The dry-run did not satisfy every invariant."
        } else if stateClassification == .approvedPostState {
            "Repair already applied; perform zero writes."
        } else {
            "Safe to proceed only with a separately authorised live repair."
        }
    }
}

enum PersonalJuly2026LiveRepairPlanner {
    static let scenarioVersion = "personal-july-2026-v1"
    static let asOfDate = "2026-07-10"
    static let expectedCurrentMoneyLeftPence = 324_423
    static let expectedSafeToSpendPence = 14_746
    static let approvedPreStateSHA256 = "14c6bc4ced90d2ece5c526671bbb37c9c4f588ae750b0cef210a6ecd3053278b"
    static let julyPayPeriodID = "pay-period-2026-07-01"
    static let jajaPotID = "pot-87f6f6a6-769b-4f16-acbf-520c815c84fe"
    static let jajaCardID = "card-9f725291-ac91-47aa-92aa-faed24a9df1e"
    static let barclaysCardID = "card-78b7d9ba-25d4-4e9e-b945-740086006d91"
    static let capitalOneCardID = "card-2f7ccdee-e482-46cb-8905-a2d033ae63a3"

    static func makePlan(
        server: PersonalJuly2026LiveRepairReadRecord,
        cache: PersonalJuly2026LiveRepairReadRecord?,
        backups: [PersonalJuly2026LiveRepairReadRecord],
        proposedAtIso: String = DateUtilities.nowIsoString()
    ) -> PersonalJuly2026LiveRepairPlan {
        var checks = validateServerRead(server)
        let beforeCollection = server.collection

        guard let activeAccount = beforeCollection.activeAccount else {
            checks.append(check("Active planner account", expected: "present", actual: "missing", passed: false, detail: "The server document decoded without an active account."))
            return PersonalJuly2026LiveRepairPlan(
                server: server,
                cache: cache,
                backups: backups,
                proposedAtIso: proposedAtIso,
                operations: [],
                checks: checks,
                beforeCollection: beforeCollection,
                proposedCollection: beforeCollection,
                beforeMetrics: nil,
                proposedMetrics: nil,
                payPeriodClassification: "Unable to classify without an active server account.",
                jajaProvenance: "Unavailable.",
                jajaLossExplanation: "Unavailable.",
                stateClassification: .invalid
            )
        }

        checks += fingerprintChecks(snapshot: activeAccount.snapshot)
        guard !checks.contains(where: { !$0.passed }) else {
            return invalidPlan(server: server, cache: cache, backups: backups, checks: checks, collection: beforeCollection, proposedAtIso: proposedAtIso)
        }

        var proposedCollection = beforeCollection
        guard let activeIndex = proposedCollection.accounts.firstIndex(where: { $0.id == proposedCollection.activeAccountId }) ?? proposedCollection.accounts.indices.first else {
            checks.append(check("Active account index", expected: "present", actual: "missing", passed: false, detail: "No mutable active account was found."))
            return invalidPlan(server: server, cache: cache, backups: backups, checks: checks, collection: beforeCollection, proposedAtIso: proposedAtIso)
        }

        let beforeSnapshot = activeAccount.snapshot
        var proposedSnapshot = beforeSnapshot
        var operations: [PersonalJuly2026LiveRepairOperation] = []

        let julyPeriods = beforeSnapshot.payPeriods.filter { $0.id == julyPayPeriodID }
        let activeJuly = julyPeriods.filter { $0.status == .active && $0.startDate == "2026-07-01" && $0.endDate == "2026-07-31" && $0.incomePence == 340_663 }
        let closedZeroIndices = beforeSnapshot.payPeriods.indices.filter { index in
            let period = beforeSnapshot.payPeriods[index]
            return period.id == julyPayPeriodID &&
                period.status == .closed &&
                period.incomePence == 0 &&
                period.startDate == "2026-07-01" &&
                period.endDate == "2026-07-31" &&
                period.payday == "2026-07-01" &&
                period.nextPayday == "2026-08-01" &&
                period.createdAt == "2026-07-09T21:05:39.709Z" &&
                period.updatedAt == "2026-07-09T21:06:44.845Z"
        }
        let activeJajaPot = activePots(beforeSnapshot).first { $0.id == jajaPotID }
        let activeBarclaysCard = activeCards(beforeSnapshot).first { $0.id == barclaysCardID }
        let activeCapitalOneCard = activeCards(beforeSnapshot).first { $0.id == capitalOneCardID }
        let isApprovedPreState = julyPeriods.count == 2 && activeJuly.count == 1 && closedZeroIndices.count == 1 &&
            activeJajaPot?.balancePence == 0 && activeBarclaysCard?.statementDate == "2026-07-10" && activeCapitalOneCard?.statementDate == "2026-07-10"
        let isApprovedPostState = julyPeriods.count == 1 && activeJuly.count == 1 && closedZeroIndices.isEmpty &&
            activeJajaPot?.balancePence == 21_580 && activeBarclaysCard?.statementDate == "2026-07-11" && activeCapitalOneCard?.statementDate == "2026-07-09"
        let stateClassification: PersonalJuly2026LiveRepairStateClassification = if isApprovedPreState {
            .approvedPreState
        } else if isApprovedPostState {
            .approvedPostState
        } else {
            .invalid
        }
        let payPeriodClassification: String

        if stateClassification == .approvedPostState {
            payPeriodClassification = "One canonical active July period; the approved duplicate is absent and the repair is already applied."
        } else if stateClassification == .approvedPreState, let duplicateIndex = closedZeroIndices.first {
            let duplicate = proposedSnapshot.payPeriods[duplicateIndex]
            let targetCheckPassed = server.decodedTargetFingerprints == .approved
            checks.append(check(
                "Approved decoded target fingerprints",
                expected: String(describing: PersonalJuly2026DecodedTargetFingerprints.approved),
                actual: String(describing: server.decodedTargetFingerprints),
                passed: targetCheckPassed,
                detail: "The four decoded target objects must match the canonical dry-run artifact before any clone mutation is proposed."
            ))
            if targetCheckPassed {
                proposedSnapshot.payPeriods.remove(at: duplicateIndex)
            }
            operations.append(.removeClosedDuplicatePayPeriod(id: duplicate.id, createdAt: duplicate.createdAt))
            payPeriodClassification = "Two logical server objects; propose removing only the closed £0.00 duplicate."
        } else {
            checks.append(check("Canonical July pay periods", expected: "one active, optionally one exact closed £0 duplicate", actual: "\(julyPeriods.count) matching-ID objects", passed: false, detail: "Unexpected logical pay-period state; no dedupe can be proposed."))
            payPeriodClassification = "Unexpected server pay-period state."
        }

        let activeJajaCards = activeCards(beforeSnapshot).filter { $0.id == jajaCardID }
        let activeJajaPots = activePots(beforeSnapshot).filter { $0.id == jajaPotID }
        var jajaProvenance = "No historical £215.80 Jaja pot was found."
        var jajaLossExplanation = "The current document alone does not identify the command that reduced or replaced the pot."

        if let jajaCard = activeJajaCards.first, let jajaPot = activeJajaPots.first {
            checks.append(check("Jaja pot-to-card link", expected: jajaCard.id, actual: jajaPot.linkedCreditCardId ?? "nil", passed: jajaPot.linkedCreditCardId == jajaCard.id, detail: "The existing active pot must remain linked to the existing active card."))

            let historicalMatch = backups.first { backup in
                guard let snapshot = backup.collection.activeAccount?.snapshot else { return false }
                return activePots(snapshot).contains {
                    normalized($0.name) == "jaja" && $0.balancePence == 21_580
                }
            }

            if let historicalMatch {
                jajaProvenance = "Server backup \(historicalMatch.redactedDocumentPath) contains a £215.80 Jaja pot; SHA-256 \(historicalMatch.canonicalSHA256)."
                jajaLossExplanation = explainJajaTransition(current: jajaPot, backup: historicalMatch)
            } else {
                jajaProvenance = "No retained server backup contains £215.80; the calibrated PersonalJuly2026 scenario and prior decoded audit provide the independent historical evidence."
            }

            if stateClassification == .approvedPreState {
                checks.append(check(
                    "Jaja server-backup provenance",
                    expected: "an authoritative backup with the approved Jaja pot ID at £215.80",
                    actual: historicalMatch == nil ? "not found" : "found",
                    passed: historicalMatch != nil,
                    detail: "A live restoration requires retained server provenance; fixture evidence alone cannot authorise the write."
                ))
            }

            if stateClassification == .approvedPreState, jajaPot.balancePence == 0 {
                proposedSnapshot.pots = proposedSnapshot.pots.map { pot in
                    guard pot.id == jajaPot.id else { return pot }
                    var repaired = pot
                    repaired.balancePence = 21_580
                    repaired.updatedAt = proposedAtIso
                    return repaired
                }
                operations.append(.restoreJajaPot(id: jajaPot.id, fromPence: 0, toPence: 21_580))
            } else if stateClassification != .approvedPostState || jajaPot.balancePence != 21_580 {
                checks.append(check("Jaja current pot balance", expected: "£0.00 or already repaired £215.80", actual: MoneyParser.formatPence(jajaPot.balancePence), passed: false, detail: "An unexpected balance must abort the repair."))
            }
        } else {
            checks.append(check("Single active Jaja card and pot", expected: "1 card / 1 pot", actual: "\(activeJajaCards.count) card / \(activeJajaPots.count) pot", passed: false, detail: "Jaja restoration cannot safely identify its target."))
        }

        if stateClassification == .approvedPreState {
            setStatementAnchor(id: barclaysCardID, name: "Barclays", target: "2026-07-11", snapshot: &proposedSnapshot, operations: &operations, checks: &checks, proposedAtIso: proposedAtIso)
            setStatementAnchor(id: capitalOneCardID, name: "Capital One", target: "2026-07-09", snapshot: &proposedSnapshot, operations: &operations, checks: &checks, proposedAtIso: proposedAtIso)

            proposedCollection.accounts[activeIndex].snapshot = proposedSnapshot
            proposedCollection.accounts[activeIndex].updatedAt = proposedAtIso
            proposedCollection.updatedAt = proposedAtIso
        }

        let beforeMetrics = metrics(snapshot: beforeSnapshot)
        let proposedMetrics = metrics(snapshot: proposedSnapshot)
        checks += invariantChecks(before: beforeMetrics, proposed: proposedMetrics, beforeSnapshot: beforeSnapshot, proposedSnapshot: proposedSnapshot)

        return PersonalJuly2026LiveRepairPlan(
            server: server,
            cache: cache,
            backups: backups,
            proposedAtIso: proposedAtIso,
            operations: checks.contains(where: { !$0.passed }) ? [] : operations,
            checks: checks,
            beforeCollection: beforeCollection,
            proposedCollection: proposedCollection,
            beforeMetrics: beforeMetrics,
            proposedMetrics: proposedMetrics,
            payPeriodClassification: payPeriodClassification,
            jajaProvenance: jajaProvenance,
            jajaLossExplanation: jajaLossExplanation,
            stateClassification: checks.contains(where: { !$0.passed }) ? .invalid : stateClassification
        )
    }

    static func canonicalData(for collection: PlannerAccountCollection) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(collection)
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validateServerRead(_ record: PersonalJuly2026LiveRepairReadRecord) -> [PersonalJuly2026LiveRepairCheck] {
        [
            check("Authoritative read source", expected: "server", actual: record.source.rawValue, passed: record.source == .server, detail: "Cache-only reads cannot authorise a plan."),
            check("Authoritative read metadata", expected: "isFromCache=false", actual: "isFromCache=\(record.isFromCache)", passed: !record.isFromCache, detail: "Firebase must confirm a server result."),
            check("Server concurrency token", expected: "server timestamp and canonical hash", actual: "\(record.serverUpdatedAtIso ?? "missing") / \(record.canonicalSHA256)", passed: record.serverUpdatedAtIso != nil && !record.canonicalSHA256.isEmpty, detail: "A later live transaction must compare both values.")
        ]
    }

    private static func fingerprintChecks(snapshot: PlannerSnapshot) -> [PersonalJuly2026LiveRepairCheck] {
        let expectedCards = ["barclays": 80_000, "capital one": 55_000, "jaja": 25_000, "zable": 50_000, "aqua": 130_000]
        let expectedBills = ["apple care": 899, "car insurance": 8_711, "icloud+": 899, "chatgpt": 8_900, "gym": 2_299, "runna": 1_599, "skin+me": 2_499]
        let cards = activeCards(snapshot)
        let bills = activeBills(snapshot)
        var checks = [
            check("Active card count", expected: "5", actual: "\(cards.count)", passed: cards.count == 5, detail: "Archived/deleted cards are excluded."),
            check("Active bill count", expected: "7", actual: "\(bills.count)", passed: bills.count == 7, detail: "Inactive/deleted bills are excluded.")
        ]

        let activeTransactions = snapshot.transactions.filter { $0.deletedAt == nil }
        let activeAllocations = snapshot.potAllocations.filter { $0.deletedAt == nil }
        let duplicateIdentityGroups: [(String, [String])] = [
            ("cards", duplicateIDs(cards.map(\.id))),
            ("bills", duplicateIDs(bills.map(\.id))),
            ("pots", duplicateIDs(activePots(snapshot).map(\.id))),
            ("transactions", duplicateIDs(activeTransactions.map(\.id))),
            ("allocations", duplicateIDs(activeAllocations.map(\.id))),
            ("paychecks", duplicateIDs(snapshot.paychecks.filter { $0.deletedAt == nil }.map(\.id))),
            ("repayments", duplicateIDs(snapshot.creditCardRepayments.filter { $0.deletedAt == nil }.map(\.id)))
        ]
        let unexpectedDuplicateIDs = duplicateIdentityGroups.flatMap { group, ids in ids.map { "\(group):\($0)" } }
        checks.append(check(
            "Unexpected duplicate stable identifiers",
            expected: "none outside the separately classified July pay-period pair",
            actual: unexpectedDuplicateIDs.isEmpty ? "none" : unexpectedDuplicateIDs.joined(separator: ", "),
            passed: unexpectedDuplicateIDs.isEmpty,
            detail: "Duplicate identities in active financial records invalidate the plan. The known July pay-period pair is classified independently."
        ))

        for (name, limit) in expectedCards {
            let matches = cards.filter { normalized($0.name) == name && $0.limitPence == limit }
            checks.append(check("Card fingerprint: \(name)", expected: MoneyParser.formatPence(limit), actual: "\(matches.count) exact match(es)", passed: matches.count == 1, detail: "Name and limit must uniquely identify the card."))
        }
        for (name, amount) in expectedBills {
            let matches = bills.filter { normalized($0.name) == name && $0.amountPence == amount }
            checks.append(check("Bill fingerprint: \(name)", expected: MoneyParser.formatPence(amount), actual: "\(matches.count) exact match(es)", passed: matches.count == 1, detail: "Name and amount must uniquely identify the bill."))
        }

        let expectedBalances = ["barclays": 65_443, "capital one": 20_237, "jaja": 21_580, "zable": 0, "aqua": 31_430]
        let period = currentJulyPeriod(snapshot)
        for (name, expected) in expectedBalances {
            let actual = cards.first { normalized($0.name) == name }.map {
                PlannerDerivedData.creditCardOwedSummary(card: $0, snapshot: snapshot, payPeriod: period, asOfDate: asOfDate).actualOwedPence
            }
            checks.append(check("Card balance: \(name)", expected: MoneyParser.formatPence(expected), actual: actual.map { MoneyParser.formatPence($0) } ?? "missing", passed: actual == expected, detail: "Calculated from persisted opening balance, transactions, and repayments."))
        }

        let iCloudBill = bills.first { normalized($0.name) == "icloud+" }
        let barclays = cards.first { normalized($0.name) == "barclays" }
        let aqua = cards.first { normalized($0.name) == "aqua" }
        let aquaPot = activePots(snapshot).first { $0.linkedCreditCardId == aqua?.id }
        let linkedICloudTransactions = activeTransactions.filter {
            $0.recurringPaymentId == iCloudBill?.id
        }
        let exactICloudTransactions = linkedICloudTransactions.filter {
            $0.recurringPaymentId == iCloudBill?.id &&
            $0.creditCardId == barclays?.id &&
            $0.amountPence == 899 &&
            $0.date == asOfDate &&
            $0.type == .spending &&
            $0.paymentMethod == .creditCard
        }
        checks.append(check(
            "Posted iCloud transaction",
            expected: "1 linked transaction and 1 exact £8.99 card-spend match on 10 July",
            actual: "\(linkedICloudTransactions.count) linked / \(exactICloudTransactions.count) exact",
            passed: linkedICloudTransactions.count == 1 && exactICloudTransactions.count == 1,
            detail: "An extra linked transaction, duplicate amount, wrong date, or wrong card invalidates the plan."
        ))

        let activePeriodID = currentJulyPeriod(snapshot)?.id
        let iCloudAllocationCount = activeAllocations.filter { allocation in
                allocation.payPeriodId == activePeriodID &&
                allocation.recurringPaymentId == iCloudBill?.id &&
                allocation.potId == iCloudBill?.potId &&
                allocation.recurringDueDate == "2026-07-10" &&
                allocation.source == .recurringBillFunding &&
                allocation.amountPence == 899
            }.count
        let runnaAllocationCount = activeAllocations.filter { allocation in
                allocation.payPeriodId == activePeriodID &&
                bills.contains { normalized($0.name) == "runna" && allocation.recurringPaymentId == $0.id && allocation.potId == $0.potId } &&
                allocation.recurringDueDate == "2026-07-18" && allocation.source == .recurringBillFunding && allocation.amountPence == 1_599
            }.count
        let appleCareAllocationCount = activeAllocations.filter { allocation in
                allocation.payPeriodId == activePeriodID &&
                bills.contains { normalized($0.name) == "apple care" && allocation.recurringPaymentId == $0.id && allocation.potId == $0.potId } &&
                allocation.recurringDueDate == "2026-07-19" && allocation.source == .recurringBillFunding && allocation.amountPence == 899
            }.count
        let aquaAllocationCount = activeAllocations.filter { allocation in
                allocation.payPeriodId == activePeriodID &&
                allocation.creditCardId == aqua?.id &&
                allocation.potId == aquaPot?.id &&
                allocation.source == .cardOpeningBalanceFunding &&
                allocation.creditCardDirectDebitDate == "2026-07-20" &&
                allocation.amountPence == 12_843
            }.count
        let expectedAllocationMatches = [iCloudAllocationCount, runnaAllocationCount, appleCareAllocationCount, aquaAllocationCount]
        checks.append(check("Four July funding allocations", expected: "4 exact allocations", actual: "\(activeAllocations.count) active; matches \(expectedAllocationMatches)", passed: activeAllocations.count == 4 && expectedAllocationMatches.allSatisfy { $0 == 1 }, detail: "No fifth allocation may be introduced."))
        return checks
    }

    private static func setStatementAnchor(
        id: String,
        name: String,
        target: String,
        snapshot: inout PlannerSnapshot,
        operations: inout [PersonalJuly2026LiveRepairOperation],
        checks: inout [PersonalJuly2026LiveRepairCheck],
        proposedAtIso: String
    ) {
        let matches = snapshot.creditCards.indices.filter {
            !snapshot.creditCards[$0].archived && snapshot.creditCards[$0].deletedAt == nil && snapshot.creditCards[$0].id == id
        }
        guard matches.count == 1, let index = matches.first else {
            checks.append(check("Statement anchor target: \(name)", expected: "one active card", actual: "\(matches.count)", passed: false, detail: "The card target is ambiguous."))
            return
        }

        let current = snapshot.creditCards[index].statementDate
        let allowedCurrent = name == "Barclays" ? ["2026-07-10", target] : ["2026-07-10", target]
        guard current.map(allowedCurrent.contains) == true else {
            checks.append(check("Statement anchor precondition: \(name)", expected: allowedCurrent.joined(separator: " or "), actual: current ?? "nil", passed: false, detail: "Unexpected statement-cycle data aborts the plan."))
            return
        }
        guard current != target else { return }
        snapshot.creditCards[index].statementDate = target
        snapshot.creditCards[index].updatedAt = proposedAtIso
        operations.append(.setStatementAnchor(cardId: snapshot.creditCards[index].id, cardName: name, from: current, to: target))
    }

    private static func metrics(snapshot: PlannerSnapshot) -> PersonalJuly2026LiveRepairMetrics? {
        guard let period = currentJulyPeriod(snapshot) else { return nil }
        let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: period, asOfDate: asOfDate)
        let cards = activeCards(snapshot)
        let availability = cards.map { PlannerDerivedData.creditCardAvailabilitySummary(card: $0, snapshot: snapshot, payPeriod: period, asOfDate: asOfDate) }
        let paychecks = snapshot.paychecks.filter { $0.deletedAt == nil && $0.payPeriodId == period.id }
        let recordedSpending = snapshot.transactions.filter {
            $0.deletedAt == nil && $0.type == .spending && $0.date >= period.startDate && $0.date <= asOfDate
        }.reduce(0) { $0 + max(0, $1.amountPence) }
        let cardNamesByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, normalized($0.name)) })
        let pots = activePots(snapshot).reduce(into: [String: Int]()) { result, pot in
            let identity = pot.linkedCreditCardId.flatMap { cardNamesByID[$0] } ?? normalized(pot.name)
            result[identity] = pot.balancePence
        }
        let repaymentIdCounts = Dictionary(grouping: snapshot.creditCardRepayments.filter { $0.deletedAt == nil }, by: \.id)

        return PersonalJuly2026LiveRepairMetrics(
            activeJulyPeriodCount: snapshot.payPeriods.filter { $0.deletedAt == nil && $0.status == .active && $0.startDate == "2026-07-01" && $0.endDate == "2026-07-31" }.count,
            incomePence: PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period),
            currentPaycheckCount: paychecks.filter { ($0.actualAmountPence ?? $0.calculatedAmountPence) == 340_663 }.count,
            zeroPaycheckCount: paychecks.filter { ($0.actualAmountPence ?? $0.calculatedAmountPence) == 0 }.count,
            unexpected1696PaycheckCount: paychecks.filter { ($0.actualAmountPence ?? $0.calculatedAmountPence) == 169_600 }.count,
            currentMoneyLeftPence: summary.currentMoneyLeftPence,
            safeToSpendPence: FinanceEngine.getDailySafeToSpendPence(spendablePence: summary.currentMoneyLeftPence, today: asOfDate, endDate: period.endDate),
            recordedSpendingPence: recordedSpending,
            activityNetPence: summary.payReceivedPence - recordedSpending,
            potBalances: pots,
            totalPotPence: pots.values.reduce(0, +),
            totalOwedPence: availability.reduce(0) { $0 + $1.actualOwedPence },
            totalAvailableCreditPence: availability.reduce(0) { $0 + $1.actualAvailablePence },
            forecastAvailabilityPence: availability.reduce(0) { $0 + $1.forecastAvailablePence },
            jajaDueDate: dueDate(cardNamed: "Jaja", snapshot: snapshot),
            capitalOneDueDate: dueDate(cardNamed: "Capital One", snapshot: snapshot),
            barclaysDueDate: dueDate(cardNamed: "Barclays", snapshot: snapshot),
            iCloudTransactionCount: snapshot.transactions.filter { transaction in
                transaction.deletedAt == nil && transaction.date == asOfDate && snapshot.recurringPayments.contains { normalized($0.name) == "icloud+" && transaction.recurringPaymentId == $0.id }
            }.count,
            activeAllocationCount: snapshot.potAllocations.filter { $0.deletedAt == nil }.count,
            duplicateRepaymentIdCount: repaymentIdCounts.values.filter { $0.count > 1 }.count
        )
    }

    private static func invariantChecks(
        before: PersonalJuly2026LiveRepairMetrics?,
        proposed: PersonalJuly2026LiveRepairMetrics?,
        beforeSnapshot: PlannerSnapshot,
        proposedSnapshot: PlannerSnapshot
    ) -> [PersonalJuly2026LiveRepairCheck] {
        guard let before, let proposed else {
            return [check("Production metrics", expected: "calculable", actual: "missing current July period", passed: false, detail: "No repair can proceed without production-derived metrics.")]
        }

        let expectedPots = ["insurance": 0, "jaja": 21_580, "capital one": 8_079, "zable": 0, "barclays": 53_183, "aqua": 30_731]
        var checks = [
            check("One active July period", expected: "1", actual: "\(proposed.activeJulyPeriodCount)", passed: proposed.activeJulyPeriodCount == 1, detail: "1–31 July only."),
            check("Current July income", expected: "£3,406.63", actual: MoneyParser.formatPence(proposed.incomePence), passed: proposed.incomePence == 340_663, detail: "Production effective income."),
            check("Current paycheck", expected: "1 × £3,406.63", actual: "\(proposed.currentPaycheckCount)", passed: proposed.currentPaycheckCount == 1, detail: "The existing paycheck remains linked."),
            check("Unexpected paychecks", expected: "no £0.00 / £1,696.00", actual: "\(proposed.zeroPaycheckCount) / \(proposed.unexpected1696PaycheckCount)", passed: proposed.zeroPaycheckCount == 0 && proposed.unexpected1696PaycheckCount == 0, detail: "No paycheck is created or removed."),
            check("Current Money Left", expected: "£3,244.23", actual: MoneyParser.formatPence(proposed.currentMoneyLeftPence), passed: proposed.currentMoneyLeftPence == expectedCurrentMoneyLeftPence, detail: "Uses currentMoneyLeftPence."),
            check("Safe to spend", expected: "£147.46", actual: MoneyParser.formatPence(proposed.safeToSpendPence), passed: proposed.safeToSpendPence == expectedSafeToSpendPence, detail: "£3,244.23 over 22 inclusive days."),
            check("Recorded spending", expected: "£8.99", actual: MoneyParser.formatPence(proposed.recordedSpendingPence), passed: proposed.recordedSpendingPence == 899, detail: "Exactly one posted iCloud transaction."),
            check("Activity net", expected: "£3,397.64", actual: MoneyParser.formatPence(proposed.activityNetPence), passed: proposed.activityNetPence == 339_764, detail: "Income minus recorded spending."),
            check("Total pots", expected: "£1,135.73", actual: MoneyParser.formatPence(proposed.totalPotPence), passed: proposed.totalPotPence == 113_573, detail: "Historical Jaja money is restored without new funding."),
            check("Total card owed", expected: "£1,386.90", actual: MoneyParser.formatPence(proposed.totalOwedPence), passed: proposed.totalOwedPence == 138_690, detail: "No card balance changes."),
            check("Available credit", expected: "£2,013.10", actual: MoneyParser.formatPence(proposed.totalAvailableCreditPence), passed: proposed.totalAvailableCreditPence == 201_310, detail: "£3,400.00 limits less owed."),
            check("Forecast availability", expected: "£1,988.12", actual: MoneyParser.formatPence(proposed.forecastAvailabilityPence), passed: proposed.forecastAvailabilityPence == 198_812, detail: "Remaining Runna and Apple Care charges."),
            check("Payment dates", expected: "Jaja 3 Aug; Capital One 2 Aug; Barclays 6 Aug", actual: "\(proposed.jajaDueDate ?? "nil"); \(proposed.capitalOneDueDate ?? "nil"); \(proposed.barclaysDueDate ?? "nil")", passed: proposed.jajaDueDate == "2026-08-03" && proposed.capitalOneDueDate == "2026-08-02" && proposed.barclaysDueDate == "2026-08-06", detail: "Derived from statement-cycle anchors and payment days."),
            check("Transaction/allocation identity", expected: "1 iCloud / 4 allocations / 0 duplicate repayments", actual: "\(proposed.iCloudTransactionCount) / \(proposed.activeAllocationCount) / \(proposed.duplicateRepaymentIdCount)", passed: proposed.iCloudTransactionCount == 1 && proposed.activeAllocationCount == 4 && proposed.duplicateRepaymentIdCount == 0, detail: "No extra financial record is created."),
            check("Jaja restoration does not reduce Money Left", expected: MoneyParser.formatPence(before.currentMoneyLeftPence), actual: MoneyParser.formatPence(proposed.currentMoneyLeftPence), passed: before.currentMoneyLeftPence == proposed.currentMoneyLeftPence, detail: "A historical balance restoration is not July funding."),
            check("Jaja restoration does not add allocation", expected: "\(before.activeAllocationCount)", actual: "\(proposed.activeAllocationCount)", passed: before.activeAllocationCount == proposed.activeAllocationCount, detail: "The existing four allocations remain unchanged."),
            check("Transactions unchanged", expected: canonicalHash(beforeSnapshot.transactions), actual: canonicalHash(proposedSnapshot.transactions), passed: beforeSnapshot.transactions == proposedSnapshot.transactions, detail: "The cloned repair never edits transactions."),
            check("Allocations unchanged", expected: canonicalHash(beforeSnapshot.potAllocations), actual: canonicalHash(proposedSnapshot.potAllocations), passed: beforeSnapshot.potAllocations == proposedSnapshot.potAllocations, detail: "The cloned repair never edits funding history.")
        ]
        for (name, expected) in expectedPots {
            let actual = proposed.potBalances[name]
            checks.append(check("Pot balance: \(name)", expected: MoneyParser.formatPence(expected), actual: actual.map { MoneyParser.formatPence($0) } ?? "missing", passed: actual == expected, detail: "Persisted balance field."))
        }

        var normalizedProposed = proposedSnapshot
        normalizedProposed.payPeriods = beforeSnapshot.payPeriods
        normalizedProposed.pots = normalizedProposed.pots.map { proposedPot in
            guard let beforePot = beforeSnapshot.pots.first(where: { $0.id == proposedPot.id }),
                  normalized(proposedPot.name) == "jaja" else { return proposedPot }
            var normalizedPot = proposedPot
            normalizedPot.balancePence = beforePot.balancePence
            normalizedPot.updatedAt = beforePot.updatedAt
            return normalizedPot
        }
        normalizedProposed.creditCards = normalizedProposed.creditCards.map { proposedCard in
            guard let beforeCard = beforeSnapshot.creditCards.first(where: { $0.id == proposedCard.id }),
                  ["barclays", "capital one"].contains(normalized(proposedCard.name)) else { return proposedCard }
            var normalizedCard = proposedCard
            normalizedCard.statementDate = beforeCard.statementDate
            normalizedCard.updatedAt = beforeCard.updatedAt
            return normalizedCard
        }
        checks.append(check(
            "No unrelated snapshot mutation",
            expected: canonicalHash(beforeSnapshot),
            actual: canonicalHash(normalizedProposed),
            passed: normalizedProposed == beforeSnapshot,
            detail: "After normalising the permitted period removal, Jaja balance/update timestamp, and two statement anchor/update timestamps, the entire cloned snapshot must match the server snapshot byte-for-byte after canonical encoding."
        ))
        return checks
    }

    private static func dueDate(cardNamed name: String, snapshot: PlannerSnapshot) -> String? {
        guard let card = activeCards(snapshot).first(where: { normalized($0.name) == normalized(name) }) else { return nil }
        return PlannerDerivedData.creditCardOpeningBalanceDirectDebitDate(card: card, today: asOfDate)
    }

    private static func currentJulyPeriod(_ snapshot: PlannerSnapshot) -> PayPeriod? {
        snapshot.payPeriods.first {
            $0.deletedAt == nil && $0.status == .active && $0.startDate == "2026-07-01" && $0.endDate == "2026-07-31" && $0.incomePence == 340_663
        }
    }

    private static func activeCards(_ snapshot: PlannerSnapshot) -> [CreditCard] {
        snapshot.creditCards.filter { !$0.archived && $0.deletedAt == nil }
    }

    private static func activeBills(_ snapshot: PlannerSnapshot) -> [RecurringPayment] {
        snapshot.recurringPayments.filter { $0.active && $0.deletedAt == nil }
    }

    private static func activePots(_ snapshot: PlannerSnapshot) -> [Pot] {
        snapshot.pots.filter { !$0.archived && $0.deletedAt == nil }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func duplicateIDs(_ ids: [String]) -> [String] {
        Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
    }

    private static func explainJajaTransition(current: Pot, backup: PersonalJuly2026LiveRepairReadRecord) -> String {
        guard let previous = backup.collection.activeAccount?.snapshot.pots.first(where: { normalized($0.name) == "jaja" && $0.balancePence == 21_580 }) else {
            return "The exact command is not determinable from retained model state."
        }
        if previous.id != current.id {
            return "The active Jaja pot was replaced: historical pot \(previous.id) held £215.80, while current pot \(current.id) was created/relinked at £0.00."
        }
        return "The same Jaja pot changed from £215.80 to £0.00 between server versions; no compensating allocation is present, so the initiating command is not determinable from the snapshot alone."
    }

    private static func invalidPlan(
        server: PersonalJuly2026LiveRepairReadRecord,
        cache: PersonalJuly2026LiveRepairReadRecord?,
        backups: [PersonalJuly2026LiveRepairReadRecord],
        checks: [PersonalJuly2026LiveRepairCheck],
        collection: PlannerAccountCollection,
        proposedAtIso: String
    ) -> PersonalJuly2026LiveRepairPlan {
        PersonalJuly2026LiveRepairPlan(
            server: server,
            cache: cache,
            backups: backups,
            proposedAtIso: proposedAtIso,
            operations: [],
            checks: checks,
            beforeCollection: collection,
            proposedCollection: collection,
            beforeMetrics: collection.activeAccount.flatMap { metrics(snapshot: $0.snapshot) },
            proposedMetrics: nil,
            payPeriodClassification: "Not evaluated because authoritative preconditions failed.",
            jajaProvenance: "Not evaluated.",
            jajaLossExplanation: "Not evaluated.",
            stateClassification: .invalid
        )
    }

    private static func check(_ name: String, expected: String, actual: String, passed: Bool, detail: String) -> PersonalJuly2026LiveRepairCheck {
        PersonalJuly2026LiveRepairCheck(name: name, expected: expected, actual: actual, passed: passed, detail: detail)
    }

    static func canonicalHash<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)).map(sha256) ?? "encoding-failed"
    }
}
#endif
