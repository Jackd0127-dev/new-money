import Foundation
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

struct FullAppLogicTortureJulSep2027SimulationResult {
    var fixtureSeeded: Bool
    var dailyRowCount: Int
    var rowCounts: [String: Int]
    var actualJsonPath: String
}

enum FullAppCellValue: Encodable {
    case blank
    case number(Double)
    case text(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .blank:
            try container.encodeNil()
        case .number(let value):
            try container.encode(value)
        case .text(let value):
            try container.encode(value)
        }
    }
}

struct FullAppSheetPayload: Encodable {
    var name: String
    var headers: [String]
    var rows: [[FullAppCellValue]]
}

struct FullAppSimulationPayload: Encodable {
    var generatedAt: String
    var fixtureSeeded: Bool
    var startDate: String
    var endDate: String
    var rowCounts: [String: Int]
    var sheets: [FullAppSheetPayload]
}

@MainActor
enum FullAppLogicTortureJulSep2027Simulation {
    static func runAndWriteArtifacts() async throws -> FullAppLogicTortureJulSep2027SimulationResult {
        let fixtureRepository = PlannerLaunchProfile.repository(environment: [
            PlannerLaunchProfile.fixtureEnvironmentKey: PlannerLaunchProfile.fullAppLogicTortureJulSep2027FixtureValue
        ])
        let fixtureSeeded = fixtureRepository is InMemoryPlannerRepository
        let seedSnapshot = try await fixtureRepository.loadSnapshot()
        let store = PlannerStore(repository: fixtureRepository)
        store.useSnapshotForSimulation(seedSnapshot)

        var runner = FullAppSimulationRunner(store: store)
        let sheets = runner.run()
        let rowCounts = Dictionary(uniqueKeysWithValues: sheets.map { ($0.name, $0.rows.count) })
        let outputDirectory = try TestArtifacts.directory(for: "full_app_simulation_jul_sep_2027")
        let actualJsonURL = outputDirectory.appendingPathComponent("full_app_sim_actual_jul_sep_2027.json")
        let payload = FullAppSimulationPayload(
            generatedAt: DateUtilities.nowIsoString(),
            fixtureSeeded: fixtureSeeded,
            startDate: FullAppSimulationRunner.startDate,
            endDate: FullAppSimulationRunner.endDate,
            rowCounts: rowCounts,
            sheets: sheets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: actualJsonURL, options: [.atomic])

        return FullAppLogicTortureJulSep2027SimulationResult(
            fixtureSeeded: fixtureSeeded,
            dailyRowCount: rowCounts["Daily Actual"] ?? 0,
            rowCounts: rowCounts,
            actualJsonPath: actualJsonURL.path
        )
    }
}

@MainActor
struct FullAppSimulationRunner {
    static let startDate = "2027-07-01"
    static let endDate = "2027-09-30"

    private let store: PlannerStore
    private var dailyRows: [[FullAppCellValue]] = []
    private var checklistRows: [[FullAppCellValue]] = []
    private var transactionRows: [[FullAppCellValue]] = []
    private var paydayRows: [[FullAppCellValue]] = []
    private var dailySummaries: [DailySummary] = []

    init(store: PlannerStore) {
        self.store = store
    }

    mutating func run() -> [FullAppSheetPayload] {
        transactionRows = openingBalanceTransactionRows(snapshot: store.snapshot)

        var currentDate = Self.startDate
        while currentDate <= Self.endDate {
            store.setManualTodayForSimulation(currentDate)
            simulateDay(currentDate)
            currentDate = FinanceEngine.addIsoDays(date: currentDate, days: 1)
        }

        return [
            FullAppSheetPayload(name: "Daily Actual", headers: Self.dailyHeaders, rows: dailyRows),
            FullAppSheetPayload(name: "Dates That Matter Actual", headers: Self.datesThatMatterHeaders, rows: datesThatMatterRows()),
            FullAppSheetPayload(name: "Payday Snapshots Actual", headers: Self.paydayHeaders, rows: paydayRows),
            FullAppSheetPayload(name: "Checklist Actual", headers: Self.checklistHeaders, rows: checklistRows),
            FullAppSheetPayload(name: "Transactions Actual", headers: Self.transactionHeaders, rows: transactionRows.sorted(by: sortRowsByFirstDateThenText)),
            FullAppSheetPayload(name: "Statements Actual", headers: Self.statementHeaders, rows: statementRows()),
            FullAppSheetPayload(name: "DD Payments Actual", headers: Self.ddPaymentHeaders, rows: ddPaymentRows()),
            FullAppSheetPayload(name: "Warning Periods Actual", headers: Self.warningPeriodHeaders, rows: warningPeriodRows()),
        ]
    }

