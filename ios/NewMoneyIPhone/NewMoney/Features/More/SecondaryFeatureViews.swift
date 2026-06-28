import SwiftUI

struct SpendingView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @State private var paymentMethod: PaymentMethod = .pot
    @State private var selectedPotId = ""
    @State private var selectedCardId = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        ScreenScaffold(
            title: "Spending",
            subtitle: "Record pot or credit-card spend with period links.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            AppCard(glow: true) {
                Picker("Route", selection: $paymentMethod) {
                    Text("Pot").tag(PaymentMethod.pot)
                    Text("Card").tag(PaymentMethod.creditCard)
                }
                .pickerStyle(.segmented)

                if paymentMethod == .pot {
                    Picker("Pot", selection: $selectedPotId) {
                        ForEach(store.activePots) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("Card", selection: $selectedCardId) {
                        ForEach(store.activeCards) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                }

                MoneyField(title: "Amount", text: $amount)
                TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .tint(AppTheme.Colors.primaryOrange)
                PrimaryButton(title: "Record spending", systemImage: "cart", isDisabled: !canSubmit) {
                    store.recordTransaction(
                        potId: paymentMethod == .pot ? selectedPotId : nil,
                        creditCardId: paymentMethod == .creditCard ? selectedCardId : nil,
                        paymentMethod: paymentMethod,
                        amountPence: MoneyParser.parsePoundsToPence(amount),
                        type: .spending,
                        date: date.isoDateString,
                        note: note
                    )
                    amount = ""
                    note = ""
                }
            }
        }
        .onAppear {
            selectedPotId = store.activePots.first?.id ?? ""
            selectedCardId = store.activeCards.first?.id ?? ""
        }
    }

    private var canSubmit: Bool {
        MoneyParser.parsePoundsToPence(amount) > 0 && (paymentMethod == .pot ? !selectedPotId.isEmpty : !selectedCardId.isEmpty)
    }
}

struct SpendingHistorySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if spendingGroups.isEmpty {
                        AppCard {
                            EmptyStateView(title: "No spending yet", message: "Recorded spending will appear here by pay period.", systemImage: "receipt")
                        }
                    } else {
                        ForEach(spendingGroups) { group in
                            AppCard(glow: group.isSelected) {
                                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.title)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                        Text(group.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }
                                    Spacer()
                                    Text("-\(MoneyParser.formatPence(group.totalPence))")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(group.totalPence > 0 ? AppTheme.Colors.orangeHighlight : AppTheme.Colors.tertiaryText)
                                }

                                AppDivider()

                                ForEach(group.transactions) { transaction in
                                    NavigationLink {
                                        SpendingTransactionDetailView(store: store, transaction: transaction)
                                    } label: {
                                        SpendingHistoryRow(transaction: transaction, routeLabel: routeLabel(for: transaction), dateLabel: friendlyDate(transaction.date))
                                    }
                                    .buttonStyle(.plain)

                                    if transaction.id != group.transactions.last?.id {
                                        AppDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Spending history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var spendingGroups: [SpendingHistoryGroup] {
        var groups: [String: SpendingHistoryGroup] = [:]

        for transaction in store.snapshot.transactions where transaction.type == .spending {
            let period = period(for: transaction)
            let id = period?.id ?? "outside-periods"
            var group = groups[id] ?? SpendingHistoryGroup(
                id: id,
                title: period.map { "\(friendlyDate($0.payday)) pay period" } ?? "Outside saved pay periods",
                subtitle: period.map { "\(friendlyDate($0.startDate)) to \(friendlyDate($0.endDate))" } ?? "No matching pay period",
                transactions: [],
                totalPence: 0,
                isSelected: period?.id == store.selectedPayPeriod?.id,
                sortDate: period?.startDate ?? transaction.date
            )
            group.transactions.append(transaction)
            group.totalPence += transaction.amountPence
            groups[id] = group
        }

        return groups.values
            .map { group in
                var copy = group
                copy.transactions.sort { $0.date > $1.date }
                return copy
            }
            .sorted {
                if $0.isSelected != $1.isSelected {
                    return $0.isSelected
                }
                return $0.sortDate > $1.sortDate
            }
    }

    private func period(for transaction: Transaction) -> PayPeriod? {
        if let payPeriodId = transaction.payPeriodId,
           let period = store.snapshot.payPeriods.first(where: { $0.id == payPeriodId }) {
            return period
        }

        return PlannerDerivedData.findPayPeriod(payPeriods: store.snapshot.payPeriods, date: transaction.date)
    }

    private func routeLabel(for transaction: Transaction) -> String {
        spendingRouteLabel(for: transaction, snapshot: store.snapshot)
    }

    private func friendlyDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct SpendingHistoryGroup: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var transactions: [Transaction]
    var totalPence: Int
    var isSelected: Bool
    var sortDate: String
}

private struct SpendingHistoryRow: View {
    var transaction: Transaction
    var routeLabel: String
    var dateLabel: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.note.isBlank ? "Spending" : transaction.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text("\(dateLabel) · \(routeLabel)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text("-\(MoneyParser.formatPence(transaction.amountPence))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.orangeHighlight)
                .multilineTextAlignment(.trailing)
        }
        .contentShape(Rectangle())
    }
}

