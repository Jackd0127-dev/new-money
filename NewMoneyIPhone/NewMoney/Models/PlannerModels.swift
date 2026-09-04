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

enum PotBankTransferDirection: String, Sendable, CaseIterable, Identifiable {
    case bankToPot
    case potToBank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bankToPot: "Bank to pot"
        case .potToBank: "Pot to bank"
        }
    }

    var reversed: Self {
        self == .bankToPot ? .potToBank : .bankToPot
    }
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
    /// Tracks normalization of paid opening statements saved against the following cycle.
    var creditCardOpeningStatementCycleMigrationVersion: Int? = nil
    /// Controls whether reserved pot balances are part of the displayed Money left total.
    /// Optional so snapshots saved before this setting existed continue to decode.
    var includePotsInMoneyLeft: Bool? = true
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
    case cancelled
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
    var amountPenceOverride: Int? = nil
    /// The portion returned for this occurrence. Legacy `.refunded` overrides
    /// without an amount still resolve as a full refund.
    var refundedAmountPence: Int? = nil
    var reversedGeneratedTransactionIds: [String]
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    func effectiveRefundedAmountPence(originalAmountPence: Int) -> Int {
        let original = max(0, originalAmountPence)
        if let refundedAmountPence {
            return min(original, max(0, refundedAmountPence))
        }
        return state == .refunded ? original : 0
    }
}

enum IncomeOccurrenceSourceKind: String, Codable, Equatable, Sendable {
    case paycheck
    case oneOffIncome = "one_off_income"
}

enum IncomeOccurrenceState: String, Codable, Equatable, Sendable, CaseIterable, Identifiable {
    case normal
    case awaiting
    case confirmed
    case cancelled

    var id: String { rawValue }
}

/// A one-off correction to an income event. The scheduled date remains the
/// stable identity so changing one payday never shifts the normal cadence.
struct IncomeOccurrenceOverride: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var sourceKind: IncomeOccurrenceSourceKind
    var sourceId: String
    var scheduledDate: String
    var state: IncomeOccurrenceState
    var actualDate: String?
    var amountPenceOverride: Int?
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
    /// Nil on legacy full refunds. New refunds store the exact returned amount
    /// so partial refunds only reverse that portion of the payment.
    var refundedAmountPence: Int? = nil
    /// Funding allocations removed with a refunded card spend, retained so an
    /// accidental refund toggle can put the exact checklist funding back.
    var refundedCardSpendFundingPayPeriodIds: [String]? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var effectiveRefundedAmountPence: Int {
        guard refundedAt != nil else { return 0 }
        return min(max(0, amountPence), max(0, refundedAmountPence ?? amountPence))
    }

    var netAmountPence: Int { max(0, amountPence - effectiveRefundedAmountPence) }
    var hasRefund: Bool { effectiveRefundedAmountPence > 0 }
    var isPartiallyRefunded: Bool { hasRefund && netAmountPence > 0 }
    var isRefunded: Bool { hasRefund && netAmountPence == 0 }

    var potBankTransferDirection: PotBankTransferDirection? {
        guard type == .transfer, potId != nil, bankAccountId != nil else { return nil }
        switch paymentMethod {
        case .bankAccount: return PotBankTransferDirection.bankToPot
        case .pot: return PotBankTransferDirection.potToBank
        case .income, .creditCard, nil: return nil
        }
    }
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
    var refundedAmountPence: Int? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var effectiveRefundedAmountPence: Int {
        guard refundedAt != nil else { return 0 }
        return min(max(0, amountPence), max(0, refundedAmountPence ?? amountPence))
    }

    var netAmountPence: Int { max(0, amountPence - effectiveRefundedAmountPence) }
    var effectivePrincipalPaidPence: Int { proportionalNetComponent(principalPaidPence) }
    var effectiveInterestPaidPence: Int { proportionalNetComponent(interestPaidPence) }
    var effectiveFeePaidPence: Int { proportionalNetComponent(feePaidPence) }
    var hasRefund: Bool { effectiveRefundedAmountPence > 0 }
    var isPartiallyRefunded: Bool { hasRefund && netAmountPence > 0 }
    var isRefunded: Bool { hasRefund && netAmountPence == 0 }

    private func proportionalNetComponent(_ componentPence: Int) -> Int {
        guard amountPence > 0, netAmountPence > 0 else { return 0 }
        if netAmountPence == amountPence { return max(0, componentPence) }
        return min(
            max(0, componentPence),
            Int((Double(max(0, componentPence)) * Double(netAmountPence) / Double(amountPence)).rounded())
        )
    }

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
        recalculationMode: DebtRecalculationMode? = nil,
        refundedAt: String? = nil,
        refundedAmountPence: Int? = nil
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
        self.refundedAt = refundedAt
        self.refundedAmountPence = refundedAmountPence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, debtId, amountPence, date, note, sourcePotId, paymentType, scheduleItemId, principalPaidPence, interestPaidPence, feePaidPence, recalculationMode, refundedAt, refundedAmountPence, createdAt, updatedAt, deletedAt
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
            recalculationMode: try container.decodeIfPresent(DebtRecalculationMode.self, forKey: .recalculationMode),
            refundedAt: try container.decodeIfPresent(String.self, forKey: .refundedAt),
            refundedAmountPence: try container.decodeIfPresent(Int.self, forKey: .refundedAmountPence)
        )
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
    var amountPenceOverride: Int? = nil
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
    var refundedAmountPence: Int? = nil
    var createdAt: String
    var updatedAt: String
    var deletedAt: String?

    var effectiveRefundedAmountPence: Int {
        guard refundedAt != nil else { return 0 }
        return min(max(0, amountPence), max(0, refundedAmountPence ?? amountPence))
    }

    var netAmountPence: Int { max(0, amountPence - effectiveRefundedAmountPence) }
    var hasRefund: Bool { effectiveRefundedAmountPence > 0 }
    var isPartiallyRefunded: Bool { hasRefund && netAmountPence > 0 }
    var isRefunded: Bool { hasRefund && netAmountPence == 0 }
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