    private mutating func simulateDay(_ date: String) {
        var events: [String] = []
        var checklistAddedPence = 0
        var paydaySnapshotDraft: PaydaySnapshotDraft?

        if let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date),
           period.payday == date {
            let beforeChecklistCount = checklistRows.count
            let beforeChecklistPence = checklistAddedPence

            let recurringItems = PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
            for item in recurringItems where !item.isCompleted {
                checklistRows.append(checklistRow(
                    dateAdded: date,
                    item: "\(item.paymentName) - \(monthName(for: period.startDate)) funding",
                    amountPence: item.amountPence,
                    potId: potCode(item.potId),
                    cardId: item.cardId.map(cardCode),
                    reason: "payday monthly funding",
                    datesCovered: shortSlashDate(item.dueDate),
                    autoTicked: true
                ))
                checklistAddedPence += item.amountPence
                _ = store.setRecurringBillFundingCompleted(
                    paymentId: item.paymentId,
                    dueDate: item.dueDate,
                    payPeriodId: item.payPeriodId,
                    completed: true
                )
            }

            let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
            for item in openingItems where !item.isCompleted {
                checklistRows.append(checklistRow(
                    dateAdded: date,
                    item: "\(cardCode(item.cardId)) opening balance funding",
                    amountPence: item.amountPence,
                    potId: potCode(item.potId),
                    cardId: cardCode(item.cardId),
                    reason: "opening balance funding",
                    datesCovered: shortSlashDate(item.directDebitDate),
                    autoTicked: true
                ))
                checklistAddedPence += item.amountPence
                _ = store.setCardOpeningBalanceFundingCompleted(
                    cardId: item.cardId,
                    directDebitDate: item.directDebitDate,
                    payPeriodId: item.payPeriodId,
                    completed: true
                )
            }

            let addedCount = checklistRows.count - beforeChecklistCount
            let addedPence = checklistAddedPence - beforeChecklistPence
            let incomeAfterTick = incomeRemainingPence(on: date)
            events.append("Payday +\(formatPounds(period.incomePence)); checklist funded \(formatPounds(addedPence)) across \(addedCount) items")
            paydaySnapshotDraft = PaydaySnapshotDraft(
                date: date,
                month: monthYear(for: date),
                incomeBeforeTickPence: period.incomePence,
                checklistCount: addedCount,
                checklistAmountPence: addedPence,
                incomeAfterTickBeforeDueProcessingPence: incomeAfterTick,
                openingFundingIncluded: openingItems.contains { !$0.isCompleted }
            )
        }

        let scheduledTransactionIdsBefore = Set(store.snapshot.transactions.map(\.id))
        _ = store.applyDueScheduledPaymentsForSimulation(asOf: date)
        let scheduledTransactions = store.snapshot.transactions
            .filter { !scheduledTransactionIdsBefore.contains($0.id) }
            .sorted(by: sortTransactions)
        for transaction in scheduledTransactions {
            transactionRows.append(transactionRow(for: transaction, type: scheduledTransactionType(transaction)))
            events.append(eventDescription(for: transaction))
        }

