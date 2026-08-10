import Charts
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AccountsLayoutSection: String, Equatable {
    case carousel
    case profileOverview
    case profilePulse
    case profilePills
}

enum AccountManagementPresentation: Equatable {
    case contextMenu
}

struct AccountsLayoutPolicy {
    static let sections: [AccountsLayoutSection] = [.carousel, .profileOverview, .profilePulse, .profilePills]
    static let createActionPlacement = "topBarTrailing"
    static let presentationStyle = "navigationDestination"
    static let createSheetDetent = "fractionHalf"
    static let createSheetShowsDividers = false
    static let showsNavigationDivider = false
    static let avatarPreviewShowsNavigationDivider = false
    static let managementPresentation: AccountManagementPresentation = .contextMenu
    static let showsBottomAccountList = false
    static let editMenuPresentation = "nativeSwiftUIMenu"
    static let avatarSourcePresentation = "nativeSwiftUIMenu"
    static let carouselInteraction = "nativeViewAlignedScroll"
    static let carouselUsesNativeSnapping = true
    static let carouselAllowsVerticalScrollPassthrough = true
    static let profileGraphMetric = "monthlySavedSpentActivity"
    static let profileGraphShowsMetricPills = false
    static let profileGraphUsesContinuousAnimation = false
    static let carouselUsesVerticalLift = false
    static var profilePulseCardCornerRadius: CGFloat { AppTheme.Radius.md }
}

struct AccountsSheetView: View {
    @ObservedObject var store: PlannerStore
    @State private var selectedAccountId: String?
    @State private var errorMessage: String?
    @State private var accountToDelete: PlannerAccount?
    @State private var accountNameInput: AccountNameInputMode?
    @State private var avatarTargetAccount: PlannerAccount?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatar: PendingAccountAvatar?
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isFileImporterPresented = false

