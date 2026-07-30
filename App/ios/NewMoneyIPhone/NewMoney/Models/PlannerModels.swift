import Foundation

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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

enum BankAccountType: String, Codable, Sendable, CaseIterable, Identifiable {
    case current
    case savings
    case cash
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current:
            "Current"
        case .savings:
            "Savings"
        case .cash:
            "Cash"
        case .other:
            "Other"
        }
    }
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
    case cardPaymentFunding = "card_payment_funding"
    case debtFunding = "debt_funding"
    case potAuto = "pot_auto"
}

enum DebtStatus: String, Codable, Sendable, CaseIterable {
    case active
    case funded
    case partFunded = "part_funded"
    case dueSoon = "due_soon"
    case dueToday = "due_today"
    case overdue
    case paid
    case paidOff = "paid_off"
    case atRisk = "at_risk"
    case interestRisk = "interest_risk"
    case archived
}

extension DebtStatus {
    var isActiveLike: Bool {
        switch self {
        case .active, .funded, .partFunded, .dueSoon, .dueToday, .overdue, .atRisk, .interestRisk:
            return true
        case .paid, .paidOff, .archived:
            return false
        }
    }

    var isPaidLike: Bool {
        self == .paid || self == .paidOff
    }
}

enum DebtType: String, Codable, Sendable, CaseIterable, Identifiable {
    case informal
    case bnpl
    case personalLoan = "personal_loan"
    case overdraft
    case creditAgreement = "credit_agreement"
    case other

    var id: String { rawValue }
}

enum DebtInterestType: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case apr
    case fixedFee = "fixed_fee"

    var id: String { rawValue }
}

enum DebtInterestAccrualMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case none
    case dailyEstimated = "daily_estimated"
    case fixedOnSchedule = "fixed_on_schedule"

    var id: String { rawValue }
}

enum DebtRepaymentStrategy: String, Codable, Sendable, CaseIterable, Identifiable {
    case autoSpreadUntilDueDate = "auto_spread_until_due_date"
    case payIn4 = "pay_in_4"
    case fixedPayment = "fixed_payment"
    case minimumPlusExtra = "minimum_plus_extra"
    case manualOnly = "manual_only"

    var id: String { rawValue }

    var defaultRecalculationMode: DebtRecalculationMode {
        switch self {
        case .autoSpreadUntilDueDate:
            return .lowerFuturePayments
        case .payIn4:
            return .lowerFuturePayments
        case .fixedPayment, .minimumPlusExtra:
            return .finishEarlier
        case .manualOnly:
            return .lowerFuturePayments
        }
    }
}

enum DebtPaymentFrequency: String, Codable, Sendable, CaseIterable, Identifiable {
    case weekly
    case fortnightly
    case monthly
    case custom

    var id: String { rawValue }
}

enum DebtPaymentScheduleStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case planned
    case funded
    case partFunded = "part_funded"
    case paid
    case missed
    case overdue
    case cancelled

    var id: String { rawValue }
}

enum DebtPaymentType: String, Codable, Sendable, CaseIterable, Identifiable {
    case scheduled
    case manualPayNow = "manual_pay_now"
    case manualSetAside = "manual_set_aside"
    case adjustment

    var id: String { rawValue }
}

enum DebtRecalculationMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case lowerFuturePayments = "lower_future_payments"
    case finishEarlier = "finish_earlier"
    case skipNextPayment = "skip_next_payment"

    var id: String { rawValue }
}

enum DebtPayFirstTiming: String, Codable, Sendable, CaseIterable, Identifiable {
    case today
    case nextPayday = "next_payday"
    case customDate = "custom_date"

    var id: String { rawValue }
}

enum PaymentMethod: String, Codable, Sendable, CaseIterable {
    case income
    case bankAccount = "bank_account"
    case pot
    case creditCard = "credit_card"

