import Foundation
import SwiftUI

struct PotsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    @State private var query = ""
    @State private var selectedType: PotType?
    @State private var selectedPot: Pot?

    private var filteredPots: [Pot] {
        store.activePots.filter { pot in
            let matchesQuery = query.isEmpty
                || pot.name.localizedCaseInsensitiveContains(query)
                || (pot.category ?? "").localizedCaseInsensitiveContains(query)
            let matchesType = selectedType == nil || pot.type == selectedType
            return matchesQuery && matchesType
        }
    }

    private var pendingFundingContexts: [String: PotPendingFundingContext] {
        potPendingFundingContexts(snapshot: store.snapshot, payPeriod: store.selectedPayPeriod, today: store.todayIso)
    }

    var body: some View {
        ScreenScaffold(
            title: "Pots",
            subtitle: "Buckets for bills, spending, savings, investments, and buffers.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            summaryCard
            if !store.activePots.isEmpty {
                controls
            }
            potList
        }
        .sheet(item: $selectedPot) { pot in
            PotDetailView(store: store, pot: pot)
        }
    }

    private var summaryCard: some View {
        AppCard(glow: true) {
            MetricRow(
                label: "Total saved",
                value: MoneyParser.formatPence(store.activePots.reduce(0) { $0 + $1.balancePence }),
                valueColor: AppTheme.Colors.primaryOrange
            )
            MetricRow(label: "Active pots", value: "\(store.activePots.count)")
        }
    }

    private var controls: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("Search pots", text: $query)
                .textFieldStyle(AppTextFieldStyle())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    FilterChip(title: "All", isSelected: selectedType == nil) { selectedType = nil }
                    ForEach(PotType.allCases) { type in
                        FilterChip(title: type.rawValue.capitalized, isSelected: selectedType == type) { selectedType = type }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 3)
            }
            .scrollClipDisabled()
        }
    }

    private var potList: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if filteredPots.isEmpty {
                AppCard {
                    if store.activePots.isEmpty {
                        EmptyStateView(title: "Create your first pot", message: "Use Add in the toolbar to set up savings, bills, buffers, or goals.", systemImage: "wallet.pass")
                    } else {
                        EmptyStateView(title: "No pots match", message: "Adjust the search or clear the selected filter.", systemImage: "magnifyingglass")
                    }
                }
            } else {
                ForEach(filteredPots) { pot in
                    Button {
                        selectedPot = pot
                    } label: {
                        PotRow(
                            pot: pot,
                            linkedLabel: linkedTargetLabel(for: pot, in: store.snapshot),
                            progress: PlannerDerivedData.potProgress(pot: pot, snapshot: store.snapshot, today: store.todayIso),
                            pendingFundingContext: pendingFundingContexts[pot.id, default: .none],
                            today: store.todayIso
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FilterChip: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(AppTheme.Gradients.primary) : AnyShapeStyle(AppTheme.Colors.elevatedSurface))
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct PotPendingFundingContext {
    static let none = PotPendingFundingContext()

    var hasPendingChecklistFunding = false
    var hasProcessedDueItems = false
}

private struct PotRow: View {
    var pot: Pot
    var linkedLabel: String?
    var progress: PotProgress
    var pendingFundingContext: PotPendingFundingContext
    var today: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.md) {
                    Circle()
                        .fill(Color(hex: pot.color))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(pot.color.uppercased() == "#FFFFFF" ? AppTheme.Colors.border : .clear, lineWidth: 1)
                        )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pot.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(rowDetail)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(MoneyParser.formatPence(pot.balancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }

                PotProgressBlock(
                    progress: progress,
                    pendingFundingContext: pendingFundingContext,
                    balancePence: pot.balancePence,
                    today: today
                )
            }
        }
    }

    private var rowDetail: String {
        if let linkedLabel {
            return "\(pot.type.rawValue.capitalized) · \(linkedLabel)"
        }
        return "\(pot.type.rawValue.capitalized) · \(pot.category ?? "Uncategorised")"
    }
}

