import SwiftUI

struct BankAccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    private let account: BankAccount?

    @State private var name: String
    @State private var provider: String
    @State private var type: BankAccountType
    @State private var currentBalance: String
    @State private var lastFourDigits: String
    @State private var color: String
    @State private var isPrimary: Bool

    init(store: PlannerStore, account: BankAccount? = nil) {
        self.store = store
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _provider = State(initialValue: account?.provider ?? "")
        _type = State(initialValue: account?.type ?? .current)
        let balance = account.map {
            PlannerDerivedData.bankAccountBalance(account: $0, snapshot: store.snapshot)
        } ?? 0
        _currentBalance = State(initialValue: account == nil ? "" : Self.moneyInput(balance))
        _lastFourDigits = State(initialValue: account?.lastFourDigits ?? "")
        _color = State(initialValue: account?.color ?? AppTheme.selectedPalette.accentHex.uppercased())
        _isPrimary = State(initialValue: account?.isPrimary ?? store.activeBankAccounts.isEmpty)
    }

    var body: some View {
        ScrollView {
            AppCard(glow: true) {
                SectionTitle(account == nil ? "Add bank account" : "Account details")

                TextField("Account name", text: $name)
                    .textFieldStyle(AppTextFieldStyle())
                TextField("Bank or provider", text: $provider)
                    .textFieldStyle(AppTextFieldStyle())

                Picker("Account type", selection: $type) {
                    ForEach(BankAccountType.allCases) { accountType in
                        Text(accountType.displayName).tag(accountType)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.Colors.primaryOrange)

                MoneyField(title: "Current balance", text: $currentBalance)

                TextField("Last 4 digits (optional)", text: $lastFourDigits)
                    .keyboardType(.numberPad)
                    .textFieldStyle(AppTextFieldStyle())
                    .onChange(of: lastFourDigits) { _, newValue in
                        lastFourDigits = String(newValue.filter(\.isNumber).prefix(4))
                    }

                Toggle("Use as main account", isOn: $isPrimary)
                    .tint(AppTheme.Colors.primaryOrange)

                colorPicker

                Text("Linked income and spending update this balance automatically. Editing the balance reconciles it without changing your history.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)

                PrimaryButton(
                    title: account == nil ? "Add account" : "Save changes",
                    systemImage: account == nil ? "plus" : "checkmark",
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: save
                )
            }
            .padding(AppTheme.Spacing.lg)
        }
        .premiumScreenBackground()
        .navigationTitle(account == nil ? "Add Bank Account" : "Edit Bank Account")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTopDividerHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Colour")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.Colors.secondaryText)

            HStack(spacing: AppTheme.Spacing.md) {
                ForEach(AppTheme.selectableColorHexes(), id: \.self) { swatch in
                    Button {
                        color = swatch
                    } label: {
                        Circle()
                            .fill(Color(hex: swatch))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if color == swatch {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.Colors.controlText)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Use \(swatch) account colour")
                }
            }
        }
    }

    private func save() {
        if var account {
            account.name = name
            account.provider = provider
            account.type = type
            account.lastFourDigits = lastFourDigits
            account.color = color
            account.isPrimary = isPrimary
            guard store.updateBankAccount(
                account,
                currentBalancePence: MoneyParser.parsePoundsToPence(currentBalance)
            ) else { return }
        } else {
            guard store.addBankAccount(
                name: name,
                provider: provider,
                type: type,
                currentBalancePence: MoneyParser.parsePoundsToPence(currentBalance),
                lastFourDigits: lastFourDigits,
                color: color,
                isPrimary: isPrimary
            ) else { return }
        }
        dismiss()
    }

    private static func moneyInput(_ amountPence: Int) -> String {
        let pounds = Double(amountPence) / 100
        return pounds.formatted(.number.precision(.fractionLength(2)))
    }
}
