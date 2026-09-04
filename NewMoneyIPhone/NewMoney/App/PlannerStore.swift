import Foundation
import Combine
import SwiftUI
import UIKit
import UserNotifications

private struct LinkedPotContribution {
    var amountPence: Int
    var singlePotId: String?
    var singlePotName: String?
    var potContributions: [CreditCardPotContribution]
}

@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var snapshot: PlannerSnapshot = DefaultData.emptySnapshot {
        didSet {
            snapshotRevision &+= 1
        }
    }
    @Published private(set) var snapshotRevision = 0
    @Published private(set) var plannerAccounts: [PlannerAccount] = []
    @Published private(set) var activePlannerAccountId: String?
    @Published private(set) var cloudSyncRevision = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var loadError: String?
    @Published private(set) var saveState: PlannerSaveState = .saved
    @Published private(set) var effectiveDateRevision = 0
    private(set) var hadPersistedPlannerDataBeforeLoad = false
    private var dateProvider: () -> Date = Date.init
    private var lastRefreshedDate: String?
    private var reminderScheduler: PlannerReminderScheduler?
    private var standaloneCollection = PlannerAccountCollection.singleAccount(snapshot: DefaultData.emptySnapshot)
    private lazy var saveCoordinator = PlannerSaveCoordinator(repository: repository, accountRepository: accountRepository) { [weak self] state in
        guard let self else { return }
        saveState = state
        if state == .failed {
            errorMessage = "Your changes are on screen but could not be saved. Please retry."
        } else if state == .saved {
            markCloudSyncNeeded()
        }
    }

    private let repository: PlannerRepository
    private let accountRepository: PlannerAccountRepository?
    private var accountCollection: PlannerAccountCollection?
    private var lastAuditedSnapshot: PlannerSnapshot?
    private var pendingAuditOrigin: PlannerAuditOrigin = .user
    private var pendingRestoredFromEventId: String?
#if DEBUG
    private var suppressAutomaticDueCatchUpForSimulation = false
