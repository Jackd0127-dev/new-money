import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case bills
    case activity
    case pots
    case credit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .bills: "Bills"
        case .activity: "Activity"
        case .pots: "Pots"
        case .credit: "Credit"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .bills: "calendar.badge.clock"
        case .activity: "list.bullet.rectangle.portrait"
        case .pots: "wallet.pass"
        case .credit: "creditcard.trianglebadge.exclamationmark"
        }
    }

}

struct PlannerTabPresentationKey: Hashable {
    var tab: AppTab
    var activePlannerAccountId: String?
    var snapshotRevision: Int
    var todayIso: String
    var selectedPayPeriodId: String?
}

struct PlannerTabPresentationContext {
    var snapshot: PlannerSnapshot
    var activePlannerAccountId: String?
    var snapshotRevision: Int
    var todayIso: String
    var selectedPayPeriod: PayPeriod?
    var isLoading = false

    func key(for tab: AppTab) -> PlannerTabPresentationKey {
        PlannerTabPresentationKey(
            tab: tab,
            activePlannerAccountId: activePlannerAccountId,
            snapshotRevision: snapshotRevision,
            todayIso: todayIso,
            selectedPayPeriodId: selectedPayPeriod?.id
        )
    }

    var warmUpIdentity: PlannerTabPresentationWarmUpIdentity {
        PlannerTabPresentationWarmUpIdentity(
            activePlannerAccountId: activePlannerAccountId,
            snapshotRevision: snapshotRevision,
            todayIso: todayIso,
            selectedPayPeriodId: selectedPayPeriod?.id,
            isLoading: isLoading
        )
    }
}

struct PlannerTabPresentationWarmUpIdentity: Hashable {
    var activePlannerAccountId: String?
    var snapshotRevision: Int
    var todayIso: String
    var selectedPayPeriodId: String?
    var isLoading: Bool
}

@MainActor
final class PlannerTabPresentationCache {
    private struct Entry {
        var key: PlannerTabPresentationKey
        var presentation: Any
    }

    private var entries: [AppTab: Entry] = [:]
    private(set) var buildCounts: [AppTab: Int] = [:]

    func value<Value>(for key: PlannerTabPresentationKey, build: () -> Value) -> Value {
        if let entry = entries[key.tab],
           entry.key == key,
           let presentation = entry.presentation as? Value {
            return presentation
        }

        let presentation = build()
        entries[key.tab] = Entry(key: key, presentation: presentation)
        buildCounts[key.tab, default: 0] += 1
        return presentation
    }

    func buildCount(for tab: AppTab) -> Int {
        buildCounts[tab, default: 0]
    }

    func removeAll() {
        entries.removeAll()
        buildCounts.removeAll()
    }
}

enum AppAddAction: String, CaseIterable, Identifiable {
    case spend
    case bill
    case pot
    case card

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spend: "Add Spend"
        case .bill: "Add Bill"
        case .pot: "Add Pot"
        case .card: "Add Card"
        }
    }

    var subtitle: String {
        switch self {
        case .spend: "Record manual spending."
        case .bill: "Add a recurring payment."
        case .pot: "Create a savings pot."
        case .card: "Add a credit card."
        }
    }

    var symbol: String {
        switch self {
        case .spend: "receipt"
        case .bill: "calendar.badge.plus"
        case .pot: "wallet.pass"
        case .card: "creditcard"
        }
    }
}

enum AppAddMenuPolicy {
    static let showsNavigationDivider = false
    static let opensSingleActionDirectly = true

    static func actions(for tab: AppTab) -> [AppAddAction] {
        switch tab {
        case .home:
            return [.spend]
        case .activity:
            return []
        case .bills:
            return [.bill]
        case .pots:
            return [.pot]
        case .credit:
            return [.card]
        }
    }
}

enum AppToolbarPolicy {
    static func leadingActionIds(for tab: AppTab) -> [String] {
        switch tab {
        case .home:
            ["profile-menu-toolbar-action"]
        case .bills, .activity, .pots, .credit:
            []
        }
    }

