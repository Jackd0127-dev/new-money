import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import NewMoneyIPhone

private typealias Transaction = NewMoneyIPhone.Transaction

extension FinanceEngineTests {
    func makeManualSettings(today: String) -> Settings {
        var settings = DefaultData.defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = today
        return settings
    }

    func makeFundingPresentationItem(
        id: String,
        name: String,
        destinationId: String,
        destinationName: String,
        amountPence: Int,
        dueDate: String,
        action: FundingChecklistAction
    ) -> FundingChecklistPresentationItem {
        FundingChecklistPresentationItem(
            id: id,
            name: name,
            destinationKind: .pot,
            destinationId: destinationId,
            destinationName: destinationName,
            title: "Add \(MoneyParser.formatPence(amountPence)) to \(destinationName)",
            detail: "\(name) · due \(dueDate)",
            amountPence: amountPence,
            dueDate: dueDate,
            breakdown: [
                FundingChecklistBreakdownItem(
                    id: "breakdown-\(id)",
                    title: name,
                    detail: "Due \(dueDate)",
                    amountPence: amountPence
                )
            ],
            isCompleted: false,
            isExcluded: false,
            status: .needsFunding,
            paidDate: nil,
            action: action
        )
    }

    func statementSummary(
        in snapshot: PlannerSnapshot,
        cardId: String,
        statementDate: String,
        asOfDate: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CreditCardStatementSummary {
        let statements = PlannerDerivedData.creditCardStatementSummaries(snapshot: snapshot, asOfDate: asOfDate)
        return try XCTUnwrap(
            statements.first { $0.cardId == cardId && $0.statementDate == statementDate },
            file: file,
            line: line
        )
    }

    @MainActor
    func completeFundingChecklistItem(
        _ item: FundingChecklistPresentationItem,
        in store: PlannerStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let completed: Bool
        switch item.action {
        case .recurringBill(let paymentId, let dueDate, let payPeriodId):
            completed = store.setRecurringBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        case .cardBill(let paymentId, let dueDate, let payPeriodId):
            completed = store.setCardBillFundingCompleted(paymentId: paymentId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        case .cardSpend(let transactionId, let payPeriodId):
            completed = store.setCardSpendFundingCompleted(transactionId: transactionId, payPeriodId: payPeriodId, completed: true)
        case .cardOpeningBalance(let cardId, let directDebitDate, let payPeriodId):
            completed = store.setCardOpeningBalanceFundingCompleted(cardId: cardId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true)
        case .cardPayment(let cardId, let potId, let directDebitDate, let payPeriodId):
            completed = store.setCardPaymentFundingCompleted(cardId: cardId, potId: potId, directDebitDate: directDebitDate, payPeriodId: payPeriodId, completed: true)
        case .debt(let debtId, let dueDate, let payPeriodId):
            completed = store.setDebtFundingCompleted(debtId: debtId, dueDate: dueDate, payPeriodId: payPeriodId, completed: true)
        }
        XCTAssertTrue(completed, item.name, file: file, line: line)
    }

    func ledgerSignature(for snapshot: PlannerSnapshot, asOfDate: String) -> [String] {
        let transactionLines = snapshot.transactions
            .sorted { $0.id < $1.id }
            .map {
                "txn:\($0.id):\($0.date):\($0.amountPence):\($0.payPeriodId ?? ""):\($0.potId ?? ""):\($0.creditCardId ?? "")"
            }
        let repaymentLines = snapshot.creditCardRepayments
            .sorted { $0.id < $1.id }
            .map {
                "repay:\($0.id):\($0.date):\($0.amountPence):\($0.statementDate ?? ""):\($0.directDebitDate ?? ""):\($0.potContributionPence ?? -1):\($0.paycheckContributionPence ?? -1)"
            }
        let potLines = snapshot.pots
            .sorted { $0.id < $1.id }
            .map { "pot:\($0.id):\($0.balancePence)" }
        let cardLines = snapshot.creditCards
            .sorted { $0.id < $1.id }
            .map { "card:\($0.id):\(PlannerDerivedData.cardBalance(card: $0, snapshot: snapshot))" }
        let selectedPeriod = PlannerDerivedData.findPayPeriod(payPeriods: snapshot.payPeriods, date: asOfDate)
        let summaryLines: [String]
        if let selectedPeriod {
            let summary = PlannerDerivedData.payPeriodCostSummary(snapshot: snapshot, payPeriod: selectedPeriod, asOfDate: asOfDate)
            summaryLines = [
                "period:\(selectedPeriod.id):\(selectedPeriod.startDate):\(selectedPeriod.endDate):\(summary.totalCostsPence):\(summary.moneyLeftPence)"
            ]
        } else {
            summaryLines = ["period:none"]
        }

        return transactionLines + repaymentLines + potLines + cardLines + summaryLines
    }

    @MainActor
    func runFullAppLogicTortureJulSep2027SimulationSheets() -> [FullAppSheetPayload] {
        let snapshot = DefaultData.fullAppLogicTortureJulSep2027Snapshot
        let store = PlannerStore(repository: TestPlannerRepository(snapshot: snapshot))
        store.useSnapshotForSimulation(snapshot)
        var runner = FullAppSimulationRunner(store: store)
        return runner.run()
    }

    func fullAppSheet(named name: String, in sheets: [FullAppSheetPayload]) -> FullAppSheetPayload? {
        sheets.first { $0.name == name }
    }

    func fullAppRow(in sheet: FullAppSheetPayload, where header: String, equals value: String) -> [FullAppCellValue]? {
        fullAppRow(in: sheet, matching: [header: value])
    }

    func fullAppRow(in sheet: FullAppSheetPayload, matching expectedValues: [String: String]) -> [FullAppCellValue]? {
        sheet.rows.first { row in
            expectedValues.allSatisfy { header, expectedValue in
                fullAppText(row, in: sheet, header) == expectedValue
            }
        }
    }

    func fullAppPence(_ row: [FullAppCellValue], in sheet: FullAppSheetPayload, _ header: String) -> Int {
        guard let index = sheet.headers.firstIndex(of: header) else {
            XCTFail("Missing full app simulation column \(header)")
            return 0
        }

        switch row[index] {
        case .number(let value):
            return Int((value * 100).rounded())
        case .text(let value):
            XCTFail("Expected money value in \(header), got \(value)")
            return 0
        case .blank:
            XCTFail("Expected money value in \(header), got blank")
            return 0
        }
    }

    func fullAppText(_ row: [FullAppCellValue], in sheet: FullAppSheetPayload, _ header: String) -> String {
        guard let index = sheet.headers.firstIndex(of: header) else {
            XCTFail("Missing full app simulation column \(header)")
            return ""
        }

        switch row[index] {
        case .text(let value):
            return value
        case .number(let value):
            return String(value)
        case .blank:
            return ""
        }
    }

    @MainActor
    func fundBasicDataJulyChecklist(in store: PlannerStore, payPeriod: PayPeriod) -> Bool {
        let billItems = PlannerDerivedData.cardBillFundingChecklistItems(snapshot: store.snapshot, payPeriod: payPeriod)
        let openingItems = PlannerDerivedData.cardOpeningBalanceFundingChecklistItems(snapshot: store.snapshot, payPeriod: payPeriod)

        guard
            let chatGPT = billItems.first(where: { $0.paymentId == "rec-chatgpt" && $0.dueDate == "2026-07-01" }),
            let insurance = billItems.first(where: { $0.paymentId == "rec-insurance" && $0.dueDate == "2026-07-01" }),
            let skincare = billItems.first(where: { $0.paymentId == "rec-skincare" && $0.dueDate == "2026-07-15" }),
            let spendingMoney = billItems.first(where: { $0.paymentId == "rec-spending-money" && $0.dueDate == "2026-07-25" }),
            let cc1Opening = openingItems.first(where: { $0.cardId == "card-cc1" && $0.directDebitDate == "2026-07-02" })
        else { return false }

        return store.setCardBillFundingCompleted(paymentId: insurance.paymentId, dueDate: insurance.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: chatGPT.paymentId, dueDate: chatGPT.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardOpeningBalanceFundingCompleted(cardId: cc1Opening.cardId, directDebitDate: cc1Opening.directDebitDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: skincare.paymentId, dueDate: skincare.dueDate, payPeriodId: payPeriod.id, completed: true) &&
            store.setCardBillFundingCompleted(paymentId: spendingMoney.paymentId, dueDate: spendingMoney.dueDate, payPeriodId: payPeriod.id, completed: true)
    }

    @MainActor
    func attachCreditRender<Content: View>(
        _ content: Content,
        name: String,
        dynamicTypeSize: DynamicTypeSize,
        colorScheme: ColorScheme
    ) {
        let rootView = content
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.colorScheme, colorScheme)
        let host = UIHostingController(rootView: rootView)
        let frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let window = UIWindow(frame: frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = frame
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let image = UIGraphicsImageRenderer(size: frame.size).image { _ in
            host.view.drawHierarchy(in: frame, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, frame.size)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }

    func makeSnapshot(
        settings: Settings = DefaultData.defaultSettings,
        bankAccounts: [BankAccount] = [],
        pots: [Pot] = [],
        recurringPayments: [RecurringPayment] = [],
        recurringPaymentOccurrenceOverrides: [RecurringPaymentOccurrenceOverride] = [],
        payPeriods: [PayPeriod] = [],
        potAllocations: [PotAllocation] = [],
        transactions: [NewMoneyIPhone.Transaction] = [],
        debts: [Debt] = [],
        debtPayments: [DebtPayment] = [],
        debtPaymentScheduleItems: [DebtPaymentScheduleItem] = [],
        creditCards: [CreditCard] = [],
        customPayments: [CustomPayment] = [],
        creditCardRepayments: [CreditCardRepayment] = [],
        creditCardPots: [CreditCardPot] = [],
        creditCardCycleOverrides: [CreditCardCycleOverride] = [],
        oneOffIncomes: [OneOffIncome] = [],
        fundingChecklistExclusions: [FundingChecklistExclusion] = []
    ) -> PlannerSnapshot {
        PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            recurringPaymentOccurrenceOverrides: recurringPaymentOccurrenceOverrides,
            payPeriods: payPeriods,
            paychecks: [],
            potAllocations: potAllocations,
            transactions: transactions,
            debts: debts,
            debtPayments: debtPayments,
            debtReserves: [],
            debtPaymentScheduleItems: debtPaymentScheduleItems,
            debtSnapshots: [],
            creditCards: creditCards,
            customPayments: customPayments,
            creditCardRepayments: creditCardRepayments,
            creditCardPots: creditCardPots,
            creditCardCycleOverrides: creditCardCycleOverrides,
            dailyBriefs: [],
            oneOffIncomes: oneOffIncomes,
            fundingChecklistExclusions: fundingChecklistExclusions,
            bankAccounts: bankAccounts
        )
    }

    func makePot(
        id: String,
        name: String,
        balancePence: Int,
        targetPence: Int?,
        linkedCreditCardId: String? = nil,
        linkedDebtId: String? = nil,
        fundingBankAccountId: String? = nil
    ) -> Pot {
        Pot(
            id: id,
            name: name,
            type: .reserved,
            category: "Bills",
            icon: nil,
            balancePence: balancePence,
            targetPence: targetPence,
            color: "#2563eb",
            linkedCreditCardId: linkedCreditCardId,
            linkedDebtId: linkedDebtId,
            fundingBankAccountId: fundingBankAccountId,
            archived: false,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    func makeRecurringPayment(
        id: String,
        name: String,
        amountPence: Int,
        dueDay: Int?,
        potId: String?,
        creditCardId: String? = nil,
        bankAccountId: String? = nil,
        dueDate: String? = nil,
        frequency: RecurringFrequency = .monthly,
        createdAt: String = "2026-06-01T00:00:00.000Z"
    ) -> RecurringPayment {
        RecurringPayment(
            id: id,
            name: name,
            amountPence: amountPence,
            dueDay: dueDay,
            dueDate: dueDate,
            frequency: frequency,
            potId: potId,
            creditCardId: creditCardId,
            bankAccountId: bankAccountId,
            priority: .essential,
            active: true,
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil
        )
    }

    func makeBankAccount(
        id: String,
        name: String = "Main account",
        openingBalancePence: Int = 0,
        isPrimary: Bool = true
    ) -> BankAccount {
        BankAccount(
            id: id,
            name: name,
            provider: "Test Bank",
            type: .current,
            openingBalancePence: openingBalancePence,
            lastFourDigits: "1234",
            color: "#2563EB",
            isPrimary: isPrimary,
            archived: false,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }

    func makeDebt(id: String, name: String, currentBalancePence: Int, dueDate: String) -> Debt {
        Debt(
            id: id,
            name: name,
            lender: "Loan Provider",
            originalAmountPence: currentBalancePence,
            currentBalancePence: currentBalancePence,
            minimumPaymentPence: 0,
            dueDate: dueDate,
            interestRateApr: nil,
            note: "",
            status: .active,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    func makePlannerDebt(
        id: String,
        name: String,
        startingBalancePence: Int,
        targetPayoffDate: String?,
        type: DebtType = .other,
        interestType: DebtInterestType = .none,
        aprBasisPoints: Int? = nil,
        fixedFeePence: Int = 0,
        minimumPaymentPence: Int = 0,
        extraPaymentPence: Int = 0,
        repaymentStrategy: DebtRepaymentStrategy,
        paymentFrequency: DebtPaymentFrequency,
        paymentDay: Int? = nil,
        payFirstTiming: DebtPayFirstTiming = .nextPayday
    ) -> Debt {
        Debt(
            id: id,
            name: name,
            lender: "Loan Provider",
            originalAmountPence: startingBalancePence,
            currentBalancePence: startingBalancePence,
            minimumPaymentPence: minimumPaymentPence,
            dueDate: targetPayoffDate ?? "",
            interestRateApr: aprBasisPoints.map { Double($0) / 100.0 },
            note: "",
            status: .active,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil,
            type: type,
            startingBalancePence: startingBalancePence,
            targetPayoffDate: targetPayoffDate,
            interestType: interestType,
            aprBasisPoints: aprBasisPoints,
            interestAccrualMode: interestType == .apr ? .dailyEstimated : DebtInterestAccrualMode.none,
            fixedFeePence: fixedFeePence,
            extraPaymentPence: extraPaymentPence,
            repaymentStrategy: repaymentStrategy,
            paymentFrequency: paymentFrequency,
            paymentDay: paymentDay,
            payFirstTiming: payFirstTiming,
            customFirstPaymentDate: nil,
            recalculationMode: repaymentStrategy.defaultRecalculationMode
        )
    }

    func makeDebtScheduleItem(
        id: String,
        debtId: String,
        dueDate: String,
        amountPence: Int,
        fundedAmountPence: Int = 0,
        status: DebtPaymentScheduleStatus = .planned
    ) -> DebtPaymentScheduleItem {
        DebtPaymentScheduleItem(
            id: id,
            debtId: debtId,
            dueDate: dueDate,
            plannedAmountPence: amountPence,
            principalAmountPence: amountPence,
            interestAmountPence: 0,
            feeAmountPence: 0,
            fundedAmountPence: fundedAmountPence,
            paidAmountPence: 0,
            paidDate: nil,
            status: status,
            createdAt: "2026-05-16T00:00:00.000Z",
            updatedAt: "2026-05-16T00:00:00.000Z",
            deletedAt: nil
        )
    }

    func makeCreditCard(
        id: String,
        name: String,
        limitPence: Int = 80000,
        openingBalancePence: Int,
        openingStatementBalancePence: Int?,
        statementDate: String?,
        dueDay: Int?,
        createdAt: String = "2026-05-20T00:00:00.000Z"
    ) -> CreditCard {
        CreditCard(
            id: id,
            name: name,
            provider: name,
            limitPence: limitPence,
            openingBalancePence: openingBalancePence,
            openingStatementBalancePence: openingStatementBalancePence,
            statementDate: statementDate,
            designId: nil,
            dueDay: dueDay,
            dueDate: nil,
            color: "#2563eb",
            archived: false,
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil
        )
    }

    func makePayPeriod(id: String, startDate: String, endDate: String, payday: String, incomePence: Int) -> PayPeriod {
        PayPeriod(
            id: id,
            startDate: startDate,
            endDate: endDate,
            payday: payday,
            nextPayday: FinanceEngine.addIsoDays(date: endDate, days: 1),
            incomePence: incomePence,
            status: .active,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }

    func makeTransaction(id: String, cardId: String, amountPence: Int, date: String, note: String) -> NewMoneyIPhone.Transaction {
        Transaction(
            id: id,
            potId: nil,
            payPeriodId: nil,
            amountPence: amountPence,
            type: .spending,
            paymentMethod: .creditCard,
            creditCardId: cardId,
            recurringPaymentId: nil,
            date: date,
            note: note,
            createdAt: "\(date)T10:00:00.000Z",
            updatedAt: "\(date)T10:00:00.000Z",
            deletedAt: nil
        )
    }

    func makePotAllocation(
        id: String,
        payPeriodId: String,
        potId: String,
        amountPence: Int,
        source: PotAllocationSource = .cardBillFunding,
        recurringPaymentId: String?,
        recurringDueDate: String?,
        debtId: String? = nil,
        debtDueDate: String? = nil
    ) -> PotAllocation {
        PotAllocation(
            id: id,
            payPeriodId: payPeriodId,
            potId: potId,
            fundingPotId: nil,
            amountPence: amountPence,
            source: source,
            recurringPaymentId: recurringPaymentId,
            recurringDueDate: recurringDueDate,
            debtId: debtId,
            debtDueDate: debtDueDate,
            createdAt: "2026-06-01T00:00:00.000Z",
            updatedAt: "2026-06-01T00:00:00.000Z",
            deletedAt: nil
        )
    }
}

actor TestPlannerRepository: PlannerRepository {
    private var snapshot: PlannerSnapshot

    init(snapshot: PlannerSnapshot) {
        self.snapshot = snapshot
    }

    func loadSnapshot() async throws -> PlannerSnapshot {
        snapshot
    }

    func saveSnapshot(_ snapshot: PlannerSnapshot) async throws {
        self.snapshot = snapshot
    }

    func resetSnapshot() async throws {
        snapshot = DefaultData.emptySnapshot
    }
}