#endif

    init() {
        let repository = PlannerLaunchProfile.repository()
        self.repository = repository
        self.accountRepository = PlannerLaunchProfile.isUsingFixture() ? nil : FilePlannerAccountRepository()
        self.reminderScheduler = PlannerLaunchProfile.isUsingFixture() ? nil : PlannerReminderScheduler()
    }

    init(repository: PlannerRepository, dateProvider: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.accountRepository = nil
        self.dateProvider = dateProvider
    }

    init(repository: PlannerRepository, accountRepository: PlannerAccountRepository?) {
        self.repository = repository
        self.accountRepository = accountRepository
    }

    var snapshotPublisher: Published<PlannerSnapshot>.Publisher {
        $snapshot
    }

    var cloudSyncPublisher: Published<Int>.Publisher {
        $cloudSyncRevision
    }

    var activePlannerAccount: PlannerAccount? {
        accountCollection?.activeAccount
    }

    var canCreatePlannerAccount: Bool {
        plannerAccounts.count < PlannerAccountCollection.maxAccounts
    }

    var selectedPayPeriod: PayPeriod? {
        if let currentPeriod = snapshot.payPeriods
            .filter({ $0.deletedAt == nil && $0.startDate <= todayIso && $0.endDate >= todayIso })
            .sorted(by: sortPayPeriodsForSelection)
            .first {
            return currentPeriod
        }

        let selectablePeriods = snapshot.payPeriods
            .filter { $0.status == .active || $0.status == .planned }

        return selectablePeriods
            .sorted(by: sortPayPeriodsForSelection)
            .first ?? snapshot.payPeriods.sorted(by: sortPayPeriodsForSelection).first
    }

    var activePots: [Pot] {
        snapshot.pots.filter { !$0.archived }
    }

    var activeBankAccounts: [BankAccount] {
        snapshot.bankAccounts
            .filter { !$0.archived && $0.deletedAt == nil }
            .sorted {
                if $0.isPrimary != $1.isPrimary {
                    return $0.isPrimary
                }
                if $0.name == $1.name {
                    return $0.id < $1.id
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var primaryBankAccount: BankAccount? {
        activeBankAccounts.first(where: \.isPrimary) ?? activeBankAccounts.first
    }

    var activeCards: [CreditCard] {
        snapshot.creditCards.filter { !$0.archived }
    }

    var activeBillGroups: [BillGroup] {
        snapshot.billGroups
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.name == $1.name {
                    return $0.id < $1.id
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    var activeDebts: [Debt] {
        snapshot.debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 }
    }

    var todayIso: String {
        if snapshot.settings.appDateMode == .manual,
           let date = snapshot.settings.manualTodayIso, FinanceEngine.isIsoDate(date) { return date }
        return FinanceEngine.toIsoDate(dateProvider())
    }

    private func sortPayPeriodsForSelection(_ lhs: PayPeriod, _ rhs: PayPeriod) -> Bool {
        if lhs.payday == rhs.payday {
            return lhs.id < rhs.id
        }
        return lhs.payday > rhs.payday
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await saveCoordinator.flush()
        } catch {
            // Keep the newer in-memory revision available for retry rather than
            // replacing it with an older file when a pending write fails.
            return
        }
        loadError = nil
        var sourceLoaded = false
        do {
            hadPersistedPlannerDataBeforeLoad = await repository.hasPersistedSnapshot()
            if let accountRepository {
                let hasAccounts = await accountRepository.hasPersistedAccountCollection()
                hadPersistedPlannerDataBeforeLoad = hadPersistedPlannerDataBeforeLoad || hasAccounts
                let loadedCollection = try await accountRepository.loadAccountCollection()
                let collection: PlannerAccountCollection
                if let loadedCollection {
                    try validateAccountCollection(loadedCollection)
                    collection = loadedCollection
                } else {
                    collection = PlannerAccountCollection.singleAccount(snapshot: try await repository.loadSnapshot())
                }
                applyAccountCollection(collection)
                sourceLoaded = true
                var shouldPersist = loadedCollection == nil
                if prepareLoadedSnapshot() {
                    shouldPersist = true
                }
                if bootstrapAuditHistoryIfNeeded() {
                    shouldPersist = true
                }
                if shouldPersist, let updatedCollection = updateActiveAccountSnapshot(snapshot) {
                    try await saveCoordinator.save(.accounts(updatedCollection))
                }
                lastAuditedSnapshot = snapshot
                refreshCreditCardCycleReminders()
                return
            }

            let loadedSnapshot = try await repository.loadSnapshot()
            sourceLoaded = true
            let migration = DefaultData.migratedSnapshot(loadedSnapshot)
            snapshot = migration.snapshot
            var shouldPersist = migration.didChange
            if removeGeneratedEmptyPayPeriodsCoveredByRecordedPaychecks() {
                shouldPersist = true
            }
#if DEBUG
            if PersonalJuly2026Fixture.isActive,
               bootstrapPersonalJuly2026FixtureIfNeeded() {
                shouldPersist = true
            }
#endif
            if ensureDebtSchedules(today: todayIso) {
                shouldPersist = true
            }
            if catchUpDueObligations(to: todayIso) {
                shouldPersist = true
            }
            if bootstrapAuditHistoryIfNeeded() {
                shouldPersist = true
            }
            if shouldPersist {
                try await saveCoordinator.save(.snapshot(snapshot))
            }
            lastAuditedSnapshot = snapshot
            refreshCreditCardCycleReminders()
        } catch {
            if sourceLoaded {
                // Startup migration/catch-up writes use the same retryable save
                // queue as ordinary edits; readable data is not a load failure.
                lastAuditedSnapshot = snapshot
            } else {
                loadError = "Unable to load local planner data. Your saved files have not been replaced."
                errorMessage = loadError
            }
        }
    }

    func replaceSnapshot(_ replacement: PlannerSnapshot) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        let migration = DefaultData.migratedSnapshot(replacement)
        snapshot = migration.snapshot
        _ = bootstrapAuditHistoryIfNeeded()
        lastAuditedSnapshot = snapshot
        if accountRepository != nil, let collection = updateActiveAccountSnapshot(snapshot) {
            try await saveCoordinator.save(.accounts(collection))
        } else {
            try await saveCoordinator.save(.snapshot(snapshot))
        }
    }

    @discardableResult
    func replaceAccountCollection(_ replacement: PlannerAccountCollection) async throws -> PlannerAccountCollection {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        try validateAccountCollection(replacement)
        applyAccountCollection(replacement)
        var collection = accountCollection ?? PlannerAccountCollection.singleAccount(snapshot: snapshot)
        if prepareLoadedSnapshot(), let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        if bootstrapAuditHistoryIfNeeded(), let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        lastAuditedSnapshot = snapshot

        if accountRepository != nil {
            try await saveCoordinator.save(.accounts(collection))
        } else {
            try await saveCoordinator.save(.snapshot(snapshot))
        }

        return collection
    }

    func saveCurrentSnapshot() async throws {
        if let loadError { throw PlannerStoreLoadError(message: loadError) }
        while true {
            let payload = currentSavePayload()
            try await saveCoordinator.save(payload)
            if payload == currentSavePayload() { return }
        }
    }

    func retrySaving() async {
        do {
            try await saveCurrentSnapshot()
            errorMessage = nil
        } catch {
            errorMessage = "Unable to save local planner data. Your changes are still available to retry."
        }
    }

    func resetLocalData() {
        guard loadError == nil else { return }
        snapshot = DefaultData.emptySnapshot
        lastAuditedSnapshot = snapshot
        saveCoordinator.enqueue(currentSavePayload())
        refreshCreditCardCycleReminders()
    }

    @discardableResult
    func resetAllPlannerDataKeepingSignedInAccount(
        to resetCollection: PlannerAccountCollection = PlannerAccountCollection.singleAccount(snapshot: DefaultData.emptySnapshot)
    ) async throws -> PlannerAccountCollection {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        try validateAccountCollection(resetCollection)
        let avatarImageNames = (accountCollection?.accounts ?? plannerAccounts)
            .compactMap(\.avatarImageName)

        if resetCollection.selectedThemePresetId == nil {
            UserDefaults.standard.removeObject(forKey: AppTheme.selectedPresetStorageKey)
        }
        snapshot = DefaultData.emptySnapshot
        applyAccountCollection(resetCollection)
        lastAuditedSnapshot = snapshot

        // An atomic replacement is safer than deleting the current file first.
        if accountRepository != nil {
            try await saveCoordinator.save(.accounts(accountCollection ?? resetCollection))
        } else {
            try await saveCoordinator.save(.snapshot(snapshot))
        }

        for imageName in avatarImageNames {
            try? PlannerAccountAvatarFileStore.removeImage(named: imageName)
        }

        markCloudSyncNeeded()
        return accountCollection ?? resetCollection
    }

    func createPlannerAccount(named name: String) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        let cleanName = try validatedAccountName(name)
        guard canCreatePlannerAccount else {
            throw PlannerAccountError.limitReached
        }

        _ = updateActiveAccountSnapshot(snapshot)

        var collection = accountCollection ?? PlannerAccountCollection.singleAccount(snapshot: snapshot)
        let now = DateUtilities.nowIsoString()
        let account = PlannerAccount(
            id: DateUtilities.newId(prefix: "planner-account"),
            name: cleanName,
            color: plannerAccountColor(at: collection.accounts.count),
            snapshot: DefaultData.emptySnapshot,
            createdAt: now,
            updatedAt: now
        )
        collection.accounts.append(account)
        collection.activeAccountId = account.id
        collection.updatedAt = now
        applyAccountCollection(collection)
        snapshot = DefaultData.emptySnapshot
        if prepareLoadedSnapshot(), let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        if bootstrapAuditHistoryIfNeeded(), let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        lastAuditedSnapshot = snapshot
        try await saveCoordinator.save(.accounts(collection))
        markCloudSyncNeeded()
    }

    func switchPlannerAccount(id: String) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        _ = updateActiveAccountSnapshot(snapshot)
        guard var collection = accountCollection,
              let account = collection.accounts.first(where: { $0.id == id })
        else {
            throw PlannerAccountError.missingAccount
        }

        collection.activeAccountId = account.id
        collection.updatedAt = DateUtilities.nowIsoString()
        applyAccountCollection(collection)
        let migration = DefaultData.migratedSnapshot(account.snapshot)
        snapshot = migration.snapshot
        var shouldPersist = migration.didChange
        if prepareLoadedSnapshot() {
            shouldPersist = true
        }
        if bootstrapAuditHistoryIfNeeded() {
            shouldPersist = true
        }
        lastAuditedSnapshot = snapshot
        if shouldPersist, let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        try await saveCoordinator.save(.accounts(collection))
        markCloudSyncNeeded()
    }

    func renamePlannerAccount(id: String, name: String) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        let cleanName = try validatedAccountName(name, excludingAccountId: id)
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == id })
        else {
            throw PlannerAccountError.missingAccount
        }

        collection.accounts[index].name = cleanName
        collection.accounts[index].updatedAt = DateUtilities.nowIsoString()
        collection.updatedAt = collection.accounts[index].updatedAt
        applyAccountCollection(collection)
        try await saveCoordinator.save(.accounts(collection))
        markCloudSyncNeeded()
    }

    func deletePlannerAccount(id: String) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        _ = updateActiveAccountSnapshot(snapshot)
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == id })
        else {
            throw PlannerAccountError.missingAccount
        }
        guard collection.accounts.count > 1 else {
            throw PlannerAccountError.cannotDeleteLastAccount
        }

        let removedAvatarImageName = collection.accounts[index].avatarImageName
        collection.accounts.remove(at: index)
        if collection.activeAccountId == id {
            collection.activeAccountId = collection.accounts[0].id
            let migration = DefaultData.migratedSnapshot(collection.accounts[0].snapshot)
            snapshot = migration.snapshot
        }
        collection.updatedAt = DateUtilities.nowIsoString()
        applyAccountCollection(collection)
        if let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        try await saveCoordinator.save(.accounts(collection))
        if let removedAvatarImageName {
            try? PlannerAccountAvatarFileStore.removeImage(named: removedAvatarImageName)
        }
        markCloudSyncNeeded()
    }

    func plannerAccountAvatarImage(for account: PlannerAccount) -> UIImage? {
        if let avatarImageDataBase64 = account.avatarImageDataBase64,
           let data = Data(base64Encoded: avatarImageDataBase64),
           let image = UIImage(data: data) {
            return image
        }
        guard let avatarImageName = account.avatarImageName else { return nil }
        return PlannerAccountAvatarFileStore.image(named: avatarImageName)
    }

    func preparedPlannerAccountAvatarImage(from image: UIImage) -> UIImage {
        PlannerAccountAvatarFileStore.preparedImage(from: image)
    }

    func savePlannerAccountAvatar(accountId: String, image: UIImage) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == accountId })
        else {
            throw PlannerAccountError.missingAccount
        }

        let previousImageName = collection.accounts[index].avatarImageName
        let imageName = previousImageName ?? "\(accountId)-avatar.jpg"
        let preparedImage = PlannerAccountAvatarFileStore.preparedImage(from: image)
        try PlannerAccountAvatarFileStore.save(image: preparedImage, named: imageName)
        let avatarImageDataBase64 = try PlannerAccountAvatarFileStore.encodedImageDataBase64(for: preparedImage)

        let now = DateUtilities.nowIsoString()
        collection.accounts[index].avatarImageName = imageName
        collection.accounts[index].avatarImageDataBase64 = avatarImageDataBase64
        collection.accounts[index].updatedAt = now
        collection.updatedAt = now
        applyAccountCollection(collection)
        try await saveCoordinator.save(.accounts(collection))
        markCloudSyncNeeded()
    }

    func removePlannerAccountAvatar(accountId: String) async throws {
        guard loadError == nil else { throw PlannerStoreLoadError() }
        guard accountRepository != nil else { return }
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == accountId })
        else {
            throw PlannerAccountError.missingAccount
        }

        let imageName = collection.accounts[index].avatarImageName
        let now = DateUtilities.nowIsoString()
        collection.accounts[index].avatarImageName = nil
        collection.accounts[index].avatarImageDataBase64 = nil
        collection.accounts[index].updatedAt = now
        collection.updatedAt = now
        applyAccountCollection(collection)
        try await saveCoordinator.save(.accounts(collection))

        if let imageName {
            try? PlannerAccountAvatarFileStore.removeImage(named: imageName)
        }
        markCloudSyncNeeded()
    }

    func updateSettings(_ settings: Settings) {
        let existingLastProcessedDate = snapshot.settings.lastProcessedDateIso
        var updatedSettings = settings.stamped()
        if updatedSettings.lastProcessedDateIso == nil {
            updatedSettings.lastProcessedDateIso = existingLastProcessedDate
        }
        snapshot.settings = updatedSettings
        persist()
    }

    func addBankAccount(
        name: String,
        provider: String,
        type: BankAccountType,
        currentBalancePence: Int,
        lastFourDigits: String?,
        color: String,
        isPrimary: Bool
    ) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }

        let now = DateUtilities.nowIsoString()
        let shouldBePrimary = isPrimary || activeBankAccounts.isEmpty
        if shouldBePrimary {
            clearPrimaryBankAccount(now: now)
        }
        snapshot.bankAccounts.insert(
            BankAccount(
                id: DateUtilities.newId(prefix: "bank-account"),
                name: cleanName,
                provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
                type: type,
                openingBalancePence: currentBalancePence,
                lastFourDigits: normalizedLastFourDigits(lastFourDigits),
                color: color,
                isPrimary: shouldBePrimary,
                archived: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
        return true
    }

    func updateBankAccount(_ account: BankAccount, currentBalancePence: Int) -> Bool {
        guard let index = snapshot.bankAccounts.firstIndex(where: { $0.id == account.id }) else { return false }
        let cleanName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return false }

        let now = DateUtilities.nowIsoString()
        if account.isPrimary {
            clearPrimaryBankAccount(excluding: account.id, now: now)
        }
        var updated = account
        updated.name = cleanName
        updated.provider = account.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.lastFourDigits = normalizedLastFourDigits(account.lastFourDigits)
        updated.openingBalancePence = currentBalancePence - PlannerDerivedData.bankAccountNetMovementPence(
            accountId: account.id,
            snapshot: snapshot
        )
        updated.updatedAt = now
        snapshot.bankAccounts[index] = updated
        ensurePrimaryBankAccount(now: now)
        persist()
        return true
    }

    func deleteBankAccount(id: String) {
        guard let index = snapshot.bankAccounts.firstIndex(where: { $0.id == id }) else { return }
        let now = DateUtilities.nowIsoString()
        let hasHistory = snapshot.paychecks.contains { $0.bankAccountId == id }
            || snapshot.oneOffIncomes.contains { $0.bankAccountId == id }
            || snapshot.potAllocations.contains { $0.bankAccountId == id }
            || snapshot.transactions.contains { $0.bankAccountId == id }

        if hasHistory {
            snapshot.bankAccounts[index].archived = true
            snapshot.bankAccounts[index].isPrimary = false
            snapshot.bankAccounts[index].updatedAt = now
            snapshot.bankAccounts[index].deletedAt = now
        } else {
            snapshot.bankAccounts.remove(at: index)
        }

        for potIndex in snapshot.pots.indices where snapshot.pots[potIndex].fundingBankAccountId == id {
            snapshot.pots[potIndex].fundingBankAccountId = nil
            snapshot.pots[potIndex].updatedAt = now
        }
        for paymentIndex in snapshot.recurringPayments.indices where snapshot.recurringPayments[paymentIndex].bankAccountId == id {
            snapshot.recurringPayments[paymentIndex].bankAccountId = nil
            snapshot.recurringPayments[paymentIndex].updatedAt = now
        }
        ensurePrimaryBankAccount(now: now)
        persist()
    }

    func createPayPeriod(
        payday: String,
        hoursWorked: Double,
        hourlyRatePence: Int,
        actualAmountPence: Int?,
        payFrequency: PayFrequency? = nil,
        bankAccountId: String? = nil
    ) {
        guard FinanceEngine.isIsoDate(payday), hoursWorked.isFinite,
              FinanceEngine.validatedPaycheckAmount(hoursWorked: hoursWorked, hourlyRatePence: hourlyRatePence, actualAmountPence: actualAmountPence) != nil else {
            errorMessage = "Enter a valid payday, hours, and amount."
            return
        }
        let frequency = payFrequency ?? snapshot.settings.payFrequency
        let monthlyAnchorDay = frequency == .monthly ? FinanceEngine.dayOfMonth(payday) : nil
        let dates = FinanceEngine.createNextPayPeriod(
            payday: payday,
            frequency: frequency,
            monthlyAnchorDay: monthlyAnchorDay
        )
        let amount = FinanceEngine.calculatePaycheckAmount(
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            actualAmountPence: actualAmountPence
        )
        let now = DateUtilities.nowIsoString()
        let id = "pay-period-\(payday)"

        for index in snapshot.payPeriods.indices where snapshot.payPeriods[index].status == .active {
            snapshot.payPeriods[index].status = .closed
            snapshot.payPeriods[index].updatedAt = now
        }

        let period = PayPeriod(
            id: id,
            startDate: dates.startDate,
            endDate: dates.endDate,
            payday: payday,
            nextPayday: dates.nextPayday,
            payFrequency: frequency,
            incomePence: amount,
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            monthlyAnchorDay: monthlyAnchorDay
        )
        let paycheck = Paycheck(
            id: "paycheck-\(UUID().uuidString.lowercased())",
            payPeriodId: id,
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            calculatedAmountPence: amount,
            actualAmountPence: actualAmountPence,
            bankAccountId: normalizedActiveBankAccountId(bankAccountId),
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )

        snapshot.payPeriods.insert(period, at: 0)
        snapshot.paychecks.insert(paycheck, at: 0)
        persist()
    }

    @discardableResult
    func addOneOffIncome(name: String, amountPence: Int, date: String, note: String, bankAccountId: String? = nil) -> Bool {
        let amount = abs(amountPence)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0, FinanceEngine.isIsoDate(date) else { return false }

        let now = DateUtilities.nowIsoString()
        let income = OneOffIncome(
            id: DateUtilities.newId(prefix: "one-off-income"),
            payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id,
            name: trimmedName.isEmpty ? "One-off income" : trimmedName,
            amountPence: amount,
            date: date,
            note: trimmedNote,
            bankAccountId: normalizedActiveBankAccountId(bankAccountId),
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )

        snapshot.oneOffIncomes.insert(income, at: 0)
        persist()
        return true
    }

    @discardableResult
    func updateOneOffIncome(
        id: String,
        name: String,
        amountPence: Int,
        date: String,
        note: String,
        bankAccountId: String? = nil
    ) -> Bool {
        guard let index = snapshot.oneOffIncomes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return false }
        let amount = abs(amountPence)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0, FinanceEngine.isIsoDate(date) else { return false }

        snapshot.oneOffIncomes[index].name = trimmedName.isEmpty ? "One-off income" : trimmedName
        snapshot.oneOffIncomes[index].amountPence = amount
        snapshot.oneOffIncomes[index].date = date
        snapshot.oneOffIncomes[index].note = trimmedNote
        snapshot.oneOffIncomes[index].bankAccountId = normalizedActiveBankAccountId(bankAccountId)
        snapshot.oneOffIncomes[index].payPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id
        snapshot.oneOffIncomes[index].updatedAt = DateUtilities.nowIsoString()
        persist()
        return true
    }

    @discardableResult
    func deleteOneOffIncome(id: String) -> Bool {
        guard let index = snapshot.oneOffIncomes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return false }
        let now = DateUtilities.nowIsoString()
        snapshot.oneOffIncomes[index].updatedAt = now
        snapshot.oneOffIncomes[index].deletedAt = now
        persist()
        return true
    }

    @discardableResult
    func permanentlyDeleteOneOffIncome(id: String) -> Bool {
        let originalCount = snapshot.oneOffIncomes.count
        snapshot.oneOffIncomes.removeAll { $0.id == id }
        guard snapshot.oneOffIncomes.count != originalCount else { return false }
        persist()
        return true
    }

    func updatePaycheck(
        id: String,
        payday: String,
        hoursWorked: Double,
        hourlyRatePence: Int,
        actualAmountPence: Int?,
        payFrequency: PayFrequency? = nil,
        bankAccountId: String? = nil
    ) {
        guard FinanceEngine.isIsoDate(payday), hoursWorked.isFinite,
              FinanceEngine.validatedPaycheckAmount(hoursWorked: hoursWorked, hourlyRatePence: hourlyRatePence, actualAmountPence: actualAmountPence) != nil else {
            errorMessage = "Enter a valid payday, hours, and amount."
            return
        }
        guard let paycheckIndex = snapshot.paychecks.firstIndex(where: { $0.id == id }) else { return }
        let payPeriodId = snapshot.paychecks[paycheckIndex].payPeriodId
        let now = DateUtilities.nowIsoString()
        let amount = FinanceEngine.calculatePaycheckAmount(
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            actualAmountPence: actualAmountPence
        )
        let existingPeriod = snapshot.payPeriods.first(where: { $0.id == payPeriodId })
        let periodFrequency = payFrequency ?? existingPeriod?.payFrequency ?? snapshot.settings.payFrequency
        let monthlyAnchorDay: Int? = if periodFrequency == .monthly {
            if existingPeriod?.payday == payday, let existingAnchor = existingPeriod?.monthlyAnchorDay {
                existingAnchor
            } else {
                FinanceEngine.dayOfMonth(payday)
            }
        } else {
            nil
        }
        let dates = FinanceEngine.createNextPayPeriod(
            payday: payday,
            frequency: periodFrequency,
            monthlyAnchorDay: monthlyAnchorDay
        )

        snapshot.paychecks[paycheckIndex].hoursWorked = hoursWorked
        snapshot.paychecks[paycheckIndex].hourlyRatePence = hourlyRatePence
        snapshot.paychecks[paycheckIndex].calculatedAmountPence = amount
        snapshot.paychecks[paycheckIndex].actualAmountPence = actualAmountPence
        snapshot.paychecks[paycheckIndex].bankAccountId = normalizedActiveBankAccountId(bankAccountId)
        snapshot.paychecks[paycheckIndex].updatedAt = now

        if let periodIndex = snapshot.payPeriods.firstIndex(where: { $0.id == payPeriodId }) {
            snapshot.payPeriods[periodIndex].startDate = dates.startDate
            snapshot.payPeriods[periodIndex].endDate = dates.endDate
            snapshot.payPeriods[periodIndex].payday = payday
            snapshot.payPeriods[periodIndex].nextPayday = dates.nextPayday
            snapshot.payPeriods[periodIndex].payFrequency = periodFrequency
            snapshot.payPeriods[periodIndex].monthlyAnchorDay = monthlyAnchorDay
            snapshot.payPeriods[periodIndex].incomePence = amount
            snapshot.payPeriods[periodIndex].updatedAt = now
        }

        persist()
    }

    func deletePaycheck(id: String) {
        guard let paycheck = snapshot.paychecks.first(where: { $0.id == id }) else { return }
        deletePayPeriod(id: paycheck.payPeriodId)
    }

    func deletePayPeriod(id: String) {
        let hasLinkedData = snapshot.payPeriods.contains { $0.id == id } ||
            snapshot.paychecks.contains { $0.payPeriodId == id } ||
            snapshot.potAllocations.contains { $0.payPeriodId == id }
        guard hasLinkedData else { return }
        let now = DateUtilities.nowIsoString()
        let linkedAllocations = snapshot.potAllocations.filter { $0.payPeriodId == id }

        for allocation in linkedAllocations {
            guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == allocation.potId }) else { continue }
            snapshot.pots[potIndex].balancePence -= abs(allocation.amountPence)
            snapshot.pots[potIndex].updatedAt = now
        }

        snapshot.potAllocations.removeAll { $0.payPeriodId == id }
        snapshot.payPeriods.removeAll { $0.id == id }
        snapshot.paychecks.removeAll { $0.payPeriodId == id }
        persist()
    }

    func addPot(
        name: String,
        type: PotType,
        category: String?,
        targetPence: Int?,
        color: String,
        balancePence: Int = 0,
        linkedCreditCardId: String? = nil,
        linkedDebtId: String? = nil,
        fundingBankAccountId: String? = nil
    ) {
        let now = DateUtilities.nowIsoString()
        let cleanCardId = linkedCreditCardId?.nilIfBlank
        let cleanDebtId = cleanCardId == nil ? linkedDebtId?.nilIfBlank : nil
        let pot = Pot(
            id: DateUtilities.newId(prefix: "pot"),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            category: category?.nilIfBlank,
            icon: nil,
            balancePence: max(0, balancePence),
            targetPence: targetPence.map { max(0, $0) },
            color: color,
            linkedCreditCardId: cleanCardId,
            linkedDebtId: cleanDebtId,
            fundingBankAccountId: normalizedActiveBankAccountId(fundingBankAccountId),
            archived: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.pots.insert(pot, at: 0)
        persist()
    }

    func updatePot(_ pot: Pot) {
        var updated = pot.stamped()
        updated.fundingBankAccountId = normalizedActiveBankAccountId(pot.fundingBankAccountId)
        replace(&snapshot.pots, with: updated)
        persist()
    }

    func archivePot(id: String) {
        guard let index = snapshot.pots.firstIndex(where: { $0.id == id }) else { return }
        snapshot.pots[index].archived = true
        snapshot.pots[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func deletePot(id: String) {
        let now = DateUtilities.nowIsoString()
        let hasHistory = snapshot.recurringPayments.contains { $0.potId == id }
            || snapshot.potAllocations.contains { $0.potId == id || $0.fundingPotId == id }
            || snapshot.transactions.contains { $0.potId == id }

        if hasHistory {
            guard let index = snapshot.pots.firstIndex(where: { $0.id == id }) else { return }
            snapshot.pots[index].archived = true
            snapshot.pots[index].updatedAt = now
            snapshot.pots[index].deletedAt = now
        } else {
            snapshot.pots.removeAll { $0.id == id }
        }

        persist()
    }

    func recordTransaction(
        potId: String?,
        creditCardId: String?,
        bankAccountId: String? = nil,
        paymentMethod: PaymentMethod,
        amountPence: Int,
        type: TransactionType,
        date: String,
        note: String
    ) {
        let now = DateUtilities.nowIsoString()
        let resolvedBankAccountId = resolvedBankAccountId(
            requestedId: bankAccountId,
            paymentMethod: paymentMethod
        )
        let resolvedPaymentMethod: PaymentMethod = resolvedBankAccountId == nil ? paymentMethod : .bankAccount
        let transaction = Transaction(
            id: DateUtilities.newId(prefix: "transaction"),
            potId: resolvedPaymentMethod == .pot ? potId?.nilIfBlank : nil,
            payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id,
            amountPence: abs(amountPence),
            type: type,
            paymentMethod: resolvedPaymentMethod,
            creditCardId: resolvedPaymentMethod == .creditCard ? creditCardId?.nilIfBlank : nil,
            bankAccountId: resolvedBankAccountId,
            recurringPaymentId: nil,
            date: date,
            note: note,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.transactions.insert(transaction, at: 0)

        if let potId, resolvedPaymentMethod == .pot, let index = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            snapshot.pots[index] = FinanceEngine.applyTransactionToPot(snapshot.pots[index], amountPence: abs(amountPence), type: type)
        }

        persist()
    }

    func updateTransaction(
        id: String,
        potId: String?,
        creditCardId: String?,
        bankAccountId: String? = nil,
        paymentMethod: PaymentMethod,
        amountPence: Int,
        date: String,
        note: String
    ) {
        let amount = abs(amountPence)
        let cleanBankAccountId = resolvedBankAccountId(
            requestedId: bankAccountId,
            paymentMethod: paymentMethod
        )
        let resolvedPaymentMethod: PaymentMethod = cleanBankAccountId == nil ? paymentMethod : .bankAccount
        let cleanPotId = resolvedPaymentMethod == .pot ? potId?.nilIfBlank : nil
        let cleanCardId = resolvedPaymentMethod == .creditCard ? creditCardId?.nilIfBlank : nil
        let hasValidFundingSource: Bool
        switch resolvedPaymentMethod {
        case .income:
            hasValidFundingSource = true
        case .bankAccount:
            hasValidFundingSource = cleanBankAccountId != nil
        case .pot:
            hasValidFundingSource = cleanPotId != nil
        case .creditCard:
            hasValidFundingSource = cleanCardId != nil
        }

        guard amount > 0,
              let index = snapshot.transactions.firstIndex(where: { $0.id == id }),
              snapshot.transactions[index].type == .spending,
              !snapshot.transactions[index].isRefunded,
              hasValidFundingSource
        else { return }

        let now = DateUtilities.nowIsoString()
        let existing = snapshot.transactions[index]
        guard let fundedCardSpendPayPeriodIds = removeCardSpendFundingAllocations(transactionId: existing.id, now: now) else {
            return
        }
        restorePotBalanceAfterRemovingTransaction(existing, now: now)

        var updated = existing
        updated.potId = cleanPotId
        updated.payPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id
        updated.amountPence = amount
        updated.paymentMethod = resolvedPaymentMethod
        updated.creditCardId = cleanCardId
        updated.bankAccountId = cleanBankAccountId
        updated.date = date
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = now
        snapshot.transactions[index] = updated

        applyPotBalanceForTransaction(updated)
        restoreCardSpendFundingAllocations(transactionId: updated.id, payPeriodIds: fundedCardSpendPayPeriodIds)
        persist()
    }

    @discardableResult
    func transferMoney(
        bankAccountId: String,
        potId: String,
        amountPence: Int,
        direction: PotBankTransferDirection,
        date: String,
        note: String
    ) -> Bool {
        let amount = abs(amountPence)
        guard amount > 0,
              let cleanBankId = normalizedActiveBankAccountId(bankAccountId),
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId && !$0.archived })
        else { return false }

        guard transferSourceHasFunds(
            direction: direction,
            amountPence: amount,
            bankAccountId: cleanBankId,
            potBalancePence: snapshot.pots[potIndex].balancePence,
            snapshot: snapshot
        ) else { return false }

        let now = DateUtilities.nowIsoString()
        let transaction = Transaction(
            id: DateUtilities.newId(prefix: "transfer"),
            potId: potId,
            payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id,
            amountPence: amount,
            type: .transfer,
            paymentMethod: direction == .bankToPot ? .bankAccount : .pot,
            creditCardId: nil,
            bankAccountId: cleanBankId,
            recurringPaymentId: nil,
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )

        snapshot.transactions.insert(transaction, at: 0)
        applyTransferToPot(direction: direction, amountPence: amount, potIndex: potIndex, now: now)
        persist()
        return true
    }

    @discardableResult
    func updatePotBankTransfer(
        id: String,
        bankAccountId: String,
        potId: String,
        amountPence: Int,
        direction: PotBankTransferDirection,
        date: String,
        note: String
    ) -> Bool {
        let amount = abs(amountPence)
        guard amount > 0,
              let transactionIndex = snapshot.transactions.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              let oldDirection = snapshot.transactions[transactionIndex].potBankTransferDirection,
              let oldPotId = snapshot.transactions[transactionIndex].potId,
              let oldPotIndex = snapshot.pots.firstIndex(where: { $0.id == oldPotId }),
              let cleanBankId = normalizedActiveBankAccountId(bankAccountId),
              let newPotIndex = snapshot.pots.firstIndex(where: { $0.id == potId && !$0.archived })
        else { return false }

        let oldAmount = snapshot.transactions[transactionIndex].netAmountPence
        guard oldDirection != .bankToPot || snapshot.pots[oldPotIndex].balancePence >= oldAmount else {
            return false
        }

        var candidate = snapshot
        candidate.transactions.remove(at: transactionIndex)
        candidate.pots[oldPotIndex].balancePence += oldDirection == .bankToPot ? -oldAmount : oldAmount

        guard transferSourceHasFunds(
            direction: direction,
            amountPence: amount,
            bankAccountId: cleanBankId,
            potBalancePence: candidate.pots[newPotIndex].balancePence,
            snapshot: candidate
        ) else { return false }

        let now = DateUtilities.nowIsoString()
        snapshot.pots[oldPotIndex].balancePence += oldDirection == .bankToPot ? -oldAmount : oldAmount
        snapshot.pots[oldPotIndex].updatedAt = now

        var updated = snapshot.transactions[transactionIndex]
        updated.potId = potId
        updated.payPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id
        updated.amountPence = amount
        updated.paymentMethod = direction == .bankToPot ? .bankAccount : .pot
        updated.bankAccountId = cleanBankId
        updated.date = date
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = now
        snapshot.transactions[transactionIndex] = updated

        applyTransferToPot(direction: direction, amountPence: amount, potIndex: newPotIndex, now: now)
        persist()
        return true
    }

    @discardableResult
    func deletePotBankTransfer(id: String) -> Bool {
        guard let transactionIndex = snapshot.transactions.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              let direction = snapshot.transactions[transactionIndex].potBankTransferDirection,
              let potId = snapshot.transactions[transactionIndex].potId,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId })
        else { return false }

        let now = DateUtilities.nowIsoString()
        let amount = snapshot.transactions[transactionIndex].netAmountPence
        guard direction != .bankToPot || snapshot.pots[potIndex].balancePence >= amount else {
            return false
        }
        snapshot.pots[potIndex].balancePence += direction == .bankToPot ? -amount : amount
        snapshot.pots[potIndex].updatedAt = now
        snapshot.transactions.remove(at: transactionIndex)
        persist()
        return true
    }

    func deleteTransaction(id: String) {
        guard let index = snapshot.transactions.firstIndex(where: { $0.id == id }),
              snapshot.transactions[index].type == .spending
        else { return }

        let now = DateUtilities.nowIsoString()
        let transaction = snapshot.transactions.remove(at: index)
        guard removeCardSpendFundingAllocations(transactionId: transaction.id, now: now) != nil else {
            snapshot.transactions.insert(transaction, at: index)
            return
        }
        restorePotBalanceAfterRemovingTransaction(transaction, now: now)
        persist()
    }

    func permanentlyDeleteActivityTransaction(id: String) {
        guard let transaction = snapshot.transactions.first(where: { $0.id == id && $0.deletedAt == nil }),
              transaction.type == .spending
        else { return }

        guard let paymentId = transaction.recurringPaymentId,
              let scheduledDueDate = recurringScheduledDueDate(for: transaction, paymentId: paymentId)
        else {
            deleteTransaction(id: id)
            return
        }

        let reversedIds = reverseGeneratedRecurringBillTransactions(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate
        )
        removeRecurringBillFundingAllocations(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate,
            now: DateUtilities.nowIsoString()
        )
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = .cancelled
            $0.actualDueDate = nil
            $0.refundedAmountPence = nil
            $0.reversedGeneratedTransactionIds = Array(Set($0.reversedGeneratedTransactionIds + reversedIds)).sorted()
        }
        snapshot.transactions.removeAll { reversedIds.contains($0.id) }
        persist()
    }

    func deletePotHistoryTransaction(id: String) {
        guard let index = snapshot.transactions.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              snapshot.transactions[index].potId != nil
        else { return }

        if snapshot.transactions[index].type == .spending {
            permanentlyDeleteActivityTransaction(id: id)
            return
        }

        guard snapshot.transactions[index].type == .allocation else { return }
        let transaction = snapshot.transactions.remove(at: index)
        restorePotBalanceAfterRemovingTransaction(transaction, now: DateUtilities.nowIsoString())
        persist()
    }

    /// Keeps the payment in history while reversing only the amount actually
    /// returned. A legacy boolean call remains as a full-refund convenience.
    func setTransactionRefunded(id: String, refunded: Bool) {
        guard let transaction = snapshot.transactions.first(where: { $0.id == id }) else { return }
        setTransactionRefundAmount(id: id, amountPence: refunded ? transaction.amountPence : 0)
    }

    func setTransactionRefundAmount(id: String, amountPence: Int) {
        guard let transaction = snapshot.transactions.first(where: { $0.id == id }),
              transaction.type == .spending
        else { return }

        // Generated recurring charges are rebuilt from their immutable
        // occurrence override. Persist the refund there first or the next
        // reconciliation pass would silently restore the old no-refund value.
        if let paymentId = transaction.recurringPaymentId,
           let scheduledDueDate = recurringScheduledDueDate(for: transaction, paymentId: paymentId) {
            setRecurringBillOccurrenceRefundAmount(
                paymentId: paymentId,
                scheduledDueDate: scheduledDueDate,
                amountPence: amountPence
            )
            return
        }

        setStandaloneTransactionRefundAmount(id: id, amountPence: amountPence)
    }

    private func setStandaloneTransactionRefundAmount(id: String, amountPence: Int) {
        guard let index = snapshot.transactions.firstIndex(where: { $0.id == id }),
              snapshot.transactions[index].type == .spending
        else { return }

        let requestedRefundPence = min(snapshot.transactions[index].amountPence, max(0, abs(amountPence)))
        let previousRefundPence = snapshot.transactions[index].effectiveRefundedAmountPence
        guard requestedRefundPence != previousRefundPence else { return }

        let now = DateUtilities.nowIsoString()
        let refundDeltaPence = requestedRefundPence - previousRefundPence
        if snapshot.transactions[index].paymentMethod == .pot,
           let potId = snapshot.transactions[index].potId,
           let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            if refundDeltaPence < 0 && snapshot.pots[potIndex].balancePence < abs(refundDeltaPence) {
                errorMessage = "Unable to reduce this refund because the linked pot no longer has enough money."
                return
            }
            snapshot.pots[potIndex].balancePence += refundDeltaPence
            snapshot.pots[potIndex].updatedAt = now
        }

        let previouslyFundedPayPeriodIds = snapshot.transactions[index].refundedCardSpendFundingPayPeriodIds ?? []
        guard let removedFundingPayPeriodIds = removeCardSpendFundingAllocations(
            transactionId: snapshot.transactions[index].id,
            now: now
        ) else { return }
        let fundingPayPeriodIds = Array(Set(previouslyFundedPayPeriodIds + removedFundingPayPeriodIds)).sorted()

        if requestedRefundPence > 0 {
            snapshot.transactions[index].refundedAt = now
            snapshot.transactions[index].refundedAmountPence = requestedRefundPence
            snapshot.transactions[index].refundedCardSpendFundingPayPeriodIds = fundingPayPeriodIds
            snapshot.transactions[index].updatedAt = now
        } else {
            snapshot.transactions[index].refundedAt = nil
            snapshot.transactions[index].refundedAmountPence = nil
            snapshot.transactions[index].refundedCardSpendFundingPayPeriodIds = nil
            snapshot.transactions[index].updatedAt = now
        }
        restoreCardSpendFundingAllocations(
            transactionId: snapshot.transactions[index].id,
            payPeriodIds: fundingPayPeriodIds
        )
        persist()
    }

    func addRecurringPayment(
        name: String,
        amountPence: Int,
        dueDay: Int?,
        frequency: RecurringFrequency,
        potId: String?,
        creditCardId: String?,
        bankAccountId: String? = nil,
        priority: RecurringPriority,
        billGroupId: String? = nil
    ) {
        let now = DateUtilities.nowIsoString()
        let cleanCardId = creditCardId?.nilIfBlank
        let cleanPotId = normalizedRecurringPaymentPotId(potId: potId, creditCardId: cleanCardId)
        let cleanGroupId = normalizedBillGroupId(billGroupId)
        let payment = RecurringPayment(
            id: DateUtilities.newId(prefix: "recurring"),
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: nil,
            frequency: frequency,
            potId: cleanPotId,
            creditCardId: cleanCardId,
            bankAccountId: cleanCardId == nil && cleanPotId == nil ? normalizedActiveBankAccountId(bankAccountId) : nil,
            billGroupId: cleanGroupId,
            priority: priority,
            active: true,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.recurringPayments.insert(payment, at: 0)
        persist()
    }

    func updateRecurringPayment(_ payment: RecurringPayment) {
        // Posted occurrences are facts, not a projection of today's series defaults.
        for transaction in snapshot.transactions where transaction.deletedAt == nil && transaction.recurringPaymentId == payment.id {
            guard let scheduledDate = recurringScheduledDueDate(for: transaction, paymentId: payment.id) else { continue }
            upsertRecurringBillOccurrenceOverride(paymentId: payment.id, scheduledDueDate: scheduledDate) { occurrence in
                if occurrence.amountPenceOverride == nil {
                    occurrence.amountPenceOverride = transaction.amountPence
                }
            }
        }
        var updated = payment.stamped()
        updated.creditCardId = payment.creditCardId?.nilIfBlank
        updated.potId = normalizedRecurringPaymentPotId(potId: payment.potId, creditCardId: updated.creditCardId)
        updated.bankAccountId = updated.creditCardId == nil && updated.potId == nil
            ? normalizedActiveBankAccountId(payment.bankAccountId)
            : nil
        updated.billGroupId = normalizedBillGroupId(payment.billGroupId)
        replace(&snapshot.recurringPayments, with: updated)
        persist()
    }

    func markRecurringBillOccurrenceAwaiting(paymentId: String, scheduledDueDate: String) {
        let reversedIds = reverseGeneratedRecurringBillTransactions(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = .awaitingPayment
            $0.actualDueDate = nil
            $0.refundedAmountPence = nil
            $0.reversedGeneratedTransactionIds = Array(Set($0.reversedGeneratedTransactionIds + reversedIds)).sorted()
        }
        persist()
    }

    func confirmRecurringBillOccurrence(paymentId: String, scheduledDueDate: String, actualDueDate: String) {
        guard FinanceEngine.isIsoDate(actualDueDate),
              let previousEffectiveDate = recurringBillOccurrenceEffectiveDate(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        else { return }

        let reversedIds = reverseGeneratedRecurringBillTransactions(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate
        )
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = .confirmed
            $0.actualDueDate = actualDueDate
            $0.refundedAmountPence = nil
            $0.reversedGeneratedTransactionIds = Array(Set(
                $0.reversedGeneratedTransactionIds + reversedIds
            )).sorted()
        }
        moveRecurringBillFundingReferences(
            paymentId: paymentId,
            fromDueDate: previousEffectiveDate,
            toDueDate: actualDueDate
        )
        reapplyRecurringBillOccurrenceIfDue(paymentId: paymentId, effectiveDueDate: actualDueDate)
        persist()
    }

    func clearRecurringBillOccurrenceAdjustment(paymentId: String, scheduledDueDate: String) {
        guard let previousEffectiveDate = recurringBillOccurrenceEffectiveDate(paymentId: paymentId, scheduledDueDate: scheduledDueDate) else { return }
        _ = reverseGeneratedRecurringBillTransactions(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = .normal
            $0.actualDueDate = nil
            $0.refundedAmountPence = nil
        }
        moveRecurringBillFundingReferences(
            paymentId: paymentId,
            fromDueDate: previousEffectiveDate,
            toDueDate: scheduledDueDate
        )
        reapplyRecurringBillOccurrenceIfDue(paymentId: paymentId, effectiveDueDate: scheduledDueDate)
        persist()
    }

    func setRecurringBillOccurrenceRefunded(paymentId: String, scheduledDueDate: String, refunded: Bool) {
        guard let payment = snapshot.recurringPayments.first(where: { $0.id == paymentId }) else { return }
        let override = snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil && $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate
        }
        let grossAmountPence = override?.amountPenceOverride ?? payment.amountPence
        setRecurringBillOccurrenceRefundAmount(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate,
            amountPence: refunded ? grossAmountPence : 0
        )
    }

    func cancelRecurringBillOccurrence(paymentId: String, scheduledDueDate: String) {
        guard FinanceEngine.isIsoDate(scheduledDueDate),
              snapshot.recurringPayments.contains(where: {
                  $0.id == paymentId && $0.active && $0.deletedAt == nil
              })
        else { return }

        let reversedIds = reverseGeneratedRecurringBillTransactions(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate
        )
        removeRecurringBillFundingAllocations(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate,
            now: DateUtilities.nowIsoString()
        )
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = .cancelled
            $0.actualDueDate = nil
            $0.refundedAmountPence = nil
            $0.reversedGeneratedTransactionIds = Array(Set(
                $0.reversedGeneratedTransactionIds + reversedIds
            )).sorted()
        }
        persist()
    }

    func setRecurringBillOccurrenceRefundAmount(paymentId: String, scheduledDueDate: String, amountPence: Int) {
        guard FinanceEngine.isIsoDate(scheduledDueDate) else { return }
        guard let payment = snapshot.recurringPayments.first(where: { $0.id == paymentId && $0.deletedAt == nil }) else { return }
        let existingOverride = snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil && $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate
        }
        let grossAmountPence = max(0, existingOverride?.amountPenceOverride ?? payment.amountPence)
        let refundAmountPence = min(grossAmountPence, max(0, abs(amountPence)))
        let generatedIds = [
            recurringTransactionId(paymentId: paymentId, scheduledDueDate: scheduledDueDate),
            cardRecurringTransactionId(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        ]
        let hasRecordedCharge = generatedIds.contains { transactionId in
            snapshot.transactions.contains { $0.id == transactionId && $0.deletedAt == nil }
        }
        guard refundAmountPence == 0 || hasRecordedCharge else {
            errorMessage = "A refund can only be logged after this bill has been charged."
            return
        }

        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.state = refundAmountPence >= grossAmountPence && grossAmountPence > 0 ? .refunded : .normal
            $0.actualDueDate = nil
            $0.refundedAmountPence = refundAmountPence > 0 ? refundAmountPence : nil
        }

        for transactionId in generatedIds where snapshot.transactions.contains(where: { $0.id == transactionId && $0.deletedAt == nil }) {
            // Keep the original charge as an auditable ledger movement and add
            // the exact returned amount as its refund credit. Full refunds no
            // longer erase a charge that genuinely reached the account/card.
            setStandaloneTransactionRefundAmount(id: transactionId, amountPence: refundAmountPence)
        }

        // Legacy full refunds removed the generated charge. If the refund is
        // later reduced or cleared, recreate the gross charge with its refund
        // metadata so the net movement and history are both correct.
        if refundAmountPence < grossAmountPence && !generatedIds.contains(where: { transactionId in
            snapshot.transactions.contains { $0.id == transactionId && $0.deletedAt == nil }
        }) {
            reapplyRecurringBillOccurrenceIfDue(paymentId: paymentId, effectiveDueDate: scheduledDueDate)
        }
        persist()
    }

    func setRecurringBillOccurrenceAmount(paymentId: String, scheduledDueDate: String, amountPence: Int?) {
        guard amountPence == nil || amountPence! > 0 else { return }
        let reversedIds = reverseGeneratedRecurringBillTransactions(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        upsertRecurringBillOccurrenceOverride(paymentId: paymentId, scheduledDueDate: scheduledDueDate) {
            $0.amountPenceOverride = amountPence
            $0.reversedGeneratedTransactionIds = Array(Set($0.reversedGeneratedTransactionIds + reversedIds)).sorted()
        }
        if let effectiveDueDate = recurringBillOccurrenceEffectiveDate(
            paymentId: paymentId,
            scheduledDueDate: scheduledDueDate
        ) {
            reapplyRecurringBillOccurrenceIfDue(paymentId: paymentId, effectiveDueDate: effectiveDueDate)
        }
        persist()
    }

    private func reapplyRecurringBillOccurrenceIfDue(paymentId: String, effectiveDueDate: String) {
        guard effectiveDueDate <= todayIso,
              let payment = snapshot.recurringPayments.first(where: {
                  $0.id == paymentId && $0.active && $0.deletedAt == nil
              })
        else { return }

        if payment.creditCardId != nil {
            _ = applyDueCreditCardRecurringPayments(asOf: todayIso)
        } else if payment.potId != nil {
            _ = applyDueRecurringPotPayments(asOf: todayIso)
        } else {
            _ = applyDueBankAccountRecurringPayments(asOf: todayIso)
        }
    }

    private func upsertRecurringBillOccurrenceOverride(
        paymentId: String,
        scheduledDueDate: String,
        mutate: (inout RecurringPaymentOccurrenceOverride) -> Void
    ) {
        guard FinanceEngine.isIsoDate(scheduledDueDate),
              snapshot.recurringPayments.contains(where: { $0.id == paymentId && $0.active && $0.deletedAt == nil })
        else { return }

        let now = DateUtilities.nowIsoString()
        if let index = snapshot.recurringPaymentOccurrenceOverrides.firstIndex(where: {
            $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate && $0.deletedAt == nil
        }) {
            mutate(&snapshot.recurringPaymentOccurrenceOverrides[index])
            snapshot.recurringPaymentOccurrenceOverrides[index].updatedAt = now
        } else {
            var override = RecurringPaymentOccurrenceOverride(
                id: "recurring-occurrence-override-\(paymentId)-\(scheduledDueDate)",
                paymentId: paymentId,
                scheduledDueDate: scheduledDueDate,
                state: .normal,
                actualDueDate: nil,
                reversedGeneratedTransactionIds: [],
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            mutate(&override)
            snapshot.recurringPaymentOccurrenceOverrides.insert(override, at: 0)
        }
    }

    private func recurringBillOccurrenceEffectiveDate(paymentId: String, scheduledDueDate: String) -> String? {
        guard FinanceEngine.isIsoDate(scheduledDueDate) else { return nil }
        let override = snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil && $0.paymentId == paymentId && $0.scheduledDueDate == scheduledDueDate
        }
        return override?.state == .confirmed ? override?.actualDueDate ?? scheduledDueDate : scheduledDueDate
    }

    private func reverseGeneratedRecurringBillTransactions(
        paymentId: String,
        scheduledDueDate: String,
        keepingDueDate: String? = nil
    ) -> [String] {
        let now = DateUtilities.nowIsoString()
        let generatedIds = [
            recurringTransactionId(paymentId: paymentId, scheduledDueDate: scheduledDueDate),
            cardRecurringTransactionId(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
        ]
        let indices = snapshot.transactions.indices.filter {
            let transaction = snapshot.transactions[$0]
            return transaction.deletedAt == nil &&
                generatedIds.contains(transaction.id) &&
                (keepingDueDate == nil || transaction.date != keepingDueDate)
        }

        for index in indices {
            let transaction = snapshot.transactions[index]
            restorePotBalanceAfterRemovingTransaction(transaction, now: now)
            snapshot.transactions[index].deletedAt = now
            snapshot.transactions[index].updatedAt = now
        }
        return indices.map { snapshot.transactions[$0].id }
    }

    /// Repairs snapshots saved with a confirmed bill-date override while a
    /// generated transaction still carries the old expected date.
    private func reconcileRescheduledGeneratedRecurringBillTransactions() -> Bool {
        typealias RescheduledBillOccurrence = (
            id: String,
            paymentId: String,
            scheduledDueDate: String,
            actualDueDate: String
        )
        let rescheduledOccurrences: [RescheduledBillOccurrence] = snapshot.recurringPaymentOccurrenceOverrides.compactMap { occurrence in
            guard occurrence.deletedAt == nil,
                  occurrence.state == .confirmed,
                  let actualDueDate = occurrence.actualDueDate,
                  FinanceEngine.isIsoDate(actualDueDate)
            else { return nil }
            return (occurrence.id, occurrence.paymentId, occurrence.scheduledDueDate, actualDueDate)
        }
        let now = DateUtilities.nowIsoString()
        var changed = false

        for occurrence in rescheduledOccurrences {
            let reversedIds = reverseGeneratedRecurringBillTransactions(
                paymentId: occurrence.paymentId,
                scheduledDueDate: occurrence.scheduledDueDate,
                keepingDueDate: occurrence.actualDueDate
            )
            guard !reversedIds.isEmpty,
                  let overrideIndex = snapshot.recurringPaymentOccurrenceOverrides.firstIndex(where: { $0.id == occurrence.id })
            else { continue }

            snapshot.recurringPaymentOccurrenceOverrides[overrideIndex].reversedGeneratedTransactionIds = Array(Set(
                snapshot.recurringPaymentOccurrenceOverrides[overrideIndex].reversedGeneratedTransactionIds + reversedIds
            )).sorted()
            snapshot.recurringPaymentOccurrenceOverrides[overrideIndex].updatedAt = now
            changed = true
        }

        return changed
    }

    private func removeRecurringBillFundingAllocations(paymentId: String, scheduledDueDate: String, now: String) {
        let linkedAllocations = snapshot.potAllocations.filter {
            $0.deletedAt == nil &&
            $0.recurringPaymentId == paymentId &&
            $0.recurringDueDate == scheduledDueDate
        }

        for allocation in linkedAllocations {
            guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == allocation.potId }) else { continue }
            snapshot.pots[potIndex].balancePence -= abs(allocation.amountPence)
            snapshot.pots[potIndex].updatedAt = now
        }

        let linkedIds = Set(linkedAllocations.map(\.id))
        snapshot.potAllocations.removeAll { linkedIds.contains($0.id) }
    }

    private func moveRecurringBillFundingReferences(paymentId: String, fromDueDate: String, toDueDate: String) {
        guard fromDueDate != toDueDate else { return }
        let destinationPayPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: toDueDate)?.id
        let now = DateUtilities.nowIsoString()

        for index in snapshot.potAllocations.indices where
            snapshot.potAllocations[index].deletedAt == nil &&
            snapshot.potAllocations[index].recurringPaymentId == paymentId &&
            snapshot.potAllocations[index].recurringDueDate == fromDueDate {
            snapshot.potAllocations[index].recurringDueDate = toDueDate
            if let destinationPayPeriodId {
                snapshot.potAllocations[index].payPeriodId = destinationPayPeriodId
            }
            snapshot.potAllocations[index].updatedAt = now
        }

        for index in snapshot.fundingChecklistExclusions.indices where
            snapshot.fundingChecklistExclusions[index].deletedAt == nil &&
            snapshot.fundingChecklistExclusions[index].kind == .recurringBill &&
            snapshot.fundingChecklistExclusions[index].sourceId == paymentId &&
            snapshot.fundingChecklistExclusions[index].occurrenceDate == fromDueDate {
            snapshot.fundingChecklistExclusions[index].occurrenceDate = toDueDate
            if let destinationPayPeriodId {
                snapshot.fundingChecklistExclusions[index].payPeriodId = destinationPayPeriodId
            }
            snapshot.fundingChecklistExclusions[index].updatedAt = now
        }
    }

    @discardableResult
    func addBillGroup(named name: String) -> BillGroup? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        if let existing = activeBillGroups.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }) {
            return existing
        }

        let now = DateUtilities.nowIsoString()
        let colors = AppTheme.selectableColorHexes()
        let color = colors.isEmpty ? AppThemePreset.defaultPreset.palette.accentHex : colors[snapshot.billGroups.count % colors.count]
        let group = BillGroup(
            id: DateUtilities.newId(prefix: "bill-group"),
            name: cleanName,
            color: color,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.billGroups.append(group)
        persist()
        return group
    }

    func assignRecurringPayment(id: String, toBillGroup groupId: String?) {
        guard let index = snapshot.recurringPayments.firstIndex(where: { $0.id == id }) else { return }
        snapshot.recurringPayments[index].billGroupId = normalizedBillGroupId(groupId)
        snapshot.recurringPayments[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func deleteBillGroup(id: String) {
        guard let index = snapshot.billGroups.firstIndex(where: { $0.id == id }) else { return }
        let now = DateUtilities.nowIsoString()
        snapshot.billGroups[index].deletedAt = now
        snapshot.billGroups[index].updatedAt = now

        for paymentIndex in snapshot.recurringPayments.indices where snapshot.recurringPayments[paymentIndex].billGroupId == id {
            snapshot.recurringPayments[paymentIndex].billGroupId = nil
            snapshot.recurringPayments[paymentIndex].updatedAt = now
        }

        persist()
    }

    private func normalizedBillGroupId(_ groupId: String?) -> String? {
        guard let cleanGroupId = groupId?.nilIfBlank,
              snapshot.billGroups.contains(where: { $0.id == cleanGroupId && $0.deletedAt == nil })
        else {
            return nil
        }

        return cleanGroupId
    }

    private func normalizedRecurringPaymentPotId(potId: String?, creditCardId: String?) -> String? {
        let cleanPotId = potId?.nilIfBlank
        guard let cardId = creditCardId?.nilIfBlank else {
            return cleanPotId
        }

        if let cleanPotId,
           snapshot.pots.contains(where: { $0.id == cleanPotId && !$0.archived && $0.linkedCreditCardId == cardId }) {
            return cleanPotId
        }

        return snapshot.pots
            .filter { !$0.archived && $0.linkedCreditCardId == cardId }
            .sorted {
                if $0.name == $1.name {
                    return $0.id < $1.id
                }
                return $0.name < $1.name
            }
            .first?
            .id
    }

    private func normalizedActiveBankAccountId(_ bankAccountId: String?) -> String? {
        guard let cleanId = bankAccountId?.nilIfBlank,
              snapshot.bankAccounts.contains(where: {
                  $0.id == cleanId && !$0.archived && $0.deletedAt == nil
              })
        else { return nil }
        return cleanId
    }

    /// "Money left" is a convenience source, not a second cash balance. Once a
    /// bank account exists, record that spend against the primary account so the
    /// bank balance and Money Left breakdown describe the same movement.
    private func resolvedBankAccountId(
        requestedId: String?,
        paymentMethod: PaymentMethod
    ) -> String? {
        if paymentMethod == .bankAccount {
            return normalizedActiveBankAccountId(requestedId)
        }
        guard paymentMethod == .income else { return nil }
        return snapshot.bankAccounts.first(where: {
            $0.isPrimary && !$0.archived && $0.deletedAt == nil
        })?.id ?? snapshot.bankAccounts.first(where: {
            !$0.archived && $0.deletedAt == nil
        })?.id
    }

    private func transferSourceHasFunds(
        direction: PotBankTransferDirection,
        amountPence: Int,
        bankAccountId: String,
        potBalancePence: Int,
        snapshot: PlannerSnapshot
    ) -> Bool {
        switch direction {
        case .bankToPot:
            guard let account = snapshot.bankAccounts.first(where: { $0.id == bankAccountId }) else { return false }
            return PlannerDerivedData.bankAccountBalance(account: account, snapshot: snapshot) >= amountPence
        case .potToBank:
            return potBalancePence >= amountPence
        }
    }

    private func applyTransferToPot(
        direction: PotBankTransferDirection,
        amountPence: Int,
        potIndex: Int,
        now: String
    ) {
        snapshot.pots[potIndex].balancePence += direction == .bankToPot ? amountPence : -amountPence
        snapshot.pots[potIndex].balancePence = max(0, snapshot.pots[potIndex].balancePence)
        snapshot.pots[potIndex].updatedAt = now
    }

    private func fundingBankAccountId(for potId: String) -> String? {
        let linkedId = snapshot.pots.first(where: { $0.id == potId && !$0.archived })?.fundingBankAccountId
        return normalizedActiveBankAccountId(linkedId)
    }

    private func normalizedLastFourDigits(_ value: String?) -> String? {
        let digits = value?.filter(\.isNumber) ?? ""
        guard !digits.isEmpty else { return nil }
        return String(digits.suffix(4))
    }

    private func clearPrimaryBankAccount(excluding excludedId: String? = nil, now: String) {
        for index in snapshot.bankAccounts.indices where
            snapshot.bankAccounts[index].id != excludedId &&
            snapshot.bankAccounts[index].isPrimary {
            snapshot.bankAccounts[index].isPrimary = false
            snapshot.bankAccounts[index].updatedAt = now
        }
    }

    private func ensurePrimaryBankAccount(now: String) {
        guard !activeBankAccounts.isEmpty,
              !activeBankAccounts.contains(where: \.isPrimary),
              let firstActiveId = activeBankAccounts.first?.id,
              let index = snapshot.bankAccounts.firstIndex(where: { $0.id == firstActiveId })
        else { return }
        snapshot.bankAccounts[index].isPrimary = true
        snapshot.bankAccounts[index].updatedAt = now
    }

    func deleteRecurringPayment(id: String) {
        snapshot.recurringPayments.removeAll { $0.id == id }
        persist()
    }

    func archiveRecurringPayment(id: String) {
        guard let index = snapshot.recurringPayments.firstIndex(where: { $0.id == id }) else { return }
        snapshot.recurringPayments[index].active = false
        snapshot.recurringPayments[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func addCreditCard(
        name: String,
        provider: String,
        limitPence: Int,
        openingBalancePence: Int,
        openingStatementBalancePence: Int?,
        statementDay: Int?,
        dueDay: Int?,
        dueDate: String?,
        color: String
    ) {
        let now = DateUtilities.nowIsoString()
        let statementDate = statementDay.map { day in
            let nextStatementDate = FinanceEngine.monthlyDate(onOrAfter: todayIso, day: day)

            // An entered statement balance belongs to the latest statement that
            // has already been issued. A blank statement balance means the opening
            // balance will feed the next statement cycle instead.
            guard openingStatementBalancePence != nil,
                  nextStatementDate > todayIso
            else {
                return nextStatementDate
            }

            return PlannerDerivedData.addIsoMonthsClamped(date: nextStatementDate, months: -1)
        }
        let card = CreditCard(
            id: DateUtilities.newId(prefix: "card"),
            name: name,
            provider: provider,
            limitPence: limitPence,
            openingBalancePence: openingBalancePence,
            openingStatementBalancePence: openingStatementBalancePence ?? openingBalancePence,
            statementDate: statementDate,
            designId: nil,
            dueDay: dueDay,
            dueDate: dueDate,
            color: color,
            archived: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.creditCards.insert(card, at: 0)
        persist()
    }

    func updateCreditCard(_ card: CreditCard) {
        replace(&snapshot.creditCards, with: card.stamped())
        persist()
    }

    func markCreditCardStatementAwaiting(cardId: String, scheduledStatementDate: String) {
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.statementState = .awaitingConfirmation
            $0.actualStatementDate = nil
        }
    }

    func clearCreditCardStatementAdjustment(cardId: String, scheduledStatementDate: String) {
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.statementState = .normal
            $0.actualStatementDate = nil
        }
    }

    func confirmCreditCardStatement(cardId: String, scheduledStatementDate: String, actualStatementDate: String) {
        guard FinanceEngine.isIsoDate(actualStatementDate) else { return }
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.statementState = .confirmed
            $0.actualStatementDate = actualStatementDate
        }
    }

    func markCreditCardDirectDebitAwaiting(cardId: String, scheduledStatementDate: String) {
        let reversedIds = reverseAutomaticStatementRepayments(cardId: cardId, scheduledStatementDate: scheduledStatementDate)
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.directDebitState = .awaitingPayment
            $0.actualDirectDebitDate = nil
            $0.reversedAutomaticRepaymentIds = Array(Set($0.reversedAutomaticRepaymentIds + reversedIds)).sorted()
        }
    }

    func clearCreditCardDirectDebitAdjustment(cardId: String, scheduledStatementDate: String) {
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.directDebitState = .normal
            $0.actualDirectDebitDate = nil
        }
    }

    func confirmCreditCardDirectDebit(cardId: String, scheduledStatementDate: String, actualDirectDebitDate: String) {
        guard FinanceEngine.isIsoDate(actualDirectDebitDate) else { return }
        let reversedIds = reverseAutomaticStatementRepayments(cardId: cardId, scheduledStatementDate: scheduledStatementDate)
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.directDebitState = .confirmed
            $0.actualDirectDebitDate = actualDirectDebitDate
            $0.reversedAutomaticRepaymentIds = Array(Set($0.reversedAutomaticRepaymentIds + reversedIds)).sorted()
        }
    }

    func setCreditCardCycleAmount(cardId: String, scheduledStatementDate: String, amountPence: Int?) {
        guard amountPence == nil || amountPence! > 0 else { return }
        let reversedIds = reverseAutomaticStatementRepayments(cardId: cardId, scheduledStatementDate: scheduledStatementDate)
        mutateCreditCardCycleOverride(cardId: cardId, scheduledStatementDate: scheduledStatementDate) {
            $0.amountPenceOverride = amountPence
            $0.reversedAutomaticRepaymentIds = Array(Set($0.reversedAutomaticRepaymentIds + reversedIds)).sorted()
        }
    }

    func updateIncomeOccurrence(
        sourceKind: IncomeOccurrenceSourceKind,
        sourceId: String,
        scheduledDate: String,
        state: IncomeOccurrenceState,
        actualDate: String?,
        amountPence: Int?
    ) {
        guard FinanceEngine.isIsoDate(scheduledDate),
              amountPence == nil || amountPence! > 0,
              state != .confirmed || (actualDate.map(FinanceEngine.isIsoDate) ?? false)
        else { return }

        let sourceExists: Bool
        switch sourceKind {
        case .paycheck:
            sourceExists = snapshot.paychecks.contains { $0.id == sourceId && $0.deletedAt == nil } ||
                snapshot.payPeriods.contains { $0.id == sourceId && $0.deletedAt == nil }
        case .oneOffIncome:
            sourceExists = snapshot.oneOffIncomes.contains { $0.id == sourceId && $0.deletedAt == nil }
        }
        guard sourceExists else { return }

        let now = DateUtilities.nowIsoString()
        if let index = snapshot.incomeOccurrenceOverrides.firstIndex(where: {
            $0.deletedAt == nil && $0.sourceKind == sourceKind && $0.sourceId == sourceId && $0.scheduledDate == scheduledDate
        }) {
            snapshot.incomeOccurrenceOverrides[index].state = state
            snapshot.incomeOccurrenceOverrides[index].actualDate = state == .confirmed ? actualDate : nil
            snapshot.incomeOccurrenceOverrides[index].amountPenceOverride = amountPence
            snapshot.incomeOccurrenceOverrides[index].updatedAt = now
        } else {
            snapshot.incomeOccurrenceOverrides.insert(
                IncomeOccurrenceOverride(
                    id: "income-occurrence-override-\(sourceKind.rawValue)-\(sourceId)-\(scheduledDate)",
                    sourceKind: sourceKind,
                    sourceId: sourceId,
                    scheduledDate: scheduledDate,
                    state: state,
                    actualDate: state == .confirmed ? actualDate : nil,
                    amountPenceOverride: amountPence,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )
        }
        persist()
    }

    func requestCreditCardCycleReminderPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    refreshCreditCardCycleReminders()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to enable card-cycle reminders."
                }
            }
        }
    }

    private func mutateCreditCardCycleOverride(
        cardId: String,
        scheduledStatementDate: String,
        mutate: (inout CreditCardCycleOverride) -> Void
    ) {
        guard FinanceEngine.isIsoDate(scheduledStatementDate),
              snapshot.creditCards.contains(where: { $0.id == cardId && !$0.archived })
        else { return }

        let now = DateUtilities.nowIsoString()
        if let index = snapshot.creditCardCycleOverrides.firstIndex(where: {
            $0.creditCardId == cardId && $0.scheduledStatementDate == scheduledStatementDate && $0.deletedAt == nil
        }) {
            mutate(&snapshot.creditCardCycleOverrides[index])
            snapshot.creditCardCycleOverrides[index].updatedAt = now
        } else {
            var override = CreditCardCycleOverride(
                id: "card-cycle-override-\(cardId)-\(scheduledStatementDate)",
                creditCardId: cardId,
                scheduledStatementDate: scheduledStatementDate,
                statementState: .normal,
                actualStatementDate: nil,
                directDebitState: .normal,
                actualDirectDebitDate: nil,
                reversedAutomaticRepaymentIds: [],
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            mutate(&override)
            snapshot.creditCardCycleOverrides.insert(override, at: 0)
        }
        persist()
    }

    private func reverseAutomaticStatementRepayments(
        cardId: String,
        scheduledStatementDate: String,
        keepingDirectDebitDate: String? = nil
    ) -> [String] {
        let now = DateUtilities.nowIsoString()
        let effectiveStatementDate = snapshot.creditCardCycleOverrides.first {
            $0.deletedAt == nil && $0.creditCardId == cardId && $0.scheduledStatementDate == scheduledStatementDate
        }?.actualStatementDate ?? scheduledStatementDate
        let matchingIndices = snapshot.creditCardRepayments.indices.filter { index in
            let repayment = snapshot.creditCardRepayments[index]
            return repayment.deletedAt == nil &&
                repayment.creditCardId == cardId &&
                (repayment.statementDate == scheduledStatementDate || repayment.statementDate == effectiveStatementDate) &&
                (repayment.source == .automaticStatement || repayment.source == .linkedPotStatement) &&
                (keepingDirectDebitDate == nil || (repayment.directDebitDate ?? repayment.date) != keepingDirectDebitDate)
        }

        for index in matchingIndices {
            let repayment = snapshot.creditCardRepayments[index]
            let contributions = repayment.potContributions ?? repayment.potId.map {
                [CreditCardPotContribution(potId: $0, amountPence: repayment.potContributionPence ?? 0)]
            } ?? []
            for contribution in contributions where contribution.amountPence > 0 {
                guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == contribution.potId }) else { continue }
                snapshot.pots[potIndex].balancePence += contribution.amountPence
                snapshot.pots[potIndex].updatedAt = now
            }
            snapshot.creditCardRepayments[index].deletedAt = now
            snapshot.creditCardRepayments[index].updatedAt = now
        }

        return matchingIndices.map { snapshot.creditCardRepayments[$0].id }
    }

    /// Repairs snapshots saved after a generated repayment ran on the scheduled date
    /// but the user subsequently confirmed a different direct-debit date.
    private func reconcileRescheduledAutomaticStatementRepayments() -> Bool {
        typealias RescheduledCycle = (
            id: String,
            cardId: String,
            scheduledStatementDate: String,
            actualDirectDebitDate: String
        )
        let rescheduledCycles: [RescheduledCycle] = snapshot.creditCardCycleOverrides.compactMap { cycle in
            guard cycle.deletedAt == nil,
                  cycle.directDebitState == .confirmed,
                  let actualDirectDebitDate = cycle.actualDirectDebitDate,
                  FinanceEngine.isIsoDate(actualDirectDebitDate)
            else { return nil }
            return (cycle.id, cycle.creditCardId, cycle.scheduledStatementDate, actualDirectDebitDate)
        }
        var changed = false
        let now = DateUtilities.nowIsoString()

        for cycle in rescheduledCycles {
            let reversedIds = reverseAutomaticStatementRepayments(
                cardId: cycle.cardId,
                scheduledStatementDate: cycle.scheduledStatementDate,
                keepingDirectDebitDate: cycle.actualDirectDebitDate
            )
            guard !reversedIds.isEmpty,
                  let overrideIndex = snapshot.creditCardCycleOverrides.firstIndex(where: { $0.id == cycle.id })
            else { continue }

            snapshot.creditCardCycleOverrides[overrideIndex].reversedAutomaticRepaymentIds = Array(Set(
                snapshot.creditCardCycleOverrides[overrideIndex].reversedAutomaticRepaymentIds + reversedIds
            )).sorted()
            snapshot.creditCardCycleOverrides[overrideIndex].updatedAt = now
            changed = true
        }

        return changed
    }

    func archiveCreditCard(id: String) {
        guard let index = snapshot.creditCards.firstIndex(where: { $0.id == id }) else { return }
        snapshot.creditCards[index].archived = true
        snapshot.creditCards[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func deleteCreditCard(id: String) {
        let now = DateUtilities.nowIsoString()
        let hasHistory = snapshot.recurringPayments.contains { $0.creditCardId == id }
            || snapshot.customPayments.contains { $0.creditCardId == id }
            || snapshot.creditCardRepayments.contains { $0.creditCardId == id }
            || snapshot.transactions.contains { $0.creditCardId == id }
            || snapshot.creditCardPots.contains { $0.creditCardId == id }
            || snapshot.pots.contains { $0.linkedCreditCardId == id }

        if hasHistory {
            guard let index = snapshot.creditCards.firstIndex(where: { $0.id == id }) else { return }
            snapshot.creditCards[index].archived = true
            snapshot.creditCards[index].updatedAt = now
            snapshot.creditCards[index].deletedAt = now
        } else {
            snapshot.creditCards.removeAll { $0.id == id }
        }

        persist()
    }

    func recordCardRepayment(cardId: String, amountPence: Int, date: String, note: String) {
        let now = DateUtilities.nowIsoString()
        snapshot.creditCardRepayments.insert(
            CreditCardRepayment(
                id: DateUtilities.newId(prefix: "card-repayment"),
                creditCardId: cardId,
                amountPence: abs(amountPence),
                date: date,
                note: note,
                source: .manual,
                paycheckContributionPence: abs(amountPence),
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
    }

    func updateCardRepayment(id: String, amountPence: Int, date: String, note: String) {
        let amountPence = abs(amountPence)
        guard amountPence > 0,
              FinanceEngine.isIsoDate(date),
              let index = snapshot.creditCardRepayments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              !snapshot.creditCardRepayments[index].hasRefund
        else { return }

        let now = DateUtilities.nowIsoString()
        let existing = snapshot.creditCardRepayments[index]
        var updated = existing

        if existing.source == .automaticStatement || existing.source == .linkedPotStatement {
            let existingContributions = existing.potContributions ?? existing.potId.map {
                [CreditCardPotContribution(potId: $0, amountPence: existing.potContributionPence ?? 0)]
            } ?? []
            for contribution in existingContributions where contribution.amountPence > 0 {
                guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == contribution.potId }) else { continue }
                snapshot.pots[potIndex].balancePence += contribution.amountPence
                snapshot.pots[potIndex].updatedAt = now
            }

            let nextContribution = deductLinkedCreditCardPots(
                creditCardId: existing.creditCardId,
                amountPence: amountPence,
                now: now
            )
            updated.source = nextContribution.amountPence > 0 ? .linkedPotStatement : .automaticStatement
            updated.potId = nextContribution.singlePotId
            updated.potContributionPence = nextContribution.amountPence
            updated.potContributions = nextContribution.potContributions
            updated.paycheckContributionPence = max(0, amountPence - nextContribution.amountPence)
            updated.directDebitDate = date
        } else {
            updated.paycheckContributionPence = amountPence
        }

        updated.amountPence = amountPence
        updated.date = date
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = now
        snapshot.creditCardRepayments[index] = updated

        if let statementDate = existing.statementDate {
            let scheduledStatementDate = snapshot.creditCardCycleOverrides.first {
                $0.deletedAt == nil &&
                    $0.creditCardId == existing.creditCardId &&
                    ($0.scheduledStatementDate == statementDate || $0.actualStatementDate == statementDate)
            }?.scheduledStatementDate ?? statementDate
            mutateCreditCardCycleOverride(
                cardId: existing.creditCardId,
                scheduledStatementDate: scheduledStatementDate
            ) {
                $0.directDebitState = .confirmed
                $0.actualDirectDebitDate = date
            }
        } else {
            persist()
        }
    }

    func setCardRepaymentRefunded(id: String, refunded: Bool) {
        guard let repayment = snapshot.creditCardRepayments.first(where: { $0.id == id }) else { return }
        setCardRepaymentRefundAmount(id: id, amountPence: refunded ? repayment.amountPence : 0)
    }

    func setCardRepaymentRefundAmount(id: String, amountPence: Int) {
        guard let index = snapshot.creditCardRepayments.firstIndex(where: { $0.id == id }),
              snapshot.creditCardRepayments[index].deletedAt == nil
        else { return }
        let refundAmountPence = min(snapshot.creditCardRepayments[index].amountPence, max(0, abs(amountPence)))
        let previousRefundPence = snapshot.creditCardRepayments[index].effectiveRefundedAmountPence
        guard refundAmountPence != previousRefundPence else { return }
        let now = DateUtilities.nowIsoString()
        let repayment = snapshot.creditCardRepayments[index]
        guard adjustPotBalancesForCardRepaymentRefund(
            repayment,
            previousRefundPence: previousRefundPence,
            refundAmountPence: refundAmountPence,
            now: now
        ) else { return }
        snapshot.creditCardRepayments[index].refundedAt = refundAmountPence > 0 ? now : nil
        snapshot.creditCardRepayments[index].refundedAmountPence = refundAmountPence > 0 ? refundAmountPence : nil
        snapshot.creditCardRepayments[index].updatedAt = now
        persist()
    }

    private func adjustPotBalancesForCardRepaymentRefund(
        _ repayment: CreditCardRepayment,
        previousRefundPence: Int,
        refundAmountPence: Int,
        now: String
    ) -> Bool {
        let contributions = repayment.potContributions ?? repayment.potId.map {
            [CreditCardPotContribution(potId: $0, amountPence: repayment.potContributionPence ?? repayment.amountPence)]
        } ?? []
        let previousByPot = proportionalRefundAmounts(
            contributions: contributions,
            paymentAmountPence: repayment.amountPence,
            refundAmountPence: previousRefundPence
        )
        let nextByPot = proportionalRefundAmounts(
            contributions: contributions,
            paymentAmountPence: repayment.amountPence,
            refundAmountPence: refundAmountPence
        )
        let potIds = Set(previousByPot.keys).union(nextByPot.keys)
        let deltasByPot = potIds.reduce(into: [String: Int]()) { result, potId in
            result[potId] = nextByPot[potId, default: 0] - previousByPot[potId, default: 0]
        }
        for (potId, delta) in deltasByPot where delta < 0 {
            guard let index = snapshot.pots.firstIndex(where: { $0.id == potId }),
                  snapshot.pots[index].balancePence >= abs(delta)
            else {
                errorMessage = "Unable to reduce this card-payment refund because its source pot no longer has enough money."
                return false
            }
        }
        for (potId, delta) in deltasByPot where delta != 0 {
            guard let index = snapshot.pots.firstIndex(where: { $0.id == potId }) else { continue }
            snapshot.pots[index].balancePence += delta
            snapshot.pots[index].updatedAt = now
        }
        return true
    }

    private func proportionalRefundAmounts(
        contributions: [CreditCardPotContribution],
        paymentAmountPence: Int,
        refundAmountPence: Int
    ) -> [String: Int] {
        let paymentAmountPence = max(0, paymentAmountPence)
        let refundAmountPence = min(paymentAmountPence, max(0, refundAmountPence))
        guard paymentAmountPence > 0, refundAmountPence > 0 else { return [:] }

        return contributions.reduce(into: [String: Int]()) { result, contribution in
            let contributionAmountPence = max(0, contribution.amountPence)
            let refundedContributionPence: Int
            if refundAmountPence == paymentAmountPence {
                refundedContributionPence = contributionAmountPence
            } else {
                refundedContributionPence = Int(
                    (Double(contributionAmountPence) * Double(refundAmountPence) / Double(paymentAmountPence)).rounded()
                )
            }
            result[contribution.potId, default: 0] += min(contributionAmountPence, refundedContributionPence)
        }
    }

    func addCustomPayment(name: String, amountPence: Int, dueDate: String, creditCardId: String?) {
        let now = DateUtilities.nowIsoString()
        snapshot.customPayments.insert(
            CustomPayment(
                id: DateUtilities.newId(prefix: "custom-payment"),
                name: name,
                amountPence: amountPence,
                dueDate: dueDate,
                creditCardId: creditCardId,
                status: .unpaid,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
    }

    func updateCustomPaymentOccurrence(id: String, amountPence: Int, dueDate: String, status: CustomPaymentStatus) {
        guard amountPence > 0,
              FinanceEngine.isIsoDate(dueDate),
              let index = snapshot.customPayments.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return }
        snapshot.customPayments[index].amountPence = amountPence
        snapshot.customPayments[index].dueDate = dueDate
        snapshot.customPayments[index].status = status
        snapshot.customPayments[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func updateCustomPayment(
        id: String,
        name: String,
        amountPence: Int,
        dueDate: String,
        creditCardId: String?,
        status: CustomPaymentStatus
    ) {
        guard amountPence > 0,
              FinanceEngine.isIsoDate(dueDate),
              let index = snapshot.customPayments.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return }
        snapshot.customPayments[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.customPayments[index].amountPence = amountPence
        snapshot.customPayments[index].dueDate = dueDate
        snapshot.customPayments[index].creditCardId = creditCardId
        snapshot.customPayments[index].status = status
        snapshot.customPayments[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func deleteCustomPayment(id: String) {
        guard let index = snapshot.customPayments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = DateUtilities.nowIsoString()
        snapshot.customPayments[index].deletedAt = now
        snapshot.customPayments[index].updatedAt = now
        persist()
    }

    func addCreditCardPot(cardId: String, name: String, amountPence: Int, source: CreditCardPotSource) {
        let now = DateUtilities.nowIsoString()
        snapshot.creditCardPots.insert(
            CreditCardPot(
                id: DateUtilities.newId(prefix: "credit-card-pot"),
                creditCardId: cardId,
                payPeriodId: selectedPayPeriod?.id,
                payday: selectedPayPeriod?.payday,
                periodStartDate: selectedPayPeriod?.startDate,
                periodEndDate: selectedPayPeriod?.endDate,
                name: name,
                amountPence: abs(amountPence),
                source: source,
                status: .active,
                note: "",
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
    }

    func updateCreditCardPot(
        id: String,
        name: String,
        amountPence: Int,
        source: CreditCardPotSource,
        status: CreditCardPotStatus,
        note: String
    ) {
        guard amountPence > 0,
              let index = snapshot.creditCardPots.firstIndex(where: { $0.id == id && $0.deletedAt == nil })
        else { return }
        snapshot.creditCardPots[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.creditCardPots[index].amountPence = abs(amountPence)
        snapshot.creditCardPots[index].source = source
        snapshot.creditCardPots[index].status = status
        snapshot.creditCardPots[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.creditCardPots[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func deleteCreditCardPot(id: String) {
        guard let index = snapshot.creditCardPots.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        let now = DateUtilities.nowIsoString()
        snapshot.creditCardPots[index].deletedAt = now
        snapshot.creditCardPots[index].updatedAt = now
        persist()
    }

    func addDebt(
        name: String,
        lender: String,
        currentBalancePence: Int,
        minimumPaymentPence: Int,
        dueDate: String,
        apr: Double?,
        note: String,
        linkedPotId: String? = nil,
        type: DebtType = .other,
        interestType: DebtInterestType? = nil,
        fixedFeePence: Int = 0,
        extraPaymentPence: Int = 0,
        repaymentStrategy: DebtRepaymentStrategy? = nil,
        paymentFrequency: DebtPaymentFrequency = .monthly,
        paymentDay: Int? = nil,
        payFirstTiming: DebtPayFirstTiming = .nextPayday,
        customFirstPaymentDate: String? = nil
    ) {
        let now = DateUtilities.nowIsoString()
        let currentBalancePence = max(0, currentBalancePence)
        let debtId = DateUtilities.newId(prefix: "debt")
        let aprBasisPoints = apr.map { Int(($0 * 100).rounded()) }
        snapshot.debts.insert(
            Debt(
                id: debtId,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                lender: lender.trimmingCharacters(in: .whitespacesAndNewlines),
                originalAmountPence: currentBalancePence,
                currentBalancePence: currentBalancePence,
                minimumPaymentPence: max(0, minimumPaymentPence),
                dueDate: dueDate,
                interestRateApr: apr,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                status: currentBalancePence > 0 ? .active : .paidOff,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                type: type,
                startingBalancePence: currentBalancePence,
                targetPayoffDate: dueDate.nilIfBlank,
                interestType: interestType,
                aprBasisPoints: aprBasisPoints,
                interestAccrualMode: interestType == .apr ? .dailyEstimated : nil,
                fixedFeePence: fixedFeePence,
                extraPaymentPence: extraPaymentPence,
                repaymentStrategy: repaymentStrategy,
                paymentFrequency: paymentFrequency,
                paymentDay: paymentDay,
                payFirstTiming: payFirstTiming,
                customFirstPaymentDate: customFirstPaymentDate
            ),
            at: 0
        )
        applyDebtPotLink(debtId: debtId, potId: linkedPotId?.nilIfBlank, now: now)
        regenerateDebtSchedule(debtId: debtId, today: todayIso, now: now)
        persist()
    }

    func updateDebt(_ debt: Debt) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == debt.id }) else { return }
        let now = DateUtilities.nowIsoString()
        let currentBalancePence = max(0, debt.currentBalancePence)
        let originalAmountPence = max(snapshot.debts[index].originalAmountPence, currentBalancePence)
        var updated = debt
        updated.name = debt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.lender = debt.lender.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.originalAmountPence = originalAmountPence
        updated.currentBalancePence = currentBalancePence
        updated.minimumPaymentPence = max(0, debt.minimumPaymentPence)
        updated.note = debt.note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.status = currentBalancePence > 0 ? debt.status : .paidOff
        updated.updatedAt = now
        snapshot.debts[index] = updated
        regenerateDebtSchedule(debtId: debt.id, today: todayIso, now: now)
        persist()
    }

    @discardableResult
    func setDebtLinkedPot(debtId: String, potId: String?) -> Bool {
        guard snapshot.debts.contains(where: { $0.id == debtId && $0.status != .archived }) else { return false }
        let now = DateUtilities.nowIsoString()
        let cleanPotId = potId?.nilIfBlank

        if let cleanPotId, !isEligibleDebtPot(potId: cleanPotId, debtId: debtId) {
            return false
        }

        applyDebtPotLink(debtId: debtId, potId: cleanPotId, now: now)
        persist()
        return true
    }

    func deleteDebt(id: String) {
        let now = DateUtilities.nowIsoString()
        snapshot.debts.removeAll { $0.id == id }
        snapshot.debtPayments.removeAll { $0.debtId == id }
        snapshot.debtReserves.removeAll { $0.debtId == id }
        snapshot.debtPaymentScheduleItems.removeAll { $0.debtId == id }
        snapshot.debtSnapshots.removeAll { $0.debtId == id }
        for index in snapshot.pots.indices where snapshot.pots[index].linkedDebtId == id {
            snapshot.pots[index].linkedDebtId = nil
            snapshot.pots[index].updatedAt = now
        }
        persist()
    }

    func archiveDebt(id: String) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == id }) else { return }
        snapshot.debts[index].status = .archived
        snapshot.debts[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func recordDebtPayment(debtId: String, amountPence: Int, date: String, note: String) {
        recordManualDebtPayment(
            debtId: debtId,
            amountPence: amountPence,
            date: date,
            paymentType: .manualPayNow,
            recalculationMode: .finishEarlier,
            note: note
        )
    }

    func updateDebtScheduleOccurrence(
        scheduleItemId: String,
        debtId: String,
        amountPence: Int,
        dueDate: String,
        status: DebtPaymentScheduleStatus
    ) {
        guard amountPence > 0,
              FinanceEngine.isIsoDate(dueDate),
              let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId && $0.status.isActiveLike })
        else { return }

        if !snapshot.debtPaymentScheduleItems.contains(where: { $0.id == scheduleItemId }),
           let derived = PlannerDerivedData.debtScheduleItems(snapshot: snapshot, payPeriod: nil).first(where: { $0.id == scheduleItemId }) {
            snapshot.debtPaymentScheduleItems.append(derived)
        }
        guard let itemIndex = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == scheduleItemId && $0.debtId == debtId && $0.deletedAt == nil }) else { return }
        let now = DateUtilities.nowIsoString()

        snapshot.debtPaymentScheduleItems[itemIndex].dueDate = dueDate
        snapshot.debtPaymentScheduleItems[itemIndex].plannedAmountPence = amountPence
        snapshot.debtPaymentScheduleItems[itemIndex].principalAmountPence = max(0, amountPence - snapshot.debtPaymentScheduleItems[itemIndex].interestAmountPence - snapshot.debtPaymentScheduleItems[itemIndex].feeAmountPence)
        snapshot.debtPaymentScheduleItems[itemIndex].updatedAt = now

        guard status == .paid else {
            snapshot.debtPaymentScheduleItems[itemIndex].status = status
            persist()
            return
        }
        guard snapshot.debtPaymentScheduleItems[itemIndex].status != .paid else {
            persist()
            return
        }

        let cappedAmount = max(0, amountPence - snapshot.debtPaymentScheduleItems[itemIndex].paidAmountPence)
        guard cappedAmount > 0 else { return }
        let application = DebtPlannerEngine.applyPayment(
            debt: snapshot.debts[debtIndex],
            scheduleItem: snapshot.debtPaymentScheduleItems[itemIndex],
            priorPayments: snapshot.debtPayments,
            amountPence: cappedAmount,
            date: dueDate,
            sourcePotId: nil,
            paymentType: .scheduled,
            note: "Scheduled payment"
        )
        snapshot.debts[debtIndex] = application.debt
        if let updatedItem = application.scheduleItem { replaceDebtScheduleItem(updatedItem) }
        snapshot.debtPayments.insert(
            DebtPayment(
                id: DateUtilities.newId(prefix: "debt-payment"),
                debtId: application.payment.debtId,
                amountPence: application.payment.amountPence,
                date: application.payment.date,
                note: application.payment.note,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sourcePotId: application.payment.sourcePotId,
                paymentType: application.payment.paymentType,
                scheduleItemId: application.payment.scheduleItemId,
                principalPaidPence: application.payment.principalPaidPence,
                interestPaidPence: application.payment.interestPaidPence,
                feePaidPence: application.payment.feePaidPence,
                recalculationMode: .finishEarlier
            ),
            at: 0
        )
        recalculateDebtAfterPayment(debtId: debtId, date: dueDate, mode: .finishEarlier, now: now)
        persist()
    }

    func recordManualDebtPayment(
        debtId: String,
        amountPence: Int,
        date: String,
        paymentType: DebtPaymentType,
        recalculationMode: DebtRecalculationMode,
        note: String
    ) {
        guard amountPence != Int.min, FinanceEngine.isIsoDate(date) else { return }
        let requestedAmountPence = max(0, abs(amountPence))
        guard requestedAmountPence > 0,
              let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId && $0.currentBalancePence > 0 && $0.status.isActiveLike })
        else { return }

        let now = DateUtilities.nowIsoString()
        let linkedPotIndex = snapshot.pots.indices
            .filter { snapshot.pots[$0].linkedDebtId == debtId && !snapshot.pots[$0].archived }
            .sorted { snapshot.pots[$0].name < snapshot.pots[$1].name }
            .first

        let scheduleItem = nextDebtScheduleItem(debtId: debtId, onOrAfter: date)
        let application = DebtPlannerEngine.applyPayment(
            debt: snapshot.debts[debtIndex], scheduleItem: scheduleItem,
            priorPayments: snapshot.debtPayments, amountPence: requestedAmountPence,
            date: date, sourcePotId: linkedPotIndex.map { snapshot.pots[$0].id },
            paymentType: paymentType, note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let cappedAmountPence = paymentType == .manualSetAside
            ? min(requestedAmountPence, max(0, snapshot.debts[debtIndex].currentBalancePence))
            : application.payment.amountPence
        guard cappedAmountPence > 0 else { return }

        if paymentType == .manualSetAside {
            guard let linkedPotIndex else { return }
            let allocationId = "manual-debt-set-aside-\(debtId)-\(date)-\(UUID().uuidString.lowercased())"
            let scheduleItemId = nextDebtScheduleItem(debtId: debtId, onOrAfter: date)?.id
            snapshot.potAllocations.insert(
                PotAllocation(
                    id: allocationId,
                    payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id ?? "",
                    potId: snapshot.pots[linkedPotIndex].id,
                    fundingPotId: nil,
                    bankAccountId: fundingBankAccountId(for: snapshot.pots[linkedPotIndex].id),
                    amountPence: cappedAmountPence,
                    source: .debtFunding,
                    recurringPaymentId: nil,
                    recurringDueDate: nil,
                    debtId: debtId,
                    debtDueDate: date,
                    debtScheduleItemId: scheduleItemId,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )
            snapshot.pots[linkedPotIndex].balancePence += cappedAmountPence
            snapshot.pots[linkedPotIndex].updatedAt = now
            if let scheduleItemId {
                addDebtScheduleFunding(scheduleItemId: scheduleItemId, amountPence: cappedAmountPence, now: now)
            }
            persist()
            return
        }

        var fundingAllocationId: String?
        if let linkedPotIndex {
            let allocationId = "manual-debt-pay-now-\(debtId)-\(date)-\(UUID().uuidString.lowercased())"
            fundingAllocationId = allocationId
            snapshot.potAllocations.insert(
                PotAllocation(
                    id: allocationId,
                    payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id ?? "",
                    potId: snapshot.pots[linkedPotIndex].id,
                    fundingPotId: nil,
                    bankAccountId: fundingBankAccountId(for: snapshot.pots[linkedPotIndex].id),
                    amountPence: cappedAmountPence,
                    source: .debtFunding,
                    recurringPaymentId: nil,
                    recurringDueDate: nil,
                    debtId: debtId,
                    debtDueDate: scheduleItem?.dueDate ?? date,
                    debtScheduleItemId: scheduleItem?.id,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )
            snapshot.pots[linkedPotIndex].balancePence += cappedAmountPence
            snapshot.pots[linkedPotIndex].balancePence -= cappedAmountPence
            snapshot.pots[linkedPotIndex].updatedAt = now
        }

        snapshot.debts[debtIndex] = application.debt
        if let updatedScheduleItem = application.scheduleItem {
            replaceDebtScheduleItem(updatedScheduleItem)
        }
        snapshot.debtPayments.insert(
            DebtPayment(
                id: DateUtilities.newId(prefix: "debt-payment"),
                debtId: application.payment.debtId,
                amountPence: application.payment.amountPence,
                date: application.payment.date,
                note: application.payment.note,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                sourcePotId: application.payment.sourcePotId,
                fundingAllocationId: fundingAllocationId,
                paymentType: application.payment.paymentType,
                scheduleItemId: application.payment.scheduleItemId,
                principalPaidPence: application.payment.principalPaidPence,
                interestPaidPence: application.payment.interestPaidPence,
                feePaidPence: application.payment.feePaidPence,
                recalculationMode: recalculationMode
            ),
            at: 0
        )
        recalculateDebtAfterPayment(debtId: debtId, date: date, mode: recalculationMode, now: now)
        persist()
    }

    func updateDebtPayment(id: String, debtId: String, amountPence: Int, date: String, note: String) {
        guard amountPence != Int.min, FinanceEngine.isIsoDate(date),
              let paymentIndex = snapshot.debtPayments.firstIndex(where: { $0.id == id && $0.deletedAt == nil }),
              snapshot.debts.contains(where: { $0.id == debtId }) else { return }
        let requested = abs(amountPence)
        let previous = snapshot.debtPayments[paymentIndex]
        guard requested > 0, !previous.hasRefund else { return }
        let now = DateUtilities.nowIsoString()
        if hasUnknownDebtFunding(previous) {
            guard debtId == previous.debtId, requested == previous.amountPence else {
                errorMessage = "This older payment has an unknown pot split. Review its funding before changing the amount or debt."
                return
            }
            snapshot.debtPayments[paymentIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            snapshot.debtPayments[paymentIndex].date = date
            snapshot.debtPayments[paymentIndex].updatedAt = now
            snapshot.debtPayments[paymentIndex].potContributions = [] // Explicit unknown split survives note edits.
            persist()
            return
        }
        let fundingAllocationIndex: Int?
        switch manualDebtFundingMatch(for: previous) {
        case .none: fundingAllocationIndex = nil
        case .matched(let index): fundingAllocationIndex = index
        case .invalid:
            errorMessage = "This payment's funding cannot be matched safely. Review its allocation before editing it."
            return
        }
        let before = snapshot
        restoreDebtPaymentAmount(previous, now: now)
        reconcileDebtScheduleAfterReversal(previous, from: previous.netAmountPence, to: 0, now: now)
        guard let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }
        let schedule = previous.debtId == debtId
            ? snapshot.debtPaymentScheduleItems.first(where: { $0.id == previous.scheduleItemId })
            : nextDebtScheduleItem(debtId: debtId, onOrAfter: date)
        let application = DebtPlannerEngine.applyPayment(
            debt: snapshot.debts[debtIndex], scheduleItem: schedule,
            priorPayments: snapshot.debtPayments.filter { $0.id != id }, amountPence: requested,
            date: date, sourcePotId: previous.sourcePotId, paymentType: previous.paymentType,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard application.payment.amountPence > 0 else { snapshot = before; return }
        var payment = application.payment
        payment.id = previous.id
        payment.createdAt = previous.createdAt
        payment.updatedAt = now
        payment.recalculationMode = previous.recalculationMode
        if let contributions = previous.potContributions {
            payment.potContributions = apportionedDebtFunding(contributions, total: payment.amountPence)
        }
        if let allocationIndex = fundingAllocationIndex {
            // Pay now creates and spends the same funding. Correct both records
            // together; their cash changes cancel and leave existing pot funds intact.
            payment.fundingAllocationId = snapshot.potAllocations[allocationIndex].id
            snapshot.potAllocations[allocationIndex].amountPence = payment.amountPence
            snapshot.potAllocations[allocationIndex].payPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id ?? ""
            snapshot.potAllocations[allocationIndex].debtId = debtId
            snapshot.potAllocations[allocationIndex].debtDueDate = schedule?.dueDate ?? date
            snapshot.potAllocations[allocationIndex].debtScheduleItemId = payment.scheduleItemId
            snapshot.potAllocations[allocationIndex].updatedAt = now
        } else {
            applyDebtPaymentCashChange(previous, from: previous.netAmountPence, to: 0, now: now)
            applyDebtPaymentCashChange(payment, from: 0, to: payment.netAmountPence, now: now)
        }
        snapshot.debtPayments[paymentIndex] = payment
        snapshot.debts[debtIndex] = application.debt
        if let item = application.scheduleItem { replaceDebtScheduleItem(item) }
        recalculateDebtAfterPayment(debtId: debtId, date: date, mode: payment.recalculationMode ?? .finishEarlier, now: now)
        if previous.debtId != debtId {
            updateDebtStatus(debtId: previous.debtId, asOf: todayIso, now: now)
        }
        persist()
    }

    func deleteDebtPayment(id: String) {
        guard let paymentIndex = snapshot.debtPayments.firstIndex(where: { $0.id == id }) else { return }
        let now = DateUtilities.nowIsoString()
        guard snapshot.debtPayments[paymentIndex].deletedAt == nil else { return }
        let payment = snapshot.debtPayments[paymentIndex]
        restoreDebtPaymentAmount(payment, now: now)
        applyDebtPaymentCashChange(payment, from: payment.netAmountPence, to: 0, now: now)
        snapshot.debtPayments[paymentIndex].deletedAt = now
        snapshot.debtPayments[paymentIndex].updatedAt = now
        reconcileDebtScheduleAfterReversal(payment, from: payment.netAmountPence, to: 0, now: now)
        persist()
    }

    func setDebtPaymentRefunded(id: String, refunded: Bool) {
        guard let payment = snapshot.debtPayments.first(where: { $0.id == id }) else { return }
        setDebtPaymentRefundAmount(id: id, amountPence: refunded ? payment.amountPence : 0)
    }

    func setDebtPaymentRefundAmount(id: String, amountPence: Int) {
        guard amountPence != Int.min else { return }
        guard let index = snapshot.debtPayments.firstIndex(where: { $0.id == id }),
              snapshot.debtPayments[index].deletedAt == nil
        else { return }
        let refundAmountPence = min(snapshot.debtPayments[index].amountPence, max(0, abs(amountPence)))
        let previousRefundPence = snapshot.debtPayments[index].effectiveRefundedAmountPence
        guard refundAmountPence != previousRefundPence else { return }
        let now = DateUtilities.nowIsoString()
        let payment = snapshot.debtPayments[index]
        snapshot.debtPayments[index].refundedAt = refundAmountPence > 0 ? now : nil
        snapshot.debtPayments[index].refundedAmountPence = refundAmountPence > 0 ? refundAmountPence : nil
        snapshot.debtPayments[index].updatedAt = now
        let principalDelta = payment.effectivePrincipalPaidPence - snapshot.debtPayments[index].effectivePrincipalPaidPence
        if principalDelta > 0 {
            restoreDebtAmount(debtId: payment.debtId, amountPence: principalDelta, now: now)
        } else if principalDelta < 0 {
            applyDebtPaymentAmount(debtId: payment.debtId, amountPence: -principalDelta, now: now)
        }
        applyDebtPaymentCashChange(payment, from: payment.netAmountPence, to: snapshot.debtPayments[index].netAmountPence, now: now)
        reconcileDebtScheduleAfterReversal(payment, from: payment.netAmountPence, to: snapshot.debtPayments[index].netAmountPence, now: now)
        persist()
    }

    func addDebtReserve(debtId: String, amountPence: Int, note: String) {
        let now = DateUtilities.nowIsoString()
        let period = selectedPayPeriod
        snapshot.debtReserves.insert(
            DebtReserve(
                id: DateUtilities.newId(prefix: "debt-reserve"),
                debtId: debtId,
                payPeriodId: period?.id,
                payday: period?.payday ?? todayIso,
                periodStartDate: period?.startDate ?? todayIso,
                periodEndDate: period?.endDate ?? todayIso,
                amountPence: abs(amountPence),
                status: .planned,
                source: .manual,
                note: note,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
    }

    @discardableResult
    func addPotAllocation(potId: String, amountPence: Int, source: PotAllocationSource = .manual, recurringPaymentId: String? = nil, recurringDueDate: String? = nil) -> Bool {
        let amount = abs(amountPence)
        guard amount > 0, snapshot.pots.contains(where: { $0.id == potId }) else { return false }
        let now = DateUtilities.nowIsoString()

        guard let period = selectedPayPeriod else {
            snapshot.transactions.insert(
                Transaction(
                    id: DateUtilities.newId(prefix: "transaction"),
                    potId: potId,
                    payPeriodId: nil,
                    amountPence: amount,
                    type: .allocation,
                    paymentMethod: .pot,
                    creditCardId: nil,
                    bankAccountId: fundingBankAccountId(for: potId),
                    recurringPaymentId: recurringPaymentId,
                    date: todayIso,
                    note: "Pot top-up",
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )

            if let index = snapshot.pots.firstIndex(where: { $0.id == potId }) {
                snapshot.pots[index] = FinanceEngine.applyTransactionToPot(snapshot.pots[index], amountPence: amount, type: .allocation)
            }

            persist()
            return true
        }

        snapshot.potAllocations.insert(
            PotAllocation(
                id: DateUtilities.newId(prefix: "allocation"),
                payPeriodId: period.id,
                potId: potId,
                fundingPotId: nil,
                bankAccountId: fundingBankAccountId(for: potId),
                amountPence: amount,
                source: source,
                recurringPaymentId: recurringPaymentId,
                recurringDueDate: recurringDueDate,
                debtId: nil,
                debtDueDate: nil,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )

        if let index = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            snapshot.pots[index].balancePence += amount
            snapshot.pots[index].updatedAt = now
        }

        persist()
        return true
    }

    @discardableResult
    func deleteManualPotAllocation(id: String) -> Bool {
        guard let index = snapshot.potAllocations.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else {
            return false
        }

        let allocation = snapshot.potAllocations[index]
        guard (allocation.source ?? .manual) == .manual,
              allocation.fundingPotId == nil,
              allocation.recurringPaymentId == nil,
              allocation.debtId == nil
        else { return false }

        snapshot.potAllocations.remove(at: index)
        if let potIndex = snapshot.pots.firstIndex(where: { $0.id == allocation.potId }) {
            snapshot.pots[potIndex].balancePence -= abs(allocation.amountPence)
            snapshot.pots[potIndex].updatedAt = DateUtilities.nowIsoString()
        }
        persist()
        return true
    }

    @discardableResult
    func setCardBillFundingCompleted(paymentId: String, dueDate: String, payPeriodId: String, completed: Bool) -> Bool {
        setRecurringBillFundingCompleted(
            paymentId: paymentId,
            dueDate: dueDate,
            payPeriodId: payPeriodId,
            completed: completed
        )
    }

    @discardableResult
    func setRecurringBillFundingCompleted(paymentId: String, dueDate: String, payPeriodId: String, completed: Bool) -> Bool {
        let payPeriod = fundingChecklistPayPeriod(id: payPeriodId)
        let duePeriodItems = PlannerDerivedData.recurringBillFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            groupByFundingDueDate: true
        )
        let item = duePeriodItems.first(where: { $0.paymentId == paymentId && $0.dueDate == dueDate })
            ?? PlannerDerivedData.recurringBillFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: payPeriod
            ).first(where: { $0.paymentId == paymentId && $0.dueDate == dueDate })
        guard let item else {
            return false
        }

        if completed {
            return completeRecurringBillFunding(item)
        }

        return reverseRecurringBillFunding(item)
    }

    @discardableResult
    func setCardSpendFundingCompleted(transactionId: String, payPeriodId: String, completed: Bool) -> Bool {
        let payPeriod = fundingChecklistPayPeriod(id: payPeriodId)
        let duePeriodItems = PlannerDerivedData.cardSpendFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            groupByFundingDueDate: true
        )
        let item = duePeriodItems.first(where: { $0.transactionId == transactionId })
            ?? PlannerDerivedData.cardSpendFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: payPeriod
            ).first(where: { $0.transactionId == transactionId })
        guard let item else {
            return false
        }

        if completed {
            return completeCardSpendFunding(item)
        }

        return reverseCardSpendFunding(item)
    }

    @discardableResult
    func setCardOpeningBalanceFundingCompleted(cardId: String, directDebitDate: String, payPeriodId: String, completed: Bool) -> Bool {
        let items = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: fundingChecklistPayPeriod(id: payPeriodId)
        )
        guard let item = items.first(where: { $0.cardId == cardId && $0.directDebitDate == directDebitDate }) else {
            return false
        }

        if completed {
            return completeCardOpeningBalanceFunding(item)
        }

        return reverseCardOpeningBalanceFunding(item)
    }

    @discardableResult
    func setCardPaymentFundingCompleted(
        cardId: String,
        potId: String,
        directDebitDate: String,
        payPeriodId: String,
        completed: Bool
    ) -> Bool {
        let payPeriod = fundingChecklistPayPeriod(id: payPeriodId)
        let duePeriodItems = PlannerDerivedData.cardPaymentFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: payPeriod,
            asOfDate: todayIso,
            groupByFundingDueDate: true
        )
        let matchesItem: (CreditCardPaymentFundingChecklistItem) -> Bool = {
            $0.cardId == cardId &&
            $0.potId == potId &&
            $0.directDebitDate == directDebitDate
        }
        let item = duePeriodItems.first(where: matchesItem)
            ?? PlannerDerivedData.cardPaymentFundingChecklistItems(
                snapshot: snapshot,
                payPeriod: payPeriod,
                asOfDate: todayIso
            ).first(where: matchesItem)
        guard let item else { return false }

        if completed {
            return completeCardPaymentFunding(item)
        }

        return reverseCardPaymentFunding(item)
    }

    @discardableResult
    func setDebtFundingCompleted(debtId: String, dueDate: String, payPeriodId: String, completed: Bool) -> Bool {
        let items = PlannerDerivedData.debtFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: fundingChecklistPayPeriod(id: payPeriodId)
        )
        guard let item = items.first(where: { $0.debtId == debtId && $0.dueDate == dueDate }) else {
            return false
        }

        if completed {
            return completeDebtFunding(item)
        }

        return reverseDebtFunding(item)
    }

    @discardableResult
    func setDebtFundingCompleted(scheduleItemId: String, payPeriodId: String, completed: Bool) -> Bool {
        let items = PlannerDerivedData.debtFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: fundingChecklistPayPeriod(id: payPeriodId)
        )
        guard let item = items.first(where: { $0.scheduleItemId == scheduleItemId }) else {
            return false
        }

        if completed {
            return completeDebtFunding(item)
        }

        return reverseDebtFunding(item)
    }

    @discardableResult
    func setFundingChecklistCompleted(action: FundingChecklistAction, completed: Bool) -> Bool {
        let succeeded: Bool
        switch action {
        case .recurringBill(let paymentId, let dueDate, let payPeriodId):
            succeeded = setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: completed)
        case .cardBill(let paymentId, let dueDate, let payPeriodId):
            succeeded = setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: completed)
        case .cardSpend(let transactionId, let payPeriodId):
            succeeded = setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: completed)
        case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
            succeeded = setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: completed)
        case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
            succeeded = setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: completed)
        case .debt(let debtId, let dueDate, let payPeriodId):
            succeeded = setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: completed)
        }

        if completed, succeeded {
            removeFundingChecklistExclusion(for: action, shouldPersist: true)
        }
        return succeeded
    }

    @discardableResult
    func setFundingChecklistExcluded(action: FundingChecklistAction, excluded: Bool) -> Bool {
        guard let identity = fundingChecklistExclusionIdentity(for: action) else { return false }

        if !excluded {
            removeFundingChecklistExclusion(for: action, shouldPersist: true)
            return true
        }

        guard setFundingChecklistCompleted(action: action, completed: false) else { return false }

        let now = DateUtilities.nowIsoString()
        snapshot.fundingChecklistExclusions.removeAll {
            $0.kind == identity.kind &&
            $0.sourceId == identity.sourceId &&
            $0.occurrenceDate == identity.occurrenceDate
        }
        snapshot.fundingChecklistExclusions.insert(
            FundingChecklistExclusion(
                id: fundingChecklistExclusionId(identity),
                kind: identity.kind,
                sourceId: identity.sourceId,
                occurrenceDate: identity.occurrenceDate,
                payPeriodId: identity.payPeriodId,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
        return true
    }

    private func fundingChecklistPayPeriod(id: String) -> PayPeriod? {
        if let savedPeriod = snapshot.payPeriods.first(where: { $0.id == id && $0.deletedAt == nil }) {
            return savedPeriod
        }

        return PlannerDerivedData.projectedFundingPayPeriods(
            snapshot: snapshot,
            startingAt: selectedPayPeriod,
            count: 24
        )
        .first { $0.id == id }
    }

    @discardableResult
    func applyDueLinkedPotObligations(asOf todayIso: String, recurringStartDate: String? = nil) -> Bool {
        var changed = false
        if recurringStartDate == nil {
            changed = reconcileRescheduledAutomaticStatementRepayments() || changed
            changed = reconcileRescheduledGeneratedRecurringBillTransactions() || changed
        }
        changed = applyDueRecurringPotPayments(asOf: todayIso, startingAt: recurringStartDate) || changed
        changed = applyDueBankAccountRecurringPayments(asOf: todayIso, startingAt: recurringStartDate) || changed
        changed = applyDueCreditCardRecurringPayments(asOf: todayIso, startingAt: recurringStartDate) || changed
        changed = applyDueCreditCardOpeningBalanceRepayments(asOf: todayIso) || changed
        changed = applyDueCreditCardStatementRepayments(asOf: todayIso) || changed
        changed = applyDueLinkedDebtPotPayments(asOf: todayIso) || changed
        return changed
    }

    private func applyDueBankAccountRecurringPayments(asOf todayIso: String, startingAt: String? = nil) -> Bool {
        let now = DateUtilities.nowIsoString()
        let bankPayments = snapshot.recurringPayments.filter { payment in
            payment.active &&
                payment.creditCardId == nil &&
                payment.potId == nil &&
                normalizedActiveBankAccountId(payment.bankAccountId) != nil
        }
        var changed = false

        for payment in bankPayments {
            let startDate = max(recurringApplicationStartDate(payment, todayIso: todayIso), startingAt ?? "0001-01-01")
            let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(
                snapshot: snapshot,
                payments: [payment],
                startDate: startDate,
                endDate: todayIso
            )

            for occurrence in occurrences {
                guard !occurrence.isAwaitingPayment,
                      occurrence.amountPence > 0,
                      let bankAccountId = normalizedActiveBankAccountId(payment.bankAccountId)
                else { continue }

                let transactionId = recurringTransactionId(
                    paymentId: payment.id,
                    scheduledDueDate: occurrence.scheduledDueDate
                )
                let ledgerAmounts = recurringTransactionLedgerAmounts(
                    payment: payment,
                    scheduledDueDate: occurrence.scheduledDueDate
                )
                if let existingIndex = snapshot.transactions.firstIndex(where: {
                    $0.id == transactionId && $0.deletedAt == nil
                }) {
                    if synchronizeRecurringTransactionLedger(
                        at: existingIndex,
                        grossAmountPence: ledgerAmounts.gross,
                        refundedAmountPence: ledgerAmounts.refunded,
                        refundedAt: ledgerAmounts.refundedAt,
                        now: now
                    ) {
                        changed = true
                    }
                    continue
                }

                snapshot.transactions.insert(
                    Transaction(
                        id: transactionId,
                        potId: nil,
                        payPeriodId: PlannerDerivedData.findPayPeriod(
                            payPeriods: snapshot.payPeriods,
                            date: occurrence.dueDate
                        )?.id,
                        amountPence: ledgerAmounts.gross,
                        type: .spending,
                        paymentMethod: .bankAccount,
                        creditCardId: nil,
                        bankAccountId: bankAccountId,
                        recurringPaymentId: payment.id,
                        date: occurrence.dueDate,
                        note: payment.name,
                        refundedAt: ledgerAmounts.refundedAt,
                        refundedAmountPence: ledgerAmounts.refunded > 0 ? ledgerAmounts.refunded : nil,
                        createdAt: now,
                        updatedAt: now,
                        deletedAt: nil
                    ),
                    at: 0
                )
                changed = true
            }
        }

        return changed
    }

    private func applyDueRecurringPotPayments(asOf todayIso: String, startingAt: String? = nil) -> Bool {
        let now = DateUtilities.nowIsoString()
        let directPayments = snapshot.recurringPayments.filter { payment in
            payment.active && payment.creditCardId == nil && payment.potId != nil
        }
        var changed = false

        for payment in directPayments {
            let startDate = max(recurringApplicationStartDate(payment, todayIso: todayIso), startingAt ?? "0001-01-01")
            let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(snapshot: snapshot, payments: [payment], startDate: startDate, endDate: todayIso)

            for occurrence in occurrences {
                guard !occurrence.isAwaitingPayment else { continue }
                let transactionId = recurringTransactionId(paymentId: payment.id, scheduledDueDate: occurrence.scheduledDueDate)
                let ledgerAmounts = recurringTransactionLedgerAmounts(
                    payment: payment,
                    scheduledDueDate: occurrence.scheduledDueDate
                )

                if let existingIndex = snapshot.transactions.firstIndex(where: {
                    $0.id == transactionId && $0.deletedAt == nil
                }) {
                    if synchronizeRecurringTransactionLedger(
                        at: existingIndex,
                        grossAmountPence: ledgerAmounts.gross,
                        refundedAmountPence: ledgerAmounts.refunded,
                        refundedAt: ledgerAmounts.refundedAt,
                        now: now
                    ) {
                        changed = true
                    }
                    continue
                }

                guard let potId = payment.potId,
                      let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId && !$0.archived }),
                      occurrence.amountPence > 0
                else { continue }

                snapshot.transactions.insert(
                    Transaction(
                        id: transactionId,
                        potId: potId,
                        payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: occurrence.dueDate)?.id,
                        amountPence: ledgerAmounts.gross,
                        type: .spending,
                        paymentMethod: .pot,
                        creditCardId: nil,
                        recurringPaymentId: payment.id,
                        date: occurrence.dueDate,
                        note: payment.name,
                        refundedAt: ledgerAmounts.refundedAt,
                        refundedAmountPence: ledgerAmounts.refunded > 0 ? ledgerAmounts.refunded : nil,
                        createdAt: now,
                        updatedAt: now,
                        deletedAt: nil
                    ),
                    at: 0
                )
                snapshot.pots[potIndex] = FinanceEngine.applyTransactionToPot(snapshot.pots[potIndex], amountPence: occurrence.amountPence, type: .spending)
                changed = true
            }
        }

        return changed
    }

    private func applyDueCreditCardRecurringPayments(asOf todayIso: String, startingAt: String? = nil) -> Bool {
        let now = DateUtilities.nowIsoString()
        let cardPayments = snapshot.recurringPayments.filter { payment in
            payment.active && payment.creditCardId != nil
        }
        var changed = false

        for payment in cardPayments {
            let startDate = max(recurringApplicationStartDate(payment, todayIso: todayIso), startingAt ?? "0001-01-01")
            let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(snapshot: snapshot, payments: [payment], startDate: startDate, endDate: todayIso)

            for occurrence in occurrences {
                guard let cardId = payment.creditCardId,
                      snapshot.creditCards.contains(where: { $0.id == cardId && !$0.archived }),
                      occurrence.amountPence > 0,
                      !occurrence.isAwaitingPayment
                else { continue }

                let transactionId = cardRecurringTransactionId(paymentId: payment.id, scheduledDueDate: occurrence.scheduledDueDate)
                let ledgerAmounts = recurringTransactionLedgerAmounts(
                    payment: payment,
                    scheduledDueDate: occurrence.scheduledDueDate
                )
                if let existingTransactionIndex = cardRecurringTransactionIndex(
                    transactionId: transactionId,
                    paymentId: payment.id,
                    scheduledDueDate: occurrence.scheduledDueDate,
                    cardId: cardId
                ) {
                    if snapshot.transactions[existingTransactionIndex].date != occurrence.dueDate {
                        snapshot.transactions[existingTransactionIndex].date = occurrence.dueDate
                        snapshot.transactions[existingTransactionIndex].payPeriodId = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: occurrence.dueDate)?.id
                        snapshot.transactions[existingTransactionIndex].updatedAt = now
                        changed = true
                    }
                    if snapshot.transactions[existingTransactionIndex].potId == nil,
                       let potId = fundedCardBillPotId(payment: payment, occurrence: occurrence) {
                        snapshot.transactions[existingTransactionIndex].potId = potId
                        snapshot.transactions[existingTransactionIndex].updatedAt = now
                        changed = true
                    }
                    if synchronizeRecurringTransactionLedger(
                        at: existingTransactionIndex,
                        grossAmountPence: ledgerAmounts.gross,
                        refundedAmountPence: ledgerAmounts.refunded,
                        refundedAt: ledgerAmounts.refundedAt,
                        now: now
                    ) {
                        changed = true
                    }
                    continue
                }

                snapshot.transactions.insert(
                    Transaction(
                        id: transactionId,
                        potId: fundedCardBillPotId(payment: payment, occurrence: occurrence),
                        payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: occurrence.dueDate)?.id,
                        amountPence: ledgerAmounts.gross,
                        type: .spending,
                        paymentMethod: .creditCard,
                        creditCardId: cardId,
                        recurringPaymentId: payment.id,
                        date: occurrence.dueDate,
                        note: payment.name,
                        refundedAt: ledgerAmounts.refundedAt,
                        refundedAmountPence: ledgerAmounts.refunded > 0 ? ledgerAmounts.refunded : nil,
                        createdAt: now,
                        updatedAt: now,
                        deletedAt: nil
                    ),
                    at: 0
                )
                changed = true
            }
        }

        return changed
    }

    private func fundedCardBillPotId(
        payment: RecurringPayment,
        occurrence: RecurringPaymentOccurrence
    ) -> String? {
        guard let potId = payment.potId,
              snapshot.pots.contains(where: { $0.id == potId && !$0.archived })
        else { return nil }

        let fundedPence = snapshot.potAllocations
            .filter {
                $0.deletedAt == nil &&
                $0.potId == potId &&
                isRecurringBillFundingSource($0.source) &&
                $0.recurringPaymentId == payment.id &&
                $0.recurringDueDate == occurrence.dueDate
            }
            .reduce(0) { $0 + max(0, $1.amountPence) }

        return fundedPence >= occurrence.amountPence ? potId : nil
    }

    private func applyDueCreditCardStatementRepayments(asOf todayIso: String) -> Bool {
        let now = DateUtilities.nowIsoString()
        var changed = false

        for card in snapshot.creditCards.filter({ !$0.archived }) {
            let startDate = card.createdAt.isoDatePrefix ?? todayIso
            let statementPayments = PlannerDerivedData.creditCardStatementPayments(
                card: card,
                snapshot: snapshot,
                startDate: startDate,
                endDate: todayIso,
                asOfDate: todayIso,
                includeCycle: { statementDate, directDebitDate in
                    !self.hasCreditCardStatementRepayment(creditCardId: card.id, statementDate: statementDate, directDebitDate: directDebitDate)
                }
            )

            for statementPayment in statementPayments {
                let repaymentId = creditCardStatementRepaymentId(
                    creditCardId: card.id,
                    statementDate: statementPayment.statementDate,
                    dueDate: statementPayment.directDebitDate
                )

                if hasCreditCardStatementRepayment(
                    creditCardId: card.id,
                    statementDate: statementPayment.statementDate,
                    directDebitDate: statementPayment.directDebitDate
                ) {
                    continue
                }

                let cardSummary = PlannerDerivedData.creditCardOwedSummary(
                    card: card,
                    snapshot: snapshot,
                    payPeriod: nil,
                    asOfDate: statementPayment.directDebitDate
                )
                let repaymentAmountPence: Int
                switch statementPayment.amountSource {
                case .confirmedBankAmount:
                    // A confirmed cycle amount is the bank's cash obligation even
                    // when the app does not contain every underlying transaction.
                    repaymentAmountPence = statementPayment.actualDuePence
                case .calculated:
                    repaymentAmountPence = min(
                        statementPayment.actualDuePence,
                        cardSummary.actualOwedPence
                    )
                }

                guard repaymentAmountPence > 0 else { continue }

                let linkedPotContribution = deductLinkedCreditCardPots(
                    creditCardId: card.id,
                    amountPence: repaymentAmountPence,
                    now: now
                )
                let paycheckContributionPence = max(0, repaymentAmountPence - linkedPotContribution.amountPence)
                let source: CreditCardRepaymentSource = linkedPotContribution.amountPence > 0 ? .linkedPotStatement : .automaticStatement

                snapshot.creditCardRepayments.insert(
                    CreditCardRepayment(
                        id: repaymentId,
                        creditCardId: card.id,
                        amountPence: repaymentAmountPence,
                        date: statementPayment.directDebitDate,
                        note: creditCardStatementRepaymentNote(cardName: card.name, linkedPotContribution: linkedPotContribution),
                        statementDate: statementPayment.statementDate,
                        directDebitDate: statementPayment.directDebitDate,
                        source: source,
                        potId: linkedPotContribution.singlePotId,
                        potContributionPence: linkedPotContribution.amountPence,
                        potContributions: linkedPotContribution.potContributions,
                        paycheckContributionPence: paycheckContributionPence,
                        createdAt: now,
                        updatedAt: now,
                        deletedAt: nil
                    ),
                    at: 0
                )
                changed = true
            }
        }

        return changed
    }

    private func applyDueCreditCardOpeningBalanceRepayments(asOf todayIso: String) -> Bool {
        let now = DateUtilities.nowIsoString()
        var changed = false

        for card in snapshot.creditCards.filter({ !$0.archived }) {
            let openingStatementPence = max(0, card.openingStatementBalancePence ?? card.openingBalancePence ?? 0)
            guard openingStatementPence > 0,
                  let statementDate = card.statementDate,
                  FinanceEngine.isIsoDate(statementDate),
                  let directDebitDate = PlannerDerivedData.creditCardOpeningBalanceDirectDebitDate(card: card, today: todayIso),
                  directDebitDate <= todayIso
            else { continue }
            guard !snapshot.creditCardRepayments.contains(where: {
                $0.deletedAt == nil &&
                $0.creditCardId == card.id &&
                $0.statementDate == statementDate &&
                $0.amountPence > 0
            }) else { continue }
            if let dueDay = card.dueDay,
               PlannerDerivedData.creditCardDirectDebitDate(statementDate: statementDate, dueDay: dueDay) == directDebitDate {
                continue
            }

            let repaymentId = creditCardOpeningBalanceRepaymentId(creditCardId: card.id, directDebitDate: directDebitDate)
            guard !snapshot.creditCardRepayments.contains(where: { $0.id == repaymentId }) else { continue }

            let cardSummary = PlannerDerivedData.creditCardOwedSummary(
                card: card,
                snapshot: snapshot,
                payPeriod: nil,
                asOfDate: directDebitDate
            )
            let repaymentAmountPence = min(openingStatementPence, cardSummary.actualOwedPence)
            guard repaymentAmountPence > 0 else { continue }

            let linkedPotContribution = deductLinkedCreditCardPots(
                creditCardId: card.id,
                amountPence: repaymentAmountPence,
                now: now
            )
            let paycheckContributionPence = repaymentAmountPence - linkedPotContribution.amountPence
            let source: CreditCardRepaymentSource = linkedPotContribution.amountPence > 0 ? .linkedPotStatement : .automaticStatement

            snapshot.creditCardRepayments.insert(
                CreditCardRepayment(
                    id: repaymentId,
                    creditCardId: card.id,
                    amountPence: repaymentAmountPence,
                    date: directDebitDate,
                    note: creditCardStatementRepaymentNote(cardName: card.name, linkedPotContribution: linkedPotContribution),
                    statementDate: card.statementDate,
                    directDebitDate: directDebitDate,
                    source: source,
                    potId: linkedPotContribution.singlePotId,
                    potContributionPence: linkedPotContribution.amountPence,
                        potContributions: linkedPotContribution.potContributions,
                    paycheckContributionPence: paycheckContributionPence,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )
            changed = true
        }

        return changed
    }

    private func applyDueLinkedDebtPotPayments(asOf todayIso: String) -> Bool {
        let now = DateUtilities.nowIsoString()
        var changed = false
        changed = ensureDebtSchedules(today: todayIso) || changed

        let dueItems = snapshot.debtPaymentScheduleItems
            .filter {
                $0.deletedAt == nil &&
                $0.status != .paid &&
                $0.status != .cancelled &&
                $0.plannedAmountPence > 0 &&
                $0.dueDate <= todayIso
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return $0.id < $1.id
                }
                return $0.dueDate < $1.dueDate
            }

        for item in dueItems {
            guard let debtIndex = snapshot.debts.firstIndex(where: { $0.id == item.debtId && $0.status.isActiveLike && $0.currentBalancePence > 0 }) else { continue }
            let debt = snapshot.debts[debtIndex]
            let linkedPotIndices = snapshot.pots.indices
                .filter { index in
                    let pot = snapshot.pots[index]
                    return !pot.archived && pot.linkedDebtId == debt.id && pot.balancePence > 0
                }
                .sorted { snapshot.pots[$0].name < snapshot.pots[$1].name }

            guard !linkedPotIndices.isEmpty else { continue }

            let paymentId = linkedDebtPotPaymentId(debtId: debt.id, dueDate: item.dueDate)
            guard !snapshot.debtPayments.contains(where: { $0.id == paymentId }) else { continue }
            guard !snapshot.debtPayments.contains(where: {
                $0.scheduleItemId == item.id && ($0.hasRefund || $0.deletedAt != nil)
            }) else { continue }

            let availableInLinkedPotsPence = linkedPotIndices.reduce(0) { total, index in
                total + max(0, snapshot.pots[index].balancePence)
            }
            let requiredPaymentPence = max(0, item.plannedAmountPence - item.paidAmountPence)
            guard requiredPaymentPence > 0 else { continue }

            guard item.fundedAmountPence >= requiredPaymentPence,
                  availableInLinkedPotsPence >= requiredPaymentPence
            else {
                if let scheduleIndex = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == item.id }) {
                    let fundedPence = max(item.fundedAmountPence, min(availableInLinkedPotsPence, requiredPaymentPence))
                    let status: DebtPaymentScheduleStatus = fundedPence > 0 ? (item.dueDate < todayIso ? .overdue : .partFunded) : (item.dueDate < todayIso ? .overdue : .missed)
                    if item.fundedAmountPence != fundedPence || item.status != status {
                        snapshot.debtPaymentScheduleItems[scheduleIndex].fundedAmountPence = fundedPence
                        snapshot.debtPaymentScheduleItems[scheduleIndex].status = status
                        snapshot.debtPaymentScheduleItems[scheduleIndex].updatedAt = now
                        updateDebtStatus(debtId: item.debtId, asOf: todayIso, now: now)
                        changed = true
                    }
                }
                continue
            }

            let note = linkedPotIndices.count == 1
                ? "Automatic \(debt.name) payment from \(snapshot.pots[linkedPotIndices[0]].name)"
                : "Automatic \(debt.name) payment from linked debt pots"

            let application = DebtPlannerEngine.applyPayment(
                debt: debt,
                scheduleItem: item,
                priorPayments: snapshot.debtPayments,
                amountPence: requiredPaymentPence,
                date: item.dueDate,
                sourcePotId: linkedPotIndices.first.map { snapshot.pots[$0].id },
                paymentType: .scheduled,
                note: note
            )

            guard application.payment.amountPence > 0 else { continue }

            var remainingToDeductPence = application.payment.amountPence
            var potContributions: [DebtPaymentPotContribution] = []
            for index in linkedPotIndices {
                if remainingToDeductPence <= 0 {
                    break
                }

                let potDeductionPence = min(max(0, snapshot.pots[index].balancePence), remainingToDeductPence)
                snapshot.pots[index].balancePence -= potDeductionPence
                snapshot.pots[index].updatedAt = now
                remainingToDeductPence -= potDeductionPence
                if potDeductionPence > 0 {
                    potContributions.append(DebtPaymentPotContribution(potId: snapshot.pots[index].id, amountPence: potDeductionPence))
                }
            }


            var payment = application.payment
            payment.potContributions = potContributions
            payment.id = paymentId
            payment.createdAt = now
            payment.updatedAt = now
            snapshot.debtPayments.insert(payment, at: 0)
            snapshot.debts[debtIndex] = application.debt
            if let updatedScheduleItem = application.scheduleItem {
                replaceDebtScheduleItem(updatedScheduleItem)
            }
            recalculateDebtAfterPayment(debtId: debt.id, date: item.dueDate, mode: debt.recalculationMode, now: now)
            changed = true
        }

        return changed
    }

    private func cardRecurringTransactionIndex(
        transactionId: String,
        paymentId: String,
        scheduledDueDate: String,
        cardId: String
    ) -> Int? {
        snapshot.transactions.firstIndex {
            $0.deletedAt == nil && (
                $0.id == transactionId ||
            (
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == cardId &&
                $0.recurringPaymentId == paymentId &&
                $0.id == cardRecurringTransactionId(paymentId: paymentId, scheduledDueDate: scheduledDueDate)
            )
            )
        }
    }

    private func recurringApplicationStartDate(_ payment: RecurringPayment, todayIso: String) -> String {
        guard let createdDate = payment.createdAt.isoDatePrefix else {
            return todayIso
        }

        return createdDate <= todayIso ? createdDate : todayIso
    }

    private func recurringTransactionLedgerAmounts(
        payment: RecurringPayment,
        scheduledDueDate: String
    ) -> (gross: Int, refunded: Int, refundedAt: String?) {
        let occurrenceOverride = snapshot.recurringPaymentOccurrenceOverrides.first {
            $0.deletedAt == nil &&
                $0.paymentId == payment.id &&
                $0.scheduledDueDate == scheduledDueDate
        }
        let posted = snapshot.transactions.first {
            $0.deletedAt == nil && $0.recurringPaymentId == payment.id &&
                ($0.id == recurringTransactionId(paymentId: payment.id, scheduledDueDate: scheduledDueDate) ||
                 $0.id == cardRecurringTransactionId(paymentId: payment.id, scheduledDueDate: scheduledDueDate))
        }
        let gross = max(0, occurrenceOverride?.amountPenceOverride ?? posted?.amountPence ?? payment.amountPence)
        let refunded = occurrenceOverride?.effectiveRefundedAmountPence(originalAmountPence: gross) ?? 0
        return (
            gross: gross,
            refunded: min(gross, max(0, refunded)),
            refundedAt: refunded > 0 ? occurrenceOverride?.updatedAt : nil
        )
    }

    @discardableResult
    private func synchronizeRecurringTransactionLedger(
        at index: Int,
        grossAmountPence: Int,
        refundedAmountPence: Int,
        refundedAt: String?,
        now: String
    ) -> Bool {
        let normalizedRefund = min(max(0, grossAmountPence), max(0, refundedAmountPence))
        let normalizedRefundDate = normalizedRefund > 0 ? refundedAt ?? now : nil
        guard snapshot.transactions[index].amountPence != grossAmountPence ||
                snapshot.transactions[index].effectiveRefundedAmountPence != normalizedRefund ||
                snapshot.transactions[index].refundedAt != normalizedRefundDate
        else { return false }

        let oldNet = snapshot.transactions[index].netAmountPence
        snapshot.transactions[index].amountPence = grossAmountPence
        snapshot.transactions[index].refundedAt = normalizedRefundDate
        snapshot.transactions[index].refundedAmountPence = normalizedRefund > 0 ? normalizedRefund : nil
        snapshot.transactions[index].updatedAt = now
        if snapshot.transactions[index].paymentMethod == .pot,
           let potId = snapshot.transactions[index].potId,
           let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            snapshot.pots[potIndex].balancePence += oldNet - snapshot.transactions[index].netAmountPence
            snapshot.pots[potIndex].updatedAt = now
        }
        return true
    }

    private func recurringTransactionId(paymentId: String, scheduledDueDate: String) -> String {
        "recurring-\(paymentId)-\(scheduledDueDate)"
    }

    private func cardRecurringTransactionId(paymentId: String, scheduledDueDate: String) -> String {
        "card-recurring-\(paymentId)-\(scheduledDueDate)"
    }

    private func recurringScheduledDueDate(for transaction: Transaction, paymentId: String) -> String? {
        let prefixes = [
            "card-recurring-\(paymentId)-",
            "recurring-\(paymentId)-"
        ]

        for prefix in prefixes where transaction.id.hasPrefix(prefix) {
            let candidate = String(transaction.id.dropFirst(prefix.count))
            if FinanceEngine.isIsoDate(candidate) {
                return candidate
            }
        }

        return nil
    }

    private func cardBillFundingAllocationId(paymentId: String, dueDate: String, payPeriodId: String) -> String {
        "card-bill-funding-allocation-\(paymentId)-\(dueDate)-\(payPeriodId)"
    }

    private func recurringBillFundingAllocationId(paymentId: String, dueDate: String, payPeriodId: String) -> String {
        "recurring-bill-funding-allocation-\(paymentId)-\(dueDate)-\(payPeriodId)"
    }

    private func fundingChecklistExclusionIdentity(
        for action: FundingChecklistAction
    ) -> (kind: FundingChecklistExclusionKind, sourceId: String, occurrenceDate: String, payPeriodId: String)? {
        switch action {
        case .recurringBill(let paymentId, let dueDate, let payPeriodId):
            let payment = snapshot.recurringPayments.first { $0.id == paymentId }
            let kind: FundingChecklistExclusionKind = payment?.creditCardId?.nilIfBlank == nil
                ? .recurringBill
                : .cardBill
            return (kind, paymentId, dueDate, payPeriodId)
        case .cardBill(let paymentId, let dueDate, let payPeriodId):
            return (.cardBill, paymentId, dueDate, payPeriodId)
        case .cardSpend(let transactionId, let payPeriodId):
            guard let transaction = snapshot.transactions.first(where: { $0.id == transactionId }) else { return nil }
            return (.cardSpend, transactionId, transaction.date, payPeriodId)
        case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
            return (.cardOpeningBalance, cardId, directDebitDate, payPeriodId)
        case .cardPayment(let cardId, _, let directDebitDate, let payPeriodId):
            return (.cardPayment, cardId, directDebitDate, payPeriodId)
        case .debt(let debtId, let dueDate, let payPeriodId):
            return (.debt, debtId, dueDate, payPeriodId)
        }
    }

    private func fundingChecklistExclusionId(
        _ identity: (kind: FundingChecklistExclusionKind, sourceId: String, occurrenceDate: String, payPeriodId: String)
    ) -> String {
        "funding-exclusion-\(identity.kind.rawValue)-\(identity.sourceId)-\(identity.occurrenceDate)-\(identity.payPeriodId)"
    }

    private func removeFundingChecklistExclusion(for action: FundingChecklistAction, shouldPersist: Bool) {
        guard let identity = fundingChecklistExclusionIdentity(for: action) else { return }
        let originalCount = snapshot.fundingChecklistExclusions.count
        snapshot.fundingChecklistExclusions.removeAll {
            $0.kind == identity.kind &&
            $0.sourceId == identity.sourceId &&
            $0.occurrenceDate == identity.occurrenceDate
        }

        if shouldPersist, snapshot.fundingChecklistExclusions.count != originalCount {
            persist()
        }
    }

    private func isRecurringBillFundingSource(_ source: PotAllocationSource?) -> Bool {
        source == .recurringBillFunding || source == .cardBillFunding
    }

    private func cardSpendFundingAllocationId(transactionId: String, payPeriodId: String) -> String {
        "card-spend-funding-allocation-\(transactionId)-\(payPeriodId)"
    }

    private func cardOpeningBalanceFundingAllocationId(cardId: String, directDebitDate: String, payPeriodId: String) -> String {
        "card-opening-balance-funding-allocation-\(cardId)-\(directDebitDate)-\(payPeriodId)"
    }

    private func cardPaymentFundingAllocationId(cardId: String, potId: String, directDebitDate: String, payPeriodId: String) -> String {
        "card-payment-funding-allocation-\(cardId)-\(potId)-\(directDebitDate)-\(payPeriodId)"
    }

    private func debtFundingAllocationId(debtId: String, dueDate: String, payPeriodId: String) -> String {
        "debt-funding-allocation-\(debtId)-\(dueDate)-\(payPeriodId)"
    }

    private func debtFundingAllocationId(scheduleItemId: String, payPeriodId: String) -> String {
        "debt-funding-allocation-\(scheduleItemId)-\(payPeriodId)"
    }

    private func linkedDebtPotPaymentId(debtId: String, dueDate: String) -> String {
        "linked-debt-pot-payment-\(debtId)-\(dueDate)"
    }

    private func creditCardStatementRepaymentId(creditCardId: String, statementDate: String, dueDate: String) -> String {
        "card-statement-repayment-\(creditCardId)-\(statementDate)-\(dueDate)"
    }

    private func creditCardOpeningBalanceRepaymentId(creditCardId: String, directDebitDate: String) -> String {
        "card-opening-balance-repayment-\(creditCardId)-\(directDebitDate)"
    }

    private func linkedCreditCardPotRepaymentId(creditCardId: String, statementDate: String, dueDate: String) -> String {
        "linked-card-pot-repayment-\(creditCardId)-\(statementDate)-\(dueDate)"
    }

    private func hasCreditCardStatementRepayment(creditCardId: String, statementDate: String, directDebitDate: String) -> Bool {
        let newId = creditCardStatementRepaymentId(creditCardId: creditCardId, statementDate: statementDate, dueDate: directDebitDate)
        let legacyLinkedPotId = linkedCreditCardPotRepaymentId(creditCardId: creditCardId, statementDate: statementDate, dueDate: directDebitDate)

        return snapshot.creditCardRepayments.contains {
            $0.deletedAt == nil && (
                $0.id == newId ||
                $0.id == legacyLinkedPotId ||
                (
                $0.creditCardId == creditCardId &&
                $0.statementDate == statementDate &&
                ($0.directDebitDate ?? $0.date) == directDebitDate
                )
            )
        }
    }

    private func deductLinkedCreditCardPots(creditCardId: String, amountPence: Int, now: String) -> LinkedPotContribution {
        let linkedPotIndices = snapshot.pots.indices
            .filter {
                !snapshot.pots[$0].archived &&
                snapshot.pots[$0].linkedCreditCardId == creditCardId &&
                snapshot.pots[$0].balancePence > 0
            }
            .sorted { snapshot.pots[$0].name < snapshot.pots[$1].name }

        var remainingPence = amountPence
        var contributedPence = 0
        var contributingPotIds: [String] = []
        var contributingPotNames: [String] = []
        var potContributions: [CreditCardPotContribution] = []

        for index in linkedPotIndices {
            guard remainingPence > 0 else { break }
            let deductionPence = min(max(0, snapshot.pots[index].balancePence), remainingPence)
            guard deductionPence > 0 else { continue }

            snapshot.pots[index].balancePence -= deductionPence
            snapshot.pots[index].updatedAt = now
            remainingPence -= deductionPence
            contributedPence += deductionPence
            contributingPotIds.append(snapshot.pots[index].id)
            contributingPotNames.append(snapshot.pots[index].name)
            potContributions.append(CreditCardPotContribution(potId: snapshot.pots[index].id, amountPence: deductionPence))
        }

        return LinkedPotContribution(
            amountPence: contributedPence,
            singlePotId: contributingPotIds.count == 1 ? contributingPotIds[0] : nil,
            singlePotName: contributingPotNames.count == 1 ? contributingPotNames[0] : nil,
            potContributions: potContributions
        )
    }

    private func creditCardStatementRepaymentNote(cardName: String, linkedPotContribution: LinkedPotContribution) -> String {
        guard linkedPotContribution.amountPence > 0 else {
            return "Automatic \(cardName) statement direct debit"
        }

        if let potName = linkedPotContribution.singlePotName {
            return "Automatic \(cardName) statement payment from \(potName) pot"
        }

        return "Automatic \(cardName) statement payment from linked card pots"
    }

    private func isEligibleDebtPot(potId: String, debtId: String) -> Bool {
        snapshot.pots.contains {
            $0.id == potId &&
            !$0.archived &&
            $0.linkedCreditCardId == nil &&
            ($0.linkedDebtId == nil || $0.linkedDebtId == debtId)
        }
    }

    private func applyDebtPotLink(debtId: String, potId: String?, now: String) {
        for index in snapshot.pots.indices where snapshot.pots[index].linkedDebtId == debtId && snapshot.pots[index].id != potId {
            snapshot.pots[index].linkedDebtId = nil
            snapshot.pots[index].updatedAt = now
        }

        guard let potId,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId }),
              isEligibleDebtPot(potId: potId, debtId: debtId)
        else { return }

        snapshot.pots[potIndex].linkedDebtId = debtId
        snapshot.pots[potIndex].updatedAt = now
    }

    private func completeRecurringBillFunding(_ item: RecurringBillFundingChecklistItem) -> Bool {
        let allocationId = recurringBillFundingAllocationId(paymentId: item.paymentId, dueDate: item.dueDate, payPeriodId: item.payPeriodId)
        if snapshot.potAllocations.contains(where: { $0.id == allocationId }) {
            return true
        }

        let hasMatchingAllocation = snapshot.potAllocations.contains {
            $0.deletedAt == nil &&
            $0.payPeriodId == item.payPeriodId &&
            $0.potId == item.potId &&
            isRecurringBillFundingSource($0.source) &&
            $0.recurringPaymentId == item.paymentId &&
            $0.recurringDueDate == item.dueDate
        }
        guard !hasMatchingAllocation,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return true }

        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: allocationId,
                payPeriodId: item.payPeriodId,
                potId: item.potId,
                fundingPotId: nil,
                bankAccountId: fundingBankAccountId(for: item.potId),
                amountPence: item.amountPence,
                source: .recurringBillFunding,
                recurringPaymentId: item.paymentId,
                recurringDueDate: item.dueDate,
                debtId: nil,
                debtDueDate: nil,
                transactionId: nil,
                transactionDate: nil,
                creditCardId: item.cardId,
                creditCardDirectDebitDate: item.cardId == nil ? nil : item.fundingDueDate,
                userConfirmed: item.cardId == nil ? nil : true,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        snapshot.pots[potIndex].balancePence += item.amountPence
        snapshot.pots[potIndex].updatedAt = now
        persist()
        return true
    }

    private func reverseRecurringBillFunding(_ item: RecurringBillFundingChecklistItem) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].potId == item.potId &&
            isRecurringBillFundingSource(snapshot.potAllocations[$0].source) &&
            snapshot.potAllocations[$0].recurringPaymentId == item.paymentId &&
            snapshot.potAllocations[$0].recurringDueDate == item.dueDate
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        let amountToReverse = matchingAllocationIndices.reduce(0) { total, index in
            total + max(0, snapshot.potAllocations[index].amountPence)
        }
        guard amountToReverse > 0,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return false }

        guard snapshot.pots[potIndex].balancePence >= amountToReverse else {
            errorMessage = "Unable to undo \(item.paymentName) funding because \(item.potName) no longer has enough money."
            return false
        }

        let now = DateUtilities.nowIsoString()
        snapshot.pots[potIndex].balancePence -= amountToReverse
        snapshot.pots[potIndex].updatedAt = now
        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
        if item.cardId != nil {
            for transactionIndex in snapshot.transactions.indices where
                snapshot.transactions[transactionIndex].deletedAt == nil &&
                snapshot.transactions[transactionIndex].type == .spending &&
                snapshot.transactions[transactionIndex].paymentMethod == .creditCard &&
                snapshot.transactions[transactionIndex].creditCardId == item.cardId &&
                snapshot.transactions[transactionIndex].recurringPaymentId == item.paymentId &&
                snapshot.transactions[transactionIndex].date == item.dueDate &&
                snapshot.transactions[transactionIndex].potId == item.potId
            {
                snapshot.transactions[transactionIndex].potId = nil
                snapshot.transactions[transactionIndex].updatedAt = now
            }
        }
        persist()
        return true
    }

    private func completeCardSpendFunding(_ item: CardSpendFundingChecklistItem, shouldPersist: Bool = true) -> Bool {
        let allocationId = cardSpendFundingAllocationId(transactionId: item.transactionId, payPeriodId: item.payPeriodId)
        if snapshot.potAllocations.contains(where: { $0.id == allocationId }) {
            return true
        }

        let hasMatchingAllocation = snapshot.potAllocations.contains {
            $0.deletedAt == nil &&
            $0.payPeriodId == item.payPeriodId &&
            $0.source == .cardSpendFunding &&
            $0.transactionId == item.transactionId
        }
        guard item.amountPence > 0,
              !hasMatchingAllocation,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return true }

        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: allocationId,
                payPeriodId: item.payPeriodId,
                potId: item.potId,
                fundingPotId: nil,
                bankAccountId: fundingBankAccountId(for: item.potId),
                amountPence: item.amountPence,
                source: .cardSpendFunding,
                recurringPaymentId: nil,
                recurringDueDate: nil,
                debtId: nil,
                debtDueDate: nil,
                transactionId: item.transactionId,
                transactionDate: item.transactionDate,
                creditCardId: item.cardId,
                creditCardDirectDebitDate: item.dueDate,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        snapshot.pots[potIndex].balancePence += item.amountPence
        snapshot.pots[potIndex].updatedAt = now
        if shouldPersist {
            persist()
        }
        return true
    }

    private func reverseCardSpendFunding(_ item: CardSpendFundingChecklistItem, shouldPersist: Bool = true) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].source == .cardSpendFunding &&
            snapshot.potAllocations[$0].transactionId == item.transactionId
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        let now = DateUtilities.nowIsoString()
        guard reverseCardSpendFundingAllocations(at: matchingAllocationIndices, now: now) else { return false }
        if shouldPersist {
            persist()
        }
        return true
    }

    private func completeCardOpeningBalanceFunding(_ item: CreditCardOpeningBalanceFundingChecklistItem) -> Bool {
        let allocationId = cardOpeningBalanceFundingAllocationId(cardId: item.cardId, directDebitDate: item.directDebitDate, payPeriodId: item.payPeriodId)
        if snapshot.potAllocations.contains(where: { $0.id == allocationId }) {
            return true
        }

        let hasMatchingAllocation = snapshot.potAllocations.contains {
            $0.deletedAt == nil &&
            $0.payPeriodId == item.payPeriodId &&
            $0.source == .cardOpeningBalanceFunding &&
            $0.creditCardId == item.cardId &&
            $0.creditCardDirectDebitDate == item.directDebitDate
        }
        guard item.amountPence > 0,
              !hasMatchingAllocation,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return true }

        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: allocationId,
                payPeriodId: item.payPeriodId,
                potId: item.potId,
                fundingPotId: nil,
                bankAccountId: fundingBankAccountId(for: item.potId),
                amountPence: item.amountPence,
                source: .cardOpeningBalanceFunding,
                recurringPaymentId: nil,
                recurringDueDate: nil,
                debtId: nil,
                debtDueDate: nil,
                transactionId: nil,
                transactionDate: nil,
                creditCardId: item.cardId,
                creditCardDirectDebitDate: item.directDebitDate,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        snapshot.pots[potIndex].balancePence += item.amountPence
        snapshot.pots[potIndex].updatedAt = now
        persist()
        return true
    }

    private func reverseCardOpeningBalanceFunding(_ item: CreditCardOpeningBalanceFundingChecklistItem) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].payPeriodId == item.payPeriodId &&
            snapshot.potAllocations[$0].source == .cardOpeningBalanceFunding &&
            snapshot.potAllocations[$0].creditCardId == item.cardId &&
            snapshot.potAllocations[$0].creditCardDirectDebitDate == item.directDebitDate
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        let amountToReverse = matchingAllocationIndices.reduce(0) { total, index in
            total + max(0, snapshot.potAllocations[index].amountPence)
        }
        guard amountToReverse > 0,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return false }

        guard snapshot.pots[potIndex].balancePence >= amountToReverse else {
            errorMessage = "Unable to undo \(item.cardName) opening balance funding because \(item.potName) no longer has enough money."
            return false
        }

        let now = DateUtilities.nowIsoString()
        snapshot.pots[potIndex].balancePence -= amountToReverse
        snapshot.pots[potIndex].updatedAt = now
        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
        persist()
        return true
    }

    private func completeCardPaymentFunding(_ item: CreditCardPaymentFundingChecklistItem) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].payPeriodId == item.payPeriodId &&
            snapshot.potAllocations[$0].potId == item.potId &&
            snapshot.potAllocations[$0].source == .cardPaymentFunding &&
            snapshot.potAllocations[$0].creditCardId == item.cardId &&
            snapshot.potAllocations[$0].creditCardDirectDebitDate == item.directDebitDate
        }
        let fundedPence = matchingAllocationIndices.reduce(0) {
            $0 + max(0, snapshot.potAllocations[$1].amountPence)
        }
        let amountToAdd = max(0, item.amountPence - fundedPence)
        guard amountToAdd > 0 else { return true }
        guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived }) else {
            return false
        }

        let now = DateUtilities.nowIsoString()
        if let allocationIndex = matchingAllocationIndices.first {
            snapshot.potAllocations[allocationIndex].amountPence += amountToAdd
            snapshot.potAllocations[allocationIndex].updatedAt = now
        } else {
            snapshot.potAllocations.insert(
                PotAllocation(
                    id: cardPaymentFundingAllocationId(cardId: item.cardId, potId: item.potId, directDebitDate: item.directDebitDate, payPeriodId: item.payPeriodId),
                    payPeriodId: item.payPeriodId,
                    potId: item.potId,
                    fundingPotId: nil,
                    bankAccountId: fundingBankAccountId(for: item.potId),
                    amountPence: amountToAdd,
                    source: .cardPaymentFunding,
                    recurringPaymentId: nil,
                    recurringDueDate: nil,
                    debtId: nil,
                    debtDueDate: nil,
                    transactionId: nil,
                    transactionDate: nil,
                    creditCardId: item.cardId,
                    creditCardDirectDebitDate: item.directDebitDate,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ),
                at: 0
            )
        }
        snapshot.pots[potIndex].balancePence += amountToAdd
        snapshot.pots[potIndex].updatedAt = now
        persist()
        return true
    }

    private func reverseCardPaymentFunding(_ item: CreditCardPaymentFundingChecklistItem) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].potId == item.potId &&
            snapshot.potAllocations[$0].source == .cardPaymentFunding &&
            snapshot.potAllocations[$0].creditCardId == item.cardId &&
            snapshot.potAllocations[$0].creditCardDirectDebitDate == item.directDebitDate
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        let amountToReverse = matchingAllocationIndices.reduce(0) {
            $0 + max(0, snapshot.potAllocations[$1].amountPence)
        }
        guard amountToReverse > 0,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return false }
        guard snapshot.pots[potIndex].balancePence >= amountToReverse else {
            errorMessage = "Unable to undo \(item.cardName) card payment funding because \(item.potName) no longer has enough money."
            return false
        }

        let now = DateUtilities.nowIsoString()
        snapshot.pots[potIndex].balancePence -= amountToReverse
        snapshot.pots[potIndex].updatedAt = now
        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
        persist()
        return true
    }

    private func completeDebtFunding(_ item: DebtFundingChecklistItem) -> Bool {
        let allocationId = debtFundingAllocationId(scheduleItemId: item.scheduleItemId, payPeriodId: item.payPeriodId)
        if snapshot.potAllocations.contains(where: { $0.id == allocationId }) {
            return true
        }

        let hasMatchingAllocation = snapshot.potAllocations.contains {
            $0.deletedAt == nil &&
            $0.payPeriodId == item.payPeriodId &&
            $0.potId == item.potId &&
            $0.source == .debtFunding &&
            $0.debtId == item.debtId &&
            (
                $0.debtScheduleItemId == item.scheduleItemId ||
                ($0.debtScheduleItemId == nil && $0.debtDueDate == item.dueDate)
            )
        }
        guard item.amountPence > 0,
              !hasMatchingAllocation,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return true }

        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: allocationId,
                payPeriodId: item.payPeriodId,
                potId: item.potId,
                fundingPotId: nil,
                bankAccountId: fundingBankAccountId(for: item.potId),
                amountPence: item.amountPence,
                source: .debtFunding,
                recurringPaymentId: nil,
                recurringDueDate: nil,
                debtId: item.debtId,
                debtDueDate: item.dueDate,
                debtScheduleItemId: item.scheduleItemId,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        snapshot.pots[potIndex].balancePence += item.amountPence
        snapshot.pots[potIndex].updatedAt = now
        addDebtScheduleFunding(scheduleItemId: item.scheduleItemId, amountPence: item.amountPence, now: now)
        persist()
        return true
    }

    private func reverseDebtFunding(_ item: DebtFundingChecklistItem) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].payPeriodId == item.payPeriodId &&
            snapshot.potAllocations[$0].potId == item.potId &&
            snapshot.potAllocations[$0].source == .debtFunding &&
            snapshot.potAllocations[$0].debtId == item.debtId &&
            (
                snapshot.potAllocations[$0].debtScheduleItemId == item.scheduleItemId ||
                (snapshot.potAllocations[$0].debtScheduleItemId == nil && snapshot.potAllocations[$0].debtDueDate == item.dueDate)
            )
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        let amountToReverse = matchingAllocationIndices.reduce(0) { total, index in
            total + max(0, snapshot.potAllocations[index].amountPence)
        }
        guard amountToReverse > 0,
              let potIndex = snapshot.pots.firstIndex(where: { $0.id == item.potId && !$0.archived })
        else { return false }

        guard snapshot.pots[potIndex].balancePence >= amountToReverse else {
            errorMessage = "Unable to undo \(item.debtName) funding because \(item.potName) no longer has enough money."
            return false
        }

        let now = DateUtilities.nowIsoString()
        snapshot.pots[potIndex].balancePence -= amountToReverse
        snapshot.pots[potIndex].updatedAt = now
        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
        removeDebtScheduleFunding(scheduleItemId: item.scheduleItemId, amountPence: amountToReverse, now: now)
        persist()
        return true
    }

    private func removeCardSpendFundingAllocations(transactionId: String, now: String) -> [String]? {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].source == .cardSpendFunding &&
            snapshot.potAllocations[$0].transactionId == transactionId
        }
        guard !matchingAllocationIndices.isEmpty else { return [] }

        var payPeriodIds = Set<String>()
        for index in matchingAllocationIndices {
            let allocation = snapshot.potAllocations[index]
            payPeriodIds.insert(allocation.payPeriodId)
        }

        guard reverseCardSpendFundingAllocations(at: matchingAllocationIndices, now: now) else { return nil }

        return Array(payPeriodIds)
    }

    private func reverseCardSpendFundingAllocations(at indices: [Int], now: String) -> Bool {
        let allocations = indices.map { snapshot.potAllocations[$0] }
        let amountByPotId = allocations.reduce(into: [String: Int]()) { result, allocation in
            result[allocation.potId, default: 0] += max(0, allocation.amountPence)
        }

        var potIndexById: [String: Int] = [:]
        for (potId, amountPence) in amountByPotId {
            guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId && !$0.archived }),
                  snapshot.pots[potIndex].balancePence >= amountPence
            else {
                errorMessage = "Unable to reverse card-spend funding because its linked pot no longer contains the allocated money."
                return false
            }
            potIndexById[potId] = potIndex
        }

        for (potId, amountPence) in amountByPotId {
            guard let potIndex = potIndexById[potId] else { return false }
            snapshot.pots[potIndex].balancePence -= amountPence
            snapshot.pots[potIndex].updatedAt = now
        }
        for index in indices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
        return true
    }

    private func restoreCardSpendFundingAllocations(transactionId: String, payPeriodIds: [String]) {
        for payPeriodId in Set(payPeriodIds) {
            guard let payPeriod = snapshot.payPeriods.first(where: { $0.id == payPeriodId }),
                  let item = PlannerDerivedData.cardSpendFundingChecklistItems(snapshot: snapshot, payPeriod: payPeriod)
                    .first(where: { $0.transactionId == transactionId })
            else { continue }

            _ = completeCardSpendFunding(item, shouldPersist: false)
        }
    }

    private func restorePotBalanceAfterRemovingTransaction(_ transaction: Transaction, now: String) {
        guard transaction.paymentMethod == .pot,
              let potId = transaction.potId,
              let index = snapshot.pots.firstIndex(where: { $0.id == potId })
        else { return }

        snapshot.pots[index].balancePence = FinanceEngine.getPotBalanceAfterTransactionRemoval(snapshot.pots[index], transaction: transaction)
        snapshot.pots[index].updatedAt = now
    }

    private func applyPotBalanceForTransaction(_ transaction: Transaction) {
        guard transaction.paymentMethod == .pot,
              let potId = transaction.potId,
              let index = snapshot.pots.firstIndex(where: { $0.id == potId })
        else { return }

        snapshot.pots[index] = FinanceEngine.applyTransactionToPot(snapshot.pots[index], amountPence: transaction.amountPence, type: transaction.type)
    }

    @discardableResult
    private func prepareLoadedSnapshot() -> Bool {
        let migration = DefaultData.migratedSnapshot(snapshot)
        snapshot = migration.snapshot
        var shouldPersist = migration.didChange
        if ensureDebtSchedules(today: todayIso) {
            shouldPersist = true
        }
        if catchUpDueObligations(to: todayIso) {
            shouldPersist = true
        }
        return shouldPersist
    }

    @discardableResult
    private func bootstrapAuditHistoryIfNeeded() -> Bool {
        guard snapshot.auditEvents.isEmpty, snapshot.hasMeaningfulPlannerData else { return false }
        snapshot.auditEvents = PlannerAuditEngine.baselineEvents(for: snapshot)
        return !snapshot.auditEvents.isEmpty
    }

    private func applyAccountCollection(_ collection: PlannerAccountCollection) {
        let sanitizedCollection = sanitizedAccountCollection(collection)
        applySelectedThemeIfNeeded(from: sanitizedCollection)
        accountCollection = sanitizedCollection
        plannerAccounts = sanitizedCollection.accounts
        activePlannerAccountId = sanitizedCollection.activeAccountId
        snapshot = sanitizedCollection.activeAccount?.snapshot ?? DefaultData.emptySnapshot
        lastAuditedSnapshot = snapshot
        lastRefreshedDate = nil
        refreshCreditCardCycleReminders()
    }

    func accountCollectionForCloudUpload() -> PlannerAccountCollection {
        var collection = accountCollection ?? standaloneCollection
        if let index = collection.accounts.firstIndex(where: { $0.id == collection.activeAccountId }) {
            collection.accounts[index].snapshot = snapshot
        }
        collection.selectedThemePresetId = AppTheme.selectedPreset.rawValue

        for index in collection.accounts.indices {
            guard collection.accounts[index].avatarImageDataBase64 == nil,
                  let avatarImageName = collection.accounts[index].avatarImageName,
                  let encodedImageData = PlannerAccountAvatarFileStore.encodedImageDataBase64(named: avatarImageName)
            else { continue }

            collection.accounts[index].avatarImageDataBase64 = encodedImageData
        }

        return collection
    }

    private func applySelectedThemeIfNeeded(from collection: PlannerAccountCollection) {
        guard let presetId = collection.selectedThemePresetId,
              AppThemePreset(rawValue: presetId) != nil,
              UserDefaults.standard.string(forKey: AppTheme.selectedPresetStorageKey) != presetId else {
            return
        }

        UserDefaults.standard.set(presetId, forKey: AppTheme.selectedPresetStorageKey)
    }

    private func validateAccountCollection(_ collection: PlannerAccountCollection) throws {
        let ids = collection.accounts.map(\.id)
        guard !ids.isEmpty, ids.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(ids).count == ids.count else {
            throw PlannerStoreLoadError(message: "The saved planner accounts need recovery. No data has been replaced.")
        }
    }

    private func sanitizedAccountCollection(_ collection: PlannerAccountCollection) -> PlannerAccountCollection {
        var accounts = collection.accounts
        if accounts.isEmpty {
            return PlannerAccountCollection.singleAccount(snapshot: snapshot)
        }

        for index in accounts.indices {
            let cleanName = accounts[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            accounts[index].name = cleanName.isEmpty ? "Account \(index + 1)" : cleanName
        }

        let activeId = accounts.contains { $0.id == collection.activeAccountId }
            ? collection.activeAccountId
            : accounts[0].id
        var sanitized = collection
        sanitized.activeAccountId = activeId
        sanitized.accounts = accounts
        return sanitized
    }

    @discardableResult
    private func updateActiveAccountSnapshot(_ activeSnapshot: PlannerSnapshot) -> PlannerAccountCollection? {
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == collection.activeAccountId })
        else {
            return nil
        }

        let selectedTheme = AppTheme.selectedPreset.rawValue
        guard collection.accounts[index].snapshot != activeSnapshot || collection.selectedThemePresetId != selectedTheme else {
            return collection
        }
        let now = DateUtilities.nowIsoString()
        collection.accounts[index].snapshot = activeSnapshot
        collection.selectedThemePresetId = selectedTheme
        collection.accounts[index].updatedAt = now
        collection.updatedAt = now
        accountCollection = collection
        plannerAccounts = collection.accounts
        activePlannerAccountId = collection.activeAccountId
        return collection
    }

    private func validatedAccountName(_ name: String, excludingAccountId: String? = nil) throws -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw PlannerAccountError.blankName
        }
        let normalizedName = cleanName.lowercased()
        let isDuplicate = plannerAccounts.contains { account in
            account.id != excludingAccountId &&
                account.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }
        guard !isDuplicate else {
            throw PlannerAccountError.duplicateName
        }
        return cleanName
    }

    private func plannerAccountColor(at index: Int) -> String {
        let colors = AppTheme.selectableColorHexes()
        return colors[min(max(index, 0), colors.count - 1)]
    }

    private func persist() {
        guard loadError == nil else { return }
#if DEBUG
        if !suppressAutomaticDueCatchUpForSimulation {
            _ = catchUpDueObligations(to: todayIso)
        }
#else
        _ = catchUpDueObligations(to: todayIso)
#endif
        recordPendingAuditEvent()
        refreshCreditCardCycleReminders()
        saveCoordinator.enqueue(currentSavePayload())
    }

    private func currentSavePayload() -> PlannerSavePayload {
        if accountRepository != nil, let collection = updateActiveAccountSnapshot(snapshot) {
            return .accounts(collection)
        }
        return .snapshot(snapshot)
    }

    /// Re-evaluate date-sensitive data on resume or day changes, without polling.
    func refreshForCurrentDate() {
        guard !isLoading, loadError == nil else { return }
        let date = todayIso
        guard lastRefreshedDate != date else { return }
        lastRefreshedDate = date
        effectiveDateRevision &+= 1
        if catchUpDueObligations(to: date) {
            recordPendingAuditEvent()
            saveCoordinator.enqueue(currentSavePayload())
        }
        refreshCreditCardCycleReminders()
    }

    private func recordPendingAuditEvent() {
        guard let before = lastAuditedSnapshot else {
            lastAuditedSnapshot = snapshot
            pendingAuditOrigin = .user
            pendingRestoredFromEventId = nil
            return
        }

        if let event = PlannerAuditEngine.event(
            before: before,
            after: snapshot,
            origin: pendingAuditOrigin,
            restoredFromEventId: pendingRestoredFromEventId
        ) {
            snapshot.auditEvents.append(event)
        }
        lastAuditedSnapshot = snapshot
        pendingAuditOrigin = .user
        pendingRestoredFromEventId = nil
    }

    func auditAction(for kind: PlannerAuditRecordKind, id: String) -> PlannerAuditAction? {
        snapshot.auditEvents.reversed().first { event in
            event.action != .baseline && event.changes.contains { $0.recordKind == kind && $0.recordId == id }
        }?.action
    }

    func auditEvents(for kind: PlannerAuditRecordKind, id: String) -> [PlannerAuditEvent] {
        snapshot.auditEvents
            .filter { event in event.changes.contains { $0.recordKind == kind && $0.recordId == id } }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    @discardableResult
    func reverseLatestEdit(for kind: PlannerAuditRecordKind, id: String) -> Bool {
        guard let event = snapshot.auditEvents.reversed().first(where: { candidate in
            candidate.action != .baseline && candidate.changes.contains {
                $0.recordKind == kind && $0.recordId == id && $0.beforeJSON != nil
            }
        }),
        let change = event.changes.first(where: { $0.recordKind == kind && $0.recordId == id }),
        applyAuditChange(change, json: change.beforeJSON)
        else { return false }

        pendingAuditOrigin = .restore
        pendingRestoredFromEventId = event.id
        persist()
        return true
    }

    @discardableResult
    func restoreAuditRecord(kind: PlannerAuditRecordKind, id: String, to eventId: String) -> Bool {
        guard let event = snapshot.auditEvents.first(where: { $0.id == eventId }),
              let change = event.changes.first(where: { $0.recordKind == kind && $0.recordId == id }),
              applyAuditChange(change, json: change.afterJSON)
        else { return false }

        pendingAuditOrigin = .restore
        pendingRestoredFromEventId = event.id
        persist()
        return true
    }

    private func applyAuditChange(_ change: PlannerAuditChange, json: String?) -> Bool {
        switch change.recordKind {
        case .bankAccount: return replaceRecord(in: &snapshot.bankAccounts, id: change.recordId, json: json)
        case .pot: return replaceRecord(in: &snapshot.pots, id: change.recordId, json: json)
        case .recurringPayment: return replaceRecord(in: &snapshot.recurringPayments, id: change.recordId, json: json)
        case .recurringOccurrence: return replaceRecord(in: &snapshot.recurringPaymentOccurrenceOverrides, id: change.recordId, json: json)
        case .incomeOccurrence: return replaceRecord(in: &snapshot.incomeOccurrenceOverrides, id: change.recordId, json: json)
        case .billGroup: return replaceRecord(in: &snapshot.billGroups, id: change.recordId, json: json)
        case .payPeriod: return replaceRecord(in: &snapshot.payPeriods, id: change.recordId, json: json)
        case .paycheck: return replaceRecord(in: &snapshot.paychecks, id: change.recordId, json: json)
        case .oneOffIncome: return replaceRecord(in: &snapshot.oneOffIncomes, id: change.recordId, json: json)
        case .potAllocation: return replaceRecord(in: &snapshot.potAllocations, id: change.recordId, json: json)
        case .transaction: return replaceRecord(in: &snapshot.transactions, id: change.recordId, json: json)
        case .debt: return replaceRecord(in: &snapshot.debts, id: change.recordId, json: json)
        case .debtPayment: return replaceRecord(in: &snapshot.debtPayments, id: change.recordId, json: json)
        case .debtReserve: return replaceRecord(in: &snapshot.debtReserves, id: change.recordId, json: json)
        case .debtSchedule: return replaceRecord(in: &snapshot.debtPaymentScheduleItems, id: change.recordId, json: json)
        case .creditCard: return replaceRecord(in: &snapshot.creditCards, id: change.recordId, json: json)
        case .customPayment: return replaceRecord(in: &snapshot.customPayments, id: change.recordId, json: json)
        case .creditCardRepayment: return replaceRecord(in: &snapshot.creditCardRepayments, id: change.recordId, json: json)
        case .creditCardPot: return replaceRecord(in: &snapshot.creditCardPots, id: change.recordId, json: json)
        case .creditCardCycle: return replaceRecord(in: &snapshot.creditCardCycleOverrides, id: change.recordId, json: json)
        }
    }

    private func replaceRecord<T: Codable & Identifiable>(in records: inout [T], id: String, json: String?) -> Bool where T.ID == String {
        guard let json else {
            let oldCount = records.count
            records.removeAll { $0.id == id }
            return records.count != oldCount
        }
        guard let decoded = PlannerAuditEngine.decode(T.self, json: json) else { return false }
        if let index = records.firstIndex(where: { $0.id == id }) {
            records[index] = decoded
        } else {
            records.append(decoded)
        }
        return true
    }

    private func refreshCreditCardCycleReminders() {
        guard let reminderScheduler else { return }
        let today = todayIso
        let accountID = activePlannerAccountId ?? standaloneCollection.activeAccountId
        let reminders = PlannerDerivedData.creditCardCycleReminders(snapshot: snapshot, asOfDate: today)
        var requests: [PlannerReminderRequest] = []
        for reminder in reminders {
            let identity = "\(accountID)-\(reminder.cardId)-\(reminder.scheduledStatementDate)"
            let entries: [(String, String, String, String)] = [
                ("statement-before", FinanceEngine.addIsoDays(date: reminder.statementDate, days: -1), "Check \(reminder.cardName) statement", "Your statement is expected tomorrow. Confirm the date if the bank changes it."),
                ("statement-day", reminder.statementDate, "Check \(reminder.cardName) statement", "Confirm the statement date or put this cycle on hold."),
                ("debit-before", FinanceEngine.addIsoDays(date: reminder.directDebitDate, days: -1), "Check \(reminder.cardName) direct debit", "Your direct debit is expected tomorrow."),
                ("debit-day", reminder.directDebitDate, "Check \(reminder.cardName) direct debit", "Confirm it was taken or put this payment on hold.")
            ]
            for (kind, date, title, body) in entries where date >= today {
                requests.append(PlannerReminderRequest(id: "\(PlannerReminderScheduler.prefix)\(kind)-\(identity)", date: date, title: title, body: body))
            }
        }
        reminderScheduler.refresh(requests)
    }

    private func markCloudSyncNeeded() {
        // Fixture repositories are test-only, in-memory stores and must never enqueue cloud writes.
        guard !PlannerLaunchProfile.isUsingFixture() else { return }
        cloudSyncRevision += 1
    }

    @discardableResult
    private func catchUpDueObligations(to targetDate: String) -> Bool {
        guard FinanceEngine.isIsoDate(targetDate) else { return false }

        var changed = false

        if let lastProcessedDate = snapshot.settings.lastProcessedDateIso,
           FinanceEngine.isIsoDate(lastProcessedDate),
           lastProcessedDate >= targetDate {
            changed = ensureCurrentPayPeriodExists(containing: targetDate) || changed
            if lastProcessedDate == targetDate {
                changed = applyDueLinkedPotObligations(asOf: targetDate) || changed
            }
            return changed
        }

        var cursor = catchUpStartDate(to: targetDate)
        if FinanceEngine.getDaysInclusive(startDate: cursor, endDate: targetDate) > dueCatchUpDayLimit {
            cursor = FinanceEngine.addIsoDays(date: targetDate, days: -(dueCatchUpDayLimit - 1))
        }

        var isFirstReplayDay = true
        while cursor <= targetDate {
            changed = ensureCurrentPayPeriodExists(containing: cursor) || changed
            changed = applyDueLinkedPotObligations(asOf: cursor, recurringStartDate: isFirstReplayDay ? nil : cursor) || changed
            isFirstReplayDay = false
            if snapshot.settings.lastProcessedDateIso != cursor {
                snapshot.settings.lastProcessedDateIso = cursor
                changed = true
            }
            cursor = FinanceEngine.addIsoDays(date: cursor, days: 1)
        }

        return changed
    }

    private var dueCatchUpDayLimit: Int { 3_660 }

    private func catchUpStartDate(to targetDate: String) -> String {
        if let lastProcessedDate = snapshot.settings.lastProcessedDateIso,
           FinanceEngine.isIsoDate(lastProcessedDate),
           lastProcessedDate < targetDate {
            return FinanceEngine.addIsoDays(date: lastProcessedDate, days: 1)
        }

        return targetDate
    }

    @discardableResult
    private func ensureCurrentPayPeriodExists(containing date: String) -> Bool {
        guard FinanceEngine.isIsoDate(date),
              snapshot.payPeriods.first(where: { $0.deletedAt == nil && $0.startDate <= date && $0.endDate >= date }) == nil
        else { return false }

        guard let sourcePeriod = snapshot.payPeriods.filter({ $0.deletedAt == nil })
            .sorted(by: sortPayPeriodsForSelection)
            .first
        else { return false }
        let frequency = sourcePeriod.payFrequency ?? snapshot.settings.payFrequency
        let monthlyAnchorDay = frequency == .monthly
            ? sourcePeriod.monthlyAnchorDay ?? FinanceEngine.dayOfMonth(sourcePeriod.payday)
            : nil
        let payday = inferredPayday(
            containing: date,
            from: sourcePeriod,
            frequency: frequency,
            monthlyAnchorDay: monthlyAnchorDay
        )
        let dates = FinanceEngine.createNextPayPeriod(
            payday: payday,
            frequency: frequency,
            monthlyAnchorDay: monthlyAnchorDay
        )
        guard dates.startDate <= date && dates.endDate >= date else { return false }

        let id = "pay-period-\(dates.startDate)"
        let now = DateUtilities.nowIsoString()
        if let existingIndex = snapshot.payPeriods.firstIndex(where: { $0.id == id }) {
            snapshot.payPeriods[existingIndex].status = .active
            snapshot.payPeriods[existingIndex].updatedAt = now
        } else {
            let isBackfilledBeforeSourcePeriod = payday < sourcePeriod.payday
            let incomePence = isBackfilledBeforeSourcePeriod ? 0 : sourcePeriod.incomePence
            let period = PayPeriod(
                id: id,
                startDate: dates.startDate,
                endDate: dates.endDate,
                payday: payday,
                nextPayday: dates.nextPayday,
                payFrequency: frequency,
                incomePence: incomePence,
                status: .active,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                monthlyAnchorDay: monthlyAnchorDay
            )
            snapshot.payPeriods.insert(period, at: 0)
        }

        for index in snapshot.payPeriods.indices where snapshot.payPeriods[index].status == .active && snapshot.payPeriods[index].id != id {
            snapshot.payPeriods[index].status = .closed
            snapshot.payPeriods[index].updatedAt = now
        }

        return true
    }

    /// Removes the legacy placeholder created when the app opened before the first paycheck was entered.
    /// It is safe to remove only when a recorded paycheck now covers the same date range.
    @discardableResult
    private func removeGeneratedEmptyPayPeriodsCoveredByRecordedPaychecks() -> Bool {
        let paycheckPeriodIds = Set(snapshot.paychecks
            .filter { $0.deletedAt == nil }
            .map(\.payPeriodId))
        let recordedPeriods = snapshot.payPeriods.filter {
            $0.deletedAt == nil && paycheckPeriodIds.contains($0.id)
        }
        let placeholderIds: Set<String> = Set(snapshot.payPeriods.compactMap { candidate in
            guard candidate.deletedAt == nil,
                  candidate.status == .closed,
                  candidate.incomePence == 0,
                  !paycheckPeriodIds.contains(candidate.id),
                  !snapshot.potAllocations.contains(where: { $0.deletedAt == nil && $0.payPeriodId == candidate.id }),
                  recordedPeriods.contains(where: {
                      $0.id != candidate.id &&
                      $0.startDate <= candidate.startDate &&
                      $0.endDate >= candidate.startDate
                  })
            else { return nil }
            return candidate.id
        })

        guard !placeholderIds.isEmpty else { return false }
        snapshot.payPeriods.removeAll { placeholderIds.contains($0.id) }
        return true
    }

    private func inferredPayday(
        containing date: String,
        from sourcePeriod: PayPeriod?,
        frequency: PayFrequency,
        monthlyAnchorDay: Int?
    ) -> String {
        guard let sourcePeriod else { return date }

        var payday = sourcePeriod.payday
        var dates = FinanceEngine.createNextPayPeriod(
            payday: payday,
            frequency: frequency,
            monthlyAnchorDay: monthlyAnchorDay
        )

        while dates.endDate < date {
            payday = dates.nextPayday
            dates = FinanceEngine.createNextPayPeriod(
                payday: payday,
                frequency: frequency,
                monthlyAnchorDay: monthlyAnchorDay
            )
        }

        while dates.startDate > date {
            let previousPayday = previousPayday(
                before: payday,
                frequency: frequency,
                monthlyAnchorDay: monthlyAnchorDay
            )
            guard previousPayday != payday else { break }
            payday = previousPayday
            dates = FinanceEngine.createNextPayPeriod(
                payday: payday,
                frequency: frequency,
                monthlyAnchorDay: monthlyAnchorDay
            )
        }

        return payday
    }

    private func previousPayday(
        before payday: String,
        frequency: PayFrequency,
        monthlyAnchorDay: Int?
    ) -> String {
        let date = FinanceEngine.parseDate(payday)
        switch frequency {
        case .weekly:
            return FinanceEngine.toIsoDate(FinanceEngine.addDays(date, days: -7))
        case .biweekly:
            return FinanceEngine.toIsoDate(FinanceEngine.addDays(date, days: -14))
        case .monthly:
            return FinanceEngine.toIsoDate(FinanceEngine.addMonthsClamped(
                date,
                months: -1,
                preferredDay: monthlyAnchorDay ?? FinanceEngine.dayOfMonth(payday)
            ))
        case .custom:
            return FinanceEngine.toIsoDate(FinanceEngine.addDays(date, days: -14))
        }
    }

    private func replace<T: Identifiable>(_ collection: inout [T], with item: T) where T.ID == String {
        guard let index = collection.firstIndex(where: { $0.id == item.id }) else { return }
        collection[index] = item
    }

    private func applyDebtPaymentAmount(debtId: String, amountPence: Int, now: String) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }
        let nextBalancePence = max(0, snapshot.debts[index].currentBalancePence - abs(amountPence))
        snapshot.debts[index].currentBalancePence = nextBalancePence
        snapshot.debts[index].status = nextBalancePence > 0 ? .active : .paidOff
        snapshot.debts[index].updatedAt = now
    }

    private enum ManualDebtFundingMatch {
        case none, matched(Int), invalid
    }

    /// Old payments did not store the allocation ID. Recover it only when both
    /// sides are unique; ambiguous or damaged links must never move money.
    private func manualDebtFundingMatch(for payment: DebtPayment) -> ManualDebtFundingMatch {
        let candidates = snapshot.potAllocations.indices.filter { index in
            let allocation = snapshot.potAllocations[index]
            if let id = payment.fundingAllocationId { return allocation.id == id }
            return payment.paymentType == .manualPayNow
                && allocation.id.hasPrefix("manual-debt-pay-now-")
                && allocation.source == .debtFunding
                && allocation.potId == payment.sourcePotId
                && allocation.createdAt == payment.createdAt
        }
        guard let index = candidates.first else {
            return payment.fundingAllocationId == nil ? .none : .invalid
        }
        let allocation = snapshot.potAllocations[index]
        guard candidates.count == 1, allocation.deletedAt == nil,
              allocation.source == .debtFunding, allocation.fundingPotId == nil,
              allocation.potId == payment.sourcePotId, allocation.debtId == payment.debtId,
              allocation.amountPence == payment.amountPence,
              allocation.debtScheduleItemId == payment.scheduleItemId,
              !snapshot.debtPayments.contains(where: { $0.id != payment.id && $0.deletedAt == nil && $0.fundingAllocationId == allocation.id })
        else { return .invalid }
        if payment.fundingAllocationId == nil {
            let matchingPayments = snapshot.debtPayments.filter {
                $0.deletedAt == nil && $0.paymentType == .manualPayNow
                    && $0.createdAt == payment.createdAt && $0.debtId == payment.debtId
                    && $0.sourcePotId == payment.sourcePotId
                    && $0.amountPence == payment.amountPence && $0.scheduleItemId == payment.scheduleItemId
            }
            guard matchingPayments.count == 1 else { return .invalid }
        }
        return .matched(index)
    }

    private func applyDebtPaymentCashChange(_ payment: DebtPayment, from previousNet: Int, to nextNet: Int, now: String) {
        guard !hasUnknownDebtFunding(payment) else {
            errorMessage = "The debt balance was updated. Review the pot refund: this older payment did not record its funding split."
            return
        }
        let contributions: [DebtPaymentPotContribution]
        if let recorded = payment.potContributions, !recorded.isEmpty {
            contributions = recorded
        } else if let potId = payment.sourcePotId {
            contributions = [DebtPaymentPotContribution(potId: potId, amountPence: payment.amountPence)]
        } else { return }
        let before = apportionedDebtFunding(contributions, total: previousNet)
        let after = apportionedDebtFunding(contributions, total: nextNet)
        for (old, new) in zip(before, after) {
            guard let index = snapshot.pots.firstIndex(where: { $0.id == old.potId }) else { continue }
            snapshot.pots[index].balancePence += old.amountPence - new.amountPence
            snapshot.pots[index].updatedAt = now
        }
    }

    /// Hierarchical proportional rounding conserves every penny and keeps each
    /// pot's retained contribution monotonic as refunds increase or decrease.
    private func apportionedDebtFunding(_ contributions: [DebtPaymentPotContribution], total: Int) -> [DebtPaymentPotContribution] {
        var weight = contributions.reduce(Decimal.zero) { $0 + Decimal(max(0, $1.amountPence)) }
        var remaining = max(0, total)
        return contributions.map { contribution in
            let amount = Decimal(max(0, contribution.amountPence))
            guard weight > 0 else { return .init(potId: contribution.potId, amountPence: 0) }
            var exact = Decimal(remaining) * amount / weight
            var rounded = Decimal.zero
            NSDecimalRound(&rounded, &exact, 0, .plain)
            let share = min(remaining, max(0, NSDecimalNumber(decimal: rounded).intValue))
            remaining -= share
            weight -= amount
            return .init(potId: contribution.potId, amountPence: share)
        }
    }

    private func hasUnknownDebtFunding(_ payment: DebtPayment) -> Bool {
        if let contributions = payment.potContributions { return contributions.isEmpty && payment.sourcePotId != nil }
        return payment.sourcePotId != nil && payment.note.hasSuffix("payment from linked debt pots")
    }

    /// Rebuild the capped occurrence total from surviving payments. Excess cash
    /// may pay down later principal without increasing this occurrence's total.
    private func reconcileDebtScheduleAfterReversal(_ payment: DebtPayment, from previousNet: Int, to nextNet: Int, now: String) {
        if let index = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == payment.scheduleItemId }) {
            var item = snapshot.debtPaymentScheduleItems[index]
            let limit = max(0, item.plannedAmountPence)
            let others = snapshot.debtPayments.filter {
                $0.id != payment.id && $0.deletedAt == nil && $0.debtId == payment.debtId && $0.scheduleItemId == item.id
            }
            let otherPaid = others.reduce(0) { total, linked in
                total + min(limit - total, max(0, linked.netAmountPence))
            }
            let previousLinked = otherPaid + min(limit - otherPaid, max(0, previousNet))
            // Preserve paid amounts evidenced only by an older aggregate record.
            let legacyPaid = max(0, min(limit, item.paidAmountPence) - previousLinked)
            let nextLinked = otherPaid + min(limit - otherPaid, max(0, nextNet))
            item.paidAmountPence = nextLinked + min(limit - nextLinked, legacyPaid)
            item.status = item.paidAmountPence >= item.plannedAmountPence ? .paid : (item.paidAmountPence > 0 ? .partFunded : .planned)
            let survivingDates = others.filter { $0.netAmountPence > 0 }.map(\.date) + (nextNet > 0 ? [payment.date] : [])
            item.paidDate = item.status == .paid ? (survivingDates.max() ?? item.paidDate) : nil
            item.updatedAt = now
            snapshot.debtPaymentScheduleItems[index] = item
        }
        updateDebtStatus(debtId: payment.debtId, asOf: todayIso, now: now)
    }

    private func restoreDebtPaymentAmount(_ payment: DebtPayment, now: String) {
        restoreDebtAmount(debtId: payment.debtId, amountPence: payment.effectivePrincipalPaidPence, now: now)
    }

    private func restoreDebtAmount(debtId: String, amountPence: Int, now: String) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }
        let restoredBalancePence = min(
            snapshot.debts[index].originalAmountPence,
            snapshot.debts[index].currentBalancePence + abs(amountPence)
        )
        snapshot.debts[index].currentBalancePence = restoredBalancePence
        snapshot.debts[index].status = restoredBalancePence > 0 ? .active : .paidOff
        snapshot.debts[index].updatedAt = now
    }

    @discardableResult
    private func ensureDebtSchedules(today: String) -> Bool {
        let existingDebtIds = Set(snapshot.debtPaymentScheduleItems.map(\.debtId))
        var changed = false
        for debt in snapshot.debts where debt.status.isActiveLike && debt.currentBalancePence > 0 && !existingDebtIds.contains(debt.id) {
            let scheduleItems = DebtPlannerEngine.generateSchedule(for: debt, payPeriods: snapshot.payPeriods, today: today)
            guard !scheduleItems.isEmpty else { continue }
            snapshot.debtPaymentScheduleItems.append(contentsOf: scheduleItems)
            changed = true
        }
        return changed
    }

    private func regenerateDebtSchedule(debtId: String, today: String, now: String) {
        guard let debt = snapshot.debts.first(where: { $0.id == debtId }) else { return }
        snapshot.debtPaymentScheduleItems.removeAll {
            $0.debtId == debtId && $0.status != .paid
        }
        guard debt.status.isActiveLike && debt.currentBalancePence > 0 else { return }
        snapshot.debtPaymentScheduleItems.append(contentsOf: DebtPlannerEngine.generateSchedule(for: debt, payPeriods: snapshot.payPeriods, today: today))
        updateDebtStatus(debtId: debtId, asOf: today, now: now)
    }

    private func recalculateDebtAfterPayment(debtId: String, date: String, mode: DebtRecalculationMode, now: String) {
        guard let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }
        if snapshot.debts[debtIndex].currentBalancePence <= 0 {
            snapshot.debts[debtIndex].currentBalancePence = 0
            snapshot.debts[debtIndex].status = .paidOff
            snapshot.debts[debtIndex].updatedAt = now
            cancelFutureDebtScheduleItems(debtId: debtId, now: now)
            return
        }

        if snapshot.debtPaymentScheduleItems.contains(where: {
            $0.debtId == debtId && $0.deletedAt == nil && $0.paidAmountPence > 0 &&
                $0.paidAmountPence < $0.plannedAmountPence && $0.status != .cancelled
        }) {
            updateDebtStatus(debtId: debtId, asOf: date, now: now)
            return
        }
        let futureItems = DebtPlannerEngine.generateSchedule(for: snapshot.debts[debtIndex], payPeriods: snapshot.payPeriods, today: date)
        snapshot.debtPaymentScheduleItems.removeAll { $0.debtId == debtId && $0.status != .paid }
        snapshot.debtPaymentScheduleItems.append(contentsOf: futureItems)
        updateDebtStatus(debtId: debtId, asOf: date, now: now)
    }

    private func cancelFutureDebtScheduleItems(debtId: String, now: String) {
        for index in snapshot.debtPaymentScheduleItems.indices where snapshot.debtPaymentScheduleItems[index].debtId == debtId && snapshot.debtPaymentScheduleItems[index].status != .paid {
            snapshot.debtPaymentScheduleItems[index].status = .cancelled
            snapshot.debtPaymentScheduleItems[index].plannedAmountPence = 0
            snapshot.debtPaymentScheduleItems[index].principalAmountPence = 0
            snapshot.debtPaymentScheduleItems[index].interestAmountPence = 0
            snapshot.debtPaymentScheduleItems[index].feeAmountPence = 0
            snapshot.debtPaymentScheduleItems[index].fundedAmountPence = 0
            snapshot.debtPaymentScheduleItems[index].updatedAt = now
        }
    }

    private func nextDebtScheduleItem(debtId: String, onOrAfter date: String) -> DebtPaymentScheduleItem? {
        if !snapshot.debtPaymentScheduleItems.contains(where: { $0.debtId == debtId }) {
            _ = ensureDebtSchedules(today: date)
        }
        return snapshot.debtPaymentScheduleItems
            .filter { $0.debtId == debtId && $0.status != .paid && $0.status != .cancelled && ($0.dueDate >= date || $0.paidAmountPence > 0) }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return $0.id < $1.id
                }
                return $0.dueDate < $1.dueDate
            }
            .first
    }

    private func replaceDebtScheduleItem(_ item: DebtPaymentScheduleItem) {
        if let index = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == item.id }) {
            snapshot.debtPaymentScheduleItems[index] = item
        } else {
            snapshot.debtPaymentScheduleItems.append(item)
        }
    }

    private func addDebtScheduleFunding(scheduleItemId: String, amountPence: Int, now: String) {
        guard let index = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == scheduleItemId }) else { return }
        let planned = max(0, snapshot.debtPaymentScheduleItems[index].plannedAmountPence - snapshot.debtPaymentScheduleItems[index].paidAmountPence)
        let funded = min(planned, max(0, snapshot.debtPaymentScheduleItems[index].fundedAmountPence + max(0, amountPence)))
        snapshot.debtPaymentScheduleItems[index].fundedAmountPence = funded
        snapshot.debtPaymentScheduleItems[index].status = funded >= planned ? .funded : (funded > 0 ? .partFunded : .planned)
        snapshot.debtPaymentScheduleItems[index].updatedAt = now
        updateDebtStatus(debtId: snapshot.debtPaymentScheduleItems[index].debtId, asOf: todayIso, now: now)
    }

    private func removeDebtScheduleFunding(scheduleItemId: String, amountPence: Int, now: String) {
        guard let index = snapshot.debtPaymentScheduleItems.firstIndex(where: { $0.id == scheduleItemId }) else { return }
        let funded = max(0, snapshot.debtPaymentScheduleItems[index].fundedAmountPence - max(0, amountPence))
        snapshot.debtPaymentScheduleItems[index].fundedAmountPence = funded
        snapshot.debtPaymentScheduleItems[index].status = funded > 0 ? .partFunded : .planned
        snapshot.debtPaymentScheduleItems[index].updatedAt = now
        updateDebtStatus(debtId: snapshot.debtPaymentScheduleItems[index].debtId, asOf: todayIso, now: now)
    }

    private func updateDebtStatus(debtId: String, asOf today: String, now: String) {
        guard let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }
        guard snapshot.debts[debtIndex].currentBalancePence > 0 else {
            snapshot.debts[debtIndex].status = .paidOff
            snapshot.debts[debtIndex].updatedAt = now
            return
        }
        let items = snapshot.debtPaymentScheduleItems
            .filter { $0.debtId == debtId && $0.status != .paid && $0.status != .cancelled }
            .sorted { $0.dueDate < $1.dueDate }
        let nextItem = items.first
        if items.contains(where: { $0.dueDate < today && $0.status != .paid }) {
            snapshot.debts[debtIndex].status = .overdue
        } else if nextItem?.dueDate == today {
            snapshot.debts[debtIndex].status = .dueToday
        } else if let nextItem, nextItem.status == .funded {
            snapshot.debts[debtIndex].status = .funded
        } else if let nextItem, nextItem.status == .partFunded {
            snapshot.debts[debtIndex].status = .partFunded
        } else if let nextItem, nextItem.dueDate <= FinanceEngine.addIsoDays(date: today, days: 7) {
            snapshot.debts[debtIndex].status = .dueSoon
        } else if snapshot.debts[debtIndex].interestType == .apr,
                  DebtPlannerEngine.hasInterestRisk(debt: snapshot.debts[debtIndex], paymentAmountPence: max(0, snapshot.debts[debtIndex].minimumPaymentPence + snapshot.debts[debtIndex].extraPaymentPence), days: 30) {
            snapshot.debts[debtIndex].status = .interestRisk
        } else {
            snapshot.debts[debtIndex].status = .active
        }
        snapshot.debts[debtIndex].updatedAt = now
    }
}

