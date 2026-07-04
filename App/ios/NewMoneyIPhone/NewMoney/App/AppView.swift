import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case plan
    case activity
    case pots
    case credit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .plan: "Plan"
        case .activity: "Activity"
        case .pots: "Pots"
        case .credit: "Credit"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .plan: "calendar.badge.clock"
        case .activity: "list.bullet.rectangle.portrait"
        case .pots: "wallet.pass"
        case .credit: "creditcard.trianglebadge.exclamationmark"
        }
    }
}

enum AppAddAction: String, CaseIterable, Identifiable {
    case spend
    case income
    case bill
    case pot
    case card
    case cardPayment
    case debt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spend: "Add Spend"
        case .income: "Add Income"
        case .bill: "Add Bill"
        case .pot: "Add Pot"
        case .card: "Add Card"
        case .cardPayment: "Add Card Payment"
        case .debt: "Add Debt"
        }
    }

    var subtitle: String {
        switch self {
        case .spend: "Record manual spending."
        case .income: "Create income and payday setup."
        case .bill: "Add a recurring payment."
        case .pot: "Create a savings pot."
        case .card: "Add a credit card."
        case .cardPayment: "Record a credit-card repayment."
        case .debt: "Track a debt balance."
        }
    }

    var symbol: String {
        switch self {
        case .spend: "receipt"
        case .income: "sterlingsign.circle"
        case .bill: "calendar.badge.plus"
        case .pot: "wallet.pass"
        case .card: "creditcard"
        case .cardPayment: "creditcard.and.123"
        case .debt: "exclamationmark.shield"
        }
    }
}

enum AppToolbarPolicy {
    static func actionIds(for tab: AppTab) -> [String] {
        var actionIds: [String] = []

        switch tab {
        case .home, .plan, .activity, .credit:
            break
        case .pots:
            actionIds.append("pot-history-toolbar-action")
        }

        actionIds.append("add-menu-toolbar-action")
        return actionIds
    }
}

private enum AppSheetDestination: String, Identifiable {
    case addMenu
    case addSpend
    case addIncome
    case addBill
    case addPot
    case addCard
    case addDebt
    case spendingHistory
    case calendar
    case settings
    case accounts
    case potHistory
    case cardPayments

    var id: String { rawValue }
}

struct AppView: View {
    @ObservedObject var store: PlannerStore
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.classic.rawValue
    @State private var selectedTab: AppTab = .home
    @State private var isAssistantPresented = false
    @State private var activeSheet: AppSheetDestination?
    @State private var pendingSheetAfterDismiss: AppSheetDestination?