enum PlannerAuditRecordKind: String, Codable, CaseIterable, Sendable {
    case bankAccount
    case pot
    case recurringPayment
    case recurringOccurrence
    case incomeOccurrence
    case billGroup
    case payPeriod
    case paycheck
    case oneOffIncome
    case potAllocation
    case transaction
    case debt
    case debtPayment
    case debtReserve
    case debtSchedule
    case creditCard
    case customPayment
    case creditCardRepayment
    case creditCardPot
    case creditCardCycle
}

enum PlannerAuditAction: String, Codable, Sendable {
    case baseline
    case created
    case edited
    case deleted
    case reverted
    case automatic
}

enum PlannerAuditOrigin: String, Codable, Sendable {
    case baseline
    case user
    case system
    case restore
}

struct PlannerAuditEffect: Codable, Equatable, Identifiable, Sendable {
    var label: String
    var deltaPence: Int

    var id: String { label }
}

struct PlannerAuditChange: Codable, Equatable, Identifiable, Sendable {
    var recordKind: PlannerAuditRecordKind
    var recordId: String
    var recordName: String
    var effectiveDate: String
    var amountPence: Int?
    var beforeJSON: String?
    var afterJSON: String?

    var id: String { "\(recordKind.rawValue):\(recordId)" }
}

struct PlannerAuditEvent: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var occurredAt: String
    var effectiveDate: String
    var action: PlannerAuditAction
    var origin: PlannerAuditOrigin
    var title: String
    var subtitle: String
    var amountPence: Int?
    var changes: [PlannerAuditChange]
    var effects: [PlannerAuditEffect]
    var restoredFromEventId: String? = nil
}

enum PlannerAuditRefundTransition: Equatable, Sendable {
    case applied
    case increased
    case decreased
    case removed
}

struct PlannerAuditRefundActivity: Equatable, Sendable {
    var recordKind: PlannerAuditRecordKind
    var recordId: String
    var recordName: String
    var previousAmountPence: Int
    var currentAmountPence: Int
    var transition: PlannerAuditRefundTransition

    var displayAmountPence: Int {
        currentAmountPence > 0 ? currentAmountPence : previousAmountPence
    }
}

struct PlannerSnapshot: Codable, Equatable, Sendable {
    var settings: Settings
    var pots: [Pot]
    var recurringPayments: [RecurringPayment]
    var recurringPaymentOccurrenceOverrides: [RecurringPaymentOccurrenceOverride]
    var incomeOccurrenceOverrides: [IncomeOccurrenceOverride]
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
    var auditEvents: [PlannerAuditEvent]