    var body: some View {
        screenContent
            .onAppear(perform: syncSelectedAccount)
            .onChange(of: store.activePlannerAccountId) { _, newValue in
                selectedAccountId = newValue
            }
            .onChange(of: selectedAccountId) { _, newValue in
                switchToAccountIfNeeded(newValue)
            }
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, item in
                loadPhotoItem(item)
            }
            .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.image]) { result in
                loadAvatarFile(result)
            }
            .sheet(isPresented: $isCameraPresented) {
                AccountCameraImagePicker { image in
                    presentAvatarPreview(image, for: avatarTargetAccount)
                }
            }
            .sheet(item: $accountNameInput) { mode in
                AccountNameInputSheet(mode: mode) { name in
                    saveAccountName(name, for: mode)
                }
            }
            .sheet(item: $pendingAvatar) { avatar in
                AccountAvatarConfirmationView(
                    accountName: avatar.accountName,
                    image: avatar.image,
                    onCancel: {
                        pendingAvatar = nil
                    },
                    onConfirm: {
                        savePendingAvatar(avatar)
                    }
                )
            }
            .alert("Delete account?", isPresented: deleteConfirmationBinding, presenting: accountToDelete) { account in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount(account)
                }
            }
            .navigationTopDividerHidden()
    }

    private var screenContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AppTheme.Spacing.md) {
                if let errorMessage {
                    ErrorBanner(message: errorMessage) {
                        self.errorMessage = nil
                    }
                    .padding(.top, AppTheme.Spacing.md)
                }

                accountCarousel
                    .frame(maxWidth: .infinity)
                    .frame(height: 208)
                    .padding(.top, AppTheme.Spacing.sm)

                if let selectedAccountProfile {
                    AccountProfileDetailsView(profile: selectedAccountProfile)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .premiumScreenBackground()
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CreateAccountToolbarButton(isVisible: store.canCreatePlannerAccount) {
                    presentCreateAccountPrompt()
                }
            }
        }
    }

    private var accountCarousel: some View {
        AccountsCarouselView(
            accounts: carouselAccounts,
            selectedAccountId: activeCarouselAccountId,
            canUseCamera: UIImagePickerController.isSourceTypeAvailable(.camera),
            onSelect: selectAccount,
            onChoosePhoto: beginPhotoLibrarySelection(for:),
            onTakePhoto: beginCameraSelection(for:),
            onChooseFile: beginFileSelection(for:),
            onRename: presentRenamePrompt(for:),
            onRemovePhoto: removeAvatar(for:),
            onDelete: presentDeletePrompt(for:)
        )
    }

    private var carouselAccounts: [AccountCarouselDisplayItem] {
        store.plannerAccounts.map { account in
            AccountCarouselDisplayItem(
                account: account,
                avatarImage: store.plannerAccountAvatarImage(for: account)
            )
        }
    }

    private var activeCarouselAccountId: String? {
        selectedAccountId ?? store.activePlannerAccountId ?? store.plannerAccounts.first?.id
    }

    private var selectedAccountProfile: AccountProfileDisplayData? {
        guard let activeCarouselAccountId,
              let index = store.plannerAccounts.firstIndex(where: { $0.id == activeCarouselAccountId })
        else {
            return nil
        }

        let account = store.plannerAccounts[index]
        return AccountProfileDisplayData(
            account: account,
            accountIndex: index + 1,
            accountCount: store.plannerAccounts.count,
            canCreateMoreAccounts: store.canCreatePlannerAccount
        )
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

    private func syncSelectedAccount() {
        selectedAccountId = store.activePlannerAccountId ?? store.plannerAccounts.first?.id
    }

    private func selectAccount(_ accountId: String) {
        selectedAccountId = accountId
    }

    private func switchToAccountIfNeeded(_ accountId: String?) {
        guard let accountId, accountId != store.activePlannerAccountId else { return }
        runAccountAction {
            try await store.switchPlannerAccount(id: accountId)
        }
    }

    private func presentCreateAccountPrompt() {
        accountNameInput = .create
    }

    private func saveAccountName(_ name: String, for mode: AccountNameInputMode) {
        switch mode {
        case .create:
            runAccountAction {
                try await store.createPlannerAccount(named: name)
                await MainActor.run {
                    accountNameInput = nil
                    selectedAccountId = store.activePlannerAccountId
                }
            }
        case .rename(let account):
            runAccountAction {
                try await store.renamePlannerAccount(id: account.id, name: name)
                await MainActor.run {
                    accountNameInput = nil
                }
            }
        }
    }

    private func deleteAccount(_ account: PlannerAccount) {
        runAccountAction {
            try await store.deletePlannerAccount(id: account.id)
            await MainActor.run {
                selectedAccountId = store.activePlannerAccountId
            }
        }
    }

    private func presentRenamePrompt(for account: PlannerAccount) {
        accountNameInput = .rename(account)
    }

    private func presentDeletePrompt(for account: PlannerAccount) {
        accountToDelete = account
    }

    private func beginPhotoLibrarySelection(for account: PlannerAccount) {
        avatarTargetAccount = account
        selectedPhotoItem = nil
        Task { @MainActor in
            await Task.yield()
            isPhotoPickerPresented = true
        }
    }

    private func beginCameraSelection(for account: PlannerAccount) {
        avatarTargetAccount = account
        Task { @MainActor in
            await Task.yield()
            isCameraPresented = true
        }
    }

    private func beginFileSelection(for account: PlannerAccount) {
        avatarTargetAccount = account
        Task { @MainActor in
            await Task.yield()
            isFileImporterPresented = true
        }
    }

    private func removeAvatar(for account: PlannerAccount) {
        runAccountAction {
            try await store.removePlannerAccountAvatar(accountId: account.id)
        }
    }

    private func loadPhotoItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    await MainActor.run {
                        errorMessage = "That image could not be opened."
                        selectedPhotoItem = nil
                    }
                    return
                }
                await MainActor.run {
                    presentAvatarPreview(image, for: avatarTargetAccount)
                    selectedPhotoItem = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private func loadAvatarFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                errorMessage = "That image could not be opened."
                return
            }
            presentAvatarPreview(image, for: avatarTargetAccount)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentAvatarPreview(_ image: UIImage, for account: PlannerAccount?) {
        guard let account else { return }
        pendingAvatar = PendingAccountAvatar(
            accountId: account.id,
            accountName: account.name,
            image: store.preparedPlannerAccountAvatarImage(from: image)
        )
    }

    private func savePendingAvatar(_ avatar: PendingAccountAvatar) {
        runAccountAction {
            try await store.savePlannerAccountAvatar(accountId: avatar.accountId, image: avatar.image)
            await MainActor.run {
                pendingAvatar = nil
            }
        }
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

private struct CreateAccountToolbarButton: View {
    var isVisible: Bool
    var action: () -> Void

    var body: some View {
        if isVisible {
            Button(action: action) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Create account")
        }
    }
}

private enum AccountNameInputMode: Identifiable {
    case create
    case rename(PlannerAccount)

    var id: String {
        switch self {
        case .create:
            return "create"
        case .rename(let account):
            return "rename-\(account.id)"
        }
    }

    var title: String {
        switch self {
        case .create:
            return "Create account"
        case .rename:
            return "Rename account"
        }
    }

    var actionTitle: String {
        switch self {
        case .create:
            return "Create"
        case .rename:
            return "Save"
        }
    }

    var initialName: String {
        switch self {
        case .create:
            return ""
        case .rename(let account):
            return account.name
        }
    }
}

private struct AccountNameInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    var mode: AccountNameInputMode
    var onSave: (String) -> Void
    @State private var name: String

    init(mode: AccountNameInputMode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        _name = State(initialValue: mode.initialName)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                TextField("Account name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .stroke(AppTheme.Colors.border, lineWidth: 1)
                    )

                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.lg)
            .premiumScreenBackground()
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.actionTitle) {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
        .navigationTopDividerHidden()
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PendingAccountAvatar: Identifiable {
    let id = UUID()
    let accountId: String
    let accountName: String
    let image: UIImage
}

private struct AccountProfileDisplayData {
    let account: PlannerAccount
    let accountIndex: Int
    let accountCount: Int
    let canCreateMoreAccounts: Bool

    var positionLabel: String {
        "\(accountIndex)/\(PlannerAccountCollection.maxAccounts)"
    }

    var createdDateLabel: String {
        accountDateLabel(account.createdAt)
    }

    var createdShortDateLabel: String {
        accountDateLabel(account.createdAt, format: .short)
    }

    var manualReviewDateLabel: String {
        accountDateLabel(
            account.createdAt,
            format: .full,
            addingMonths: 6
        )
    }

    var manualReviewShortDateLabel: String {
        accountDateLabel(
            account.createdAt,
            format: .short,
            addingMonths: 6
        )
    }

    var accountSlotLabel: String {
        canCreateMoreAccounts ? "\(PlannerAccountCollection.maxAccounts - accountCount) spaces open" : "3 profiles live"
    }

    var chartMonthLabels: [String] {
        chartMonths.map { $0.label }
    }

    var monthlySavedPence: [Int] {
        let activePotIDs = Set(
            account.snapshot.pots
                .filter { !$0.archived && $0.deletedAt == nil }
                .map(\.id)
        )
        let payPeriodDates = account.snapshot.payPeriods.reduce(into: [String: String]()) { dates, period in
            dates[period.id] = period.payday
        }

        let allocationValues = chartMonths.map { month in
            account.snapshot.potAllocations
                .filter { allocation in
                    allocation.deletedAt == nil &&
                        activePotIDs.contains(allocation.potId) &&
                        monthKey(
                            allocation.transactionDate ??
                                payPeriodDates[allocation.payPeriodId] ??
                                allocation.createdAt
                        ) == month.key
                }
                .reduce(0) { $0 + max(0, $1.amountPence) }
        }

        guard allocationValues.allSatisfy({ $0 == 0 }) else {
            return allocationValues
        }

        return chartMonths.map { month in
            account.snapshot.transactions
                .filter {
                    $0.deletedAt == nil &&
                        $0.type == .allocation &&
                        monthKey($0.date) == month.key
                }
                .reduce(0) { $0 + max(0, abs($1.amountPence)) }
        }
    }

    var monthlySpentPence: [Int] {
        chartMonths.map { month in
            account.snapshot.transactions
                .filter {
                    $0.deletedAt == nil &&
                        $0.type == .spending &&
                        monthKey($0.date) == month.key
                }
                .reduce(0) { $0 + abs($1.amountPence) }
        }
    }

    var chartHasActivity: Bool {
        monthlySavedPence.contains(where: { $0 > 0 }) || monthlySpentPence.contains(where: { $0 > 0 })
    }

    var chartSavedTotalPence: Int {
        monthlySavedPence.reduce(0, +)
    }

    var chartSpentTotalPence: Int {
        monthlySpentPence.reduce(0, +)
    }

    private var chartMonths: [(key: String, label: String)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let today = FinanceEngine.parseDate(FinanceEngine.getAppTodayIso(settings: account.snapshot.settings))
        let components = calendar.dateComponents([.year, .month], from: today)

        guard let currentMonth = calendar.date(from: components) else {
            return []
        }

        return (-5...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: offset, to: currentMonth) else {
                return nil
            }

            return (
                key: String(FinanceEngine.toIsoDate(date).prefix(7)),
                label: date.formatted(.dateTime.month(.abbreviated))
            )
        }
    }

    private func monthKey(_ isoString: String) -> String {
        String(isoString.prefix(7))
    }

    private enum AccountDateFormat {
        case full
        case short
    }

    private func accountDateLabel(_ isoString: String, format: AccountDateFormat = .full, addingMonths months: Int = 0) -> String {
        let datePrefix = String(isoString.prefix(10))
        guard datePrefix.count == 10 else {
            return "Saved"
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let createdDate = FinanceEngine.parseDate(datePrefix)
        let displayDate = calendar.date(byAdding: .month, value: months, to: createdDate) ?? createdDate

        switch format {
        case .full:
            return displayDate.formatted(.dateTime.day().month(.abbreviated).year())
        case .short:
            return displayDate.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

private struct AccountProfileDetailsView: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            AccountProfileOverviewStrip(profile: profile)
            AccountProfilePulseCard(profile: profile)
            AccountProfilePillRail(profile: profile)
        }
    }
}

private struct AccountProfileOverviewStrip: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Active account")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.cardEyebrow)
                    .textCase(.uppercase)

                Text(profile.account.name)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Text(profile.positionLabel)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.Colors.controlText)
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(height: 34)
                .background(Color(hex: profile.account.color), in: Capsule())
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