private enum PlannerAccountAvatarFileStore {
    private static let avatarPixelSize = CGSize(width: 512, height: 512)

    private static var directoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NewMoneyIPhone", isDirectory: true)
            .appendingPathComponent("AccountAvatars", isDirectory: true)
    }

    static func image(named imageName: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: imageName).path)
    }

    static func save(image: UIImage, named imageName: String) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try jpegData(for: image)
        try data.write(to: fileURL(for: imageName), options: [.atomic])
    }

    static func encodedImageDataBase64(for image: UIImage) throws -> String {
        try jpegData(for: image).base64EncodedString()
    }

    static func encodedImageDataBase64(named imageName: String) -> String? {
        try? Data(contentsOf: fileURL(for: imageName)).base64EncodedString()
    }

    static func removeImage(named imageName: String) throws {
        let url = fileURL(for: imageName)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func preparedImage(from image: UIImage) -> UIImage {
        let source = image.normalizedForPlannerAccountAvatar
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return image }

        let scale = max(avatarPixelSize.width / sourceSize.width, avatarPixelSize.height / sourceSize.height)
        let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let drawOrigin = CGPoint(
            x: (avatarPixelSize.width - drawSize.width) / 2,
            y: (avatarPixelSize.height - drawSize.height) / 2
        )

        return UIGraphicsImageRenderer(size: avatarPixelSize).image { _ in
            source.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
    }

    private static func jpegData(for image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.78) else {
            throw PlannerAccountAvatarError.encodingFailed
        }
        return data
    }

    private static func fileURL(for imageName: String) -> URL {
        directoryURL.appendingPathComponent(URL(fileURLWithPath: imageName).lastPathComponent)
    }
}