    init(
        settings: Settings,
        pots: [Pot],
        recurringPayments: [RecurringPayment],
        recurringPaymentOccurrenceOverrides: [RecurringPaymentOccurrenceOverride] = [],
        incomeOccurrenceOverrides: [IncomeOccurrenceOverride] = [],
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
        bankAccounts: [BankAccount] = [],
        auditEvents: [PlannerAuditEvent] = []
    ) {
        self.settings = settings
        self.pots = pots
        self.recurringPayments = recurringPayments
        self.recurringPaymentOccurrenceOverrides = recurringPaymentOccurrenceOverrides
        self.incomeOccurrenceOverrides = incomeOccurrenceOverrides
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
        self.auditEvents = auditEvents
    }

    private enum CodingKeys: String, CodingKey {
        case settings, pots, recurringPayments, recurringPaymentOccurrenceOverrides, incomeOccurrenceOverrides, billGroups, payPeriods, paychecks, potAllocations, transactions, debts, debtPayments, debtReserves, debtPaymentScheduleItems, debtSnapshots, creditCards, customPayments, creditCardRepayments, creditCardPots, creditCardCycleOverrides, dailyBriefs, oneOffIncomes, fundingChecklistExclusions, bankAccounts, auditEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            settings: try container.decode(Settings.self, forKey: .settings),
            pots: try container.decodeIfPresent([Pot].self, forKey: .pots) ?? [],
            recurringPayments: try container.decodeIfPresent([RecurringPayment].self, forKey: .recurringPayments) ?? [],
            recurringPaymentOccurrenceOverrides: try container.decodeIfPresent([RecurringPaymentOccurrenceOverride].self, forKey: .recurringPaymentOccurrenceOverrides) ?? [],
            incomeOccurrenceOverrides: try container.decodeIfPresent([IncomeOccurrenceOverride].self, forKey: .incomeOccurrenceOverrides) ?? [],
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
            bankAccounts: try container.decodeIfPresent([BankAccount].self, forKey: .bankAccounts) ?? [],
            auditEvents: try container.decodeIfPresent([PlannerAuditEvent].self, forKey: .auditEvents) ?? []
        )
    }
}