    var displayName: String {
        switch self {
        case .income:
            "Money left"
        case .bankAccount:
            "Bank account"
        case .pot:
            "Pot"
        case .creditCard:
            "Credit card"
        }
    }
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
    /// Tracks one-time repairs to persisted planner snapshots. Optional so older snapshots decode safely.
    var cardRecurringPotReserveMigrationVersion: Int? = nil
    /// Tracks the targeted removal of a known automatic card-bill funding error.
    var cardRecurringAutoFundingRepairVersion: Int? = nil
    var aiInstructions: String
    var aiProvider: AIProvider
    var assistantName: String?
    var assistantResponseStyle: AssistantResponseStyle?
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct BankAccount: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var provider: String
    var type: BankAccountType
    /// The balance before linked app movements. The current balance is derived so
    /// edits, refunds, and checklist reversals cannot make the account drift.
    var openingBalancePence: Int
    var lastFourDigits: String?
    var color: String
    var isPrimary: Bool
    var archived: Bool
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
    /// The real account that supplies future allocations into this pot.
    var fundingBankAccountId: String? = nil
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
    /// Used only for bills paid directly from a bank account. Pot/card routes
    /// keep this nil so funding is never counted twice.
    var bankAccountId: String? = nil
    var billGroupId: String? = nil
    var priority: RecurringPriority
    var active: Bool
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

enum RecurringPaymentOccurrenceState: String, Codable, Equatable, Sendable {
    case normal
    case awaitingPayment
    case confirmed
    case refunded
}

/// A one-off correction to a recurring bill. The scheduled date stays immutable so
/// the bill returns to its normal recurrence after this occurrence.
struct RecurringPaymentOccurrenceOverride: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var paymentId: String
    var scheduledDueDate: String
    var state: RecurringPaymentOccurrenceState
    var actualDueDate: String?
    var reversedGeneratedTransactionIds: [String]
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct BillGroup: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var color: String
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
    /// Preserves the payday the user selected for monthly income when a shorter
    /// month temporarily clamps that date (for example, 31 January -> 28 February).
    var monthlyAnchorDay: Int? = nil
}

struct Paycheck: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var payPeriodId: String
    var hoursWorked: Double
    var hourlyRatePence: Int
    var calculatedAmountPence: Int
    var actualAmountPence: Int?
    var bankAccountId: String? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct OneOffIncome: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var payPeriodId: String?
    var name: String
    var amountPence: Int
    var date: String
    var note: String
    var bankAccountId: String? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

enum FundingChecklistExclusionKind: String, Codable, Sendable {
    case recurringBill = "recurring_bill"
    case cardBill = "card_bill"
    case cardSpend = "card_spend"
    case cardOpeningBalance = "card_opening_balance"
    case cardPayment = "card_payment"
    case debt
}

struct FundingChecklistExclusion: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var kind: FundingChecklistExclusionKind
    var sourceId: String
    var occurrenceDate: String
    var payPeriodId: String
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?
}