private struct AccountProfilePulseCard: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saved vs spent")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)

                    Text(profile.chartHasActivity ? "Monthly account activity · last 6 months" : "Your six-month trend will build here")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer(minLength: AppTheme.Spacing.sm)
            }

            HStack(spacing: AppTheme.Spacing.lg) {
                AccountProfileGraphMetric(
                    label: "Put aside",
                    value: MoneyParser.formatPence(profile.chartSavedTotalPence),
                    color: AppTheme.Colors.neonMoneyUp
                )

                AccountProfileGraphMetric(
                    label: "Spent",
                    value: MoneyParser.formatPence(profile.chartSpentTotalPence),
                    color: AppTheme.Colors.neonMoneyDown
                )
            }

            AccountProfileLineGraph(profile: profile)
                .frame(height: 164)

            AccountProfileMiniTimeline(profile: profile)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: AccountsLayoutPolicy.profilePulseCardCornerRadius, style: .continuous))
        .background(
            LinearGradient(
                colors: [
                    Color(hex: profile.account.color).opacity(0.16),
                    AppTheme.Colors.cardBackground.opacity(0)
                ],
                startPoint: .topTrailing,
                endPoint: .center
            ),
            in: RoundedRectangle(cornerRadius: AccountsLayoutPolicy.profilePulseCardCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AccountsLayoutPolicy.profilePulseCardCornerRadius, style: .continuous)
                .stroke(AppTheme.Colors.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.Colors.shadow.opacity(0.8), radius: 18, y: 12)
    }
}

