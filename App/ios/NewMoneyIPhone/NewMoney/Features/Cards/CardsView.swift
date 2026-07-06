import SwiftUI

enum CardsSection: String, Equatable {
    case summary
    case paymentAllocation
    case activeCards
}

struct CardsLayoutPolicy {
    static let toolbarActionId = "add"
    static let detailToolbarActionId = "card-detail-add-payment"
    static let detailToolbarSymbol = "plus"
    static let repaymentFlowPlacement = "cardDetailToolbar"
    static let sections: [CardsSection] = [
        .summary,
        .activeCards
    ]

    static func toolbarMode(addAction: @escaping () -> Void) -> AppToolbarMode {
        .add(action: addAction)
    }
}

enum CardFormLayoutPolicy {
    static let dayFieldOrder = ["directDebitDay", "statementDay"]
    static let colorSwatchAlignment = "center"
    static let showsPlaceholderToolbar = false
    static let hidesNavigationDivider = true
    static let usesBillsStyleCard = true
    static let designSelectionPresentation = "navigationPushGroupedDesignBrowser"
    static let designGridColumnCount = 2
    static let preservesDesignAspectRatio = true
}

struct CardsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    @State private var selectedCard: CreditCard?
    @State private var isAddCardPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Cards",
            subtitle: "Track card balances, repayments, saved payments, and cover pots.",
            navigationMode: navigationMode,
            toolbarMode: resolvedToolbarMode
        ) {
            ForEach(CardsLayoutPolicy.sections, id: \.rawValue) { section in
                cardsSection(section)
            }
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(store: store, card: card)
        }
        .sheet(isPresented: $isAddCardPresented) {
            CardFormView(store: store)
        }
    }

    private var resolvedToolbarMode: AppToolbarMode {
        switch toolbarMode {
        case .none, .add(_), .editDone(_, _), .actions(_):
            toolbarMode
        case .primaryDouble, .secondarySingle, .modalSingle:
            CardsLayoutPolicy.toolbarMode {
                isAddCardPresented = true
            }
        }
    }

    @ViewBuilder
    private func cardsSection(_ section: CardsSection) -> some View {
        switch section {
        case .summary:
            summary
        case .paymentAllocation:
            EmptyView()
        case .activeCards:
            activeCardsSection
        }
    }

    private var activeCardsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Active cards")
            if store.activeCards.isEmpty {
                AppCard {
                    EmptyStateView(title: "Add your first card", message: "Use Add in the toolbar to start tracking card balances and repayments.", systemImage: "creditcard")
                }
            } else {
                ForEach(store.activeCards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        CreditCardRow(
                            card: card,
                            balancePence: PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot),
                            availability: availabilitySummary(for: card),
                            linkBadges: creditCardLinkBadges(card: card, snapshot: store.snapshot)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var summary: some View {
        let summaries = store.activeCards.map { availabilitySummary(for: $0) }
        let owed = summaries.reduce(0) { $0 + $1.actualOwedPence }
        let forecastOwed = summaries.reduce(0) { $0 + $1.forecastOwedPence }
        let available = summaries.reduce(0) { $0 + $1.actualAvailablePence }
        let forecastAvailable = summaries.reduce(0) { $0 + $1.forecastAvailablePence }
        return AppCard(glow: true) {
            MetricRow(label: "Owed", value: MoneyParser.formatPence(owed), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(
                label: available < 0 ? "Over limit" : "Available credit",
                value: MoneyParser.formatPence(abs(available)),
                valueColor: available < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText
            )
            if forecastOwed != owed || forecastAvailable != available {
                MetricRow(
                    label: forecastAvailable < 0 ? "Forecast over limit" : "Forecast availability",
                    value: MoneyParser.formatPence(abs(forecastAvailable)),
                    valueColor: forecastAvailable < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                )
            }
        }
    }

    private func availabilitySummary(for card: CreditCard) -> CreditCardAvailabilitySummary {
        PlannerDerivedData.creditCardAvailabilitySummary(
            card: card,
            snapshot: store.snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
    }

}

private struct CreditCardRow: View {
    var card: CreditCard
    var balancePence: Int
    var availability: CreditCardAvailabilitySummary? = nil
    var linkBadges: [CreditCardLinkBadge] = []

    private var design: CreditCardDesign {
        CreditCardDesignCatalog.design(forStoredValue: card.color)
    }

    var body: some View {
        AppCard(glow: balancePence > card.limitPence) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                    CreditCardDesignMiniPreview(
                        design: design,
                        provider: card.provider,
                        badges: linkBadges
                    )
                    .frame(width: 82, height: 42)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)

                        Text(card.provider)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    VStack(alignment: .trailing, spacing: 7) {
                        Text(MoneyParser.formatPence(balancePence))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryOrange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        linkBadgeStrip
                    }
                }

                ProgressView(value: min(1, Double(balancePence) / Double(max(1, card.limitPence))))
                    .tint(balancePence > card.limitPence ? AppTheme.Colors.danger : AppTheme.Colors.primaryOrange)
                    .background(AppTheme.Colors.divider)

                HStack {
                    Pill(text: "Limit \(MoneyParser.formatPence(card.limitPence))", systemImage: "gauge")
                    if let dueDay = card.dueDay {
                        Pill(text: "Due day \(dueDay)", systemImage: "calendar")
                    }
                }

                HStack {
                    Text(cardAvailabilityLabel(actualAvailablePence))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                    Spacer()
                    if forecastAvailablePence != actualAvailablePence {
                        Text(forecastAvailabilityLabel(forecastAvailablePence))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var actualAvailablePence: Int {
        availability?.actualAvailablePence ?? card.limitPence - balancePence
    }

    private var forecastAvailablePence: Int {
        availability?.forecastAvailablePence ?? actualAvailablePence
    }

    @ViewBuilder
    private var linkBadgeStrip: some View {
        if !linkBadges.isEmpty {
            HStack(spacing: 5) {
                ForEach(linkBadges.prefix(3)) { badge in
                    CreditCardLinkBadgePill(badge: badge, isCompact: true)
                }
            }
        }
    }
}

struct CardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var provider = ""
    @State private var limit = ""
    @State private var opening = ""
    @State private var openingStatement = ""
    @State private var statementDay = 1
    @State private var directDebitDay = 1
    @State private var color = CreditCardDesignCatalog.defaultDesign.storageHex

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Add card")
                    TextField("Card name", text: $name).textFieldStyle(AppTextFieldStyle())
                    TextField("Provider", text: $provider).textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: "Credit limit", text: $limit)
                    MoneyField(title: "Opening balance", text: $opening)
                    MoneyField(title: "Existing statement due", text: $openingStatement)

                    dayFields

                    CreditCardDesignSelectionLink(selectedValue: $color, provider: provider)

                    PrimaryButton(title: "Add card", systemImage: "plus", isDisabled: name.isBlank || limit.isBlank) {
                        store.addCreditCard(
                            name: name,
                            provider: provider.isBlank ? "Card" : provider,
                            limitPence: MoneyParser.parsePoundsToPence(limit),
                            openingBalancePence: MoneyParser.parsePoundsToPence(opening),
                            openingStatementBalancePence: openingStatement.isBlank ? nil : MoneyParser.parsePoundsToPence(openingStatement),
                            statementDay: statementDay,
                            dueDay: directDebitDay,
                            dueDate: nil,
                            color: color
                        )
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .onAppear {
                    if color.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        color = CreditCardDesignCatalog.defaultDesign.storageHex
                    }
                }
            }
            .premiumScreenBackground()
            .navigationTitle("Add card")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var dayFields: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            SelectionField(title: "Direct debit day", value: creditCardDaySelectionValue(directDebitDay), systemImage: "calendar.badge.clock") {
                ForEach(1...31, id: \.self) { day in
                    Button(creditCardDaySelectionValue(day)) {
                        directDebitDay = day
                    }
                }
            }
            .frame(maxWidth: .infinity)

            SelectionField(title: "Statement day", value: creditCardDaySelectionValue(statementDay), systemImage: "calendar") {
                ForEach(1...31, id: \.self) { day in
                    Button(creditCardDaySelectionValue(day)) {
                        statementDay = day
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

func creditCardDaySelectionValue(_ day: Int) -> String {
    "Day \(day)"
}

private struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var isHistoryExpanded = true
    @State private var isCardPaymentPresented = false

    private var currentCard: CreditCard {
        store.snapshot.creditCards.first(where: { $0.id == card.id }) ?? card
    }

    private var cardAvailability: CreditCardAvailabilitySummary {
        PlannerDerivedData.creditCardAvailabilitySummary(
            card: currentCard,
            snapshot: store.snapshot,
            payPeriod: store.selectedPayPeriod,
            asOfDate: store.todayIso
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    CreditCardRow(
                        card: currentCard,
                        balancePence: PlannerDerivedData.cardBalance(card: currentCard, snapshot: store.snapshot),
                        availability: cardAvailability,
                        linkBadges: creditCardLinkBadges(card: currentCard, snapshot: store.snapshot)
                    )
                    statementSummaryCard
                    linkedSection
                    historySection
                    SecondaryButton(title: "Delete card", systemImage: "trash", role: .destructive) {
                        store.deleteCreditCard(id: card.id)
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(card.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(id: CardsLayoutPolicy.detailToolbarActionId, placement: .topBarTrailing) {
                    Button {
                        isCardPaymentPresented = true
                    } label: {
                        Image(systemName: CardsLayoutPolicy.detailToolbarSymbol)
                    }
                    .accessibilityLabel("Add Card Payment")
                }
            }
            .sheet(isPresented: $isCardPaymentPresented) {
                CardPaymentFlowSheetView(store: store, initialCardId: currentCard.id)
            }
        }
    }

    private var statementSummaryCard: some View {
        AppCard {
            SectionTitle("Statement")
            MetricRow(label: "Statement day", value: statementDayLabel)
            MetricRow(label: "Next statement", value: nextStatementDate.map(friendlyDate) ?? "Not set")
            MetricRow(label: "Direct debit", value: nextDirectDebitDate.map(friendlyDate) ?? "Not set")
            MetricRow(label: "Current statement due", value: MoneyParser.formatPence(currentStatementDuePence), valueColor: currentStatementDuePence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
            MetricRow(
                label: cardAvailability.actualAvailablePence < 0 ? "Over limit" : "Available",
                value: MoneyParser.formatPence(abs(cardAvailability.actualAvailablePence)),
                valueColor: cardAvailability.actualAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success
            )
            if cardAvailability.forecastAvailablePence != cardAvailability.actualAvailablePence {
                MetricRow(
                    label: cardAvailability.forecastAvailablePence < 0 ? "Forecast over limit" : "Forecast availability",
                    value: MoneyParser.formatPence(abs(cardAvailability.forecastAvailablePence)),
                    valueColor: cardAvailability.forecastAvailablePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.warning
                )
            }
            MetricRow(label: "Linked pot cover", value: MoneyParser.formatPence(linkedPotCoverPence), valueColor: AppTheme.Colors.primaryOrange)
            MetricRow(label: "Paycheck impact", value: MoneyParser.formatPence(directDebitPaycheckImpactPence), valueColor: directDebitPaycheckImpactPence > 0 ? AppTheme.Colors.warning : AppTheme.Colors.success)
        }
    }

    private var linkedSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Linked to this card")
            if linkedRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "Nothing linked", message: "Bills, one-off payments, and pots linked to this card will appear here.", systemImage: "link")
                }
            } else {
                ForEach(linkedRows) { row in
                    CardPaymentAllocationRowCard(row: row)
                }
            }
        }
    }

    private var historySection: some View {
        DisclosureGroup(isExpanded: $isHistoryExpanded) {
            if historyRows.isEmpty {
                AppCard {
                    EmptyStateView(title: "No card history", message: "Charges, payments, cover pots, and card spending will appear here.", systemImage: "clock.arrow.circlepath")
                }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(historyRows) { row in
                        CardPaymentAllocationRowCard(row: row)
                    }
                }
                .padding(.top, AppTheme.Spacing.sm)
            }
        } label: {
            SectionTitle("Card history")
        }
        .tint(AppTheme.Colors.primaryOrange)
    }

    private var linkedRows: [CardPaymentAllocationRow] {
        let recurring = store.snapshot.recurringPayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "linked-recurring-\(payment.id)",
                    title: payment.name,
                    detail: recurringLinkedDetail(payment),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.warning,
                    context: "Bill",
                    symbol: "calendar.badge.clock",
                    sortDate: recurringSortDate(payment)
                )
            }

        let custom = store.snapshot.customPayments
            .filter { $0.deletedAt == nil && $0.status != .archived && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "linked-custom-\(payment.id)",
                    title: payment.name,
                    detail: friendlyDate(payment.dueDate),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "One-off",
                    symbol: "calendar.badge.plus",
                    sortDate: payment.dueDate
                )
            }

        let linkedPots = store.snapshot.pots
            .filter { !$0.archived && $0.linkedCreditCardId == currentCard.id }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "linked-pot-\(pot.id)",
                    title: pot.name,
                    detail: "\(pot.type.rawValue.capitalized) pot",
                    amount: MoneyParser.formatPence(pot.balancePence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "Pot",
                    symbol: "wallet.pass",
                    sortDate: String(pot.updatedAt.prefix(10))
                )
            }

        let coverPots = store.snapshot.creditCardPots
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id && $0.status == .active }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "linked-cover-\(pot.id)",
                    title: pot.name,
                    detail: coverPotSourceLabel(pot.source),
                    amount: MoneyParser.formatPence(pot.amountPence),
                    amountColor: AppTheme.Colors.success,
                    context: "Cover pot",
                    symbol: "wallet.pass",
                    sortDate: creditCardPotDate(pot)
                )
            }

        return (recurring + custom + linkedPots + coverPots).sorted { $0.sortDate > $1.sortDate }
    }

    private var historyRows: [CardPaymentAllocationRow] {
        let recurring = store.snapshot.recurringPayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "history-recurring-\(payment.id)",
                    title: payment.name,
                    detail: "\(payment.frequency.rawValue.capitalized) · \(payment.dueDay.map { "Day \($0)" } ?? "No due day")",
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.warning,
                    context: "Bill",
                    symbol: "calendar.badge.clock",
                    sortDate: recurringSortDate(payment)
                )
            }

        let custom = store.snapshot.customPayments
            .filter { $0.deletedAt == nil && $0.status != .archived && $0.creditCardId == currentCard.id }
            .map { payment in
                CardPaymentAllocationRow(
                    id: "history-custom-\(payment.id)",
                    title: payment.name,
                    detail: friendlyDate(payment.dueDate),
                    amount: MoneyParser.formatPence(payment.amountPence),
                    amountColor: AppTheme.Colors.primaryOrange,
                    context: "One-off",
                    symbol: "calendar.badge.plus",
                    sortDate: payment.dueDate
                )
            }

        let spending = store.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .spending && $0.creditCardId == currentCard.id }
            .map { transaction in
                CardPaymentAllocationRow(
                    id: "history-spending-\(transaction.id)",
                    title: transaction.note.isBlank ? "Card spending" : transaction.note,
                    detail: friendlyDate(transaction.date),
                    amount: "-\(MoneyParser.formatPence(transaction.amountPence))",
                    amountColor: AppTheme.Colors.orangeHighlight,
                    context: "Spending",
                    symbol: "receipt",
                    sortDate: transaction.date
                )
            }

        let repayments = store.snapshot.creditCardRepayments
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { repayment in
                CardPaymentAllocationRow(
                    id: "history-repayment-\(repayment.id)",
                    title: repayment.note.isBlank ? "Card payment" : repayment.note,
                    detail: friendlyDate(repayment.date),
                    amount: MoneyParser.formatPence(repayment.amountPence),
                    amountColor: AppTheme.Colors.success,
                    context: "Payment",
                    symbol: "arrow.down.circle",
                    sortDate: repayment.date
                )
            }

        let coverPots = store.snapshot.creditCardPots
            .filter { $0.deletedAt == nil && $0.creditCardId == currentCard.id }
            .map { pot in
                CardPaymentAllocationRow(
                    id: "history-cover-\(pot.id)",
                    title: pot.name,
                    detail: "\(friendlyDate(creditCardPotDate(pot))) · \(coverPotSourceLabel(pot.source))",
                    amount: "-\(MoneyParser.formatPence(pot.amountPence))",
                    amountColor: AppTheme.Colors.success,
                    context: "Cover pot",
                    symbol: "wallet.pass",
                    sortDate: creditCardPotDate(pot)
                )
            }

        return (recurring + custom + spending + repayments + coverPots).sorted { $0.sortDate > $1.sortDate }
    }

    private func recurringSortDate(_ payment: RecurringPayment) -> String {
        payment.dueDate ?? "9999-12-\(String(format: "%02d", payment.dueDay ?? 1))"
    }

    private func recurringLinkedDetail(_ payment: RecurringPayment) -> String {
        var parts = [payment.frequency.rawValue.capitalized, payment.dueDay.map { "Day \($0)" } ?? "No due day"]
        if let potId = payment.potId,
           let pot = store.snapshot.pots.first(where: { $0.id == potId }) {
            parts.append(pot.name)
        }
        return parts.joined(separator: " · ")
    }

    private func creditCardPotDate(_ pot: CreditCardPot) -> String {
        pot.payday ?? pot.periodStartDate ?? String(pot.createdAt.prefix(10))
    }

    private func coverPotSourceLabel(_ source: CreditCardPotSource) -> String {
        switch source {
        case .paycheck:
            return "Paycheck cover"
        case .external:
            return "External cover"
        }
    }

    private var statementDayLabel: String {
        guard let statementDate = currentCard.statementDate else { return "Not set" }
        let day = Calendar.current.component(.day, from: FinanceEngine.parseDate(statementDate))
        return "Day \(day)"
    }

    private var nextStatementDate: String? {
        guard var statementDate = currentCard.statementDate, FinanceEngine.isIsoDate(statementDate) else { return nil }

        for _ in 0..<240 where statementDate < store.todayIso {
            statementDate = PlannerDerivedData.addIsoMonthsClamped(date: statementDate, months: 1)
        }

        return statementDate
    }

    private var nextDirectDebitDate: String? {
        guard let statementDate = nextStatementDate,
              let dueDay = currentCard.dueDay
        else { return nil }
        return PlannerDerivedData.creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay)
    }

    private var nextStatementPayment: CreditCardStatementPayment? {
        PlannerDerivedData.creditCardStatementPayments(
            card: currentCard,
            snapshot: store.snapshot,
            startDate: store.todayIso,
            endDate: FinanceEngine.addIsoDays(date: store.todayIso, days: 90),
            asOfDate: store.todayIso
        )
        .first
    }

    private var currentStatementDuePence: Int {
        nextStatementPayment?.actualDuePence ?? 0
    }

    private var linkedPotCoverPence: Int {
        FinanceEngine.getLinkedCreditCardPotPence(pots: store.snapshot.pots, creditCardId: currentCard.id)
    }

    private var directDebitPaycheckImpactPence: Int {
        if let repayment = store.snapshot.creditCardRepayments
            .filter({ $0.creditCardId == currentCard.id && $0.directDebitDate == nextDirectDebitDate })
            .sorted(by: { $0.date > $1.date })
            .first {
            return max(0, repayment.paycheckContributionPence ?? repayment.amountPence)
        }

        return max(0, currentStatementDuePence - linkedPotCoverPence)
    }

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