private enum PlannerAccountAvatarError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        "Unable to prepare that account photo."
    }
}

private extension UIImage {
    var normalizedForPlannerAccountAvatar: UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#if DEBUG
extension PlannerStore {
    /// The sole fixture-specific bootstrap point. It uses the same checklist commands as the app.
    @discardableResult
    func bootstrapPersonalJuly2026FixtureIfNeeded() -> Bool {
        guard snapshot.payPeriods.contains(where: { $0.id == PersonalJuly2026Fixture.payPeriodId }) else { return false }

        suppressAutomaticDueCatchUpForSimulation = true
        defer { suppressAutomaticDueCatchUpForSimulation = false }

        let periodId = PersonalJuly2026Fixture.payPeriodId
        let actions = [
            setRecurringBillFundingCompleted(paymentId: PersonalJuly2026Fixture.iCloudBillId, dueDate: "2026-07-10", payPeriodId: periodId, completed: true),
            setRecurringBillFundingCompleted(paymentId: PersonalJuly2026Fixture.runnaBillId, dueDate: "2026-07-18", payPeriodId: periodId, completed: true),
            setRecurringBillFundingCompleted(paymentId: PersonalJuly2026Fixture.appleCareBillId, dueDate: "2026-07-19", payPeriodId: periodId, completed: true),
            recordPersonalJuly2026AquaOpeningFundingIfNeeded(payPeriodId: periodId),
        ]
        return actions.contains(true)
    }

