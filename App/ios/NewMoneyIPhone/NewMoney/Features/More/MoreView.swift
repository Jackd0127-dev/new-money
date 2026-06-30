import SwiftUI

struct MoreView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble

    var body: some View {
        ScreenScaffold(
            title: "More",
            subtitle: "Income planning and account settings.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            moreLink(
                "Income",
                subtitle: "Paycheck inputs, pay periods, and money left.",
                symbol: "sterlingsign.circle",
                destination: IncomeBreakdownView(store: store)
            )
            moreLink(
                "Statements",
                subtitle: "Credit card statements, due dates, and linked transactions.",
                symbol: "doc.text.magnifyingglass",
                destination: StatementsView(store: store)
            )
        }
    }

    private func moreLink<Destination: View>(_ title: String, subtitle: String, symbol: String, destination: Destination) -> some View {
        NavigationLink {
            destination
        } label: {
            AppCard {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: symbol)
                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more-link-\(title.accessibilityIdentifierSlug)")
    }
}

struct StatementsView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .inline
    var toolbarMode: AppToolbarMode = .secondarySingle

    var body: some View {
        ScreenScaffold(
            title: "Statements",
            subtitle: "Created card statements and direct debit status.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            let statements = PlannerDerivedData.creditCardStatementSummaries(
                snapshot: store.snapshot,
                asOfDate: store.todayIso
            )

            if statements.isEmpty {
                AppCard {
                    EmptyStateView(title: "No statements yet", message: "Statements appear after a card statement date has passed.", systemImage: "doc.text")
                }
            } else {
                ForEach(statements) { statement in
                    StatementSummaryCard(statement: statement)
                }
            }
        }
        .accessibilityIdentifier("statements-screen")
    }
}

private struct StatementSummaryCard: View {
    var statement: CreditCardStatementSummary

    var body: some View {
        AppCard(glow: statement.status == .overdue) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(statement.cardName) Statement")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.primaryText)
                        Text("Statement date: \(shortDate(statement.statementDate))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                    }
                    Spacer()
                    Text(statusLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(spacing: 8) {
                    MetricRow(label: "Amount", value: MoneyParser.formatPence(statement.statementAmountPence), valueColor: AppTheme.Colors.primaryOrange)
                    MetricRow(label: "Due date", value: shortDate(statement.directDebitDate))
                    if statement.paidAmountPence > 0 {
                        MetricRow(label: "Paid", value: MoneyParser.formatPence(statement.paidAmountPence), valueColor: AppTheme.Colors.success)
                    }
                    if statement.unpaidAmountPence > 0 {
                        MetricRow(label: "Unpaid", value: MoneyParser.formatPence(statement.unpaidAmountPence), valueColor: statement.status == .overdue ? AppTheme.Colors.danger : AppTheme.Colors.warning)
                    }
                }

                if !statement.transactions.isEmpty {
                    AppDivider()
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        SectionTitle("Transactions")
                            .accessibilityIdentifier("statement-transactions-\(statement.cardId)-\(statement.statementDate)")
                        ForEach(statement.transactions) { transaction in
                            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(transaction.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Colors.primaryText)
                                    Text("\(sourceLabel(transaction.source)) · \(shortDate(transaction.date))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.secondaryText)
                                }
                                Spacer()
                                Text(MoneyParser.formatPence(transaction.amountPence))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.Colors.primaryText)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("statement-card-\(statement.cardId)-\(statement.statementDate)")
    }

    private var statusLabel: String {
        switch statement.status {
        case .upcoming:
            return "Upcoming"
        case .paid:
            return "Paid"
        case .overdue:
            return "Overdue"
        }
    }

    private var statusColor: Color {
        switch statement.status {
        case .upcoming:
            return AppTheme.Colors.warning
        case .paid:
            return AppTheme.Colors.success
        case .overdue:
            return AppTheme.Colors.danger
        }
    }

    private func sourceLabel(_ source: CreditCardStatementTransactionSource) -> String {
        switch source {
        case .spending:
            return "Card spend"
        case .recurring:
            return "Bill"
        case .custom:
            return "Payment"
        }
    }

    private func shortDate(_ isoDate: String) -> String {
        FinanceEngine.parseDate(isoDate).formatted(.dateTime.day().month(.abbreviated))
    }
}

private extension String {
    var accessibilityIdentifierSlug: String {
        lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}

struct DateSimulationCard: View {
    @ObservedObject var store: PlannerStore
    @State private var manualDate = Date()

    var body: some View {
        AppCard(glow: store.snapshot.settings.appDateMode == .manual) {
            SectionTitle("Date simulation")
            MetricRow(label: "Today", value: FinanceEngine.formatShortDateLabel(store.todayIso), valueColor: store.snapshot.settings.appDateMode == .manual ? AppTheme.Colors.primaryOrange : AppTheme.Colors.success)
            Picker("Date mode", selection: dateModeBinding) {
                ForEach(AppDateMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if store.snapshot.settings.appDateMode == .manual {
                DatePicker("Manual today", selection: manualDateBinding, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(AppTheme.Colors.primaryOrange)
                    .foregroundStyle(AppTheme.Colors.primaryText)
            }
        }
        .onAppear {
            manualDate = store.snapshot.settings.manualTodayIso?.isoDate ?? store.todayIso.isoDate
        }
    }

    private var dateModeBinding: Binding<AppDateMode> {
        Binding {
            store.snapshot.settings.appDateMode
        } set: { mode in
            var settings = store.snapshot.settings
            settings.appDateMode = mode
            switch mode {
            case .automatic:
                settings.manualTodayIso = nil
            case .manual:
                let selectedDate = settings.manualTodayIso?.isoDate ?? manualDate
                manualDate = selectedDate
                settings.manualTodayIso = selectedDate.isoDateString
            }
            store.updateSettings(settings)
        }
    }

    private var manualDateBinding: Binding<Date> {
        Binding {
            manualDate
        } set: { selectedDate in
            manualDate = selectedDate
            var settings = store.snapshot.settings
            settings.appDateMode = .manual
            settings.manualTodayIso = selectedDate.isoDateString
            store.updateSettings(settings)
        }
    }
}
