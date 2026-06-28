import Foundation

enum PayFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case weekly
    case biweekly
    case monthly
    case custom

    var id: String { rawValue }
}

enum Currency: String, Codable, Sendable {
    case gbp = "GBP"
}

enum AIProvider: String, Codable, Sendable, CaseIterable, Identifiable {
    case gemini
    case openrouter

    var id: String { rawValue }
}

enum AssistantResponseStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case straightToThePoint = "straight_to_the_point"
    case affirmative
    case enthusiastic
    case friendly
    case flirty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .straightToThePoint:
            return "Straight to the point"
        case .affirmative:
            return "Affirmative"
        case .enthusiastic:
            return "Enthusiastic"
        case .friendly:
            return "Friendly"
        case .flirty:
            return "Flirty"
        }
    }
}

enum AppDateMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }
}

enum PotType: String, Codable, Sendable, CaseIterable, Identifiable {
    case spending
    case reserved
    case saving
    case investment
    case buffer

    var id: String { rawValue }
}

enum RecurringFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case once
    case weekly
    case biweekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }
}

enum RecurringPriority: String, Codable, Sendable, CaseIterable, Identifiable {
    case essential
    case important
    case optional

    var id: String { rawValue }
}

enum PayPeriodStatus: String, Codable, Sendable, CaseIterable {
    case planned
    case active
    case closed
}

enum TransactionType: String, Codable, Sendable, CaseIterable {
    case spending
    case allocation
    case transfer
    case adjustment
}

enum PotAllocationSource: String, Codable, Sendable {
    case manual
    case recurring
    case recurringBillFunding = "recurring_bill_funding"
    case cardBillFunding = "card_bill_funding"
    case cardSpendFunding = "card_spend_funding"
    case cardOpeningBalanceFunding = "card_opening_balance_funding"
    case debtFunding = "debt_funding"
    case potAuto = "pot_auto"
}

enum DebtStatus: String, Codable, Sendable, CaseIterable {
    case active
    case paid
    case archived
}

enum PaymentMethod: String, Codable, Sendable, CaseIterable {
    case pot
    case creditCard = "credit_card"
}

enum CustomPaymentStatus: String, Codable, Sendable, CaseIterable {
    case unpaid
    case paid
    case archived
}

enum CreditCardPotSource: String, Codable, Sendable {
    case paycheck
    case external
}

enum CreditCardPotStatus: String, Codable, Sendable, CaseIterable {
    case active
    case applied
    case cancelled
}

enum CreditCardRepaymentSource: String, Codable, Sendable, CaseIterable {
    case manual
    case automaticStatement = "automatic_statement"
    case linkedPotStatement = "linked_pot_statement"
}

enum DebtReserveStatus: String, Codable, Sendable, CaseIterable {
    case planned
    case skipped
    case applied
    case cancelled
}

enum DebtReserveSource: String, Codable, Sendable {
    case assistant
    case manual
}

protocol TimestampedModel {
    var createdAt: String { get set }
    var updatedAt: String { get set }
    var deletedAt: String? { get set }
}