struct CardPaymentFlowSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var initialCardId: String? = nil
    @State private var repaymentCardId = ""
    @State private var repaymentAmount = ""
    @State private var repaymentDate = Date()
    @State private var repaymentNote = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    repaymentCard
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Card payments")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if let initialCardId,
                   store.activeCards.contains(where: { $0.id == initialCardId }) {
                    repaymentCardId = initialCardId
                } else if repaymentCardId.isEmpty {
                    repaymentCardId = store.activeCards.first?.id ?? ""
                }
            }
        }
    }

    private var repaymentCard: some View {
        AppCard(glow: true) {
            SectionTitle("Record payment")
            Picker("Card", selection: $repaymentCardId) {
                ForEach(store.activeCards) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            .tint(AppTheme.Colors.primaryOrange)
            MoneyField(title: "Amount", text: $repaymentAmount)
            DatePicker("Date", selection: $repaymentDate, displayedComponents: .date)
                .tint(AppTheme.Colors.primaryOrange)
            TextField("Note", text: $repaymentNote).textFieldStyle(AppTextFieldStyle())
            PrimaryButton(title: "Record payment", systemImage: "arrow.down.circle", isDisabled: repaymentCardId.isEmpty || MoneyParser.parsePoundsToPence(repaymentAmount) <= 0) {
                store.recordCardRepayment(
                    cardId: repaymentCardId,
                    amountPence: MoneyParser.parsePoundsToPence(repaymentAmount),
                    date: repaymentDate.isoDateString,
                    note: repaymentNote
                )
                repaymentAmount = ""
                repaymentNote = ""
            }
        }
    }
}