private struct SpendingTransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var transaction: Transaction
    @State private var paymentMethod: PaymentMethod
    @State private var selectedPotId: String
    @State private var selectedCardId: String
    @State private var amount: String
    @State private var note: String
    @State private var date: Date
    @State private var isDeleteConfirmationPresented = false

    init(store: PlannerStore, transaction: Transaction) {
        self.store = store
        self.transaction = transaction
        let initialMethod = transaction.paymentMethod ?? (transaction.creditCardId == nil ? .pot : .creditCard)
        _paymentMethod = State(initialValue: initialMethod)
        _selectedPotId = State(initialValue: transaction.potId ?? "")
        _selectedCardId = State(initialValue: transaction.creditCardId ?? "")
        _amount = State(initialValue: transaction.amountPence > 0 ? String(format: "%.2f", Double(transaction.amountPence) / 100) : "")
        _note = State(initialValue: transaction.note)
        _date = State(initialValue: FinanceEngine.parseDate(transaction.date))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                AppCard(glow: true) {
                    SectionTitle("Spending details")
                    Picker("Route", selection: $paymentMethod) {
                        Text("Pot").tag(PaymentMethod.pot)
                        Text("Card").tag(PaymentMethod.creditCard)
                    }
                    .pickerStyle(.segmented)

                    if paymentMethod == .pot {
                        Picker("Pot", selection: $selectedPotId) {
                            ForEach(selectablePots) { pot in
                                Text(pot.name).tag(pot.id)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("Card", selection: $selectedCardId) {
                            ForEach(selectableCards) { card in
                                Text(card.name).tag(card.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    MoneyField(title: "Amount", text: $amount)
                    TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .tint(AppTheme.Colors.primaryOrange)
                    PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSave) {
                        store.updateTransaction(
                            id: transaction.id,
                            potId: paymentMethod == .pot ? selectedPotId : nil,
                            creditCardId: paymentMethod == .creditCard ? selectedCardId : nil,
                            paymentMethod: paymentMethod,
                            amountPence: MoneyParser.parsePoundsToPence(amount),
                            date: date.isoDateString,
                            note: note
                        )
                        dismiss()
                    }
                }

                SecondaryButton(title: "Delete spending", systemImage: "trash", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle("Edit spending")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if selectedPotId.isEmpty {
                selectedPotId = selectablePots.first?.id ?? ""
            }
            if selectedCardId.isEmpty {
                selectedCardId = selectableCards.first?.id ?? ""
            }
        }
        .alert("Delete spending?", isPresented: $isDeleteConfirmationPresented) {
            Button("Delete spending", role: .destructive) {
                store.deleteTransaction(id: transaction.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the spending record and restores any linked pot balance.")
        }
    }

    private var selectablePots: [Pot] {
        let active = store.activePots
        guard let currentPotId = transaction.potId,
              !active.contains(where: { $0.id == currentPotId }),
              let currentPot = store.snapshot.pots.first(where: { $0.id == currentPotId })
        else { return active }
        return active + [currentPot]
    }

    private var selectableCards: [CreditCard] {
        let active = store.activeCards
        guard let currentCardId = transaction.creditCardId,
              !active.contains(where: { $0.id == currentCardId }),
              let currentCard = store.snapshot.creditCards.first(where: { $0.id == currentCardId })
        else { return active }
        return active + [currentCard]
    }

    private var canSave: Bool {
        MoneyParser.parsePoundsToPence(amount) > 0 && (paymentMethod == .pot ? !selectedPotId.isEmpty : !selectedCardId.isEmpty)
    }

}

private func spendingRouteLabel(for transaction: Transaction, snapshot: PlannerSnapshot) -> String {
    if transaction.paymentMethod == .creditCard || transaction.creditCardId != nil {
        guard let cardId = transaction.creditCardId else { return "Credit card" }
        return snapshot.creditCards.first { $0.id == cardId }?.name ?? "Credit card"
    }

    if let potId = transaction.potId {
        return snapshot.pots.first { $0.id == potId }?.name ?? "Pot"
    }

    return "Unlinked"
}

struct SpendingSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            SpendingView(store: store, navigationMode: .inline, toolbarMode: .none)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct AddBillSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDay = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var priority: RecurringPriority = .essential
    @State private var potId = ""
    @State private var cardId = ""
    @State private var routeToCard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Add recurring payment")
                    TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: "Amount", text: $amount)
                    TextField("Due day", text: $dueDay).keyboardType(.numberPad).textFieldStyle(AppTextFieldStyle())
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Priority", selection: $priority) {
                        ForEach(RecurringPriority.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Linked to card", isOn: $routeToCard)
                        .tint(AppTheme.Colors.primaryOrange)
                    if routeToCard {
                        SelectionField(title: "Card", value: selectedCardName, placeholder: "No card", systemImage: "creditcard") {
                            Button("No card") { cardId = "" }
                            ForEach(store.activeCards) { card in
                                Button(card.name) { cardId = card.id }
                            }
                        }
                        SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                            Button("No pot") { potId = "" }
                            if cardLinkedPots.isEmpty {
                                Text("No linked card pots")
                            } else {
                                ForEach(cardLinkedPots) { pot in
                                    Button(pot.name) { potId = pot.id }
                                }
                            }
                        }
                    } else {
                        SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                            Button("No pot") { potId = "" }
                            ForEach(store.activePots) { pot in
                                Button(pot.name) { potId = pot.id }
                            }
                        }
                    }
                    PrimaryButton(title: "Add bill", systemImage: "plus", isDisabled: name.isBlank || MoneyParser.parsePoundsToPence(amount) <= 0) {
                        store.addRecurringPayment(
                            name: name,
                            amountPence: MoneyParser.parsePoundsToPence(amount),
                            dueDay: Int(dueDay),
                            frequency: frequency,
                            potId: cleanPotId,
                            creditCardId: routeToCard ? cardId.nilIfBlank : nil,
                            priority: priority
                        )
                        reset()
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add bill")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
        .onAppear {
            potId = store.activePots.first?.id ?? ""
            cardId = store.activeCards.first?.id ?? ""
            normalizeSelectedCardPot()
        }
        .onChange(of: cardId) { _, _ in normalizeSelectedCardPot() }
        .onChange(of: routeToCard) { _, _ in normalizeSelectedCardPot() }
    }

    private func reset() {
        name = ""
        amount = ""
        dueDay = ""
        frequency = .monthly
        priority = .essential
        routeToCard = false
    }

    private var cardLinkedPots: [Pot] {
        store.activePots.filter { $0.linkedCreditCardId == cardId }
    }

    private var selectedCardName: String {
        store.activeCards.first { $0.id == cardId }?.name ?? ""
    }

    private var selectedPotName: String {
        store.activePots.first { $0.id == potId }?.name ?? ""
    }

    private var cleanPotId: String? {
        if routeToCard {
            return cardLinkedPots.contains(where: { $0.id == potId }) ? potId.nilIfBlank : nil
        }

        return potId.nilIfBlank
    }

    private func normalizeSelectedCardPot() {
        guard routeToCard else { return }
        if !cardLinkedPots.contains(where: { $0.id == potId }) {
            potId = cardLinkedPots.first?.id ?? ""
        }
    }
}

struct BillsView: View {
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDay = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var priority: RecurringPriority = .essential
    @State private var potId = ""
    @State private var cardId = ""
    @State private var routeToCard = false

    var body: some View {
        ScreenScaffold(
            title: "Bills",
            subtitle: "Recurring payment templates and upcoming bill agenda.",
            navigationMode: .inline,
            toolbarMode: .secondarySingle
        ) {
            AppCard(glow: true) {
                SectionTitle("Add recurring payment")
                TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
                MoneyField(title: "Amount", text: $amount)
                TextField("Due day", text: $dueDay).keyboardType(.numberPad).textFieldStyle(AppTextFieldStyle())
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Priority", selection: $priority) {
                    ForEach(RecurringPriority.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Linked to card", isOn: $routeToCard)
                    .tint(AppTheme.Colors.primaryOrange)
                if routeToCard {
                    SelectionField(title: "Card", value: selectedCardName, placeholder: "No card", systemImage: "creditcard") {
                        Button("No card") { cardId = "" }
                        ForEach(store.activeCards) { card in
                            Button(card.name) { cardId = card.id }
                        }
                    }
                    SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                        Button("No pot") { potId = "" }
                        if cardLinkedPots.isEmpty {
                            Text("No linked card pots")
                        } else {
                            ForEach(cardLinkedPots) { pot in
                                Button(pot.name) { potId = pot.id }
                            }
                        }
                    }
                } else {
                    SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                        Button("No pot") { potId = "" }
                        ForEach(store.activePots) { pot in
                            Button(pot.name) { potId = pot.id }
                        }
                    }
                }
                PrimaryButton(title: "Add bill", systemImage: "plus", isDisabled: name.isBlank || MoneyParser.parsePoundsToPence(amount) <= 0) {
                    store.addRecurringPayment(
                        name: name,
                        amountPence: MoneyParser.parsePoundsToPence(amount),
                        dueDay: Int(dueDay),
                        frequency: frequency,
                        potId: cleanPotId,
                        creditCardId: routeToCard ? cardId.nilIfBlank : nil,
                        priority: priority
                    )
                    name = ""
                    amount = ""
                }
            }

            upcomingAgenda
            billList
        }
        .onAppear {
            potId = store.activePots.first?.id ?? ""
            cardId = store.activeCards.first?.id ?? ""
            normalizeSelectedCardPot()
        }
        .onChange(of: cardId) { _, _ in normalizeSelectedCardPot() }
        .onChange(of: routeToCard) { _, _ in normalizeSelectedCardPot() }
    }

    private var upcomingAgenda: some View {
        let endDate = FinanceEngine.addIsoDays(date: store.todayIso, days: 30)
        let upcoming = PlannerDerivedData.recurringOccurrences(payments: store.snapshot.recurringPayments, startDate: store.todayIso, endDate: endDate)
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Next 30 days")
            AppCard {
                if upcoming.isEmpty {
                    EmptyStateView(title: "No upcoming bills", message: "Recurring payments with due dates appear here.", systemImage: "calendar")
                } else {
                    ForEach(upcoming.prefix(8)) { occurrence in
                        MetricRow(label: "\(occurrence.dueDate) · \(occurrence.payment.name)", value: MoneyParser.formatPence(occurrence.amountPence), valueColor: AppTheme.Colors.warning)
                    }
                }
            }
        }
    }

    private var billList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Bills list")
            if store.snapshot.recurringPayments.isEmpty {
                AppCard { EmptyStateView(title: "No recurring payments", message: "Add rent, subscriptions, utilities, and card-linked bills.", systemImage: "calendar.badge.plus") }
            } else {
                ForEach(store.snapshot.recurringPayments) { payment in
                    AppCard {
                        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(payment.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(payment.active ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                                    .lineLimit(1)
                                Text("\(payment.frequency.rawValue.capitalized) · \(billDueLabel(payment.dueDay)) · \(payment.priority.rawValue.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                                Text(billLinkLabel(payment))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                Text(MoneyParser.formatPence(payment.amountPence))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                                Button {
                                    store.archiveRecurringPayment(id: payment.id)
                                } label: {
                                    Label("Archive", systemImage: "archivebox")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.danger)
                            }
                        }
                    }
                }
            }
        }
    }

    private func billDueLabel(_ dueDay: Int?) -> String {
        dueDay.map { "Day \($0)" } ?? "No due day"
    }

    private func billLinkLabel(_ payment: RecurringPayment) -> String {
        let potName = payment.potId.flatMap { potId in store.snapshot.pots.first { $0.id == potId }?.name }
        let cardName = payment.creditCardId.flatMap { cardId in store.snapshot.creditCards.first { $0.id == cardId }?.name }

        if let cardName, let potName {
            return "\(cardName) + \(potName)"
        }
        if let potName {
            return potName
        }
        if let cardName {
            return cardName
        }
        return "No link"
    }

    private var cardLinkedPots: [Pot] {
        store.activePots.filter { $0.linkedCreditCardId == cardId }
    }

    private var selectedCardName: String {
        store.activeCards.first { $0.id == cardId }?.name ?? ""
    }

    private var selectedPotName: String {
        store.activePots.first { $0.id == potId }?.name ?? ""
    }

    private var cleanPotId: String? {
        if routeToCard {
            return cardLinkedPots.contains(where: { $0.id == potId }) ? potId.nilIfBlank : nil
        }

        return potId.nilIfBlank
    }

    private func normalizeSelectedCardPot() {
        guard routeToCard else { return }
        if !cardLinkedPots.contains(where: { $0.id == potId }) {
            potId = cardLinkedPots.first?.id ?? ""
        }
    }
}

