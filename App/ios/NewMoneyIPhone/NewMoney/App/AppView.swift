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

enum AppNavigationTitleDisplayStyle: Equatable {
    case large
    case inline
}

enum AppNavigationTitleDisplayPolicy {
    static func style(for tab: AppTab) -> AppNavigationTitleDisplayStyle {
        tab == .activity ? .inline : .large
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
    case addIncome
    case appearance
    case history
    case creditStatements

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addIncome: "Add Income"
        case .appearance: "Appearance"
        case .history: "History"
        case .creditStatements: "Credit Statements"
        }
    }

    var subtitle: String {
        switch self {
        case .addIncome: "Create income and payday setup."
        case .appearance: "Themes and colour presets."
        case .history: "Paycheck and allocation history."
        case .creditStatements: "Card statements and direct debit status."
        }
    }

    var symbol: String {
        switch self {
        case .addIncome: "sterlingsign.circle"
        case .appearance: "paintpalette"
        case .history: "clock.arrow.circlepath"
        case .creditStatements: "doc.text.magnifyingglass"
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
    static let includesAddIncomeAction = true
    static let opensAppearanceDirectly = true
    static let usesSystemFullScreenSafeArea = true
    static let usesInlineNavigationTitle = true
    static let showsProfileSubtitle = false
    static let editActionTitle = "Edit"
    static let editActionOpensAccounts = true
    static let animatesFromBottom = false
    static let avoidsSystemNavigationBar = false
}

private enum AppSheetDestination: String, Identifiable {
    case addMenu
    case addSpend
    case addBill
    case addPot
    case addCard
    case spendingHistory
    case calendar
    case accounts
    case potHistory

    var id: String { rawValue }
}

private enum AppNavigationDestination: String, Identifiable {
    case plan

    var id: String { rawValue }
}

struct AppView: View {
    @ObservedObject var store: PlannerStore
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.classic.rawValue
    @State private var selectedTab: AppTab = .home
    @State private var rootTabScrollState = RootTabScrollState.inactive
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
            case .accounts:
                AccountsSheetView(store: store)
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
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: selectedTabBinding) {
                tabNavigationRoot(for: .home) {
                    DashboardView(
                        store: store,
                        navigationMode: .tabRoot,
                        toolbarMode: .none,
                        onOpenAccount: { activeSheet = .accounts },
                        onViewPlan: { activeNavigationDestination = .plan },
                        onViewActivity: { selectTab(.activity) }
                    )
                }
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }
                .tag(AppTab.home)

                tabNavigationRoot(for: .bills) {
                    BillsView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                }
                .tabItem { Label(AppTab.bills.title, systemImage: AppTab.bills.symbol) }
                .tag(AppTab.bills)

                tabNavigationRoot(for: .activity) {
                    ActivityView(store: store)
                }
                .tabItem { Label(AppTab.activity.title, systemImage: AppTab.activity.symbol) }
                .tag(AppTab.activity)

                tabNavigationRoot(for: .pots) {
                    PotsView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                }
                .tabItem { Label(AppTab.pots.title, systemImage: AppTab.pots.symbol) }
                .tag(AppTab.pots)

                tabNavigationRoot(for: .credit) {
                    CreditView(store: store)
                }
                .tabItem { Label(AppTab.credit.title, systemImage: AppTab.credit.symbol) }
                .tag(AppTab.credit)
            }
            .environment(
                \.rootTabScrollState,
                rootTabScrollState
            )
            .id("tabs-\(selectedThemeRawValue)")
            .tint(AppTheme.Colors.primaryOrange)

            Button {
                isAssistantPresented = true
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.controlText)
                    .frame(width: 56, height: 56)
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
        rootTabScrollState = RootTabScrollState(
            selectedTitle: tab.title,
            revision: rootTabScrollState.revision + 1
        )
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
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.classic.rawValue

    var body: some View {
        ZStack {
            AppTheme.Colors.appBackground
            AppTheme.Gradients.screenBackground
        }
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

private struct ProfileMenuScreenView: View {
    @EnvironmentObject private var authSession: FirebaseAuthSession
    @ObservedObject var store: PlannerStore
    @State private var isAddIncomePresented = false
    @State private var isAccountsPresented = false
    @State private var isLogOutConfirmationPresented = false

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
                Button(ProfileMenuPresentationPolicy.editActionTitle) {
                    isAccountsPresented = true
                }
            }
        }
        .sheet(isPresented: $isAddIncomePresented) {
            AddPaycheckSheetView(store: store)
        }
        .sheet(isPresented: $isAccountsPresented) {
            AccountsSheetView(store: store)
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
    }

    private var profileHeader: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            profileAvatar

            Text(activeAccountName)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    private var profileAvatar: some View {
        Group {
            if let activeAccount {
                PlannerAccountAvatarCircle(
                    account: activeAccount,
                    image: store.plannerAccountAvatarImage(for: activeAccount),
                    size: 86
                )
            } else {
                fallbackProfileAvatar
            }
        }
        .accessibilityLabel("Profile image for \(activeAccountName)")
    }

    private var actionsCard: some View {
        AppCard {
            ForEach(Array(ProfileMenuAction.allCases.enumerated()), id: \.element.rawValue) { index, action in
                if action == .addIncome {
                    Button {
                        isAddIncomePresented = true
                    } label: {
                        ProfileMenuActionRow(action: action)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-menu-\(action.rawValue)")
                } else {
                    NavigationLink {
                        profileDestination(for: action)
                    } label: {
                        ProfileMenuActionRow(action: action)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile-menu-\(action.rawValue)")
                }

                if index < ProfileMenuAction.allCases.count - 1 {
                    AppDivider()
                }
            }
        }
    }

    private var signOutCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                SectionTitle("Account")
                SecondaryButton(
                    title: authSession.isWorking ? "Logging Out..." : ProfileMenuPresentationPolicy.logOutActionTitle,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    role: .destructive
                ) {
                    isLogOutConfirmationPresented = true
                }
                .disabled(authSession.isWorking)
                .accessibilityIdentifier("profile-sign-out")
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
        .frame(width: 86, height: 86)
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
        case .addIncome:
            EmptyView()
        case .appearance:
            AppearanceSettingsView(navigationMode: .inline, toolbarMode: .none)
        case .history:
            HistoryView(store: store)
        case .creditStatements:
            StatementsView(store: store, navigationMode: .inline, toolbarMode: .none)
        }
    }
}

private struct ProfileMenuActionRow: View {
    var action: ProfileMenuAction

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: action.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primaryOrange)
                .frame(width: 38, height: 38)
                .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                Text(action.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
    }
}

#Preview {
    AppView()
}
