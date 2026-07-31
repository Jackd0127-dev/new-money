import SwiftUI

enum SpendingFormLayoutPolicy {
    static let accountPickerStyle = "selectionFieldBox"
    static let paymentMethods: [PaymentMethod] = [.income, .bankAccount, .pot, .creditCard]
}

struct SpendingView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @State private var paymentMethod: PaymentMethod = .income
    @State private var selectedPotId = ""
    @State private var selectedCardId = ""
    @State private var selectedBankAccountId = ""
    @State private var amount = ""
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        ScreenScaffold(
            title: "Spending",
            subtitle: "",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            AppCard(glow: true) {
                Picker("Route", selection: $paymentMethod) {
                    Text("Money").tag(PaymentMethod.income)
                    Text("Bank").tag(PaymentMethod.bankAccount)
                    Text("Pot").tag(PaymentMethod.pot)
                    Text("Card").tag(PaymentMethod.creditCard)
                }
                .pickerStyle(.segmented)

                if paymentMethod == .income {
                    Text("Deduct this debit-card spend directly from money left in the current pay period.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                } else if paymentMethod == .bankAccount {
                    SelectionField(title: "Bank account", value: selectedBankAccountName, placeholder: "No account", systemImage: "building.columns") {
                        ForEach(store.activeBankAccounts) { account in
                            Button(account.name) { selectedBankAccountId = account.id }
                        }
                    }
                } else if paymentMethod == .pot {
                    SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                        ForEach(store.activePots) { pot in
                            Button(pot.name) { selectedPotId = pot.id }
                        }
                    }
                } else {
                    SelectionField(title: "Card", value: selectedCardName, placeholder: "No card", systemImage: "creditcard") {
                        ForEach(store.activeCards) { card in
                            Button(card.name) { selectedCardId = card.id }
                        }
                    }
                }

                MoneyField(title: "Amount", text: $amount)
                TextField("Note", text: $note).textFieldStyle(AppTextFieldStyle())
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .tint(AppTheme.Colors.primaryOrange)
                PrimaryButton(title: "Record spending", systemImage: "cart", isDisabled: !canSubmit) {
                    store.recordTransaction(
                        potId: paymentMethod == .pot ? selectedPotId : nil,
                        creditCardId: paymentMethod == .creditCard ? selectedCardId : nil,
                        bankAccountId: paymentMethod == .bankAccount ? selectedBankAccountId : nil,
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
            selectedBankAccountId = store.primaryBankAccount?.id ?? ""
        }
    }

    private var canSubmit: Bool {
        guard MoneyParser.parsePoundsToPence(amount) > 0 else { return false }
        return switch paymentMethod {
        case .income:
            true
        case .bankAccount:
            !selectedBankAccountId.isEmpty
        case .pot:
            !selectedPotId.isEmpty
        case .creditCard:
            !selectedCardId.isEmpty
        }
    }

    private var selectedPotName: String {
        store.activePots.first { $0.id == selectedPotId }?.name ?? ""
    }

    private var selectedCardName: String {
        store.activeCards.first { $0.id == selectedCardId }?.name ?? ""
    }

    private var selectedBankAccountName: String {
        store.activeBankAccounts.first { $0.id == selectedBankAccountId }?.name ?? ""
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
                Text("\(dateLabel) · \(routeLabel)\(transaction.isRefunded ? " · Refunded" : "")")
                    .font(.caption)
                    .foregroundStyle(transaction.isRefunded ? AppTheme.Colors.success : AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text(transaction.isRefunded ? MoneyParser.formatPence(transaction.amountPence) : "-\(MoneyParser.formatPence(transaction.amountPence))")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(transaction.isRefunded ? AppTheme.Colors.tertiaryText : AppTheme.Colors.orangeHighlight)
                .multilineTextAlignment(.trailing)
        }
        .contentShape(Rectangle())
    }
}

struct SpendingTransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var transaction: Transaction
    @State private var paymentMethod: PaymentMethod
    @State private var selectedPotId: String
    @State private var selectedCardId: String
    @State private var selectedBankAccountId: String
    @State private var amount: String
    @State private var note: String
    @State private var date: Date
    @State private var isDeleteConfirmationPresented = false

    init(store: PlannerStore, transaction: Transaction) {
        self.store = store
        self.transaction = transaction
        let initialMethod = transaction.paymentMethod
            ?? (transaction.bankAccountId != nil ? .bankAccount : (transaction.creditCardId == nil ? .pot : .creditCard))
        _paymentMethod = State(initialValue: initialMethod)
        _selectedPotId = State(initialValue: transaction.potId ?? "")
        _selectedCardId = State(initialValue: transaction.creditCardId ?? "")
        _selectedBankAccountId = State(initialValue: transaction.bankAccountId ?? "")
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
                        Text("Money").tag(PaymentMethod.income)
                        Text("Bank").tag(PaymentMethod.bankAccount)
                        Text("Pot").tag(PaymentMethod.pot)
                        Text("Card").tag(PaymentMethod.creditCard)
                    }
                    .pickerStyle(.segmented)

                    if paymentMethod == .income {
                        Text("This spend is deducted directly from money left in its pay period.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    } else if paymentMethod == .bankAccount {
                        Picker("Bank account", selection: $selectedBankAccountId) {
                            Text("No account").tag("")
                            ForEach(selectableBankAccounts) { account in
                                Text(account.name).tag(account.id)
                            }
                        }
                        .pickerStyle(.menu)
                    } else if paymentMethod == .pot {
                        Picker("Pot", selection: $selectedPotId) {
                            Text("No pot").tag("")
                            ForEach(selectablePots) { pot in
                                Text(pot.name).tag(pot.id)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Picker("Card", selection: $selectedCardId) {
                            Text("No card").tag("")
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
                    Toggle("This payment was refunded", isOn: Binding(
                        get: { currentTransaction.isRefunded },
                        set: { store.setTransactionRefunded(id: transaction.id, refunded: $0) }
                    ))
                    .tint(AppTheme.Colors.primaryOrange)
                    if currentTransaction.isRefunded {
                        Text("Refunded payments remain in your history but no longer affect money left, pots, or card balances.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    PrimaryButton(title: "Save changes", systemImage: "checkmark", isDisabled: !canSave) {
                        store.updateTransaction(
                            id: transaction.id,
                            potId: paymentMethod == .pot ? selectedPotId : nil,
                            creditCardId: paymentMethod == .creditCard ? selectedCardId : nil,
                            bankAccountId: paymentMethod == .bankAccount ? selectedBankAccountId : nil,
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedPotId.isEmpty {
                selectedPotId = selectablePots.first?.id ?? ""
            }
            if selectedCardId.isEmpty {
                selectedCardId = selectableCards.first?.id ?? ""
            }
            if selectedBankAccountId.isEmpty {
                selectedBankAccountId = selectableBankAccounts.first(where: \.isPrimary)?.id
                    ?? selectableBankAccounts.first?.id
                    ?? ""
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

    private var currentTransaction: Transaction {
        store.snapshot.transactions.first(where: { $0.id == transaction.id }) ?? transaction
    }

    private var selectableCards: [CreditCard] {
        let active = store.activeCards
        guard let currentCardId = transaction.creditCardId,
              !active.contains(where: { $0.id == currentCardId }),
              let currentCard = store.snapshot.creditCards.first(where: { $0.id == currentCardId })
        else { return active }
        return active + [currentCard]
    }

    private var selectableBankAccounts: [BankAccount] {
        let active = store.activeBankAccounts
        guard let currentId = transaction.bankAccountId,
              !active.contains(where: { $0.id == currentId }),
              let currentAccount = store.snapshot.bankAccounts.first(where: { $0.id == currentId })
        else { return active }
        return active + [currentAccount]
    }

    private var canSave: Bool {
        guard !currentTransaction.isRefunded else { return false }
        guard MoneyParser.parsePoundsToPence(amount) > 0 else { return false }
        return switch paymentMethod {
        case .income:
            true
        case .bankAccount:
            !selectedBankAccountId.isEmpty
        case .pot:
            !selectedPotId.isEmpty
        case .creditCard:
            !selectedCardId.isEmpty
        }
    }

}

private func spendingRouteLabel(for transaction: Transaction, snapshot: PlannerSnapshot) -> String {
    if transaction.paymentMethod == .income {
        return PaymentMethod.income.displayName
    }

    if transaction.paymentMethod == .creditCard || transaction.creditCardId != nil {
        guard let cardId = transaction.creditCardId else { return "Credit card" }
        return snapshot.creditCards.first { $0.id == cardId }?.name ?? "Credit card"
    }

    if transaction.paymentMethod == .bankAccount || transaction.bankAccountId != nil {
        guard let bankAccountId = transaction.bankAccountId else { return "Bank account" }
        return snapshot.bankAccounts.first { $0.id == bankAccountId }?.name ?? "Bank account"
    }

    if let potId = transaction.potId {
        return snapshot.pots.first { $0.id == potId }?.name ?? "Pot"
    }

    return "Money left"
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

enum AddBillFormLayoutPolicy {
    static let hidesNavigationDivider = true
    static let allowedFrequencies: [RecurringFrequency] = [.weekly, .biweekly, .monthly, .yearly]
}

enum BillPaymentRoute: String, CaseIterable, Identifiable {
    case pot
    case creditCard
    case bankAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pot: "Pot"
        case .creditCard: "Card"
        case .bankAccount: "Bank"
        }
    }
}

private struct BillEditorFormCard: View {
    @ObservedObject var store: PlannerStore
    var title: String
    @Binding var name: String
    @Binding var amount: String
    @Binding var dueDay: String
    @Binding var frequency: RecurringFrequency
    @Binding var priority: RecurringPriority
    @Binding var potId: String
    @Binding var cardId: String
    @Binding var bankAccountId: String
    @Binding var billGroupId: String
    @Binding var paymentRoute: BillPaymentRoute
    @Binding var isActive: Bool
    var showsActiveToggle = false
    var primaryTitle: String
    var primarySystemImage: String
    var isPrimaryDisabled: Bool
    var primaryAction: () -> Void

    var body: some View {
        AppCard(glow: true) {
            SectionTitle(title)
            TextField("Name", text: $name).textFieldStyle(AppTextFieldStyle())
            MoneyField(title: "Amount", text: $amount)
            TextField("Due day", text: $dueDay)
                .keyboardType(.numberPad)
                .textFieldStyle(AppTextFieldStyle())
            Picker("Frequency", selection: $frequency) {
                ForEach(AddBillFormLayoutPolicy.allowedFrequencies) { frequency in
                    Text(frequency.rawValue.capitalized).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            Picker("Priority", selection: $priority) {
                ForEach(RecurringPriority.allCases) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            if showsActiveToggle {
                Toggle("Active", isOn: $isActive)
                    .tint(AppTheme.Colors.primaryOrange)
            }
            if !store.activeBillGroups.isEmpty {
                SelectionField(title: "Group", value: selectedBillGroupName, placeholder: "Ungrouped", systemImage: "folder") {
                    Button("Ungrouped") { billGroupId = "" }
                    ForEach(store.activeBillGroups) { group in
                        Button(group.name) { billGroupId = group.id }
                    }
                }
            }
            Picker("Paid from", selection: $paymentRoute) {
                ForEach(BillPaymentRoute.allCases) { route in
                    Text(route.title).tag(route)
                }
            }
            .pickerStyle(.segmented)
            if paymentRoute == .creditCard {
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
            } else if paymentRoute == .pot {
                SelectionField(title: "Pot", value: selectedPotName, placeholder: "No pot", systemImage: "wallet.pass") {
                    Button("No pot") { potId = "" }
                    ForEach(store.activePots) { pot in
                        Button(pot.name) { potId = pot.id }
                    }
                }
            } else {
                SelectionField(title: "Bank account", value: selectedBankAccountName, placeholder: "No account", systemImage: "building.columns") {
                    Button("No account") { bankAccountId = "" }
                    ForEach(store.activeBankAccounts) { account in
                        Button(account.name) { bankAccountId = account.id }
                    }
                }
            }
            PrimaryButton(title: primaryTitle, systemImage: primarySystemImage, isDisabled: isPrimaryDisabled, action: primaryAction)
        }
        .onChange(of: cardId) { _, _ in normalizeSelectedCardPot() }
        .onChange(of: paymentRoute) { _, _ in normalizeSelectedCardPot() }
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

    private var selectedBankAccountName: String {
        store.activeBankAccounts.first { $0.id == bankAccountId }?.name ?? ""
    }

    private var selectedBillGroupName: String {
        store.activeBillGroups.first { $0.id == billGroupId }?.name ?? ""
    }

    private func normalizeSelectedCardPot() {
        guard paymentRoute == .creditCard else { return }
        if !cardLinkedPots.contains(where: { $0.id == potId }) {
            potId = cardLinkedPots.first?.id ?? ""
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
    @State private var bankAccountId = ""
    @State private var billGroupId = ""
    @State private var paymentRoute: BillPaymentRoute = .pot
    @State private var isActive = true

    var body: some View {
        NavigationStack {
            ScrollView {
                BillEditorFormCard(
                    store: store,
                    title: "Add recurring payment",
                    name: $name,
                    amount: $amount,
                    dueDay: $dueDay,
                    frequency: $frequency,
                    priority: $priority,
                    potId: $potId,
                    cardId: $cardId,
                    bankAccountId: $bankAccountId,
                    billGroupId: $billGroupId,
                    paymentRoute: $paymentRoute,
                    isActive: $isActive,
                    primaryTitle: "Add bill",
                    primarySystemImage: "plus",
                    isPrimaryDisabled: !canSave
                ) {
                        store.addRecurringPayment(
                            name: name,
                            amountPence: MoneyParser.parsePoundsToPence(amount),
                            dueDay: Int(dueDay),
                            frequency: frequency,
                            potId: cleanPotId,
                            creditCardId: paymentRoute == .creditCard ? cardId.nilIfBlank : nil,
                            bankAccountId: paymentRoute == .bankAccount ? bankAccountId.nilIfBlank : nil,
                            priority: priority,
                            billGroupId: billGroupId.nilIfBlank
                        )
                        reset()
                        dismiss()
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add bill")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .onAppear {
            potId = store.activePots.first?.id ?? ""
            cardId = store.activeCards.first?.id ?? ""
            bankAccountId = store.primaryBankAccount?.id ?? store.activeBankAccounts.first?.id ?? ""
            normalizeSelectedCardPot()
        }
    }

    private func reset() {
        name = ""
        amount = ""
        dueDay = ""
        frequency = .monthly
        priority = .essential
        billGroupId = ""
        paymentRoute = .pot
        isActive = true
    }

    private var cardLinkedPots: [Pot] {
        store.activePots.filter { $0.linkedCreditCardId == cardId }
    }

    private var canSave: Bool {
        !name.isBlank
            && MoneyParser.parsePoundsToPence(amount) > 0
            && (paymentRoute != .bankAccount || !bankAccountId.isBlank)
    }

    private var cleanPotId: String? {
        if paymentRoute == .creditCard {
            return cardLinkedPots.contains(where: { $0.id == potId }) ? potId.nilIfBlank : nil
        }

        return paymentRoute == .pot ? potId.nilIfBlank : nil
    }

    private func normalizeSelectedCardPot() {
        guard paymentRoute == .creditCard else { return }
        if !cardLinkedPots.contains(where: { $0.id == potId }) {
            potId = cardLinkedPots.first?.id ?? ""
        }
    }
}

private struct EditBillView: View {
    @ObservedObject var store: PlannerStore
    var payment: RecurringPayment
    @State private var name: String
    @State private var amount: String
    @State private var dueDay: String
    @State private var frequency: RecurringFrequency
    @State private var priority: RecurringPriority
    @State private var potId: String
    @State private var cardId: String
    @State private var bankAccountId: String
    @State private var billGroupId: String
    @State private var paymentRoute: BillPaymentRoute
    @State private var isActive: Bool
    @State private var isDeleteConfirmationPresented = false

    init(store: PlannerStore, payment: RecurringPayment) {
        self.store = store
        self.payment = payment
        _name = State(initialValue: payment.name)
        _amount = State(initialValue: Self.formatMoneyInput(payment.amountPence))
        _dueDay = State(initialValue: payment.dueDay.map(String.init) ?? "")
        _frequency = State(initialValue: payment.frequency)
        _priority = State(initialValue: payment.priority)
        _potId = State(initialValue: payment.potId ?? "")
        _cardId = State(initialValue: payment.creditCardId ?? "")
        _bankAccountId = State(initialValue: payment.bankAccountId ?? "")
        _billGroupId = State(initialValue: payment.billGroupId ?? "")
        _paymentRoute = State(initialValue: payment.creditCardId != nil ? .creditCard : (payment.bankAccountId != nil ? .bankAccount : .pot))
        _isActive = State(initialValue: payment.active)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                BillEditorFormCard(
                    store: store,
                    title: "Bill details",
                    name: $name,
                    amount: $amount,
                    dueDay: $dueDay,
                    frequency: $frequency,
                    priority: $priority,
                    potId: $potId,
                    cardId: $cardId,
                    bankAccountId: $bankAccountId,
                    billGroupId: $billGroupId,
                    paymentRoute: $paymentRoute,
                    isActive: $isActive,
                    showsActiveToggle: true,
                    primaryTitle: "Save changes",
                    primarySystemImage: "checkmark",
                    isPrimaryDisabled: !canSave,
                    primaryAction: saveChanges
                )

                SecondaryButton(title: "Delete bill", systemImage: "trash", role: .destructive) {
                    isDeleteConfirmationPresented = true
                }
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle(BillsLayoutPolicy.editBillTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTopDividerHidden()
        .alert("Delete bill?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteRecurringPayment(id: payment.id)
            }
        } message: {
            Text("This removes the recurring bill from future bill lists and projected costs.")
        }
    }

    private var currentPayment: RecurringPayment {
        store.snapshot.recurringPayments.first(where: { $0.id == payment.id }) ?? payment
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && MoneyParser.parsePoundsToPence(amount) > 0
            && (paymentRoute != .bankAccount || !bankAccountId.isBlank)
    }

    private var cardLinkedPots: [Pot] {
        store.activePots.filter { $0.linkedCreditCardId == cardId }
    }

    private var cleanPotId: String? {
        if paymentRoute == .creditCard {
            return cardLinkedPots.contains(where: { $0.id == potId }) ? potId.nilIfBlank : nil
        }

        return paymentRoute == .pot ? potId.nilIfBlank : nil
    }

    private func saveChanges() {
        var updated = currentPayment
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.amountPence = MoneyParser.parsePoundsToPence(amount)
        updated.dueDay = Int(dueDay)
        updated.frequency = frequency
        updated.priority = priority
        updated.potId = cleanPotId
        updated.creditCardId = paymentRoute == .creditCard ? cardId.nilIfBlank : nil
        updated.bankAccountId = paymentRoute == .bankAccount ? bankAccountId.nilIfBlank : nil
        updated.billGroupId = billGroupId.nilIfBlank
        updated.active = isActive
        store.updateRecurringPayment(updated)
    }

    private static func formatMoneyInput(_ amountPence: Int) -> String {
        amountPence > 0 ? String(format: "%.2f", Double(amountPence) / 100) : ""
    }
}

enum BillsSection: String, Equatable {
    case overview
    case fundingChecklist
    case groups
    case upcoming
    case billGroups
}

enum BillsOverviewPresentation: Equatable {
    case navigationPush
}

enum BillsLayoutPolicy {
    static let sections: [BillsSection] = [.overview, .fundingChecklist, .groups, .billGroups, .upcoming]
    static let overviewPresentation: BillsOverviewPresentation = .navigationPush
    static let groupCreationPlacement = "groupsHeader"
    static let showsCreditCardAndPotLinksOnBills = false
    static let billGroupingPersistence = "recurringPayment.billGroupId"
    static let groupFilterScrollClipsContent = false
    static let groupFilterHorizontalContentPadding: CGFloat = 3
    static let overviewHeroUsesGlow = true
    static let detailShowsDuplicateUpcomingEmptyState = false
    static let fundingChecklistPlacement = "belowOverview"
    static let fundingChecklistAlwaysVisible = true
    static let fundingChecklistUsesExistingDerivedItems = true
    static let fundingChecklistProjectedPeriodCount = 2
    static let yourBillsPresentation = "collapsibleDropdown"
    static let takingSoonPresentation = "collapsibleDropdown"
    static let overviewUpcomingPresentation = "collapsibleProgressiveLazyList"
    static let overviewGroupsPresentation = "collapsibleDropdown"
    static let upcomingSchedulePageMonths = 12
    static let upcomingScheduleLoadsOnlyWhenExpanded = true
    static let collapsibleHeaderStyle = "activityExpandableSection"
    static let collapsibleHeaderMinimumHeight: CGFloat = 44
    static let collapsibleToggleDuration = 0.18
    static let collapsibleUsesReduceMotionSafeAnimation = true
    static let yourBillsAppearsAboveTakingSoon = true
    static let billRowsOpenEditScreen = true
    static let billRowsShowChevron = false
    static let billRowsShowTrailingMenu = false
    static let billIconSize: CGFloat = 30
    static let editBillTitle = "Edit Bill"
    static let editUsesExistingRecurringPaymentUpdate = true
}

private struct BillsTabPresentation {
    var activeBillGroups: [BillGroup]
    var sortedBills: [RecurringPayment]
    var ungroupedBills: [RecurringPayment]
    var billsByGroupId: [String: [RecurringPayment]]
    var upcomingOccurrences: [RecurringPaymentOccurrence]
    var fundingChecklistGroups: [BillsFundingChecklistPeriodGroup]
    var nextDueLabelsByPaymentId: [String: String]
    var activeBillCount: Int
    var activeTemplateTotalPence: Int
    var linkedBillCount: Int
}

private struct BillsFundingChecklistPeriodGroup: Identifiable {
    var id: String { payPeriod.id }
    var payPeriod: PayPeriod
    var items: [FundingChecklistPresentationItem]
}

struct BillsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    var rootTabResetRevision: Int?
    var presentationCache: PlannerTabPresentationCache?
    var presentationContext: PlannerTabPresentationContext?
    @State private var selectedGroupId: String?
    @State private var selectedBillIdForEdit: String?
    @State private var isYourBillsExpanded = true
    @State private var isUpcomingExpanded = false
    @State private var isNewGroupPresented = false
    @State private var newGroupName = ""
    @State private var selectedOccurrenceForAdjustment: RecurringPaymentOccurrence?

    private let ungroupedGroupId = "ungrouped"

    var body: some View {
        ScreenScaffold(
            title: "Bills",
            subtitle: "Recurring bills, groups, due dates, and linked pots or cards.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode,
            rootTabResetRevision: rootTabResetRevision
        ) {
            ForEach(BillsLayoutPolicy.sections, id: \.rawValue) { section in
                billsSection(section)
            }
        }
        .alert("New bill group", isPresented: $isNewGroupPresented) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) {
                newGroupName = ""
            }
            Button("Create") {
                createGroup()
            }
            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Use groups to keep subscriptions, home bills, card bills, and savings transfers tidy.")
        }
        .onChange(of: tabPresentation.activeBillGroups.map(\.id)) { _, groupIds in
            if let selectedGroupId,
               selectedGroupId != ungroupedGroupId,
               !groupIds.contains(selectedGroupId) {
                self.selectedGroupId = nil
            }
        }
        .navigationDestination(item: $selectedBillIdForEdit) { paymentId in
            if let payment = store.snapshot.recurringPayments.first(where: { $0.id == paymentId }) {
                EditBillView(store: store, payment: payment)
            }
        }
        .sheet(item: $selectedOccurrenceForAdjustment) { occurrence in
            RecurringBillOccurrenceAdjustmentSheet(store: store, occurrence: occurrence)
        }
    }

    @ViewBuilder
    private func billsSection(_ section: BillsSection) -> some View {
        switch section {
        case .overview:
            overviewCard
        case .fundingChecklist:
            fundingChecklistSection
        case .groups:
            groupsSection
        case .upcoming:
            upcomingSection
        case .billGroups:
            groupedBillsSection
        }
    }

    private var overviewCard: some View {
        NavigationLink {
            BillsOverviewDetailView(store: store)
        } label: {
            AppCard(glow: BillsLayoutPolicy.overviewHeroUsesGlow) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Bills")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.cardEyebrow)
                                .textCase(.uppercase)
                            Text(MoneyParser.formatPence(activeTemplateTotalPence))
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(activeBillCount == 0 ? "No active bills yet" : "\(activeBillCount) active templates")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                        }

                        Spacer(minLength: AppTheme.Spacing.sm)

                        VStack(alignment: .trailing, spacing: 8) {
                            HStack(spacing: 5) {
                                Text("Details")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryOrange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.primaryOrange.opacity(0.13))
                            .clipShape(Capsule())

                            Text(nextBillTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                            Text(nextBillDate)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                        }
                    }

                    HStack(spacing: AppTheme.Spacing.sm) {
                        BillsOverviewPill(title: "\(linkedBillCount)", subtitle: "linked", color: AppTheme.Colors.success)
                        BillsOverviewPill(title: "\(tabPresentation.activeBillGroups.count)", subtitle: "groups", color: AppTheme.Colors.primaryOrange)
                        BillsOverviewPill(title: "\(ungroupedBills.count)", subtitle: "ungrouped", color: AppTheme.Colors.secondaryText)
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Open bill details")
        .accessibilityHint("Shows bill totals, linked bills, upcoming dates, and groups.")
    }

    private var fundingChecklistSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Funding checklist")

            if fundingChecklistGroups.isEmpty {
                AppCard {
                    EmptyStateView(
                        title: "Nothing to tick off",
                        message: "Linked bills, card payments, and debt funding will be grouped by income period here.",
                        systemImage: "checklist"
                    )
                }
            } else {
                ForEach(fundingChecklistGroups) { group in
                    BillsFundingChecklistPeriodCard(group: group) { item in
                        applyFundingChecklistAction(item)
                    } excludeAction: { item in
                        applyFundingChecklistExclusion(item)
                    } adjustAction: { item in
                        selectedOccurrenceForAdjustment = recurringOccurrence(for: item)
                    }
                }
            }
        }
    }

    private var fundingChecklistGroups: [BillsFundingChecklistPeriodGroup] {
        tabPresentation.fundingChecklistGroups
    }

    private func recurringOccurrence(for item: FundingChecklistPresentationItem) -> RecurringPaymentOccurrence? {
        guard case let .recurringBill(paymentId, dueDate, _) = item.action,
              let payment = store.snapshot.recurringPayments.first(where: { $0.id == paymentId })
        else { return nil }

        return PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: store.snapshot,
            payments: [payment],
            startDate: PlannerDerivedData.addIsoMonthsClamped(date: store.todayIso, months: -2),
            endDate: PlannerDerivedData.addIsoMonthsClamped(date: store.todayIso, months: 3)
        )
        .first { $0.dueDate == dueDate }
    }

    private func applyFundingChecklistAction(_ item: FundingChecklistPresentationItem) {
        guard item.status != .paidCompleted else { return }
        _ = store.setFundingChecklistCompleted(action: item.action, completed: item.isExcluded || !item.isCompleted)
    }

    private func applyFundingChecklistExclusion(_ item: FundingChecklistPresentationItem) {
        guard item.status != .paidCompleted else { return }
        _ = store.setFundingChecklistExcluded(action: item.action, excluded: !item.isExcluded)
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Groups", actionTitle: "New group") {
                isNewGroupPresented = true
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    BillsGroupFilterPill(
                        title: "All",
                        count: sortedBills.count,
                        color: AppTheme.Colors.primaryOrange,
                        isSelected: selectedGroupId == nil
                    ) {
                        selectedGroupId = nil
                    }

                    ForEach(tabPresentation.activeBillGroups) { group in
                        BillsGroupFilterPill(
                            title: group.name,
                            count: bills(in: group).count,
                            color: Color(hex: group.color),
                            isSelected: selectedGroupId == group.id
                        ) {
                            selectedGroupId = group.id
                        }
                        .contextMenu {
                            Button("Delete group", role: .destructive) {
                                store.deleteBillGroup(id: group.id)
                            }
                        }
                    }

                    if !ungroupedBills.isEmpty {
                        BillsGroupFilterPill(
                            title: "Ungrouped",
                            count: ungroupedBills.count,
                            color: AppTheme.Colors.tertiaryText,
                            isSelected: selectedGroupId == ungroupedGroupId
                        ) {
                            selectedGroupId = ungroupedGroupId
                        }
                    }
                }
                .padding(.horizontal, BillsLayoutPolicy.groupFilterHorizontalContentPadding)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private var upcomingSection: some View {
        BillsCollapsibleSection(
            title: "Upcoming",
            subtitle: upcomingSectionSubtitle,
            isExpanded: $isUpcomingExpanded
        ) {
            if !refundedOccurrences.isEmpty {
                AppCard {
                    SectionTitle("Refunded")
                    ForEach(refundedOccurrences) { occurrence in
                        Button {
                            selectedOccurrenceForAdjustment = occurrence
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(occurrence.payment.name)
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                    Text("Refunded · (billsFriendlyDate(occurrence.scheduledDueDate))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.success)
                                }
                                Spacer()
                                Text(MoneyParser.formatPence(occurrence.amountPence))
                                    .foregroundStyle(AppTheme.Colors.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            BillsProgressiveUpcomingList(
                snapshot: store.snapshot,
                payments: sortedBills,
                todayIso: store.todayIso
            ) { occurrence in
                selectedOccurrenceForAdjustment = occurrence
            }
        }
    }

    private var groupedBillsSection: some View {
        BillsCollapsibleSection(
            title: "Your bills",
            subtitle: yourBillsSectionSubtitle,
            isExpanded: $isYourBillsExpanded
        ) {
            if sortedBills.isEmpty && tabPresentation.activeBillGroups.isEmpty {
                AppCard {
                    EmptyStateView(title: "No bills yet", message: "Use Add to create rent, subscriptions, utilities, transfers, or card-linked bills.", systemImage: "calendar.badge.plus")
                }
            } else {
                ForEach(displaySections) { section in
                    BillsGroupSectionCard(
                        section: section,
                        nextDueLabel: nextDueLabel(for:),
                        edit: { payment in
                            selectedBillIdForEdit = payment.id
                        }
                    )
                }
            }
        }
    }

    private var yourBillsSectionSubtitle: String {
        if sortedBills.isEmpty {
            return "No recurring bills yet"
        }

        return "\(sortedBills.count) bill\(sortedBills.count == 1 ? "" : "s")"
    }

    private var upcomingSectionSubtitle: String {
        "Next payments in date order"
    }

    private var activeBillCount: Int {
        tabPresentation.activeBillCount
    }

    private var activeTemplateTotalPence: Int {
        tabPresentation.activeTemplateTotalPence
    }

    private var linkedBillCount: Int {
        tabPresentation.linkedBillCount
    }

    private var nextBillTitle: String {
        nextBillOccurrence?.payment.name ?? "Next bill"
    }

    private var nextBillDate: String {
        nextBillOccurrence.map { billsFriendlyDate($0.dueDate) } ?? "None"
    }

    private var nextBillOccurrence: RecurringPaymentOccurrence? {
        upcomingOccurrences.first
    }

    private var upcomingOccurrences: [RecurringPaymentOccurrence] {
        tabPresentation.upcomingOccurrences
    }

    private var refundedOccurrences: [RecurringPaymentOccurrence] {
        store.snapshot.recurringPaymentOccurrenceOverrides
            .filter { $0.deletedAt == nil && $0.state == .refunded }
            .compactMap { override in
                guard let payment = store.snapshot.recurringPayments.first(where: { $0.id == override.paymentId }) else { return nil }
                return RecurringPaymentOccurrence(
                    payment: payment,
                    scheduledDueDate: override.scheduledDueDate,
                    dueDate: override.scheduledDueDate,
                    amountPence: payment.amountPence
                )
            }
            .sorted { $0.scheduledDueDate > $1.scheduledDueDate }
    }

    private var sortedBills: [RecurringPayment] {
        tabPresentation.sortedBills
    }

    private var ungroupedBills: [RecurringPayment] {
        tabPresentation.ungroupedBills
    }

    private var tabPresentation: BillsTabPresentation {
        let context = presentationContext ?? PlannerTabPresentationContext(
            snapshot: store.snapshot,
            activePlannerAccountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriod: store.selectedPayPeriod
        )

        guard let presentationCache else {
            return Self.makePresentation(context: context)
        }

        return presentationCache.value(for: context.key(for: .bills)) {
            Self.makePresentation(context: context)
        }
    }

    static func warmPresentation(cache: PlannerTabPresentationCache, context: PlannerTabPresentationContext) {
        let _: BillsTabPresentation = cache.value(for: context.key(for: .bills)) {
            makePresentation(context: context)
        }
    }

    private static func makePresentation(context: PlannerTabPresentationContext) -> BillsTabPresentation {
        let snapshot = context.snapshot
        let todayIso = context.todayIso
        let activeBillGroups = snapshot.billGroups
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.name == $1.name {
                    return $0.id < $1.id
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        let sortedBills = snapshot.recurringPayments
            .filter { $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.active == rhs.active {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.active && !rhs.active
            }
        let groupIds = Set(activeBillGroups.map(\.id))
        let ungroupedBills = sortedBills.filter { payment in
            guard let groupId = payment.billGroupId else { return true }
            return !groupIds.contains(groupId)
        }
        let billsByGroupId = Dictionary(grouping: sortedBills.compactMap { payment -> (String, RecurringPayment)? in
            guard let groupId = payment.billGroupId else { return nil }
            return (groupId, payment)
        }, by: { $0.0 })
        .mapValues { rows in rows.map(\.1) }
        let upcomingOccurrences = PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: sortedBills,
            startDate: todayIso,
            endDate: FinanceEngine.addIsoDays(date: todayIso, days: 30)
        )
        .sorted { lhs, rhs in
            if lhs.dueDate == rhs.dueDate {
                return lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name) == .orderedAscending
            }
            return lhs.dueDate < rhs.dueDate
        }
        let nextDueEndDate = FinanceEngine.addIsoDays(date: todayIso, days: 180)
        let nextDueLabelsByPaymentId = Dictionary(uniqueKeysWithValues: sortedBills.map { payment in
            let label = PlannerDerivedData.resolvedRecurringOccurrences(
                snapshot: snapshot,
                payments: [payment],
                startDate: todayIso,
                endDate: nextDueEndDate
            )
            .sorted { $0.dueDate < $1.dueDate }
            .first
            .map { "Next \(billsFriendlyDate($0.dueDate))" }
                ?? billsDueTemplateLabel(payment)
            return (payment.id, label)
        })

        return BillsTabPresentation(
            activeBillGroups: activeBillGroups,
            sortedBills: sortedBills,
            ungroupedBills: ungroupedBills,
            billsByGroupId: billsByGroupId,
            upcomingOccurrences: upcomingOccurrences,
            fundingChecklistGroups: PlannerDerivedData.projectedFundingPayPeriods(
                snapshot: snapshot,
                startingAt: context.selectedPayPeriod,
                count: BillsLayoutPolicy.fundingChecklistProjectedPeriodCount
            )
            .compactMap { payPeriod in
                let items = PlannerDerivedData.fundingChecklistPresentationItems(
                    snapshot: snapshot,
                    payPeriod: payPeriod,
                    asOfDate: max(todayIso, payPeriod.startDate),
                    groupByFundingDueDate: true
                )
                guard !items.isEmpty else { return nil }
                return BillsFundingChecklistPeriodGroup(payPeriod: payPeriod, items: items)
            },
            nextDueLabelsByPaymentId: nextDueLabelsByPaymentId,
            activeBillCount: sortedBills.filter(\.active).count,
            activeTemplateTotalPence: sortedBills.filter(\.active).reduce(0) { $0 + $1.amountPence },
            linkedBillCount: sortedBills.filter { $0.potId != nil || $0.creditCardId != nil }.count
        )
    }

    private var displaySections: [BillsDisplaySection] {
        if selectedGroupId == ungroupedGroupId {
            return [BillsDisplaySection(id: ungroupedGroupId, title: "Ungrouped", color: AppTheme.Colors.tertiaryText, payments: ungroupedBills)]
        }

        if let selectedGroupId,
           let group = tabPresentation.activeBillGroups.first(where: { $0.id == selectedGroupId }) {
            return [section(for: group)]
        }

        var sections = tabPresentation.activeBillGroups.map(section(for:))
        if !ungroupedBills.isEmpty {
            sections.append(BillsDisplaySection(id: ungroupedGroupId, title: "Ungrouped", color: AppTheme.Colors.tertiaryText, payments: ungroupedBills))
        }
        return sections
    }

    private func section(for group: BillGroup) -> BillsDisplaySection {
        BillsDisplaySection(
            id: group.id,
            title: group.name,
            color: Color(hex: group.color),
            group: group,
            payments: bills(in: group)
        )
    }

    private func bills(in group: BillGroup) -> [RecurringPayment] {
        tabPresentation.billsByGroupId[group.id, default: []]
    }

    private func createGroup() {
        guard let group = store.addBillGroup(named: newGroupName) else { return }
        selectedGroupId = group.id
        newGroupName = ""
    }

    private func nextDueLabel(for payment: RecurringPayment) -> String {
        tabPresentation.nextDueLabelsByPaymentId[payment.id] ?? billsDueTemplateLabel(payment)
    }
}

private enum RecurringBillOccurrenceDateChoice: String, CaseIterable, Identifiable {
    case asExpected = "As expected"
    case awaiting = "Not yet"
    case actualDate = "Choose date"
    case refunded = "Refunded"

    var id: String { rawValue }
}

private struct RecurringBillOccurrenceAdjustmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var occurrence: RecurringPaymentOccurrence
    @State private var choice: RecurringBillOccurrenceDateChoice
    @State private var actualDate: Date
    @State private var confirmsExpectedDateWasMissed = false

    init(store: PlannerStore, occurrence: RecurringPaymentOccurrence) {
        self.store = store
        self.occurrence = occurrence
        let override = store.snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil &&
            $0.paymentId == occurrence.payment.id &&
            $0.scheduledDueDate == occurrence.scheduledDueDate
        }
        _choice = State(initialValue: override?.state == .awaitingPayment ? .awaiting : (override?.state == .confirmed ? .actualDate : (override?.state == .refunded ? .refunded : .asExpected)))
        _actualDate = State(initialValue: FinanceEngine.parseDate(override?.actualDueDate ?? occurrence.dueDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Expected date") { Text(displayDate(occurrence.scheduledDueDate)) }
                    LabeledContent("Amount") { Text(MoneyParser.formatPence(occurrence.amountPence)) }
                    Text("This update applies only to this occurrence. The normal recurring schedule is unchanged.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Section("What happened?") {
                    Picker("Payment status", selection: $choice) {
                        ForEach(RecurringBillOccurrenceDateChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if choice == .awaiting {
                        Text("New Money will hold this bill, prevent automatic settlement, and keep its amount reserved until you confirm the date.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }

                    if choice == .actualDate {
                        DatePicker("Actual payment date", selection: $actualDate, displayedComponents: .date)
                        Toggle("I confirm this bill was not paid on the expected date", isOn: $confirmsExpectedDateWasMissed)
                            .font(.footnote.weight(.medium))
                        Text("If New Money had already created an automatic bill transaction, it will be reversed before the occurrence is recorded on the date above.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.warning)
                    }

                    if choice == .refunded {
                        Text("This keeps the bill in history but removes this occurrence from costs and card balances. Future occurrences are unchanged.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                }
            }
            .navigationTitle("Check this bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(choice == .actualDate && !confirmsExpectedDateWasMissed)
                }
            }
        }
    }

    private func save() {
        switch choice {
        case .asExpected:
            store.clearRecurringBillOccurrenceAdjustment(paymentId: occurrence.payment.id, scheduledDueDate: occurrence.scheduledDueDate)
        case .awaiting:
            store.markRecurringBillOccurrenceAwaiting(paymentId: occurrence.payment.id, scheduledDueDate: occurrence.scheduledDueDate)
        case .actualDate:
            store.markRecurringBillOccurrenceAwaiting(paymentId: occurrence.payment.id, scheduledDueDate: occurrence.scheduledDueDate)
            store.confirmRecurringBillOccurrence(
                paymentId: occurrence.payment.id,
                scheduledDueDate: occurrence.scheduledDueDate,
                actualDueDate: FinanceEngine.toIsoDate(actualDate)
            )
        case .refunded:
            store.setRecurringBillOccurrenceRefunded(paymentId: occurrence.payment.id, scheduledDueDate: occurrence.scheduledDueDate, refunded: true)
        }
    }

    private func displayDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated).year())
    }
}

private struct BillsFundingChecklistPeriodCard: View {
    var group: BillsFundingChecklistPeriodGroup
    var action: (FundingChecklistPresentationItem) -> Void
    var excludeAction: (FundingChecklistPresentationItem) -> Void
    var adjustAction: (FundingChecklistPresentationItem) -> Void

    var body: some View {
        AppCard(glow: hasPendingFunding) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(periodTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Amount due")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                        .textCase(.uppercase)
                    Text(MoneyParser.formatPence(totalAmountPence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
            }

            AppDivider()
            checklistSection(title: "Active funding", items: activeItems, isReadOnly: false)

            if !paidItems.isEmpty {
                AppDivider()
                checklistSection(title: "Paid / completed", items: paidItems, isReadOnly: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Funding period \(periodTitle), \(MoneyParser.formatPence(totalAmountPence)) due")
    }

    @ViewBuilder
    private func checklistSection(
        title: String,
        items: [FundingChecklistPresentationItem],
        isReadOnly: Bool
    ) -> some View {
        if !items.isEmpty {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .textCase(.uppercase)

            ForEach(items) { item in
                BillsFundingChecklistRow(item: item, isReadOnly: isReadOnly) {
                    action(item)
                } excludeAction: {
                    excludeAction(item)
                } adjustAction: {
                    adjustAction(item)
                }

                if item.id != items.last?.id {
                    AppDivider()
                }
            }
        }
    }

    private var activeItems: [FundingChecklistPresentationItem] {
        group.items.filter { $0.status != .paidCompleted }
    }

    private var paidItems: [FundingChecklistPresentationItem] {
        group.items.filter { $0.status == .paidCompleted }
    }

    private var fundedCount: Int {
        group.items.count(where: \.isCompleted)
    }

    private var hasPendingFunding: Bool {
        activeItems.contains { !$0.isCompleted && !$0.isExcluded }
    }

    private var totalAmountPence: Int {
        group.items.reduce(0) { $0 + max(0, $1.amountPence) }
    }

    private var progressText: String {
        let countText = "\(fundedCount)/\(group.items.count) funded"
        return hasPendingFunding ? "Funding pending · \(countText)" : countText
    }

    private var periodTitle: String {
        let start = FinanceEngine.parseDate(group.payPeriod.startDate)
            .formatted(.dateTime.day().month(.abbreviated).year())
        let end = FinanceEngine.parseDate(group.payPeriod.endDate)
            .formatted(.dateTime.day().month(.abbreviated).year())
        return "\(start) – \(end)"
    }
}

private struct BillsFundingChecklistRow: View {
    var item: FundingChecklistPresentationItem
    var isReadOnly: Bool
    var action: () -> Void
    var excludeAction: () -> Void
    var adjustAction: () -> Void
    @State private var isBreakdownExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Button(action: action) {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(iconColor)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(titleColor)
                                .strikethrough(item.isExcluded, color: AppTheme.Colors.secondaryText)
                                .lineLimit(2)

                            Text(detailText)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.secondaryText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: AppTheme.Spacing.sm)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                FundingChecklistBreakdownToggle(isExpanded: $isBreakdownExpanded, itemName: item.name)

                if !isReadOnly {
                    if canAdjustOccurrence {
                        Button(action: adjustAction) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primaryOrange)
                                .frame(width: 30, height: 30)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Check \(item.name) occurrence")
                    }

                    Button(action: excludeAction) {
                        Image(systemName: item.isExcluded ? "arrow.uturn.backward.circle.fill" : "xmark.circle")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(item.isExcluded ? AppTheme.Colors.warning : AppTheme.Colors.secondaryText)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isExcluded ? "Include \(item.name)" : "Exclude \(item.name)")
                }
            }

            if isBreakdownExpanded {
                FundingChecklistBreakdownList(items: item.breakdown)
            }
        }
        .opacity(isReadOnly ? 0.72 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        if item.isExcluded {
            return AppTheme.Colors.warning
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.secondaryText
    }

    private var canAdjustOccurrence: Bool {
        if case .recurringBill = item.action {
            return true
        }
        return false
    }

    private var titleColor: Color {
        if isReadOnly {
            return AppTheme.Colors.secondaryText
        }

        if item.isExcluded {
            return AppTheme.Colors.secondaryText
        }

        return item.isCompleted ? AppTheme.Colors.success : AppTheme.Colors.primaryText
    }

    private var detailText: String {
        if item.isExcluded {
            return "\(item.detail) · excluded this period"
        }

        guard let paidDate = item.paidDate else {
            return item.detail
        }

        return "\(item.detail) · paid \(shortDate(paidDate))"
    }

    private var accessibilityLabel: String {
        if isReadOnly {
            return "Paid \(item.name)"
        }

        if item.isExcluded {
            return "Fund excluded \(item.name)"
        }

        return "\(item.isCompleted ? "Undo" : "Fund") \(item.name)"
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct BillsOverviewDetailView: View {
    @ObservedObject var store: PlannerStore
    @State private var isUpcomingExpanded = false
    @State private var isGroupsExpanded = false

    var body: some View {
        ScreenScaffold(
            title: "Bills",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            heroCard

            SectionTitle("Bill breakdown")
            AppCard {
                MetricRow(label: "Active bills", value: "\(activeBillCount)")
                AppDivider()
                MetricRow(label: "Monthly planned", value: MoneyParser.formatPence(activeTemplateTotalPence), valueColor: AppTheme.Colors.primaryOrange)
                AppDivider()
                MetricRow(label: "Linked to cards", value: "\(cardLinkedBillCount)", valueColor: AppTheme.Colors.warning)
                AppDivider()
                MetricRow(label: "Linked to pots", value: "\(potLinkedBillCount)", valueColor: AppTheme.Colors.success)
                AppDivider()
                MetricRow(label: "Ungrouped", value: "\(ungroupedBills.count)", valueColor: AppTheme.Colors.secondaryText)
            }

            BillsCollapsibleSection(
                title: "Upcoming",
                subtitle: upcomingSectionSubtitle,
                isExpanded: $isUpcomingExpanded
            ) {
                BillsProgressiveUpcomingList(
                    snapshot: store.snapshot,
                    payments: sortedBills,
                    todayIso: store.todayIso
                )
            }

            BillsCollapsibleSection(
                title: "Groups",
                subtitle: groupsSectionSubtitle,
                isExpanded: $isGroupsExpanded
            ) {
                if groupSections.isEmpty {
                    AppCard {
                        EmptyStateView(title: "No groups yet", message: "Create groups to organise subscriptions, home bills, card bills, and savings transfers.", systemImage: "folder")
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        ForEach(groupSections) { section in
                            BillsOverviewGroupCard(section: section)
                        }
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        AppCard(glow: BillsLayoutPolicy.overviewHeroUsesGlow) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Planned bills")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                            .textCase(.uppercase)
                        Text(MoneyParser.formatPence(activeTemplateTotalPence))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(activeBillCount == 0 ? "No active bills yet" : "\(activeBillCount) active bills tracked")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }

                    Spacer(minLength: AppTheme.Spacing.sm)

                    VStack(alignment: .trailing, spacing: 8) {
                        Text("Next")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                        Text(nextBillTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text(nextBillDate)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryOrange)
                    }
                    .frame(maxWidth: 132, alignment: .trailing)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    BillsOverviewPill(title: "\(linkedBillCount)", subtitle: "linked", color: AppTheme.Colors.success)
                    BillsOverviewPill(title: "\(store.activeBillGroups.count)", subtitle: "groups", color: AppTheme.Colors.primaryOrange)
                    BillsOverviewPill(title: "\(ungroupedBills.count)", subtitle: "ungrouped", color: AppTheme.Colors.secondaryText)
                }
            }
        }
    }

    private var activeBillCount: Int {
        sortedBills.filter(\.active).count
    }

    private var activeTemplateTotalPence: Int {
        sortedBills.filter(\.active).reduce(0) { $0 + $1.amountPence }
    }

    private var cardLinkedBillCount: Int {
        sortedBills.filter { $0.creditCardId != nil }.count
    }

    private var potLinkedBillCount: Int {
        sortedBills.filter { $0.potId != nil }.count
    }

    private var linkedBillCount: Int {
        sortedBills.filter { $0.potId != nil || $0.creditCardId != nil }.count
    }

    private var nextBillTitle: String {
        nextBillOccurrence?.payment.name ?? "Next bill"
    }

    private var nextBillDate: String {
        nextBillOccurrence.map { billsFriendlyDate($0.dueDate) } ?? "None"
    }

    private var nextBillOccurrence: RecurringPaymentOccurrence? {
        upcomingOccurrences.first
    }

    private var upcomingSectionSubtitle: String {
        guard let nextBillOccurrence else {
            return "Future payments in date order"
        }

        return "Next \(billsFriendlyDate(nextBillOccurrence.dueDate)) · loads as you scroll"
    }

    private var groupsSectionSubtitle: String {
        guard !groupSections.isEmpty else {
            return "No groups yet"
        }

        let billCount = groupSections.reduce(0) { $0 + $1.payments.count }
        return "\(groupSections.count) group\(groupSections.count == 1 ? "" : "s") · \(billCount) bill\(billCount == 1 ? "" : "s")"
    }

    private var upcomingOccurrences: [RecurringPaymentOccurrence] {
        let endDate = FinanceEngine.addIsoDays(date: store.todayIso, days: 60)
        return PlannerDerivedData.resolvedRecurringOccurrences(snapshot: store.snapshot, payments: sortedBills, startDate: store.todayIso, endDate: endDate)
            .sorted { lhs, rhs in
                if lhs.dueDate == rhs.dueDate {
                    return lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name) == .orderedAscending
                }
                return lhs.dueDate < rhs.dueDate
            }
    }

    private var sortedBills: [RecurringPayment] {
        store.snapshot.recurringPayments
            .filter { $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.active == rhs.active {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.active && !rhs.active
            }
    }

    private var ungroupedBills: [RecurringPayment] {
        sortedBills.filter { payment in
            guard let groupId = payment.billGroupId else { return true }
            return !store.activeBillGroups.contains { $0.id == groupId }
        }
    }

    private var groupSections: [BillsDisplaySection] {
        var sections = store.activeBillGroups.map { group in
            BillsDisplaySection(
                id: group.id,
                title: group.name,
                color: Color(hex: group.color),
                group: group,
                payments: sortedBills.filter { $0.billGroupId == group.id }
            )
        }

        if !ungroupedBills.isEmpty {
            sections.append(BillsDisplaySection(id: "ungrouped", title: "Ungrouped", color: AppTheme.Colors.tertiaryText, payments: ungroupedBills))
        }

        return sections
    }
}

private struct BillsOverviewGroupCard: View {
    var section: BillsDisplaySection

    private var activePayments: [RecurringPayment] {
        section.payments.filter(\.active)
    }

    private var totalPence: Int {
        activePayments.reduce(0) { $0 + $1.amountPence }
    }

    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Circle()
                    .fill(section.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: section.color.opacity(0.45), radius: 7, y: 2)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(activePayments.isEmpty ? "No active bills" : "\(activePayments.count) active bills")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(MoneyParser.formatPence(totalPence))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(totalPence > 0 ? AppTheme.Colors.primaryOrange : AppTheme.Colors.tertiaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct BillsDisplaySection: Identifiable {
    var id: String
    var title: String
    var color: Color
    var group: BillGroup?
    var payments: [RecurringPayment]
}

private struct BillsCollapsibleSection<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var title: String
    var subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleExpansion) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    SectionTitle(title)

                    Spacer(minLength: AppTheme.Spacing.sm)

                    Image(systemName: ExpandableSectionLayoutPolicy.symbol(isExpanded: isExpanded))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }
                .frame(minHeight: BillsLayoutPolicy.collapsibleHeaderMinimumHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .zIndex(1)
            .accessibilityLabel(title)
            .accessibilityValue("\(isExpanded ? "Expanded" : "Collapsed"). \(subtitle)")
            .accessibilityHint(isExpanded ? "Closes this section" : "Opens this section")

            if isExpanded {
                content
                    .padding(.top, AppTheme.Spacing.md)
                    .transition(contentTransition)
                    .zIndex(0)
            }
        }
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -14)),
            removal: .opacity.combined(with: .offset(y: -14))
        )
    }

    private func toggleExpansion() {
        let animation = reduceMotion
            ? Animation.linear(duration: BillsLayoutPolicy.collapsibleToggleDuration)
            : Animation.easeOut(duration: BillsLayoutPolicy.collapsibleToggleDuration)

        withAnimation(animation) {
            isExpanded.toggle()
        }
    }
}

private struct BillsOverviewPill: View {
    var title: String
    var subtitle: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct BillsGroupFilterPill: View {
    var title: String
    var count: Int
    var color: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.6), radius: isSelected ? 8 : 0)
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(isSelected ? AppTheme.Colors.controlText.opacity(0.9) : color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((isSelected ? AppTheme.Colors.controlText : color).opacity(0.14), in: Capsule())
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(isSelected ? AppTheme.Colors.controlText : AppTheme.Colors.primaryText)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(isSelected ? AnyShapeStyle(AppTheme.Gradients.primary) : AnyShapeStyle(AppTheme.Colors.elevatedSurface), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppTheme.Colors.selectedStroke : AppTheme.Colors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BillsUpcomingRow: View {
    var occurrence: RecurringPaymentOccurrence
    var adjustAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            BillsDateTile(date: occurrence.dueDate)

            VStack(alignment: .leading, spacing: 6) {
                Text(occurrence.payment.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                Text("\(billsFriendlyDate(occurrence.dueDate)) · \(occurrence.payment.frequency.rawValue.capitalized)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Text(MoneyParser.formatPence(occurrence.amountPence))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.warning)
                .multilineTextAlignment(.trailing)

            if let adjustAction {
                Button(action: adjustAction) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Check (occurrence.payment.name) occurrence")
            }
        }
    }
}

private struct BillsProgressiveUpcomingList: View {
    var snapshot: PlannerSnapshot
    var payments: [RecurringPayment]
    var todayIso: String
    var adjustAction: ((RecurringPaymentOccurrence) -> Void)? = nil
    @State private var loadedPageCount = 1

    var body: some View {
        let occurrences = loadedOccurrences

        if occurrences.isEmpty {
            AppCard {
                EmptyStateView(
                    title: "No upcoming bills",
                    message: "Active bills with future due dates will appear here.",
                    systemImage: "calendar"
                )
            }
        } else {
            AppCard {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(occurrences) { occurrence in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            BillsUpcomingRow(
                                occurrence: occurrence,
                                adjustAction: adjustmentAction(for: occurrence)
                            )

                            if occurrence.id != occurrences.last?.id {
                                AppDivider()
                            }
                        }
                        .onAppear {
                            loadNextPageIfNeeded(after: occurrence, visibleOccurrences: occurrences)
                        }
                    }
                }
            }
        }
    }

    private var loadedOccurrences: [RecurringPaymentOccurrence] {
        PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: activePayments,
            startDate: todayIso,
            endDate: loadedThroughDate
        )
        .sorted { lhs, rhs in
            if lhs.dueDate == rhs.dueDate {
                return lhs.payment.name.localizedCaseInsensitiveCompare(rhs.payment.name) == .orderedAscending
            }
            return lhs.dueDate < rhs.dueDate
        }
    }

    private var activePayments: [RecurringPayment] {
        payments.filter { $0.deletedAt == nil && $0.active }
    }

    private var loadedThroughDate: String {
        let pagedEndDate = PlannerDerivedData.addIsoMonthsClamped(
            date: todayIso,
            months: loadedPageCount * BillsLayoutPolicy.upcomingSchedulePageMonths
        )
        let finalOneOffDate = activePayments
            .filter { $0.frequency == .once }
            .compactMap(\.dueDate)
            .filter { $0 >= todayIso }
            .max()

        return max(pagedEndDate, finalOneOffDate ?? pagedEndDate)
    }

    private var hasOpenEndedSchedule: Bool {
        activePayments.contains { $0.frequency != .once }
    }

    private func adjustmentAction(for occurrence: RecurringPaymentOccurrence) -> (() -> Void)? {
        guard let adjustAction else { return nil }
        return {
            adjustAction(occurrence)
        }
    }

    private func loadNextPageIfNeeded(
        after occurrence: RecurringPaymentOccurrence,
        visibleOccurrences: [RecurringPaymentOccurrence]
    ) {
        guard hasOpenEndedSchedule,
              occurrence.id == visibleOccurrences.last?.id else {
            return
        }

        loadedPageCount += 1
    }
}

private struct BillsGroupSectionCard: View {
    var section: BillsDisplaySection
    var nextDueLabel: (RecurringPayment) -> String
    var edit: (RecurringPayment) -> Void

    private var totalPence: Int {
        section.payments.filter(\.active).reduce(0) { $0 + $1.amountPence }
    }

    var body: some View {
        AppCard {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(section.color)
                        .frame(width: 10, height: 10)
                        .shadow(color: section.color.opacity(0.6), radius: 8)
                    Text(section.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyParser.formatPence(totalPence))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                    Text("\(section.payments.count) bills")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }

            if section.payments.isEmpty {
                Text("No bills in this group yet.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .padding(.vertical, AppTheme.Spacing.sm)
            } else {
                ForEach(Array(section.payments.enumerated()), id: \.element.id) { index, payment in
                    BillsPaymentRow(
                        payment: payment,
                        nextDueLabel: nextDueLabel(payment),
                        edit: {
                            edit(payment)
                        }
                    )

                    if index != section.payments.count - 1 {
                        AppDivider()
                    }
                }
            }
        }
    }
}

private struct BillsPaymentRow: View {
    var payment: RecurringPayment
    var nextDueLabel: String
    var edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                BillsBillIcon(payment: payment)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(payment.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(payment.active ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                            .lineLimit(1)

                        if !payment.active {
                            Text("Inactive")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.tertiaryText)
                        }
                    }

                    Text("\(nextDueLabel) · \(payment.frequency.rawValue.capitalized) · \(payment.priority.rawValue.capitalized)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Text(MoneyParser.formatPence(payment.amountPence))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .multilineTextAlignment(.trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .accessibilityHint("Opens bill details")
    }
}

enum BillsBillSymbolPolicy {
    static func symbol(for payment: RecurringPayment) -> String {
        let name = payment.name.lowercased()

        if name.contains("insurance") || name.contains("applecare") || name.contains("cover") {
            return "shield.checkered"
        }
        if name.contains("gym") || name.contains("fitness") || name.contains("runna") {
            return "figure.run"
        }
        if name.contains("car") || name.contains("vehicle") || name.contains("fuel") {
            return "car.fill"
        }
        if name.contains("rent") || name.contains("mortgage") || name.contains("home") {
            return "house.fill"
        }
        if name.contains("electric") || name.contains("energy") || name.contains("gas") {
            return "bolt.fill"
        }
        if name.contains("water") {
            return "drop.fill"
        }
        if name.contains("phone") || name.contains("mobile") {
            return "iphone"
        }
        if name.contains("internet") || name.contains("broadband") || name.contains("wifi") {
            return "wifi"
        }
        if name.contains("icloud") || name.contains("cloud") {
            return "cloud.fill"
        }
        if name.contains("capcut") || name.contains("video") {
            return "scissors"
        }
        if name.contains("chatgpt") || name.contains("openai") {
            return "sparkles"
        }
        if name.contains("netflix") || name.contains("stream") || name.contains("tv") {
            return "play.rectangle.fill"
        }
        if name.contains("spotify") || name.contains("music") {
            return "music.note"
        }

        return payment.creditCardId != nil ? "creditcard.fill" : "doc.text.fill"
    }
}

private struct BillsBillIcon: View {
    var payment: RecurringPayment

    private var color: Color {
        if payment.creditCardId != nil { return AppTheme.Colors.warning }
        if payment.potId != nil { return AppTheme.Colors.success }
        return AppTheme.Colors.primaryOrange
    }

    private var symbol: String {
        BillsBillSymbolPolicy.symbol(for: payment)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: BillsLayoutPolicy.billIconSize, height: BillsLayoutPolicy.billIconSize)
            .background(color.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

private struct BillsDateTile: View {
    var date: String

    var body: some View {
        VStack(spacing: 2) {
            Text(billsDayNumber(date))
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text(billsMonthText(date))
                .font(.caption2.weight(.black))
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(width: 48, height: 50)
        .background(AppTheme.Colors.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

private func billsDueTemplateLabel(_ payment: RecurringPayment) -> String {
    if let dueDate = payment.dueDate {
        return "Due \(billsFriendlyDate(dueDate))"
    }

    if let dueDay = payment.dueDay {
        return "Due \(billsOrdinalDayLabel(dueDay))"
    }

    return "No due date"
}

private func billsFriendlyDate(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    let date = FinanceEngine.parseDate(isoDate)
    let day = calendar.component(.day, from: date)
    let month = calendar.component(.month, from: date)
    return "\(billsOrdinalDayLabel(day)) \(billsShortMonthLabel(month))"
}

private func billsDayNumber(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return "\(calendar.component(.day, from: FinanceEngine.parseDate(isoDate)))"
}

private func billsMonthText(_ isoDate: String) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return billsShortMonthLabel(calendar.component(.month, from: FinanceEngine.parseDate(isoDate))).uppercased()
}

private func billsOrdinalDayLabel(_ day: Int) -> String {
    let suffix: String
    switch day {
    case 11, 12, 13:
        suffix = "th"
    default:
        switch day % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
    }
    return "\(day)\(suffix)"
}

private func billsShortMonthLabel(_ month: Int) -> String {
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    guard months.indices.contains(month - 1) else { return "Jan" }
    return months[month - 1]
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
                    DebtSelectionMenu(
                        title: "Debt type",
                        value: debtTypeLabel(debtType),
                        systemImage: "tag"
                    ) {
                        ForEach(DebtType.allCases) { type in
                            Button {
                                debtType = type
                            } label: {
                                if debtType == type {
                                    Label(debtTypeLabel(type), systemImage: "checkmark")
                                } else {
                                    Text(debtTypeLabel(type))
                                }
                            }
                        }
                    }
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
                    DebtSelectionMenu(
                        title: "Strategy",
                        value: debtStrategyLabel(repaymentStrategy),
                        systemImage: "arrow.triangle.branch"
                    ) {
                        ForEach(DebtRepaymentStrategy.allCases) { strategy in
                            Button {
                                repaymentStrategy = strategy
                            } label: {
                                if repaymentStrategy == strategy {
                                    Label(debtStrategyLabel(strategy), systemImage: "checkmark")
                                } else {
                                    Text(debtStrategyLabel(strategy))
                                }
                            }
                        }
                    }
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
                    DebtSelectionMenu(
                        title: "Linked pot",
                        value: selectedLinkedPotName,
                        systemImage: "wallet.pass"
                    ) {
                        Button {
                            linkedPotId = ""
                        } label: {
                            if linkedPotId.isEmpty {
                                Label("No linked pot", systemImage: "checkmark")
                            } else {
                                Text("No linked pot")
                            }
                        }
                        ForEach(eligibleDebtPots(in: store.snapshot, debtId: nil)) { pot in
                            Button {
                                linkedPotId = pot.id
                            } label: {
                                if linkedPotId == pot.id {
                                    Label(pot.name, systemImage: "checkmark")
                                } else {
                                    Text(pot.name)
                                }
                            }
                        }
                    }
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationTopDividerHidden()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
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

    private var selectedLinkedPotName: String {
        guard !linkedPotId.isEmpty else { return "No linked pot" }
        return eligibleDebtPots(in: store.snapshot, debtId: nil)
            .first(where: { $0.id == linkedPotId })?.name ?? "No linked pot"
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

enum DebtFormLayoutPolicy {
    static let dropdownFields = ["debtType", "strategy", "linkedPot"]
    static let dropdownPresentation = "selectionFieldBox"
}

private struct DebtSelectionMenu<Content: View>: View {
    let title: String
    let value: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        value: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background(AppTheme.Colors.elevatedSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

enum DebtsSection: String, Equatable {
    case summary
    case activeDebts
}

struct DebtsLayoutPolicy {
    static let toolbarActionId = "add"
    static let addFlowPlacement = "debtsSectionToolbar"
    static let sections: [DebtsSection] = [
        .summary,
        .activeDebts
    ]

    static func toolbarMode(addAction: @escaping () -> Void) -> AppToolbarMode {
        .add(action: addAction)
    }
}

struct DebtsView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedDebt: Debt?
    @State private var isAddDebtPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Debts",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: DebtsLayoutPolicy.toolbarMode {
                isAddDebtPresented = true
            }
        ) {
            ForEach(DebtsLayoutPolicy.sections, id: \.rawValue) { section in
                debtsSection(section)
            }
        }
        .sheet(item: $selectedDebt) { debt in
            DebtDetailView(store: store, debt: debt)
        }
        .sheet(isPresented: $isAddDebtPresented) {
            AddDebtSheetView(store: store)
        }
    }

    @ViewBuilder
    private func debtsSection(_ section: DebtsSection) -> some View {
        switch section {
        case .summary:
            debtSummary
        case .activeDebts:
            activeDebtsSection
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

    private var activeDebtsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Active debts")
            if store.activeDebts.isEmpty {
                AppCard { EmptyStateView(title: "No active debts", message: "Use Add in the toolbar to track minimums, reserves, and payments.", systemImage: "checkmark.shield") }
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
            .navigationBarTitleDisplayMode(.inline)
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
            return AppTheme.Colors.controlText
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

enum HistoryLayoutPolicy {
    static let toolbarMode = "none"
    static let showsPlaceholderOptions = false
}

struct HistoryView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "History",
            subtitle: "Closed and active paycheck plans with allocations.",
            navigationMode: .inline,
            toolbarMode: .none
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

enum SettingsRoute: String, CaseIterable, Equatable {
    case history
    case creditStatements

    var title: String {
        switch self {
        case .history: "History"
        case .creditStatements: "Credit Statements"
        }
    }

    var subtitle: String {
        switch self {
        case .history: "Paycheck and allocation history."
        case .creditStatements: "Card statements and direct debit status."
        }
    }

    var symbol: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .creditStatements: "doc.text.magnifyingglass"
        }
    }
}

struct AppearanceSettingsView: View {
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .none
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue

    var body: some View {
        ScreenScaffold(
            title: "Appearance",
            subtitle: "Choose the colour theme used on this iPhone.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            AppearanceThemeCustomizerCard(selectedThemeRawValue: $selectedThemeRawValue)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var authSession: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue
    @State private var hourlyRate = ""
    @State private var hours = ""
    @State private var showResetAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showLogOutConfirmation = false
    @State private var resetDataToggle = false

    var body: some View {
        ScreenScaffold(
            title: "Settings",
            subtitle: "Planner defaults, account, and local data controls.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            appearanceCard

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

            moneyLeftCard

            settingsRoutes

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
        .alert("Delete account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await authSession.deleteAccount()
                }
            }
        } message: {
            Text("This deletes your account through the backend account endpoint. Local data on this iPhone is not reset by this action.")
        }
        .alert("Log out?", isPresented: $showLogOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(ProfileMenuPresentationPolicy.logOutActionTitle, role: .destructive) {
                Task {
                    await authSession.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to log out of this account?")
        }
    }

    private var appearanceCard: some View {
        AppearanceThemeCustomizerCard(selectedThemeRawValue: $selectedThemeRawValue)
    }

    private var moneyLeftCard: some View {
        AppCard {
            SectionTitle("Money left")
            Toggle("Include pots in Money left", isOn: includePotsInMoneyLeftBinding)
                .tint(AppTheme.Colors.success)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Turn this off to show only bank-account balances and any current income that is not linked to an account. Pot and card-reserve balances remain tracked but are left out of the total.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
    }

    private var settingsRoutes: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ForEach(SettingsRoute.allCases, id: \.rawValue) { route in
                settingsRoute(route)
            }
        }
    }

    @ViewBuilder
    private func settingsRoute(_ route: SettingsRoute) -> some View {
        switch route {
        case .history:
            NavigationLink {
                HistoryView(store: store)
            } label: {
                settingsRouteCard(route)
            }
            .buttonStyle(.plain)
        case .creditStatements:
            NavigationLink {
                StatementsView(store: store)
            } label: {
                settingsRouteCard(route)
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsRouteCard(_ route: SettingsRoute) -> some View {
        AppCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: route.symbol)
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(route.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text(route.subtitle)
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

    private var accountCard: some View {
        AppCard {
            SectionTitle("Account")
            if let user = currentAuthUser {
                MetricRow(label: "Provider", value: user.providerLabel, valueColor: AppTheme.Colors.success)
                if let email = user.email {
                    MetricRow(label: "Email", value: email)
                }
                if let phoneNumber = user.phoneNumber {
                    MetricRow(label: "Phone", value: phoneNumber)
                }
                MetricRow(label: "Cloud sync", value: authSession.cloudStatus)

                SecondaryButton(title: ProfileMenuPresentationPolicy.logOutActionTitle, systemImage: "rectangle.portrait.and.arrow.right") {
                    showLogOutConfirmation = true
                }

                SecondaryButton(title: "Delete Account", systemImage: "trash", role: .destructive) {
                    showDeleteAccountAlert = true
                }
            } else {
                MetricRow(label: "Status", value: "Signed out", valueColor: AppTheme.Colors.warning)
            }
        }
    }

    private var currentAuthUser: AuthUser? {
        switch authSession.state {
        case .emailVerificationRequired(let user),
             .syncing(let user, _),
             .ready(let user):
            return user
        case .loading, .signedOut, .failed:
            return nil
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

    private var includePotsInMoneyLeftBinding: Binding<Bool> {
        Binding {
            store.snapshot.settings.includePotsInMoneyLeft ?? true
        } set: { includesPots in
            var settings = store.snapshot.settings
            settings.includePotsInMoneyLeft = includesPots
            store.updateSettings(settings)
        }
    }
}

private struct AppearanceThemeCustomizerCard: View {
    @Binding var selectedThemeRawValue: String

    var body: some View {
        AppCard(glow: true) {
            SectionTitle("Appearance")
            Text("Choose the colour theme used on this iPhone.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.secondaryText)

            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(AppThemePreset.allCases) { preset in
                    Button {
                        withAnimation(AppTheme.Animation.standard) {
                            selectedThemeRawValue = preset.rawValue
                        }
                    } label: {
                        SettingsThemePresetRow(
                            preset: preset,
                            isSelected: selectedThemeRawValue == preset.rawValue
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-theme-\(preset.rawValue)")
                }
            }
        }
    }
}

private struct SettingsThemePresetRow: View {
    var preset: AppThemePreset
    var isSelected: Bool

    private var palette: AppThemePalette {
        preset.palette
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            SettingsThemeSwatches(palette: palette)

            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(preset.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline.weight(.bold))
                .foregroundStyle(isSelected ? AppTheme.Colors.primaryOrange : AppTheme.Colors.tertiaryText)
        }
        .padding(AppTheme.Spacing.md)
        .background(isSelected ? AppTheme.Colors.primaryOrange.opacity(0.14) : AppTheme.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                .stroke(isSelected ? AppTheme.Colors.primaryOrange.opacity(0.5) : AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

private struct SettingsThemeSwatches: View {
    var palette: AppThemePalette

    var body: some View {
        HStack(spacing: -8) {
            swatch(palette.backgroundHex)
            swatch(palette.accentHex)
            swatch(palette.textHex)
        }
        .frame(width: 58, alignment: .leading)
    }

    private func swatch(_ hex: String) -> some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: 26, height: 26)
            .overlay(
                Circle()
                    .stroke(AppTheme.Colors.border, lineWidth: 1)
            )
            .shadow(color: AppTheme.Colors.shadow, radius: 6, y: 3)
    }
}

enum AssistantPresentationMode: Equatable {
    case modal
    case pushed
}

enum AssistantMenuPresentationPolicy {
    static let toolbarTitle = "Edit"
    static let presentation = "nativeSwiftUIMenu"
    static let actions = ["Customise assistant", "Rename"]
    static let customiseAssistantRoute = "instructionsScreen"
    static let renamePresentation = "textFieldAlert"
    static let instructionsUsesPlaceholderToolbar = false
}

struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var presentationMode: AssistantPresentationMode = .modal
    @State private var prompt = ""
    @State private var isRenameAssistantPresented = false
    @State private var assistantNameDraft = ""
    @State private var activeAssistantSheet: AssistantSettingsSheet?
    @State private var messages: [AssistantMessage] = [
        AssistantMessage(role: "Assistant", text: "I can summarise your local planner. Authenticated AI chat needs the native Firebase/backend TODOs in Settings.")
    ]
    @FocusState private var isPromptFocused: Bool
    private let assistantCoordinateSpace = "assistantScrollSpace"

    private var assistantName: String {
        store.snapshot.settings.assistantName?.nilIfBlank ?? "Assistant"
    }

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
                .navigationTitle(assistantName)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTopDividerHidden()
                .toolbar {
                    if presentationMode == .modal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu(AssistantMenuPresentationPolicy.toolbarTitle) {
                            Button(AssistantMenuPresentationPolicy.actions[0]) {
                                activeAssistantSheet = .instructions
                            }

                            Button(AssistantMenuPresentationPolicy.actions[1]) {
                                assistantNameDraft = assistantName
                                isRenameAssistantPresented = true
                            }
                        }
                    }
                }
                .alert("Rename assistant", isPresented: $isRenameAssistantPresented) {
                    TextField("Assistant name", text: $assistantNameDraft)

                    Button("Cancel", role: .cancel) {}
                    Button("Save") {
                        saveAssistantName()
                    }
                } message: {
                    Text("Choose the name shown in assistant replies.")
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
                    .foregroundStyle(AppTheme.Colors.controlText)
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
        let reply = "Local summary: \(MoneyParser.formatPence(period?.incomePence ?? 0)) income in the current plan, \(MoneyParser.formatPence(FinanceEngine.getSpendablePence(pots: store.snapshot.pots))) spendable, and \(store.snapshot.recurringPayments.filter(\.active).count) active bills. Authenticated AI actions are waiting on native Firebase ID tokens."
        messages.append(AssistantMessage(role: assistantName, text: reply))
    }

    private func saveAssistantName() {
        let previousName = assistantName
        let newName = assistantNameDraft.nilIfBlank ?? "Assistant"
        var settings = store.snapshot.settings
        settings.assistantName = newName
        store.updateSettings(settings)
        messages = messages.map { message in
            guard message.role == previousName || message.role == "Assistant" else { return message }
            var renamedMessage = message
            renamedMessage.role = newName
            return renamedMessage
        }
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
            .navigationTopDividerHidden()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
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
            .navigationTopDividerHidden()
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
