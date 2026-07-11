import XCTest
@testable import NewMoneyIPhone

@MainActor
final class PersonalJuly2026ScenarioTests: XCTestCase {
    func testBaselineLoadsRawSourceDataAndAudit() async throws {
        let store = await makeFundedBaselineStore()

        XCTAssertEqual(store.snapshot.creditCards.count, 5)
        XCTAssertEqual(store.snapshot.recurringPayments.filter(\.active).count, 7)
        XCTAssertEqual(store.snapshot.pots.count, 6)
        XCTAssertEqual(store.snapshot.paychecks.count, 0)
        XCTAssertEqual(store.snapshot.oneOffIncomes.filter { $0.amountPence == PersonalJuly2026ExpectedResults.incomePence }.count, 1)
        XCTAssertFalse(store.snapshot.oneOffIncomes.contains { $0.amountPence == 0 || $0.amountPence == 169_600 })
        XCTAssertEqual(store.selectedPayPeriod?.startDate, "2026-07-01")
        XCTAssertEqual(store.selectedPayPeriod?.endDate, "2026-07-31")
        XCTAssertEqual(store.snapshot.recurringPayments.reduce(0) { $0 + $1.amountPence }, PersonalJuly2026ExpectedResults.billsTotalPence)
        XCTAssertEqual(openingPotTotal(), PersonalJuly2026ExpectedResults.openingPotTotalPence)
        XCTAssertEqual(store.snapshot.pots.reduce(0) { $0 + $1.balancePence }, PersonalJuly2026ExpectedResults.potTotalPence)
        XCTAssertEqual(store.snapshot.potAllocations.filter { $0.deletedAt == nil }.count, 4)
        XCTAssertEqual(store.snapshot.potAllocations.reduce(0) { $0 + $1.amountPence }, PersonalJuly2026ExpectedResults.fundingTotalPence)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-barclays" }?.balancePence, 54_082)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-aqua" }?.balancePence, 30_731)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-jaja" }?.balancePence, 21_580)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-capital-one" }?.balancePence, 8_079)
        XCTAssertTrue(store.snapshot.transactions.isEmpty)

        let period = try XCTUnwrap(store.selectedPayPeriod)
        let costs = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: PersonalJuly2026ExpectedResults.baselineDate)
        XCTAssertEqual(costs.committedCostsPence, PersonalJuly2026ExpectedResults.baselineCommittedPence)
        XCTAssertEqual(costs.currentMoneyLeftPence, PersonalJuly2026ExpectedResults.baselineMoneyLeftPence)
        XCTAssertEqual(FinanceEngine.getDailySafeToSpendPence(spendablePence: costs.currentMoneyLeftPence, today: PersonalJuly2026ExpectedResults.baselineDate, endDate: period.endDate), PersonalJuly2026ExpectedResults.baselineSafeToSpendPence)
        XCTAssertTrue(store.snapshot.potAllocations.contains { $0.recurringPaymentId == PersonalJuly2026Fixture.iCloudBillId && $0.recurringDueDate == "2026-07-10" })
        XCTAssertTrue(store.snapshot.potAllocations.contains { $0.recurringPaymentId == PersonalJuly2026Fixture.runnaBillId && $0.recurringDueDate == "2026-07-18" })
        XCTAssertTrue(store.snapshot.potAllocations.contains { $0.recurringPaymentId == PersonalJuly2026Fixture.appleCareBillId && $0.recurringDueDate == "2026-07-19" })
        XCTAssertTrue(store.snapshot.potAllocations.contains { $0.creditCardId == PersonalJuly2026Fixture.aquaCardId && $0.creditCardDirectDebitDate == PersonalJuly2026Fixture.aquaOpeningDueDate })
        XCTAssertEqual(try PersonalJuly2026ScenarioAudit.write(snapshot: store.snapshot, date: PersonalJuly2026ExpectedResults.baselineDate).lastPathComponent, "PersonalJuly2026ScenarioAudit-2026-07-09.md")
    }

    func testFixtureRepositoryIsIsolatedAndIdempotent() async throws {
        let repository = InMemoryPlannerRepository(seedSnapshot: PersonalJuly2026Fixture.snapshot())
        let store = PlannerStore(repository: repository)
        await store.load()
        let first = store.snapshot
        await store.load()
        XCTAssertEqual(store.snapshot.creditCards.count, first.creditCards.count)
        XCTAssertEqual(store.snapshot.recurringPayments.count, first.recurringPayments.count)
        XCTAssertEqual(store.snapshot.transactions.count, first.transactions.count)
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [PlannerLaunchProfile.fixtureEnvironmentKey: PersonalJuly2026Fixture.fixtureValue]) is InMemoryPlannerRepository)
        XCTAssertTrue(PlannerLaunchProfile.repository(environment: [:]) is FilePlannerRepository)
    }

    func testAfterICloudUsesScheduledProductionWorkflowOnce() async throws {
        let store = await makeFundedBaselineStore()
        let allocationId = "recurring-bill-funding-allocation-bill-icloud-2026-07-10-personal-july-2026"
        let transactionId = "card-recurring-bill-icloud-2026-07-10"
        let occurrenceId = "bill-icloud-2026-07-10"
        let barclaysBefore = store.snapshot.pots.first { $0.id == "pot-barclays" }?.balancePence
        let totalBefore = store.snapshot.pots.reduce(0) { $0 + $1.balancePence }
        let unrelatedPotsBefore = Dictionary(uniqueKeysWithValues: store.snapshot.pots.filter { $0.id != "pot-barclays" }.map { ($0.id, $0.balancePence) })
        let allocationsBefore = store.snapshot.potAllocations
        let julyOccurrences = PlannerDerivedData.recurringOccurrences(
            payments: store.snapshot.recurringPayments,
            startDate: "2026-07-01",
            endDate: "2026-07-31"
        )

        XCTAssertEqual(barclaysBefore, 54_082)
        XCTAssertEqual(totalBefore, PersonalJuly2026ExpectedResults.potTotalPence)
        XCTAssertEqual(julyOccurrences.filter { $0.id == occurrenceId }.count, 1)
        XCTAssertEqual(allocationsBefore.filter { $0.id == allocationId }.count, 1)
        XCTAssertFalse(store.snapshot.transactions.contains { $0.id == transactionId })

        store.setManualTodayForSimulation(PersonalJuly2026ExpectedResults.afterICloudDate)
        XCTAssertTrue(store.applyDueScheduledPaymentsForSimulation(asOf: PersonalJuly2026ExpectedResults.afterICloudDate))

        let iCloud = store.snapshot.transactions.filter { $0.recurringPaymentId == "bill-icloud" && $0.date == PersonalJuly2026ExpectedResults.afterICloudDate }
        XCTAssertEqual(iCloud.count, 1)
        XCTAssertEqual(iCloud.first?.id, transactionId)
        XCTAssertEqual(iCloud.first?.amountPence, 899)
        XCTAssertEqual(iCloud.first?.paymentMethod, .creditCard)
        XCTAssertEqual(iCloud.first?.creditCardId, "card-barclays")
        XCTAssertEqual(iCloud.first?.potId, "pot-barclays")
        XCTAssertEqual(store.snapshot.potAllocations.filter { $0.id == allocationId }.count, 1)
        XCTAssertEqual(store.snapshot.potAllocations, allocationsBefore)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-barclays" }?.balancePence, 53_183)
        XCTAssertEqual(store.snapshot.pots.reduce(0) { $0 + $1.balancePence }, PersonalJuly2026ExpectedResults.afterICloudPotTotalPence)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: store.snapshot.pots.filter { $0.id != "pot-barclays" }.map { ($0.id, $0.balancePence) }), unrelatedPotsBefore)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-jaja" }?.balancePence, 21_580)
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-capital-one" }?.balancePence, 8_079)
        XCTAssertEqual(PlannerDerivedData.cardBalance(card: try XCTUnwrap(store.snapshot.creditCards.first { $0.id == "card-barclays" }), snapshot: store.snapshot), 65_443)
        let period = try XCTUnwrap(store.selectedPayPeriod)
        let costs = PlannerDerivedData.payPeriodCostSummary(snapshot: store.snapshot, payPeriod: period, asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate)
        XCTAssertEqual(costs.currentMoneyLeftPence, PersonalJuly2026ExpectedResults.baselineMoneyLeftPence)
        XCTAssertEqual(FinanceEngine.getDailySafeToSpendPence(spendablePence: costs.currentMoneyLeftPence, today: PersonalJuly2026ExpectedResults.afterICloudDate, endDate: period.endDate), PersonalJuly2026ExpectedResults.afterICloudSafeToSpendPence)
        XCTAssertFalse(store.applyDueScheduledPaymentsForSimulation(asOf: PersonalJuly2026ExpectedResults.afterICloudDate))
        XCTAssertEqual(store.snapshot.transactions.filter { $0.id == transactionId }.count, 1)
        XCTAssertEqual(store.snapshot.potAllocations.filter { $0.id == allocationId }.count, 1)
        XCTAssertEqual(try PersonalJuly2026ScenarioAudit.write(snapshot: store.snapshot, date: PersonalJuly2026ExpectedResults.afterICloudDate).lastPathComponent, "PersonalJuly2026ScenarioAudit-2026-07-10.md")
    }

    func testLinkedCardPaymentGapsAppearInChecklistAndAquaCanBeFundedFromIncome() async throws {
        let store = await makeFundedBaselineStore()
        store.setManualTodayForSimulation(PersonalJuly2026ExpectedResults.afterICloudDate)
        XCTAssertTrue(store.applyDueScheduledPaymentsForSimulation(asOf: PersonalJuly2026ExpectedResults.afterICloudDate))

        let period = try XCTUnwrap(store.selectedPayPeriod)
        let items = PlannerDerivedData.cardPaymentFundingChecklistItems(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate
        )
        let amountsByCard = Dictionary(uniqueKeysWithValues: items.map { ($0.cardName, $0.amountPence) })

        XCTAssertEqual(amountsByCard["Aqua"], 699)
        XCTAssertEqual(amountsByCard["Capital One"], 12_158)
        XCTAssertEqual(amountsByCard["Barclays"], 13_859)

        let aqua = try XCTUnwrap(items.first { $0.cardId == PersonalJuly2026Fixture.aquaCardId })
        XCTAssertEqual(aqua.potId, "pot-aqua")
        XCTAssertEqual(aqua.directDebitDate, "2026-08-20")
        XCTAssertFalse(aqua.isCompleted)

        let currentMoneyLeftBefore = PlannerDerivedData.payPeriodCostSummary(
            snapshot: store.snapshot,
            payPeriod: period,
            asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate
        ).currentMoneyLeftPence
        XCTAssertEqual(currentMoneyLeftBefore, PersonalJuly2026ExpectedResults.baselineMoneyLeftPence)

        XCTAssertTrue(store.setCardPaymentFundingCompleted(
            cardId: aqua.cardId,
            potId: aqua.potId,
            directDebitDate: aqua.directDebitDate,
            payPeriodId: aqua.payPeriodId,
            completed: true
        ))

        let aquaAllocation = try XCTUnwrap(store.snapshot.potAllocations.first {
            $0.source == .cardPaymentFunding && $0.creditCardId == PersonalJuly2026Fixture.aquaCardId
        })
        XCTAssertEqual(aquaAllocation.amountPence, 699)
        XCTAssertEqual(aquaAllocation.creditCardDirectDebitDate, "2026-08-20")
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-aqua" }?.balancePence, 31_430)
        XCTAssertEqual(
            PlannerDerivedData.cardPaymentFundingChecklistItems(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate
            ).first { $0.cardId == PersonalJuly2026Fixture.aquaCardId }?.isCompleted,
            true
        )
        XCTAssertEqual(
            PlannerDerivedData.payPeriodCostSummary(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate
            ).currentMoneyLeftPence,
            PersonalJuly2026ExpectedResults.baselineMoneyLeftPence - 699
        )

        XCTAssertTrue(store.setCardPaymentFundingCompleted(
            cardId: aqua.cardId,
            potId: aqua.potId,
            directDebitDate: aqua.directDebitDate,
            payPeriodId: aqua.payPeriodId,
            completed: false
        ))
        XCTAssertFalse(store.snapshot.potAllocations.contains { $0.source == .cardPaymentFunding })
        XCTAssertEqual(store.snapshot.pots.first { $0.id == "pot-aqua" }?.balancePence, 30_731)
        XCTAssertEqual(
            PlannerDerivedData.payPeriodCostSummary(
                snapshot: store.snapshot,
                payPeriod: period,
                asOfDate: PersonalJuly2026ExpectedResults.afterICloudDate
            ).currentMoneyLeftPence,
            PersonalJuly2026ExpectedResults.baselineMoneyLeftPence
        )
    }

    private func makeFundedBaselineStore() async -> PlannerStore {
        let store = PlannerStore(repository: InMemoryPlannerRepository(seedSnapshot: PersonalJuly2026Fixture.snapshot(phase: .beforeICloud)))
        await store.load()
        XCTAssertEqual(store.todayIso, PersonalJuly2026ExpectedResults.baselineDate)
        XCTAssertTrue(store.bootstrapPersonalJuly2026FixtureIfNeeded())
        XCTAssertTrue(store.snapshot.transactions.isEmpty)
        return store
    }

    private func openingPotTotal() -> Int {
        0 + 21_580 + 8_079 + 0 + 50_685 + 17_888
    }
}
