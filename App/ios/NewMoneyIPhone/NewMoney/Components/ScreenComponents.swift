import SwiftUI

enum AppEditDoneToolbarPolicy {
    static let editToolbarActionId = "edit-toolbar-action"
    static let editTitle = "Edit"
    static let doneTitle = "Done"
    static let usesNativeToolbarContentSwap = true
    static let springResponse = 0.28
    static let springDampingFraction = 0.86
}

let appToolbarMorphAnimation = Animation.spring(
    response: AppEditDoneToolbarPolicy.springResponse,
    dampingFraction: AppEditDoneToolbarPolicy.springDampingFraction
)

struct AppToolbarAction: Identifiable {
    let id: String
    let symbol: String
    var title: String? = nil
    let accessibilityLabel: String
    let action: () -> Void

    static func edit(action: @escaping () -> Void = {}) -> AppToolbarAction {
        AppToolbarAction(
            id: AppEditDoneToolbarPolicy.editToolbarActionId,
            symbol: "pencil",
            title: AppEditDoneToolbarPolicy.editTitle,
            accessibilityLabel: AppEditDoneToolbarPolicy.editTitle,
            action: action
        )
    }
}

struct AppToolbarButton: View {
    let action: AppToolbarAction

    var body: some View {
        Button(action: action.action) {
            if let title = action.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            } else {
                Image(systemName: action.symbol)
            }
        }
        .foregroundStyle(AppTheme.Colors.accent)
        .tint(AppTheme.Colors.accent)
        .accessibilityLabel(action.accessibilityLabel)
    }
}

struct AppEditDoneToolbarButton: View {
    var isEditing: Bool
    let action: () -> Void

    var body: some View {
        if isEditing {
            AppDoneToolbarBranchButton(action: action)
        } else {
            AppEditToolbarBranchButton(action: action)
        }
    }
}

private struct AppEditToolbarBranchButton: View {
    let action: () -> Void

    var body: some View {
        Button(AppEditDoneToolbarPolicy.editTitle, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .accessibilityLabel(AppEditDoneToolbarPolicy.editTitle)
    }
}

private struct AppDoneToolbarBranchButton: View {
    let action: () -> Void

    var body: some View {
        Button(AppEditDoneToolbarPolicy.doneTitle, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.accent)
            .accessibilityLabel(AppEditDoneToolbarPolicy.doneTitle)
    }
}

enum AppToolbarMode {
    case none
    case primaryDouble
    case secondarySingle
    case modalSingle
    case add(action: () -> Void)
    case editDone(isEditing: Bool, action: () -> Void)
    case actions([AppToolbarAction])
}

enum ScreenNavigationMode {
    case root
    case inline
    case tabRoot
}

struct RootTabScrollState: Equatable {
    var selectedTitle: String
    var revision: Int

    static let inactive = RootTabScrollState(selectedTitle: "", revision: 0)
}

enum RootTabScrollPolicy {
    static let topAnchorID = "root-tab-scroll-top"
    static let resetsTabRootOnSelection = true
    static let disablesSelectionScrollAnimation = true
    static let rebuildsSelectedTabScrollViewOnSelection = false
    static let keepsInactiveTabIdentityStableDuringSwitch = true
    static let usesScrollReaderForTabReset = true
    static let updatesResetTargetBeforeSelectedTab = true
    static let preventsPreviousTabResetDuringSwitch = true
}

private struct RootTabScrollStateKey: EnvironmentKey {
    static let defaultValue = RootTabScrollState.inactive
}

extension EnvironmentValues {
    var rootTabScrollState: RootTabScrollState {
        get { self[RootTabScrollStateKey.self] }
        set { self[RootTabScrollStateKey.self] = newValue }
    }
}

struct ScreenScaffold<Content: View>: View {
    @Environment(\.rootTabScrollState) private var rootTabScrollState
    @AppStorage(AppTheme.selectedPresetStorageKey) private var selectedThemeRawValue = AppThemePreset.classic.rawValue
    var title: String
    var subtitle: String
    var navigationMode: ScreenNavigationMode = .root
    var toolbarMode: AppToolbarMode = .primaryDouble
    var titleDisplayMode: NavigationBarItem.TitleDisplayMode = .large
    @ViewBuilder var content: Content

    @ViewBuilder
    var body: some View {
        switch navigationMode {
        case .root:
            NavigationStack {
                screenContentWithNavigation
            }
        case .inline:
            screenContentWithNavigation
        case .tabRoot:
            screenContent
        }
    }