struct PotAllocation: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var payPeriodId: String
    var potId: String
    var fundingPotId: String?
    /// Captures the source at allocation time so later pot edits do not rewrite
    /// historical bank-account movements.
    var bankAccountId: String? = nil
    var amountPence: Int
    var source: PotAllocationSource?
    var recurringPaymentId: String?
    var recurringDueDate: String?
    var debtId: String?
    var debtDueDate: String?
    var debtScheduleItemId: String? = nil
    var transactionId: String? = nil
    var transactionDate: String? = nil
    var creditCardId: String? = nil
    var creditCardDirectDebitDate: String? = nil
    /// Marks a recurring card-bill reserve that the user explicitly ticked in
    /// the funding checklist. This keeps a one-off repair from removing a
    /// legitimate later manual funding decision.
    var userConfirmed: Bool? = nil
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
    var bankAccountId: String? = nil
    var recurringPaymentId: String?
    var date: String
    var note: String
    /// A refund preserves the original record for audit/history while removing
    /// its cash, pot, and card-balance effect.
    var refundedAt: String? = nil
    /// Funding allocations removed with a refunded card spend, retained so an
    /// accidental refund toggle can put the exact checklist funding back.
    var refundedCardSpendFundingPayPeriodIds: [String]? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var isRefunded: Bool { refundedAt != nil }
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

    var type: DebtType
    var startingBalancePence: Int
    var targetPayoffDate: String?
    var interestType: DebtInterestType
    var aprBasisPoints: Int?
    var interestAccrualMode: DebtInterestAccrualMode
    var fixedFeePence: Int
    var extraPaymentPence: Int
    var repaymentStrategy: DebtRepaymentStrategy
    var paymentFrequency: DebtPaymentFrequency
    var paymentDay: Int?
    var payFirstTiming: DebtPayFirstTiming
    var customFirstPaymentDate: String?
    var recalculationMode: DebtRecalculationMode

    init(
        id: String,
        name: String,
        lender: String,
        originalAmountPence: Int,
        currentBalancePence: Int,
        minimumPaymentPence: Int,
        dueDate: String,
        interestRateApr: Double?,
        note: String,
        status: DebtStatus,
        createdAt: String,
        updatedAt: String,
        deletedAt: String?,
        type: DebtType = .other,
        startingBalancePence: Int? = nil,
        targetPayoffDate: String? = nil,
        interestType: DebtInterestType? = nil,
        aprBasisPoints: Int? = nil,
        interestAccrualMode: DebtInterestAccrualMode? = nil,
        fixedFeePence: Int = 0,
        extraPaymentPence: Int = 0,
        repaymentStrategy: DebtRepaymentStrategy? = nil,
        paymentFrequency: DebtPaymentFrequency = .monthly,
        paymentDay: Int? = nil,
        payFirstTiming: DebtPayFirstTiming = .nextPayday,
        customFirstPaymentDate: String? = nil,
        recalculationMode: DebtRecalculationMode? = nil
    ) {
        let balance = max(0, currentBalancePence)
        let original = max(0, originalAmountPence)
        let derivedAprBasisPoints = aprBasisPoints ?? interestRateApr.map { Int(($0 * 100).rounded()) }
        let derivedInterestType = interestType ?? (derivedAprBasisPoints == nil ? .none : .apr)
        let cleanTargetPayoffDate = targetPayoffDate?.nilIfBlank ?? dueDate.nilIfBlank
        let derivedStrategy = repaymentStrategy ?? {
            if balance <= 0 {
                return .manualOnly
            }
            if minimumPaymentPence > 0 {
                return .fixedPayment
            }
            return cleanTargetPayoffDate == nil ? .manualOnly : .autoSpreadUntilDueDate
        }()

        self.id = id
        self.name = name
        self.lender = lender
        self.originalAmountPence = original
        self.currentBalancePence = balance
        self.minimumPaymentPence = max(0, minimumPaymentPence)
        self.dueDate = dueDate
        self.interestRateApr = interestRateApr
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.type = type
        self.startingBalancePence = max(0, startingBalancePence ?? original)
        self.targetPayoffDate = cleanTargetPayoffDate
        self.interestType = derivedInterestType
        self.aprBasisPoints = derivedAprBasisPoints
        self.interestAccrualMode = interestAccrualMode ?? (derivedInterestType == .apr ? .dailyEstimated : (derivedInterestType == .fixedFee ? .fixedOnSchedule : .none))
        self.fixedFeePence = max(0, fixedFeePence)
        self.extraPaymentPence = max(0, extraPaymentPence)
        self.repaymentStrategy = derivedStrategy
        self.paymentFrequency = paymentFrequency
        self.paymentDay = paymentDay
        self.payFirstTiming = payFirstTiming
        self.customFirstPaymentDate = customFirstPaymentDate?.nilIfBlank
        self.recalculationMode = recalculationMode ?? derivedStrategy.defaultRecalculationMode
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, lender, originalAmountPence, currentBalancePence, minimumPaymentPence, dueDate, interestRateApr, note, status, createdAt, updatedAt, deletedAt
        case type, startingBalancePence, targetPayoffDate, interestType, aprBasisPoints, interestAccrualMode, fixedFeePence, extraPaymentPence, repaymentStrategy, paymentFrequency, paymentDay, payFirstTiming, customFirstPaymentDate, recalculationMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let originalAmountPence = try container.decodeIfPresent(Int.self, forKey: .originalAmountPence) ?? 0
        let currentBalancePence = try container.decodeIfPresent(Int.self, forKey: .currentBalancePence) ?? originalAmountPence
        let minimumPaymentPence = try container.decodeIfPresent(Int.self, forKey: .minimumPaymentPence) ?? 0
        let dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate) ?? ""
        let interestRateApr = try container.decodeIfPresent(Double.self, forKey: .interestRateApr)
        let decodedAprBasisPoints = try container.decodeIfPresent(Int.self, forKey: .aprBasisPoints)
        let derivedAprBasisPoints = decodedAprBasisPoints ?? interestRateApr.map { Int(($0 * 100).rounded()) }
        let decodedInterestType = try container.decodeIfPresent(DebtInterestType.self, forKey: .interestType)
        let derivedInterestType = decodedInterestType ?? (derivedAprBasisPoints == nil ? .none : .apr)
        let cleanTargetPayoffDate = try container.decodeIfPresent(String.self, forKey: .targetPayoffDate)?.nilIfBlank ?? dueDate.nilIfBlank
        let decodedStrategy = try container.decodeIfPresent(DebtRepaymentStrategy.self, forKey: .repaymentStrategy)
        let derivedStrategy = decodedStrategy ?? {
            if minimumPaymentPence > 0 && cleanTargetPayoffDate != nil {
                return .fixedPayment
            }
            return .manualOnly
        }()

        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            lender: try container.decodeIfPresent(String.self, forKey: .lender) ?? "",
            originalAmountPence: originalAmountPence,
            currentBalancePence: currentBalancePence,
            minimumPaymentPence: minimumPaymentPence,
            dueDate: dueDate,
            interestRateApr: interestRateApr,
            note: try container.decodeIfPresent(String.self, forKey: .note) ?? "",
            status: try container.decodeIfPresent(DebtStatus.self, forKey: .status) ?? (currentBalancePence > 0 ? .active : .paidOff),
            createdAt: try container.decodeIfPresent(String.self, forKey: .createdAt) ?? DateUtilities.nowIsoString(),
            updatedAt: try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? DateUtilities.nowIsoString(),
            deletedAt: try container.decodeIfPresent(String.self, forKey: .deletedAt),
            type: try container.decodeIfPresent(DebtType.self, forKey: .type) ?? .other,
            startingBalancePence: try container.decodeIfPresent(Int.self, forKey: .startingBalancePence) ?? originalAmountPence,
            targetPayoffDate: cleanTargetPayoffDate,
            interestType: derivedInterestType,
            aprBasisPoints: derivedAprBasisPoints,
            interestAccrualMode: try container.decodeIfPresent(DebtInterestAccrualMode.self, forKey: .interestAccrualMode),
            fixedFeePence: try container.decodeIfPresent(Int.self, forKey: .fixedFeePence) ?? 0,
            extraPaymentPence: try container.decodeIfPresent(Int.self, forKey: .extraPaymentPence) ?? 0,
            repaymentStrategy: derivedStrategy,
            paymentFrequency: try container.decodeIfPresent(DebtPaymentFrequency.self, forKey: .paymentFrequency) ?? .monthly,
            paymentDay: try container.decodeIfPresent(Int.self, forKey: .paymentDay),
            payFirstTiming: try container.decodeIfPresent(DebtPayFirstTiming.self, forKey: .payFirstTiming) ?? .nextPayday,
            customFirstPaymentDate: try container.decodeIfPresent(String.self, forKey: .customFirstPaymentDate),
            recalculationMode: try container.decodeIfPresent(DebtRecalculationMode.self, forKey: .recalculationMode)
        )
    }
}