enum PlannerAuditEngine {
    static func baselineEvents(for snapshot: PlannerSnapshot) -> [PlannerAuditEvent] {
        var changes: [PlannerAuditChange] = []
        appendBaseline(snapshot.transactions, kind: .transaction, to: &changes) { transaction in
            descriptor(
                name: transaction.note.nilIfBlank ?? "Payment",
                date: transaction.date,
                amountPence: transaction.netAmountPence
            )
        }
        appendBaseline(snapshot.recurringPayments, kind: .recurringPayment, to: &changes) { payment in
            descriptor(name: payment.name, date: payment.dueDate ?? payment.createdAt, amountPence: payment.amountPence)
        }
        appendBaseline(snapshot.creditCardRepayments, kind: .creditCardRepayment, to: &changes) { repayment in
            descriptor(name: repayment.note.nilIfBlank ?? "Card payment", date: repayment.date, amountPence: repayment.netAmountPence)
        }
        appendBaseline(snapshot.creditCards, kind: .creditCard, to: &changes) { card in
            descriptor(name: card.name, date: card.statementDate ?? card.createdAt, amountPence: card.openingBalancePence)
        }
        appendBaseline(snapshot.creditCardCycleOverrides, kind: .creditCardCycle, to: &changes) { cycle in
            descriptor(name: "Card statement", date: cycle.actualStatementDate ?? cycle.scheduledStatementDate, amountPence: cycle.amountPenceOverride)
        }
        appendBaseline(snapshot.paychecks, kind: .paycheck, to: &changes) { paycheck in
            descriptor(name: "Paycheck", date: paycheck.createdAt, amountPence: paycheck.actualAmountPence ?? paycheck.calculatedAmountPence)
        }
        appendBaseline(snapshot.oneOffIncomes, kind: .oneOffIncome, to: &changes) { income in
            descriptor(name: income.name, date: income.date, amountPence: income.amountPence)
        }
        appendBaseline(snapshot.payPeriods, kind: .payPeriod, to: &changes) { period in
            descriptor(name: "Pay period", date: period.payday, amountPence: period.incomePence)
        }
        appendBaseline(snapshot.potAllocations, kind: .potAllocation, to: &changes) { allocation in
            descriptor(name: "Pot allocation", date: allocation.transactionDate ?? allocation.createdAt, amountPence: allocation.amountPence)
        }
        appendBaseline(snapshot.pots, kind: .pot, to: &changes) { pot in
            descriptor(name: pot.name, date: pot.createdAt, amountPence: pot.balancePence)
        }
        appendBaseline(snapshot.bankAccounts, kind: .bankAccount, to: &changes) { account in
            descriptor(name: account.name, date: account.createdAt, amountPence: PlannerDerivedData.bankAccountBalance(account: account, snapshot: snapshot))
        }
        appendBaseline(snapshot.debts, kind: .debt, to: &changes) { debt in
            descriptor(name: debt.name, date: debt.dueDate.nilIfBlank ?? debt.createdAt, amountPence: debt.currentBalancePence)
        }
        appendBaseline(snapshot.debtPayments, kind: .debtPayment, to: &changes) { payment in
            descriptor(name: payment.note.nilIfBlank ?? "Debt payment", date: payment.date, amountPence: payment.netAmountPence)
        }
        appendBaseline(snapshot.debtReserves, kind: .debtReserve, to: &changes) { reserve in
            descriptor(name: reserve.note.nilIfBlank ?? "Debt reserve", date: reserve.payday, amountPence: reserve.amountPence)
        }
        appendBaseline(snapshot.customPayments, kind: .customPayment, to: &changes) { payment in
            descriptor(name: payment.name, date: payment.dueDate, amountPence: payment.amountPence)
        }
        appendBaseline(snapshot.billGroups, kind: .billGroup, to: &changes) { group in
            descriptor(name: group.name, date: group.createdAt, amountPence: nil)
        }
        appendBaseline(snapshot.recurringPaymentOccurrenceOverrides, kind: .recurringOccurrence, to: &changes) { occurrence in
            descriptor(name: "Bill occurrence", date: occurrence.actualDueDate ?? occurrence.scheduledDueDate, amountPence: occurrence.amountPenceOverride)
        }
        appendBaseline(snapshot.incomeOccurrenceOverrides, kind: .incomeOccurrence, to: &changes) { occurrence in
            descriptor(name: "Income occurrence", date: occurrence.actualDate ?? occurrence.scheduledDate, amountPence: occurrence.amountPenceOverride)
        }
        appendBaseline(snapshot.creditCardPots, kind: .creditCardPot, to: &changes) { pot in
            descriptor(name: pot.name, date: pot.createdAt, amountPence: pot.amountPence)
        }
        appendBaseline(snapshot.debtPaymentScheduleItems, kind: .debtSchedule, to: &changes) { item in
            descriptor(name: "Debt schedule", date: item.dueDate, amountPence: item.plannedAmountPence)
        }

        return changes.map { change in
            PlannerAuditEvent(
                id: "audit-baseline-\(change.recordKind.rawValue)-\(change.recordId)",
                occurredAt: normalizedTimestamp(change.effectiveDate),
                effectiveDate: change.effectiveDate,
                action: .baseline,
                origin: .baseline,
                title: change.recordName,
                subtitle: "Baseline \(displayName(for: change.recordKind))",
                amountPence: change.amountPence,
                changes: [change],
                effects: []
            )
        }
        .sorted { $0.occurredAt < $1.occurredAt }
    }

