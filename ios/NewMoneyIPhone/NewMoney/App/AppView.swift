import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case payday
    case pots
    case cards
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Overview"
        case .payday: "Payday"
        case .pots: "Pots"
        case .cards: "Cards"
        case .more: "More"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "chart.line.uptrend.xyaxis"
        case .payday: "sterlingsign.circle"
        case .pots: "wallet.pass"
        case .cards: "creditcard"
        case .more: "square.grid.2x2"
        }
    }
}

struct AppView: View {
    @StateObject private var store = PlannerStore()
    @State private var selectedTab: AppTab = .dashboard
    @State private var isAssistantPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                DashboardView(store: store)
                    .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }
                    .tag(AppTab.dashboard)

                PaydayView(store: store)
                    .tabItem { Label(AppTab.payday.title, systemImage: AppTab.payday.symbol) }
                    .tag(AppTab.payday)

                PotsView(store: store)
                    .tabItem { Label(AppTab.pots.title, systemImage: AppTab.pots.symbol) }
                    .tag(AppTab.pots)

                CardsView(store: store)
                    .tabItem { Label(AppTab.cards.title, systemImage: AppTab.cards.symbol) }
                    .tag(AppTab.cards)

                MoreView(store: store)
                    .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.symbol) }
                    .tag(AppTab.more)
            }
            .tint(AppTheme.Colors.primaryOrange)
            .task {
                await store.load()
            }

            Button {
                isAssistantPresented = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.Gradients.primary)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.Colors.glowOrange, radius: 20, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, AppTheme.Spacing.lg)
            .padding(.bottom, 72)
            .accessibilityLabel("Open Assistant")
        }
        .background(AppTheme.Colors.appBackground)
        .dismissKeyboardOnBackgroundTap()
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isAssistantPresented) {
            AssistantView(store: store)
        }
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppTheme.Colors.primaryOrange)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primaryOrange)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppTheme.Colors.tertiaryText)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.tertiaryText)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    AppView()
}