private struct PotProgressBlock: View {
    var progress: PotProgress
    var pendingFundingContext: PotPendingFundingContext
    var balancePence: Int
    var today: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if progress.targetPence > 0 {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Text("\(progress.percent)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.success)
                    Spacer(minLength: AppTheme.Spacing.sm)
                    Text(progress.targetLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                ProgressView(value: cappedProgressValue, total: 100)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.Colors.success)

                Text(potFundingStatusLabel(progress: progress))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(progress.shortfallPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
                    .lineLimit(1)

                pendingFundingContextLine

                if !progress.linkedCardPayments.isEmpty {
                    LinkedCardPaymentsBlock(payments: progress.linkedCardPayments)
                } else {
                    if let dueLabel = potDueLabel(progress: progress, today: today) {
                        Text(dueLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.warning)
                            .lineLimit(1)
                    }

                    if let laterLabel = potLaterLabel(progress: progress) {
                        Text(laterLabel)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                            .lineLimit(1)
                    }
                }
            } else {
                HStack {
                    Text("No target")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Spacer()
                    Text("Balance only")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }

                pendingFundingContextLine
            }

            if !progress.sourceLabels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(progress.sourceLabels.prefix(2)), id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.elevatedSurface)
                            .clipShape(Capsule())
                    }
                    if progress.sourceLabels.count > 2 {
                        Text("+\(progress.sourceLabels.count - 2)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.Colors.elevatedSurface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var cappedProgressValue: Double {
        Double(min(max(progress.percent, 0), 100))
    }

    @ViewBuilder
    private var pendingFundingContextLine: some View {
        if let text = pendingFundingContextText {
            Text(text)
                .font(.caption2)
                .foregroundStyle(pendingFundingContextColor)
                .lineLimit(2)
        }
    }

    private var pendingFundingContextText: String? {
        guard pendingFundingContext.hasPendingChecklistFunding else { return nil }

        if balancePence < 0 {
            return "Temporary until funding is ticked."
        }

        if pendingFundingContext.hasProcessedDueItems {
            return "Due items processed, funding not completed yet."
        }

        return "Pending checklist funding."
    }

    private var pendingFundingContextColor: Color {
        balancePence < 0 || pendingFundingContext.hasProcessedDueItems ? AppTheme.Colors.warning : AppTheme.Colors.tertiaryText
    }
}

private struct LinkedCardPaymentsBlock: View {
    var payments: [LinkedCardPaymentDue]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cardName = payments.first?.cardName {
                Text("Upcoming \(cardName) payments")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            ForEach(Array(payments.enumerated()), id: \.element.dueIso) { _, payment in
                HStack(spacing: 6) {
                    Text(shortDayMonth(payment.dueIso))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("- \(MoneyParser.formatPence(payment.amountPence)) due")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
            }
        }
    }
}

struct PotFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var type: PotType = .spending
    @State private var balance = ""
    @State private var target = ""
    @State private var color = "#E85002"
    @State private var linkType: PotLinkType = .none
    @State private var linkedEntityId = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.md) {
                    PotSetupFields(
                        store: store,
                        name: $name,
                        type: $type,
                        balance: $balance,
                        target: $target,
                        color: $color,
                        linkType: $linkType,
                        linkedEntityId: $linkedEntityId
                    )

                    PrimaryButton(title: "Add pot", systemImage: "plus", isDisabled: isSaveDisabled) {
                        store.addPot(
                            name: name,
                            type: type,
                            category: type.defaultCategory,
                            targetPence: target.potNilIfBlank.map { MoneyParser.parsePoundsToPence($0) },
                            color: color,
                            balancePence: MoneyParser.parsePoundsToPence(balance),
                            linkedCreditCardId: linkType == .creditCard ? linkedEntityId.potNilIfBlank : nil,
                            linkedDebtId: linkType == .debt ? linkedEntityId.potNilIfBlank : nil
                        )
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add pot")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var isSaveDisabled: Bool {
        name.potTrimmed.isEmpty || !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store)
    }
}