private struct AccountProfileLineGraph: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        let monthLabels = profile.chartMonthLabels
        let savedValues = profile.monthlySavedPence
        let spentValues = profile.monthlySpentPence

        Chart {
            ForEach(Array(monthLabels.indices), id: \.self) { index in
                AreaMark(
                    x: .value("Month", index),
                    yStart: .value("Baseline", 0),
                    yEnd: .value("Put aside", savedValues[index])
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.neonMoneyUp.opacity(0.2),
                            AppTheme.Colors.neonMoneyUp.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Month", index),
                    y: .value("Put aside", savedValues[index])
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.Colors.neonMoneyUp)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("Month", index),
                    y: .value("Spent", spentValues[index])
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.Colors.neonMoneyDown)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Month", index),
                    y: .value("Put aside", savedValues[index])
                )
                .foregroundStyle(AppTheme.Colors.neonMoneyUp)
                .symbolSize(index == monthLabels.indices.last ? 34 : 16)

                PointMark(
                    x: .value("Month", index),
                    y: .value("Spent", spentValues[index])
                )
                .foregroundStyle(AppTheme.Colors.neonMoneyDown)
                .symbolSize(index == monthLabels.indices.last ? 34 : 16)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...chartUpperBoundPence(savedValues: savedValues, spentValues: spentValues))
        .chartXAxis {
            AxisMarks(values: Array(monthLabels.indices)) { value in
                AxisTick(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(AppTheme.Colors.border.opacity(0.75))
                AxisValueLabel {
                    if let index = value.as(Int.self), monthLabels.indices.contains(index) {
                        Text(monthLabels[index])
                            .font(.caption2.weight(index == monthLabels.indices.last ? .bold : .medium))
                            .foregroundStyle(index == monthLabels.indices.last ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.75, dash: [3, 4]))
                    .foregroundStyle(AppTheme.Colors.border.opacity(0.45))
                AxisValueLabel {
                    if let amountPence = value.as(Int.self) {
                        Text(compactMoney(amountPence))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(AppTheme.Colors.elevatedSurface.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        }
        .accessibilityLabel("Money put aside and spent over the last six months")
        .accessibilityValue(
            "Put aside \(MoneyParser.formatPence(profile.chartSavedTotalPence)); spent \(MoneyParser.formatPence(profile.chartSpentTotalPence))"
        )
    }

    private func chartUpperBoundPence(savedValues: [Int], spentValues: [Int]) -> Int {
        let largestValue = max(
            savedValues.max() ?? 0,
            spentValues.max() ?? 0
        )
        return max(100, Int((Double(largestValue) * 1.18).rounded(.up)))
    }

    private func compactMoney(_ amountPence: Int) -> String {
        let pounds = Double(amountPence) / 100
        if pounds >= 1_000 {
            return String(format: "£%.1fk", pounds / 1_000)
        }
        return String(format: "£%.0f", pounds)
    }
}

private struct AccountProfileGraphMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.5), radius: 6, y: 2)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.tertiaryText)

            Text(value)
                .font(.caption.weight(.black))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AccountProfileMiniTimeline: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            AccountProfileTimelinePoint(title: "Created", value: profile.createdDateLabel, color: Color(hex: profile.account.color))

            Rectangle()
                .fill(AppTheme.Colors.border.opacity(0.72))
                .frame(height: 1)

            AccountProfileTimelinePoint(title: "Manual Review", value: profile.manualReviewDateLabel, color: AppTheme.Colors.success)
        }
    }
}