struct DebtPayment: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var debtId: String
    var amountPence: Int
    var date: String
    var note: String
    var sourcePotId: String?
    var paymentType: DebtPaymentType
    var scheduleItemId: String?
    var principalPaidPence: Int
    var interestPaidPence: Int
    var feePaidPence: Int
    var recalculationMode: DebtRecalculationMode?
    /// Nil on existing snapshots; populated when the payment is reversed by a refund.
    var refundedAt: String? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var isRefunded: Bool { refundedAt != nil }

    init(
        id: String,
        debtId: String,
        amountPence: Int,
        date: String,
        note: String,
        createdAt: String,
        updatedAt: String,
        deletedAt: String?,
        sourcePotId: String? = nil,
        paymentType: DebtPaymentType = .manualPayNow,
        scheduleItemId: String? = nil,
        principalPaidPence: Int? = nil,
        interestPaidPence: Int = 0,
        feePaidPence: Int = 0,
        recalculationMode: DebtRecalculationMode? = nil
    ) {
        let amount = max(0, abs(amountPence))
        let interest = max(0, interestPaidPence)
        let fee = max(0, feePaidPence)
        self.id = id
        self.debtId = debtId
        self.amountPence = amount
        self.date = date
        self.note = note
        self.sourcePotId = sourcePotId?.nilIfBlank
        self.paymentType = paymentType
        self.scheduleItemId = scheduleItemId?.nilIfBlank
        self.principalPaidPence = max(0, principalPaidPence ?? max(0, amount - interest - fee))
        self.interestPaidPence = interest
        self.feePaidPence = fee
        self.recalculationMode = recalculationMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, debtId, amountPence, date, note, sourcePotId, paymentType, scheduleItemId, principalPaidPence, interestPaidPence, feePaidPence, recalculationMode, refundedAt, createdAt, updatedAt, deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let amountPence = try container.decodeIfPresent(Int.self, forKey: .amountPence) ?? 0
        self.init(
            id: try container.decode(String.self, forKey: .id),
            debtId: try container.decode(String.self, forKey: .debtId),
            amountPence: amountPence,
            date: try container.decode(String.self, forKey: .date),
            note: try container.decodeIfPresent(String.self, forKey: .note) ?? "",
            createdAt: try container.decodeIfPresent(String.self, forKey: .createdAt) ?? DateUtilities.nowIsoString(),
            updatedAt: try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? DateUtilities.nowIsoString(),
            deletedAt: try container.decodeIfPresent(String.self, forKey: .deletedAt),
            sourcePotId: try container.decodeIfPresent(String.self, forKey: .sourcePotId),
            paymentType: try container.decodeIfPresent(DebtPaymentType.self, forKey: .paymentType) ?? .manualPayNow,
            scheduleItemId: try container.decodeIfPresent(String.self, forKey: .scheduleItemId),
            principalPaidPence: try container.decodeIfPresent(Int.self, forKey: .principalPaidPence),
            interestPaidPence: try container.decodeIfPresent(Int.self, forKey: .interestPaidPence) ?? 0,
            feePaidPence: try container.decodeIfPresent(Int.self, forKey: .feePaidPence) ?? 0,
            recalculationMode: try container.decodeIfPresent(DebtRecalculationMode.self, forKey: .recalculationMode)
        )
        self.refundedAt = try container.decodeIfPresent(String.self, forKey: .refundedAt)
    }
}