private struct CardPaymentAllocationRowCard: View {
    var row: CardPaymentAllocationRow

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                    Text(row.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: AppTheme.Spacing.md)
                VStack(alignment: .trailing, spacing: 6) {
                    Text(row.amount)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(row.amountColor)
                        .multilineTextAlignment(.trailing)
                    Pill(text: row.context, systemImage: row.symbol, color: row.amountColor)
                }
            }
        }
    }
}

private struct CardPaymentAllocationRow: Identifiable {
    var id: String
    var title: String
    var detail: String
    var amount: String
    var amountColor: Color
    var context: String
    var symbol: String
    var sortDate: String
}

private func cardAvailabilityLabel(_ availablePence: Int) -> String {
    availablePence < 0
        ? "Over limit by \(MoneyParser.formatPence(abs(availablePence)))"
        : "Available \(MoneyParser.formatPence(availablePence))"
}

private func forecastAvailabilityLabel(_ availablePence: Int) -> String {
    availablePence < 0
        ? "Forecast over limit by \(MoneyParser.formatPence(abs(availablePence)))"
        : "Forecast available \(MoneyParser.formatPence(availablePence))"
}

private func creditCardLinkBadges(card: CreditCard, snapshot: PlannerSnapshot) -> [CreditCardLinkBadge] {
    let linkedPots = snapshot.pots.filter {
        $0.deletedAt == nil &&
        !$0.archived &&
        $0.linkedCreditCardId == card.id
    }
    let linkedPotIds = Set(linkedPots.map(\.id))

    let hasPotLink = !linkedPots.isEmpty || snapshot.creditCardPots.contains {
        $0.deletedAt == nil &&
        $0.status == .active &&
        $0.creditCardId == card.id
    }

    let hasBillLink = snapshot.recurringPayments.contains { payment in
        guard payment.deletedAt == nil, payment.active else { return false }
        if payment.creditCardId == card.id { return true }
        guard let potId = payment.potId else { return false }
        return linkedPotIds.contains(potId)
    } || snapshot.customPayments.contains {
        $0.deletedAt == nil &&
        $0.status != .archived &&
        $0.creditCardId == card.id
    }

    let hasDebtLink = linkedPots.contains { pot in
        guard let debtId = pot.linkedDebtId else { return false }
        return snapshot.debts.contains {
            $0.id == debtId &&
            $0.deletedAt == nil &&
            $0.status.isActiveLike
        }
    }

    var badges: [CreditCardLinkBadge] = []
    if hasPotLink { badges.append(.pot) }
    if hasBillLink { badges.append(.bill) }
    if hasDebtLink { badges.append(.debt) }
    return badges
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