        for action in DefaultData.fullAppLogicTortureJulSep2027ManualActions where action.date == date {
            guard let cardId = action.cardId else { continue }
            store.recordTransaction(
                potId: nil,
                creditCardId: cardId,
                paymentMethod: .creditCard,
                amountPence: action.amountPence,
                type: .spending,
                date: action.date,
                note: action.name
            )
            guard let transaction = store.snapshot.transactions.first(where: {
                $0.date == action.date &&
                $0.creditCardId == cardId &&
                $0.amountPence == action.amountPence &&
                $0.note == action.name
            }),
                  let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: action.date),
                  let checklistItem = PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: store.snapshot, payPeriod: period)
                    .first(where: { $0.transactionId == transaction.id })
            else { continue }

            checklistRows.append(checklistRow(
                dateAdded: date,
                item: "\(action.name) - manual card spend funding",
                amountPence: checklistItem.amountPence,
                potId: potCode(checklistItem.potId),
                cardId: cardCode(checklistItem.cardId),
                reason: "manual action funding",
                datesCovered: shortSlashDate(action.date),
                autoTicked: action.autoTickChecklist
            ))
            checklistAddedPence += checklistItem.amountPence
            if action.autoTickChecklist {
                _ = store.setCardSpendFundingCompleted(
                    transactionId: transaction.id,
                    payPeriodId: period.id,
                    completed: true
                )
            }
            transactionRows.append(transactionRow(for: transaction, type: "Manual card spend", fundingPotId: action.potId))
            events.append(manualEventDescription(action: action, transaction: transaction))
        }

        for summary in PlannerDerivedData.creditCardStatementSummaries(snapshot: store.snapshot, asOfDate: date)
            where summary.statementDate == date {
            events.append("\(cardCode(summary.cardId)) statement created \(formatPounds(summary.statementAmountPence)); due \(shortSlashDate(summary.directDebitDate))")
        }

        let repaymentIdsBefore = Set(store.snapshot.creditCardRepayments.map(\.id))
        _ = store.applyDueCreditCardPaymentsForSimulation(asOf: date)
        let newRepayments = store.snapshot.creditCardRepayments
            .filter { !repaymentIdsBefore.contains($0.id) }
            .sorted(by: sortRepayments)
        for repayment in newRepayments {
            events.append(ddPaymentEventDescription(repayment))
        }

        let warning = warningText(on: date)
        let dailyRow = makeDailyRow(date: date, events: events, checklistAddedPence: checklistAddedPence, warning: warning)
        dailyRows.append(dailyRow)
        dailySummaries.append(DailySummary(date: date, row: dailyRow, events: events.joined(separator: " | "), warning: warning))

        if let paydaySnapshotDraft {
            paydayRows.append(paydayRow(from: paydaySnapshotDraft, endOfDayWarning: warning, date: date))
        }
    }

    private func makeDailyRow(date: String, events: [String], checklistAddedPence: Int, warning: String) -> [FullAppCellValue] {
        let snapshot = store.snapshot
        let payPeriod = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)
        let incomeRemaining = incomeRemainingPence(on: date)
        let potProgressById = Dictionary(uniqueKeysWithValues: Self.potOrder.compactMap { potId -> (String, PotProgress)? in
            guard let pot = snapshot.pots.first(where: { $0.id == potId }) else { return nil }
            return (potId, PlannerDerivedData.potProgress(pot: pot, snapshot: snapshot, today: date))
        })
        let potById = Dictionary(uniqueKeysWithValues: snapshot.pots.map { ($0.id, $0) })
        let cardById = Dictionary(uniqueKeysWithValues: snapshot.creditCards.map { ($0.id, $0) })
        let reserveByCard = Dictionary(uniqueKeysWithValues: Self.cardOrder.map { ($0, cardReservePence(cardId: $0, asOfDate: date)) })
        let availabilityByCard = Dictionary(uniqueKeysWithValues: Self.cardOrder.compactMap { cardId -> (String, CreditCardAvailabilitySummary)? in
            guard let card = cardById[cardId] else { return nil }
            return (cardId, PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: snapshot, payPeriod: payPeriod, asOfDate: date))
        })

        var row: [FullAppCellValue] = [
            .text(date),
            .text(weekdayAbbreviation(date)),
            events.isEmpty ? .blank : .text(events.joined(separator: " | ")),
            money(checklistAddedPence),
            money(incomeRemaining),
            money(Self.potOrder.reduce(0) { $0 + (potProgressById[$1]?.targetPence ?? 0) }),
            money(Self.potOrder.reduce(0) { $0 + max(0, potById[$1]?.balancePence ?? 0) }),
            money(Self.cardOrder.reduce(0) { $0 + (reserveByCard[$1] ?? 0) }),
            money(Self.cardOrder.reduce(0) { total, cardId in
                guard let card = cardById[cardId] else { return total }
                return total + PlannerDerivedData.cardBalance(card: card, snapshot: snapshot)
            }),
        ]

        for potId in Self.potOrder {
            row.append(money(potProgressById[potId]?.targetPence ?? 0))
            row.append(money(potById[potId]?.balancePence ?? 0))
        }

        for cardId in Self.cardOrder {
            row.append(money(reserveByCard[cardId] ?? 0))
        }

        for cardId in Self.cardOrder {
            let balance = cardById[cardId].map { PlannerDerivedData.cardBalance(card: $0, snapshot: snapshot) } ?? 0
            let availability = availabilityByCard[cardId]
            let forecastRemaining = max(0, (availability?.forecastOwedPence ?? balance) - (availability?.actualOwedPence ?? balance))
            row.append(money(balance))
            row.append(money(forecastRemaining))
            row.append(money(availability?.actualAvailablePence ?? 0))
            row.append(money(availability?.forecastAvailablePence ?? 0))
        }

        row.append(warning.isEmpty ? .blank : .text(warning))
        return row
    }

    private func datesThatMatterRows() -> [[FullAppCellValue]] {
        var rows: [[FullAppCellValue]] = []
        var previousWarning = ""

        for summary in dailySummaries {
            let isPayday = summary.date.hasSuffix("-01")
            let warningChanged = summary.warning != previousWarning
            if !summary.events.isEmpty || warningChanged || isPayday {
                let reasonParts = [
                    summary.events.isEmpty ? nil : "event",
                    warningChanged ? "warning change" : nil,
                    isPayday ? "payday" : nil,
                ].compactMap { $0 }
                let row = summary.row
                rows.append([
                    row[0],
                    row[1],
                    .text(reasonParts.joined(separator: ", ")),
                    row[2],
                    row[4],
                    row[6],
                    row[7],
                    row[8],
                    row[28],
                    row[31],
                    row[32],
                    row[35],
                    row[36],
                    row[39],
                    row[40],
                    row[43],
                    row[44],
                    row[47],
                    row[48],
                ])
            }
            previousWarning = summary.warning
        }

        return rows
    }

    private func statementRows() -> [[FullAppCellValue]] {
        let snapshot = store.snapshot
        var rows: [[FullAppCellValue]] = []

        for card in snapshot.creditCards.sorted(by: { cardCode($0.id) < cardCode($1.id) }) {
            let openingStatementPence = max(0, card.openingStatementBalancePence ?? 0)
            if openingStatementPence > 0,
               let statementDate = card.statementDate,
               let directDebitDate = openingBalanceDirectDebitDate(for: card) {
                rows.append([
                    .text(cardCode(card.id)),
                    .text(statementDate),
                    .text(directDebitDate),
                    money(openingStatementPence),
                    .text("Created before run"),
                    .text("opening statement balance"),
                ])
            }
        }

        let summaries = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: "2027-10-31")
        for summary in summaries.sorted(by: sortStatementSummaries) {
            let isAlreadyIncludedOpeningStatement = snapshot.creditCards.contains {
                $0.id == summary.cardId &&
                $0.statementDate == summary.statementDate &&
                max(0, $0.openingStatementBalancePence ?? 0) > 0
            }
            if isAlreadyIncludedOpeningStatement { continue }

            rows.append([
                .text(cardCode(summary.cardId)),
                .text(summary.statementDate),
                .text(summary.directDebitDate),
                money(summary.statementAmountPence),
                .text(statementStatusLabel(statementDate: summary.statementDate)),
                .text(statementSources(summary.transactions)),
            ])
        }

        return rows
    }

    private func ddPaymentRows() -> [[FullAppCellValue]] {
        store.snapshot.creditCardRepayments
            .filter { $0.date >= Self.startDate && $0.date <= Self.endDate && $0.amountPence > 0 }
            .sorted(by: sortRepayments)
            .map { repayment in
                [
                    .text(repayment.date),
                    .text(cardCode(repayment.creditCardId)),
                    repayment.statementDate.map { FullAppCellValue.text($0) } ?? .blank,
                    money(repayment.amountPence),
                    .text(ddSourceBreakdown(repayment)),
                    .text(ddLabel(repayment)),
                ]
            }
    }

    private func warningPeriodRows() -> [[FullAppCellValue]] {
        var periods: [[FullAppCellValue]] = []
        var activeStart: String?
        var activeWarning = ""
        var previousDate: String?

        for summary in dailySummaries {
            if summary.warning != activeWarning {
                if let activeStart, !activeWarning.isEmpty, let previousDate {
                    periods.append(warningPeriodRow(startDate: activeStart, endDate: previousDate, warning: activeWarning))
                }
                activeStart = summary.warning.isEmpty ? nil : summary.date
                activeWarning = summary.warning
            }
            previousDate = summary.date
        }

        if let activeStart, !activeWarning.isEmpty, let previousDate {
            periods.append(warningPeriodRow(startDate: activeStart, endDate: previousDate, warning: activeWarning))
        }

        return periods
    }

    private func paydayRow(from draft: PaydaySnapshotDraft, endOfDayWarning: String, date: String) -> [FullAppCellValue] {
        [
            .text(draft.date),
            .text(draft.month),
            money(draft.incomeBeforeTickPence),
            .number(Double(draft.checklistCount)),
            money(draft.checklistAmountPence),
            money(draft.incomeAfterTickBeforeDueProcessingPence),
            .text(draft.openingFundingIncluded ? "Yes" : "No"),
            money(incomeRemainingPence(on: date)),
            money(Self.potOrder.reduce(0) { total, potId in
                total + max(0, store.snapshot.pots.first(where: { $0.id == potId })?.balancePence ?? 0)
            }),
            money(Self.cardOrder.reduce(0) { total, cardId in
                guard let card = store.snapshot.creditCards.first(where: { $0.id == cardId }) else { return total }
                return total + PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot)
            }),
            endOfDayWarning.isEmpty ? .blank : .text(endOfDayWarning),
        ]
    }

    private func openingBalanceTransactionRows(snapshot: PlannerSnapshot) -> [[FullAppCellValue]] {
        snapshot.creditCards
            .sorted { cardCode($0.id) < cardCode($1.id) }
            .compactMap { card -> [FullAppCellValue]? in
                let openingBalancePence = max(0, card.openingBalancePence ?? 0)
                guard openingBalancePence > 0,
                      let statementDate = card.statementDate,
                      let dueDate = openingBalanceDirectDebitDate(for: card)
                else { return nil }

                let potId = snapshot.pots.first { $0.linkedCreditCardId == card.id }?.id
                let note = (card.openingStatementBalancePence ?? 0) > 0
                    ? "Opening statement balance due during simulation."
                    : "Opening balance exists at app start but is not statemented yet."

                return [
                    .text(Self.startDate),
                    .text("Opening balance"),
                    .text("\(cardCode(card.id)) opening balance"),
                    money(openingBalancePence),
                    potId.map { FullAppCellValue.text(potCode($0)) } ?? .blank,
                    .text(cardCode(card.id)),
                    .text(statementDate),
                    .text(dueDate),
                    .text("Opening balance funding"),
                    .text(note),
                ]
            }
    }

    private func transactionRow(for transaction: Transaction, type: String, fundingPotId: String? = nil) -> [FullAppCellValue] {
        let card = transaction.creditCardId.flatMap { cardId in
            store.snapshot.creditCards.first { $0.id == cardId }
        }
        let statementDate: String?
        let dueDate: String?
        if let card {
            statementDate = statementDateForCard(card, chargeDate: transaction.date)
            dueDate = directDebitDateForCard(card, chargeDate: transaction.date)
        } else {
            statementDate = nil
            dueDate = nil
        }
        let potId = fundingPotId ?? transaction.potId

        return [
            .text(transaction.date),
            .text(type),
            .text(transaction.note),
            money(transaction.amountPence),
            potId.map { FullAppCellValue.text(potCode($0)) } ?? .blank,
            transaction.creditCardId.map { FullAppCellValue.text(cardCode($0)) } ?? .blank,
            statementDate.map { FullAppCellValue.text($0) } ?? .blank,
            dueDate.map { FullAppCellValue.text($0) } ?? .blank,
            .text(transaction.paymentMethod == .creditCard ? "Linked pot funding" : "Direct pot payment"),
            .text(transaction.recurringPaymentId == nil ? "Manual or one-off app transaction." : "Scheduled bill occurrence."),
        ]
    }

    private func checklistRow(
        dateAdded: String,
        item: String,
        amountPence: Int,
        potId: String,
        cardId: String?,
        reason: String,
        datesCovered: String,
        autoTicked: Bool
    ) -> [FullAppCellValue] {
        [
            .text(dateAdded),
            .text(item),
            money(amountPence),
            .text(potId),
            cardId.map { FullAppCellValue.text($0) } ?? .blank,
            .text(reason),
            .text(datesCovered),
            .text(autoTicked ? "Yes" : "No"),
        ]
    }

    private func warningPeriodRow(startDate: String, endDate: String, warning: String) -> [FullAppCellValue] {
        [
            .text(startDate),
            .text(endDate),
            .number(Double(FinanceEngine.getDaysInclusive(startDate: startDate, endDate: endDate))),
            .text(warning),
        ]
    }

    private func incomeRemainingPence(on date: String) -> Int {
        let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date)
        return PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: date).moneyLeftPence
    }

    private func cardReservePence(cardId: String, asOfDate: String) -> Int {
        let snapshot = store.snapshot
        let recurringReserve = snapshot.transactions.reduce(0) { total, transaction in
            guard transaction.deletedAt == nil,
                  transaction.paymentMethod == .creditCard,
                  transaction.creditCardId == cardId,
                  transaction.recurringPaymentId != nil,
                  transaction.potId != nil,
                  transaction.date <= asOfDate,
                  !isTransactionRepaid(transaction, asOfDate: asOfDate)
            else { return total }
            return total + max(0, transaction.amountPence)
        }
        let allocationReserve = snapshot.potAllocations.reduce(0) { total, allocation in
            guard allocation.deletedAt == nil,
                  allocation.creditCardId == cardId,
                  allocation.source == .cardSpendFunding,
                  !isAllocationRepaid(allocation, asOfDate: asOfDate)
            else { return total }
            return total + max(0, allocation.amountPence)
        }
        return recurringReserve + allocationReserve
    }

    private func isTransactionRepaid(_ transaction: Transaction, asOfDate: String) -> Bool {
        guard let cardId = transaction.creditCardId,
              let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
              let statementDate = statementDateForCard(card, chargeDate: transaction.date)
        else { return false }

        return store.snapshot.creditCardRepayments.contains {
            $0.deletedAt == nil &&
            $0.creditCardId == cardId &&
            $0.statementDate == statementDate &&
            $0.date <= asOfDate &&
            $0.amountPence > 0
        }
    }

    private func isAllocationRepaid(_ allocation: PotAllocation, asOfDate: String) -> Bool {
        guard let cardId = allocation.creditCardId else { return false }
        return store.snapshot.creditCardRepayments.contains {
            $0.deletedAt == nil &&
            $0.creditCardId == cardId &&
            ($0.directDebitDate ?? $0.date) == allocation.creditCardDirectDebitDate &&
            $0.date <= asOfDate &&
            $0.amountPence > 0
        }
    }

    private func warningText(on date: String) -> String {
        let period = PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: date)
        let warnings = Self.cardOrder.compactMap { cardId -> String? in
            guard let card = store.snapshot.creditCards.first(where: { $0.id == cardId }) else { return nil }
            let availability = PlannerDerivedData.creditCardAvailabilitySummary(card: card, snapshot: store.snapshot, payPeriod: period, asOfDate: date)
            if availability.actualAvailablePence < 0 {
                return "\(cardCode(cardId)) over limit by \(formatPounds(abs(availability.actualAvailablePence)))"
            }
            if availability.forecastAvailablePence < 0 {
                return "\(cardCode(cardId)) unsafe after forecast by \(formatPounds(abs(availability.forecastAvailablePence)))"
            }
            return nil
        }
        return warnings.joined(separator: "; ")
    }

    private func eventDescription(for transaction: Transaction) -> String {
        if transaction.paymentMethod == .creditCard,
           let cardId = transaction.creditCardId,
           let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
           let statementDate = statementDateForCard(card, chargeDate: transaction.date),
           let dueDate = directDebitDateForCard(card, chargeDate: transaction.date) {
            let pot = transaction.potId.map(potCode) ?? "unfunded pot"
            return "\(transaction.note) \(formatPounds(transaction.amountPence)) from \(pot) to \(cardCode(cardId)); statement \(shortSlashDate(statementDate)) due \(shortSlashDate(dueDate))"
        }

        let pot = transaction.potId.map(potCode) ?? "Pot"
        return "\(transaction.note) \(formatPounds(transaction.amountPence)) paid directly from \(pot); no card"
    }

    private func manualEventDescription(action: DefaultData.FullAppLogicTortureManualAction, transaction: Transaction) -> String {
        guard let cardId = transaction.creditCardId,
              let card = store.snapshot.creditCards.first(where: { $0.id == cardId }),
              let statementDate = statementDateForCard(card, chargeDate: transaction.date),
              let dueDate = directDebitDateForCard(card, chargeDate: transaction.date)
        else {
            return "Manual \(action.name) \(formatPounds(action.amountPence))"
        }

        return "Manual \(action.name) \(formatPounds(action.amountPence)) on \(cardCode(cardId)) via \(potCode(action.potId)); statement \(shortSlashDate(statementDate)) due \(shortSlashDate(dueDate))"
    }

    private func ddPaymentEventDescription(_ repayment: CreditCardRepayment) -> String {
        "\(cardCode(repayment.creditCardId)) DD paid \(formatPounds(repayment.amountPence)) (\(ddSourceBreakdown(repayment)))"
    }

    private func ddSourceBreakdown(_ repayment: CreditCardRepayment) -> String {
        var parts: [String] = []
        if let potContributionPence = repayment.potContributionPence, potContributionPence > 0 {
            if let potId = repayment.potId {
                parts.append("\(formatPounds(potContributionPence)) from \(potCode(potId))")
            } else {
                parts.append("\(formatPounds(potContributionPence)) from linked card pots")
            }
        }
        for reserveContributionPence in cardReserveContributionParts(for: repayment) {
            parts.append("\(formatPounds(reserveContributionPence)) from \(cardCode(repayment.creditCardId)) reserve")
        }
        if let paycheckContributionPence = repayment.paycheckContributionPence, paycheckContributionPence > 0 {
            parts.append("\(formatPounds(paycheckContributionPence)) from paycheck")
        }
        if parts.isEmpty {
            parts.append("\(formatPounds(repayment.amountPence)) automatic")
        }
        return parts.joined(separator: "; ")
    }

    private func cardReserveContributionParts(for repayment: CreditCardRepayment) -> [Int] {
        guard let statementDate = repayment.statementDate,
              let card = store.snapshot.creditCards.first(where: { $0.id == repayment.creditCardId })
        else { return [] }

        let recurringOrderById = Dictionary(uniqueKeysWithValues: store.snapshot.recurringPayments.enumerated().map { index, payment in
            (payment.id, index)
        })

        let scheduledReserveEntries = store.snapshot.transactions.compactMap { transaction -> ReserveContributionEntry? in
            guard transaction.deletedAt == nil,
                  transaction.paymentMethod == .creditCard,
                  transaction.creditCardId == repayment.creditCardId,
                  transaction.recurringPaymentId != nil,
                  transaction.potId != nil,
                  transaction.date <= repayment.date,
                  statementDateForCard(card, chargeDate: transaction.date) == statementDate
            else { return nil }

            let amountPence = max(0, transaction.amountPence)
            guard amountPence > 0 else { return nil }
            let recurringOrder = transaction.recurringPaymentId.flatMap { recurringOrderById[$0] } ?? Int.max
            return ReserveContributionEntry(
                date: transaction.date,
                order: recurringOrder,
                transactionId: transaction.id,
                amountPence: amountPence
            )
        }

        let manualReserveEntries = store.snapshot.potAllocations.compactMap { allocation -> ReserveContributionEntry? in
            guard allocation.deletedAt == nil,
                  allocation.source == .cardSpendFunding,
                  allocation.creditCardId == repayment.creditCardId,
                  let transactionId = allocation.transactionId,
                  let transaction = store.snapshot.transactions.first(where: {
                      $0.id == transactionId &&
                      $0.deletedAt == nil &&
                      $0.paymentMethod == .creditCard &&
                      $0.creditCardId == repayment.creditCardId &&
                      $0.date <= repayment.date
                  }),
                  statementDateForCard(card, chargeDate: allocation.transactionDate ?? transaction.date) == statementDate
            else { return nil }

            let amountPence = min(max(0, allocation.amountPence), max(0, transaction.amountPence))
            guard amountPence > 0 else { return nil }
            return ReserveContributionEntry(
                date: allocation.transactionDate ?? transaction.date,
                order: Int.max,
                transactionId: transaction.id,
                amountPence: amountPence
            )
        }

        let reserveCapacityPence = max(0, repayment.amountPence - max(0, repayment.potContributionPence ?? 0) - max(0, repayment.paycheckContributionPence ?? 0))
        var remainingReservePence = reserveCapacityPence
        var parts: [Int] = []
        for entry in (scheduledReserveEntries + manualReserveEntries).sorted(by: <) where remainingReservePence > 0 {
            let contributionPence = min(entry.amountPence, remainingReservePence)
            if contributionPence > 0 {
                parts.append(contributionPence)
                remainingReservePence -= contributionPence
            }
        }
        return parts
    }

    private func ddLabel(_ repayment: CreditCardRepayment) -> String {
        if let statementDate = repayment.statementDate {
            return "statement from \(slashDateWithYear(statementDate))"
        }
        return repayment.note
    }

    private func statementSources(_ transactions: [CreditCardStatementTransaction]) -> String {
        guard !transactions.isEmpty else { return "app statement summary" }
        return transactions.map { "\($0.name) \(formatPounds($0.amountPence))" }.joined(separator: "; ")
    }

    private func scheduledTransactionType(_ transaction: Transaction) -> String {
        transaction.paymentMethod == .creditCard ? "Scheduled card bill" : "Scheduled pot bill"
    }

    private func statementDateForCard(_ card: CreditCard, chargeDate: String) -> String? {
        guard var statementDate = card.statementDate,
              FinanceEngine.isIsoDate(statementDate)
        else { return nil }

        for _ in 0..<240 {
            if statementDate >= chargeDate {
                return statementDate
            }
            statementDate = PlannerDerivedData.addIsoMonthsClamped(date: statementDate, months: 1)
        }

        return nil
    }

    private func directDebitDateForCard(_ card: CreditCard, chargeDate: String) -> String? {
        guard let statementDate = statementDateForCard(card, chargeDate: chargeDate),
              let dueDay = card.dueDay
        else { return nil }

        return PlannerDerivedData.creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
    }

    private func openingBalanceDirectDebitDate(for card: CreditCard) -> String? {
        PlannerDerivedData.creditCardOpeningBalanceDirectDebitDate(card: card, today: Self.startDate)
    }

    private func statementStatusLabel(statementDate: String) -> String {
        if statementDate < Self.startDate {
            return "Created before run"
        }
        if statementDate > Self.endDate {
            return "Expected after run"
        }
        return "Created inside run"
    }

    private func sortRowsByFirstDateThenText(_ lhs: [FullAppCellValue], _ rhs: [FullAppCellValue]) -> Bool {
        let lhsDate = lhs.first?.sortString ?? ""
        let rhsDate = rhs.first?.sortString ?? ""
        if lhsDate == rhsDate {
            return lhs.map(\.sortString).joined(separator: "|") < rhs.map(\.sortString).joined(separator: "|")
        }
        return lhsDate < rhsDate
    }

    private func sortTransactions(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
        if lhs.date == rhs.date {
            return lhs.note < rhs.note
        }
        return lhs.date < rhs.date
    }

    private func sortRepayments(_ lhs: CreditCardRepayment, _ rhs: CreditCardRepayment) -> Bool {
        if lhs.date == rhs.date {
            return cardCode(lhs.creditCardId) < cardCode(rhs.creditCardId)
        }
        return lhs.date < rhs.date
    }

    private func sortStatementSummaries(_ lhs: CreditCardStatementSummary, _ rhs: CreditCardStatementSummary) -> Bool {
        if lhs.statementDate == rhs.statementDate {
            return cardCode(lhs.cardId) < cardCode(rhs.cardId)
        }
        return lhs.statementDate < rhs.statementDate
    }

    private func cardCode(_ cardId: String) -> String {
        Self.cardCodes[cardId] ?? cardId
    }

    private func potCode(_ potId: String) -> String {
        Self.potCodes[potId] ?? potId
    }

    private func money(_ pence: Int) -> FullAppCellValue {
        .number(Double(pence) / 100.0)
    }

    private func formatPounds(_ pence: Int) -> String {
        let absolutePence = abs(pence)
        let sign = pence < 0 ? "-" : ""
        if absolutePence % 100 == 0 {
            return "\(sign)£\(absolutePence / 100)"
        }
        return String(format: "\(sign)£%.2f", Double(absolutePence) / 100.0)
    }

    private func weekdayAbbreviation(_ isoDate: String) -> String {
        Self.weekdayFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func monthName(for isoDate: String) -> String {
        Self.monthFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func monthYear(for isoDate: String) -> String {
        Self.monthYearFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func shortSlashDate(_ isoDate: String) -> String {
        Self.shortSlashFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private func slashDateWithYear(_ isoDate: String) -> String {
        Self.slashWithYearFormatter.string(from: FinanceEngine.parseDate(isoDate))
    }

    private struct DailySummary {
        var date: String
        var row: [FullAppCellValue]
        var events: String
        var warning: String
    }

    private struct PaydaySnapshotDraft {
        var date: String
        var month: String
        var incomeBeforeTickPence: Int
        var checklistCount: Int
        var checklistAmountPence: Int
        var incomeAfterTickBeforeDueProcessingPence: Int
        var openingFundingIncluded: Bool
    }

    private struct ReserveContributionEntry: Comparable {
        var date: String
        var order: Int
        var transactionId: String
        var amountPence: Int

        static func < (lhs: ReserveContributionEntry, rhs: ReserveContributionEntry) -> Bool {
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }
            if lhs.order != rhs.order {
                return lhs.order < rhs.order
            }
            return lhs.transactionId < rhs.transactionId
        }
    }

    private static let potOrder = ["pot-pot1", "pot-pot2", "pot-pot3", "pot-pot4", "pot-pot5", "pot-pot6", "pot-pot7"]
    private static let cardOrder = ["card-cc1", "card-cc2", "card-cc3", "card-cc4", "card-cc5"]
    private static let potCodes = [
        "pot-pot1": "Pot1",
        "pot-pot2": "Pot2",
        "pot-pot3": "Pot3",
        "pot-pot4": "Pot4",
        "pot-pot5": "Pot5",
        "pot-pot6": "Pot6",
        "pot-pot7": "Pot7",
    ]
    private static let cardCodes = [
        "card-cc1": "CC1",
        "card-cc2": "CC2",
        "card-cc3": "CC3",
        "card-cc4": "CC4",
        "card-cc5": "CC5",
    ]

    private static let dailyHeaders = [
        "Date", "Day", "Events", "Checklist Added Today", "Income Remaining", "Total Pot Target",
        "Total Pot Balance", "Total Card Reserve", "Total Card Balance", "Pot1 Target", "Pot1 Balance",
        "Pot2 Target", "Pot2 Balance", "Pot3 Target", "Pot3 Balance", "Pot4 Target", "Pot4 Balance",
        "Pot5 Target", "Pot5 Balance", "Pot6 Target", "Pot6 Balance", "Pot7 Target", "Pot7 Balance",
        "CC1 Reserve", "CC2 Reserve", "CC3 Reserve", "CC4 Reserve", "CC5 Reserve", "CC1 Balance",
        "CC1 Forecast Remaining", "CC1 Actual Available", "CC1 Safe Available", "CC2 Balance",
        "CC2 Forecast Remaining", "CC2 Actual Available", "CC2 Safe Available", "CC3 Balance",
        "CC3 Forecast Remaining", "CC3 Actual Available", "CC3 Safe Available", "CC4 Balance",
        "CC4 Forecast Remaining", "CC4 Actual Available", "CC4 Safe Available", "CC5 Balance",
        "CC5 Forecast Remaining", "CC5 Actual Available", "CC5 Safe Available", "Warning",
    ]
    private static let datesThatMatterHeaders = [
        "Date", "Day", "Reason", "Events", "Income Remaining", "Total Pot Balance", "Total Card Reserve",
        "Total Card Balance", "CC1 Bal", "CC1 Safe", "CC2 Bal", "CC2 Safe", "CC3 Bal", "CC3 Safe",
        "CC4 Bal", "CC4 Safe", "CC5 Bal", "CC5 Safe", "Warning",
    ]
    private static let paydayHeaders = [
        "date", "month", "income_before_tick", "checklist_count", "checklist_amount",
        "income_after_tick_before_due_processing", "opening_funding_included", "income_end_of_day",
        "pot_balance_end_of_day", "card_balance_end_of_day", "warning_end_of_day",
    ]
    private static let checklistHeaders = ["date_added", "item", "amount", "pot_id", "card_id", "reason", "dates_covered", "auto_ticked"]
    private static let transactionHeaders = ["date", "type", "name", "amount", "pot_id", "card_id", "statement_date", "due_date", "funding_source", "note"]
    private static let statementHeaders = ["card_id", "statement_date", "due_date", "amount", "status", "sources"]
    private static let ddPaymentHeaders = ["date", "card_id", "statement_date", "amount_paid", "source_breakdown", "label"]
    private static let warningPeriodHeaders = ["start_date", "end_date", "days", "warning"]

    private static let weekdayFormatter = makeDateFormatter("EEE")
    private static let monthFormatter = makeDateFormatter("LLLL")
    private static let monthYearFormatter = makeDateFormatter("LLLL yyyy")
    private static let shortSlashFormatter = makeDateFormatter("dd/MM")
    private static let slashWithYearFormatter = makeDateFormatter("dd/MM/yyyy")

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

extension FullAppCellValue {
    var sortString: String {
        switch self {
        case .blank:
            return ""
        case .number(let value):
            return String(format: "%020.4f", value)
        case .text(let value):
            return value
        }
    }
}
