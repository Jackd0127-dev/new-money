import SwiftUI

struct MoreView: View {
    @ObservedObject var store: PlannerStore

    var body: some View {
        ScreenScaffold(
            title: "More",
            subtitle: "Spending, bills, debts, calendar, history, settings, and account tools."
        ) {
            moreLink("Spending", subtitle: "Record pot or credit-card spend.", symbol: "cart", destination: SpendingView(store: store))
            moreLink("Bills", subtitle: "Recurring payments and upcoming bill agenda.", symbol: "calendar.badge.clock", destination: BillsView(store: store))
            moreLink("Debts", subtitle: "Balances, reserves, and payments.", symbol: "exclamationmark.shield", destination: DebtsView(store: store))
            moreLink("Calendar", subtitle: "Paydays, bills, spending, cards, and debt events.", symbol: "calendar", destination: CalendarPlannerView(store: store))
            moreLink("History", subtitle: "Paycheck and allocation history.", symbol: "clock.arrow.circlepath", destination: HistoryView(store: store))
            moreLink("Settings", subtitle: "Date mode, pay defaults, account, AI, and reset.", symbol: "gearshape", destination: SettingsView(store: store))
            moreLink("Assistant", subtitle: "AI planner placeholder and local financial facts.", symbol: "sparkles", destination: AssistantView(store: store))
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
    }
}
