import SwiftUI

struct BankAccountsView: View {
    @ObservedObject var store: PlannerStore
    @State private var isAddPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Bank Accounts",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            overviewCard
            accountsSection
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add account", systemImage: "plus") {
                    isAddPresented = true
                }
                .accessibilityIdentifier("bank-accounts-add")
            }
        }
        .sheet(isPresented: $isAddPresented) {
            NavigationStack {
                BankAccountFormView(store: store)
            }
        }
        .navigationTopDividerHidden()
    }

    private var overviewCard: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Across your accounts")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.Colors.cardEyebrow)

                Text(MoneyParser.formatPence(totalBalancePence))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(totalBalancePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                    .minimumScaleFactor(0.65)

                HStack(spacing: AppTheme.Spacing.sm) {
                    Pill(
                        text: "\(store.activeBankAccounts.count) account\(store.activeBankAccounts.count == 1 ? "" : "s")",
                        systemImage: "building.columns",
                        color: AppTheme.Colors.primaryOrange
                    )
                    if let primaryAccount = store.primaryBankAccount {
                        Pill(text: primaryAccount.name, systemImage: "star.fill", color: AppTheme.Colors.success)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Your accounts")

            if store.activeBankAccounts.isEmpty {
                AppCard {
                    EmptyStateView(
                        title: "No bank accounts yet",
                        message: "Add an account to link income, pots, bills, and everyday spending to a real balance.",
                        systemImage: "building.columns"
                    )
                }
            } else {
                ForEach(store.activeBankAccounts) { account in
                    NavigationLink {
                        BankAccountDetailView(store: store, account: account)
                    } label: {
                        AppCard {
                            HStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: account.type.systemImage)
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: account.color))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: account.color).opacity(0.14))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(account.name)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                            .lineLimit(1)
                                        if account.isPrimary {
                                            Image(systemName: "star.fill")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.Colors.warning)
                                                .accessibilityLabel("Primary account")
                                        }
                                    }

                                    Text(account.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: AppTheme.Spacing.sm)

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(MoneyParser.formatPence(balance(for: account)))
                                        .font(.headline.bold())
                                        .foregroundStyle(balance(for: account) < 0 ? AppTheme.Colors.danger : AppTheme.Colors.success)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bank-account-\(account.id)")
                }
            }
        }
    }

    private var totalBalancePence: Int {
        store.activeBankAccounts.reduce(0) { $0 + balance(for: $1) }
    }

    private func balance(for account: BankAccount) -> Int {
        PlannerDerivedData.bankAccountBalance(account: account, snapshot: store.snapshot)
    }
}

extension BankAccountType {
    var systemImage: String {
        switch self {
        case .current:
            "building.columns"
        case .savings:
            "banknote"
        case .cash:
            "sterlingsign.circle"
        case .other:
            "wallet.bifold"
        }
    }
}

extension BankAccount {
    var subtitle: String {
        let providerName = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = lastFourDigits.map { "•••• \($0)" }
        return [providerName.isEmpty ? type.displayName : providerName, suffix]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