    static func event(
        before: PlannerSnapshot,
        after: PlannerSnapshot,
        origin: PlannerAuditOrigin,
        restoredFromEventId: String? = nil
    ) -> PlannerAuditEvent? {
        var changes: [PlannerAuditChange] = []
        appendChanges(before.transactions, after.transactions, kind: .transaction, to: &changes) { item in
            descriptor(name: item.note.nilIfBlank ?? "Payment", date: item.date, amountPence: item.netAmountPence)
        }
        appendChanges(before.recurringPayments, after.recurringPayments, kind: .recurringPayment, to: &changes) { item in
            descriptor(name: item.name, date: item.dueDate ?? item.updatedAt, amountPence: item.amountPence)
        }
        appendChanges(before.creditCardRepayments, after.creditCardRepayments, kind: .creditCardRepayment, to: &changes) { item in
            descriptor(name: item.note.nilIfBlank ?? "Card payment", date: item.date, amountPence: item.netAmountPence)
        }
        appendChanges(before.creditCards, after.creditCards, kind: .creditCard, to: &changes) { item in
            descriptor(name: item.name, date: item.statementDate ?? item.updatedAt, amountPence: item.openingBalancePence)
        }
        appendChanges(before.creditCardCycleOverrides, after.creditCardCycleOverrides, kind: .creditCardCycle, to: &changes) { item in
            descriptor(name: "Card statement", date: item.actualStatementDate ?? item.scheduledStatementDate, amountPence: item.amountPenceOverride)
        }
        appendChanges(before.paychecks, after.paychecks, kind: .paycheck, to: &changes) { item in
            descriptor(name: "Paycheck", date: item.updatedAt, amountPence: item.actualAmountPence ?? item.calculatedAmountPence)
        }
        appendChanges(before.oneOffIncomes, after.oneOffIncomes, kind: .oneOffIncome, to: &changes) { item in
            descriptor(name: item.name, date: item.date, amountPence: item.amountPence)
        }
        appendChanges(before.customPayments, after.customPayments, kind: .customPayment, to: &changes) { item in
            descriptor(name: item.name, date: item.dueDate, amountPence: item.amountPence)
        }
        appendChanges(before.debtPayments, after.debtPayments, kind: .debtPayment, to: &changes) { item in
            descriptor(name: item.note.nilIfBlank ?? "Debt payment", date: item.date, amountPence: item.netAmountPence)
        }
        appendChanges(before.debts, after.debts, kind: .debt, to: &changes) { item in
            descriptor(name: item.name, date: item.dueDate.nilIfBlank ?? item.updatedAt, amountPence: item.currentBalancePence)
        }
        appendChanges(before.potAllocations, after.potAllocations, kind: .potAllocation, to: &changes) { item in
            descriptor(name: "Pot allocation", date: item.transactionDate ?? item.updatedAt, amountPence: item.amountPence)
        }
        appendChanges(before.pots, after.pots, kind: .pot, to: &changes) { item in
            descriptor(name: item.name, date: item.updatedAt, amountPence: item.balancePence)
        }
        appendChanges(before.bankAccounts, after.bankAccounts, kind: .bankAccount, to: &changes) { item in
            descriptor(name: item.name, date: item.updatedAt, amountPence: item.openingBalancePence)
        }
        appendChanges(before.payPeriods, after.payPeriods, kind: .payPeriod, to: &changes) { item in
            descriptor(name: "Pay period", date: item.payday, amountPence: item.incomePence)
        }
        appendChanges(before.recurringPaymentOccurrenceOverrides, after.recurringPaymentOccurrenceOverrides, kind: .recurringOccurrence, to: &changes) { item in
            descriptor(name: "Bill occurrence", date: item.actualDueDate ?? item.scheduledDueDate, amountPence: item.amountPenceOverride)
        }
        appendChanges(before.incomeOccurrenceOverrides, after.incomeOccurrenceOverrides, kind: .incomeOccurrence, to: &changes) { item in
            descriptor(name: "Income occurrence", date: item.actualDate ?? item.scheduledDate, amountPence: item.amountPenceOverride)
        }
        appendChanges(before.creditCardPots, after.creditCardPots, kind: .creditCardPot, to: &changes) { item in
            descriptor(name: item.name, date: item.updatedAt, amountPence: item.amountPence)
        }
        appendChanges(before.debtReserves, after.debtReserves, kind: .debtReserve, to: &changes) { item in
            descriptor(name: item.note.nilIfBlank ?? "Debt reserve", date: item.payday, amountPence: item.amountPence)
        }
        appendChanges(before.billGroups, after.billGroups, kind: .billGroup, to: &changes) { item in
            descriptor(name: item.name, date: item.updatedAt, amountPence: nil)
        }
        appendChanges(before.debtPaymentScheduleItems, after.debtPaymentScheduleItems, kind: .debtSchedule, to: &changes) { item in
            descriptor(name: "Debt schedule", date: item.dueDate, amountPence: item.plannedAmountPence)
        }

        guard let primary = changes.first else { return nil }
        let action: PlannerAuditAction
        switch origin {
        case .restore:
            action = .reverted
        case .system:
            action = .automatic
        case .baseline:
            action = .baseline
        case .user:
            if primary.beforeJSON == nil { action = .created }
            else if primary.afterJSON == nil { action = .deleted }
            else { action = .edited }
        }

        let timestamp = DateUtilities.nowIsoString()
        return PlannerAuditEvent(
            id: DateUtilities.newId(prefix: "planner-audit"),
            occurredAt: timestamp,
            effectiveDate: primary.effectiveDate,
            action: action,
            origin: origin,
            title: eventTitle(name: primary.recordName, action: action),
            subtitle: changes.count == 1
                ? displayName(for: primary.recordKind)
                : "\(displayName(for: primary.recordKind)) and \(changes.count - 1) linked changes",
            amountPence: primary.amountPence,
            changes: changes,
            effects: effects(before: before, after: after),
            restoredFromEventId: restoredFromEventId
        )
    }

