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

private enum AppToolbarSheet: String, Identifiable {
    case spending
    case calendar
    case settings

    var id: String { rawValue }
}

struct AppView: View {
    @StateObject private var store = PlannerStore()
    @State private var selectedTab: AppTab = .dashboard
    @State private var isAssistantPresented = false
    @State private var activeToolbarSheet: AppToolbarSheet?
    @Namespace private var rootToolbarNamespace

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                TabView(selection: selectedTabBinding) {
                    DashboardView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }
                        .tag(AppTab.dashboard)

                    PaydayView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.payday.title, systemImage: AppTab.payday.symbol) }
                        .tag(AppTab.payday)

                    PotsView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.pots.title, systemImage: AppTab.pots.symbol) }
                        .tag(AppTab.pots)

                    CardsView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.cards.title, systemImage: AppTab.cards.symbol) }
                        .tag(AppTab.cards)

                    MoreView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.symbol) }
                        .tag(AppTab.more)
                }
                .tint(AppTheme.Colors.primaryOrange)
                .navigationTitle(selectedTab.title)
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar(id: "root-tab-toolbar") {
                    rootTabToolbarContent
                }
                .task {
                    await store.load()
                }
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
        .sheet(item: $activeToolbarSheet) { sheet in
            switch sheet {
            case .spending:
                SpendingSheetView(store: store)
            case .calendar:
                CalendarSheetView(store: store)
            case .settings:
                SettingsSheetView(store: store)
            }
        }
        .sheet(isPresented: $isAssistantPresented) {
            AssistantView(store: store, presentationMode: .modal)
        }
        .onAppear {
            configureTabBarAppearance()
        }
    }

    @ToolbarContentBuilder
    private var rootTabToolbarContent: some CustomizableToolbarContent {
        if let secondaryToolbarAction {
            rootToolbarItem(secondaryToolbarAction)
        }
        if let primaryToolbarAction {
            rootToolbarItem(primaryToolbarAction)
        }
    }

    @ToolbarContentBuilder
    private func rootToolbarItem(_ action: AppToolbarAction) -> some CustomizableToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(id: action.id, placement: .topBarTrailing) {
                AppToolbarButton(action: action)
            }
            .matchedTransitionSource(id: action.id, in: rootToolbarNamespace)
        } else {
            ToolbarItem(id: action.id, placement: .topBarTrailing) {
                AppToolbarButton(action: action)
            }
        }
    }

    private var primaryToolbarAction: AppToolbarAction? {
        selectedTabToolbarActions.last
    }

    private var secondaryToolbarAction: AppToolbarAction? {
        selectedTabToolbarActions.count > 1 ? selectedTabToolbarActions.first : nil
    }

    private var selectedTabToolbarActions: [AppToolbarAction] {
        switch selectedTab {
        case .dashboard:
            overviewToolbarActions
        case .payday, .pots, .cards:
            spendingToolbarActions
        case .more:
            moreToolbarActions
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { newTab in
            withAnimation(.smooth(duration: 0.32)) {
                selectedTab = newTab
            }
        }
    }

    private var spendingToolbarActions: [AppToolbarAction] {
        [
            AppToolbarAction(id: "primary-toolbar-action", symbol: "plus", accessibilityLabel: "Record Spending") {
                activeToolbarSheet = .spending
            }
        ]
    }

    private var moreToolbarActions: [AppToolbarAction] {
        [
            AppToolbarAction(id: "primary-toolbar-action", symbol: "gearshape", accessibilityLabel: "Open Settings") {
                activeToolbarSheet = .settings
            }
        ]
    }

    private var overviewToolbarActions: [AppToolbarAction] {
        [
            AppToolbarAction(id: "secondary-toolbar-action", symbol: "calendar", accessibilityLabel: "Open Calendar") {
                activeToolbarSheet = .calendar
            },
            AppToolbarAction(id: "primary-toolbar-action", symbol: "plus", accessibilityLabel: "Record Spending") {
                activeToolbarSheet = .spending
            }
        ]
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