struct DebtPaymentScheduleItem: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var debtId: String
    var dueDate: String
    var plannedAmountPence: Int
    var principalAmountPence: Int
    var interestAmountPence: Int
    var feeAmountPence: Int
    var fundedAmountPence: Int
    var paidAmountPence: Int
    var paidDate: String?
    var status: DebtPaymentScheduleStatus
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var outstandingFundingPence: Int {
        max(0, plannedAmountPence - fundedAmountPence)
    }

    var outstandingPaymentPence: Int {
        max(0, plannedAmountPence - paidAmountPence)
    }
}

struct DebtSnapshot: Codable, Equatable, Sendable {
    var date: String
    var debtId: String
    var openingBalancePence: Int
    var interestAccruedPence: Int
    var paymentsMadePence: Int
    var closingBalancePence: Int
    var remainingScheduledAmountPence: Int
    var status: DebtStatus
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

enum CreditCardCycleStatementState: String, Codable, Equatable, Sendable {
    case normal
    case awaitingConfirmation
    case confirmed
}

enum CreditCardCycleDirectDebitState: String, Codable, Equatable, Sendable {
    case normal
    case awaitingPayment
    case confirmed
}

/// A one-off correction to a card's normal monthly cycle. The scheduled statement
/// date remains the stable identity so a temporary bank delay never changes future cycles.
struct CreditCardCycleOverride: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var creditCardId: String
    var scheduledStatementDate: String
    var statementState: CreditCardCycleStatementState
    var actualStatementDate: String?
    var directDebitState: CreditCardCycleDirectDebitState
    var actualDirectDebitDate: String?
    var reversedAutomaticRepaymentIds: [String]
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
    var potContributions: [CreditCardPotContribution]? = nil
    var paycheckContributionPence: Int? = nil
    /// Nil on existing snapshots; a refund leaves the repayment visible but no
    /// longer reduces the card balance or statement due.
    var refundedAt: String? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var isRefunded: Bool { refundedAt != nil }
}

