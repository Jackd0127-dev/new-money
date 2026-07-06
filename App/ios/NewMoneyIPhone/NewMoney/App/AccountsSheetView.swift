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
    static let presentationDetent = "large"
    static let showsNavigationDivider = false
    static let avatarPreviewShowsNavigationDivider = false
    static let managementPresentation: AccountManagementPresentation = .contextMenu
    static let showsBottomAccountList = false
    static var carouselSnapThreshold: CGFloat { 0.12 }
    static var carouselMinimumDragDistance: CGFloat { 6 }
    static var carouselMinimumSwipeDistance: CGFloat { 16 }
    static var carouselMaximumSwipeDistance: CGFloat { 32 }
    static var carouselVerticalToleranceRatio: CGFloat { 0.55 }
    static let editMenuPresentation = "nativeSwiftUIMenu"
    static let avatarSourcePresentation = "nativeSwiftUIMenu"
    static let carouselInteraction = "directionalSwipeAutoAdvance"
    static let profileGraphMetric = "savedSpentTotals"
}

struct AccountsSheetView: View {
    @Environment(\.dismiss) private var dismiss
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
        navigationContent
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
    }

    private var navigationContent: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.md) {
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    CreateAccountToolbarButton(isVisible: store.canCreatePlannerAccount) {
                        presentCreateAccountPrompt()
                    }
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
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selectedAccountId = accountId
        }
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
        DispatchQueue.main.async {
            isPhotoPickerPresented = true
        }
    }

    private func beginCameraSelection(for account: PlannerAccount) {
        avatarTargetAccount = account
        DispatchQueue.main.async {
            isCameraPresented = true
        }
    }

    private func beginFileSelection(for account: PlannerAccount) {
        avatarTargetAccount = account
        DispatchQueue.main.async {
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
        .presentationDetents([.height(220)])
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

    var savedTotalPence: Int {
        account.snapshot.pots
            .filter { !$0.archived && $0.deletedAt == nil }
            .reduce(0) { total, pot in
                total + max(0, pot.balancePence)
            }
    }

    var spentTotalPence: Int {
        account.snapshot.transactions
            .filter { $0.deletedAt == nil && $0.type == .spending }
            .reduce(0) { total, transaction in
                total + abs(transaction.amountPence)
            }
    }

    var hasSavedOrSpentTotal: Bool {
        savedTotalPence > 0 || spentTotalPence > 0
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

                    Text(profile.hasSavedOrSpentTotal ? "This account's live totals" : "Created \(profile.createdDateLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                }

                Spacer(minLength: AppTheme.Spacing.sm)
            }

            AccountProfileLineGraph(profile: profile)
                .frame(height: 112)

            AccountProfileMiniTimeline(profile: profile)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(
            LinearGradient(
                colors: [
                    Color(hex: profile.account.color).opacity(0.16),
                    AppTheme.Colors.cardBackground.opacity(0)
                ],
                startPoint: .topTrailing,
                endPoint: .center
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.Colors.border.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: AppTheme.Colors.shadow.opacity(0.8), radius: 18, y: 12)
    }
}

private struct AccountProfileLineGraph: View {
    let profile: AccountProfileDisplayData
    @State private var drawProgress: CGFloat = 0

    private var savedValues: [Double] {
        normalizedValues(for: profile.savedTotalPence)
    }

    private var spentValues: [Double] {
        normalizedValues(for: profile.spentTotalPence)
    }

    private var dominantValues: [Double] {
        profile.savedTotalPence >= profile.spentTotalPence ? savedValues : spentValues
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            GeometryReader { proxy in
                let size = proxy.size
                let savedEndPoint = linePoint(for: savedValues.count - 1, value: savedValues.last ?? 0, values: savedValues, size: size)
                let spentEndPoint = linePoint(for: spentValues.count - 1, value: spentValues.last ?? 0, values: spentValues, size: size)

                ZStack {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            AppTheme.Colors.border.opacity(0.32)
                                .frame(height: 1)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)

                    if profile.hasSavedOrSpentTotal {
                        AccountProfileLineAreaShape(values: dominantValues)
                            .trim(from: 0, to: drawProgress)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        dominantColor.opacity(0.18),
                                        dominantColor.opacity(0.08),
                                        AppTheme.Colors.cardBackground.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    AccountProfileLineShape(values: savedValues)
                        .trim(from: 0, to: drawProgress)
                        .stroke(
                            AppTheme.Colors.neonMoneyUp,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: profile.savedTotalPence > 0 ? AppTheme.Colors.neonMoneyUp.opacity(0.34) : .clear, radius: 10, y: 5)

                    AccountProfileLineShape(values: spentValues)
                        .trim(from: 0, to: drawProgress)
                        .stroke(
                            AppTheme.Colors.neonMoneyDown,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: profile.spentTotalPence > 0 ? AppTheme.Colors.neonMoneyDown.opacity(0.34) : .clear, radius: 10, y: 5)

                    if drawProgress > 0.96 {
                        if profile.savedTotalPence > 0 {
                            AccountProfilePulseMarker(color: AppTheme.Colors.neonMoneyUp)
                                .position(savedEndPoint)
                        }
                        if profile.spentTotalPence > 0 {
                            AccountProfilePulseMarker(color: AppTheme.Colors.neonMoneyDown)
                                .position(spentEndPoint)
                        }
                    }
                }
            }

            HStack(spacing: AppTheme.Spacing.sm) {
                AccountProfileGraphMetric(label: "Saved", value: MoneyParser.formatPence(profile.savedTotalPence), color: AppTheme.Colors.neonMoneyUp)
                AccountProfileGraphMetric(label: "Spent", value: MoneyParser.formatPence(profile.spentTotalPence), color: AppTheme.Colors.neonMoneyDown)
            }
        }
        .onAppear {
            drawProgress = 0

            withAnimation(.easeOut(duration: 1.05).delay(0.08)) {
                drawProgress = 1
            }
        }
    }

    private var dominantColor: Color {
        profile.savedTotalPence >= profile.spentTotalPence ? AppTheme.Colors.neonMoneyUp : AppTheme.Colors.neonMoneyDown
    }

    private func normalizedValues(for amountPence: Int) -> [Double] {
        let maxPence = max(profile.savedTotalPence, profile.spentTotalPence, 1)
        let ratio = Double(amountPence) / Double(maxPence)
        return [0, 0.18, 0.38, 0.62, 0.82, 1].map { progress in
            min(1, max(0, ratio * progress))
        }
    }

    private func linePoint(for index: Int, value: Double, values: [Double], size: CGSize) -> CGPoint {
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 12
        let usableWidth = max(size.width - (horizontalPadding * 2), 1)
        let usableHeight = max(size.height - (verticalPadding * 2), 1)
        let denominator = max(values.count - 1, 1)
        let x = horizontalPadding + (CGFloat(index) / CGFloat(denominator) * usableWidth)
        let y = verticalPadding + ((1 - CGFloat(value)) * usableHeight)
        return CGPoint(x: x, y: y)
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
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AccountProfileLineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard let firstValue = values.first else {
            return Path()
        }

        let points = chartPoints(in: rect)
        var path = Path()
        path.move(to: points.first ?? CGPoint(x: rect.minX, y: rect.midY))

        for index in points.indices.dropFirst() {
            let previous = points[index - 1]
            let current = points[index]
            let controlX = previous.x + ((current.x - previous.x) * 0.5)
            path.addCurve(
                to: current,
                control1: CGPoint(x: controlX, y: previous.y),
                control2: CGPoint(x: controlX, y: current.y)
            )
        }

        if values.count == 1 {
            path.addLine(to: CGPoint(x: rect.maxX, y: yPosition(for: firstValue, in: rect)))
        }

        return path
    }

    private func chartPoints(in rect: CGRect) -> [CGPoint] {
        let horizontalPadding: CGFloat = 24
        let usableWidth = max(rect.width - (horizontalPadding * 2), 1)
        let denominator = max(values.count - 1, 1)

        return values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + horizontalPadding + (CGFloat(index) / CGFloat(denominator) * usableWidth),
                y: yPosition(for: value, in: rect)
            )
        }
    }

    private func yPosition(for value: Double, in rect: CGRect) -> CGFloat {
        let verticalPadding: CGFloat = 12
        let usableHeight = max(rect.height - (verticalPadding * 2), 1)
        return rect.minY + verticalPadding + ((1 - CGFloat(value)) * usableHeight)
    }
}

