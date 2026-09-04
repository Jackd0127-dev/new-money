import SwiftUI

enum HistoryLayoutPolicy {
    static let toolbarMode = "none"
    static let showsPlaceholderOptions = false
    static let baselineLabel = "Baseline"
    static let editedLabel = "Edited"
    static let revertedLabel = "Reverted"
    static let filterLabels = ["All", "Out", "Cards", "Refunds", "System"]
    static let usesStableSourceTint = true
    static let sourceTintPlacement = "iconAndLeadingKeyline"
    static let detailEditTitle = "Edit"
}

private enum HistoryAuditFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case moneyOut = "Out"
    case cards = "Cards"
    case refunds = "Refunds"
    case system = "System"

    var id: String { rawValue }

    var accessibilityLabel: String {
        self == .moneyOut ? "Money out" : rawValue
    }
}

private struct HistoryAuditFilterBar: View {
    @Binding var selection: HistoryAuditFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HistoryAuditFilter.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.rawValue)
                        .font(.caption.weight(selection == option ? .bold : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Colors.primaryText)
                .background {
                    if selection == option {
                        Capsule(style: .continuous)
                            .fill(AppTheme.Colors.selectedFill)
                    }
                }
                .accessibilityLabel(option.accessibilityLabel)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(3)
        .background(AppTheme.Colors.surface, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(AppTheme.Colors.border.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("History filter")
        .accessibilityIdentifier("history-filter")
        // Keep the five navigation labels readable as one control. VoiceOver
        // still exposes each full label and every button retains a 44pt target.
        .dynamicTypeSize(.xSmall ... .large)
    }
}

private struct HistoryAuditPresentedEvent: Identifiable {
    var event: PlannerAuditEvent
    var relationshipKey: String
    var refundActivity: PlannerAuditRefundActivity?

    var id: String { event.id }

    static func make(event: PlannerAuditEvent, snapshot: PlannerSnapshot) -> HistoryAuditPresentedEvent {
        HistoryAuditPresentedEvent(
            event: event,
            relationshipKey: PlannerAuditEngine.relationshipKey(for: event, snapshot: snapshot),
            refundActivity: PlannerAuditEngine.refundActivity(for: event, snapshot: snapshot)
        )
    }
}

struct HistoryView: View {
    @ObservedObject var store: PlannerStore
    @State private var searchText = ""
    @State private var filter: HistoryAuditFilter = .all
    @State private var presentationCache = RevisionPresentationCache<PlannerPresentationRevision, [HistoryAuditPresentedEvent]>()

    var body: some View {
        ScreenScaffold(
            title: "History",
            subtitle: "Every recorded change and the totals it affected.",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            let events = filteredEvents
            VStack(spacing: AppTheme.Spacing.sm) {
                TextField("Search payments, statements, bills...", text: $searchText)
                    .textFieldStyle(AppTextFieldStyle())

                HistoryAuditFilterBar(selection: $filter)
            }

            if events.isEmpty {
                AppCard {
                    EmptyStateView(
                        title: "No matching history",
                        message: emptyStateMessage,
                        systemImage: "clock.arrow.circlepath"
                    )
                }
            } else {
                ForEach(groupedMonths(for: events), id: \.key) { month in
                    SectionTitle("\(month.key)  \(month.events.count) events")
                    AppCard {
                        ForEach(Array(month.events.enumerated()), id: \.element.id) { index, event in
                            NavigationLink {
                                HistoryAuditEventDetailView(store: store, eventId: event.event.id)
                            } label: {
                                HistoryAuditEventRow(event: event)
                            }
                            .buttonStyle(.plain)

                            if index < month.events.count - 1 {
                                AppDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var filteredEvents: [HistoryAuditPresentedEvent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return presentedEvents
            .filter { item in
                let event = item.event
                return switch filter {
                case .all:
                    true
                case .moneyOut:
                    event.changes.contains { [.transaction, .recurringPayment, .debtPayment, .potAllocation].contains($0.recordKind) }
                case .cards:
                    event.changes.contains { [.creditCard, .creditCardCycle, .creditCardRepayment, .creditCardPot].contains($0.recordKind) }
                case .refunds:
                    item.refundActivity != nil
                case .system:
                    event.origin == .system || event.action == .automatic
                }
            }
            .filter { item in
                guard !query.isEmpty else { return true }
                let event = item.event
                return event.title.localizedStandardContains(query)
                    || event.subtitle.localizedStandardContains(query)
                    || event.changes.contains { $0.recordName.localizedStandardContains(query) }
                    || refundSummary(item.refundActivity).localizedStandardContains(query)
            }
    }

    private var presentedEvents: [HistoryAuditPresentedEvent] {
        let key = PlannerPresentationRevision(
            accountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriodId: nil
        )
        return presentationCache.value(for: key) {
            let snapshot = store.snapshot
            return snapshot.auditEvents
                .map { HistoryAuditPresentedEvent.make(event: $0, snapshot: snapshot) }
                .sorted { $0.event.occurredAt > $1.event.occurredAt }
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private func groupedMonths(for events: [HistoryAuditPresentedEvent]) -> [(key: String, events: [HistoryAuditPresentedEvent])] {
        Dictionary(grouping: events) { item in
            Self.monthFormatter.string(from: FinanceEngine.parseDate(item.event.effectiveDate))
        }
        .map { (key: $0.key, events: $0.value) }
        .sorted { lhs, rhs in
            (lhs.events.first?.event.effectiveDate ?? "") > (rhs.events.first?.event.effectiveDate ?? "")
        }
    }

    private var emptyStateMessage: String {
        filter == .refunds
            ? "Refunds and later refund changes appear here."
            : "Inputs, payments, statements, edits, and calculated changes appear here."
    }
}

private struct HistoryAuditEventRow: View {
    var event: HistoryAuditPresentedEvent
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint.color.opacity(tint.foregroundOpacity))
                    .frame(width: min(iconSize, 36), height: min(iconSize, 36))
                    .background(tint.color.opacity(tint.backgroundOpacity), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.event.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HistoryAuditStatusPill(action: event.event.action)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("\(historyFullDate(event.event.effectiveDate)) · \(rowSubtitle)")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                if let amountPence = displayAmountPence {
                    Text(MoneyParser.formatPence(amountPence))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(amountColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .layoutPriority(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
        }
        .padding(.leading, AppTheme.Spacing.sm)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(tint.color.opacity(0.72))
                .frame(width: 2)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch event.event.action {
        case .baseline: "clock"
        case .created: "plus"
        case .edited: "pencil"
        case .deleted: "trash"
        case .reverted: "arrow.uturn.backward"
        case .automatic: "arrow.triangle.2.circlepath"
        }
    }

    private var tint: HistoryAuditTint {
        HistoryAuditTint.make(relationshipKey: event.relationshipKey)
    }

    private var rowSubtitle: String {
        let summary = refundSummary(event.refundActivity)
        return summary.isEmpty ? event.event.subtitle : summary
    }

    private var displayAmountPence: Int? {
        event.refundActivity?.displayAmountPence ?? event.event.amountPence
    }

    private var amountColor: Color {
        if let activity = event.refundActivity {
            return activity.transition == .removed ? AppTheme.Colors.secondaryText : AppTheme.Colors.success
        }
        return (event.event.amountPence ?? 0) < 0 ? AppTheme.Colors.success : AppTheme.Colors.primaryText
    }
}

private struct HistoryAuditTint {
    var color: Color
    var foregroundOpacity: Double
    var backgroundOpacity: Double

    static func make(relationshipKey: String) -> HistoryAuditTint {
        let colors = AppTheme.selectableColorHexes()
        guard !colors.isEmpty else {
            return HistoryAuditTint(color: AppTheme.Colors.primaryOrange, foregroundOpacity: 0.9, backgroundOpacity: 0.12)
        }

        let hash = PlannerAuditEngine.stableRelationshipHash(relationshipKey)
        let colorIndex = Int(hash % UInt64(colors.count))
        let shadeIndex = Int((hash / UInt64(colors.count)) % 3)
        let foregroundOpacities = [0.72, 0.86, 1.0]
        let backgroundOpacities = [0.09, 0.12, 0.16]
        return HistoryAuditTint(
            color: Color(hex: colors[colorIndex]),
            foregroundOpacity: foregroundOpacities[shadeIndex],
            backgroundOpacity: backgroundOpacities[shadeIndex]
        )
    }
}

struct HistoryAuditStatusPill: View {
    var action: PlannerAuditAction

    var body: some View {
        if let label {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(color)
                .textCase(.uppercase)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(color.opacity(0.14), in: Capsule())
                .accessibilityLabel(label)
        }
    }

    private var label: String? {
        switch action {
        case .baseline: HistoryLayoutPolicy.baselineLabel
        case .edited: HistoryLayoutPolicy.editedLabel
        case .reverted: HistoryLayoutPolicy.revertedLabel
        case .automatic: "Automatic"
        case .created, .deleted: nil
        }
    }

    private var color: Color {
        switch action {
        case .reverted: AppTheme.Colors.success
        case .baseline: AppTheme.Colors.secondaryText
        case .created, .edited, .deleted, .automatic: AppTheme.Colors.primaryOrange
        }
    }
}

private struct HistoryAuditEventDetailView: View {
    @ObservedObject var store: PlannerStore
    var eventId: String
    @State private var presentedEditor: HistoryAuditEditTarget?

    private var event: PlannerAuditEvent? {
        store.snapshot.auditEvents.first { $0.id == eventId }
    }

    private var editTarget: HistoryAuditEditTarget? {
        event.flatMap { HistoryAuditEditTarget.make(event: $0, snapshot: store.snapshot) }
    }

    var body: some View {
        ScreenScaffold(
            title: "Revision",
            subtitle: event?.title ?? "History record",
            navigationMode: .inline,
            toolbarMode: .none,
            titleDisplayMode: .inline
        ) {
            if let event, let primary = event.changes.first {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(PlannerAuditEngine.displayName(for: primary.recordKind))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                            .textCase(.uppercase)
                        HistoryAuditStatusPill(action: event.action)
                    }
                    Text(primary.recordName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(historyFullDate(primary.effectiveDate)) · recorded \(historyFullDate(event.occurredAt))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                SectionTitle("What changed")
                HStack(spacing: 0) {
                    HistoryAuditVersionColumn(title: "Previous", summary: AuditRecordSummary.make(kind: primary.recordKind, json: primary.beforeJSON))
                    AppDivider().frame(width: 1)
                    HistoryAuditVersionColumn(title: "Current", summary: AuditRecordSummary.make(kind: primary.recordKind, json: primary.afterJSON))
                }
                .padding(.vertical, AppTheme.Spacing.sm)

                if !event.effects.isEmpty {
                    SectionTitle("Affected results")
                    AppCard {
                        ForEach(event.effects) { effect in
                            MetricRow(
                                label: effect.label,
                                value: signedMoney(effect.deltaPence),
                                valueColor: effect.deltaPence < 0 ? AppTheme.Colors.success : AppTheme.Colors.primaryOrange
                            )
                        }
                    }
                }

                SectionTitle("Versions")
                AppCard {
                    let versions = store.auditEvents(for: primary.recordKind, id: primary.recordId)
                    ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Circle()
                                .fill(version.id == event.id ? AppTheme.Colors.primaryOrange : AppTheme.Colors.tertiaryText)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(version.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(historyFullDate(version.occurredAt))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }
                            Spacer()
                            if version.id != versions.first?.id,
                               version.changes.first(where: { $0.recordKind == primary.recordKind && $0.recordId == primary.recordId })?.afterJSON != nil {
                                Button("Restore") {
                                    _ = store.restoreAuditRecord(kind: primary.recordKind, id: primary.recordId, to: version.id)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                                .buttonStyle(.plain)
                            }
                        }
                        if index < versions.count - 1 { AppDivider() }
                    }
                }

                if store.auditAction(for: primary.recordKind, id: primary.recordId) == .edited {
                    SecondaryButton(title: "Reverse latest edit", systemImage: "arrow.uturn.backward") {
                        _ = store.reverseLatestEdit(for: primary.recordKind, id: primary.recordId)
                    }
                }
            } else {
                AppCard {
                    EmptyStateView(title: "History unavailable", message: "This revision could not be loaded.", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .toolbar {
            if let editTarget {
                ToolbarItem(id: "history-record-edit", placement: .topBarTrailing) {
                    Button(HistoryLayoutPolicy.detailEditTitle) {
                        presentedEditor = editTarget
                    }
                    .accessibilityHint("Edits the current source record while preserving this revision")
                    .accessibilityIdentifier("history-record-edit")
                }
            }
        }
        .sheet(item: $presentedEditor) { target in
            HistoryAuditEditorSheet(store: store, target: target)
        }
    }
}

enum HistoryAuditEditTarget: Equatable, Identifiable {
    case card(CreditCardBalanceHistoryEditTarget)
    case recurringBill(String)
    case debtPayment(String)
    case debt(String)
    case pot(String)
    case bankAccount(String)

    var id: String {
        switch self {
        case .card(let target): "card-history-\(target.id)"
        case .recurringBill(let id): "bill-\(id)"
        case .debtPayment(let id): "debt-payment-\(id)"
        case .debt(let id): "debt-\(id)"
        case .pot(let id): "pot-\(id)"
        case .bankAccount(let id): "bank-account-\(id)"
        }
    }

    static func make(event: PlannerAuditEvent, snapshot: PlannerSnapshot) -> HistoryAuditEditTarget? {
        for change in event.changes {
            switch change.recordKind {
            case .transaction:
                guard let transaction = snapshot.transactions.first(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                let target = CreditCardBalanceHistoryData.transactionEditTarget(
                    for: transaction,
                    snapshot: snapshot
                )
                if case .recurring(let paymentId, _) = target,
                   !snapshot.recurringPayments.contains(where: { $0.id == paymentId && $0.deletedAt == nil }) {
                    continue
                }
                return .card(target)
            case .recurringPayment:
                guard snapshot.recurringPayments.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .recurringBill(change.recordId)
            case .recurringOccurrence:
                guard let occurrence = snapshot.recurringPaymentOccurrenceOverrides.first(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }), snapshot.recurringPayments.contains(where: {
                    $0.id == occurrence.paymentId && $0.deletedAt == nil
                }) else { continue }
                return .card(.recurring(
                    paymentId: occurrence.paymentId,
                    scheduledDueDate: occurrence.scheduledDueDate
                ))
            case .creditCardRepayment:
                guard snapshot.creditCardRepayments.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .card(.repayment(change.recordId))
            case .creditCardCycle:
                guard let cycle = snapshot.creditCardCycleOverrides.first(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }), snapshot.creditCards.contains(where: {
                    $0.id == cycle.creditCardId && !$0.archived && $0.deletedAt == nil
                }) else { continue }
                return .card(.statement(
                    cardId: cycle.creditCardId,
                    scheduledStatementDate: cycle.scheduledStatementDate
                ))
            case .creditCard:
                guard snapshot.creditCards.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .card(.card(change.recordId))
            case .debtPayment:
                guard snapshot.debtPayments.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .debtPayment(change.recordId)
            case .debt:
                guard snapshot.debts.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .debt(change.recordId)
            case .pot:
                guard snapshot.pots.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .pot(change.recordId)
            case .bankAccount:
                guard snapshot.bankAccounts.contains(where: {
                    $0.id == change.recordId && $0.deletedAt == nil
                }) else { continue }
                return .bankAccount(change.recordId)
            default:
                continue
            }
        }
        return nil
    }
}

private struct HistoryAuditEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var target: HistoryAuditEditTarget

    @ViewBuilder
    var body: some View {
        switch target {
        case .card(let target):
            CreditCardBalanceHistoryEditorSheet(store: store, target: target)
        case .recurringBill(let id):
            if let payment = store.snapshot.recurringPayments.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    EditBillView(store: store, payment: payment)
                        .toolbar { closeToolbarItem }
                }
            } else {
                missingRecord
            }
        case .debtPayment(let id):
            if let payment = store.snapshot.debtPayments.first(where: { $0.id == id && $0.deletedAt == nil }) {
                DebtPaymentEditSheetView(store: store, payment: payment)
            } else {
                missingRecord
            }
        case .debt(let id):
            if let debt = store.snapshot.debts.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    DebtDetailScreenView(store: store, debt: debt)
                        .toolbar { closeToolbarItem }
                }
            } else {
                missingRecord
            }
        case .pot(let id):
            if let pot = store.snapshot.pots.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    PotEditView(store: store, pot: pot)
                        .toolbar { closeToolbarItem }
                }
            } else {
                missingRecord
            }
        case .bankAccount(let id):
            if let account = store.snapshot.bankAccounts.first(where: { $0.id == id && $0.deletedAt == nil }) {
                NavigationStack {
                    BankAccountFormView(store: store, account: account)
                }
            } else {
                missingRecord
            }
        }
    }

    @ToolbarContentBuilder
    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
    }

    private var missingRecord: some View {
        NavigationStack {
            ContentUnavailableView(
                "Record unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("This source record is no longer available to edit.")
            )
            .premiumScreenBackground()
            .toolbar { closeToolbarItem }
        }
    }
}

private struct HistoryAuditVersionColumn: View {
    var title: String
    var summary: AuditRecordSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Text(summary?.amountPence.map { MoneyParser.formatPence($0) } ?? "Not recorded")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text(summary.map { "\($0.name) · \(historyFullDate($0.date))" } ?? "No earlier version")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.sm)
    }
}

private struct AuditRecordSummary {
    var name: String
    var date: String
    var amountPence: Int?

    static func make(kind: PlannerAuditRecordKind, json: String?) -> AuditRecordSummary? {
        guard let json else { return nil }
        switch kind {
        case .transaction:
            return PlannerAuditEngine.decode(Transaction.self, json: json).map { .init(name: $0.note.nilIfBlank ?? "Payment", date: $0.date, amountPence: $0.netAmountPence) }
        case .recurringPayment:
            return PlannerAuditEngine.decode(RecurringPayment.self, json: json).map { .init(name: $0.name, date: $0.dueDate ?? $0.updatedAt, amountPence: $0.amountPence) }
        case .creditCardRepayment:
            return PlannerAuditEngine.decode(CreditCardRepayment.self, json: json).map { .init(name: $0.note.nilIfBlank ?? "Card payment", date: $0.date, amountPence: $0.netAmountPence) }
        case .creditCard:
            return PlannerAuditEngine.decode(CreditCard.self, json: json).map { .init(name: $0.name, date: $0.statementDate ?? $0.updatedAt, amountPence: $0.openingBalancePence) }
        case .creditCardCycle:
            return PlannerAuditEngine.decode(CreditCardCycleOverride.self, json: json).map { .init(name: "Card statement", date: $0.actualStatementDate ?? $0.scheduledStatementDate, amountPence: $0.amountPenceOverride) }
        case .paycheck:
            return PlannerAuditEngine.decode(Paycheck.self, json: json).map { .init(name: "Paycheck", date: $0.updatedAt, amountPence: $0.actualAmountPence ?? $0.calculatedAmountPence) }
        case .oneOffIncome:
            return PlannerAuditEngine.decode(OneOffIncome.self, json: json).map { .init(name: $0.name, date: $0.date, amountPence: $0.amountPence) }
        case .debtPayment:
            return PlannerAuditEngine.decode(DebtPayment.self, json: json).map { .init(name: $0.note.nilIfBlank ?? "Debt payment", date: $0.date, amountPence: $0.netAmountPence) }
        default:
            return nil
        }
    }
}

private func signedMoney(_ pence: Int) -> String {
    pence > 0 ? "+\(MoneyParser.formatPence(pence))" : MoneyParser.formatPence(pence)
}

private func refundSummary(_ activity: PlannerAuditRefundActivity?) -> String {
    guard let activity else { return "" }
    switch activity.transition {
    case .applied:
        return "Refunded \(MoneyParser.formatPence(activity.currentAmountPence))"
    case .increased:
        return "Refund increased to \(MoneyParser.formatPence(activity.currentAmountPence))"
    case .decreased:
        return "Refund reduced to \(MoneyParser.formatPence(activity.currentAmountPence))"
    case .removed:
        return "Refund removed"
    }
}

private func historyFullDate(_ value: String) -> String {
    let isoDate = String(value.prefix(10))
    return FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