    private var screenContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(RootTabScrollPolicy.topAnchorID)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if navigationMode != .tabRoot {
                        ScreenHeader(subtitle: subtitle)
                    }
                    content
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.sm)
                .padding(.bottom, 110)
            }
            .premiumScreenBackground()
            .id(screenContentIdentity)
            .onAppear {
                resetTabRootScrollIfNeeded(proxy)
            }
            .onChange(of: rootTabScrollState) { _, _ in
                resetTabRootScrollIfNeeded(proxy)
            }
        }
    }

    private var screenContentWithNavigation: some View {
        screenContent
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(titleDisplayMode)
        .toolbarColorScheme(AppTheme.selectedColorScheme, for: .navigationBar)
        .appPlaceholderToolbar(toolbarMode)
        .id("screen-\(selectedThemeRawValue)-\(title)")
    }

    private var screenContentIdentity: String {
        let baseIdentity = "screen-content-\(selectedThemeRawValue)-\(title)"
        guard RootTabScrollPolicy.rebuildsSelectedTabScrollViewOnSelection else {
            return baseIdentity
        }

        guard navigationMode == .tabRoot,
              rootTabScrollState.selectedTitle == title else {
            return baseIdentity
        }

        return "\(baseIdentity)-selected-\(rootTabScrollState.revision)"
    }

    private func resetTabRootScrollIfNeeded(_ proxy: ScrollViewProxy) {
        guard RootTabScrollPolicy.resetsTabRootOnSelection,
              navigationMode == .tabRoot,
              rootTabScrollState.selectedTitle == title else {
            return
        }

        if RootTabScrollPolicy.disablesSelectionScrollAnimation {
            withAnimation(nil) {
                proxy.scrollTo(RootTabScrollPolicy.topAnchorID, anchor: .top)
            }
        } else {
            proxy.scrollTo(RootTabScrollPolicy.topAnchorID, anchor: .top)
        }
    }
}

private struct PlaceholderToolbarModifier: ViewModifier {
    var mode: AppToolbarMode

    func body(content: Content) -> some View {
        switch mode {
        case .none:
            content
        case .editDone(let isEditing, let action):
            content.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AppEditDoneToolbarButton(isEditing: isEditing, action: action)
                }
            }
        default:
            content.toolbar {
                if let secondaryAction {
                    ToolbarItem(id: secondaryAction.id, placement: .topBarTrailing) {
                        toolbarButton(secondaryAction)
                    }
                }
                if let primaryAction {
                    ToolbarItem(id: primaryAction.id, placement: .topBarTrailing) {
                        toolbarButton(primaryAction)
                    }
                }
            }
        }
    }

    private var primaryAction: AppToolbarAction? {
        actions.last
    }

    private var secondaryAction: AppToolbarAction? {
        actions.count > 1 ? actions.first : nil
    }

    private var actions: [AppToolbarAction] {
        switch mode {
        case .none:
            []
        case .primaryDouble:
            [
                AppToolbarAction(id: "placeholder-options", symbol: "slider.horizontal.3", accessibilityLabel: "Placeholder options") {},
                AppToolbarAction(id: "placeholder-action", symbol: "ellipsis.circle", accessibilityLabel: "Placeholder action") {}
            ]
        case .secondarySingle, .modalSingle:
            [
                AppToolbarAction(id: "placeholder-action", symbol: "ellipsis.circle", accessibilityLabel: "Placeholder action") {}
            ]
        case .add(let action):
            [
                AppToolbarAction(id: "add", symbol: "plus", accessibilityLabel: "Add", action: action)
            ]
        case .editDone:
            []
        case .actions(let actions):
            actions
        }
    }

    private func toolbarButton(_ action: AppToolbarAction) -> some View {
        AppToolbarButton(action: action)
    }
}

extension View {
    func appPlaceholderToolbar(_ mode: AppToolbarMode) -> some View {
        modifier(PlaceholderToolbarModifier(mode: mode))
    }
}

struct ScreenHeader: View {
    var subtitle: String

    var body: some View {
        if subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionTitle: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
            }
        }
    }
}

struct MetricRow: View {
    var label: String
    var value: String
    var valueColor: Color = AppTheme.Colors.primaryText

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct Pill: View {
    var text: String
    var systemImage: String?
    var color: Color = AppTheme.Colors.primaryOrange

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.Colors.divider)
            .frame(height: 1)
    }
}

struct AddButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.controlText)
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(minHeight: 38)
                .background(AppTheme.Gradients.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

extension Date {
    var isoDateString: String {
        FinanceEngine.toIsoDate(self)
    }
}

extension String {
    var isoDate: Date {
        FinanceEngine.parseDate(self)
    }
}