    static func actionIds(for tab: AppTab) -> [String] {
        var actionIds: [String] = []

        switch tab {
        case .home:
            actionIds.append("plan-calendar-toolbar-action")
        case .bills:
            break
        case .activity:
            actionIds.append("activity-infinity-toolbar-action")
        case .credit:
            break
        case .pots:
            actionIds.append("pot-history-toolbar-action")
        }

        if !AppAddMenuPolicy.actions(for: tab).isEmpty {
            actionIds.append("add-menu-toolbar-action")
        }
        return actionIds
    }
}

enum AppNavigationTitlePolicy {
    static func title(for tab: AppTab, activeAccountName: String?) -> String {
        guard tab == .home else { return tab.title }

        let accountName = activeAccountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return accountName.isEmpty ? tab.title : accountName
    }
}

enum FloatingAssistantPolicy {
    static let symbol = "person.fill"
    static let minimumTapTarget: CGFloat = 56
}

enum AppNavigationTitleDisplayStyle: Equatable {
    case large
    case inline
}

enum AppNavigationTitleDisplayPolicy {
    static func style(for tab: AppTab) -> AppNavigationTitleDisplayStyle {
        .inline
    }

    static func mode(for tab: AppTab) -> NavigationBarItem.TitleDisplayMode {
        switch style(for: tab) {
        case .large:
            return .large
        case .inline:
            return .inline
        }
    }
}

enum AppTabNavigationStackPolicy {
    static let isolatesNavigationStackPerTab = false
    static let wrapsTabShellInRootNavigationStack = true
    static let pushedScreensCoverAppleTabBar = true
    static let appliesTitleInsideRootTabShell = true
    static let appliesToolbarInsideRootTabShell = true
    static let keepsTabRootScrollReset = true
}

enum ProfileMenuAction: String, CaseIterable, Identifiable {
    case income
    case accounts
    case statements
    case faq
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Income"
        case .accounts: "Accounts"
        case .statements: "Statements"
        case .faq: "FAQ"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .income: "Paychecks, one-off income, and pay periods."
        case .accounts: "Balances, income destinations, pots, and Direct Debits."
        case .statements: "Card statements and direct debit status."
        case .faq: "Answers to common New Money questions."
        case .settings: "Appearance, history, planner defaults, and account controls."
        }
    }

    var symbol: String {
        switch self {
        case .income: "sterlingsign.circle"
        case .accounts: "building.columns"
        case .statements: "doc.text.magnifyingglass"
        case .faq: "questionmark.circle"
        case .settings: "gearshape"
        }
    }

    var tint: Color {
        switch self {
        case .income: AppTheme.Colors.success
        case .accounts: AppTheme.Colors.primaryOrange
        case .statements: AppTheme.Colors.warning
        case .faq: AppTheme.Colors.accent
        case .settings: AppTheme.Colors.secondaryText
        }
    }
}

enum ProfileMenuPresentationStyle: Equatable {
    case rootNavigationLink
}

enum ProfileMenuSettingsPresentationStyle: Equatable {
    case navigationLink
}

enum ProfileMenuPresentationPolicy {
    static let profileStyle: ProfileMenuPresentationStyle = .rootNavigationLink
    static let settingsStyle: ProfileMenuSettingsPresentationStyle = .navigationLink
    static let centersProfileIdentity = true
    static let syncsActiveAccountName = true
    static let syncsActiveAccountAvatar = true
    static let showsSignOutAction = true
    static let signOutUsesAuthGateSession = true
    static let logOutActionTitle = "Log Out"
    static let confirmsLogOut = true
    static let showsResetDataAction = true
    static let resetDataActionTitle = "Reset Data"
    static let resetDataConfirmationCount = 2
    static let resetDataKeepsAuthAccount = true
    static let resetDataDeletesCloudPlannerData = true
    static let includesAddIncomeAction = false
    static let opensAppearanceDirectly = false
    static let usesSystemFullScreenSafeArea = true
    static let usesInlineNavigationTitle = true
    static let showsProfileSubtitle = false
    static let editActionTitle = "Edit"
    static let editActionOpensAccounts = true
    static let accountsPresentationStyle = "navigationDestination"
    static let animatesFromBottom = false
    static let avoidsSystemNavigationBar = false
    static let usesCompactActionRows = true
    static let showsActionIcons = true
    static let showsActionSubtitles = false
    static let showsActionDisclosureIndicators = true
    static let showsActionDividers = true
    static let usesSeparateDestructiveActionCards = false
    static let actionRowMinimumHeight: CGFloat = 54
    static let actionCardCornerRadius: CGFloat = AppTheme.Radius.lg
}