struct AddDebtSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var lender = ""
    @State private var balance = ""
    @State private var minimum = ""
    @State private var dueDate = Date()
    @State private var linkedPotId = ""
    @State private var apr = ""
    @State private var fixedFee = ""
    @State private var extraPayment = ""
    @State private var debtType: DebtType = .other
    @State private var interestType: DebtInterestType = .none
    @State private var repaymentStrategy: DebtRepaymentStrategy = .autoSpreadUntilDueDate
    @State private var paymentFrequency: DebtPaymentFrequency = .monthly
    @State private var paymentDay = ""
    @State private var payFirstTiming: DebtPayFirstTiming = .nextPayday
    @State private var hasFixedDueDate = true
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                AppCard(glow: true) {
                    SectionTitle("Add debt")
                    TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
                    TextField("Lender", text: $lender).textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: "Current balance", text: $balance)
                    Picker("Debt type", selection: $debtType) {
                        ForEach(DebtType.allCases) { type in
                            Text(debtTypeLabel(type)).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Interest", selection: $interestType) {
                        ForEach(DebtInterestType.allCases) { type in
                            Text(debtInterestLabel(type)).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    if interestType == .apr {
                        TextField("APR", text: $apr).keyboardType(.decimalPad).textFieldStyle(AppTextFieldStyle())
                    } else if interestType == .fixedFee {
                        MoneyField(title: "Fixed fee", text: $fixedFee)
                    }
                    Toggle("Fixed payoff date", isOn: $hasFixedDueDate)
                        .tint(AppTheme.Colors.primaryOrange)
                    if hasFixedDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                            .tint(AppTheme.Colors.primaryOrange)
                    }
                    Picker("Strategy", selection: $repaymentStrategy) {
                        ForEach(DebtRepaymentStrategy.allCases) { strategy in
                            Text(debtStrategyLabel(strategy)).tag(strategy)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Frequency", selection: $paymentFrequency) {
                        ForEach(DebtPaymentFrequency.allCases) { frequency in
                            Text(debtFrequencyLabel(frequency)).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Payment day", text: $paymentDay)
                        .keyboardType(.numberPad)
                        .textFieldStyle(AppTextFieldStyle())
                    MoneyField(title: repaymentStrategy == .fixedPayment ? "Fixed payment" : "Minimum payment", text: $minimum)
                    if repaymentStrategy == .minimumPlusExtra {
                        MoneyField(title: "Extra payment", text: $extraPayment)
                    }
                    if repaymentStrategy == .payIn4 {
                        Picker("First payment", selection: $payFirstTiming) {
                            ForEach(DebtPayFirstTiming.allCases) { timing in
                                Text(debtFirstPaymentLabel(timing)).tag(timing)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Picker("Linked pot", selection: $linkedPotId) {
                        Text("No linked pot").tag("")
                        ForEach(eligibleDebtPots(in: store.snapshot, debtId: nil)) { pot in
                            Text(pot.name).tag(pot.id)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                    previewCard
                    PrimaryButton(title: "Add debt", systemImage: "plus", isDisabled: name.isBlank || MoneyParser.parsePoundsToPence(balance) <= 0) {
                        store.addDebt(
                            name: name,
                            lender: lender,
                            currentBalancePence: MoneyParser.parsePoundsToPence(balance),
                            minimumPaymentPence: MoneyParser.parsePoundsToPence(minimum),
                            dueDate: hasFixedDueDate ? dueDate.isoDateString : "",
                            apr: interestType == .apr ? Double(apr) : nil,
                            note: note,
                            linkedPotId: linkedPotId.nilIfBlank,
                            type: debtType,
                            interestType: interestType,
                            fixedFeePence: MoneyParser.parsePoundsToPence(fixedFee),
                            extraPaymentPence: MoneyParser.parsePoundsToPence(extraPayment),
                            repaymentStrategy: repaymentStrategy,
                            paymentFrequency: paymentFrequency,
                            paymentDay: Int(paymentDay).map { min(31, max(1, $0)) },
                            payFirstTiming: payFirstTiming
                        )
                        reset()
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add debt")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var previewCard: some View {
        let schedule = previewSchedule
        return VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Preview")
            MetricRow(label: "First payment", value: schedule.first.map { "\(MoneyParser.formatPence($0.plannedAmountPence)) on \($0.dueDate)" } ?? "No automatic payment")
            MetricRow(label: "Commitment", value: MoneyParser.formatPence(schedule.reduce(0) { $0 + $1.plannedAmountPence }))
            MetricRow(label: "Estimated payoff", value: schedule.last?.dueDate ?? (hasFixedDueDate ? dueDate.isoDateString : "Manual"))
            MetricRow(label: "Projected interest", value: MoneyParser.formatPence(schedule.reduce(0) { $0 + $1.interestAmountPence }))
        }
    }

    private var previewSchedule: [DebtPaymentScheduleItem] {
        let amountPence = MoneyParser.parsePoundsToPence(balance)
        guard amountPence > 0 else { return [] }
        let debt = Debt(
            id: "preview-debt",
            name: name.isBlank ? "Debt" : name,
            lender: lender,
            originalAmountPence: amountPence,
            currentBalancePence: amountPence,
            minimumPaymentPence: MoneyParser.parsePoundsToPence(minimum),
            dueDate: hasFixedDueDate ? dueDate.isoDateString : "",
            interestRateApr: interestType == .apr ? Double(apr) : nil,
            note: note,
            status: .active,
            createdAt: DateUtilities.nowIsoString(),
            updatedAt: DateUtilities.nowIsoString(),
            deletedAt: nil,
            type: debtType,
            startingBalancePence: amountPence,
            targetPayoffDate: hasFixedDueDate ? dueDate.isoDateString : nil,
            interestType: interestType,
            aprBasisPoints: Double(apr).map { Int(($0 * 100).rounded()) },
            fixedFeePence: MoneyParser.parsePoundsToPence(fixedFee),
            extraPaymentPence: MoneyParser.parsePoundsToPence(extraPayment),
            repaymentStrategy: repaymentStrategy,
            paymentFrequency: paymentFrequency,
            paymentDay: Int(paymentDay).map { min(31, max(1, $0)) },
            payFirstTiming: payFirstTiming
        )
        return DebtPlannerEngine.generateSchedule(for: debt, payPeriods: store.snapshot.payPeriods, today: store.todayIso)
    }

    private func reset() {
        name = ""
        lender = ""
        balance = ""
        minimum = ""
        dueDate = Date()
        linkedPotId = ""
        apr = ""
        fixedFee = ""
        extraPayment = ""
        debtType = .other
        interestType = .none
        repaymentStrategy = .autoSpreadUntilDueDate
        paymentFrequency = .monthly
        paymentDay = ""
        payFirstTiming = .nextPayday
        hasFixedDueDate = true
        note = ""
    }
}

struct DebtsView: View {
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var lender = ""
    @State private var balance = ""
    @State private var minimum = ""
    @State private var dueDate = Date()
    @State private var linkedPotId = ""
    @State private var apr = ""
    @State private var note = ""
    @State private var selectedDebt: Debt?
    @State private var isAddDebtPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Debts",
            subtitle: "Balances, reserves, minimums, and payoff progress.",
            navigationMode: .inline,
            toolbarMode: .secondarySingle
        ) {
            debtSummary
            addDebtCard
            SectionTitle("Active debts")
            if store.activeDebts.isEmpty {
                AppCard { EmptyStateView(title: "No active debts", message: "Add debts to track minimums, reserves, and payments.", systemImage: "checkmark.shield") }
            } else {
                ForEach(store.activeDebts) { debt in
                    Button {
                        selectedDebt = debt
                    } label: {
                        debtRow(debt)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedDebt) { debt in
            DebtDetailView(store: store, debt: debt)
        }
        .sheet(isPresented: $isAddDebtPresented) {
            AddDebtSheetView(store: store)
        }
    }

    private var debtSummary: some View {
        let summary = FinanceEngine.getDebtSummary(debts: store.snapshot.debts, payments: store.snapshot.debtPayments, reserves: store.snapshot.debtReserves, pots: store.snapshot.pots, today: store.todayIso)
        return AppCard(glow: true) {
            MetricRow(label: "Current balance", value: MoneyParser.formatPence(summary.totalCurrentBalancePence), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Paid", value: MoneyParser.formatPence(summary.totalPaidPence))
            MetricRow(label: "Progress", value: "\(Int(summary.progressPercent.rounded()))%")
            MetricRow(label: "Overdue", value: "\(summary.overdueDebtCount)", valueColor: summary.overdueDebtCount > 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
        }
    }

    private var addDebtCard: some View {
        AppCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SectionTitle("Add debt")
                    Text("Create a balance-based repayment plan.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                PrimaryButton(title: "Add", systemImage: "plus") {
                    isAddDebtPresented = true
                }
            }
        }
    }

    private func debtRow(_ debt: Debt) -> some View {
        AppCard(glow: debt.status == .overdue || debt.status == .dueToday) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(debt.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(debtSummaryLine(for: debt, in: store.snapshot))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(MoneyParser.formatPence(debt.currentBalancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                    Text(nextDebtPaymentLine(for: debt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
        }
    }

    private func nextDebtPaymentLine(for debt: Debt) -> String {
        let item = PlannerDerivedData.debtScheduleItems(snapshot: store.snapshot, payPeriod: nil)
            .filter { $0.debtId == debt.id && $0.status != .paid && $0.status != .cancelled }
            .sorted { $0.dueDate < $1.dueDate }
            .first
        guard let item else { return debtStrategyLabel(debt.repaymentStrategy) }
        return "\(MoneyParser.formatPence(item.plannedAmountPence)) due \(item.dueDate)"
    }
}

private struct DebtDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var debt: Debt
    @State private var payment = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    AppCard(glow: true) {
                        MetricRow(label: "Balance", value: MoneyParser.formatPence(currentDebt.currentBalancePence), valueColor: AppTheme.Colors.primaryOrange)
                        MetricRow(label: "Original", value: MoneyParser.formatPence(currentDebt.startingBalancePence))
                        MetricRow(label: "Minimum", value: MoneyParser.formatPence(currentDebt.minimumPaymentPence))
                        MetricRow(label: "Strategy", value: debtStrategyLabel(currentDebt.repaymentStrategy))
                        MetricRow(label: "Next payment", value: nextScheduleItem.map { "\(MoneyParser.formatPence($0.plannedAmountPence)) on \($0.dueDate)" } ?? "None")
                        MetricRow(label: "Funded", value: MoneyParser.formatPence(nextScheduleItem?.fundedAmountPence ?? 0), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Status", value: debtStatusLabel(currentDebt.status))
                        MetricRow(label: "Linked pot", value: linkedDebtPotName(in: store.snapshot, debtId: currentDebt.id) ?? "None")
                    }
                    AppCard {
                        SectionTitle("Schedule")
                        ForEach(scheduleItems, id: \.id) { (item: DebtPaymentScheduleItem) in
                            MetricRow(label: item.dueDate, value: "\(MoneyParser.formatPence(item.plannedAmountPence)) · \(item.status.rawValue.replacingOccurrences(of: "_", with: " "))")
                        }
                    }
                    AppCard {
                        SectionTitle("Payment")
                        MoneyField(title: "Payment amount", text: $payment)
                        TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                        SecondaryButton(title: "Record payment", systemImage: "checkmark.circle") {
                            store.recordDebtPayment(debtId: debt.id, amountPence: MoneyParser.parsePoundsToPence(payment), date: Date().isoDateString, note: note)
                            payment = ""
                            note = ""
                        }
                    }
                    SecondaryButton(title: "Archive debt", systemImage: "archivebox", role: .destructive) {
                        store.archiveDebt(id: debt.id)
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(debt.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
    }

    private var currentDebt: Debt {
        store.snapshot.debts.first(where: { $0.id == debt.id }) ?? debt
    }

    private var scheduleItems: [DebtPaymentScheduleItem] {
        PlannerDerivedData.debtScheduleItems(snapshot: store.snapshot, payPeriod: nil)
            .filter { $0.debtId == currentDebt.id && $0.status != .cancelled }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var nextScheduleItem: DebtPaymentScheduleItem? {
        scheduleItems.first { $0.status != .paid }
    }

}

struct CalendarPlannerView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @State private var month = Date()
    @State private var selectedDate = FinanceEngine.toIsoDate(Date())
    @State private var mode: CalendarDisplayMode = .calendar

    var body: some View {
        ScreenScaffold(
            title: "Calendar",
            subtitle: "Money events by month.",
            navigationMode: navigationMode,
            toolbarMode: .actions([
                AppToolbarAction(id: "calendar-mode-toggle", symbol: "ellipsis.circle", accessibilityLabel: "Toggle Calendar View") {
                    withAnimation(AppTheme.Animation.standard) {
                        mode = mode == .calendar ? .list : .calendar
                    }
                }
            ])
        ) {
            calendarHeader
            if mode == .calendar {
                calendarGrid
                selectedDayDetails
            } else {
                agendaList
            }
        }
        .onAppear {
            if selectedDate < monthStart || selectedDate > monthEnd {
                selectedDate = monthStart
            }
        }
    }

    private var calendarHeader: some View {
        AppCard(glow: true) {
            HStack(spacing: AppTheme.Spacing.md) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())

                VStack(alignment: .leading, spacing: 8) {
                    Pill(text: month.formatted(.dateTime.month(.wide).year()), systemImage: "calendar")
                    Text(mode == .calendar ? "Calendar view" : "List view")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(ordinalDay(selectedDate))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(monthName(selectedDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var calendarGrid: some View {
        AppCard {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    if let isoDate = day.isoDate {
                        Button {
                            withAnimation(AppTheme.Animation.standard) {
                                selectedDate = isoDate
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(day.dayNumber)")
                                    .font(.subheadline.weight(day.isToday ? .bold : .semibold))
                                    .foregroundStyle(dayTextColor(day))
                                    .frame(width: 34, height: 34)
                                    .background(dayBackground(day))
                                    .clipShape(Circle())

                                HStack(spacing: 2) {
                                    ForEach(Array(eventTypes(for: isoDate).prefix(3)), id: \.rawValue) { type in
                                        Circle()
                                            .fill(color(for: type))
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .opacity(day.isCurrentMonth ? 1 : 0.32)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(minHeight: 56)
                    }
                }
            }
        }
    }

    private var selectedDayDetails: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("\(weekdayName(selectedDate)), \(ordinalDay(selectedDate))")
            let dayEvents = eventsByDate[selectedDate] ?? []
            if dayEvents.isEmpty {
                AppCard {
                    EmptyStateView(title: "Nothing planned", message: "No finance events are scheduled for this day.", systemImage: "calendar")
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ForEach(dayEvents) { event in
                    calendarEventCard(event)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(AppTheme.Animation.standard, value: selectedDate)
    }

    private var agendaList: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("This month")
            if groupedDates.isEmpty {
                AppCard {
                    EmptyStateView(title: "No events this month", message: "Paydays, bills, card payments, spending, and debts appear here.", systemImage: "calendar")
                }
            } else {
                ForEach(groupedDates, id: \.self) { date in
                    AppCard {
                        HStack(alignment: .firstTextBaseline) {
                            Pill(text: monthName(date), systemImage: nil, color: AppTheme.Colors.primaryOrange)
                            Spacer()
                            Text(ordinalDay(date))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                        }
                        ForEach(eventsByDate[date] ?? []) { event in
                            calendarEventLine(event)
                        }
                    }
                }
            }
        }
    }

    private func calendarEventCard(_ event: CalendarEvent) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol(for: event.type))
                    .foregroundStyle(color(for: event.type))
                    .frame(width: 34, height: 34)
                    .background(color(for: event.type).opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(eventSubtitle(event))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                Spacer()
                if let amountPence = event.amountPence {
                    Text(MoneyParser.formatPence(amountPence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(color(for: event.type))
                }
            }
        }
    }

    private func calendarEventLine(_ event: CalendarEvent) -> some View {
        MetricRow(
            label: "\(event.title) · \(eventTypeLabel(event.type))",
            value: event.amountPence.map { MoneyParser.formatPence($0) } ?? eventSubtitle(event),
            valueColor: color(for: event.type)
        )
    }

    private var monthStart: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month], from: month)
        return FinanceEngine.toIsoDate(calendar.date(from: components) ?? month)
    }

    private var monthEnd: String {
        let start = monthStart.isoDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return FinanceEngine.toIsoDate(FinanceEngine.addDays(next, days: -1))
    }

    private var events: [CalendarEvent] {
        PlannerDerivedData.calendarEvents(snapshot: store.snapshot, startDate: monthStart, endDate: monthEnd)
    }

    private var eventsByDate: [String: [CalendarEvent]] {
        Dictionary(grouping: events, by: \.date)
    }

    private var groupedDates: [String] {
        eventsByDate.keys.sorted()
    }

    private var weekdaySymbols: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var calendarDays: [CalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let start = FinanceEngine.parseDate(monthStart)
        let dayRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let weekday = calendar.component(.weekday, from: start)
        let leadingEmptyCount = (weekday + 5) % 7
        var days = (0..<leadingEmptyCount).map { CalendarDay(id: "blank-\($0)", date: nil, isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false) }

        days += dayRange.map { day in
            var components = calendar.dateComponents([.year, .month], from: start)
            components.day = day
            let date = calendar.date(from: components) ?? start
            let isoDate = FinanceEngine.toIsoDate(date)
            return CalendarDay(id: isoDate, date: date, isoDate: isoDate, dayNumber: day, isCurrentMonth: true, isToday: isoDate == store.todayIso)
        }

        while days.count % 7 != 0 {
            days.append(CalendarDay(id: "blank-\(days.count)", date: nil, isoDate: nil, dayNumber: 0, isCurrentMonth: false, isToday: false))
        }

        return days
    }

    private func moveMonth(by value: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
        selectedDate = monthStart
    }

    private func eventTypes(for date: String) -> [CalendarEventType] {
        Array(Set(eventsByDate[date]?.map(\.type) ?? []))
            .sorted { eventRank($0) < eventRank($1) }
    }

    private func dayTextColor(_ day: CalendarDay) -> Color {
        guard let isoDate = day.isoDate else { return AppTheme.Colors.tertiaryText }
        if isoDate == selectedDate || day.isToday {
            return .white
        }
        return AppTheme.Colors.primaryText
    }

    private func dayBackground(_ day: CalendarDay) -> AnyShapeStyle {
        guard let isoDate = day.isoDate else { return AnyShapeStyle(Color.clear) }
        if isoDate == selectedDate {
            return AnyShapeStyle(AppTheme.Gradients.primary)
        }
        if day.isToday {
            return AnyShapeStyle(AppTheme.Colors.primaryOrange.opacity(0.34))
        }
        return AnyShapeStyle(Color.clear)
    }

    private func eventSubtitle(_ event: CalendarEvent) -> String {
        switch event.type {
        case .payday:
            return event.amountPence == nil ? "Next period starts" : "Income lands"
        case .recurring:
            return event.detail.replacingOccurrences(of: "_", with: " ").capitalized
        case .savedPayment:
            return "Saved payment"
        case .spending:
            return event.detail.replacingOccurrences(of: "_", with: " ").capitalized
        case .cardPayment:
            return "Card repayment"
        case .debtDue:
            return event.detail
        case .debtReserve:
            return "Debt reserve"
        case .debtPayment:
            return event.detail.isEmpty ? "Debt payment" : event.detail
        case .allocation:
            return "Pot allocation"
        }
    }

    private func eventTypeLabel(_ type: CalendarEventType) -> String {
        switch type {
        case .payday: "Payday"
        case .recurring: "Bill"
        case .savedPayment: "Saved"
        case .spending: "Spend"
        case .cardPayment: "Card"
        case .debtDue: "Debt"
        case .debtReserve: "Reserve"
        case .debtPayment: "Debt paid"
        case .allocation: "Pot"
        }
    }

    private func symbol(for type: CalendarEventType) -> String {
        switch type {
        case .payday: "sterlingsign.circle"
        case .recurring: "calendar.badge.clock"
        case .savedPayment: "calendar.badge.plus"
        case .spending: "receipt"
        case .cardPayment: "creditcard"
        case .debtDue: "exclamationmark.shield"
        case .debtReserve: "plus.circle"
        case .debtPayment: "checkmark.circle"
        case .allocation: "wallet.pass"
        }
    }

    private func color(for type: CalendarEventType) -> Color {
        switch type {
        case .payday: AppTheme.Colors.success
        case .recurring, .savedPayment, .debtDue: AppTheme.Colors.warning
        case .cardPayment, .spending: AppTheme.Colors.orangeHighlight
        case .debtReserve, .debtPayment, .allocation: AppTheme.Colors.primaryOrange
        }
    }

    private func eventRank(_ type: CalendarEventType) -> Int {
        switch type {
        case .payday: 0
        case .recurring: 1
        case .savedPayment: 2
        case .debtDue: 3
        case .cardPayment: 4
        case .spending: 5
        case .debtReserve: 6
        case .debtPayment: 7
        case .allocation: 8
        }
    }

    private func ordinalDay(_ isoDate: String) -> String {
        let day = Calendar(identifier: .gregorian).component(.day, from: FinanceEngine.parseDate(isoDate))
        let suffix: String
        if (11...13).contains(day % 100) {
            suffix = "th"
        } else {
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }

    private func monthName(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.month(.abbreviated))
    }

    private func weekdayName(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.weekday(.wide))
    }
}

private enum CalendarDisplayMode {
    case calendar
    case list
}

private struct CalendarDay: Identifiable {
    var id: String
    var date: Date?
    var isoDate: String?
    var dayNumber: Int
    var isCurrentMonth: Bool
    var isToday: Bool
}

struct CalendarSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            CalendarPlannerView(store: store, navigationMode: .inline, toolbarMode: .none)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct HistoryView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "History",
            subtitle: "Closed and active paycheck plans with allocations.",
            navigationMode: .inline,
            toolbarMode: .secondarySingle
        ) {
            AppCard(glow: true) {
                MetricRow(label: "Paychecks", value: "\(store.snapshot.paychecks.count)")
                MetricRow(label: "Total income", value: MoneyParser.formatPence(store.snapshot.payPeriods.reduce(0) { $0 + $1.incomePence }), valueColor: AppTheme.Colors.success)
                MetricRow(label: "Total allocated", value: MoneyParser.formatPence(store.snapshot.potAllocations.reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
            }

            if store.snapshot.payPeriods.isEmpty {
                AppCard { EmptyStateView(title: "No history", message: "Paycheck plans and allocation breakdowns appear here.", systemImage: "clock") }
            } else {
                ForEach(store.snapshot.payPeriods.sorted { $0.payday > $1.payday }) { period in
                    AppCard {
                        MetricRow(label: "Payday", value: period.payday)
                        MetricRow(label: "Income", value: MoneyParser.formatPence(period.incomePence), valueColor: AppTheme.Colors.success)
                        MetricRow(label: "Allocated", value: MoneyParser.formatPence(allocations(for: period).reduce(0) { $0 + $1.amountPence }), valueColor: AppTheme.Colors.primaryOrange)
                        ForEach(allocations(for: period)) { allocation in
                            MetricRow(label: store.snapshot.pots.first(where: { $0.id == allocation.potId })?.name ?? "Pot", value: MoneyParser.formatPence(allocation.amountPence))
                        }
                    }
                }
            }
        }
    }

    private func allocations(for period: PayPeriod) -> [PotAllocation] {
        store.snapshot.potAllocations.filter { $0.payPeriodId == period.id }
    }
}

struct SettingsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @State private var hourlyRate = ""
    @State private var hours = ""
    @State private var showResetAlert = false
    @State private var resetDataToggle = false

    var body: some View {
        ScreenScaffold(
            title: "Settings",
            subtitle: "Planner defaults, account placeholders, and local data controls.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            AppCard(glow: true) {
                SectionTitle("Pay defaults")
                Picker("Pay frequency", selection: bindingPayFrequency) {
                    ForEach(PayFrequency.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                MoneyField(title: "Hourly rate", text: $hourlyRate)
                TextField("Default hours", text: $hours).keyboardType(.decimalPad).textFieldStyle(AppTextFieldStyle())
                SecondaryButton(title: "Save pay defaults", systemImage: "checkmark") {
                    var settings = store.snapshot.settings
                    settings.hourlyRatePence = MoneyParser.parsePoundsToPence(hourlyRate)
                    settings.defaultHoursWorked = Double(hours) ?? settings.defaultHoursWorked
                    store.updateSettings(settings)
                }
            }

            DateSimulationCard(store: store)

            historyLink

            AppCard {
                SectionTitle("AI")
                Picker("Provider", selection: bindingAIProvider) {
                    ForEach(AIProvider.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                TextEditor(text: bindingAIInstructions)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(AppTheme.Spacing.sm)
                    .background(AppTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            }

            accountCard

            resetDataCard
        }
        .onAppear {
            hourlyRate = String(format: "%.2f", Double(store.snapshot.settings.hourlyRatePence) / 100)
            hours = String(format: "%.0f", store.snapshot.settings.defaultHoursWorked)
        }
        .alert("Reset local planner?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {
                resetDataToggle = false
            }
            Button("Reset", role: .destructive) {
                store.resetLocalData()
                hourlyRate = "0.00"
                hours = "0"
                resetDataToggle = false
            }
        } message: {
            Text("This clears local iPhone planner inputs and returns the app to its default data.")
        }
    }

    private var historyLink: some View {
        NavigationLink {
            HistoryView(store: store)
        } label: {
            AppCard {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("History")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text("Paycheck and allocation history.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var accountCard: some View {
        AppCard {
            SectionTitle("Account")
            MetricRow(label: "Native Firebase", value: "Not configured", valueColor: AppTheme.Colors.warning)
            MetricRow(label: "Cloud sync", value: "Placeholder service")
            Text("TODO: add Firebase iOS Auth, GoogleService-Info.plist, Google/Apple provider setup, and Firestore snapshot sync for users/{uid}/planner/snapshot.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var resetDataCard: some View {
        AppCard {
            SectionTitle("Data")
            Toggle("Reset data", isOn: resetDataBinding)
                .tint(AppTheme.Colors.danger)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Clears paychecks, pots, bills, cards, debts, spending, history, date simulation, and saved settings from this iPhone.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var resetDataBinding: Binding<Bool> {
        Binding {
            resetDataToggle
        } set: { isOn in
            resetDataToggle = isOn
            if isOn {
                showResetAlert = true
            }
        }
    }

    private var bindingPayFrequency: Binding<PayFrequency> {
        Binding {
            store.snapshot.settings.payFrequency
        } set: {
            var settings = store.snapshot.settings
            settings.payFrequency = $0
            settings.defaultPayPeriodDays = FinanceEngine.frequencyToDays($0)
            store.updateSettings(settings)
        }
    }

    private var bindingAIProvider: Binding<AIProvider> {
        Binding {
            store.snapshot.settings.aiProvider
        } set: {
            var settings = store.snapshot.settings
            settings.aiProvider = $0
            store.updateSettings(settings)
        }
    }

    private var bindingAIInstructions: Binding<String> {
        Binding {
            store.snapshot.settings.aiInstructions
        } set: {
            var settings = store.snapshot.settings
            settings.aiInstructions = $0
            store.updateSettings(settings)
        }
    }
}

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            SettingsView(store: store, navigationMode: .inline, toolbarMode: .none)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

enum AssistantPresentationMode: Equatable {
    case modal
    case pushed
}

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var presentationMode: AssistantPresentationMode = .modal
    @State private var prompt = ""
    @State private var isAssistantOptionsPresented = false
    @State private var activeAssistantSheet: AssistantSettingsSheet?
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: "Assistant", text: "I can summarise your local planner. Authenticated AI chat needs the native Firebase/backend TODOs in Settings.")
    ]
    @FocusState private var isPromptFocused: Bool
    private let assistantCoordinateSpace = "assistantScrollSpace"

    @ViewBuilder
    var body: some View {
        switch presentationMode {
        case .modal:
            NavigationStack {
                assistantContent
            }
        case .pushed:
            assistantContent
        }
    }

    private var assistantContent: some View {
        ScrollViewReader { proxy in
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            AppCard(glow: true) {
                                MetricRow(label: "Spendable", value: MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots)), valueColor: AppTheme.Colors.primaryOrange)
                                MetricRow(label: "Active cards", value: "\(store.activeCards.count)")
                                MetricRow(label: "Active debts", value: "\(store.activeDebts.count)")
                            }
                            .assistantBottomContentBlur(viewportHeight: geometry.size.height, coordinateSpaceName: assistantCoordinateSpace)

                            ForEach(messages) { message in
                                HStack {
                                    if message.role == "You" { Spacer() }
                                    Text(message.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                        .padding(AppTheme.Spacing.md)
                                        .background(message.role == "You" ? AppTheme.Colors.primaryOrange.opacity(0.32) : AppTheme.Colors.elevatedSurface)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                                    if message.role != "You" { Spacer() }
                                }
                                .assistantBottomContentBlur(viewportHeight: geometry.size.height, coordinateSpaceName: assistantCoordinateSpace)
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, AppTheme.Spacing.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollToBottom(with: proxy, animated: false)
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(with: proxy)
                    }
                    .onChange(of: isPromptFocused) { _, isFocused in
                        if isFocused {
                            scrollToBottomAfterLayoutSettles(with: proxy)
                        }
                    }

                    assistantComposer(proxy: proxy)
                        .zIndex(1)
                }
                .coordinateSpace(name: assistantCoordinateSpace)
                .premiumScreenBackground()
                .navigationTitle("Assistant")
                .toolbar {
                    if presentationMode == .modal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
                }
                .appPlaceholderToolbar(.actions([
                    AppToolbarAction(id: "assistant-options", symbol: "ellipsis.circle", accessibilityLabel: "Assistant Options") {
                        isAssistantOptionsPresented = true
                    }
                ]))
                .confirmationDialog("Assistant options", isPresented: $isAssistantOptionsPresented, titleVisibility: .visible) {
                    Button("Add custom instructions") {
                        activeAssistantSheet = .instructions
                    }
                    Button("Customise assistant") {
                        activeAssistantSheet = .customise
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(item: $activeAssistantSheet) { sheet in
                    switch sheet {
                    case .instructions:
                        AssistantCustomInstructionsView(store: store)
                    case .customise:
                        AssistantCustomiseView(store: store)
                    }
                }
            }
        }
    }

    private func assistantComposer(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            promptField(proxy: proxy)

            Button {
                sendLocalReply()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.Gradients.primary)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.Colors.glowOrange.opacity(0.6), radius: 12, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(prompt.isBlank)
        }
        .padding(AppTheme.Spacing.lg)
    }

    private func promptField(proxy: ScrollViewProxy) -> some View {
        TextField("Ask Assistant", text: $prompt)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 48)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.primaryText.opacity(0.14), lineWidth: 1)
            )
            .focused($isPromptFocused)
            .simultaneousGesture(
                TapGesture().onEnded {
                    scrollToBottomAfterLayoutSettles(with: proxy)
                }
            )
    }

    private func scrollToBottomAfterLayoutSettles(with proxy: ScrollViewProxy) {
        scrollToBottom(with: proxy)
        DispatchQueue.main.async {
            scrollToBottom(with: proxy)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            scrollToBottom(with: proxy)
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageID = messages.last?.id else { return }
        if animated {
            withAnimation(AppTheme.Animation.standard) {
                proxy.scrollTo(lastMessageID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageID, anchor: .bottom)
        }
    }

    private func sendLocalReply() {
        let text = prompt
        messages.append(AssistantMessage(role: "You", text: text))
        prompt = ""
        let period = store.selectedPayPeriod
        let name = store.snapshot.settings.assistantName?.nilIfBlank ?? "Assistant"
        let reply = "Local summary: \(MoneyParser.formatPence(period?.incomePence ?? 0)) income in the current plan, \(MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots))) spendable, and \(store.snapshot.recurringPayments.filter(\.active).count) active bills. Authenticated AI actions are waiting on native Firebase ID tokens."
        messages.append(AssistantMessage(role: name, text: reply))
    }
}

private enum AssistantSettingsSheet: String, Identifiable {
    case instructions
    case customise

    var id: String { rawValue }
}

private struct AssistantCustomInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    AppCard(glow: true) {
                        SectionTitle("Custom instructions")
                        Text("Type or paste the prompt the assistant should remember when helping with your planner.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                        TextEditor(text: $instructions)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 220)
                            .padding(AppTheme.Spacing.sm)
                            .background(AppTheme.Colors.elevatedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                    .stroke(AppTheme.Colors.border, lineWidth: 1)
                            )
                        PrimaryButton(title: "Save instructions", systemImage: "checkmark") {
                            var settings = store.snapshot.settings
                            settings.aiInstructions = instructions
                            store.updateSettings(settings)
                            dismiss()
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Instructions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
            .onAppear {
                instructions = store.snapshot.settings.aiInstructions
            }
        }
    }
}

private struct AssistantCustomiseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var assistantName = ""
    @State private var responseStyle: AssistantResponseStyle = .straightToThePoint

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    AppCard(glow: true) {
                        SectionTitle("Customise assistant")
                        TextField("Assistant name", text: $assistantName)
                            .textFieldStyle(AppTextFieldStyle())
                        VStack(spacing: AppTheme.Spacing.sm) {
                            ForEach(AssistantResponseStyle.allCases) { style in
                                Button {
                                    responseStyle = style
                                } label: {
                                    HStack {
                                        Text(style.label)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                        Spacer()
                                        if responseStyle == style {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                                        }
                                    }
                                    .padding(AppTheme.Spacing.md)
                                    .background(responseStyle == style ? AppTheme.Colors.primaryOrange.opacity(0.12) : AppTheme.Colors.elevatedSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                            .stroke(responseStyle == style ? AppTheme.Colors.primaryOrange.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        PrimaryButton(title: "Save assistant", systemImage: "checkmark") {
                            var settings = store.snapshot.settings
                            settings.assistantName = assistantName.nilIfBlank ?? "Assistant"
                            settings.assistantResponseStyle = responseStyle
                            store.updateSettings(settings)
                            dismiss()
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Customise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
            .onAppear {
                assistantName = store.snapshot.settings.assistantName?.nilIfBlank ?? "Assistant"
                responseStyle = store.snapshot.settings.assistantResponseStyle ?? .straightToThePoint
            }
        }
    }
}

private struct AssistantBottomContentBlurModifier: ViewModifier {
    let viewportHeight: CGFloat
    let coordinateSpaceName: String

    private let blurZoneHeight: CGFloat = 132
    private let blurRampHeight: CGFloat = 72
    private let maxBlurRadius: CGFloat = 2.4

    func body(content: Content) -> some View {
        content.visualEffect { effect, geometry in
            let frame = geometry.frame(in: .named(coordinateSpaceName))
            let zoneStart = viewportHeight - blurZoneHeight
            let distanceIntoZone = max(frame.maxY - zoneStart, 0)
            let progress = min(distanceIntoZone / blurRampHeight, 1)

            return effect.blur(radius: progress * maxBlurRadius)
        }
    }
}

private extension View {
    func assistantBottomContentBlur(viewportHeight: CGFloat, coordinateSpaceName: String) -> some View {
        modifier(AssistantBottomContentBlurModifier(viewportHeight: viewportHeight, coordinateSpaceName: coordinateSpaceName))
    }
}

private func eligibleDebtPots(in snapshot: PlannerSnapshot, debtId: String?) -> [Pot] {
    snapshot.pots
        .filter {
            !$0.archived &&
            $0.linkedCreditCardId == nil &&
            ($0.linkedDebtId == nil || $0.linkedDebtId == debtId)
        }
        .sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.id < rhs.id
            }
            return lhs.name < rhs.name
        }
}

private func linkedDebtPot(in snapshot: PlannerSnapshot, debtId: String) -> Pot? {
    eligibleDebtPots(in: snapshot, debtId: debtId)
        .first { $0.linkedDebtId == debtId }
}

private func linkedDebtPotName(in snapshot: PlannerSnapshot, debtId: String) -> String? {
    linkedDebtPot(in: snapshot, debtId: debtId)?.name
}

private func debtSummaryLine(for debt: Debt, in snapshot: PlannerSnapshot) -> String {
    if let potName = linkedDebtPotName(in: snapshot, debtId: debt.id) {
        return "\(debt.lender) · \(potName) · \(debtStrategyLabel(debt.repaymentStrategy))"
    }
    return "\(debt.lender) · \(debtStrategyLabel(debt.repaymentStrategy))"
}

private func debtTypeLabel(_ type: DebtType) -> String {
    switch type {
    case .informal: return "Informal"
    case .bnpl: return "BNPL"
    case .personalLoan: return "Personal loan"
    case .overdraft: return "Overdraft"
    case .creditAgreement: return "Credit agreement"
    case .other: return "Other"
    }
}

private func debtInterestLabel(_ type: DebtInterestType) -> String {
    switch type {
    case .none: return "None"
    case .apr: return "APR"
    case .fixedFee: return "Fee"
    }
}

private func debtStrategyLabel(_ strategy: DebtRepaymentStrategy) -> String {
    switch strategy {
    case .autoSpreadUntilDueDate: return "Auto spread"
    case .payIn4: return "Pay in 4"
    case .fixedPayment: return "Fixed payment"
    case .minimumPlusExtra: return "Minimum + extra"
    case .manualOnly: return "Manual only"
    }
}

private func debtFrequencyLabel(_ frequency: DebtPaymentFrequency) -> String {
    switch frequency {
    case .weekly: return "Weekly"
    case .fortnightly: return "Fortnightly"
    case .monthly: return "Monthly"
    case .custom: return "Custom"
    }
}

private func debtFirstPaymentLabel(_ timing: DebtPayFirstTiming) -> String {
    switch timing {
    case .today: return "Today"
    case .nextPayday: return "Next payday"
    case .customDate: return "Custom"
    }
}

private func debtStatusLabel(_ status: DebtStatus) -> String {
    status.rawValue
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}

private struct AssistantMessage: Identifiable {
    let id = UUID()
    var role: String
    var text: String
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        isBlank ? nil : self
    }
}