    /// The standard checklist intentionally omits this row when an existing pot balance covers it.
    /// The historical QA action still runs the production completion workflow with its raw source amount.
    @discardableResult
    private func recordPersonalJuly2026AquaOpeningFundingIfNeeded(payPeriodId: String) -> Bool {
        guard let card = snapshot.creditCards.first(where: { $0.id == PersonalJuly2026Fixture.aquaCardId && !$0.archived }),
              let pot = snapshot.pots.first(where: { $0.id == "pot-aqua" && !$0.archived })
        else { return false }

        return completeCardOpeningBalanceFunding(
            CreditCardOpeningBalanceFundingChecklistItem(
                id: PlannerDerivedData.cardOpeningBalanceFundingChecklistId(
                    cardId: card.id,
                    directDebitDate: PersonalJuly2026Fixture.aquaOpeningDueDate
                ),
                cardId: card.id,
                cardName: card.name,
                amountPence: 12_843,
                directDebitDate: PersonalJuly2026Fixture.aquaOpeningDueDate,
                payPeriodId: payPeriodId,
                potId: pot.id,
                potName: pot.name,
                isCompleted: false
            )
        )
    }

    func useSnapshotForSimulation(_ snapshot: PlannerSnapshot) {
        suppressAutomaticDueCatchUpForSimulation = true
        self.snapshot = snapshot
    }