struct CreditCardPotContribution: Codable, Equatable, Sendable {
    var potId: String
    var amountPence: Int
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
    var recurringPaymentOccurrenceOverrides: [RecurringPaymentOccurrenceOverride]
    var billGroups: [BillGroup]
    var payPeriods: [PayPeriod]
    var paychecks: [Paycheck]
    var potAllocations: [PotAllocation]
    var transactions: [Transaction]
    var debts: [Debt]
    var debtPayments: [DebtPayment]
    var debtReserves: [DebtReserve]
    var debtPaymentScheduleItems: [DebtPaymentScheduleItem]
    var debtSnapshots: [DebtSnapshot]
    var creditCards: [CreditCard]
    var customPayments: [CustomPayment]
    var creditCardRepayments: [CreditCardRepayment]
    var creditCardPots: [CreditCardPot]
    var creditCardCycleOverrides: [CreditCardCycleOverride]
    var dailyBriefs: [DailyBrief]
    var oneOffIncomes: [OneOffIncome]
    var fundingChecklistExclusions: [FundingChecklistExclusion]
    var bankAccounts: [BankAccount]

    init(
        settings: Settings,
        pots: [Pot],
        recurringPayments: [RecurringPayment],
        recurringPaymentOccurrenceOverrides: [RecurringPaymentOccurrenceOverride] = [],
        billGroups: [BillGroup] = [],
        payPeriods: [PayPeriod],
        paychecks: [Paycheck],
        potAllocations: [PotAllocation],
        transactions: [Transaction],
        debts: [Debt],
        debtPayments: [DebtPayment],
        debtReserves: [DebtReserve],
        debtPaymentScheduleItems: [DebtPaymentScheduleItem] = [],
        debtSnapshots: [DebtSnapshot] = [],
        creditCards: [CreditCard],
        customPayments: [CustomPayment],
        creditCardRepayments: [CreditCardRepayment],
        creditCardPots: [CreditCardPot],
        creditCardCycleOverrides: [CreditCardCycleOverride] = [],
        dailyBriefs: [DailyBrief],
        oneOffIncomes: [OneOffIncome] = [],
        fundingChecklistExclusions: [FundingChecklistExclusion] = [],
        bankAccounts: [BankAccount] = []
    ) {
        self.settings = settings
        self.pots = pots
        self.recurringPayments = recurringPayments
        self.recurringPaymentOccurrenceOverrides = recurringPaymentOccurrenceOverrides
        self.billGroups = billGroups
        self.payPeriods = payPeriods
        self.paychecks = paychecks
        self.potAllocations = potAllocations
        self.transactions = transactions
        self.debts = debts
        self.debtPayments = debtPayments
        self.debtReserves = debtReserves
        self.debtPaymentScheduleItems = debtPaymentScheduleItems
        self.debtSnapshots = debtSnapshots
        self.creditCards = creditCards
        self.customPayments = customPayments
        self.creditCardRepayments = creditCardRepayments
        self.creditCardPots = creditCardPots
        self.creditCardCycleOverrides = creditCardCycleOverrides
        self.dailyBriefs = dailyBriefs
        self.oneOffIncomes = oneOffIncomes
        self.fundingChecklistExclusions = fundingChecklistExclusions
        self.bankAccounts = bankAccounts
    }