private struct AccountProfileTimelinePoint: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.55), radius: 8, y: 2)

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.tertiaryText)

                Text(value)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
        }
        .frame(width: 72)
    }
}

private struct AccountProfilePillRail: View {
    let profile: AccountProfileDisplayData

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: AppTheme.Spacing.sm),
                GridItem(.flexible(), spacing: AppTheme.Spacing.sm)
            ],
            spacing: AppTheme.Spacing.sm
        ) {
            AccountProfileStatusPill(title: "Active account", color: AppTheme.Colors.success)
            AccountProfileStatusPill(title: "Slot \(profile.positionLabel)", color: Color(hex: profile.account.color))
            AccountProfileStatusPill(title: "Review \(profile.manualReviewShortDateLabel)", color: AppTheme.Colors.primaryOrange)
            AccountProfileStatusPill(title: profile.accountSlotLabel, color: AppTheme.Colors.secondaryText)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, 2)
    }
}

private struct AccountProfileStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
    }
}

private struct AccountCarouselDisplayItem: Identifiable {
    let account: PlannerAccount
    let avatarImage: UIImage?

    var id: String {
        account.id
    }
}

private struct AccountsCarouselView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let accounts: [AccountCarouselDisplayItem]
    let selectedAccountId: String?
    let canUseCamera: Bool
    let onSelect: (String) -> Void
    let onChoosePhoto: (PlannerAccount) -> Void
    let onTakePhoto: (PlannerAccount) -> Void
    let onChooseFile: (PlannerAccount) -> Void
    let onRename: (PlannerAccount) -> Void
    let onRemovePhoto: (PlannerAccount) -> Void
    let onDelete: (PlannerAccount) -> Void
    @State private var visibleAccountId: String?

    var body: some View {
        let shouldReduceMotion = reduceMotion

        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: AppTheme.Spacing.lg) {
                    ForEach(accounts) { item in
                        AccountCarouselItem(
                            account: item.account,
                            avatarImage: item.avatarImage,
                            onSelect: {
                                onSelect(item.id)
                            },
                            canDelete: accounts.count > 1,
                            canUseCamera: canUseCamera,
                            canRemovePhoto: item.account.avatarImageName != nil,
                            onChoosePhoto: {
                                onChoosePhoto(item.account)
                            },
                            onTakePhoto: {
                                onTakePhoto(item.account)
                            },
                            onChooseFile: {
                                onChooseFile(item.account)
                            },
                            onRename: {
                                onRename(item.account)
                            },
                            onRemovePhoto: {
                                onRemovePhoto(item.account)
                            },
                            onDelete: {
                                onDelete(item.account)
                            }
                        )
                        .frame(width: 138)
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(shouldReduceMotion ? 1 : (phase.isIdentity ? 1.06 : 0.86))
                                .opacity(phase.isIdentity ? 1 : 0.5)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (proxy.size.width - 138) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $visibleAccountId, anchor: .center)
        }
        .onAppear {
            visibleAccountId = selectedAccountId ?? accounts.first?.id
        }
        .onChange(of: selectedAccountId) { _, newValue in
            guard visibleAccountId != newValue else { return }
            withAnimation(reduceMotion ? nil : .snappy) {
                visibleAccountId = newValue
            }
        }
        .onChange(of: visibleAccountId) { _, newValue in
            guard let newValue, newValue != selectedAccountId else { return }
            onSelect(newValue)
        }
    }
}