private struct AccountProfileLineAreaShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        let points = chartPoints(in: rect)
        guard let first = points.first, let last = points.last else {
            return Path()
        }

        var path = Path()
        path.move(to: CGPoint(x: first.x, y: rect.maxY - 10))
        path.addLine(to: first)

        for index in points.indices.dropFirst() {
            let previous = points[index - 1]
            let current = points[index]
            let controlX = previous.x + ((current.x - previous.x) * 0.5)
            path.addCurve(
                to: current,
                control1: CGPoint(x: controlX, y: previous.y),
                control2: CGPoint(x: controlX, y: current.y)
            )
        }

        path.addLine(to: CGPoint(x: last.x, y: rect.maxY - 10))
        path.closeSubpath()
        return path
    }

    private func chartPoints(in rect: CGRect) -> [CGPoint] {
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 12
        let usableWidth = max(rect.width - (horizontalPadding * 2), 1)
        let usableHeight = max(rect.height - (verticalPadding * 2), 1)
        let denominator = max(values.count - 1, 1)

        return values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + horizontalPadding + (CGFloat(index) / CGFloat(denominator) * usableWidth),
                y: rect.minY + verticalPadding + ((1 - CGFloat(value)) * usableHeight)
            )
        }
    }
}

private struct AccountProfilePulseMarker: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.28), lineWidth: 1)
                .frame(width: isPulsing ? 34 : 16, height: isPulsing ? 34 : 16)
                .opacity(isPulsing ? 0 : 1)

            Circle()
                .fill(color)
                .frame(width: 11, height: 11)
                .shadow(color: color.opacity(0.64), radius: 10, y: 3)

            Circle()
                .fill(AppTheme.Colors.controlText.opacity(0.9))
                .frame(width: 4, height: 4)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
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

    var body: some View {
        GeometryReader { proxy in
            let step = min(proxy.size.width * 0.46, 176)
            let activeIndex = activeIndex

            ZStack {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, item in
                    let relativePosition = CGFloat(index - activeIndex)
                    let prominence = carouselProminence(for: relativePosition)

                AccountCarouselItem(
                        account: item.account,
                        avatarImage: item.avatarImage,
                        prominence: prominence,
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
                    .scaleEffect(0.84 + (0.24 * prominence))
                    .opacity(0.42 + (0.58 * prominence))
                    .offset(x: relativePosition * step, y: 12 - (16 * prominence))
                    .zIndex(Double(prominence))
                    .allowsHitTesting(abs(relativePosition) < 1.15)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .contentShape(Rectangle())
            .simultaneousGesture(carouselSwipeGesture(step: step), including: .all)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: selectedAccountId)
        }
    }

    private var activeIndex: Int {
        guard let selectedAccountId,
              let index = accounts.firstIndex(where: { $0.id == selectedAccountId })
        else {
            return 0
        }
        return index
    }

    private func carouselSwipeGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: AccountsLayoutPolicy.carouselMinimumDragDistance)
            .onEnded { value in
                advanceCarousel(for: value, step: step)
            }
    }

    private func advanceCarousel(for value: DragGesture.Value, step: CGFloat) {
        guard accounts.count > 1 else { return }
        let horizontalMovement = dominantHorizontalMovement(for: value)
        let verticalMovement = dominantVerticalMovement(for: value)
        let threshold = min(
            max(step * AccountsLayoutPolicy.carouselSnapThreshold, AccountsLayoutPolicy.carouselMinimumSwipeDistance),
            AccountsLayoutPolicy.carouselMaximumSwipeDistance
        )
        guard abs(horizontalMovement) >= threshold,
              abs(horizontalMovement) > verticalMovement * AccountsLayoutPolicy.carouselVerticalToleranceRatio
        else {
            return
        }

        var targetIndex = activeIndex

        if horizontalMovement < 0, targetIndex < accounts.count - 1 {
            targetIndex += 1
        } else if horizontalMovement > 0, targetIndex > 0 {
            targetIndex -= 1
        } else {
            return
        }

        onSelect(accounts[targetIndex].id)
    }

    private func dominantHorizontalMovement(for value: DragGesture.Value) -> CGFloat {
        let actual = value.translation.width
        let predicted = value.predictedEndTranslation.width
        return abs(predicted) > abs(actual) ? predicted : actual
    }

    private func dominantVerticalMovement(for value: DragGesture.Value) -> CGFloat {
        max(abs(value.translation.height), abs(value.predictedEndTranslation.height) * 0.55)
    }

    private func carouselProminence(for relativePosition: CGFloat) -> CGFloat {
        max(0, min(1, 1 - abs(relativePosition)))
    }
}

private struct AccountCarouselItem: View {
    var account: PlannerAccount
    var avatarImage: UIImage?
    var prominence: CGFloat
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
                    size: 60 + (18 * prominence)
                )

                Text(account.name)
                    .font(prominence > 0.55 ? .headline.weight(.bold) : .subheadline.weight(.semibold))
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
