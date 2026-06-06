import SwiftUI

struct CardsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    @State private var isAddPresented = false
    @State private var selectedCard: CreditCard?

    var body: some View {
        ScreenScaffold(
            title: "Cards",
            subtitle: "Track card balances, repayments, saved payments, and cover pots.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            summary
            SectionTitle("Active cards", actionTitle: "Add") {
                isAddPresented = true
            }
            if store.activeCards.isEmpty {
                AppCard {
                    EmptyStateView(title: "No cards yet", message: "Add a card to route credit-card spending and repayments.", systemImage: "creditcard")
                }
            } else {
                ForEach(store.activeCards) { card in
                    Button {
                        selectedCard = card
                    } label: {
                        CreditCardRow(card: card, balancePence: PlannerDerivedData.cardBalance(card: card, snapshot: store.snapshot))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            CardFormView(store: store)
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(store: store, card: card)
        }
    }

    private var summary: some View {
        let owed = store.activeCards.reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: store.snapshot) }
        let limits = store.activeCards.reduce(0) { $0 + $1.limitPence }
        let available = max(0, limits - owed)
        return AppCard(glow: true) {
            MetricRow(label: "Owed", value: MoneyParser.formatPence(owed), valueColor: AppTheme.Colors.orangeHighlight)
            MetricRow(label: "Available credit", value: MoneyParser.formatPence(available))
            MetricRow(label: "Cover pots", value: MoneyParser.formatPence(store.snapshot.creditCardPots.filter { $0.status == .active }.reduce(0) { $0 + $1.amountPence }))
        }
    }
}

private struct CreditCardRow: View {
    var card: CreditCard
    var balancePence: Int

    var body: some View {
        AppCard(glow: balancePence > card.limitPence) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(card.provider)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Text(MoneyParser.formatPence(balancePence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
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
            }
        }
    }
}

private struct CardFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var name = ""
    @State private var provider = ""
    @State private var limit = ""
    @State private var opening = ""
    @State private var dueDay = ""
    @State private var color = "#E85002"

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.md) {
                TextField("Card name", text: $name).textFieldStyle(AppTextFieldStyle())
                TextField("Provider", text: $provider).textFieldStyle(AppTextFieldStyle())
                MoneyField(title: "Credit limit", text: $limit)
                MoneyField(title: "Opening balance", text: $opening)
                TextField("Due day", text: $dueDay).keyboardType(.numberPad).textFieldStyle(AppTextFieldStyle())
                TextField("Colour hex", text: $color).textFieldStyle(AppTextFieldStyle())
                PrimaryButton(title: "Add card", systemImage: "plus", isDisabled: name.isBlank || limit.isBlank) {
                    store.addCreditCard(
                        name: name,
                        provider: provider.isBlank ? "Card" : provider,
                        limitPence: MoneyParser.parsePoundsToPence(limit),
                        openingBalancePence: MoneyParser.parsePoundsToPence(opening),
                        dueDay: Int(dueDay),
                        color: color
                    )
                    dismiss()
                }
                Spacer()
            }
            .padding(AppTheme.Spacing.lg)
            .premiumScreenBackground()
            .navigationTitle("Add card")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
    }
}

private struct CardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var card: CreditCard
    @State private var repayment = ""
    @State private var potAmount = ""
    @State private var customName = ""
    @State private var customAmount = ""
    @State private var customDueDate = Date()

    private var currentCard: CreditCard {
        store.snapshot.creditCards.first(where: { $0.id == card.id }) ?? card
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    CreditCardRow(card: currentCard, balancePence: PlannerDerivedData.cardBalance(card: currentCard, snapshot: store.snapshot))
                    AppCard {
                        SectionTitle("Repay or cover")
                        MoneyField(title: "Repayment amount", text: $repayment)
                        SecondaryButton(title: "Record repayment", systemImage: "arrow.down.circle") {
                            store.recordCardRepayment(cardId: card.id, amountPence: MoneyParser.parsePoundsToPence(repayment), date: Date().isoDateString, note: "Manual repayment")
                            repayment = ""
                        }
                        AppDivider()
                        MoneyField(title: "Cover pot amount", text: $potAmount)
                        SecondaryButton(title: "Create cover pot", systemImage: "plus.circle") {
                            store.addCreditCardPot(cardId: card.id, name: "\(card.name) cover", amountPence: MoneyParser.parsePoundsToPence(potAmount), source: .paycheck)
                            potAmount = ""
                        }
                    }
                    AppCard {
                        SectionTitle("Saved card payment")
                        TextField("Payment name", text: $customName).textFieldStyle(AppTextFieldStyle())
                        MoneyField(title: "Amount", text: $customAmount)
                        DatePicker("Due date", selection: $customDueDate, displayedComponents: .date)
                            .tint(AppTheme.Colors.primaryOrange)
                        SecondaryButton(title: "Save payment", systemImage: "calendar.badge.plus") {
                            store.addCustomPayment(name: customName.isBlank ? "Saved payment" : customName, amountPence: MoneyParser.parsePoundsToPence(customAmount), dueDate: customDueDate.isoDateString, creditCardId: card.id)
                            customName = ""
                            customAmount = ""
                        }
                    }
                    SecondaryButton(title: "Archive card", systemImage: "archivebox", role: .destructive) {
                        store.archiveCreditCard(id: card.id)
                        dismiss()
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle(card.name)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .appPlaceholderToolbar(.modalSingle)
        }
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
