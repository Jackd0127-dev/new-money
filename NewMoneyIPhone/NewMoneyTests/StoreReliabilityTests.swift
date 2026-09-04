import Foundation
import XCTest
@testable import NewMoneyIPhone

extension FinanceEngineTests {
    @MainActor
    func testPayNowAmountCorrectionsKeepFundingAndAvailableIncomeTogether() async throws {
        let store = await makeManualPaymentStore()
        store.recordDebtPayment(debtId: "loan", amountPence: 10_000, date: "2026-08-01", note: "Paid")
        let original = try XCTUnwrap(store.snapshot.debtPayments.first)
        let allocation = try XCTUnwrap(store.snapshot.potAllocations.first)
        XCTAssertEqual(original.fundingAllocationId, allocation.id)

        for amount in [15_000, 6_000] {
            store.updateDebtPayment(id: original.id, debtId: "loan", amountPence: amount, date: original.date, note: "Corrected")
            XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 100_000 - amount)
            XCTAssertEqual(store.snapshot.pots[0].balancePence, 0)
            XCTAssertEqual(store.snapshot.potAllocations[0].amountPence, amount)
            XCTAssertEqual(store.snapshot.potAllocations[0].id, allocation.id)
            XCTAssertEqual(store.snapshot.potAllocations[0].createdAt, allocation.createdAt)
            XCTAssertEqual(PlannerDerivedData.currentMoneyBreakdown(snapshot: store.snapshot, payPeriod: store.snapshot.payPeriods[0])
                .components.first { $0.kind == .unlinkedIncome }?.amountPence, 50_000 - amount)
        }

