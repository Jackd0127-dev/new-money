import Foundation

enum DefaultData {
    static let createdAt = "2026-05-16T00:00:00.000Z"

    static let defaultSettings = Settings(
        id: "default",
        currency: .gbp,
        payFrequency: .biweekly,
        defaultPayPeriodDays: 14,
        hourlyRatePence: 0,
        defaultHoursWorked: 0,
        appDateMode: .automatic,
        manualTodayIso: nil,
        aiInstructions: "",
        aiProvider: .gemini,
        createdAt: createdAt,
        updatedAt: createdAt,
        deletedAt: nil
    )

    static let defaultPots: [Pot] = [
        Pot(id: "pot-bills", name: "Bills", type: .reserved, category: "Bills", icon: "home", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-subscriptions", name: "Subscriptions", type: .reserved, category: "Bills", icon: "phone", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-food", name: "Food", type: .spending, category: "Spending", icon: "food", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-transport", name: "Transport", type: .spending, category: "Spending", icon: "car", balancePence: 0, targetPence: nil, color: "#0891b2", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-fun", name: "Fun", type: .spending, category: "Spending", icon: "gift", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-savings", name: "Savings", type: .saving, category: "Savings", icon: "savings", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-investments", name: "Investments", type: .investment, category: "Savings", icon: "target", balancePence: 0, targetPence: nil, color: "#4338ca", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
        Pot(id: "pot-buffer", name: "Buffer", type: .buffer, category: "Savings", icon: "wallet", balancePence: 0, targetPence: nil, color: "#475569", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil),
    ]

    static var emptySnapshot: PlannerSnapshot {
        PlannerSnapshot(
            settings: defaultSettings,
            pots: defaultPots,
            recurringPayments: [],
            payPeriods: [],
            paychecks: [],
            potAllocations: [],
            transactions: [],
            debts: [],
            debtPayments: [],
            debtReserves: [],
            creditCards: [],
            customPayments: [],
            creditCardRepayments: [],
            creditCardPots: [],
            dailyBriefs: []
        )
    }
}
