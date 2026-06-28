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
        assistantName: "Assistant",
        assistantResponseStyle: .straightToThePoint,
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

    static var basicDataSnapshot: PlannerSnapshot {
        let seedCreatedAt = "2026-07-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-07-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(
                id: "card-cc1",
                name: "CC1",
                provider: "CC1",
                limitPence: 100000,
                openingBalancePence: 50000,
                openingStatementBalancePence: 50000,
                statementDate: "2026-07-05",
                designId: nil,
                dueDay: 2,
                dueDate: nil,
                color: "#2563eb",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc2",
                name: "CC2",
                provider: "CC2",
                limitPence: 20000,
                openingBalancePence: 0,
                openingStatementBalancePence: 0,
                statementDate: "2026-07-15",
                designId: nil,
                dueDay: 10,
                dueDate: nil,
                color: "#16a34a",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc3",
                name: "CC3",
                provider: "CC3",
                limitPence: 50000,
                openingBalancePence: 0,
                openingStatementBalancePence: 0,
                statementDate: "2026-07-10",
                designId: nil,
                dueDay: 15,
                dueDate: nil,
                color: "#ea580c",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            )
        ]

        let pots = [
            Pot(id: "pot-cc1", name: "Pot 1", type: .reserved, category: "Cards", icon: "creditcard", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-cc2", name: "Pot 2", type: .reserved, category: "Cards", icon: "creditcard", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-cc3", name: "Pot 3", type: .reserved, category: "Cards", icon: "creditcard", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-skincare", name: "Skincare", amountPence: 5000, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-cc1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-insurance", name: "Insurance", amountPence: 10000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-cc2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-spending-money", name: "Spending money", amountPence: 20000, dueDay: 25, dueDate: nil, frequency: .monthly, potId: "pot-cc3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-chatgpt", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-cc1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let payPeriod = PayPeriod(
            id: "pay-period-basic-july-2026",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            nextPayday: "2026-08-01",
            payFrequency: .monthly,
            incomePence: 100000,
            status: .active,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let paycheck = Paycheck(
            id: "paycheck-basic-july-2026",
            payPeriodId: payPeriod.id,
            hoursWorked: 0,
            hourlyRatePence: 0,
            calculatedAmountPence: 100000,
            actualAmountPence: 100000,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: [payPeriod],
            paychecks: [paycheck],
            potAllocations: [],
            transactions: [],
            debts: [],
            debtPayments: [],
            debtReserves: [],
            creditCards: cards,
            customPayments: [],
            creditCardRepayments: [],
            creditCardPots: [],
            dailyBriefs: []
        )
    }

    static var complexStressSnapshot: PlannerSnapshot {
        let seedCreatedAt = "2026-09-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-09-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(
                id: "card-cc1",
                name: "Barclays Rewards",
                provider: "Barclays Rewards",
                limitPence: 120000,
                openingBalancePence: 43000,
                openingStatementBalancePence: 43000,
                statementDate: "2026-08-05",
                designId: nil,
                dueDay: 2,
                dueDate: nil,
                color: "#2563eb",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc2",
                name: "Capital One",
                provider: "Capital One",
                limitPence: 45000,
                openingBalancePence: 16000,
                openingStatementBalancePence: 16000,
                statementDate: "2026-08-15",
                designId: nil,
                dueDay: 10,
                dueDate: nil,
                color: "#16a34a",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc3",
                name: "Zable",
                provider: "Zable",
                limitPence: 60000,
                openingBalancePence: 21000,
                openingStatementBalancePence: 0,
                statementDate: "2026-09-03",
                designId: nil,
                dueDay: 18,
                dueDate: nil,
                color: "#ea580c",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc4",
                name: "Aqua",
                provider: "Aqua",
                limitPence: 30000,
                openingBalancePence: 9000,
                openingStatementBalancePence: 9000,
                statementDate: "2026-08-25",
                designId: nil,
                dueDay: 27,
                dueDate: nil,
                color: "#7c3aed",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            )
        ]

        let pots = [
            Pot(id: "pot-pot1", name: "Subscriptions", type: .reserved, category: "Subscriptions", icon: "phone", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot2", name: "Car & Insurance", type: .reserved, category: "Bills", icon: "car", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot3", name: "Food & Fuel", type: .reserved, category: "Spending", icon: "food", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot4", name: "Emergency", type: .reserved, category: "Emergency", icon: "wallet", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot5", name: "Annual & Work", type: .reserved, category: "Work", icon: "target", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: "card-cc4", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-bill-chatgpt", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-cloud-storage", name: "Cloud Storage", amountPence: 800, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-phone", name: "Phone", amountPence: 3400, dueDay: 12, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-gym-dd", name: "Gym Direct Debit", amountPence: 3200, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-insurance", name: "Insurance", amountPence: 11000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-finance", name: "Car Finance", amountPence: 22000, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries", name: "Groceries", amountPence: 8000, dueDay: nil, dueDate: "2026-09-07", frequency: .weekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel", name: "Fuel", amountPence: 5500, dueDay: nil, dueDate: "2026-09-04", frequency: .biweekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-barber", name: "Barber", amountPence: 1800, dueDay: nil, dueDate: "2026-09-09", frequency: .biweekly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-road-tax", name: "Road Tax", amountPence: 18000, dueDay: nil, dueDate: "2026-09-30", frequency: .quarterly, potId: "pot-pot5", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-tools-sub", name: "Tools Subscription", amountPence: 2400, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-emergency-transfer", name: "Emergency Fund Transfer", amountPence: 6000, dueDay: 8, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let septemberPeriod = PayPeriod(
            id: "pay-period-complex-september-2026",
            startDate: "2026-09-01",
            endDate: "2026-09-30",
            payday: "2026-09-01",
            nextPayday: "2026-10-01",
            payFrequency: .monthly,
            incomePence: 260000,
            status: .active,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let octoberPeriod = PayPeriod(
            id: "pay-period-complex-october-2026",
            startDate: "2026-10-01",
            endDate: "2026-10-31",
            payday: "2026-10-01",
            nextPayday: "2026-11-01",
            payFrequency: .monthly,
            incomePence: 260000,
            status: .planned,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let paychecks = [
            Paycheck(id: "paycheck-complex-september-2026", payPeriodId: septemberPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 260000, actualAmountPence: 260000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-complex-october-2026", payPeriodId: octoberPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 260000, actualAmountPence: 260000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: [septemberPeriod, octoberPeriod],
            paychecks: paychecks,
            potAllocations: [],
            transactions: [],
            debts: [],
            debtPayments: [],
            debtReserves: [],
            creditCards: cards,
            customPayments: [],
            creditCardRepayments: [],
            creditCardPots: [],
            dailyBriefs: []
        )
    }

    static var complexStressJanMar2027Snapshot: PlannerSnapshot {
        let seedCreatedAt = "2027-01-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = "2027-01-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(
                id: "card-cc1",
                name: "Barclays Rewards",
                provider: "Barclays Rewards",
                limitPence: 150000,
                openingBalancePence: 52000,
                openingStatementBalancePence: 52000,
                statementDate: "2026-12-05",
                designId: nil,
                dueDay: 2,
                dueDate: nil,
                color: "#2563eb",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc2",
                name: "Capital One",
                provider: "Capital One",
                limitPence: 65000,
                openingBalancePence: 28000,
                openingStatementBalancePence: 28000,
                statementDate: "2026-12-15",
                designId: nil,
                dueDay: 10,
                dueDate: nil,
                color: "#16a34a",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc3",
                name: "Zable",
                provider: "Zable",
                limitPence: 70000,
                openingBalancePence: 26000,
                openingStatementBalancePence: 0,
                statementDate: "2027-01-03",
                designId: nil,
                dueDay: 18,
                dueDate: nil,
                color: "#ea580c",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc4",
                name: "Aqua",
                provider: "Aqua",
                limitPence: 40000,
                openingBalancePence: 12000,
                openingStatementBalancePence: 12000,
                statementDate: "2026-12-25",
                designId: nil,
                dueDay: 27,
                dueDate: nil,
                color: "#7c3aed",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc5",
                name: "Jaja",
                provider: "Jaja",
                limitPence: 90000,
                openingBalancePence: 31000,
                openingStatementBalancePence: 0,
                statementDate: "2027-01-28",
                designId: nil,
                dueDay: 7,
                dueDate: nil,
                color: "#0f766e",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
        ]

        let pots = [
            Pot(id: "pot-pot1", name: "Subscriptions", type: .reserved, category: "Subscriptions", icon: "phone", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot2", name: "Car & Insurance", type: .reserved, category: "Bills", icon: "car", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot3", name: "Food & Fuel", type: .reserved, category: "Spending", icon: "food", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot4", name: "Emergency", type: .reserved, category: "Emergency", icon: "wallet", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: "card-cc4", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot5", name: "Annual & Work", type: .reserved, category: "Work", icon: "target", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: "card-cc5", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot6", name: "Rent & Travel", type: .reserved, category: "Housing", icon: "home", balancePence: 0, targetPence: nil, color: "#0891b2", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-bill-chatgpt", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-cloud-storage", name: "Cloud Storage", amountPence: 800, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-phone", name: "Phone", amountPence: 3400, dueDay: 12, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-gym-dd", name: "Gym Direct Debit", amountPence: 3200, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-insurance", name: "Insurance", amountPence: 11000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-finance", name: "Car Finance", amountPence: 22000, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-mot-savings", name: "MOT Savings", amountPence: 4500, dueDay: 14, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries", name: "Groceries", amountPence: 8000, dueDay: nil, dueDate: "2027-01-04", frequency: .weekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel", name: "Fuel", amountPence: 5500, dueDay: nil, dueDate: "2027-01-08", frequency: .biweekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-barber", name: "Barber", amountPence: 1800, dueDay: nil, dueDate: "2027-01-13", frequency: .biweekly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-bus-travel", name: "Bus Travel", amountPence: 4500, dueDay: nil, dueDate: "2027-01-02", frequency: .weekly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-rent-contribution", name: "Rent Contribution", amountPence: 65000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot6", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-emergency-transfer", name: "Emergency Fund Transfer", amountPence: 7500, dueDay: 8, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-road-tax", name: "Road Tax", amountPence: 18000, dueDay: nil, dueDate: "2027-01-31", frequency: .once, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-tools-sub", name: "Tools Subscription", amountPence: 2400, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-software-licence", name: "Software Licence", amountPence: 12000, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-trade-membership", name: "Trade Membership", amountPence: 9500, dueDay: nil, dueDate: "2027-02-01", frequency: .once, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-equipment-insurance", name: "Equipment Insurance", amountPence: 7500, dueDay: 25, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let januaryPeriod = PayPeriod(
            id: "pay-period-complex-january-2027",
            startDate: "2027-01-01",
            endDate: "2027-01-31",
            payday: "2027-01-01",
            nextPayday: "2027-02-01",
            payFrequency: .monthly,
            incomePence: 400000,
            status: .active,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let februaryPeriod = PayPeriod(
            id: "pay-period-complex-february-2027",
            startDate: "2027-02-01",
            endDate: "2027-02-28",
            payday: "2027-02-01",
            nextPayday: "2027-03-01",
            payFrequency: .monthly,
            incomePence: 400000,
            status: .planned,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let marchPeriod = PayPeriod(
            id: "pay-period-complex-march-2027",
            startDate: "2027-03-01",
            endDate: "2027-03-31",
            payday: "2027-03-01",
            nextPayday: "2027-04-01",
            payFrequency: .monthly,
            incomePence: 400000,
            status: .planned,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let paychecks = [
            Paycheck(id: "paycheck-complex-january-2027", payPeriodId: januaryPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 400000, actualAmountPence: 400000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-complex-february-2027", payPeriodId: februaryPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 400000, actualAmountPence: 400000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-complex-march-2027", payPeriodId: marchPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 400000, actualAmountPence: 400000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: [januaryPeriod, februaryPeriod, marchPeriod],
            paychecks: paychecks,
            potAllocations: [],
            transactions: [],
            debts: [],
            debtPayments: [],
            debtReserves: [],
            creditCards: cards,
            customPayments: [],
            creditCardRepayments: [],
            creditCardPots: [],
            dailyBriefs: []
        )
    }

    static var groupedComplexJanMar2027Snapshot: PlannerSnapshot {
        let seedCreatedAt = "2027-01-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = "2027-01-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(
                id: "card-cc1",
                name: "Barclays Rewards",
                provider: "Barclays Rewards",
                limitPence: 150000,
                openingBalancePence: 42000,
                openingStatementBalancePence: 42000,
                statementDate: "2026-12-06",
                designId: nil,
                dueDay: 3,
                dueDate: nil,
                color: "#2563eb",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc2",
                name: "Capital One",
                provider: "Capital One",
                limitPence: 70000,
                openingBalancePence: 26000,
                openingStatementBalancePence: 26000,
                statementDate: "2026-12-15",
                designId: nil,
                dueDay: 12,
                dueDate: nil,
                color: "#16a34a",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc3",
                name: "Zable",
                provider: "Zable",
                limitPence: 85000,
                openingBalancePence: 33000,
                openingStatementBalancePence: 0,
                statementDate: "2027-01-10",
                designId: nil,
                dueDay: 18,
                dueDate: nil,
                color: "#ea580c",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc4",
                name: "Aqua",
                provider: "Aqua",
                limitPence: 60000,
                openingBalancePence: 12500,
                openingStatementBalancePence: 12500,
                statementDate: "2026-12-20",
                designId: nil,
                dueDay: 25,
                dueDate: nil,
                color: "#7c3aed",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
            CreditCard(
                id: "card-cc5",
                name: "Jaja",
                provider: "Jaja",
                limitPence: 50000,
                openingBalancePence: 18000,
                openingStatementBalancePence: 18000,
                statementDate: "2026-12-24",
                designId: nil,
                dueDay: 28,
                dueDate: nil,
                color: "#0f766e",
                archived: false,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            ),
        ]

        let pots = [
            Pot(id: "pot-pot1", name: "Subscriptions & Digital", type: .reserved, category: "Subscriptions", icon: "phone", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot2", name: "Home & Utilities", type: .reserved, category: "Bills", icon: "house", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot3", name: "Food, Fuel & Travel", type: .reserved, category: "Spending", icon: "car", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot4", name: "Car & Work", type: .reserved, category: "Work", icon: "wrench", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: "card-cc4", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot5", name: "Annual & Irregular", type: .reserved, category: "Annual", icon: "target", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: "card-cc5", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot6", name: "Emergency Savings", type: .saving, category: "Emergency", icon: "wallet", balancePence: 0, targetPence: nil, color: "#0891b2", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot7", name: "Rent, Holiday & Buffer", type: .reserved, category: "Housing", icon: "home", balancePence: 0, targetPence: nil, color: "#be123c", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-bill-rent-board", name: "Rent / Board", amountPence: 65000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-chatgpt", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-work-software-bundle", name: "Work Software Bundle", amountPence: 1800, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-streaming-bundle", name: "Streaming Bundle", amountPence: 2800, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-cloud-storage", name: "Cloud Storage", amountPence: 900, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-phone-contract", name: "Phone Contract", amountPence: 4200, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-gym-direct-debit", name: "Gym Direct Debit", amountPence: 3600, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-home-insurance", name: "Home Insurance", amountPence: 11500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-council-rates", name: "Council Rates", amountPence: 12000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-electricity-top-up", name: "Electricity Top-Up", amountPence: 9500, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-broadband", name: "Broadband", amountPence: 3800, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries-big-shop-a", name: "Groceries Big Shop A", amountPence: 15000, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel-fill-a", name: "Fuel Fill A", amountPence: 7000, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries-big-shop-b", name: "Groceries Big Shop B", amountPence: 15000, dueDay: 24, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel-fill-b", name: "Fuel Fill B", amountPence: 7000, dueDay: 24, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-insurance", name: "Car Insurance", amountPence: 13000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-tools-workwear", name: "Tools / Workwear", amountPence: 5500, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-finance", name: "Car Finance", amountPence: 24000, dueDay: 25, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-website-hosting", name: "Website Hosting", amountPence: 4500, dueDay: 24, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-annual-renewals-fund", name: "Annual Renewals Fund", amountPence: 7500, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-emergency-fund-transfer", name: "Emergency Fund Transfer", amountPence: 8000, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot6", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-holiday-fund", name: "Holiday Fund", amountPence: 20000, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-road-tax", name: "Road Tax", amountPence: 21000, dueDay: nil, dueDate: "2027-01-28", frequency: .once, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-service", name: "Car Service", amountPence: 26000, dueDay: nil, dueDate: "2027-02-20", frequency: .once, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-apple-developer-fee", name: "Apple Developer Fee", amountPence: 9900, dueDay: nil, dueDate: "2027-03-05", frequency: .once, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-01-31", name: "Month-End Buffer Transfer", amountPence: 10000, dueDay: nil, dueDate: "2027-01-31", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-02-28", name: "Month-End Buffer Transfer", amountPence: 10000, dueDay: nil, dueDate: "2027-02-28", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-03-31", name: "Month-End Buffer Transfer", amountPence: 10000, dueDay: nil, dueDate: "2027-03-31", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let januaryPeriod = PayPeriod(
            id: "pay-period-grouped-january-2027",
            startDate: "2027-01-01",
            endDate: "2027-01-31",
            payday: "2027-01-01",
            nextPayday: "2027-02-01",
            payFrequency: .monthly,
            incomePence: 450000,
            status: .active,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let februaryPeriod = PayPeriod(
            id: "pay-period-grouped-february-2027",
            startDate: "2027-02-01",
            endDate: "2027-02-28",
            payday: "2027-02-01",
            nextPayday: "2027-03-01",
            payFrequency: .monthly,
            incomePence: 450000,
            status: .planned,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let marchPeriod = PayPeriod(
            id: "pay-period-grouped-march-2027",
            startDate: "2027-03-01",
            endDate: "2027-03-31",
            payday: "2027-03-01",
            nextPayday: "2027-04-01",
            payFrequency: .monthly,
            incomePence: 450000,
            status: .planned,
            createdAt: seedCreatedAt,
            updatedAt: seedCreatedAt,
            deletedAt: nil
        )
        let paychecks = [
            Paycheck(id: "paycheck-grouped-january-2027", payPeriodId: januaryPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 450000, actualAmountPence: 450000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-grouped-february-2027", payPeriodId: februaryPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 450000, actualAmountPence: 450000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-grouped-march-2027", payPeriodId: marchPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 450000, actualAmountPence: 450000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: [januaryPeriod, februaryPeriod, marchPeriod],
            paychecks: paychecks,
            potAllocations: [],
            transactions: [],
            debts: [],
            debtPayments: [],
            debtReserves: [],
            creditCards: cards,
            customPayments: [],
            creditCardRepayments: [],
            creditCardPots: [],
            dailyBriefs: []
        )
    }

    static var emptySnapshot: PlannerSnapshot {
        PlannerSnapshot(
            settings: defaultSettings,
            pots: [],
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

    static func migratedSnapshot(_ snapshot: PlannerSnapshot) -> (snapshot: PlannerSnapshot, didChange: Bool) {
        var migrated = snapshot
        let referencedPotIds = legacyReferencedPotIds(in: snapshot)
        let legacyPotsById = Dictionary(uniqueKeysWithValues: defaultPots.map { ($0.id, $0) })

        migrated.pots.removeAll { pot in
            guard let legacyPot = legacyPotsById[pot.id],
                  pot == legacyPot,
                  !referencedPotIds.contains(pot.id)
            else { return false }

            return true
        }

        return (migrated, migrated != snapshot)
    }

    private static func legacyReferencedPotIds(in snapshot: PlannerSnapshot) -> Set<String> {
        var ids = Set<String>()

        for payment in snapshot.recurringPayments {
            if let potId = payment.potId {
                ids.insert(potId)
            }
        }

        for allocation in snapshot.potAllocations {
            ids.insert(allocation.potId)
            if let fundingPotId = allocation.fundingPotId {
                ids.insert(fundingPotId)
            }
        }

        for transaction in snapshot.transactions {
            if let potId = transaction.potId {
                ids.insert(potId)
            }
        }

        return ids
    }
}