        let encoded = try JSONEncoder().encode(store.snapshot)
        let reloaded = PlannerStore(repository: TestPlannerRepository(snapshot: try JSONDecoder().decode(PlannerSnapshot.self, from: encoded)))
        await reloaded.load()
        XCTAssertEqual(reloaded.snapshot.debtPayments[0].fundingAllocationId, allocation.id)
        reloaded.updateDebtPayment(id: original.id, debtId: "loan", amountPence: 150_000, date: original.date, note: "Capped at balance")
        XCTAssertEqual(reloaded.snapshot.debtPayments[0].amountPence, 100_000)
        XCTAssertEqual(reloaded.snapshot.potAllocations[0].amountPence, 100_000)
        XCTAssertEqual(reloaded.snapshot.debts[0].currentBalancePence, 0)
        XCTAssertEqual(reloaded.snapshot.pots[0].balancePence, 0)
    }

    @MainActor
    func testLegacyPayNowFundingLinkSurvivesDebtAndPeriodCorrections() async throws {
        let store = await makeManualPaymentStore()
        store.recordDebtPayment(debtId: "loan", amountPence: 10_000, date: "2026-08-01", note: "Paid")
        var legacy = store.snapshot
        legacy.debtPayments[0].fundingAllocationId = nil
        legacy.debts.append(makePlannerDebt(id: "other", name: "Other", startingBalancePence: 100_000,
            targetPayoffDate: nil, repaymentStrategy: .manualOnly, paymentFrequency: .monthly))
        legacy.payPeriods.append(makePayPeriod(id: "september", startDate: "2026-09-01", endDate: "2026-09-30", payday: "2026-09-01", incomePence: 50_000))
        let reloaded = PlannerStore(repository: TestPlannerRepository(snapshot: legacy))
        await reloaded.load()
        let payment = legacy.debtPayments[0]
        reloaded.updateDebtPayment(id: payment.id, debtId: "other", amountPence: 15_000, date: "2026-09-02", note: "Correct debt")
        XCTAssertEqual(reloaded.snapshot.debts.first { $0.id == "loan" }?.currentBalancePence, 100_000)
        XCTAssertEqual(reloaded.snapshot.debts.first { $0.id == "other" }?.currentBalancePence, 85_000)
        XCTAssertEqual(reloaded.snapshot.potAllocations[0].payPeriodId, "september")
        XCTAssertEqual(reloaded.snapshot.potAllocations[0].debtId, "other")
        XCTAssertEqual(reloaded.snapshot.potAllocations[0].debtDueDate, "2026-09-02")
        XCTAssertEqual(reloaded.snapshot.debtPayments[0].fundingAllocationId, legacy.potAllocations[0].id)
        reloaded.updateDebtPayment(id: payment.id, debtId: "other", amountPence: 6_000, date: "2026-09-02", note: "Correct amount again")
        XCTAssertEqual(reloaded.snapshot.potAllocations[0].amountPence, 6_000)
        XCTAssertEqual(reloaded.snapshot.debts.first { $0.id == "other" }?.currentBalancePence, 94_000)
        XCTAssertEqual(reloaded.snapshot.pots[0].balancePence, 0)
    }

    @MainActor
    func testAmbiguousLegacyPayNowFundingBlocksCorrectionWithoutMovingMoney() async throws {
        let store = await makeManualPaymentStore()
        store.recordDebtPayment(debtId: "loan", amountPence: 10_000, date: "2026-08-01", note: "Paid")
        var legacy = store.snapshot
        legacy.debtPayments[0].fundingAllocationId = nil
        var duplicate = legacy.potAllocations[0]
        duplicate.id += "-duplicate"
        legacy.potAllocations.append(duplicate)
        let reloaded = PlannerStore(repository: TestPlannerRepository(snapshot: legacy))
        await reloaded.load()
        let before = reloaded.snapshot
        reloaded.updateDebtPayment(id: legacy.debtPayments[0].id, debtId: "loan", amountPence: 15_000, date: "2026-08-01", note: "Ambiguous")
        XCTAssertEqual(reloaded.snapshot, before)
        XCTAssertNotNil(reloaded.errorMessage)
    }

    @MainActor
    func testDamagedLegacyPayNowDebtLinkBlocksCorrectionWithoutMovingMoney() async throws {
        let store = await makeManualPaymentStore()
        store.recordDebtPayment(debtId: "loan", amountPence: 10_000, date: "2026-08-01", note: "Paid")
        var legacy = store.snapshot
        legacy.debtPayments[0].fundingAllocationId = nil
        legacy.debtPayments[0].debtId = "other"
        legacy.debts[0].currentBalancePence = 100_000
        var other = makePlannerDebt(id: "other", name: "Other", startingBalancePence: 100_000,
            targetPayoffDate: nil, repaymentStrategy: .manualOnly, paymentFrequency: .monthly)
        other.currentBalancePence = 90_000
        legacy.debts.append(other)
        let reloaded = PlannerStore(repository: TestPlannerRepository(snapshot: legacy))
        await reloaded.load()
        let before = reloaded.snapshot
        reloaded.updateDebtPayment(id: legacy.debtPayments[0].id, debtId: "other", amountPence: 15_000, date: "2026-08-01", note: "Damaged link")
        XCTAssertEqual(reloaded.snapshot, before)
        XCTAssertNotNil(reloaded.errorMessage)
    }

    @MainActor
    func testExistingPotPaymentCorrectionStillAdjustsCashWithoutCreatingFunding() async throws {
        let seed = await makeManualPaymentStore()
        var snapshot = seed.snapshot
        snapshot.pots[0].balancePence = 40_000
        snapshot.debts[0].currentBalancePence = 90_000
        snapshot.debtPayments = [DebtPayment(id: "existing", debtId: "loan", amountPence: 10_000,
            date: "2026-08-01", note: "From existing pot", createdAt: "2026-08-01T00:00:00Z",
            updatedAt: "2026-08-01T00:00:00Z", deletedAt: nil, sourcePotId: "funding", paymentType: .scheduled)]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        await store.load()
        store.updateDebtPayment(id: "existing", debtId: "loan", amountPence: 15_000, date: "2026-08-01", note: "Corrected")
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 35_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 85_000)
        XCTAssertTrue(store.snapshot.potAllocations.isEmpty)
    }

    @MainActor
    private func makeManualPaymentStore() async -> PlannerStore {
        let debt = makePlannerDebt(id: "loan", name: "Loan", startingBalancePence: 100_000,
            targetPayoffDate: nil, repaymentStrategy: .manualOnly, paymentFrequency: .monthly)
        let period = makePayPeriod(id: "august", startDate: "2026-08-01", endDate: "2026-08-31", payday: "2026-08-01", incomePence: 50_000)
        let pot = makePot(id: "funding", name: "Funding", balancePence: 0, targetPence: nil, linkedDebtId: debt.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: makeManualSettings(today: "2026-08-01"), pots: [pot], payPeriods: [period], debts: [debt])))
        await store.load()
        return store
    }

    func testMoneyFormattingPreservesPenniesAtIntegerLimits() {
        XCTAssertEqual(MoneyParser.formatPence(1), "£0.01")
        XCTAssertEqual(MoneyParser.formatPence(-1), "-£0.01")
        XCTAssertEqual(MoneyParser.formatPence(Int.max), "£92,233,720,368,547,758.07")
        XCTAssertEqual(MoneyParser.formatPence(Int.min), "-£92,233,720,368,547,758.08")
    }

    @MainActor
    func testFailedLoadBlocksNormalAndAccountSaves() async {
        let store = PlannerStore(repository: BrokenLegacyRepository())
        await store.load()
        XCTAssertNotNil(store.loadError)
        store.updateSettings(makeManualSettings(today: "2026-08-01"))
        store.resetLocalData()
        do { try await store.saveCurrentSnapshot(); XCTFail("Unreadable data must remain protected") } catch {}
        do { try await store.createPlannerAccount(named: "Replacement"); XCTFail("Account writes must remain blocked") } catch {}
        await Task.yield()
    }

    @MainActor
    func testStartupWriteFailureRemainsRetryableAfterSuccessfulRead() async {
        let source = makeSnapshot(settings: makeManualSettings(today: "2026-08-01"))
        let repository = RecoverableStartupRepository(snapshot: source)
        let store = PlannerStore(repository: repository)
        await store.load()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.saveState, .failed)
        let pending = store.snapshot
        await repository.allowWrites()
        await store.retrySaving()
        XCTAssertNil(store.loadError)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.saveState, .saved)
        let saved = await repository.saved
        XCTAssertEqual(saved, pending)
    }

    @MainActor
    func testAutomaticDebtDebitMatchesCappedCashAndRefundsExactPotSplit() async throws {
        let debt = makeDebt(id: "loan", name: "Loan", currentBalancePence: 5_000, dueDate: "2026-08-01")
        let item = makeDebtScheduleItem(id: "due", debtId: debt.id, dueDate: "2026-08-01", amountPence: 10_000, fundedAmountPence: 10_000, status: .funded)
        let pots = [makePot(id: "a", name: "A", balancePence: 2_000, targetPence: nil, linkedDebtId: debt.id),
                    makePot(id: "b", name: "B", balancePence: 8_000, targetPence: nil, linkedDebtId: debt.id)]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01"), pots: pots, debts: [debt], debtPaymentScheduleItems: [item])))
        await store.load()
        let payment = try XCTUnwrap(store.snapshot.debtPayments.first)
        XCTAssertEqual(payment.amountPence, 5_000)
        XCTAssertEqual(payment.potContributions?.map(\.amountPence), [2_000, 3_000])
        XCTAssertEqual(store.snapshot.pots.map(\.balancePence), [0, 5_000])
        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 5_000)
        XCTAssertEqual(store.snapshot.pots.map(\.balancePence), [2_000, 8_000])
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 5_000)
    }

    @MainActor
    func testScheduledPaymentIncludesInterestAndRefundReopensOriginalOccurrence() async throws {
        let debt = makeDebt(id: "loan", name: "Loan", currentBalancePence: 10_000, dueDate: "2026-08-01")
        var item = makeDebtScheduleItem(id: "due", debtId: debt.id, dueDate: "2026-08-01", amountPence: 11_000)
        item.principalAmountPence = 10_000
        item.interestAmountPence = 1_000
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01"), debts: [debt], debtPaymentScheduleItems: [item])))
        await store.load()
        store.updateDebtScheduleOccurrence(scheduleItemId: item.id, debtId: debt.id, amountPence: 11_000, dueDate: item.dueDate, status: .paid)
        let payment = try XCTUnwrap(store.snapshot.debtPayments.first)
        XCTAssertEqual(payment.amountPence, 11_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 0)
        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 5_500)
        let reopened = try XCTUnwrap(store.snapshot.debtPaymentScheduleItems.first { $0.id == item.id })
        XCTAssertEqual(reopened.paidAmountPence, 5_500)
        XCTAssertEqual(reopened.interestAmountPence, 1_000)
        XCTAssertEqual(reopened.status, .partFunded)
        XCTAssertNil(reopened.paidDate)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 5_000)
        store.deleteDebtPayment(id: payment.id)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == item.id }?.paidAmountPence, 0)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 10_000)
    }

    @MainActor
    func testOverpaymentRefundAndDeletionPreserveSurvivingScheduledPayments() async throws {
        let store = await makeOverpaidDebtStore()
        store.setDebtPaymentRefundAmount(id: "later", amountPence: 10_000)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 10_000)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.status, .paid)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 80_000)

        store.setDebtPaymentRefundAmount(id: "later", amountPence: 24_000)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 6_000)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.status, .partFunded)
        store.deleteDebtPayment(id: "later")
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 5_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 95_000)
    }

    @MainActor
    func testOverpaymentEditPreservesOtherPaymentsInOccurrence() async throws {
        let store = await makeOverpaidDebtStore()
        store.updateDebtPayment(id: "later", debtId: "loan", amountPence: 15_000, date: "2026-08-01", note: "Corrected")
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 10_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 80_000)
        store.updateDebtPayment(id: "later", debtId: "loan", amountPence: 2_000, date: "2026-08-01", note: "Corrected again")
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 7_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 93_000)
    }

    @MainActor
    func testReversalPreservesLegacyAggregateWithoutLinkedPaymentRecord() async throws {
        let store = await makeOverpaidDebtStore(earlier: 0, later: 3_000, recordedPaid: 8_000)
        store.setDebtPaymentRefundAmount(id: "later", amountPence: 2_000)
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 6_000)
        store.deleteDebtPayment(id: "later")
        XCTAssertEqual(store.snapshot.debtPaymentScheduleItems.first { $0.id == "due" }?.paidAmountPence, 5_000)
    }

    @MainActor
    private func makeOverpaidDebtStore(earlier: Int = 5_000, later: Int = 25_000, recordedPaid: Int = 10_000) async -> PlannerStore {
        let legacyPaid = max(0, recordedPaid - earlier - later)
        var debt = makeDebt(id: "loan", name: "Loan", currentBalancePence: 100_000 - earlier - later - legacyPaid, dueDate: "2026-08-02")
        debt.originalAmountPence = 100_000
        var item = makeDebtScheduleItem(id: "due", debtId: debt.id, dueDate: "2026-08-02", amountPence: 10_000)
        item.paidAmountPence = recordedPaid
        item.status = recordedPaid == item.plannedAmountPence ? .paid : .partFunded
        item.paidDate = item.status == .paid ? "2026-08-01" : nil
        let payments = [("earlier", earlier), ("later", later)].filter { $0.1 > 0 }.map { id, amount in
            DebtPayment(id: id, debtId: debt.id, amountPence: amount, date: "2026-08-01", note: "Paid",
                createdAt: "2026-08-01T00:00:00Z", updatedAt: "2026-08-01T00:00:00Z", deletedAt: nil,
                paymentType: .manualPayNow, scheduleItemId: item.id, principalPaidPence: amount, interestPaidPence: 0, feePaidPence: 0)
        }
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(
            settings: makeManualSettings(today: "2026-08-01"), debts: [debt], debtPayments: payments, debtPaymentScheduleItems: [item])))
        await store.load()
        return store
    }

    @MainActor
    func testLegacySplitNoteEditDoesNotChangeCashOrLoseUnknownFundingMarker() async throws {
        let debt = makeDebt(id: "loan", name: "Loan", currentBalancePence: 5_000, dueDate: "2027-01-01")
        let pot = makePot(id: "funding", name: "Funding", balancePence: 2_000, targetPence: nil)
        let payment = DebtPayment(id: "paid", debtId: debt.id, amountPence: 1_000, date: "2026-07-31", note: "Automatic Loan payment from linked debt pots", createdAt: "2026-07-31T00:00:00Z", updatedAt: "2026-07-31T00:00:00Z", deletedAt: nil, sourcePotId: pot.id)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01"), pots: [pot], debts: [debt], debtPayments: [payment])))
        await store.load()
        store.updateDebtPayment(id: payment.id, debtId: debt.id, amountPence: 1_000, date: payment.date, note: "Paid")
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 2_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 5_000)
        XCTAssertEqual(store.snapshot.debtPayments[0].potContributions, [])
        store.updateDebtPayment(id: payment.id, debtId: debt.id, amountPence: 2_000, date: payment.date, note: "Paid")
        XCTAssertEqual(store.snapshot.debtPayments[0].amountPence, 1_000)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 2_000)
    }

    @MainActor
    func testCurrentAccountsLoadWithoutReadingCorruptLegacySnapshot() async throws {
        let collection = PlannerAccountCollection.singleAccount(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01")), name: "Current")
        let store = PlannerStore(repository: BrokenLegacyRepository(), accountRepository: InMemoryPlannerAccountRepository(seedCollection: collection))
        await store.load()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.activePlannerAccount?.name, "Current")
        XCTAssertTrue(store.hadPersistedPlannerDataBeforeLoad)
    }

    @MainActor
    func testLoadingPreservesExistingAccountsBeyondCreationLimit() async throws {
        var collection = PlannerAccountCollection.singleAccount(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01")))
        let original = collection.accounts[0]
        for index in 1...3 {
            var account = original
            account.id = "imported-\(index)"
            account.name = "Account \(index)"
            collection.accounts.append(account)
        }
        let store = PlannerStore(repository: BrokenLegacyRepository(), accountRepository: InMemoryPlannerAccountRepository(seedCollection: collection))
        await store.load()
        XCTAssertNil(store.loadError)
        XCTAssertEqual(store.plannerAccounts.count, 4)
        XCTAssertFalse(store.canCreatePlannerAccount)
        XCTAssertEqual(store.accountCollectionForCloudUpload().accounts.map(\.id), collection.accounts.map(\.id))
    }

    @MainActor
    func testAccountSanitizationPreservesThemeAndExportDoesNotMutateStore() async throws {
        let key = AppTheme.selectedPresetStorageKey
        let original = UserDefaults.standard.object(forKey: key)
        defer { if let original { UserDefaults.standard.set(original, forKey: key) } else { UserDefaults.standard.removeObject(forKey: key) } }
        var collection = PlannerAccountCollection.singleAccount(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01")))
        let preset = try XCTUnwrap(AppThemePreset.allCases.first { $0 != .defaultPreset })
        collection.selectedThemePresetId = preset.rawValue
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: collection.accounts[0].snapshot), accountRepository: InMemoryPlannerAccountRepository(seedCollection: collection))
        await store.load()
        let before = store.snapshotRevision
        let first = store.accountCollectionForCloudUpload()
        let second = store.accountCollectionForCloudUpload()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.selectedThemePresetId, preset.rawValue)
        XCTAssertEqual(store.snapshotRevision, before)
    }

    @MainActor
    func testSeriesAmountEditPreservesPostedChargeAndPotBalance() async throws {
        let pot = makePot(id: "bills", name: "Bills", balancePence: 10_000, targetPence: nil)
        let bill = makeRecurringPayment(id: "bill", name: "Subscription", amountPence: 1_000, dueDay: 1, potId: pot.id, createdAt: "2026-08-01T00:00:00.000Z")
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01"), pots: [pot], recurringPayments: [bill])))
        await store.load()
        let posted = try XCTUnwrap(store.snapshot.transactions.first { $0.recurringPaymentId == bill.id })
        let balance = store.snapshot.pots[0].balancePence
        var changed = bill
        changed.amountPence = 2_000
        store.updateRecurringPayment(changed)
        XCTAssertEqual(store.snapshot.transactions.first { $0.id == posted.id }?.amountPence, 1_000)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, balance)
        store.setRecurringBillOccurrenceAmount(paymentId: bill.id, scheduledDueDate: "2026-08-01", amountPence: 1_500)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, balance - 500)
        store.setRecurringBillOccurrenceRefundAmount(paymentId: bill.id, scheduledDueDate: "2026-08-01", amountPence: 250)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, balance - 250)
        try await store.saveCurrentSnapshot()
        await store.load()
        XCTAssertEqual(store.snapshot.pots[0].balancePence, balance - 250)
    }

    @MainActor
    func testDebtRefundRestoresPrincipalAndGrossPotCashIndependently() async throws {
        var debt = makeDebt(id: "loan", name: "Loan", currentBalancePence: 4_100, dueDate: "2027-01-01")
        debt.originalAmountPence = 10_000
        let pot = makePot(id: "funding", name: "Funding", balancePence: 2_000, targetPence: nil)
        let payment = DebtPayment(id: "paid", debtId: debt.id, amountPence: 1_000, date: "2026-07-31", note: "Payment", createdAt: "2026-07-31T00:00:00Z", updatedAt: "2026-07-31T00:00:00Z", deletedAt: nil, sourcePotId: pot.id, paymentType: .manualPayNow, principalPaidPence: 900, interestPaidPence: 100, feePaidPence: 0)
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: makeManualSettings(today: "2026-08-01"), pots: [pot], debts: [debt], debtPayments: [payment])))
        await store.load()
        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 500)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 4_550)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 2_500)
        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 1_000)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 5_000)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 3_000)
        store.setDebtPaymentRefundAmount(id: payment.id, amountPence: 0)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 4_100)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 2_000)
        store.deleteDebtPayment(id: payment.id)
        XCTAssertEqual(store.snapshot.debts[0].currentBalancePence, 5_000)
        XCTAssertEqual(store.snapshot.pots[0].balancePence, 3_000)
        XCTAssertNotNil(store.snapshot.debtPayments.first { $0.id == payment.id }?.deletedAt)
    }

    @MainActor
    func testForegroundDateRefreshIsIdempotentAndInvalidatesPresentation() async {
        var today = FinanceEngine.parseDate("2026-08-01")
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .automatic
        settings.lastProcessedDateIso = "2026-08-01"
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: makeSnapshot(settings: settings)), dateProvider: { today })
        await store.load()
        store.refreshForCurrentDate()
        let first = store.effectiveDateRevision
        store.refreshForCurrentDate()
        XCTAssertEqual(store.effectiveDateRevision, first)
        today = FinanceEngine.parseDate("2026-08-03")
        store.refreshForCurrentDate()
        XCTAssertEqual(store.snapshot.settings.lastProcessedDateIso, "2026-08-03")
        XCTAssertEqual(store.effectiveDateRevision, first + 1)
    }

    func testUnknownFixtureDoesNotDisablePersistentAccountMode() {
        for value in ["", "unknown"] {
            let environment = [PlannerLaunchProfile.fixtureEnvironmentKey: value]
            XCTAssertFalse(PlannerLaunchProfile.isUsingFixture(environment: environment))
            XCTAssertTrue(PlannerLaunchProfile.repository(environment: environment) is FilePlannerRepository)
        }
    }
}

private struct BrokenLegacyRepository: PlannerRepository {
    func loadSnapshot() async throws -> PlannerSnapshot { throw CocoaError(.fileReadCorruptFile) }
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws { XCTFail("Legacy file must not be written") }
    func resetSnapshot() async throws { XCTFail("Legacy file must not be reset") }
}

private actor RecoverableStartupRepository: PlannerRepository {
    let snapshot: PlannerSnapshot
    var saved: PlannerSnapshot?
    private var writesAllowed = false
    init(snapshot: PlannerSnapshot) { self.snapshot = snapshot }
    func allowWrites() { writesAllowed = true }
    func loadSnapshot() async throws -> PlannerSnapshot { snapshot }
    func resetSnapshot() async throws { XCTFail("Reset is not part of save recovery") }
    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        guard writesAllowed else { throw CocoaError(.fileWriteUnknown) }
        saved = snapshot
    }
}