struct PotHistorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var selectedMode: PotHistoryMode = .allHistory

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    Picker("History", selection: $selectedMode) {
                        ForEach(PotHistoryMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(AppTheme.Colors.primaryOrange)

                    if rows.isEmpty {
                        AppCard {
                            EmptyStateView(
                                title: selectedMode.emptyTitle,
                                message: selectedMode.emptyMessage,
                                systemImage: "receipt"
                            )
                        }
                    } else {
                        VStack(spacing: AppTheme.Spacing.md) {
                            ForEach(rows) { row in
                                PotHistoryRowView(row: row)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Pots history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var rows: [PotHistoryRow] {
        switch selectedMode {
        case .topUps:
            topUpRows
        case .payments:
            paymentRows
        case .allHistory:
            (topUpRows + paymentRows).sorted(by: sortRows)
        }
    }

    private var topUpRows: [PotHistoryRow] {
        let allocationRows = store.snapshot.potAllocations
            .filter { $0.deletedAt == nil }
            .compactMap { allocation -> PotHistoryRow? in
                guard let pot = pot(for: allocation.potId) else { return nil }
                let period = store.snapshot.payPeriods.first { $0.id == allocation.payPeriodId }
                return PotHistoryRow(
                    id: allocation.id,
                    potName: pot.name,
                    date: period?.payday ?? String(allocation.createdAt.prefix(10)),
                    detail: allocationSourceLabel(allocation.source),
                    amountPence: allocation.amountPence,
                    kind: .topUp
                )
            }

        let transactionRows = store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .allocation && $0.potId != nil }
            .compactMap { transaction -> PotHistoryRow? in
                guard let potId = transaction.potId, let pot = pot(for: potId) else { return nil }
                return PotHistoryRow(
                    id: transaction.id,
                    potName: pot.name,
                    date: transaction.date,
                    detail: transaction.note.potTrimmed.isEmpty ? "Pot top-up" : transaction.note,
                    amountPence: transaction.amountPence,
                    kind: .topUp
                )
            }

        return (allocationRows + transactionRows).sorted(by: sortRows)
    }

    private var paymentRows: [PotHistoryRow] {
        store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .spending && $0.potId != nil }
            .compactMap { transaction -> PotHistoryRow? in
                guard let potId = transaction.potId, let pot = pot(for: potId) else { return nil }
                return PotHistoryRow(
                    id: transaction.id,
                    potName: pot.name,
                    date: transaction.date,
                    detail: transaction.note.potTrimmed.isEmpty ? "Recorded payment" : transaction.note,
                    amountPence: transaction.amountPence,
                    kind: .payment
                )
            }
            .sorted(by: sortRows)
    }

    private func pot(for id: String) -> Pot? {
        store.snapshot.pots.first { $0.id == id }
    }

    private func allocationSourceLabel(_ source: PotAllocationSource?) -> String {
        switch source ?? .manual {
        case .manual:
            return "Manual top-up"
        case .recurring:
            return "Recurring top-up"
        case .recurringBillFunding:
            return "Bill funding"
        case .cardBillFunding:
            return "Card bill funding"
        case .cardSpendFunding:
            return "Card spend funding"
        case .cardOpeningBalanceFunding:
            return "Card opening balance funding"
        case .debtFunding:
            return "Debt funding"
        case .potAuto:
            return "Auto top-up"
        }
    }

    private func sortRows(_ lhs: PotHistoryRow, _ rhs: PotHistoryRow) -> Bool {
        if lhs.date == rhs.date {
            return lhs.id > rhs.id
        }
        return lhs.date > rhs.date
    }
}

private enum PotHistoryMode: String, CaseIterable, Identifiable {
    case topUps
    case payments
    case allHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topUps:
            return "Top ups"
        case .payments:
            return "Payments"
        case .allHistory:
            return "All history"
        }
    }

    var emptyTitle: String {
        switch self {
        case .topUps:
            return "No top ups yet"
        case .payments:
            return "No payments yet"
        case .allHistory:
            return "No pot history yet"
        }
    }

    var emptyMessage: String {
        switch self {
        case .topUps:
            return "Top up a pot to see it here."
        case .payments:
            return "Record pot spending to see payments here."
        case .allHistory:
            return "Top ups and payments will appear here."
        }
    }
}

private enum PotHistoryKind {
    case topUp
    case payment

    var title: String {
        switch self {
        case .topUp:
            return "Top up"
        case .payment:
            return "Payment"
        }
    }

    var symbol: String {
        switch self {
        case .topUp:
            return "arrow.down.circle"
        case .payment:
            return "arrow.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .topUp:
            return AppTheme.Colors.success
        case .payment:
            return AppTheme.Colors.warning
        }
    }
}

private struct PotHistoryRow: Identifiable {
    let id: String
    let potName: String
    let date: String
    let detail: String
    let amountPence: Int
    let kind: PotHistoryKind
}