private enum AppSheetDestination: String, Identifiable {
    case addMenu
    case addSpend
    case addBill
    case addPot
    case addCard
    case spendingHistory
    case calendar
    case potHistory

    var id: String { rawValue }
}

private enum AppNavigationDestination: String, Identifiable {
    case plan
    case accounts

    var id: String { rawValue }
}

struct AppView: View {
    @ObservedObject var store: PlannerStore
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue
    @State private var selectedTab: AppTab = .home
    @State private var rootTabResetRevisions: [AppTab: Int] = [:]
    @State private var tabPresentationCache = PlannerTabPresentationCache()
    @State private var isAssistantPresented = false
    @State private var activeSheet: AppSheetDestination?
    @State private var activeNavigationDestination: AppNavigationDestination?
    @State private var pendingSheetAfterDismiss: AppSheetDestination?

    init(store: PlannerStore = PlannerStore()) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            appTabShell
                .navigationDestination(item: $activeNavigationDestination) { destination in
                    navigationDestination(for: destination)
                }
        }
        .background {
            PremiumRootBackground()
        }
        .dismissKeyboardOnBackgroundTap()
        .preferredColorScheme(selectedTheme.palette.preferredColorScheme)
        .sheet(item: $activeSheet, onDismiss: presentPendingSheet) { sheet in
            switch sheet {
            case .addMenu:
                AddMenuSheetView(actions: selectedTabAddActions) { action in
                    pendingSheetAfterDismiss = sheetDestination(for: action)
                    activeSheet = nil
                }
            case .addSpend:
                SpendingSheetView(store: store)
            case .addBill:
                AddBillSheetView(store: store)
            case .addPot:
                PotFormView(store: store)
            case .addCard:
                CardFormView(store: store)
            case .spendingHistory:
                SpendingHistorySheetView(store: store)
            case .calendar:
                CalendarSheetView(store: store)
            case .potHistory:
                PotHistorySheetView(store: store)
            }
        }
        .sheet(isPresented: $isAssistantPresented) {
            AssistantView(store: store, presentationMode: .modal)
        }
        .onAppear {
            configureSystemChromeAppearance()
        }
        .onChange(of: selectedThemeRawValue) { _, _ in
            configureSystemChromeAppearance()
        }
    }

    private var appTabShell: some View {
        let presentationContext = plannerTabPresentationContext

        return ZStack(alignment: .bottomTrailing) {
            TabView(selection: selectedTabBinding) {
                tabNavigationRoot(for: .home) {
                    DashboardView(
                        store: store,
                        navigationMode: .tabRoot,
                        toolbarMode: .none,
                        rootTabResetRevision: rootTabResetRevision(for: .home),
                        presentationCache: tabPresentationCache,
                        presentationContext: presentationContext,
                        onOpenAccount: { activeNavigationDestination = .accounts },
                        onViewPlan: { activeNavigationDestination = .plan },
                        onViewActivity: { selectTab(.activity) }
                    )
                }
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }
                .tag(AppTab.home)

                tabNavigationRoot(for: .bills) {
                    BillsView(
                        store: store,
                        navigationMode: .tabRoot,
                        toolbarMode: .none,
                        rootTabResetRevision: rootTabResetRevision(for: .bills),
                        presentationCache: tabPresentationCache,
                        presentationContext: presentationContext
                    )
                }
                .tabItem { Label(AppTab.bills.title, systemImage: AppTab.bills.symbol) }
                .tag(AppTab.bills)

                tabNavigationRoot(for: .activity) {
                    ActivityView(
                        store: store,
                        rootTabResetRevision: rootTabResetRevision(for: .activity),
                        presentationCache: tabPresentationCache,
                        presentationContext: presentationContext
                    )
                }
                .tabItem { Label(AppTab.activity.title, systemImage: AppTab.activity.symbol) }
                .tag(AppTab.activity)

                tabNavigationRoot(for: .pots) {
                    PotsView(
                        store: store,
                        navigationMode: .tabRoot,
                        toolbarMode: .none,
                        rootTabResetRevision: rootTabResetRevision(for: .pots),
                        presentationCache: tabPresentationCache,
                        presentationContext: presentationContext
                    )
                }
                .tabItem { Label(AppTab.pots.title, systemImage: AppTab.pots.symbol) }
                .tag(AppTab.pots)

                tabNavigationRoot(for: .credit) {
                    CreditView(
                        store: store,
                        rootTabResetRevision: rootTabResetRevision(for: .credit),
                        presentationCache: tabPresentationCache,
                        presentationContext: presentationContext
                    )
                }
                .tabItem { Label(AppTab.credit.title, systemImage: AppTab.credit.symbol) }
                .tag(AppTab.credit)
            }
            .id("tabs-\(selectedThemeRawValue)")
            .tint(AppTheme.Colors.primaryOrange)

            Button {
                isAssistantPresented = true
            } label: {
                Image(systemName: FloatingAssistantPolicy.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.controlText)
                    .frame(
                        width: FloatingAssistantPolicy.minimumTapTarget,
                        height: FloatingAssistantPolicy.minimumTapTarget
                    )
                    .background(AppTheme.Gradients.primary)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.Colors.glowOrange, radius: 20, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.trailing, AppTheme.Spacing.sm)
            .padding(.bottom, 58)
            .accessibilityLabel("Open Assistant")

        }
        .navigationTitle(navigationTitle(for: selectedTab))
        .navigationBarTitleDisplayMode(AppNavigationTitleDisplayPolicy.mode(for: selectedTab))
        .toolbarColorScheme(selectedTheme.palette.preferredColorScheme, for: .navigationBar)
        .toolbar {
            tabToolbarContent(for: selectedTab)
        }
        .task(id: presentationContext.warmUpIdentity) {
            await warmRootTabPresentations(context: presentationContext)
        }
    }

    @ViewBuilder
    private func tabNavigationRoot<Content: View>(for tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        content()
    }

    @ToolbarContentBuilder
    private func tabToolbarContent(for tab: AppTab) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            ForEach(leadingToolbarActions(for: tab)) { action in
                toolbarButton(for: action)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            ForEach(toolbarActions(for: tab)) { action in
                toolbarButton(for: action)
            }
        }
    }

    private func leadingToolbarActions(for tab: AppTab) -> [AppToolbarAction] {
        AppToolbarPolicy.leadingActionIds(for: tab).compactMap(toolbarAction)
    }

    private func toolbarActions(for tab: AppTab) -> [AppToolbarAction] {
        AppToolbarPolicy.actionIds(for: tab).compactMap(toolbarAction)
    }

    private var selectedTheme: AppThemePreset {
        AppThemePreset.resolved(from: selectedThemeRawValue)
    }

    private var selectedTabAddActions: [AppAddAction] {
        AppAddMenuPolicy.actions(for: selectedTab)
    }

    private var plannerTabPresentationContext: PlannerTabPresentationContext {
        PlannerTabPresentationContext(
            snapshot: store.snapshot,
            activePlannerAccountId: store.activePlannerAccountId,
            snapshotRevision: store.snapshotRevision,
            todayIso: store.todayIso,
            selectedPayPeriod: store.selectedPayPeriod,
            isLoading: store.isLoading
        )
    }

    private func navigationTitle(for tab: AppTab) -> String {
        AppNavigationTitlePolicy.title(for: tab, activeAccountName: activePlannerAccountName)
    }

    private var activePlannerAccountName: String? {
        store.activePlannerAccount?.name
            ?? store.plannerAccounts.first { $0.id == store.activePlannerAccountId }?.name
    }

    private func toolbarAction(for id: String) -> AppToolbarAction? {
        switch id {
        case "profile-menu-toolbar-action":
            AppToolbarAction(id: id, symbol: "person.fill", accessibilityLabel: "Open Profile") {}
        case "plan-calendar-toolbar-action":
            AppToolbarAction(id: id, symbol: "calendar", accessibilityLabel: "Open Planning Calendar") {
                activeNavigationDestination = .plan
            }
        case "spending-history-toolbar-action":
            AppToolbarAction(id: id, symbol: "receipt", accessibilityLabel: "Open Spending History") {
                activeSheet = .spendingHistory
            }
        case "activity-infinity-toolbar-action":
            AppToolbarAction(
                id: id,
                symbol: ActivityTimelineLayoutPolicy.toolbarSymbol,
                accessibilityLabel: "Timeline placeholder"
            ) {}
        case "pot-history-toolbar-action":
            AppToolbarAction(id: id, symbol: "clock.arrow.circlepath", accessibilityLabel: "Pots History") {
                activeSheet = .potHistory
            }
        case "add-menu-toolbar-action":
            AppToolbarAction(id: id, symbol: "plus", accessibilityLabel: "Open Add Menu") {
                openAddFlowForSelectedTab()
            }
        default:
            nil
        }
    }

    @ViewBuilder
    private func toolbarButton(for action: AppToolbarAction) -> some View {
        if action.id == "profile-menu-toolbar-action" {
            ProfileToolbarButton(action: action, store: store)
        } else {
            AppToolbarButton(action: action)
        }
    }

    @ViewBuilder
    private func navigationDestination(for destination: AppNavigationDestination) -> some View {
        switch destination {
        case .plan:
            PlanView(store: store, navigationMode: .inline, toolbarMode: .none)
        case .accounts:
            AccountsSheetView(store: store)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { newTab in
            selectTab(newTab)
        }
    }

    private func selectTab(_ tab: AppTab) {
        requestRootScrollReset(for: tab)
        selectedTab = tab
    }

    private func requestRootScrollReset(for tab: AppTab) {
        rootTabResetRevisions[tab, default: 0] += 1
    }

    private func rootTabResetRevision(for tab: AppTab) -> Int {
        rootTabResetRevisions[tab, default: 0]
    }

    private func warmRootTabPresentations(context: PlannerTabPresentationContext) async {
        guard !store.isLoading else { return }

        await Task.yield()

        for tab in AppTab.allCases where tab != .home {
            guard !Task.isCancelled else { return }

            switch tab {
            case .home:
                break
            case .bills:
                BillsView.warmPresentation(cache: tabPresentationCache, context: context)
            case .activity:
                ActivityView.warmPresentation(cache: tabPresentationCache, context: context)
            case .pots:
                PotsView.warmPresentation(cache: tabPresentationCache, context: context)
            case .credit:
                CreditView.warmPresentation(cache: tabPresentationCache, context: context)
            }

            await Task.yield()
        }
    }

    private func openAddFlowForSelectedTab() {
        if AppAddMenuPolicy.opensSingleActionDirectly,
           selectedTabAddActions.count == 1,
           let action = selectedTabAddActions.first {
            activeSheet = sheetDestination(for: action)
        } else {
            activeSheet = .addMenu
        }
    }

    private func sheetDestination(for action: AppAddAction) -> AppSheetDestination {
        switch action {
        case .spend: .addSpend
        case .bill: .addBill
        case .pot: .addPot
        case .card: .addCard
        }
    }

    private func presentPendingSheet() {
        guard let pendingSheetAfterDismiss else { return }
        self.pendingSheetAfterDismiss = nil
        activeSheet = pendingSheetAfterDismiss
    }

    private func configureSystemChromeAppearance() {
        configureNavigationBarAppearance()
        configureTabBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.appBackground)
        appearance.backgroundEffect = nil
        appearance.shadowColor = UIColor(AppTheme.Colors.divider)
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primaryText)]
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.primaryText)]

        let buttonAppearance = UIBarButtonItemAppearance()
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.accent)]
        buttonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.accentHighlight)]
        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppTheme.Colors.accent)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.Colors.surface)
        appearance.backgroundEffect = nil
        appearance.shadowColor = UIColor(AppTheme.Colors.divider)
        appearance.selectionIndicatorTintColor = UIColor(AppTheme.Colors.selectedFill)
        configureTabBarItemAppearance(appearance.stackedLayoutAppearance)
        configureTabBarItemAppearance(appearance.inlineLayoutAppearance)
        configureTabBarItemAppearance(appearance.compactInlineLayoutAppearance)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AppTheme.Colors.accent)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppTheme.Colors.tertiaryText)
    }

    private func configureTabBarItemAppearance(_ itemAppearance: UITabBarItemAppearance) {
        itemAppearance.selected.iconColor = UIColor(AppTheme.Colors.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.accent)]
        itemAppearance.normal.iconColor = UIColor(AppTheme.Colors.tertiaryText)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.Colors.tertiaryText)]
    }
}

