import Foundation
import SwiftUI

@MainActor
final class PlannerStore: ObservableObject {
    @Published private(set) var snapshot: PlannerSnapshot = DefaultData.emptySnapshot
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: PlannerRepository
    private let paydayCleanupKey = "NewMoneyIPhone.didClearPaydayActivityV1"

    init(repository: PlannerRepository = FilePlannerRepository()) {
        self.repository = repository
    }

    var selectedPayPeriod: PayPeriod? {
        snapshot.payPeriods
            .filter { $0.status == .active || $0.status == .planned }
            .sorted { $0.payday > $1.payday }
            .first ?? snapshot.payPeriods.sorted { $0.payday > $1.payday }.first
    }

    var activePots: [Pot] {
        snapshot.pots.filter { !$0.archived }
    }

    var activeCards: [CreditCard] {
        snapshot.creditCards.filter { !$0.archived }
    }

    var activeDebts: [Debt] {
        snapshot.debts.filter { $0.status == .active }
    }

    var todayIso: String {
        FinanceEngine.getAppTodayIso(settings: snapshot.settings)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            snapshot = try await repository.loadSnapshot()
            await clearPaydayActivityOnFirstLoadIfNeeded()
        } catch {
            errorMessage = "Unable to load local planner data."
            snapshot = DefaultData.emptySnapshot
        }
    }

    func resetLocalData() {
        snapshot = DefaultData.emptySnapshot
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

    func updateSettings(_ settings: Settings) {
        snapshot.settings = settings.stamped()
        persist()
    }

    func createPayPeriod(payday: String, hoursWorked: Double, hourlyRatePence: Int, actualAmountPence: Int?) {
        let dates = FinanceEngine.createNextPayPeriod(payday: payday, frequency: snapshot.settings.payFrequency)
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
            payFrequency: snapshot.settings.payFrequency,
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

    func updatePaycheck(id: String, payday: String, hoursWorked: Double, hourlyRatePence: Int, actualAmountPence: Int?) {
        guard let paycheckIndex = snapshot.paychecks.firstIndex(where: { $0.id == id }) else { return }
        let payPeriodId = snapshot.paychecks[paycheckIndex].payPeriodId
        let now = DateUtilities.nowIsoString()
        let amount = FinanceEngine.calculatePaycheckAmount(
            hoursWorked: hoursWorked,
            hourlyRatePence: hourlyRatePence,
            actualAmountPence: actualAmountPence
        )
        let periodFrequency = snapshot.payPeriods.first(where: { $0.id == payPeriodId })?.payFrequency ?? snapshot.settings.payFrequency
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

    func addPot(name: String, type: PotType, category: String?, targetPence: Int?, color: String) {
        let now = DateUtilities.nowIsoString()
        let pot = Pot(
            id: DateUtilities.newId(prefix: "pot"),
            name: name,
            type: type,
            category: category?.nilIfBlank,
            icon: nil,
            balancePence: 0,
            targetPence: targetPence,
            color: color,
            linkedCreditCardId: nil,
            linkedDebtId: nil,
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

    func recordTransaction(potId: String?, creditCardId: String?, paymentMethod: PaymentMethod, amountPence: Int, type: TransactionType, date: String, note: String) {
        let now = DateUtilities.nowIsoString()
        let transaction = Transaction(
            id: DateUtilities.newId(prefix: "transaction"),
            potId: potId,
            payPeriodId: selectedPayPeriod?.id,
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

    func addRecurringPayment(name: String, amountPence: Int, dueDay: Int?, frequency: RecurringFrequency, potId: String?, creditCardId: String?, priority: RecurringPriority) {
        let now = DateUtilities.nowIsoString()
        let payment = RecurringPayment(
            id: DateUtilities.newId(prefix: "recurring"),
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: nil,
            frequency: frequency,
            potId: potId,
            creditCardId: creditCardId,
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
        replace(&snapshot.recurringPayments, with: payment.stamped())
        persist()
    }

    func archiveRecurringPayment(id: String) {
        guard let index = snapshot.recurringPayments.firstIndex(where: { $0.id == id }) else { return }
        snapshot.recurringPayments[index].active = false
        snapshot.recurringPayments[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func addCreditCard(name: String, provider: String, limitPence: Int, openingBalancePence: Int, dueDay: Int?, color: String) {
        let now = DateUtilities.nowIsoString()
        let card = CreditCard(
            id: DateUtilities.newId(prefix: "card"),
            name: name,
            provider: provider,
            limitPence: limitPence,
            openingBalancePence: openingBalancePence,
            openingStatementBalancePence: openingBalancePence,
            statementDate: nil,
            designId: nil,
            dueDay: dueDay,
            dueDate: nil,
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

    func recordCardRepayment(cardId: String, amountPence: Int, date: String, note: String) {
        let now = DateUtilities.nowIsoString()
        snapshot.creditCardRepayments.insert(
            CreditCardRepayment(
                id: DateUtilities.newId(prefix: "card-repayment"),
                creditCardId: cardId,
                amountPence: abs(amountPence),
                date: date,
                note: note,
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

    func addDebt(name: String, lender: String, originalAmountPence: Int, currentBalancePence: Int, minimumPaymentPence: Int, dueDate: String, apr: Double?, note: String) {
        let now = DateUtilities.nowIsoString()
        snapshot.debts.insert(
            Debt(
                id: DateUtilities.newId(prefix: "debt"),
                name: name,
                lender: lender,
                originalAmountPence: originalAmountPence,
                currentBalancePence: currentBalancePence,
                minimumPaymentPence: minimumPaymentPence,
                dueDate: dueDate,
                interestRateApr: apr,
                note: note,
                status: .active,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )
        persist()
    }

    func updateDebt(_ debt: Debt) {
        replace(&snapshot.debts, with: debt.stamped())
        persist()
    }

    func archiveDebt(id: String) {
        guard let index = snapshot.debts.firstIndex(where: { $0.id == id }) else { return }
        snapshot.debts[index].status = .archived
        snapshot.debts[index].updatedAt = DateUtilities.nowIsoString()
        persist()
    }

    func recordDebtPayment(debtId: String, amountPence: Int, date: String, note: String) {
        let now = DateUtilities.nowIsoString()
        snapshot.debtPayments.insert(
            DebtPayment(
                id: DateUtilities.newId(prefix: "debt-payment"),
                debtId: debtId,
                amountPence: abs(amountPence),
                date: date,
                note: note,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )

        if let index = snapshot.debts.firstIndex(where: { $0.id == debtId }) {
            snapshot.debts[index].currentBalancePence = max(0, snapshot.debts[index].currentBalancePence - abs(amountPence))
            snapshot.debts[index].status = snapshot.debts[index].currentBalancePence == 0 ? .paid : snapshot.debts[index].status
            snapshot.debts[index].updatedAt = now
        }

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

    func addPotAllocation(potId: String, amountPence: Int, source: PotAllocationSource = .manual, recurringPaymentId: String? = nil) {
        guard let period = selectedPayPeriod else { return }
        let now = DateUtilities.nowIsoString()
        snapshot.potAllocations.insert(
            PotAllocation(
                id: DateUtilities.newId(prefix: "allocation"),
                payPeriodId: period.id,
                potId: potId,
                fundingPotId: nil,
                amountPence: abs(amountPence),
                source: source,
                recurringPaymentId: recurringPaymentId,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            ),
            at: 0
        )

        if let index = snapshot.pots.firstIndex(where: { $0.id == potId }) {
            snapshot.pots[index].balancePence += abs(amountPence)
            snapshot.pots[index].updatedAt = now
        }

        persist()
    }

    private func persist() {
        let snapshot = snapshot
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

    private func clearPaydayActivityOnFirstLoadIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: paydayCleanupKey) else { return }

        snapshot.payPeriods.removeAll()
        snapshot.paychecks.removeAll()
        snapshot.potAllocations.removeAll()
        snapshot.transactions.removeAll()
        snapshot.settings.hourlyRatePence = 0
        snapshot.settings.defaultHoursWorked = 0
        snapshot.settings.updatedAt = DateUtilities.nowIsoString()

        do {
            try await repository.saveSnapshot(snapshot)
            UserDefaults.standard.set(true, forKey: paydayCleanupKey)
        } catch {
            errorMessage = "Unable to clear old local payday activity."
        }
    }

    private func replace<T: Identifiable>(_ collection: inout [T], with item: T) where T.ID == String {
        guard let index = collection.firstIndex(where: { $0.id == item.id }) else { return }
        collection[index] = item
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
