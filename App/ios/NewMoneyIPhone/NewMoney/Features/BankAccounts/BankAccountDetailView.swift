import SwiftUI

struct BankAccountDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    var account: BankAccount
    @State private var isEditPresented = false
    @State private var isDeleteConfirmationPresented = false

    var body: some View {
        ScreenScaffold(
            title: currentAccount.name,
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            balanceCard
            linksCard
            activitySection
            deleteButton
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditPresented = true
                }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            NavigationStack {
                BankAccountFormView(store: store, account: currentAccount)
            }
        }
        .alert("Remove bank account?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                store.deleteBankAccount(id: account.id)
                dismiss()
            }
        } message: {
            Text("The account will be removed from future selections. Existing linked activity stays in history.")
        }
        .navigationTopDividerHidden()
    }

    private var balanceCard: some View {
        AppCard(glow: true) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Current balance")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.Colors.cardEyebrow)
                        Text(MoneyParser.formatPence(currentBalancePence))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(currentBalancePence < 0 ? AppTheme.Colors.danger : AppTheme.Colors.primaryText)
                            .minimumScaleFactor(0.65)
                    }
                    Spacer()
                    Image(systemName: currentAccount.type.systemImage)
                        .font(.title2.bold())
                        .foregroundStyle(Color(hex: currentAccount.color))
                        .frame(width: 50, height: 50)
                        .background(Color(hex: currentAccount.color).opacity(0.14))
                        .clipShape(Circle())
                }

                AppDivider()
                MetricRow(label: "Provider", value: currentAccount.provider.isEmpty ? "Not set" : currentAccount.provider)
                MetricRow(label: "Type", value: currentAccount.type.displayName)
                if let lastFourDigits = currentAccount.lastFourDigits {
                    MetricRow(label: "Account", value: "•••• \(lastFourDigits)")
                }
                MetricRow(label: "Main account", value: currentAccount.isPrimary ? "Yes" : "No", valueColor: currentAccount.isPrimary ? AppTheme.Colors.success : AppTheme.Colors.secondaryText)
            }
        }
    }

    private var linksCard: some View {
        AppCard {
            SectionTitle("Linked flows")
            MetricRow(label: "Income records", value: "\(linkedIncomeCount)")
            MetricRow(label: "Funding pots", value: "\(linkedPots.count)")
            MetricRow(label: "Direct bills", value: "\(linkedBills.count)")
            MetricRow(label: "Bank spending", value: "\(linkedSpendingCount)")

            if !linkedPots.isEmpty {
                AppDivider()
                Text("Pots: \(linkedPots.map(\.name).joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionTitle("Account activity")
            if movements.isEmpty {
                AppCard {
                    EmptyStateView(
                        title: "No linked activity",
                        message: "Link income, spending, or a pot to this account to build its balance history.",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
            } else {
                AppCard {
                    ForEach(Array(movements.prefix(20).enumerated()), id: \.element.id) { index, movement in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                            Image(systemName: movement.amountPence >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(movement.amountPence >= 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(movement.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                Text(FinanceEngine.formatPaydayLabel(movement.date))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.secondaryText)
                            }

                            Spacer()
                            Text(MoneyParser.formatPence(movement.amountPence))
                                .font(.subheadline.bold())
                                .foregroundStyle(movement.amountPence >= 0 ? AppTheme.Colors.success : AppTheme.Colors.warning)
                        }

                        if index < min(20, movements.count) - 1 {
                            AppDivider()
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        SecondaryButton(title: "Remove bank account", systemImage: "trash", role: .destructive) {
            isDeleteConfirmationPresented = true
        }
    }

    private var currentAccount: BankAccount {
        store.snapshot.bankAccounts.first(where: { $0.id == account.id }) ?? account
    }

    private var currentBalancePence: Int {
        PlannerDerivedData.bankAccountBalance(account: currentAccount, snapshot: store.snapshot)
    }

    private var linkedIncomeCount: Int {
        store.snapshot.paychecks.count(where: { $0.deletedAt == nil && $0.bankAccountId == account.id }) +
            store.snapshot.oneOffIncomes.count(where: { $0.deletedAt == nil && $0.bankAccountId == account.id })
    }

    private var linkedPots: [Pot] {
        store.snapshot.pots.filter { !$0.archived && $0.fundingBankAccountId == account.id }
    }

    private var linkedBills: [RecurringPayment] {
        store.snapshot.recurringPayments.filter { $0.active && $0.bankAccountId == account.id }
    }

    private var linkedSpendingCount: Int {
        store.snapshot.transactions.count(where: {
            $0.deletedAt == nil &&
                !$0.isRefunded &&
                $0.type == .spending &&
                $0.bankAccountId == account.id
        })
    }

    private var movements: [Movement] {
        let periods = Dictionary(uniqueKeysWithValues: store.snapshot.payPeriods.map { ($0.id, $0) })
        let paychecks = store.snapshot.paychecks.compactMap { paycheck -> Movement? in
            guard paycheck.deletedAt == nil, paycheck.bankAccountId == account.id else { return nil }
            return Movement(
                id: "paycheck-\(paycheck.id)",
                title: "Paycheck",
                date: periods[paycheck.payPeriodId]?.payday ?? paycheck.createdAt,
                amountPence: max(0, paycheck.actualAmountPence ?? paycheck.calculatedAmountPence)
            )
        }
        let incomes = store.snapshot.oneOffIncomes.compactMap { income -> Movement? in
            guard income.deletedAt == nil, income.bankAccountId == account.id else { return nil }
            return Movement(id: "income-\(income.id)", title: income.name, date: income.date, amountPence: max(0, income.amountPence))
        }
        let allocations = store.snapshot.potAllocations.compactMap { allocation -> Movement? in
            guard allocation.deletedAt == nil, allocation.bankAccountId == account.id else { return nil }
            let name = store.snapshot.pots.first(where: { $0.id == allocation.potId })?.name ?? "Pot"
            return Movement(
                id: "allocation-\(allocation.id)",
                title: "Funded \(name)",
                date: String(allocation.createdAt.prefix(10)),
                amountPence: -max(0, allocation.amountPence)
            )
        }
        let transactions = store.snapshot.transactions.compactMap { transaction -> Movement? in
            guard transaction.deletedAt == nil,
                  !transaction.isRefunded,
                  transaction.bankAccountId == account.id
            else { return nil }
            return Movement(
                id: "transaction-\(transaction.id)",
                title: transaction.note.isEmpty ? "Bank payment" : transaction.note,
                date: transaction.date,
                amountPence: -max(0, transaction.amountPence)
            )
        }

        return (paychecks + incomes + allocations + transactions).sorted {
            if $0.date == $1.date {
                return $0.id > $1.id
            }
            return $0.date > $1.date
        }
    }

    private struct Movement: Identifiable {
        var id: String
        var title: String
        var date: String
        var amountPence: Int
    }
}
