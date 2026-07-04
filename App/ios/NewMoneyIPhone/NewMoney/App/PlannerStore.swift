import Foundation
import Combine
import SwiftUI

private struct LinkedPotContribution {
    var amountPence: Int
    var singlePotId: String?
    var singlePotName: String?
}

@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var snapshot: PlannerSnapshot = DefaultData.emptySnapshot
    @Published private(set) var plannerAccounts: [PlannerAccount] = []
    @Published private(set) var activePlannerAccountId: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: PlannerRepository
    private let accountRepository: PlannerAccountRepository?
    private var accountCollection: PlannerAccountCollection?
#if DEBUG
    private var suppressAutomaticDueCatchUpForSimulation = false
#endif

    init() {
        let repository = PlannerLaunchProfile.repository()
        self.repository = repository
        self.accountRepository = PlannerLaunchProfile.isUsingFixture() ? nil : FilePlannerAccountRepository()
    }

    init(repository: PlannerRepository) {
        self.repository = repository
        self.accountRepository = nil
    }

    init(repository: PlannerRepository, accountRepository: PlannerAccountRepository?) {
        self.repository = repository
        self.accountRepository = accountRepository
    }

    var snapshotPublisher: Published<PlannerSnapshot>.Publisher {
        $snapshot
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

    var activeCards: [CreditCard] {
        snapshot.creditCards.filter { !$0.archived }
    }

    var activeDebts: [Debt] {
        snapshot.debts.filter { $0.status.isActiveLike && $0.currentBalancePence > 0 }
    }

    var todayIso: String {
        FinanceEngine.getAppTodayIso(settings: snapshot.settings)
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
            if let accountRepository {
                let legacySnapshot = try await repository.loadSnapshot()
                let loadedCollection = try await accountRepository.loadAccountCollection()
                let collection = loadedCollection ?? PlannerAccountCollection.singleAccount(snapshot: legacySnapshot)
                applyAccountCollection(collection)
                var shouldPersist = loadedCollection == nil
                if prepareLoadedSnapshot() {
                    shouldPersist = true
                }
                if shouldPersist, let updatedCollection = updateActiveAccountSnapshot(snapshot) {
                    try await accountRepository.saveAccountCollection(updatedCollection)
                }
                return
            }

            let loadedSnapshot = try await repository.loadSnapshot()
            let migration = DefaultData.migratedSnapshot(loadedSnapshot)
            snapshot = migration.snapshot
            var shouldPersist = migration.didChange
            if ensureDebtSchedules(today: todayIso) {
                shouldPersist = true
            }
            if catchUpDueObligations(to: todayIso) {
                shouldPersist = true
            }
            if shouldPersist {
                try await repository.saveSnapshot(snapshot)
            }
        } catch {
            errorMessage = "Unable to load local planner data."
        }
    }

    func replaceSnapshot(_ replacement: PlannerSnapshot) async throws {
        let migration = DefaultData.migratedSnapshot(replacement)
        snapshot = migration.snapshot
        if let accountRepository, let collection = updateActiveAccountSnapshot(snapshot) {
            try await accountRepository.saveAccountCollection(collection)
        } else {
            try await repository.saveSnapshot(snapshot)
        }
    }

    func saveCurrentSnapshot() async throws {
        if let accountRepository, let collection = updateActiveAccountSnapshot(snapshot) {
            try await accountRepository.saveAccountCollection(collection)
        } else {
            try await repository.saveSnapshot(snapshot)
        }
    }

    func resetLocalData() {
        snapshot = DefaultData.emptySnapshot
        if let accountRepository, let collection = updateActiveAccountSnapshot(snapshot) {
            Task {
                do {
                    try await accountRepository.saveAccountCollection(collection)
                } catch {
                    await MainActor.run {
                        errorMessage = "Unable to reset local planner data."
                    }
                }
            }
            return
        }
        Task {
            do {
                try await repository.resetSnapshot()
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to reset local planner data."
                }
            }
        }
    }

    func createPlannerAccount(named name: String) async throws {
        guard let accountRepository else { return }
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
        try await accountRepository.saveAccountCollection(collection)
    }

    func switchPlannerAccount(id: String) async throws {
        guard let accountRepository else { return }
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
        if shouldPersist, let updatedCollection = updateActiveAccountSnapshot(snapshot) {
            collection = updatedCollection
        }
        try await accountRepository.saveAccountCollection(collection)
    }

    func renamePlannerAccount(id: String, name: String) async throws {
        guard let accountRepository else { return }
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
        try await accountRepository.saveAccountCollection(collection)
    }

    func deletePlannerAccount(id: String) async throws {
        guard let accountRepository else { return }
        _ = updateActiveAccountSnapshot(snapshot)
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == id })
        else {
            throw PlannerAccountError.missingAccount
        }
        guard collection.accounts.count > 1 else {
            throw PlannerAccountError.cannotDeleteLastAccount
        }

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
        try await accountRepository.saveAccountCollection(collection)
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

    func createPayPeriod(payday: String, hoursWorked: Double, hourlyRatePence: Int, actualAmountPence: Int?, payFrequency: PayFrequency? = nil) {
        let frequency = payFrequency ?? snapshot.settings.payFrequency
        let dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: frequency)
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
            deletedAt: nil
        )
        let paycheck = Paycheck(
            id: "paycheck-\(UUID().uuidString.lowercased())",
            payPeriodId: id,
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            calculatedAmountPence: amount,
            actualAmountPence: actualAmountPence,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )

        snapshot.payPeriods.insert(period, at: 0)
        snapshot.paychecks.insert(paycheck, at: 0)
        persist()
    }

    func updatePaycheck(id: String, payday: String, hoursWorked: Double, hourlyRatePence: Int, actualAmountPence: Int?, payFrequency: PayFrequency? = nil) {
        guard let paycheckIndex = snapshot.paychecks.firstIndex(where: { $0.id == id }) else { return }
        let payPeriodId = snapshot.paychecks[paycheckIndex].payPeriodId
        let now = DateUtilities.nowIsoString()
        let amount = FinanceEngine.calculatePaycheckAmount(
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            actualAmountPence: actualAmountPence
        )
        let periodFrequency = payFrequency ?? snapshot.payPeriods.first(where: { $0.id == payPeriodId })?.payFrequency ?? snapshot.settings.payFrequency
        let dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: periodFrequency)

        snapshot.paychecks[paycheckIndex].hoursWorked = hoursWorked
        snapshot.paychecks[paycheckIndex].hourlyRatePence = hourlyRatePence
        snapshot.paychecks[paycheckIndex].calculatedAmountPence = amount
        snapshot.paychecks[paycheckIndex].actualAmountPence = actualAmountPence
        snapshot.paychecks[paycheckIndex].updatedAt = now

        if let periodIndex = snapshot.payPeriods.firstIndex(where: { $0.id == payPeriodId }) {
            snapshot.payPeriods[periodIndex].startDate = dates.startDate
            snapshot.payPeriods[periodIndex].endDate = dates.endDate
            snapshot.payPeriods[periodIndex].payday = payday
            snapshot.payPeriods[periodIndex].nextPayday = dates.nextPayday
            snapshot.payPeriods[periodIndex].payFrequency = periodFrequency
            snapshot.payPeriods[periodIndex].incomePence = amount
            snapshot.payPeriods[periodIndex].updatedAt = now
        }

        persist()
    }

    func deletePaycheck(id: String) {
        guard let paycheck = snapshot.paychecks.first(where: { $0.id == id }) else { return }
        let now = DateUtilities.nowIsoString()
        let payPeriodId = paycheck.payPeriodId
        let linkedAllocations = snapshot.potAllocations.filter { $0.payPeriodId == payPeriodId }

        for allocation in linkedAllocations {
            guard let potIndex = snapshot.pots.firstIndex(where: { $0.id == allocation.potId }) else { continue }
            snapshot.pots[potIndex].balancePence -= abs(allocation.amountPence)
            snapshot.pots[potIndex].updatedAt = now
        }

        snapshot.potAllocations.removeAll { $0.payPeriodId == payPeriodId }
        snapshot.payPeriods.removeAll { $0.id == payPeriodId }
        snapshot.paychecks.removeAll { $0.id == id }
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
        linkedDebtId: String? = nil
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
            archived: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.pots.insert(pot, at: 0)
        persist()
    }

    func updatePot(_ pot: Pot) {
        replace(&snapshot.pots, with: pot.stamped())
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

    func recordTransaction(potId: String?, creditCardId: String?, paymentMethod: PaymentMethod, amountPence: Int, type: TransactionType, date: String, note: String) {
        let now = DateUtilities.nowIsoString()
        let transaction = Transaction(
            id: DateUtilities.newId(prefix: "transaction"),
            potId: potId,
            payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id,
            amountPence: abs(amountPence),
            type: type,
            paymentMethod: paymentMethod,
            creditCardId: creditCardId,
            recurringPaymentId: nil,
            date: date,
            note: note,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        snapshot.transactions.insert(transaction, at: 0)

        if let potId, paymentMethod == .pot, let index = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            snapshot.pots[index] = FinanceEngine.applyTransactionToPot(snapshot.pots[index], amountPence: abs(amountPence), type: type)
        }

        persist()
    }

    func updateTransaction(id: String, potId: String?, creditCardId: String?, paymentMethod: PaymentMethod, amountPence: Int, date: String, note: String) {
        let amount = abs(amountPence)
        let cleanPotId = paymentMethod == .pot ? potId?.nilIfBlank : nil
        let cleanCardId = paymentMethod == .creditCard ? creditCardId?.nilIfBlank : nil
        guard amount > 0,
              let index = snapshot.transactions.firstIndex(where: { $0.id == id }),
              snapshot.transactions[index].type == .spending,
              paymentMethod == .pot ? cleanPotId != nil : cleanCardId != nil
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
        updated.paymentMethod = paymentMethod
        updated.creditCardId = cleanCardId
        updated.date = date
        updated.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = now
        snapshot.transactions[index] = updated

        applyPotBalanceForTransaction(updated)
        restoreCardSpendFundingAllocations(transactionId: updated.id, payPeriodIds: fundedCardSpendPayPeriodIds)
        persist()
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

    func addRecurringPayment(name: String, amountPence: Int, dueDay: Int?, frequency: RecurringFrequency, potId: String?, creditCardId: String?, priority: RecurringPriority) {
        let now = DateUtilities.nowIsoString()
        let cleanCardId = creditCardId?.nilIfBlank
        let cleanPotId = normalizedRecurringPaymentPotId(potId: potId, creditCardId: cleanCardId)
        let payment = RecurringPayment(
            id: DateUtilities.newId(prefix: "recurring"),
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: nil,
            frequency: frequency,
            potId: cleanPotId,
            creditCardId: cleanCardId,
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
        var updated = payment.stamped()
        updated.creditCardId = payment.creditCardId?.nilIfBlank
        updated.potId = normalizedRecurringPaymentPotId(potId: payment.potId, creditCardId: updated.creditCardId)
        replace(&snapshot.recurringPayments, with: updated)
        persist()
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
        let statementDate = statementDay.map { FinanceEngine.monthlyDate(onOrAfter: todayIso, day: $0) }
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

    func recordManualDebtPayment(
        debtId: String,
        amountPence: Int,
        date: String,
        paymentType: DebtPaymentType,
        recalculationMode: DebtRecalculationMode,
        note: String
    ) {
        let requestedAmountPence = max(0, abs(amountPence))
        guard requestedAmountPence > 0,
              let debtIndex = snapshot.debts.firstIndex(where: { $0.id == debtId && $0.currentBalancePence > 0 && $0.status.isActiveLike })
        else { return }

        let now = DateUtilities.nowIsoString()
        let linkedPotIndex = snapshot.pots.indices
            .filter { snapshot.pots[$0].linkedDebtId == debtId && !snapshot.pots[$0].archived }
            .sorted { snapshot.pots[$0].name < snapshot.pots[$1].name }
            .first

        let cappedAmountPence = min(requestedAmountPence, max(0, snapshot.debts[debtIndex].currentBalancePence))
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

        let scheduleItem = nextDebtScheduleItem(debtId: debtId, onOrAfter: date)
        if let linkedPotIndex {
            let allocationId = "manual-debt-pay-now-\(debtId)-\(date)-\(UUID().uuidString.lowercased())"
            snapshot.potAllocations.insert(
                PotAllocation(
                    id: allocationId,
                    payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: date)?.id ?? selectedPayPeriod?.id ?? "",
                    potId: snapshot.pots[linkedPotIndex].id,
                    fundingPotId: nil,
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

        let application = DebtPlannerEngine.applyPayment(
            debt: snapshot.debts[debtIndex],
            scheduleItem: scheduleItem,
            amountPence: cappedAmountPence,
            date: date,
            sourcePotId: linkedPotIndex.map { snapshot.pots[$0].id },
            paymentType: paymentType,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )

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
        let requestedAmountPence = abs(amountPence)
        guard requestedAmountPence > 0,
              let paymentIndex = snapshot.debtPayments.firstIndex(where: { $0.id == id }),
              snapshot.debts.contains(where: { $0.id == debtId })
        else { return }

        let now = DateUtilities.nowIsoString()
        let existingPayment = snapshot.debtPayments[paymentIndex]

        if existingPayment.debtId != debtId,
           let targetDebt = snapshot.debts.first(where: { $0.id == debtId }),
           targetDebt.currentBalancePence <= 0 {
            return
        }

        restoreDebtPaymentAmount(existingPayment, now: now)
        guard let targetIndex = snapshot.debts.firstIndex(where: { $0.id == debtId }) else { return }

        let appliedAmountPence = min(requestedAmountPence, max(0, snapshot.debts[targetIndex].currentBalancePence))
        guard appliedAmountPence > 0 else {
            applyDebtPaymentAmount(debtId: existingPayment.debtId, amountPence: existingPayment.amountPence, now: now)
            persist()
            return
        }

        snapshot.debtPayments[paymentIndex].debtId = debtId
        snapshot.debtPayments[paymentIndex].amountPence = appliedAmountPence
        snapshot.debtPayments[paymentIndex].date = date
        snapshot.debtPayments[paymentIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.debtPayments[paymentIndex].updatedAt = now
        applyDebtPaymentAmount(debtId: debtId, amountPence: appliedAmountPence, now: now)
        persist()
    }

    func deleteDebtPayment(id: String) {
        guard let paymentIndex = snapshot.debtPayments.firstIndex(where: { $0.id == id }) else { return }
        let now = DateUtilities.nowIsoString()
        let payment = snapshot.debtPayments.remove(at: paymentIndex)
        restoreDebtPaymentAmount(payment, now: now)
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
        let items = PlannerDerivedData.recurringBillFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: snapshot.payPeriods.first(where: { $0.id == payPeriodId })
        )
        guard let item = items.first(where: { $0.paymentId == paymentId && $0.dueDate == dueDate }) else {
            return false
        }

        if completed {
            return completeRecurringBillFunding(item)
        }

        return reverseRecurringBillFunding(item)
    }

    @discardableResult
    func setCardSpendFundingCompleted(transactionId: String, payPeriodId: String, completed: Bool) -> Bool {
        let items = PlannerDerivedData.cardSpendFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: snapshot.payPeriods.first(where: { $0.id == payPeriodId })
        )
        guard let item = items.first(where: { $0.transactionId == transactionId }) else {
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
            payPeriod: snapshot.payPeriods.first(where: { $0.id == payPeriodId })
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
    func setDebtFundingCompleted(debtId: String, dueDate: String, payPeriodId: String, completed: Bool) -> Bool {
        let items = PlannerDerivedData.debtFundingChecklistItems(
            snapshot: snapshot,
            payPeriod: snapshot.payPeriods.first(where: { $0.id == payPeriodId })
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
            payPeriod: snapshot.payPeriods.first(where: { $0.id == payPeriodId })
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
    func applyDueLinkedPotObligations(asOf todayIso: String) -> Bool {
        var changed = false
        changed = applyDueRecurringPotPayments(asOf: todayIso) || changed
        changed = applyDueCreditCardRecurringPayments(asOf: todayIso) || changed
        changed = applyDueCreditCardOpeningBalanceRepayments(asOf: todayIso) || changed
        changed = applyDueCreditCardStatementRepayments(asOf: todayIso) || changed
        changed = applyDueLinkedDebtPotPayments(asOf: todayIso) || changed
        return changed
    }

    private func applyDueRecurringPotPayments(asOf todayIso: String) -> Bool {
        let now = DateUtilities.nowIsoString()
        let directPayments = snapshot.recurringPayments.filter { payment in
            payment.active && payment.creditCardId == nil && payment.potId != nil
        }
        var changed = false

        for payment in directPayments {
            let startDate = recurringApplicationStartDate(payment, todayIso: todayIso)
            let occurrences = PlannerDerivedData.recurringOccurrences(payments: [payment], startDate: startDate, endDate: todayIso)

            for occurrence in occurrences {
                let transactionId = recurringTransactionId(paymentId: payment.id, dueDate: occurrence.dueDate)

                guard !snapshot.transactions.contains(where: { $0.id == transactionId }),
                      let potId = payment.potId,
                      let potIndex = snapshot.pots.firstIndex(where: { $0.id == potId && !$0.archived }),
                      occurrence.amountPence > 0
                else { continue }

                snapshot.transactions.insert(
                    Transaction(
                        id: transactionId,
                        potId: potId,
                        payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: occurrence.dueDate)?.id,
                        amountPence: occurrence.amountPence,
                        type: .spending,
                        paymentMethod: .pot,
                        creditCardId: nil,
                        recurringPaymentId: payment.id,
                        date: occurrence.dueDate,
                        note: payment.name,
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

    private func applyDueCreditCardRecurringPayments(asOf todayIso: String) -> Bool {
        let now = DateUtilities.nowIsoString()
        let cardPayments = snapshot.recurringPayments.filter { payment in
            payment.active && payment.creditCardId != nil
        }
        var changed = false

        for payment in cardPayments {
            let startDate = recurringApplicationStartDate(payment, todayIso: todayIso)
            let occurrences = PlannerDerivedData.recurringOccurrences(payments: [payment], startDate: startDate, endDate: todayIso)

            for occurrence in occurrences {
                guard let cardId = payment.creditCardId,
                      snapshot.creditCards.contains(where: { $0.id == cardId && !$0.archived }),
                      occurrence.amountPence > 0
                else { continue }

                let transactionId = cardRecurringTransactionId(paymentId: payment.id, dueDate: occurrence.dueDate)
                if let existingTransactionIndex = cardRecurringTransactionIndex(
                    transactionId: transactionId,
                    paymentId: payment.id,
                    dueDate: occurrence.dueDate,
                    cardId: cardId
                ) {
                    let consumedPotId = consumeCardBillFundingIfAvailable(
                        payment: payment,
                        occurrence: occurrence,
                        cardId: cardId,
                        existingTransactionIndex: existingTransactionIndex,
                        now: now
                    )
                    changed = consumedPotId != nil || changed
                    continue
                }

                let consumedPotId = consumeCardBillFundingIfAvailable(
                    payment: payment,
                    occurrence: occurrence,
                    cardId: cardId,
                    existingTransactionIndex: nil,
                    now: now
                )

                snapshot.transactions.insert(
                    Transaction(
                        id: transactionId,
                        potId: consumedPotId,
                        payPeriodId: PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: occurrence.dueDate)?.id,
                        amountPence: occurrence.amountPence,
                        type: .spending,
                        paymentMethod: .creditCard,
                        creditCardId: cardId,
                        recurringPaymentId: payment.id,
                        date: occurrence.dueDate,
                        note: payment.name,
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
                asOfDate: todayIso
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
                let repaymentAmountPence = min(
                    statementPayment.actualDuePence,
                    cardSummary.actualOwedPence
                )

                guard repaymentAmountPence > 0 else { continue }

                let consumedBillFundingPence = min(
                    repaymentAmountPence,
                    PlannerDerivedData.linkedCreditCardConsumedBillFundingPence(
                        cardId: card.id,
                        snapshot: snapshot,
                        startDate: creditCardStatementCycleStartDate(card: card, statementDate: statementPayment.statementDate),
                        endDate: statementPayment.statementDate
                    )
                )
                let remainingFundingPence = max(0, repaymentAmountPence - consumedBillFundingPence)
                let linkedPotContribution = deductLinkedCreditCardPots(
                    creditCardId: card.id,
                    amountPence: remainingFundingPence,
                    now: now
                )
                let paycheckContributionPence = max(0, remainingFundingPence - linkedPotContribution.amountPence)
                let source: CreditCardRepaymentSource = (consumedBillFundingPence > 0 || linkedPotContribution.amountPence > 0) ? .linkedPotStatement : .automaticStatement

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
                    snapshot.debtPaymentScheduleItems[scheduleIndex].fundedAmountPence = fundedPence
                    snapshot.debtPaymentScheduleItems[scheduleIndex].status = fundedPence > 0 ? (item.dueDate < todayIso ? .overdue : .partFunded) : (item.dueDate < todayIso ? .overdue : .missed)
                    snapshot.debtPaymentScheduleItems[scheduleIndex].updatedAt = now
                    updateDebtStatus(debtId: item.debtId, asOf: todayIso, now: now)
                    changed = true
                }
                continue
            }

            var remainingToDeductPence = requiredPaymentPence
            for index in linkedPotIndices {
                if remainingToDeductPence <= 0 {
                    break
                }

                let potDeductionPence = min(max(0, snapshot.pots[index].balancePence), remainingToDeductPence)
                snapshot.pots[index].balancePence -= potDeductionPence
                snapshot.pots[index].updatedAt = now
                remainingToDeductPence -= potDeductionPence
            }

            let note = linkedPotIndices.count == 1
                ? "Automatic \(debt.name) payment from \(snapshot.pots[linkedPotIndices[0]].name)"
                : "Automatic \(debt.name) payment from linked debt pots"

            let application = DebtPlannerEngine.applyPayment(
                debt: debt,
                scheduleItem: item,
                amountPence: requiredPaymentPence,
                date: item.dueDate,
                sourcePotId: linkedPotIndices.first.map { snapshot.pots[$0].id },
                paymentType: .scheduled,
                note: note
            )

            var payment = application.payment
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

    private func consumeCardBillFundingIfAvailable(
        payment: RecurringPayment,
        occurrence: RecurringPaymentOccurrence,
        cardId: String,
        existingTransactionIndex: Int?,
        now: String
    ) -> String? {
        guard let potId = payment.potId,
              let potIndex = snapshot.pots.firstIndex(where: {
                  $0.id == potId &&
                  !$0.archived
              })
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

        if let existingTransactionIndex,
           snapshot.transactions[existingTransactionIndex].potId != nil {
            return nil
        }

        guard fundedPence >= occurrence.amountPence,
              occurrence.amountPence > 0,
              snapshot.pots[potIndex].balancePence >= occurrence.amountPence
        else { return nil }

        snapshot.pots[potIndex].balancePence -= occurrence.amountPence
        snapshot.pots[potIndex].updatedAt = now
        if let existingTransactionIndex {
            snapshot.transactions[existingTransactionIndex].potId = potId
            snapshot.transactions[existingTransactionIndex].updatedAt = now
        }
        return potId
    }

    private func cardRecurringTransactionIndex(
        transactionId: String,
        paymentId: String,
        dueDate: String,
        cardId: String
    ) -> Int? {
        snapshot.transactions.firstIndex {
            $0.id == transactionId ||
            (
                $0.type == .spending &&
                $0.paymentMethod == .creditCard &&
                $0.creditCardId == cardId &&
                $0.recurringPaymentId == paymentId &&
                $0.date == dueDate
            )
        }
    }

    private func recurringApplicationStartDate(_ payment: RecurringPayment, todayIso: String) -> String {
        guard let createdDate = payment.createdAt.isoDatePrefix else {
            return todayIso
        }

        return createdDate <= todayIso ? createdDate : todayIso
    }

    private func recurringTransactionId(paymentId: String, dueDate: String) -> String {
        "recurring-\(paymentId)-\(dueDate)"
    }

    private func cardRecurringTransactionId(paymentId: String, dueDate: String) -> String {
        "card-recurring-\(paymentId)-\(dueDate)"
    }

    private func cardBillFundingAllocationId(paymentId: String, dueDate: String, payPeriodId: String) -> String {
        "card-bill-funding-allocation-\(paymentId)-\(dueDate)-\(payPeriodId)"
    }

    private func recurringBillFundingAllocationId(paymentId: String, dueDate: String, payPeriodId: String) -> String {
        "recurring-bill-funding-allocation-\(paymentId)-\(dueDate)-\(payPeriodId)"
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
            $0.id == newId ||
            $0.id == legacyLinkedPotId ||
            (
                $0.creditCardId == creditCardId &&
                $0.statementDate == statementDate &&
                ($0.directDebitDate ?? $0.date) == directDebitDate
            )
        }
    }

    private func creditCardStatementCycleStartDate(card: CreditCard, statementDate: String) -> String {
        if statementDate == card.statementDate {
            return card.createdAt.isoDatePrefix ?? statementDate
        }

        let previousStatementDate = PlannerDerivedData.addIsoMonthsClamped(date: statementDate, months: -1)
        return FinanceEngine.addIsoDays(date: previousStatementDate, days: 1)
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
        }

        return LinkedPotContribution(
            amountPence: contributedPence,
            singlePotId: contributingPotIds.count == 1 ? contributingPotIds[0] : nil,
            singlePotName: contributingPotNames.count == 1 ? contributingPotNames[0] : nil
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
                amountPence: item.amountPence,
                source: .recurringBillFunding,
                recurringPaymentId: item.paymentId,
                recurringDueDate: item.dueDate,
                debtId: nil,
                debtDueDate: nil,
                transactionId: nil,
                transactionDate: nil,
                creditCardId: item.cardId,
                creditCardDirectDebitDate: nil,
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
            snapshot.potAllocations[$0].payPeriodId == item.payPeriodId &&
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
              snapshot.pots.contains(where: { $0.id == item.potId && !$0.archived })
        else { return true }

        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: allocationId,
                payPeriodId: item.payPeriodId,
                potId: item.potId,
                fundingPotId: nil,
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
        if shouldPersist {
            persist()
        }
        return true
    }

    private func reverseCardSpendFunding(_ item: CardSpendFundingChecklistItem, shouldPersist: Bool = true) -> Bool {
        let matchingAllocationIndices = snapshot.potAllocations.indices.filter {
            snapshot.potAllocations[$0].deletedAt == nil &&
            snapshot.potAllocations[$0].payPeriodId == item.payPeriodId &&
            snapshot.potAllocations[$0].source == .cardSpendFunding &&
            snapshot.potAllocations[$0].transactionId == item.transactionId
        }
        guard !matchingAllocationIndices.isEmpty else { return true }

        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }
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

        for index in matchingAllocationIndices.sorted(by: >) {
            snapshot.potAllocations.remove(at: index)
        }

        return Array(payPeriodIds)
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

    private func applyAccountCollection(_ collection: PlannerAccountCollection) {
        let sanitizedCollection = sanitizedAccountCollection(collection)
        accountCollection = sanitizedCollection
        plannerAccounts = sanitizedCollection.accounts
        activePlannerAccountId = sanitizedCollection.activeAccountId
        snapshot = sanitizedCollection.activeAccount?.snapshot ?? DefaultData.emptySnapshot
    }

    private func sanitizedAccountCollection(_ collection: PlannerAccountCollection) -> PlannerAccountCollection {
        var accounts = Array(collection.accounts.prefix(PlannerAccountCollection.maxAccounts))
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
        return PlannerAccountCollection(
            activeAccountId: activeId,
            accounts: accounts,
            updatedAt: collection.updatedAt
        )
    }

    @discardableResult
    private func updateActiveAccountSnapshot(_ activeSnapshot: PlannerSnapshot) -> PlannerAccountCollection? {
        guard var collection = accountCollection,
              let index = collection.accounts.firstIndex(where: { $0.id == collection.activeAccountId })
        else {
            return nil
        }

        let now = DateUtilities.nowIsoString()
        collection.accounts[index].snapshot = activeSnapshot
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
        let colors = ["#F97316", "#14B8A6", "#8B5CF6"]
        return colors[min(max(index, 0), colors.count - 1)]
    }

    private func persist() {
#if DEBUG
        if !suppressAutomaticDueCatchUpForSimulation {
            _ = catchUpDueObligations(to: todayIso)
        }
#else
        _ = catchUpDueObligations(to: todayIso)
#endif
        let snapshot = snapshot
        if let accountRepository, let collection = updateActiveAccountSnapshot(snapshot) {
            Task {
                do {
                    try await accountRepository.saveAccountCollection(collection)
                } catch {
                    await MainActor.run {
                        errorMessage = "Unable to save local planner data."
                    }
                }
            }
            return
        }
        Task {
            do {
                try await repository.saveSnapshot(snapshot)
            } catch {
                await MainActor.run {
                    errorMessage = "Unable to save local planner data."
                }
            }
        }
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

        while cursor <= targetDate {
            changed = ensureCurrentPayPeriodExists(containing: cursor) || changed
            changed = applyDueLinkedPotObligations(asOf: cursor) || changed
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

        let sourcePeriod = snapshot.payPeriods
            .filter { $0.deletedAt == nil }
            .sorted(by: sortPayPeriodsForSelection)
            .first
        let frequency = sourcePeriod?.payFrequency ?? snapshot.settings.payFrequency
        let payday = inferredPayday(containing: date, from: sourcePeriod, frequency: frequency)
        let dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: frequency)
        guard dates.startDate <= date && dates.endDate >= date else { return false }

        let id = "pay-period-\(dates.startDate)"
        let now = DateUtilities.nowIsoString()
        if let existingIndex = snapshot.payPeriods.firstIndex(where: { $0.id == id }) {
            snapshot.payPeriods[existingIndex].status = .active
            snapshot.payPeriods[existingIndex].updatedAt = now
        } else {
            let incomePence = sourcePeriod?.incomePence ?? 0
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
                deletedAt: nil
            )
            snapshot.payPeriods.insert(period, at: 0)

            if !snapshot.paychecks.contains(where: { $0.payPeriodId == id }) {
                snapshot.paychecks.insert(
                    Paycheck(
                        id: "paycheck-\(id)",
                        payPeriodId: id,
                        hoursWorked: 0,
                        hourlyRatePence: 0,
                        calculatedAmountPence: incomePence,
                        actualAmountPence: incomePence,
                        createdAt: now,
                        updatedAt: now,
                        deletedAt: nil
                    ),
                    at: 0
                )
            }
        }

        for index in snapshot.payPeriods.indices where snapshot.payPeriods[index].status == .active && snapshot.payPeriods[index].id != id {
            snapshot.payPeriods[index].status = .closed
            snapshot.payPeriods[index].updatedAt = now
        }

        return true
    }

    private func inferredPayday(containing date: String, from sourcePeriod: PayPeriod?, frequency: PayFrequency) -> String {
        guard let sourcePeriod else { return date }

        var payday = sourcePeriod.payday
        var dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: frequency)

        while dates.endDate < date {
            payday = dates.nextPayday
            dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: frequency)
        }

        while dates.startDate > date {
            let previousPayday = previousPayday(before: payday, frequency: frequency)
            guard previousPayday != payday else { break }
            payday = previousPayday
            dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: frequency)
        }

        return payday
    }

    private func previousPayday(before payday: String, frequency: PayFrequency) -> String {
        let date = FinanceEngine.parseDate(payday)
        switch frequency {
        case .weekly:
            return FinanceEngine.toIsoDate(FinanceEngine.addDays(date, days: -7))
        case .biweekly:
            return FinanceEngine.toIsoDate(FinanceEngine.addDays(date, days: -14))
        case .monthly, .custom:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            return FinanceEngine.toIsoDate(calendar.date(byAdding: .month, value: -1, to: date) ?? date)
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

    private func restoreDebtPaymentAmount(_ payment: DebtPayment, now: String) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == payment.debtId }) else { return }
        let restoredBalancePence = min(
            snapshot.debts[index].originalAmountPence,
            snapshot.debts[index].currentBalancePence + abs(payment.amountPence)
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
            .filter { $0.debtId == debtId && $0.status != .paid && $0.status != .cancelled && $0.dueDate >= date }
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

#if DEBUG
extension PlannerStore {
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