    init(store: PlannerStore = PlannerStore()) {
        self.store = store
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            NavigationStack {
                TabView(selection: selectedTabBinding) {
                    DashboardView(
                        store: store,
                        navigationMode: .tabRoot,
                        toolbarMode: .none,
                        onOpenAccount: { activeSheet = .accounts },
                        onViewPlan: { selectedTab = .plan },
                        onViewActivity: { selectedTab = .activity }
                    )
                        .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.symbol) }
                        .tag(AppTab.home)

                    PlanView(store: store)
                        .tabItem { Label(AppTab.plan.title, systemImage: AppTab.plan.symbol) }
                        .tag(AppTab.plan)

                    ActivityView(store: store)
                        .tabItem { Label(AppTab.activity.title, systemImage: AppTab.activity.symbol) }
                        .tag(AppTab.activity)

                    PotsView(store: store, navigationMode: .tabRoot, toolbarMode: .none)
                        .tabItem { Label(AppTab.pots.title, systemImage: AppTab.pots.symbol) }
                        .tag(AppTab.pots)

                    CreditView(store: store)
                        .tabItem { Label(AppTab.credit.title, systemImage: AppTab.credit.symbol) }
                        .tag(AppTab.credit)
                }
                .tint(AppTheme.Colors.primaryOrange)
                .navigationTitle(selectedTab.title)
                .navigationBarTitleDisplayMode(.large)
                .toolbarColorScheme(selectedTheme.palette.preferredColorScheme, for: .navigationBar)
                .toolbar {
                    rootTabToolbarContent
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
            .padding(.trailing, AppTheme.Spacing.sm)
            .padding(.bottom, 58)
            .accessibilityLabel("Open Assistant")
        }
        .background(AppTheme.Colors.appBackground)
        .dismissKeyboardOnBackgroundTap()
        .preferredColorScheme(selectedTheme.palette.preferredColorScheme)
        .sheet(item: $activeSheet, onDismiss: presentPendingSheet) { sheet in
            switch sheet {
            case .addMenu:
                AddMenuSheetView { action in
                    pendingSheetAfterDismiss = sheetDestination(for: action)
                    activeSheet = nil
                }
            case .addSpend:
                SpendingSheetView(store: store)
            case .addIncome:
                AddPaycheckSheetView(store: store)
            case .addBill:
                AddBillSheetView(store: store)
            case .addPot:
                PotFormView(store: store)
            case .addCard:
                CardFormView(store: store)
            case .addDebt:
                AddDebtSheetView(store: store)
            case .spendingHistory:
                SpendingHistorySheetView(store: store)
            case .calendar:
                CalendarSheetView(store: store)
            case .settings:
                SettingsSheetView(store: store)
            case .accounts:
                AccountsSheetView(store: store)
            case .potHistory:
                PotHistorySheetView(store: store)
            case .cardPayments:
                CardPaymentFlowSheetView(store: store)
            }
        }
        .sheet(isPresented: $isAssistantPresented) {
            AssistantView(store: store, presentationMode: .modal)
        }
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: selectedThemeRawValue) { _, _ in
            configureTabBarAppearance()
        }
    }

    @ToolbarContentBuilder
    private var rootTabToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            ForEach(selectedTabToolbarActions) { action in
                AppToolbarButton(action: action)
            }
        }
    }

    private var selectedTabToolbarActions: [AppToolbarAction] {
        AppToolbarPolicy.actionIds(for: selectedTab).compactMap(toolbarAction)
    }

    private var selectedTheme: AppThemePreset {
        AppThemePreset.resolved(from: selectedThemeRawValue)
    }

    private func toolbarAction(for id: String) -> AppToolbarAction? {
        switch id {
        case "settings-toolbar-action":
            AppToolbarAction(id: id, symbol: "gearshape", accessibilityLabel: "Open Settings") {
                activeSheet = .settings
            }
        case "spending-history-toolbar-action":
            AppToolbarAction(id: id, symbol: "receipt", accessibilityLabel: "Open Spending History") {
                activeSheet = .spendingHistory
            }
        case "pot-history-toolbar-action":
            AppToolbarAction(id: id, symbol: "clock.arrow.circlepath", accessibilityLabel: "Pots History") {
                activeSheet = .potHistory
            }
        case "add-menu-toolbar-action":
            AppToolbarAction(id: id, symbol: "plus", accessibilityLabel: "Open Add Menu") {
                activeSheet = .addMenu
            }
        default:
            nil
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

    private func sheetDestination(for action: AppAddAction) -> AppSheetDestination {
        switch action {
        case .spend: .addSpend
        case .income: .addIncome
        case .bill: .addBill
        case .pot: .addPot
        case .card: .addCard
        case .cardPayment: .cardPayments
        case .debt: .addDebt
        }
    }

    private func presentPendingSheet() {
        guard let pendingSheetAfterDismiss else { return }
        self.pendingSheetAfterDismiss = nil
        activeSheet = pendingSheetAfterDismiss
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

private struct AddMenuSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (AppAddAction) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    ForEach(AppAddAction.allCases) { action in
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
    }
}

private struct AccountsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PlannerStore
    @State private var newAccountName = ""
    @State private var errorMessage: String?
    @State private var accountToDelete: PlannerAccount?
    @State private var accountToRename: PlannerAccount?
    @State private var renameName = ""
    @State private var isRenamePresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    headerCard

                    if let errorMessage {
                        ErrorBanner(message: errorMessage) {
                            self.errorMessage = nil
                        }
                    }

                    createAccountCard

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        SectionTitle("Your accounts")
                        ForEach(store.plannerAccounts) { account in
                            accountRow(account)
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .premiumScreenBackground()
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .appPlaceholderToolbar(.modalSingle)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Rename account", isPresented: $isRenamePresented) {
            TextField("Account name", text: $renameName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                guard let accountToRename else { return }
                runAccountAction {
                    try await store.renamePlannerAccount(id: accountToRename.id, name: renameName)
                }
            }
        } message: {
            Text("Give this planner account a short, clear name.")
        }
        .alert("Delete account?", isPresented: deleteConfirmationBinding, presenting: accountToDelete) { account in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                runAccountAction {
                    try await store.deletePlannerAccount(id: account.id)
                }
            }
        } message: { account in
            Text("This removes \(account.name) and all planner data stored inside it on this iPhone.")
        }
    }

    private var headerCard: some View {
        AppCard(glow: true) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Gradients.primary)
                    Image(systemName: "person.2.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Planner accounts")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("Keep separate money setups for different parts of life.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Pill(
                    text: "\(store.plannerAccounts.count)/\(PlannerAccountCollection.maxAccounts)",
                    systemImage: nil,
                    color: store.canCreatePlannerAccount ? AppTheme.Colors.primaryOrange : AppTheme.Colors.tertiaryText
                )
            }
        }
    }

    private var createAccountCard: some View {
        AppCard {
            SectionTitle("Create account")
            TextField("Account name", text: $newAccountName)
                .textFieldStyle(AppTextFieldStyle())
                .textInputAutocapitalization(.words)
                .disabled(!store.canCreatePlannerAccount)

            PrimaryButton(
                title: store.canCreatePlannerAccount ? "Create account" : "Account limit reached",
                systemImage: store.canCreatePlannerAccount ? "plus" : "lock",
                isDisabled: newAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.canCreatePlannerAccount
            ) {
                let name = newAccountName
                runAccountAction {
                    try await store.createPlannerAccount(named: name)
                    await MainActor.run {
                        newAccountName = ""
                    }
                }
            }
        }
    }

    private func accountRow(_ account: PlannerAccount) -> some View {
        let isActive = account.id == store.activePlannerAccountId

        return AppCard(glow: isActive) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Circle()
                    .fill(Color(hex: account.color))
                    .frame(width: 13, height: 13)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Text(account.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                            .lineLimit(1)

                        if isActive {
                            Pill(text: "Active", systemImage: "checkmark", color: AppTheme.Colors.success)
                        }
                    }

                    Text(accountSummary(account))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: AppTheme.Spacing.sm)
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                if isActive {
                    Text("Open now")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.success)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                        .background(AppTheme.Colors.success.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Button {
                        runAccountAction {
                            try await store.switchPlannerAccount(id: account.id)
                        }
                    } label: {
                        Label("Use", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.primaryOrange)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 34)
                            .background(AppTheme.Colors.primaryOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Button {
                    accountToRename = account
                    renameName = account.name
                    isRenamePresented = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                        .frame(width: 42, height: 34)
                        .background(AppTheme.Colors.elevatedSurface)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Rename \(account.name)")

                Button {
                    accountToDelete = account
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.plannerAccounts.count > 1 ? AppTheme.Colors.danger : AppTheme.Colors.tertiaryText)
                        .frame(width: 42, height: 34)
                        .background(AppTheme.Colors.elevatedSurface)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(store.plannerAccounts.count <= 1)
                .accessibilityLabel("Delete \(account.name)")
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            accountToDelete != nil
        } set: { isPresented in
            if !isPresented {
                accountToDelete = nil
            }
        }
    }

    private func accountSummary(_ account: PlannerAccount) -> String {
        let snapshot = account.snapshot
        let potCount = snapshot.pots.filter { !$0.archived }.count
        let cardCount = snapshot.creditCards.filter { !$0.archived }.count
        let debtCount = snapshot.debts.filter { $0.status.isActiveLike }.count
        let billCount = snapshot.recurringPayments.filter(\.active).count
        let activityCount = snapshot.transactions.count

        var parts: [String] = []
        if potCount > 0 { parts.append("\(potCount) pot\(potCount == 1 ? "" : "s")") }
        if billCount > 0 { parts.append("\(billCount) bill\(billCount == 1 ? "" : "s")") }
        if cardCount > 0 { parts.append("\(cardCount) card\(cardCount == 1 ? "" : "s")") }
        if debtCount > 0 { parts.append("\(debtCount) debt\(debtCount == 1 ? "" : "s")") }
        if activityCount > 0 { parts.append("\(activityCount) activity") }

        return parts.isEmpty ? "No planner data yet" : parts.joined(separator: " · ")
    }

    private func runAccountAction(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                errorMessage = nil
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

#Preview {
    AppView()
}