    static func decode<T: Decodable>(_ type: T.Type, json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Refund activity is derived from the immutable before/after audit payloads.
    /// The underlying finance records remain the source of truth, so no audit
    /// schema migration is required.
    static func refundActivity(
        for event: PlannerAuditEvent,
        snapshot: PlannerSnapshot
    ) -> PlannerAuditRefundActivity? {
        let candidates = event.changes.compactMap { change -> PlannerAuditRefundActivity? in
            guard change.afterJSON != nil,
                  let amounts = refundAmounts(for: change, snapshot: snapshot),
                  amounts.previous != amounts.current
            else { return nil }

            let transition: PlannerAuditRefundTransition
            if amounts.previous == 0 {
                transition = .applied
            } else if amounts.current == 0 {
                transition = .removed
            } else if amounts.current > amounts.previous {
                transition = .increased
            } else {
                transition = .decreased
            }

            return PlannerAuditRefundActivity(
                recordKind: change.recordKind,
                recordId: change.recordId,
                recordName: change.recordName,
                previousAmountPence: amounts.previous,
                currentAmountPence: amounts.current,
                transition: transition
            )
        }

        return candidates.max { lhs, rhs in
            abs(lhs.currentAmountPence - lhs.previousAmountPence)
                < abs(rhs.currentAmountPence - rhs.previousAmountPence)
        }
    }

    /// Produces a stable source identity for subtle History colouring. Linked
    /// records deliberately collapse to their canonical bill/card/debt source.
    static func relationshipKey(
        for event: PlannerAuditEvent,
        snapshot: PlannerSnapshot
    ) -> String {
        for change in event.changes {
            if let key = relationshipKey(for: change, snapshot: snapshot) {
                return key
            }
        }
        guard let primary = event.changes.first else { return "event:\(event.id)" }
        return "\(primary.recordKind.rawValue):\(primary.recordId)"
    }

    static func stableRelationshipHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    static func displayName(for kind: PlannerAuditRecordKind) -> String {
        switch kind {
        case .bankAccount: "Bank account"
        case .pot: "Pot"
        case .recurringPayment: "Bill"
        case .recurringOccurrence: "Bill occurrence"
        case .incomeOccurrence: "Income occurrence"
        case .billGroup: "Bill group"
        case .payPeriod: "Pay period"
        case .paycheck: "Paycheck"
        case .oneOffIncome: "Income"
        case .potAllocation: "Pot allocation"
        case .transaction: "Payment"
        case .debt: "Debt"
        case .debtPayment: "Debt payment"
        case .debtReserve: "Debt reserve"
        case .debtSchedule: "Debt schedule"
        case .creditCard: "Credit card"
        case .customPayment: "Saved payment"
        case .creditCardRepayment: "Card payment"
        case .creditCardPot: "Card pot"
        case .creditCardCycle: "Statement"
        }
    }

    private struct Descriptor {
        var name: String
        var date: String
        var amountPence: Int?
    }

    private static func descriptor(name: String, date: String, amountPence: Int?) -> Descriptor {
        Descriptor(name: name, date: normalizedDate(date), amountPence: amountPence)
    }

    private static func refundAmounts(
        for change: PlannerAuditChange,
        snapshot: PlannerSnapshot
    ) -> (previous: Int, current: Int)? {
        switch change.recordKind {
        case .transaction:
            let previous = change.beforeJSON.flatMap { decode(Transaction.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            let current = change.afterJSON.flatMap { decode(Transaction.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            return (previous, current)
        case .creditCardRepayment:
            let previous = change.beforeJSON.flatMap { decode(CreditCardRepayment.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            let current = change.afterJSON.flatMap { decode(CreditCardRepayment.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            return (previous, current)
        case .debtPayment:
            let previous = change.beforeJSON.flatMap { decode(DebtPayment.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            let current = change.afterJSON.flatMap { decode(DebtPayment.self, json: $0) }?.effectiveRefundedAmountPence ?? 0
            return (previous, current)
        case .recurringOccurrence:
            let previous = change.beforeJSON.flatMap { decode(RecurringPaymentOccurrenceOverride.self, json: $0) }
            let current = change.afterJSON.flatMap { decode(RecurringPaymentOccurrenceOverride.self, json: $0) }
            let paymentId = current?.paymentId ?? previous?.paymentId
            let normalAmountPence = snapshot.recurringPayments.first { $0.id == paymentId }?.amountPence ?? 0
            let previousAmount = previous.map {
                $0.effectiveRefundedAmountPence(originalAmountPence: $0.amountPenceOverride ?? normalAmountPence)
            } ?? 0
            let currentAmount = current.map {
                $0.effectiveRefundedAmountPence(originalAmountPence: $0.amountPenceOverride ?? normalAmountPence)
            } ?? 0
            return (previousAmount, currentAmount)
        default:
            return nil
        }
    }

    private static func relationshipKey(
        for change: PlannerAuditChange,
        snapshot: PlannerSnapshot
    ) -> String? {
        switch change.recordKind {
        case .transaction:
            guard let value = auditValue(
                Transaction.self,
                change: change,
                current: snapshot.transactions.first { $0.id == change.recordId }
            ) else { return nil }
            if let paymentId = value.recurringPaymentId { return "bill:\(paymentId)" }
            if let cardId = value.creditCardId { return "card:\(cardId)" }
            if let potId = value.potId { return "pot:\(potId)" }
            if let bankId = value.bankAccountId { return "bank:\(bankId)" }
            return "transaction:\(value.id)"
        case .recurringPayment:
            return "bill:\(change.recordId)"
        case .recurringOccurrence:
            let value = auditValue(
                RecurringPaymentOccurrenceOverride.self,
                change: change,
                current: snapshot.recurringPaymentOccurrenceOverrides.first { $0.id == change.recordId }
            )
            return value.map { "bill:\($0.paymentId)" }
        case .potAllocation:
            guard let value = auditValue(
                PotAllocation.self,
                change: change,
                current: snapshot.potAllocations.first { $0.id == change.recordId }
            ) else { return nil }
            if let paymentId = value.recurringPaymentId { return "bill:\(paymentId)" }
            if let debtId = value.debtId { return "debt:\(debtId)" }
            if let cardId = value.creditCardId { return "card:\(cardId)" }
            if let transactionId = value.transactionId,
               let transaction = snapshot.transactions.first(where: { $0.id == transactionId }) {
                if let paymentId = transaction.recurringPaymentId { return "bill:\(paymentId)" }
                if let cardId = transaction.creditCardId { return "card:\(cardId)" }
            }
            return "pot:\(value.potId)"
        case .pot:
            return "pot:\(change.recordId)"
        case .bankAccount:
            return "bank:\(change.recordId)"
        case .debt:
            return "debt:\(change.recordId)"
        case .debtPayment:
            let value = auditValue(
                DebtPayment.self,
                change: change,
                current: snapshot.debtPayments.first { $0.id == change.recordId }
            )
            return value.map { "debt:\($0.debtId)" }
        case .debtReserve:
            let value = auditValue(
                DebtReserve.self,
                change: change,
                current: snapshot.debtReserves.first { $0.id == change.recordId }
            )
            return value.map { "debt:\($0.debtId)" }
        case .debtSchedule:
            let value = auditValue(
                DebtPaymentScheduleItem.self,
                change: change,
                current: snapshot.debtPaymentScheduleItems.first { $0.id == change.recordId }
            )
            return value.map { "debt:\($0.debtId)" }
        case .creditCard:
            return "card:\(change.recordId)"
        case .creditCardRepayment:
            let value = auditValue(
                CreditCardRepayment.self,
                change: change,
                current: snapshot.creditCardRepayments.first { $0.id == change.recordId }
            )
            return value.map { "card:\($0.creditCardId)" }
        case .creditCardPot:
            let value = auditValue(
                CreditCardPot.self,
                change: change,
                current: snapshot.creditCardPots.first { $0.id == change.recordId }
            )
            return value.map { "card:\($0.creditCardId)" }
        case .creditCardCycle:
            let value = auditValue(
                CreditCardCycleOverride.self,
                change: change,
                current: snapshot.creditCardCycleOverrides.first { $0.id == change.recordId }
            )
            return value.map { "card:\($0.creditCardId)" }
        case .customPayment:
            let value = auditValue(
                CustomPayment.self,
                change: change,
                current: snapshot.customPayments.first { $0.id == change.recordId }
            )
            if let cardId = value?.creditCardId { return "card:\(cardId)" }
            return "customPayment:\(change.recordId)"
        default:
            return nil
        }
    }

    private static func auditValue<T: Decodable>(
        _ type: T.Type,
        change: PlannerAuditChange,
        current: T?
    ) -> T? {
        if let json = change.afterJSON, let value = decode(type, json: json) { return value }
        if let json = change.beforeJSON, let value = decode(type, json: json) { return value }
        return current
    }

    private static func appendBaseline<T: Codable & Equatable & Identifiable>(
        _ values: [T],
        kind: PlannerAuditRecordKind,
        to changes: inout [PlannerAuditChange],
        describe: (T) -> Descriptor
    ) where T.ID == String {
        for value in values {
            let info = describe(value)
            changes.append(
                PlannerAuditChange(
                    recordKind: kind,
                    recordId: value.id,
                    recordName: info.name,
                    effectiveDate: info.date,
                    amountPence: info.amountPence,
                    beforeJSON: nil,
                    afterJSON: encode(value)
                )
            )
        }
    }

    private static func appendChanges<T: Codable & Equatable & Identifiable>(
        _ oldValues: [T],
        _ newValues: [T],
        kind: PlannerAuditRecordKind,
        to changes: inout [PlannerAuditChange],
        describe: (T) -> Descriptor
    ) where T.ID == String {
        // Imported and repaired snapshots can temporarily contain duplicate legacy IDs.
        // Audit capture must stay non-fatal while the canonical store mutation keeps the
        // last record, matching the snapshot's visible ordering semantics.
        let oldById = Dictionary(oldValues.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let newById = Dictionary(newValues.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        for id in Set(oldById.keys).union(newById.keys).sorted() {
            let oldValue = oldById[id]
            let newValue = newById[id]
            guard oldValue != newValue, let sample = newValue ?? oldValue else { continue }
            let info = describe(sample)
            changes.append(
                PlannerAuditChange(
                    recordKind: kind,
                    recordId: id,
                    recordName: info.name,
                    effectiveDate: info.date,
                    amountPence: info.amountPence,
                    beforeJSON: oldValue.map { encode($0) } ?? nil,
                    afterJSON: newValue.map { encode($0) } ?? nil
                )
            )
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func effects(before: PlannerSnapshot, after: PlannerSnapshot) -> [PlannerAuditEffect] {
        let beforeMetrics = metrics(before)
        let afterMetrics = metrics(after)
        return [
            PlannerAuditEffect(label: "Card owed", deltaPence: afterMetrics.cardOwed - beforeMetrics.cardOwed),
            PlannerAuditEffect(label: "Pot balances", deltaPence: afterMetrics.pots - beforeMetrics.pots),
            PlannerAuditEffect(label: "Bank balances", deltaPence: afterMetrics.banks - beforeMetrics.banks),
            PlannerAuditEffect(label: "Recorded spending", deltaPence: afterMetrics.spending - beforeMetrics.spending),
            PlannerAuditEffect(label: "Recorded income", deltaPence: afterMetrics.income - beforeMetrics.income)
        ].filter { $0.deltaPence != 0 }
    }

    private static func metrics(_ snapshot: PlannerSnapshot) -> (cardOwed: Int, pots: Int, banks: Int, spending: Int, income: Int) {
        let cardOwed = snapshot.creditCards
            .filter { !$0.archived && $0.deletedAt == nil }
            .reduce(0) { $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: snapshot) }
        let pots = snapshot.pots.filter { !$0.archived && $0.deletedAt == nil }.reduce(0) { $0 + $1.balancePence }
        let banks = snapshot.bankAccounts
            .filter { !$0.archived && $0.deletedAt == nil }
            .reduce(into: 0) { total, account in
                total += PlannerDerivedData.bankAccountBalance(account: account, snapshot: snapshot)
            }
        let spending = snapshot.transactions.filter { $0.deletedAt == nil && $0.type == .spending }.reduce(0) { $0 + $1.netAmountPence }
        let income = snapshot.paychecks.filter { $0.deletedAt == nil }.reduce(0) { $0 + ($1.actualAmountPence ?? $1.calculatedAmountPence) }
            + snapshot.oneOffIncomes.filter { $0.deletedAt == nil }.reduce(0) { $0 + $1.amountPence }
        return (cardOwed, pots, banks, spending, income)
    }

    private static func eventTitle(name: String, action: PlannerAuditAction) -> String {
        switch action {
        case .baseline: name
        case .created: "\(name) added"
        case .edited: "\(name) edited"
        case .deleted: "\(name) deleted"
        case .reverted: "\(name) restored"
        case .automatic: "\(name) recalculated"
        }
    }

    private static func normalizedDate(_ value: String) -> String {
        let prefix = String(value.prefix(10))
        return FinanceEngine.isIsoDate(prefix) ? prefix : FinanceEngine.toIsoDate(Date())
    }

    private static func normalizedTimestamp(_ value: String) -> String {
        if value.count > 10 { return value }
        return "\(normalizedDate(value))T12:00:00Z"
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
