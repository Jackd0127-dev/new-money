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
        cardRecurringPotReserveMigrationVersion: 1,
        cardRecurringAutoFundingRepairVersion: 1,
        includePotsInMoneyLeft: true,
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

    struct FullAppLogicTortureManualAction: Equatable, Sendable {
        var actionId: String
        var date: String
        var actionType: String
        var name: String
        var amountPence: Int
        var potId: String
        var cardId: String?
        var autoTickChecklist: Bool
        var expectedStatementRule: String
        var notes: String
    }

    struct FullAppLogicTortureRule: Equatable, Sendable {
        var rule: String
        var details: String
    }

    static let fullAppLogicTortureJulSep2027ManualActions: [FullAppLogicTortureManualAction] = [
        FullAppLogicTortureManualAction(actionId: "M1", date: "2027-07-02", actionType: "manual_card_spend", name: "Domain renewal", amountPence: 6400, potId: "pot-pot1", cardId: "card-cc1", autoTickChecklist: true, expectedStatementRule: "statement 2027-07-05; due 2027-08-02", notes: "Same day as CC1 direct debit; after old statement DD."),
        FullAppLogicTortureManualAction(actionId: "M2", date: "2027-07-05", actionType: "manual_card_spend", name: "App Store statement-day", amountPence: 1850, potId: "pot-pot1", cardId: "card-cc1", autoTickChecklist: true, expectedStatementRule: "statement 2027-07-05; due 2027-08-02", notes: "CC1 statement day; should be included in 5 Jul statement."),
        FullAppLogicTortureManualAction(actionId: "M3", date: "2027-07-10", actionType: "manual_card_spend", name: "Grocery add-on", amountPence: 4600, potId: "pot-pot3", cardId: "card-cc3", autoTickChecklist: true, expectedStatementRule: "statement 2027-07-10; due 2027-07-18", notes: "CC3 statement day; should be included in 10 Jul statement."),
        FullAppLogicTortureManualAction(actionId: "M4", date: "2027-07-15", actionType: "manual_card_spend", name: "Router replacement", amountPence: 8800, potId: "pot-pot2", cardId: "card-cc2", autoTickChecklist: true, expectedStatementRule: "statement 2027-07-15; due 2027-08-10", notes: "CC2 statement day; should be included in 15 Jul statement."),
        FullAppLogicTortureManualAction(actionId: "M5", date: "2027-07-27", actionType: "manual_card_spend", name: "Tyre repair", amountPence: 15000, potId: "pot-pot4", cardId: "card-cc4", autoTickChecklist: true, expectedStatementRule: "statement 2027-08-25; due 2027-08-27", notes: "Same day as CC4 DD; after statement day, should be next cycle."),
        FullAppLogicTortureManualAction(actionId: "M6", date: "2027-07-28", actionType: "manual_card_spend", name: "Travel bag", amountPence: 7200, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2027-08-01; due 2027-08-28", notes: "Same day as CC5 DD and Road Tax."),
        FullAppLogicTortureManualAction(actionId: "M7", date: "2027-08-01", actionType: "manual_card_spend", name: "Statement-day luggage fee", amountPence: 3500, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2027-08-01; due 2027-08-28", notes: "Payday and CC5 statement day; included in 1 Aug statement."),
        FullAppLogicTortureManualAction(actionId: "M8", date: "2027-08-10", actionType: "manual_card_spend", name: "Fuel extra", amountPence: 4000, potId: "pot-pot3", cardId: "card-cc3", autoTickChecklist: true, expectedStatementRule: "statement 2027-08-10; due 2027-08-18", notes: "CC3 statement day."),
        FullAppLogicTortureManualAction(actionId: "M9", date: "2027-08-25", actionType: "manual_card_spend", name: "Service extra", amountPence: 5500, potId: "pot-pot4", cardId: "card-cc4", autoTickChecklist: true, expectedStatementRule: "statement 2027-08-25; due 2027-08-27", notes: "CC4 statement day with MOT & Service."),
        FullAppLogicTortureManualAction(actionId: "M10", date: "2027-09-01", actionType: "manual_card_spend", name: "Statement-day renewal add-on", amountPence: 2250, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2027-09-01; due 2027-09-28", notes: "Payday and CC5 statement day."),
        FullAppLogicTortureManualAction(actionId: "M11", date: "2027-09-02", actionType: "manual_card_spend", name: "New month DD-day spend", amountPence: 2600, potId: "pot-pot1", cardId: "card-cc1", autoTickChecklist: true, expectedStatementRule: "statement 2027-09-05; due 2027-10-02", notes: "Same day as CC1 DD."),
        FullAppLogicTortureManualAction(actionId: "M12", date: "2027-09-15", actionType: "manual_card_spend", name: "Broadband install part", amountPence: 5500, potId: "pot-pot2", cardId: "card-cc2", autoTickChecklist: true, expectedStatementRule: "statement 2027-09-15; due 2027-10-10", notes: "CC2 statement day."),
    ]

    static let fullAppLogicTortureJulSep2027Rules: [FullAppLogicTortureRule] = [
        FullAppLogicTortureRule(rule: "event_order", details: "For each date: payday funding and tick; scheduled bills; manual actions; statement creation; direct debit card payments; end-of-day snapshot."),
        FullAppLogicTortureRule(rule: "payday_funding", details: "On the 1st, checklist contains all scheduled bill occurrences inside that calendar month, plus opening balances due in July only."),
        FullAppLogicTortureRule(rule: "manual_action_funding", details: "Manual action creates a same-day checklist item, auto-ticks it, reduces income, then immediately consumes the pot amount into card repayment reserve."),
        FullAppLogicTortureRule(rule: "card_statement_assignment", details: "If charge day <= statement day, charge goes on that month's statement. Otherwise it goes on next month's statement."),
        FullAppLogicTortureRule(rule: "card_due_assignment", details: "Due date is the first card due date after the statement date. If due_day <= statement_day, due month is next month."),
        FullAppLogicTortureRule(rule: "opening_statemented", details: "Funded on payday, stays in pot until DD due date, then pays from pot."),
        FullAppLogicTortureRule(rule: "opening_unstatemented", details: "Funded on payday, appears on specified statement date, then pays from pot on due date."),
        FullAppLogicTortureRule(rule: "card_bills", details: "On bill due date, pot target/balance decrease, card balance increases, card reserve increases, forecast decreases."),
        FullAppLogicTortureRule(rule: "direct_pot_bills", details: "On bill due date, pot target/balance decrease only. No card/reserve/statement."),
        FullAppLogicTortureRule(rule: "forecast", details: "Forecast remaining is only scheduled card-linked bills in the current pay month that have not yet charged. Manual spends are not forecast before action."),
    ]

    static var fullAppLogicTortureJulSep2027Snapshot: PlannerSnapshot {
        let seedCreatedAt = "2027-07-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = "2027-07-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(id: "card-cc1", name: "Barclays Rewards", provider: "Barclays Rewards", limitPence: 180000, openingBalancePence: 54000, openingStatementBalancePence: 54000, statementDate: "2027-06-05", designId: nil, dueDay: 2, dueDate: nil, color: "#2563eb", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc2", name: "Capital One", provider: "Capital One", limitPence: 90000, openingBalancePence: 27500, openingStatementBalancePence: 27500, statementDate: "2027-06-15", designId: nil, dueDay: 10, dueDate: nil, color: "#16a34a", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc3", name: "Zable", provider: "Zable", limitPence: 100000, openingBalancePence: 39000, openingStatementBalancePence: 0, statementDate: "2027-07-10", designId: nil, dueDay: 18, dueDate: nil, color: "#ea580c", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc4", name: "Aqua", provider: "Aqua", limitPence: 65000, openingBalancePence: 21000, openingStatementBalancePence: 21000, statementDate: "2027-06-25", designId: nil, dueDay: 27, dueDate: "2027-07-27", color: "#7c3aed", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc5", name: "Jaja", provider: "Jaja", limitPence: 55000, openingBalancePence: 13000, openingStatementBalancePence: 0, statementDate: "2027-07-01", designId: nil, dueDay: 28, dueDate: nil, color: "#0f766e", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let pots = [
            Pot(id: "pot-pot1", name: "Subscriptions", type: .reserved, category: "Subscriptions", icon: "phone", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot2", name: "Home & Utilities", type: .reserved, category: "Bills", icon: "house", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot3", name: "Food & Fuel", type: .reserved, category: "Spending", icon: "car", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot4", name: "Car & Work", type: .reserved, category: "Work", icon: "wrench", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: "card-cc4", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot5", name: "Annual & Irregular", type: .reserved, category: "Annual", icon: "target", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: "card-cc5", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot6", name: "Emergency Fund", type: .saving, category: "Emergency", icon: "wallet", balancePence: 0, targetPence: nil, color: "#0891b2", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot7", name: "Rent & Savings", type: .reserved, category: "Housing", icon: "home", balancePence: 0, targetPence: nil, color: "#be123c", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-bill-rent-board", name: "Rent / Board", amountPence: 90000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-chatgpt", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-cloud-storage", name: "Cloud Storage", amountPence: 900, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-streaming-bundle", name: "Streaming Bundle", amountPence: 3200, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-phone-contract", name: "Phone Contract", amountPence: 4400, dueDay: 12, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-gym-direct-debit", name: "Gym Direct Debit", amountPence: 3600, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-security-software-annual", name: "Security Software Annual", amountPence: 4800, dueDay: nil, dueDate: "2027-08-05", frequency: .once, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-home-insurance", name: "Home Insurance", amountPence: 12500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-council-rates", name: "Council Rates", amountPence: 15500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-electricity-top-up", name: "Electricity Top-Up", amountPence: 11500, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-broadband", name: "Broadband", amountPence: 4200, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-water-direct-debit", name: "Water Direct Debit", amountPence: 6000, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-tv-licence", name: "TV Licence", amountPence: 4700, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries-big-shop-a", name: "Groceries Big Shop A", amountPence: 17500, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel-fill-a", name: "Fuel Fill A", amountPence: 8000, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-travel-card-top-up", name: "Travel Card Top-Up", amountPence: 5500, dueDay: 18, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-pet-food", name: "Pet Food", amountPence: 7000, dueDay: nil, dueDate: "2027-07-07", frequency: .biweekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-groceries-big-shop-b", name: "Groceries Big Shop B", amountPence: 16500, dueDay: 24, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-fuel-fill-b", name: "Fuel Fill B", amountPence: 8000, dueDay: 24, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-insurance", name: "Car Insurance", amountPence: 14000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-work-tools", name: "Work Tools", amountPence: 6500, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-car-finance", name: "Car Finance", amountPence: 26000, dueDay: 27, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-mot-service", name: "MOT & Service", amountPence: 31000, dueDay: nil, dueDate: "2027-08-25", frequency: .once, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-parking-permit", name: "Parking Permit", amountPence: 9000, dueDay: nil, dueDate: "2027-09-27", frequency: .once, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-website-hosting", name: "Website Hosting", amountPence: 4500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-insurance-excess-fund", name: "Insurance Excess Fund", amountPence: 6000, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-annual-renewals-fund", name: "Annual Renewals Fund", amountPence: 8500, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-road-tax", name: "Road Tax", amountPence: 22000, dueDay: nil, dueDate: "2027-07-28", frequency: .once, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-apple-developer-fee", name: "Apple Developer Fee", amountPence: 9900, dueDay: nil, dueDate: "2027-08-01", frequency: .once, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-emergency-fund-transfer", name: "Emergency Fund Transfer", amountPence: 12500, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot6", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-savings-transfer", name: "Savings Transfer", amountPence: 25000, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-07-31", name: "Month-End Buffer Transfer", amountPence: 12500, dueDay: nil, dueDate: "2027-07-31", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-08-31", name: "Month-End Buffer Transfer", amountPence: 12500, dueDay: nil, dueDate: "2027-08-31", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-month-end-buffer-transfer-2027-09-30", name: "Month-End Buffer Transfer", amountPence: 12500, dueDay: nil, dueDate: "2027-09-30", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let julyPeriod = PayPeriod(id: "pay-period-full-app-july-2027", startDate: "2027-07-01", endDate: "2027-07-31", payday: "2027-07-01", nextPayday: "2027-08-01", payFrequency: .monthly, incomePence: 650000, status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil)
        let augustPeriod = PayPeriod(id: "pay-period-full-app-august-2027", startDate: "2027-08-01", endDate: "2027-08-31", payday: "2027-08-01", nextPayday: "2027-09-01", payFrequency: .monthly, incomePence: 650000, status: .planned, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil)
        let septemberPeriod = PayPeriod(id: "pay-period-full-app-september-2027", startDate: "2027-09-01", endDate: "2027-09-30", payday: "2027-09-01", nextPayday: "2027-10-01", payFrequency: .monthly, incomePence: 650000, status: .planned, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil)
        let paychecks = [
            Paycheck(id: "paycheck-full-app-july-2027", payPeriodId: julyPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 650000, actualAmountPence: 650000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-full-app-august-2027", payPeriodId: augustPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 650000, actualAmountPence: 650000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Paycheck(id: "paycheck-full-app-september-2027", payPeriodId: septemberPeriod.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: 650000, actualAmountPence: 650000, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: [julyPeriod, augustPeriod, septemberPeriod],
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

    static let finalDebtFullAppSimJanApr2028ManualActions: [FullAppLogicTortureManualAction] = [
        FullAppLogicTortureManualAction(actionId: "M1", date: "2028-01-02", actionType: "manual_card_spend", name: "Domain add-on", amountPence: 6400, potId: "pot-pot1", cardId: "card-cc1", autoTickChecklist: true, expectedStatementRule: "statement 2028-01-05; due 2028-02-02", notes: "Same day as CC1 old statement DD."),
        FullAppLogicTortureManualAction(actionId: "M2", date: "2028-01-05", actionType: "manual_card_spend", name: "App Store Statement-Day Spend", amountPence: 1850, potId: "pot-pot1", cardId: "card-cc1", autoTickChecklist: true, expectedStatementRule: "statement 2028-01-05; due 2028-02-02", notes: "CC1 statement day."),
        FullAppLogicTortureManualAction(actionId: "M3", date: "2028-01-10", actionType: "manual_card_spend", name: "Groceries Add-On", amountPence: 4600, potId: "pot-pot3", cardId: "card-cc3", autoTickChecklist: true, expectedStatementRule: "statement 2028-01-10; due 2028-01-18", notes: "CC3 statement day."),
        FullAppLogicTortureManualAction(actionId: "M4", date: "2028-01-15", actionType: "manual_card_spend", name: "Router Replacement", amountPence: 8800, potId: "pot-pot2", cardId: "card-cc2", autoTickChecklist: true, expectedStatementRule: "statement 2028-01-15; due 2028-02-10", notes: "CC2 statement day."),
        FullAppLogicTortureManualAction(actionId: "M5", date: "2028-01-20", actionType: "manual_debt_payment_now", name: "Friend IOU Part Payment", amountPence: 10000, potId: "pot-pot6", cardId: nil, autoTickChecklist: true, expectedStatementRule: "debt D5 manual payment", notes: "Manual-only debt payment."),
        FullAppLogicTortureManualAction(actionId: "M6", date: "2028-01-27", actionType: "manual_card_spend", name: "Tyre Repair", amountPence: 15000, potId: "pot-pot4", cardId: "card-cc4", autoTickChecklist: true, expectedStatementRule: "statement 2028-02-25; due 2028-02-27", notes: "Same day as CC4 DD."),
        FullAppLogicTortureManualAction(actionId: "M7", date: "2028-01-28", actionType: "manual_card_spend", name: "Travel Bag", amountPence: 7200, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2028-02-01; due 2028-02-28", notes: "Same day as CC5 DD and Road Tax."),
        FullAppLogicTortureManualAction(actionId: "M8", date: "2028-02-10", actionType: "manual_debt_set_aside", name: "Extra Debt Pot Set-Aside", amountPence: 5000, potId: "pot-pot6", cardId: nil, autoTickChecklist: true, expectedStatementRule: "set aside only", notes: "Set aside only; does not reduce debt balance."),
        FullAppLogicTortureManualAction(actionId: "M9", date: "2028-02-29", actionType: "manual_card_spend", name: "Leap-Day CC5 Add-On", amountPence: 3500, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2028-03-01; due 2028-03-28", notes: "Leap day/yearly bill stress."),
        FullAppLogicTortureManualAction(actionId: "M10", date: "2028-03-15", actionType: "manual_debt_payment_now", name: "Extra Credit Agreement Payment", amountPence: 20000, potId: "pot-pot6", cardId: nil, autoTickChecklist: true, expectedStatementRule: "finish earlier", notes: "APR debt extra payment."),
        FullAppLogicTortureManualAction(actionId: "M11", date: "2028-03-20", actionType: "manual_debt_payment_now", name: "Friend IOU Overpayment Attempt", amountPence: 20000, potId: "pot-pot6", cardId: nil, autoTickChecklist: true, expectedStatementRule: "cap to remaining balance", notes: "Should cap at remaining balance and not make debt negative."),
        FullAppLogicTortureManualAction(actionId: "M12", date: "2028-04-01", actionType: "manual_card_spend", name: "Statement-Day Renewal Add-On", amountPence: 2250, potId: "pot-pot5", cardId: "card-cc5", autoTickChecklist: true, expectedStatementRule: "statement 2028-04-01; due 2028-04-28", notes: "Payday and CC5 statement day."),
        FullAppLogicTortureManualAction(actionId: "M13", date: "2028-04-15", actionType: "manual_card_spend", name: "Broadband Install Part", amountPence: 5500, potId: "pot-pot2", cardId: "card-cc2", autoTickChecklist: true, expectedStatementRule: "statement 2028-04-15; due 2028-05-10", notes: "CC2 statement day."),
    ]

    static let finalDebtFullAppSimJanApr2028Rules: [FullAppLogicTortureRule] = [
        FullAppLogicTortureRule(rule: "Income windows", details: "Each income date funds obligations due until the day before the next income date. Multiple income entries on the same day are combined."),
        FullAppLogicTortureRule(rule: "Checklist same-day", details: "All generated checklist items are ticked immediately."),
        FullAppLogicTortureRule(rule: "Monthly day 31", details: "Monthly due day 31 clamps to month end in February and April."),
        FullAppLogicTortureRule(rule: "Bill frequencies", details: "Support once, weekly, biweekly, monthly, quarterly, and yearly exactly."),
        FullAppLogicTortureRule(rule: "Debt interest", details: "APR debts accrue estimated daily interest at start of day, rounded to nearest penny."),
        FullAppLogicTortureRule(rule: "Debt payments", details: "Payments reduce fees, interest, and principal conceptually; expected model reduces the debt balance by processed payment after interest accrues."),
        FullAppLogicTortureRule(rule: "Manual debt overpay", details: "Requested manual payment over balance is capped to remaining balance. Excess is reported but not deducted."),
        FullAppLogicTortureRule(rule: "Manual debt set-aside", details: "Adds money to Debt Repayments pot and does not reduce debt balance."),
        FullAppLogicTortureRule(rule: "Card statements", details: "Statement cutoff is end-of-day inclusive."),
        FullAppLogicTortureRule(rule: "Credit card DD", details: "Pays statement amount only and does not reduce income again."),
        FullAppLogicTortureRule(rule: "Debt is not credit card", details: "Debt payments must not affect card balances, card forecasts, or card statements."),
    ]

    static var finalDebtFullAppSimJanApr2028Snapshot: PlannerSnapshot {
        let seedCreatedAt = "2028-01-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.payFrequency = .custom
        settings.defaultPayPeriodDays = 7
        settings.appDateMode = .manual
        settings.manualTodayIso = "2028-01-01"
        settings.createdAt = seedCreatedAt
        settings.updatedAt = seedCreatedAt

        let cards = [
            CreditCard(id: "card-cc1", name: "Barclays Rewards", provider: "Barclays Rewards", limitPence: 150000, openingBalancePence: 32000, openingStatementBalancePence: 32000, statementDate: "2027-12-05", designId: nil, dueDay: 2, dueDate: nil, color: "#2563eb", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc2", name: "Capital One", provider: "Capital One", limitPence: 80000, openingBalancePence: 21000, openingStatementBalancePence: 21000, statementDate: "2027-12-15", designId: nil, dueDay: 10, dueDate: nil, color: "#16a34a", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc3", name: "Zable", provider: "Zable", limitPence: 90000, openingBalancePence: 26000, openingStatementBalancePence: 0, statementDate: "2028-01-10", designId: nil, dueDay: 18, dueDate: nil, color: "#ea580c", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc4", name: "Aqua", provider: "Aqua", limitPence: 50000, openingBalancePence: 9000, openingStatementBalancePence: 9000, statementDate: "2027-12-25", designId: nil, dueDay: 27, dueDate: nil, color: "#7c3aed", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            CreditCard(id: "card-cc5", name: "Jaja", provider: "Jaja", limitPence: 45000, openingBalancePence: 12000, openingStatementBalancePence: 0, statementDate: "2028-01-01", designId: nil, dueDay: 28, dueDate: nil, color: "#0f766e", archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let pots = [
            Pot(id: "pot-pot1", name: "Subscriptions", type: .reserved, category: "Subscriptions", icon: "phone", balancePence: 0, targetPence: nil, color: "#2563eb", linkedCreditCardId: "card-cc1", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot2", name: "Home & Utilities", type: .reserved, category: "Bills", icon: "house", balancePence: 0, targetPence: nil, color: "#16a34a", linkedCreditCardId: "card-cc2", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot3", name: "Food & Fuel", type: .reserved, category: "Spending", icon: "car", balancePence: 0, targetPence: nil, color: "#ea580c", linkedCreditCardId: "card-cc3", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot4", name: "Car & Work", type: .reserved, category: "Work", icon: "wrench", balancePence: 0, targetPence: nil, color: "#7c3aed", linkedCreditCardId: "card-cc4", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot5", name: "Annual & Irregular", type: .reserved, category: "Annual", icon: "target", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: "card-cc5", linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot6", name: "Debt Repayments", type: .reserved, category: "Debt", icon: "wallet", balancePence: 0, targetPence: nil, color: "#0891b2", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot7", name: "Emergency & Savings", type: .saving, category: "Emergency", icon: "savings", balancePence: 0, targetPence: nil, color: "#0f766e", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            Pot(id: "pot-pot8", name: "Rent & Core", type: .reserved, category: "Housing", icon: "home", balancePence: 0, targetPence: nil, color: "#be123c", linkedCreditCardId: nil, linkedDebtId: nil, archived: false, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let recurringPayments = [
            RecurringPayment(id: "rec-bill-b1", name: "Rent / Board", amountPence: 85000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot8", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b2", name: "Month-End Buffer Transfer", amountPence: 12500, dueDay: 31, dueDate: nil, frequency: .monthly, potId: "pot-pot8", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b3", name: "Emergency Fund Transfer", amountPence: 10000, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b4", name: "ChatGPT", amountPence: 7500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b5", name: "Cloud Storage", amountPence: 900, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b6", name: "Streaming Bundle", amountPence: 3200, dueDay: 5, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b7", name: "Phone Contract", amountPence: 4400, dueDay: 12, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b8", name: "Gym Direct Debit", amountPence: 3600, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot1", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b9", name: "Web Domain Renewal", amountPence: 9600, dueDay: nil, dueDate: "2028-01-05", frequency: .yearly, potId: "pot-pot1", creditCardId: "card-cc1", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b10", name: "Home Insurance", amountPence: 12500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b11", name: "Council Rates", amountPence: 15500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b12", name: "Electricity Top-Up", amountPence: 11500, dueDay: 10, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b13", name: "Broadband", amountPence: 4200, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b14", name: "Water Direct Debit", amountPence: 6000, dueDay: 15, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b15", name: "TV Licence", amountPence: 4700, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b16", name: "Quarterly Council Adjustment", amountPence: 21000, dueDay: nil, dueDate: "2028-03-15", frequency: .quarterly, potId: "pot-pot2", creditCardId: "card-cc2", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b17", name: "Groceries Weekly", amountPence: 9000, dueDay: nil, dueDate: "2028-01-03", frequency: .weekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b18", name: "Fuel Biweekly", amountPence: 7000, dueDay: nil, dueDate: "2028-01-04", frequency: .biweekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b19", name: "Travel Card Monthly", amountPence: 5500, dueDay: 18, dueDate: nil, frequency: .monthly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b20", name: "Pet Food Biweekly", amountPence: 3200, dueDay: nil, dueDate: "2028-01-11", frequency: .biweekly, potId: "pot-pot3", creditCardId: "card-cc3", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b21", name: "Car Insurance", amountPence: 14000, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b22", name: "Work Tools", amountPence: 6500, dueDay: 20, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b23", name: "Car Finance", amountPence: 26000, dueDay: 27, dueDate: nil, frequency: .monthly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b24", name: "Dental Bill", amountPence: 18000, dueDay: nil, dueDate: "2028-01-31", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b25", name: "Furniture Deposit", amountPence: 30000, dueDay: nil, dueDate: "2028-03-20", frequency: .once, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b26", name: "Business Insurance", amountPence: 22000, dueDay: nil, dueDate: "2028-01-01", frequency: .quarterly, potId: "pot-pot4", creditCardId: "card-cc4", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b27", name: "Website Hosting", amountPence: 4500, dueDay: 1, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b28", name: "Annual Renewals Fund", amountPence: 8500, dueDay: 28, dueDate: nil, frequency: .monthly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b29", name: "Road Tax", amountPence: 18000, dueDay: nil, dueDate: "2028-01-28", frequency: .quarterly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b30", name: "Apple Developer Fee", amountPence: 9900, dueDay: nil, dueDate: "2028-02-29", frequency: .yearly, potId: "pot-pot5", creditCardId: "card-cc5", priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
            RecurringPayment(id: "rec-bill-b31", name: "Passport Renewal", amountPence: 11000, dueDay: nil, dueDate: "2028-04-15", frequency: .once, potId: "pot-pot7", creditCardId: nil, priority: .essential, active: true, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil),
        ]

        let incomeWindows: [(String, String, Int)] = [
            ("2028-01-01", "2028-01-06", 320000), ("2028-01-07", "2028-01-13", 18000),
            ("2028-01-14", "2028-01-20", 61000), ("2028-01-21", "2028-01-27", 18000),
            ("2028-01-28", "2028-01-31", 61000), ("2028-02-01", "2028-02-03", 320000),
            ("2028-02-04", "2028-02-10", 18000), ("2028-02-11", "2028-02-17", 61000),
            ("2028-02-18", "2028-02-24", 18000), ("2028-02-25", "2028-02-28", 61000),
            ("2028-02-29", "2028-02-29", 75000), ("2028-03-01", "2028-03-02", 320000),
            ("2028-03-03", "2028-03-09", 18000), ("2028-03-10", "2028-03-16", 61000),
            ("2028-03-17", "2028-03-23", 18000), ("2028-03-24", "2028-03-30", 61000),
            ("2028-03-31", "2028-03-31", 18000), ("2028-04-01", "2028-04-06", 320000),
            ("2028-04-07", "2028-04-13", 61000), ("2028-04-14", "2028-04-14", 18000),
            ("2028-04-15", "2028-04-20", 75000), ("2028-04-21", "2028-04-27", 61000),
            ("2028-04-28", "2028-04-30", 18000),
        ]
        let payPeriods = incomeWindows.enumerated().map { index, window in
            PayPeriod(
                id: "pay-period-final-debt-\(window.0)",
                startDate: window.0,
                endDate: window.1,
                payday: window.0,
                nextPayday: index + 1 < incomeWindows.count ? incomeWindows[index + 1].0 : "2028-05-01",
                payFrequency: .custom,
                incomePence: window.2,
                status: index == 0 ? .active : .planned,
                createdAt: seedCreatedAt,
                updatedAt: seedCreatedAt,
                deletedAt: nil
            )
        }
        let paychecks = payPeriods.map {
            Paycheck(id: "paycheck-final-debt-\($0.payday)", payPeriodId: $0.id, hoursWorked: 0, hourlyRatePence: 0, calculatedAmountPence: $0.incomePence, actualAmountPence: $0.incomePence, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil)
        }

        let debts = [
            Debt(id: "debt-d1", name: "Family Loan", lender: "Family Loan", originalAmountPence: 100000, currentBalancePence: 100000, minimumPaymentPence: 0, dueDate: "2028-04-30", interestRateApr: nil, note: "No-interest auto spread.", status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil, type: .informal, startingBalancePence: 100000, targetPayoffDate: "2028-04-30", interestType: DebtInterestType.none, aprBasisPoints: nil, repaymentStrategy: .autoSpreadUntilDueDate, paymentFrequency: .monthly, paymentDay: 1),
            Debt(id: "debt-d2", name: "BNPL Laptop", lender: "BNPL Laptop", originalAmountPence: 39999, currentBalancePence: 39999, minimumPaymentPence: 0, dueDate: "2028-02-19", interestRateApr: nil, note: "Pay in 4, pennies split safely.", status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil, type: .bnpl, startingBalancePence: 39999, targetPayoffDate: "2028-02-19", interestType: DebtInterestType.none, aprBasisPoints: nil, repaymentStrategy: .payIn4, paymentFrequency: .fortnightly, paymentDay: nil, payFirstTiming: .customDate, customFirstPaymentDate: "2028-01-08"),
            Debt(id: "debt-d3", name: "Credit Agreement", lender: "Credit Agreement", originalAmountPence: 150000, currentBalancePence: 150000, minimumPaymentPence: 6000, dueDate: "2028-04-30", interestRateApr: 24.9, note: "APR debt, payment £140/month.", status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil, type: .creditAgreement, startingBalancePence: 150000, targetPayoffDate: "2028-04-30", interestType: .apr, aprBasisPoints: 2490, extraPaymentPence: 8000, repaymentStrategy: .minimumPlusExtra, paymentFrequency: .monthly, paymentDay: 15),
            Debt(id: "debt-d4", name: "Overdraft Cleanup", lender: "Overdraft Cleanup", originalAmountPence: 65000, currentBalancePence: 65000, minimumPaymentPence: 4000, dueDate: "2028-04-30", interestRateApr: 39.9, note: "High APR fixed biweekly payments.", status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil, type: .overdraft, startingBalancePence: 65000, targetPayoffDate: "2028-04-30", interestType: .apr, aprBasisPoints: 3990, extraPaymentPence: 8000, repaymentStrategy: .fixedPayment, paymentFrequency: .fortnightly, payFirstTiming: .customDate, customFirstPaymentDate: "2028-01-07"),
            Debt(id: "debt-d5", name: "Friend IOU", lender: "Friend IOU", originalAmountPence: 25000, currentBalancePence: 25000, minimumPaymentPence: 0, dueDate: "2028-04-20", interestRateApr: nil, note: "Manual-only debt with overpayment test.", status: .active, createdAt: seedCreatedAt, updatedAt: seedCreatedAt, deletedAt: nil, type: .informal, startingBalancePence: 25000, targetPayoffDate: "2028-04-20", interestType: DebtInterestType.none, aprBasisPoints: nil, repaymentStrategy: .manualOnly, paymentFrequency: .custom),
        ]

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: recurringPayments,
            payPeriods: payPeriods,
            paychecks: paychecks,
            potAllocations: [],
            transactions: [],
            debts: debts,
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

    static var debtDemoSnapshot: PlannerSnapshot {
        let now = "2026-07-01T00:00:00.000Z"
        var settings = defaultSettings
        settings.appDateMode = .manual
        settings.manualTodayIso = "2026-07-01"
        let period = PayPeriod(
            id: "period-debt-demo-july",
            startDate: "2026-07-01",
            endDate: "2026-07-31",
            payday: "2026-07-01",
            nextPayday: "2026-08-01",
            payFrequency: .monthly,
            incomePence: 250000,
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
        let familyDebt = Debt(
            id: "debt-demo-family",
            name: "Family loan",
            lender: "Family",
            originalAmountPence: 90000,
            currentBalancePence: 90000,
            minimumPaymentPence: 0,
            dueDate: "2026-09-30",
            interestRateApr: nil,
            note: "No-interest family loan",
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            type: .informal,
            startingBalancePence: 90000,
            targetPayoffDate: "2026-09-30",
            interestType: DebtInterestType.none,
            repaymentStrategy: .autoSpreadUntilDueDate,
            paymentFrequency: .monthly,
            paymentDay: 1
        )
        let payIn4Debt = Debt(
            id: "debt-demo-pay-in-4",
            name: "Pay in 4 purchase",
            lender: "BNPL",
            originalAmountPence: 40000,
            currentBalancePence: 40000,
            minimumPaymentPence: 0,
            dueDate: "2026-10-01",
            interestRateApr: nil,
            note: "Four equal payments",
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            type: .bnpl,
            startingBalancePence: 40000,
            targetPayoffDate: "2026-10-01",
            interestType: DebtInterestType.none,
            repaymentStrategy: .payIn4,
            paymentFrequency: .monthly,
            payFirstTiming: .nextPayday
        )
        let aprDebt = Debt(
            id: "debt-demo-apr",
            name: "APR loan",
            lender: "Personal Loan",
            originalAmountPence: 120000,
            currentBalancePence: 120000,
            minimumPaymentPence: 5000,
            dueDate: "",
            interestRateApr: 24.9,
            note: "24.9% APR with extra payments",
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            type: .personalLoan,
            startingBalancePence: 120000,
            targetPayoffDate: nil,
            interestType: .apr,
            aprBasisPoints: 2490,
            extraPaymentPence: 7500,
            repaymentStrategy: .minimumPlusExtra,
            paymentFrequency: .monthly,
            paymentDay: 15
        )
        let manualDebt = Debt(
            id: "debt-demo-manual",
            name: "Manual IOU",
            lender: "Friend",
            originalAmountPence: 25000,
            currentBalancePence: 25000,
            minimumPaymentPence: 0,
            dueDate: "",
            interestRateApr: nil,
            note: "Manual-only repayment",
            status: .active,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            type: .informal,
            startingBalancePence: 25000,
            targetPayoffDate: nil,
            interestType: DebtInterestType.none,
            repaymentStrategy: .manualOnly,
            paymentFrequency: .monthly
        )
        let debts = [familyDebt, payIn4Debt, aprDebt, manualDebt]
        let pots = debts.map {
            Pot(
                id: "pot-\($0.id)",
                name: "\($0.name) pot",
                type: .reserved,
                category: "Debts",
                icon: nil,
                balancePence: 0,
                targetPence: nil,
                color: "#f97316",
                linkedCreditCardId: nil,
                linkedDebtId: $0.id,
                archived: false,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
        }
        let scheduleItems = debts.flatMap {
            DebtPlannerEngine.generateSchedule(for: $0, payPeriods: [period], today: "2026-07-01")
        }

        return PlannerSnapshot(
            settings: settings,
            pots: pots,
            recurringPayments: [],
            payPeriods: [period],
            paychecks: [],
            potAllocations: [],
            transactions: [],
            debts: debts,
            debtPayments: [],
            debtReserves: [],
            debtPaymentScheduleItems: scheduleItems,
            debtSnapshots: [],
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
        let legacyPotsById = defaultPots.reduce(into: [String: Pot]()) { result, pot in
            result[pot.id] = pot
        }

        migrated.pots.removeAll { pot in
            guard let legacyPot = legacyPotsById[pot.id],
                  pot == legacyPot,
                  !referencedPotIds.contains(pot.id)
            else { return false }

            return true
        }

        normalizeMonthlyPayPeriods(in: &migrated)
        repairUnsettledRecurringCardBillReserves(in: &migrated)
        repairKnownAutomaticCardBillFunding(in: &migrated)

        return (migrated, migrated != snapshot)
    }

    private static func normalizeMonthlyPayPeriods(in snapshot: inout PlannerSnapshot) {
        let recordedPeriodIds = Set(snapshot.paychecks
            .filter { $0.deletedAt == nil }
            .map(\.payPeriodId))
        let orderedIndices = snapshot.payPeriods.indices.sorted {
            snapshot.payPeriods[$0].payday < snapshot.payPeriods[$1].payday
        }
        var currentMonthlyAnchorDay: Int?

        for index in orderedIndices {
            let frequency = snapshot.payPeriods[index].payFrequency ?? snapshot.settings.payFrequency
            guard frequency == .monthly else { continue }

            let enteredDay = FinanceEngine.dayOfMonth(snapshot.payPeriods[index].payday)
            if recordedPeriodIds.contains(snapshot.payPeriods[index].id) {
                currentMonthlyAnchorDay = snapshot.payPeriods[index].monthlyAnchorDay ?? enteredDay
            } else if let storedAnchor = snapshot.payPeriods[index].monthlyAnchorDay {
                currentMonthlyAnchorDay = storedAnchor
            } else if currentMonthlyAnchorDay == nil {
                currentMonthlyAnchorDay = enteredDay
            }

            let anchorDay = currentMonthlyAnchorDay ?? enteredDay
            let dates = FinanceEngine.createNextPayPeriod(
                payday: snapshot.payPeriods[index].payday,
                frequency: .monthly,
                monthlyAnchorDay: anchorDay
            )
            snapshot.payPeriods[index].startDate = dates.startDate
            snapshot.payPeriods[index].endDate = dates.endDate
            snapshot.payPeriods[index].nextPayday = dates.nextPayday
            snapshot.payPeriods[index].payFrequency = .monthly
            snapshot.payPeriods[index].monthlyAnchorDay = anchorDay
        }
    }

    /// Removes the single, confirmed automatic funding record created for the
    /// Vitamins Zable card charge on 11 July 2026. The charge remains on the
    /// card; only the erroneous pot reserve and funding allocation are undone.
    private static func repairKnownAutomaticCardBillFunding(in snapshot: inout PlannerSnapshot) {
        let allocationID = "recurring-bill-funding-allocation-recurring-dd0df7dd-f274-4902-8109-515c02762ca9-2026-07-11-pay-period-2026-07-01"
        let paymentID = "recurring-dd0df7dd-f274-4902-8109-515c02762ca9"
        let potID = "pot-4b7c6b1d-e5e8-4704-9d6b-e0a7243acbc9"
        let cardID = "card-6747ab5b-82d1-4ccb-a3cc-3cc0dd0ad309"
        let dueDate = "2026-07-11"

        if let allocationIndex = snapshot.potAllocations.firstIndex(where: {
            $0.id == allocationID &&
            $0.deletedAt == nil &&
            $0.potId == potID &&
            $0.creditCardId == cardID &&
            $0.recurringPaymentId == paymentID &&
            $0.recurringDueDate == dueDate &&
            $0.amountPence == 2_212 &&
            $0.userConfirmed != true
        }) {
            let allocation = snapshot.potAllocations.remove(at: allocationIndex)
            if let potIndex = snapshot.pots.firstIndex(where: { $0.id == potID && !$0.archived }) {
                snapshot.pots[potIndex].balancePence = max(0, snapshot.pots[potIndex].balancePence - allocation.amountPence)
                snapshot.pots[potIndex].updatedAt = DateUtilities.nowIsoString()
            }

            for transactionIndex in snapshot.transactions.indices where
                snapshot.transactions[transactionIndex].deletedAt == nil &&
                snapshot.transactions[transactionIndex].type == .spending &&
                snapshot.transactions[transactionIndex].paymentMethod == .creditCard &&
                snapshot.transactions[transactionIndex].creditCardId == cardID &&
                snapshot.transactions[transactionIndex].recurringPaymentId == paymentID &&
                snapshot.transactions[transactionIndex].date == dueDate &&
                snapshot.transactions[transactionIndex].potId == potID
            {
                snapshot.transactions[transactionIndex].potId = nil
                snapshot.transactions[transactionIndex].updatedAt = DateUtilities.nowIsoString()
            }
        }

        // Some cached cloud documents already include the marker without the
        // correction. Always use the exact allocation fingerprint above as the
        // authority, then leave a marker once it is no longer present.
        snapshot.settings.cardRecurringAutoFundingRepairVersion = 1
    }

    /// Before version 1, posting a funded recurring card bill removed its cash from the
    /// linked pot immediately. Restore that cash only when the matching card charge has
    /// not yet been included in a statement repayment.
    private static func repairUnsettledRecurringCardBillReserves(in snapshot: inout PlannerSnapshot) {
        guard (snapshot.settings.cardRecurringPotReserveMigrationVersion ?? 0) < 1 else { return }

        for allocation in snapshot.potAllocations where
            allocation.deletedAt == nil &&
            (allocation.source == .recurringBillFunding || allocation.source == .cardBillFunding) &&
            allocation.amountPence > 0 &&
            allocation.recurringPaymentId != nil &&
            allocation.recurringDueDate != nil
        {
            guard let paymentId = allocation.recurringPaymentId,
                  let dueDate = allocation.recurringDueDate,
                  let transaction = snapshot.transactions.first(where: {
                      $0.deletedAt == nil &&
                      $0.type == .spending &&
                      $0.paymentMethod == .creditCard &&
                      $0.recurringPaymentId == paymentId &&
                      $0.date == dueDate &&
                      $0.potId == allocation.potId
                  }),
                  let cardId = transaction.creditCardId ?? allocation.creditCardId,
                  !hasStatementRepaymentSettling(cardId: cardId, chargeDate: dueDate, in: snapshot),
                  let potIndex = snapshot.pots.firstIndex(where: { $0.id == allocation.potId && !$0.archived })
            else { continue }

            snapshot.pots[potIndex].balancePence += allocation.amountPence
            snapshot.pots[potIndex].updatedAt = allocation.updatedAt
        }

        snapshot.settings.cardRecurringPotReserveMigrationVersion = 1
    }

    private static func hasStatementRepaymentSettling(cardId: String, chargeDate: String, in snapshot: PlannerSnapshot) -> Bool {
        snapshot.creditCardRepayments.contains { repayment in
            guard repayment.deletedAt == nil,
                  repayment.creditCardId == cardId,
                  repayment.amountPence > 0
            else { return false }

            let statementDate = repayment.statementDate ?? repayment.date
            return statementDate >= chargeDate
        }
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