private struct PotHistoryRowView: View {
    var row: PotHistoryRow

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.potName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("\(friendlyDate(row.date)) · \(row.detail)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: AppTheme.Spacing.md)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(amountText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(row.kind.color)
                    Pill(text: row.kind.title, systemImage: row.kind.symbol, color: row.kind.color)
                }
            }
        }
    }

    private var amountText: String {
        "\(row.kind == .payment ? "-" : "+")\(MoneyParser.formatPence(row.amountPence))"
    }

    private func friendlyDate(_ value: String) -> String {
        FinanceEngine.parseDate(value).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct PotDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var pot: Pot
    @State private var allocation = ""
    @State private var spend = ""
    @State private var note = ""
    @State private var isEditingSetup = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    PotRow(
                        pot: latestPot,
                        linkedLabel: linkedTargetLabel(for: latestPot, in: store.snapshot),
                        progress: PlannerDerivedData.potProgress(pot: latestPot, snapshot: store.snapshot, today: store.todayIso),
                        pendingFundingContext: potPendingFundingContexts(
                            snapshot: store.snapshot,
                            payPeriod: store.selectedPayPeriod,
                            today: store.todayIso
                        )[latestPot.id, default: .none],
                        today: store.todayIso
                    )
                    AppCard {
                        SectionTitle("Move money")
                        MoneyField(title: "Add allocation", text: $allocation)
                        SecondaryButton(title: "Allocate to pot", systemImage: "plus") {
                            let amountPence = MoneyParser.parsePoundsToPence(allocation)
                            guard amountPence > 0 else { return }
                            if store.addPotAllocation(potId: pot.id, amountPence: amountPence) {
                                allocation = ""
                            }
                        }
                        AppDivider()
                        MoneyField(title: "Spend amount", text: $spend)
                        TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                        SecondaryButton(title: "Record spending", systemImage: "cart") {
                            store.recordTransaction(potId: pot.id, creditCardId: nil, paymentMethod: .pot, amountPence: MoneyParser.parsePoundsToPence(spend), type: .spending, date: Date().isoDateString, note: note)
                            spend = ""
                            note = ""
                        }
                    }
                    SecondaryButton(title: "Delete pot", systemImage: "trash", role: .destructive) {
                        isDeleteConfirmationPresented = true
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(latestPot.name)
            .navigationDestination(isPresented: $isEditingSetup) {
                PotEditView(store: store, pot: latestPot)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(id: "pot-setup-edit", placement: .topBarTrailing) {
                    Button {
                        isEditingSetup = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Edit pot setup")
                }
            }
            .alert("Delete pot?", isPresented: $isDeleteConfirmationPresented) {
                Button("Delete pot", role: .destructive) {
                    store.deletePot(id: pot.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Pots with existing history are hidden instead so old records stay intact.")
            }
        }
    }

    private var latestPot: Pot {
        store.snapshot.pots.first(where: { $0.id == pot.id }) ?? pot
    }
}

private struct PotEditView: View {
    @ObservedObject var store: PlannerStore
    var pot: Pot
    @State private var name: String
    @State private var type: PotType
    @State private var balance: String
    @State private var target: String
    @State private var color: String
    @State private var linkType: PotLinkType
    @State private var linkedEntityId: String

    init(store: PlannerStore, pot: Pot) {
        self.store = store
        self.pot = pot
        _name = State(initialValue: pot.name)
        _type = State(initialValue: pot.type)
        _balance = State(initialValue: moneyInputText(for: pot.balancePence))
        _target = State(initialValue: moneyInputText(for: pot.targetPence))
        _color = State(initialValue: pot.color)
        if let linkedCreditCardId = pot.linkedCreditCardId {
            _linkType = State(initialValue: .creditCard)
            _linkedEntityId = State(initialValue: linkedCreditCardId)
        } else if let linkedDebtId = pot.linkedDebtId {
            _linkType = State(initialValue: .debt)
            _linkedEntityId = State(initialValue: linkedDebtId)
        } else {
            _linkType = State(initialValue: .none)
            _linkedEntityId = State(initialValue: "")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                PotSetupFields(
                    store: store,
                    name: $name,
                    type: $type,
                    balance: $balance,
                    target: $target,
                    color: $color,
                    linkType: $linkType,
                    linkedEntityId: $linkedEntityId
                )

                PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: isSaveDisabled) {
                    saveChanges()
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Edit pot")
        .navigationBarTitleDisplayMode(.large)
    }

    private var isSaveDisabled: Bool {
        name.potTrimmed.isEmpty || !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store)
    }

    private func saveChanges() {
        guard var updated = store.snapshot.pots.first(where: { $0.id == pot.id }) else { return }
        updated.name = name.potTrimmed
        updated.type = type
        updated.category = type.defaultCategory
        updated.balancePence = max(0, MoneyParser.parsePoundsToPence(balance))
        updated.targetPence = target.potNilIfBlank.map { max(0, MoneyParser.parsePoundsToPence($0)) }
        updated.color = color
        updated.linkedCreditCardId = linkType == .creditCard ? linkedEntityId.potNilIfBlank : nil
        updated.linkedDebtId = linkType == .debt ? linkedEntityId.potNilIfBlank : nil
        store.updatePot(updated)
    }
}

private struct PotSetupFields: View {
    @ObservedObject var store: PlannerStore
    @Binding var name: String
    @Binding var type: PotType
    @Binding var balance: String
    @Binding var target: String
    @Binding var color: String
    @Binding var linkType: PotLinkType
    @Binding var linkedEntityId: String

    private let potColors = ["#E85002", "#2563EB", "#16A34A", "#7C3AED", "#0F766E", "#4338CA", "#475569", "#FFFFFF"]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            TextField("Name", text: $name)
                .textFieldStyle(AppTextFieldStyle())

            Picker("Type", selection: $type) {
                ForEach(PotType.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            MoneyField(title: "Current balance", text: $balance)
            MoneyField(title: "Target (optional)", text: $target)
            linkControls
            colorSwatches
        }
        .onAppear {
            normalizeLinkedSelection()
        }
    }

    private var linkControls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Link this pot to")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            Picker("Link this pot to", selection: linkTypeBinding) {
                ForEach(PotLinkType.allCases) { linkType in
                    Text(linkType.title).tag(linkType)
                }
            }
            .pickerStyle(.segmented)

            switch linkType {
            case .none:
                EmptyView()
            case .creditCard:
                if selectableCards.isEmpty {
                    linkEmptyState("No active credit cards")
                } else {
                    Picker("Credit card", selection: $linkedEntityId) {
                        ForEach(selectableCards) { card in
                            Text(card.name).tag(card.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            case .debt:
                if selectableDebts.isEmpty {
                    linkEmptyState("No active debts")
                } else {
                    Picker("Debt", selection: $linkedEntityId) {
                        ForEach(selectableDebts) { debt in
                            Text(debt.name).tag(debt.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var colorSwatches: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ForEach(potColors, id: \.self) { swatch in
                Button {
                    color = swatch
                } label: {
                    Circle()
                        .fill(Color(hex: swatch))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(color == swatch ? AppTheme.Colors.primaryText : AppTheme.Colors.border, lineWidth: color == swatch ? 2 : 1)
                        )
                        .overlay {
                            if color == swatch {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(swatch.uppercased() == "#FFFFFF" ? AppTheme.Colors.appBackground : .white)
                            }
                        }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Pot color")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var linkTypeBinding: Binding<PotLinkType> {
        Binding {
            linkType
        } set: { newValue in
            linkType = newValue
            linkedEntityId = defaultLinkId(for: newValue)
        }
    }

    private var selectableCards: [CreditCard] {
        linkableCreditCards(in: store.snapshot, currentId: linkedEntityId)
    }

    private var selectableDebts: [Debt] {
        linkableDebts(in: store.snapshot, currentId: linkedEntityId)
    }

    private func normalizeLinkedSelection() {
        guard linkType != .none else {
            linkedEntityId = ""
            return
        }
        if !isValidLinkSelection(linkType: linkType, linkedEntityId: linkedEntityId, store: store) {
            linkedEntityId = defaultLinkId(for: linkType)
        }
    }

    private func defaultLinkId(for linkType: PotLinkType) -> String {
        switch linkType {
        case .none:
            return ""
        case .creditCard:
            return selectableCards.first?.id ?? ""
        case .debt:
            return selectableDebts.first?.id ?? ""
        }
    }

    private func linkEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

private enum PotLinkType: String, CaseIterable, Identifiable {
    case none
    case creditCard
    case debt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "No link"
        case .creditCard:
            return "Credit card"
        case .debt:
            return "Debt"
        }
    }
}

private func linkedTargetLabel(for pot: Pot, in snapshot: PlannerSnapshot) -> String? {
    if let cardId = pot.linkedCreditCardId,
       let card = snapshot.creditCards.first(where: { $0.id == cardId }) {
        return "Linked to \(card.name)"
    }
    if let debtId = pot.linkedDebtId,
       let debt = snapshot.debts.first(where: { $0.id == debtId }) {
        return "Linked to \(debt.name)"
    }
    return nil
}

private func potPendingFundingContexts(snapshot: PlannerSnapshot, payPeriod: PayPeriod?, today: String) -> [String: PotPendingFundingContext] {
    guard let payPeriod else { return [:] }

    var contexts: [String: PotPendingFundingContext] = [:]

    func markPending(potId: String, hasProcessedDueItems: Bool = false) {
        var context = contexts[potId, default: .none]
        context.hasPendingChecklistFunding = true
        context.hasProcessedDueItems = context.hasProcessedDueItems || hasProcessedDueItems
        contexts[potId] = context
    }

    for item in PlannerDerivedData.recurringBillFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        let hasProcessedDueItems = item.cardId == nil && hasProcessedDirectRecurringBill(item: item, snapshot: snapshot, today: today)
        markPending(potId: item.potId, hasProcessedDueItems: hasProcessedDueItems)
    }

    for item in PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    for item in PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    for item in PlannerDerivedData.debtFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod) where !item.isCompleted {
        markPending(potId: item.potId)
    }

    return contexts
}

private func hasProcessedDirectRecurringBill(item: RecurringBillFundingChecklistItem, snapshot: PlannerSnapshot, today: String) -> Bool {
    snapshot.transactions.contains {
        $0.deletedAt == nil &&
        $0.type == .spending &&
        $0.paymentMethod == .pot &&
        $0.creditCardId == nil &&
        $0.recurringPaymentId == item.paymentId &&
        $0.date == item.dueDate &&
        $0.date <= today &&
        $0.potId == item.potId
    }
}

private func potDueLabel(progress: PotProgress, today: String) -> String? {
    guard progress.targetPence > 0 else { return nil }

    guard let obligation = progress.nextObligation else {
        return progress.shortfallPence > 0 ? "Top up \(MoneyParser.formatPence(progress.shortfallPence))" : nil
    }

    let days = daysUntil(obligation.dueIso, from: today)
    let dueText = days <= 0 ? "Due now" : "Due in \(days) day\(days == 1 ? "" : "s")"
    return "Next payment: \(MoneyParser.formatPence(obligation.amountPence)) \(dueText.lowercased())"
}

private func potFundingStatusLabel(progress: PotProgress) -> String {
    progress.shortfallPence > 0 ? "\(MoneyParser.formatPence(progress.shortfallPence)) to fund" : "Fully funded"
}

private func potLaterLabel(progress: PotProgress) -> String? {
    guard let obligation = progress.laterObligation else { return nil }
    return "Later: \(MoneyParser.formatPence(obligation.amountPence)) on \(shortDayMonth(obligation.dueIso))"
}

private func daysUntil(_ dueIso: String, from today: String) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let start = FinanceEngine.parseDate(today)
    let end = FinanceEngine.parseDate(dueIso)
    return calendar.dateComponents([.day], from: start, to: end).day ?? 0
}

private func shortDayMonth(_ isoDate: String) -> String {
    FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
}

private func linkableCreditCards(in snapshot: PlannerSnapshot, currentId: String) -> [CreditCard] {
    snapshot.creditCards.filter { !$0.archived || $0.id == currentId }
}

private func linkableDebts(in snapshot: PlannerSnapshot, currentId: String) -> [Debt] {
    snapshot.debts.filter { ($0.status != .archived && $0.currentBalancePence > 0) || $0.id == currentId }
}

@MainActor
private func isValidLinkSelection(linkType: PotLinkType, linkedEntityId: String, store: PlannerStore) -> Bool {
    switch linkType {
    case .none:
        return true
    case .creditCard:
        return linkableCreditCards(in: store.snapshot, currentId: linkedEntityId).contains { $0.id == linkedEntityId }
    case .debt:
        return linkableDebts(in: store.snapshot, currentId: linkedEntityId).contains { $0.id == linkedEntityId }
    }
}

private func moneyInputText(for amountPence: Int?) -> String {
    guard let amountPence, amountPence > 0 else { return "" }
    return String(format: "%.2f", Double(amountPence) / 100)
}

private extension PotType {
    var defaultCategory: String {
        switch self {
        case .spending:
            return "Spending"
        case .reserved:
            return "Bills"
        case .saving, .investment, .buffer:
            return "Savings"
        }
    }
}

private extension String {
    var potTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var potNilIfBlank: String? {
        let trimmed = potTrimmed
        return trimmed.isEmpty ? nil : trimmed
    }
}