    func setManualTodayForSimulation(_ todayIso: String) {
        guard FinanceEngine.isIsoDate(todayIso) else { return }
        snapshot.settings.appDateMode = .manual
        snapshot.settings.manualTodayIso = todayIso
        snapshot.settings.lastProcessedDateIso = todayIso
        snapshot.settings.updatedAt = DateUtilities.nowIsoString()
    }

    @discardableResult
    func applyDueScheduledPaymentsForSimulation(asOf todayIso: String) -> Bool {
        var changed = false
        changed = applyDueRecurringPotPayments(asOf: todayIso) || changed
        changed = applyDueCreditCardRecurringPayments(asOf: todayIso) || changed
        changed = applyDueBankAccountRecurringPayments(asOf: todayIso) || changed
        changed = applyDueLinkedDebtPotPayments(asOf: todayIso) || changed
        return changed
    }

    @discardableResult
    func applyDueCreditCardPaymentsForSimulation(asOf todayIso: String) -> Bool {
        var changed = false
        changed = applyDueCreditCardOpeningBalanceRepayments(asOf: todayIso) || changed
        changed = applyDueCreditCardStatementRepayments(asOf: todayIso) || changed
        return changed
    }
}
#endif

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isoDatePrefix: String? {
        let prefix = String(prefix(10))
        return FinanceEngine.isIsoDate(prefix) ? prefix : nil
    }
}

private extension Settings {
    func stamped() -> Settings {
        var copy = self
        copy.updatedAt = DateUtilities.nowIsoString()
        return copy
    }
}

private extension Pot {
    func stamped() -> Pot {
        var copy = self
        copy.updatedAt = DateUtilities.nowIsoString()
        return copy
    }
}

private extension RecurringPayment {
    func stamped() -> RecurringPayment {
        var copy = self
        copy.updatedAt = DateUtilities.nowIsoString()
        return copy
    }
}

private extension CreditCard {
    func stamped() -> CreditCard {
        var copy = self
        copy.updatedAt = DateUtilities.nowIsoString()
        return copy
    }
}

private extension Debt {
    func stamped() -> Debt {
        var copy = self
        copy.updatedAt = DateUtilities.nowIsoString()
        return copy
    }
}

private struct PlannerStoreLoadError: LocalizedError {
    var message = "Saved planner data must be recovered before making changes."
    var errorDescription: String? { message }
}