    private enum CodingKeys: String, CodingKey {
        case settings, pots, recurringPayments, recurringPaymentOccurrenceOverrides, billGroups, payPeriods, paychecks, potAllocations, transactions, debts, debtPayments, debtReserves, debtPaymentScheduleItems, debtSnapshots, creditCards, customPayments, creditCardRepayments, creditCardPots, creditCardCycleOverrides, dailyBriefs, oneOffIncomes, fundingChecklistExclusions, bankAccounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            settings: try container.decode(Settings.self, forKey: .settings),
            pots: try container.decodeIfPresent([Pot].self, forKey: .pots) ?? [],
            recurringPayments: try container.decodeIfPresent([RecurringPayment].self, forKey: .recurringPayments) ?? [],
            recurringPaymentOccurrenceOverrides: try container.decodeIfPresent([RecurringPaymentOccurrenceOverride].self, forKey: .recurringPaymentOccurrenceOverrides) ?? [],
            billGroups: try container.decodeIfPresent([BillGroup].self, forKey: .billGroups) ?? [],
            payPeriods: try container.decodeIfPresent([PayPeriod].self, forKey: .payPeriods) ?? [],
            paychecks: try container.decodeIfPresent([Paycheck].self, forKey: .paychecks) ?? [],
            potAllocations: try container.decodeIfPresent([PotAllocation].self, forKey: .potAllocations) ?? [],
            transactions: try container.decodeIfPresent([Transaction].self, forKey: .transactions) ?? [],
            debts: try container.decodeIfPresent([Debt].self, forKey: .debts) ?? [],
            debtPayments: try container.decodeIfPresent([DebtPayment].self, forKey: .debtPayments) ?? [],
            debtReserves: try container.decodeIfPresent([DebtReserve].self, forKey: .debtReserves) ?? [],
            debtPaymentScheduleItems: try container.decodeIfPresent([DebtPaymentScheduleItem].self, forKey: .debtPaymentScheduleItems) ?? [],
            debtSnapshots: try container.decodeIfPresent([DebtSnapshot].self, forKey: .debtSnapshots) ?? [],
            creditCards: try container.decodeIfPresent([CreditCard].self, forKey: .creditCards) ?? [],
            customPayments: try container.decodeIfPresent([CustomPayment].self, forKey: .customPayments) ?? [],
            creditCardRepayments: try container.decodeIfPresent([CreditCardRepayment].self, forKey: .creditCardRepayments) ?? [],
            creditCardPots: try container.decodeIfPresent([CreditCardPot].self, forKey: .creditCardPots) ?? [],
            creditCardCycleOverrides: try container.decodeIfPresent([CreditCardCycleOverride].self, forKey: .creditCardCycleOverrides) ?? [],
            dailyBriefs: try container.decodeIfPresent([DailyBrief].self, forKey: .dailyBriefs) ?? [],
            oneOffIncomes: try container.decodeIfPresent([OneOffIncome].self, forKey: .oneOffIncomes) ?? [],
            fundingChecklistExclusions: try container.decodeIfPresent([FundingChecklistExclusion].self, forKey: .fundingChecklistExclusions) ?? [],
            bankAccounts: try container.decodeIfPresent([BankAccount].self, forKey: .bankAccounts) ?? []
        )
    }
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