struct Settings: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var currency: Currency
    var payFrequency: PayFrequency
    var defaultPayPeriodDays: Int
    var hourlyRatePence: Int
    var defaultHoursWorked: Double
    var appDateMode: AppDateMode
    var manualTodayIso: String?
    var lastProcessedDateIso: String? = nil
    var aiInstructions: String
    var aiProvider: AIProvider
    var assistantName: String?
    var assistantResponseStyle: AssistantResponseStyle?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct Pot: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var type: PotType
    var category: String?
    var icon: String?
    var balancePence: Int
    var targetPence: Int?
    var color: String
    var linkedCreditCardId: String?
    var linkedDebtId: String?
    var archived: Bool
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct RecurringPayment: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var amountPence: Int
    var dueDay: Int?
    var dueDate: String?
    var frequency: RecurringFrequency
    var potId: String?
    var creditCardId: String?
    var priority: RecurringPriority
    var active: Bool
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct PayPeriod: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var startDate: String
    var endDate: String
    var payday: String
    var nextPayday: String
    var payFrequency: PayFrequency?
    var incomePence: Int
    var status: PayPeriodStatus
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct Paycheck: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var payPeriodId: String
    var hoursWorked: Double
    var hourlyRatePence: Int
    var calculatedAmountPence: Int
    var actualAmountPence: Int?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct PotAllocation: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var payPeriodId: String
    var potId: String
    var fundingPotId: String?
    var amountPence: Int
    var source: PotAllocationSource?
    var recurringPaymentId: String?
    var recurringDueDate: String?
    var debtId: String?
    var debtDueDate: String?
    var transactionId: String? = nil
    var transactionDate: String? = nil
    var creditCardId: String? = nil
    var creditCardDirectDebitDate: String? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct Transaction: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var potId: String?
    var payPeriodId: String?
    var amountPence: Int
    var type: TransactionType
    var paymentMethod: PaymentMethod?
    var creditCardId: String?
    var recurringPaymentId: String?
    var date: String
    var note: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct Debt: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var lender: String
    var originalAmountPence: Int
    var currentBalancePence: Int
    var minimumPaymentPence: Int
    var dueDate: String
    var interestRateApr: Double?
    var note: String
    var status: DebtStatus
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct DebtPayment: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var debtId: String
    var amountPence: Int
    var date: String
    var note: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct DebtReserve: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var debtId: String
    var payPeriodId: String?
    var payday: String
    var periodStartDate: String
    var periodEndDate: String
    var amountPence: Int
    var status: DebtReserveStatus
    var source: DebtReserveSource
    var note: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct CreditCard: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var provider: String
    var limitPence: Int
    var openingBalancePence: Int?
    var openingStatementBalancePence: Int?
    var statementDate: String?
    var designId: String?
    var dueDay: Int?
    var dueDate: String?
    var color: String
    var archived: Bool
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct CustomPayment: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var amountPence: Int
    var dueDate: String
    var creditCardId: String?
    var status: CustomPaymentStatus
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct CreditCardRepayment: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var creditCardId: String
    var amountPence: Int
    var date: String
    var note: String
    var statementDate: String? = nil
    var directDebitDate: String? = nil
    var source: CreditCardRepaymentSource? = nil
    var potId: String? = nil
    var potContributionPence: Int? = nil
    var paycheckContributionPence: Int? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct CreditCardPot: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var creditCardId: String
    var payPeriodId: String?
    var payday: String?
    var periodStartDate: String?
    var periodEndDate: String?
    var name: String
    var amountPence: Int
    var source: CreditCardPotSource
    var status: CreditCardPotStatus
    var note: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct DailyBrief: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var date: String
    var snapshotSignature: String
    var content: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct PlannerSnapshot: Codable, Equatable, Sendable {
    var settings: Settings
    var pots: [Pot]
    var recurringPayments: [RecurringPayment]
    var payPeriods: [PayPeriod]
    var paychecks: [Paycheck]
    var potAllocations: [PotAllocation]
    var transactions: [Transaction]
    var debts: [Debt]
    var debtPayments: [DebtPayment]
    var debtReserves: [DebtReserve]
    var creditCards: [CreditCard]
    var customPayments: [CustomPayment]
    var creditCardRepayments: [CreditCardRepayment]
    var creditCardPots: [CreditCardPot]
    var dailyBriefs: [DailyBrief]
}

struct NextPayPeriod: Equatable, Sendable {
    var startDate: String
    var endDate: String
    var nextPayday: String
}

struct AllocationBalance: Equatable, Sendable {
    var availableAfterReservedPence: Int
    var remainingPence: Int
    var isOverAllocated: Bool
}

struct PayPeriodMoneySummary: Equatable, Sendable {
    var payReceivedPence: Int
    var allocatedPence: Int
    var uncoveredRecurringPence: Int
    var totalPaymentsDuePence: Int
    var moneyLeftPence: Int
    var isOverCommitted: Bool
}

enum PeriodCostItemSource: String, Sendable {
    case recurring
    case savedPayment = "saved_payment"
    case manualSpend = "manual_spend"
    case potAllocation = "pot_allocation"
    case debtMinimum = "debt_minimum"
    case debtReserve = "debt_reserve"
    case creditCardPot = "credit_card_pot"
    case creditCardRepayment = "credit_card_repayment"
}

struct PeriodCostItem: Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var amountPence: Int
    var date: String
    var source: PeriodCostItemSource
    var creditCardId: String?
    var potId: String?
    var fundingPotId: String?
    var isProjected: Bool = false
}

struct PayPeriodCostSummary: Equatable, Sendable {
    var payReceivedPence: Int
    var directRecurringPence: Int
    var savedPaymentsPence: Int
    var manualSpendingPence: Int
    var potAllocationsPence: Int
    var debtMinimumsPence: Int
    var debtReservesPence: Int
    var creditCardPotsPence: Int
    var creditCardChargesPence: Int
    var creditCardRepaymentsPence: Int
    var creditCardNetPence: Int
    var committedCostsPence: Int
    var unfundedChecklistPence: Int
    var projectedCostsPence: Int
    var currentMoneyLeftPence: Int
    var projectedMoneyLeftPence: Int
    var totalCostsPence: Int
    var moneyLeftPence: Int
    var isOverCommitted: Bool
    var items: [PeriodCostItem]
}

struct DebtSummary: Equatable, Sendable {
    var activeDebtCount: Int
    var overdueDebtCount: Int
    var totalCurrentBalancePence: Int
    var totalOriginalAmountPence: Int
    var totalPaidPence: Int
    var debtDueThisPayPeriodPence: Int
    var progressPercent: Double
}
