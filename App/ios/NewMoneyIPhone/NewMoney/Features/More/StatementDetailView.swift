import SwiftUI

struct StatementDetailView: View {
    var statement: CreditCardStatementSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScreenScaffold(
            title: "\(statement.cardName) Statement",
            subtitle: "Statement details and the transactions included in this billing cycle.",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            AppCard(glow: statement.status == .overdue) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        Label("Statement summary", systemImage: "doc.text")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)

                        statusBadge
                    }
                } else {
                    HStack(alignment: .center) {
                        Label("Statement summary", systemImage: "doc.text")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)

                        Spacer()

                        statusBadge
                    }
                }

                Text(statusDescription)
                    .font(.footnote)
                    .foregroundStyle(status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.secondaryText)

                CreditMetricGrid(items: statementMetrics)

                if statement.statementAmountPence > 0 {
                    ProgressView(value: paymentProgress)
                        .tint(statement.unpaidAmountPence == 0 ? AppTheme.Colors.success : AppTheme.Colors.primaryOrange)
                        .accessibilityLabel("Statement payment progress")
                        .accessibilityValue("\(Int(paymentProgress * 100)) percent paid")
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Statement breakdown")

                AppCard {
                    CreditMetricGrid(items: breakdownMetrics)

                    if statement.amountSource == .confirmedBankAmount {
                        Text("The bank total is kept authoritative. The adjustment reconciles it with the real transactions currently itemised in New Money.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Tracked transactions")
                    .accessibilityIdentifier("statement-transactions-\(statement.cardId)-\(statement.statementDate)")

                if statement.transactions.isEmpty {
                    AppCard {
                        EmptyStateView(
                            title: "No transaction details",
                            message: "This statement does not contain any itemised transactions.",
                            systemImage: "receipt"
                        )
                    }
                } else {
                    AppCard {
                        ForEach(Array(statement.transactions.enumerated()), id: \.element.id) { index, transaction in
                            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                                Image(systemName: sourceSymbol(transaction.source))
                                    .foregroundStyle(AppTheme.Colors.primaryOrange)
                                    .frame(width: 28, height: 28)
                                    .background(AppTheme.Colors.primaryOrange.opacity(0.12), in: Circle())
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.primaryText)

                                    Text("\(sourceLabel(transaction.source)) · \(fullDate(transaction.date))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }

                                Spacer(minLength: AppTheme.Spacing.sm)

                                Text(MoneyParser.formatPence(transaction.amountPence))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                                    .lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)

                            if index < statement.transactions.count - 1 {
                                AppDivider()
                            }
                        }
                    }
                }
            }
        }
        .navigationTopDividerHidden()
        .accessibilityIdentifier("statement-detail-\(statement.cardId)-\(statement.statementDate)")
    }

    private var status: CreditCardStatementStatus {
        statement.status
    }

    private var statusBadge: some View {
        Text(statusLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var statusLabel: String {
        switch status {
        case .upcoming:
            "Upcoming"
        case .paid:
            "Paid"
        case .overdue:
            "Overdue"
        case .awaitingConfirmation:
            "Awaiting confirmation"
        }
    }

    private var statusDescription: String {
        switch status {
        case .upcoming:
            "The remaining balance is scheduled for payment on \(fullDate(statement.directDebitDate))."
        case .paid:
            "This statement has been paid in full."
        case .overdue:
            "The remaining balance was due on \(fullDate(statement.directDebitDate))."
        case .awaitingConfirmation:
            "The bank dates for this statement are waiting for confirmation."
        }
    }

    private var statusColor: Color {
        switch status {
        case .upcoming, .awaitingConfirmation:
            AppTheme.Colors.warning
        case .paid:
            AppTheme.Colors.success
        case .overdue:
            AppTheme.Colors.danger
        }
    }

    private var remainingColor: Color {
        guard statement.unpaidAmountPence > 0 else { return AppTheme.Colors.success }
        return status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.warning
    }

    private var statementMetrics: [CreditMetricGrid.Item] {
        [
            .init(
                label: statement.amountSource == .confirmedBankAmount ? "Confirmed statement total" : "Statement total",
                value: MoneyParser.formatPence(statement.statementAmountPence),
                valueColor: AppTheme.Colors.primaryOrange
            ),
            .init(label: "Statement date", value: fullDate(statement.statementDate)),
            .init(label: "Direct debit date", value: fullDate(statement.directDebitDate)),
            .init(
                label: "Paid",
                value: MoneyParser.formatPence(statement.paidAmountPence),
                valueColor: statement.paidAmountPence > 0 ? AppTheme.Colors.success : AppTheme.Colors.secondaryText
            ),
            .init(
                label: "Remaining",
                value: MoneyParser.formatPence(statement.unpaidAmountPence),
                valueColor: remainingColor
            ),
            .init(label: "Tracked transactions", value: "\(statement.transactions.count)")
        ]
    }

    private var breakdownMetrics: [CreditMetricGrid.Item] {
        var items: [CreditMetricGrid.Item] = []
        if sourceTotal(.openingStatement) > 0 {
            items.append(.init(label: "Opening balance", value: MoneyParser.formatPence(sourceTotal(.openingStatement))))
        }
        if sourceTotal(.spending) > 0 {
            items.append(.init(label: "Card spending", value: MoneyParser.formatPence(sourceTotal(.spending))))
        }
        if sourceTotal(.recurring) > 0 {
            items.append(.init(label: "Bills", value: MoneyParser.formatPence(sourceTotal(.recurring))))
        }
        if sourceTotal(.custom) > 0 {
            items.append(.init(label: "One-off payments", value: MoneyParser.formatPence(sourceTotal(.custom))))
        }
        if sourceTotal(.refund) < 0 {
            items.append(
                .init(
                    label: "Refund credits",
                    value: MoneyParser.formatPence(sourceTotal(.refund)),
                    valueColor: AppTheme.Colors.success
                )
            )
        }
        items.append(
            .init(
                label: "Tracked transaction total",
                value: MoneyParser.formatPence(statement.calculatedAmountPence)
            )
        )
        if statement.amountSource == .confirmedBankAmount {
            items.append(
                .init(
                    label: "Bank statement adjustment",
                    value: signedMoney(statement.reconciliationAdjustmentPence),
                    valueColor: statement.reconciliationAdjustmentPence == 0 ? AppTheme.Colors.secondaryText : AppTheme.Colors.warning
                )
            )
        }
        return items
    }

    private func signedMoney(_ pence: Int) -> String {
        guard pence > 0 else { return MoneyParser.formatPence(pence) }
        return "+\(MoneyParser.formatPence(pence))"
    }

    private var paymentProgress: Double {
        let total = max(1, statement.statementAmountPence)
        return min(1, max(0, Double(statement.paidAmountPence) / Double(total)))
    }

    private func sourceTotal(_ source: CreditCardStatementTransactionSource) -> Int {
        statement.transactions
            .filter { $0.source == source }
            .reduce(0) { $0 + $1.amountPence }
    }

    private func sourceLabel(_ source: CreditCardStatementTransactionSource) -> String {
        switch source {
        case .openingStatement:
            "Opening balance"
        case .spending:
            "Card spend"
        case .recurring:
            "Bill"
        case .custom:
            "One-off payment"
        case .refund:
            "Refund credit"
        }
    }

    private func sourceSymbol(_ source: CreditCardStatementTransactionSource) -> String {
        switch source {
        case .openingStatement:
            "arrow.turn.down.right"
        case .spending:
            "creditcard"
        case .recurring:
            "calendar.badge.clock"
        case .custom:
            "calendar.badge.plus"
        case .refund:
            "arrow.uturn.backward.circle.fill"
        }
    }

    private func fullDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.weekday(.abbreviated).day().month(.wide).year())
    }
}