private struct AccountCarouselItem: View {
    var account: PlannerAccount
    var avatarImage: UIImage?
    var onSelect: () -> Void
    var canDelete: Bool
    var canUseCamera: Bool
    var canRemovePhoto: Bool
    var onChoosePhoto: () -> Void
    var onTakePhoto: () -> Void
    var onChooseFile: () -> Void
    var onRename: () -> Void
    var onRemovePhoto: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppTheme.Spacing.sm) {
                PlannerAccountAvatarCircle(
                    account: account,
                    image: avatarImage,
                    size: 78
                )

                Text(account.name)
                    .font(.headline.bold())
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
            .frame(minHeight: 132)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Select \(account.name)")
        .contextMenu {
            Menu {
                Button {
                    onRename()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Menu {
                    Button {
                        onChoosePhoto()
                    } label: {
                        Label("Choose photo", systemImage: "photo")
                    }

                    if canUseCamera {
                        Button {
                            onTakePhoto()
                        } label: {
                            Label("Take photo", systemImage: "camera")
                        }
                    }

                    Button {
                        onChooseFile()
                    } label: {
                        Label("Choose file", systemImage: "folder")
                    }

                    if canRemovePhoto {
                        Button(role: .destructive) {
                            onRemovePhoto()
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                } label: {
                    Label("Edit profile picture", systemImage: "person.crop.circle")
                }

                if canDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete account", systemImage: "trash")
                    }
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
}

struct PlannerAccountAvatarCircle: View {
    var account: PlannerAccount
    var image: UIImage?
    var size: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(AppTheme.Colors.elevatedSurface)

                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryOrange)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: AppTheme.Colors.glowOrange.opacity(0.35), radius: 12, y: 5)
    }
}

private struct AccountAvatarConfirmationView: View {
    var accountName: String
    var image: UIImage
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(AppTheme.Colors.selectedStroke, lineWidth: 1)
                    )
                    .shadow(color: AppTheme.Colors.accentGlow, radius: 24, y: 10)

                VStack(spacing: 8) {
                    Text(accountName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.primaryText)
                    Text("This is how the account photo will appear.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: AppTheme.Spacing.sm) {
                    PrimaryButton(title: "Use Photo", systemImage: "checkmark", action: onConfirm)
                    SecondaryButton(title: "Cancel", systemImage: "xmark", action: onCancel)
                }
            }
            .padding(AppTheme.Spacing.lg)
            .premiumScreenBackground()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

private struct AccountCameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImagePicked: (UIImage) -> Void
        var dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