private struct PremiumRootBackground: View {
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.defaultPreset.rawValue

    var body: some View {
        AppTheme.Colors.appBackground
        .id("root-background-\(selectedThemeRawValue)")
        .ignoresSafeArea()
    }
}

private struct ProfileToolbarButton: View {
    let action: AppToolbarAction
    @ObservedObject var store: PlannerStore

    var body: some View {
        NavigationLink {
            ProfileMenuScreenView(store: store)
        } label: {
            if let activeAccount {
                PlannerAccountAvatarCircle(
                    account: activeAccount,
                    image: store.plannerAccountAvatarImage(for: activeAccount),
                    size: 34
                )
            } else {
                fallbackAvatar
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(action.accessibilityLabel)
    }

    private var activeAccount: PlannerAccount? {
        store.activePlannerAccount
            ?? store.plannerAccounts.first { $0.id == store.activePlannerAccountId }
            ?? store.plannerAccounts.first
    }

    private var fallbackAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.elevatedSurface)
            Image(systemName: action.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryOrange)
        }
        .frame(width: 34, height: 34)
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.Colors.glowOrange.opacity(0.35), radius: 10, y: 4)
    }
}

private struct AddMenuSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var actions: [AppAddAction]
    var onSelect: (AppAddAction) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(actions) { action in
                        Button {
                            onSelect(action)
                        } label: {
                            AppCard {
                                HStack(spacing: AppTheme.Spacing.md) {
                                    Image(systemName: action.symbol)
                                        .foregroundStyle(AppTheme.Colors.primaryOrange)
                                        .frame(width: 40, height: 40)
                                        .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(action.title)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.Colors.primaryText)
                                        Text(action.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Colors.secondaryText)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.Colors.tertiaryText)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("add-menu-\(action.rawValue)")
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Add")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProfileMenuScreenView: View {
    @EnvironmentObject private var authSession: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    @State private var isLogOutConfirmationPresented = false
    @State private var isFirstResetConfirmationPresented = false
    @State private var isSecondResetConfirmationPresented = false

    var body: some View {
        ScreenScaffold(
            title: "Profile",
            subtitle: "",
            navigationMode: .inline,
            toolbarMode: .none
        ) {
            profileHeader
            actionsCard
            signOutCard
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AccountsSheetView(store: store)
                } label: {
                    Text(ProfileMenuPresentationPolicy.editActionTitle)
                }
            }
        }
        .alert("Log out?", isPresented: $isLogOutConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button(ProfileMenuPresentationPolicy.logOutActionTitle, role: .destructive) {
                Task {
                    await authSession.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to log out of this account?")
        }
        .alert("Reset all data?", isPresented: $isFirstResetConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                Task { @MainActor in
                    await Task.yield()
                    isSecondResetConfirmationPresented = true
                }
            }
        } message: {
            Text("This keeps your login account, but permanently deletes your money data from this iPhone and Firebase.")
        }
        .alert("Delete everything permanently?", isPresented: $isSecondResetConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button(ProfileMenuPresentationPolicy.resetDataActionTitle, role: .destructive) {
                Task {
                    await authSession.resetPlannerData(store: store)
                }
            }
        } message: {
            Text("This cannot be undone. Accounts, bills, pots, cards, debts, statements, activity, and planner history will be reset.")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 6) {
            profileAvatar

            Text(activeAccountName)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text("Active planner")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.sm)
    }

    private var profileAvatar: some View {
        Group {
            if let activeAccount {
                PlannerAccountAvatarCircle(
                    account: activeAccount,
                    image: store.plannerAccountAvatarImage(for: activeAccount),
                    size: 66
                )
            } else {
                fallbackProfileAvatar
            }
        }
        .accessibilityLabel("Profile image for \(activeAccountName)")
    }

    private var actionsCard: some View {
        CompactMenuCard {
            ForEach(Array(ProfileMenuAction.allCases.enumerated()), id: \.element.rawValue) { index, action in
                NavigationLink {
                    profileDestination(for: action)
                } label: {
                    ProfileMenuActionRow(action: action)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-menu-\(action.rawValue)")

                if index < ProfileMenuAction.allCases.count - 1 {
                    AppDivider()
                        .padding(.leading, 50)
                }
            }
        }
    }

    private var signOutCard: some View {
        CompactMenuCard {
            VStack(spacing: 0) {
                Button(role: .destructive) {
                    isLogOutConfirmationPresented = true
                } label: {
                    CompactMenuRow(
                        title: authSession.isWorking ? "Logging Out…" : ProfileMenuPresentationPolicy.logOutActionTitle,
                        systemImage: "rectangle.portrait.and.arrow.right",
                        isDestructive: true,
                        showsDisclosure: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(authSession.isWorking)
                .accessibilityIdentifier("profile-sign-out")

                AppDivider()
                    .padding(.leading, 50)

                Button(role: .destructive) {
                    isFirstResetConfirmationPresented = true
                } label: {
                    CompactMenuRow(
                        title: authSession.isWorking ? "Resetting Data…" : ProfileMenuPresentationPolicy.resetDataActionTitle,
                        systemImage: "trash",
                        isDestructive: true,
                        showsDisclosure: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(authSession.isWorking)
                .accessibilityIdentifier("profile-reset-data")
            }
        }
    }

    private var fallbackProfileAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Gradients.primary)
            Image(systemName: "person.fill")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.Colors.controlText)
        }
        .frame(width: 66, height: 66)
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.primaryText.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: AppTheme.Colors.glowOrange, radius: 18, y: 8)
    }

    private var activeAccount: PlannerAccount? {
        store.activePlannerAccount
            ?? store.plannerAccounts.first { $0.id == store.activePlannerAccountId }
            ?? store.plannerAccounts.first
    }

    private var activeAccountName: String {
        activeAccount?.name ?? "Planner account"
    }

    @ViewBuilder
    private func profileDestination(for action: ProfileMenuAction) -> some View {
        switch action {
        case .income:
            IncomeBreakdownView(store: store)
        case .accounts:
            BankAccountsView(store: store)
        case .statements:
            StatementsView(store: store, navigationMode: .inline, toolbarMode: .none)
        case .faq:
            FAQView()
        case .settings:
            SettingsView(store: store, navigationMode: .inline, toolbarMode: .none)
        }
    }
}

private struct ProfileMenuActionRow: View {
    var action: ProfileMenuAction

    var body: some View {
        CompactMenuRow(
            title: action.title,
            systemImage: action.symbol,
            tint: action.tint
        )
    }
}

#Preview {
    AppView()
}
