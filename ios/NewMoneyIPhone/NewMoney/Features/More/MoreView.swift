import SwiftUI

struct MoreView: View {
    @ObservedObject var store: PlannerStore
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble

    var body: some View {
        ScreenScaffold(
            title: "More",
            subtitle: "History and account settings.",
            navigationMode: navigationMode,
            toolbarMode: toolbarMode
        ) {
            moreLink("History", subtitle: "Paycheck and allocation history.", symbol: "clock.arrow.circlepath", destination: HistoryView(store: store))
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
