import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    func testCreditCardStatementDueDateUsesNextMonthWhenDueDayIsBeforeStatementDay() {
        let settings = makeManualSettings(today: "2026-07-09")
        let jajaCard = makeCreditCard(
            id: "card-jaja",
            name: "Jaja",
            limitPence: 25000,
            openingBalancePence: 21580,
            openingStatementBalancePence: 21580,
            statementDate: "2026-07-07",
            dueDay: 3
        )
        let snapshot = makeSnapshot(settings: settings, creditCards: [jajaCard])

        let payments = PlannerDerivedData.creditCardStatementPayments(
            card: jajaCard,
            snapshot: snapshot,
            startDate: "2026-08-01",
            endDate: "2026-08-31",
            asOfDate: "2026-07-09"
        )

        XCTAssertEqual(payments.map(\.directDebitDate), ["2026-08-03"])
        XCTAssertEqual(payments.map(\.actualDuePence), [21580])
    }

    func testFormatsPaydayLabelWithOrdinalFullMonthAndTwoDigitYear() {
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-01"), "1st June 27")
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-02"), "2nd June 27")
        XCTAssertEqual(FinanceEngine.formatPaydayLabel("2027-06-11"), "11th June 27")
    }

    func testFormatsShortDateLabelForDateSimulationCard() {
        XCTAssertEqual(FinanceEngine.formatShortDateLabel("2026-06-07"), "7 Jun 2026")
    }

    func testCreditCardDaySelectionValueShowsSelectedDay() {
        XCTAssertEqual(creditCardDaySelectionValue(14), "Day 14")
    }

    func testManualAppDateModeReturnsSelectedDate() {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-12-25"

        XCTAssertEqual(FinanceEngine.getAppTodayIso(settings: settings), "2026-12-25")
    }

    func testInvalidManualAppDateFallsBackToValidAutomaticDate() {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "tomorrow"

        let today = FinanceEngine.getAppTodayIso(settings: settings)

        XCTAssertNotEqual(today, "tomorrow")
        XCTAssertTrue(FinanceEngine.isIsoDate(today))
    }

    func testCreatesWeeklyBiweeklyAndMonthlyPayPeriodsFromPayday() {
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-12", frequency: .weekly),
                       NextPayPeriod(startDate: "2026-06-12", endDate: "2026-06-18", nextPayday: "2026-06-19"))
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-12", frequency: .biweekly),
                       NextPayPeriod(startDate: "2026-06-12", endDate: "2026-06-25", nextPayday: "2026-06-26"))
        XCTAssertEqual(FinanceEngine.createNextPayPeriod(payday: "2026-06-30", frequency: .monthly),
                       NextPayPeriod(startDate: "2026-06-30", endDate: "2026-07-29", nextPayday: "2026-07-30"))
    }

    func testMonthlyPayPeriodsPreserveTheSelectedDayAndClampShorterMonths() {
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(
                payday: "2027-01-31",
                frequency: .monthly,
                monthlyAnchorDay: 31
            ),
            NextPayPeriod(startDate: "2027-01-31", endDate: "2027-02-27", nextPayday: "2027-02-28")
        )
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(
                payday: "2027-02-28",
                frequency: .monthly,
                monthlyAnchorDay: 31
            ),
            NextPayPeriod(startDate: "2027-02-28", endDate: "2027-03-30", nextPayday: "2027-03-31")
        )
        XCTAssertEqual(
            FinanceEngine.createNextPayPeriod(payday: "2026-07-16", frequency: .monthly),
            NextPayPeriod(startDate: "2026-07-16", endDate: "2026-08-15", nextPayday: "2026-08-16")
        )
    }

    @MainActor
    func testUpdatingAClampedMonthlyPaycheckKeepsTheOriginalThirtyFirstAnchor() async {
        var settings = makeManualSettings(today: "2027-02-28")
        settings.payFrequency = .monthly
        var period = makePayPeriod(
            id: "period-february",
            startDate: "2027-02-28",
            endDate: "2027-03-30",
            payday: "2027-02-28",
            incomePence: 100000
        )
        period.nextPayday = "2027-03-31"
        period.payFrequency = .monthly
        period.monthlyAnchorDay = 31
        let paycheck = Paycheck(
            id: "paycheck-february",
            payPeriodId: period.id,
            hoursWorked: 0,
            hourlyRatePence: 0,
            calculatedAmountPence: 100000,
            actualAmountPence: 100000,
            createdAt: "2027-02-28T00:00:00.000Z",
            updatedAt: "2027-02-28T00:00:00.000Z",
            deletedAt: nil
        )
        var snapshot = makeSnapshot(settings: settings, payPeriods: [period])
        snapshot.paychecks = [paycheck]
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))

        await store.load()
        store.updatePaycheck(
            id: paycheck.id,
            payday: "2027-02-28",
            hoursWorked: 0,
            hourlyRatePence: 0,
            actualAmountPence: 100000,
            payFrequency: .monthly
        )

        XCTAssertEqual(store.snapshot.payPeriods.first?.monthlyAnchorDay, 31)
        XCTAssertEqual(store.snapshot.payPeriods.first?.nextPayday, "2027-03-31")
        XCTAssertEqual(store.snapshot.payPeriods.first?.endDate, "2027-03-30")
    }

    func testOnceRecurringOccurrencesOnlyEmitExplicitDueDate() {
        let roadTax = makeRecurringPayment(
            id: "rec-road-tax",
            name: "Road Tax",
            amountPence: 18000,
            dueDay: nil,
            potId: "pot-pot4",
            creditCardId: "card-cc4",
            dueDate: "2027-01-31",
            frequency: .once,
            createdAt: "2027-01-01T00:00:00.000Z"
        )
        let tradeMembership = makeRecurringPayment(
            id: "rec-trade-membership",
            name: "Trade Membership",
            amountPence: 9500,
            dueDay: nil,
            potId: "pot-pot5",
            creditCardId: "card-cc5",
            dueDate: "2027-02-01",
            frequency: .once,
            createdAt: "2027-01-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [roadTax, tradeMembership],
            startDate: "2027-01-01",
            endDate: "2028-03-31"
        )

        XCTAssertEqual(occurrences.map { "\($0.payment.id)-\($0.dueDate)" }, [
            "rec-road-tax-2027-01-31",
            "rec-trade-membership-2027-02-01",
        ])
    }

    func testQuarterlyRecurringOccurrencesFollowThreeMonthCadence() {
        let payment = makeRecurringPayment(
            id: "rec-road-tax",
            name: "Road Tax",
            amountPence: 18000,
            dueDay: nil,
            potId: "pot-pot5",
            creditCardId: "card-cc4",
            dueDate: "2026-09-30",
            frequency: .quarterly,
            createdAt: "2026-09-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [payment],
            startDate: "2026-09-01",
            endDate: "2027-04-01"
        )

        XCTAssertEqual(occurrences.map(\.dueDate), ["2026-09-30", "2026-12-30", "2027-03-30"])
    }

    func testMonthlyRecurringOccurrencesDoNotBackfillBeforePaymentWasCreated() {
        let carFinance = makeRecurringPayment(
            id: "rec-car-finance",
            name: "Car Finance",
            amountPence: 22000,
            dueDay: 28,
            potId: "pot-pot2",
            creditCardId: "card-cc2",
            createdAt: "2026-09-01T00:00:00.000Z"
        )
        let tools = makeRecurringPayment(
            id: "rec-tools",
            name: "Tools",
            amountPence: 2400,
            dueDay: 15,
            potId: "pot-pot2",
            creditCardId: "card-cc2",
            createdAt: "2026-09-01T00:00:00.000Z"
        )

        let occurrences = PlannerDerivedData.recurringOccurrences(
            payments: [carFinance, tools],
            startDate: "2026-08-15",
            endDate: "2026-09-15"
        )

        XCTAssertEqual(occurrences.map { "\($0.payment.id)-\($0.dueDate)" }, ["rec-tools-2026-09-15"])
    }

    func testPlanningOnlyRecurringBillOverrideMovesOnlyTheResolvedOccurrence() {
        let payment = makeRecurringPayment(id: "rec-plan", name: "Planning bill", amountPence: 2_000, dueDay: 15, potId: nil)
        var snapshot = makeSnapshot(recurringPayments: [payment])
        snapshot.recurringPaymentOccurrenceOverrides = [
            RecurringPaymentOccurrenceOverride(
                id: "override",
                paymentId: payment.id,
                scheduledDueDate: "2026-06-15",
                state: .confirmed,
                actualDueDate: "2026-06-18",
                reversedGeneratedTransactionIds: [],
                createdAt: "2026-06-15T00:00:00.000Z",
                updatedAt: "2026-06-15T00:00:00.000Z",
                deletedAt: nil
            )
        ]

        let occurrences = PlannerDerivedData.resolvedRecurringOccurrences(
            snapshot: snapshot,
            payments: [payment],
            startDate: "2026-06-01",
            endDate: "2026-07-31"
        )

        XCTAssertEqual(occurrences.first { $0.scheduledDueDate == "2026-06-15" }?.dueDate, "2026-06-18")
        XCTAssertEqual(occurrences.first { $0.scheduledDueDate == "2026-07-15" }?.dueDate, "2026-07-15")
    }

    func testRecurringBillCycleAdjustmentSelectsRecentlyMissedOccurrence() {
        let payment = makeRecurringPayment(
            id: "rec-rent",
            name: "Rent",
            amountPence: 75_000,
            dueDay: 1,
            potId: nil,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let snapshot = makeSnapshot(recurringPayments: [payment])

        let occurrence = PlannerDerivedData.recurringBillCycleAdjustmentOccurrence(
            snapshot: snapshot,
            payment: payment,
            asOfDate: "2026-08-03"
        )

        XCTAssertEqual(occurrence?.scheduledDueDate, "2026-08-01")
    }

    func testRecurringBillCycleAdjustmentSelectsNextOccurrenceBeforeItIsDue() {
        let payment = makeRecurringPayment(
            id: "rec-broadband",
            name: "Broadband",
            amountPence: 4_500,
            dueDay: 20,
            potId: nil,
            createdAt: "2026-08-01T00:00:00.000Z"
        )
        let snapshot = makeSnapshot(recurringPayments: [payment])

        let occurrence = PlannerDerivedData.recurringBillCycleAdjustmentOccurrence(
            snapshot: snapshot,
            payment: payment,
            asOfDate: "2026-08-01"
        )

        XCTAssertEqual(occurrence?.scheduledDueDate, "2026-08-20")
    }

    func testHomeDueEventsIncludesEveryRequestedSourceWithinRollingWindow() {
        let today = "2026-07-10"
        let period = makePayPeriod(id: "period-july", startDate: "2026-07-10", endDate: "2026-08-09", payday: today, incomePence: 120000)
        let snapshot = makeSnapshot(
            recurringPayments: [makeRecurringPayment(id: "bill", name: "Energy", amountPence: 4200, dueDay: 10, potId: nil)],
            payPeriods: [period],
            debts: [makeDebt(id: "debt", name: "Loan", currentBalancePence: 50000, dueDate: today)],
            debtPaymentScheduleItems: [makeDebtScheduleItem(id: "debt-cycle", debtId: "debt", dueDate: today, amountPence: 3000)],
            creditCards: [makeCreditCard(id: "card", name: "Main card", openingBalancePence: 25000, openingStatementBalancePence: 25000, statementDate: "2026-06-10", dueDay: 11)],
            customPayments: [CustomPayment(id: "saved", name: "Dentist", amountPence: 6500, dueDate: "2026-07-11", creditCardId: nil, status: .unpaid, createdAt: today, updatedAt: today, deletedAt: nil)],
            oneOffIncomes: [OneOffIncome(id: "bonus", payPeriodId: period.id, name: "Bonus", amountPence: 8000, date: "2026-07-11", note: "", createdAt: today, updatedAt: today, deletedAt: nil)]
        )

        let events = PlannerDerivedData.homeDueEvents(snapshot: snapshot, asOfDate: today)

        XCTAssertTrue(events.contains { if case .payday = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .oneOffIncome = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .recurringBill = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .savedPayment = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .debtPayment = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .cardStatement = $0.source { true } else { false } })
        XCTAssertTrue(events.contains { if case .cardDirectDebit = $0.source { true } else { false } })
        XCTAssertTrue(events.allSatisfy { $0.date == today || $0.date == "2026-07-11" })
        XCTAssertEqual(events.map(\.date), events.map(\.date).sorted())
    }

    func testHomeDueEventsIncludesPreviousSevenDaysAndNextThreeDaysOnly() {
        let today = "2026-07-10"
        let payments = [
            CustomPayment(id: "past-boundary", name: "Past boundary", amountPence: 1000, dueDate: "2026-07-03", creditCardId: nil, status: .paid, createdAt: today, updatedAt: today, deletedAt: nil),
            CustomPayment(id: "too-old", name: "Too old", amountPence: 1000, dueDate: "2026-07-02", creditCardId: nil, status: .paid, createdAt: today, updatedAt: today, deletedAt: nil),
            CustomPayment(id: "future-boundary", name: "Future boundary", amountPence: 1000, dueDate: "2026-07-13", creditCardId: nil, status: .unpaid, createdAt: today, updatedAt: today, deletedAt: nil),
            CustomPayment(id: "too-far", name: "Too far", amountPence: 1000, dueDate: "2026-07-14", creditCardId: nil, status: .unpaid, createdAt: today, updatedAt: today, deletedAt: nil)
        ]

        let events = PlannerDerivedData.homeDueEvents(
            snapshot: makeSnapshot(customPayments: payments),
            asOfDate: today
        )

        XCTAssertEqual(events.map(\.title), ["Past boundary", "Future boundary"])
        XCTAssertEqual(events.map(\.date), ["2026-07-03", "2026-07-13"])
    }

    func testHomeDueEventsUsesStableOverridesAndRetainsCancelledItemsInWindow() {
        let today = "2026-07-10"
        let period = makePayPeriod(id: "period-july", startDate: today, endDate: "2026-08-09", payday: today, incomePence: 100000)
        var snapshot = makeSnapshot(
            payPeriods: [period],
            customPayments: [CustomPayment(id: "archived", name: "Old", amountPence: 1000, dueDate: today, creditCardId: nil, status: .archived, createdAt: today, updatedAt: today, deletedAt: nil)],
            oneOffIncomes: [
                OneOffIncome(id: "moved", payPeriodId: period.id, name: "Moved bonus", amountPence: 5000, date: today, note: "", createdAt: today, updatedAt: today, deletedAt: nil),
                OneOffIncome(id: "later", payPeriodId: nil, name: "Later", amountPence: 5000, date: "2026-07-14", note: "", createdAt: today, updatedAt: today, deletedAt: nil),
                OneOffIncome(id: "cancelled", payPeriodId: period.id, name: "Cancelled", amountPence: 5000, date: today, note: "", createdAt: today, updatedAt: today, deletedAt: nil)
            ]
        )
        snapshot.incomeOccurrenceOverrides = [
            IncomeOccurrenceOverride(id: "move", sourceKind: .oneOffIncome, sourceId: "moved", scheduledDate: today, state: .confirmed, actualDate: "2026-07-11", amountPenceOverride: 7250, createdAt: today, updatedAt: today, deletedAt: nil),
            IncomeOccurrenceOverride(id: "cancel", sourceKind: .oneOffIncome, sourceId: "cancelled", scheduledDate: today, state: .cancelled, actualDate: nil, amountPenceOverride: nil, createdAt: today, updatedAt: today, deletedAt: nil)
        ]

        let events = PlannerDerivedData.homeDueEvents(snapshot: snapshot, asOfDate: today)
        let moved = events.first { $0.title == "Moved bonus" }

        XCTAssertEqual(moved?.scheduledDate, today)
        XCTAssertEqual(moved?.date, "2026-07-11")
        XCTAssertEqual(moved?.amountPence, 7250)
        XCTAssertEqual(moved?.status, .completed)
        XCTAssertEqual(events.first { $0.title == "Cancelled" }?.status, .cancelled)
        XCTAssertEqual(events.first { $0.title == "Old" }?.status, .cancelled)
        XCTAssertFalse(events.contains { $0.title == "Later" })
    }

    func testIncomeOccurrenceStatesPreserveProjectedIncomeButChangeLiveCashExplicitly() {
        let period = makePayPeriod(id: "period", startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", incomePence: 100000)
        let paycheck = Paycheck(id: "pay", payPeriodId: period.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 100000, actualAmountPence: nil, createdAt: "2026-07-01", updatedAt: "2026-07-01", deletedAt: nil)
        var snapshot = makeSnapshot(payPeriods: [period])
        snapshot.paychecks = [paycheck]
        snapshot.incomeOccurrenceOverrides = [IncomeOccurrenceOverride(id: "await", sourceKind: .paycheck, sourceId: paycheck.id, scheduledDate: period.payday, state: .awaiting, actualDate: nil, amountPenceOverride: 110000, createdAt: "2026-07-01", updatedAt: "2026-07-01", deletedAt: nil)]

        XCTAssertEqual(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period), 110000)
        XCTAssertEqual(PlannerDerivedData.currentTotalMoneyPence(snapshot: snapshot, payPeriod: period), 0)

        snapshot.incomeOccurrenceOverrides[0].state = .confirmed
        snapshot.incomeOccurrenceOverrides[0].actualDate = "2026-07-02"
        XCTAssertEqual(PlannerDerivedData.currentTotalMoneyPence(snapshot: snapshot, payPeriod: period), 110000)

        snapshot.incomeOccurrenceOverrides[0].state = .cancelled
        XCTAssertEqual(PlannerDerivedData.effectivePayPeriodIncomePence(snapshot: snapshot, payPeriod: period), 0)
        XCTAssertEqual(PlannerDerivedData.currentTotalMoneyPence(snapshot: snapshot, payPeriod: period), 0)
    }

    func testNextRecurringOccurrencesLimitsEveryFrequencyAndSortsDeterministically() {
        let asOfDate = "2026-07-10"
        let payments = [
            makeRecurringPayment(id: "weekly", name: "Zulu Weekly", amountPence: 1000, dueDay: nil, potId: nil, dueDate: "2026-07-10", frequency: .weekly),
            makeRecurringPayment(id: "biweekly", name: "Alpha Biweekly", amountPence: 2000, dueDay: nil, potId: nil, dueDate: "2026-07-10", frequency: .biweekly),
            makeRecurringPayment(id: "monthly", name: "Monthly", amountPence: 3000, dueDay: 11, potId: nil, frequency: .monthly),
            makeRecurringPayment(id: "quarterly", name: "Quarterly", amountPence: 4000, dueDay: nil, potId: nil, dueDate: "2026-07-12", frequency: .quarterly),
            makeRecurringPayment(id: "yearly", name: "Yearly", amountPence: 5000, dueDay: nil, potId: nil, dueDate: "2026-07-13", frequency: .yearly),
            makeRecurringPayment(id: "once", name: "One off", amountPence: 6000, dueDay: nil, potId: nil, dueDate: "2026-07-14", frequency: .once)
        ]

        let occurrences = PlannerDerivedData.nextRecurringOccurrences(
            snapshot: makeSnapshot(recurringPayments: payments),
            payments: payments,
            asOfDate: asOfDate,
            limitPerPayment: 2
        )
        let datesByPayment = Dictionary(grouping: occurrences, by: { $0.payment.id })
            .mapValues { $0.map(\.dueDate) }

        XCTAssertEqual(datesByPayment["weekly"], ["2026-07-10", "2026-07-17"])
        XCTAssertEqual(datesByPayment["biweekly"], ["2026-07-10", "2026-07-24"])
        XCTAssertEqual(datesByPayment["monthly"], ["2026-07-11", "2026-08-11"])
        XCTAssertEqual(datesByPayment["quarterly"], ["2026-07-12", "2026-10-12"])
        XCTAssertEqual(datesByPayment["yearly"], ["2026-07-13", "2027-07-13"])
        XCTAssertEqual(datesByPayment["once"], ["2026-07-14"])
        XCTAssertTrue(datesByPayment.values.allSatisfy { $0.count <= 2 })

        let sortKeys = occurrences.map { "\($0.dueDate)|\($0.payment.name.lowercased())|\($0.scheduledDueDate)|\($0.id)" }
        XCTAssertEqual(sortKeys, sortKeys.sorted())
        XCTAssertEqual(Array(occurrences.prefix(2)).map(\.payment.id), ["biweekly", "weekly"])
    }
}
