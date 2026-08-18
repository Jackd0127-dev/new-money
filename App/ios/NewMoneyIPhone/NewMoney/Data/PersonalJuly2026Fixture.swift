import Foundation

/// Debug-only, in-memory QA data. This file is intentionally excluded from Release compilation.
#if DEBUG
enum PersonalJuly2026Fixture {
    static let fixtureValue = "personal-july-2026"
    static let scenarioKey = "MONEYAPP_SCENARIO"
    static let phaseKey = "MONEYAPP_SCENARIO_PHASE"
    static let scenarioValue = "PersonalJuly2026"
    static let payPeriodId = "personal-july-2026"
    static let iCloudBillId = "bill-icloud"
    static let runnaBillId = "bill-runna"
    static let appleCareBillId = "bill-apple-care"
    static let aquaCardId = "card-aqua"
    static let aquaOpeningDueDate = "2026-07-20"

    enum Phase: String {
        case beforeICloud = "BeforeICloud"
        case afterICloud = "AfterICloud"

        var fixedTodayIso: String {
            switch self {
            case .beforeICloud: "2026-07-09"
            case .afterICloud: "2026-07-10"
            }
        }
    }

    static func phase(environment: [String: String] = ProcessInfo.processInfo.environment) -> Phase {
        Phase(rawValue: environment[phaseKey] ?? "") ?? .beforeICloud
    }

    static var isActive: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment[PlannerLaunchProfile.fixtureEnvironmentKey] == fixtureValue &&
            environment[scenarioKey] == scenarioValue
    }

    /// The base snapshot is deliberately immutable. Every QA launch receives a fresh in-memory copy.
    static func snapshot(phase: Phase = .beforeICloud) -> PlannerSnapshot {
        let createdAt = "2026-07-09T12:00:00.000+01:00"
        var settings = DefaultData.defaultSettings
        settings.payFrequency = .monthly
        settings.defaultPayPeriodDays = 31
        settings.appDateMode = .manual
        settings.manualTodayIso = phase.fixedTodayIso
        settings.createdAt = createdAt
        settings.updatedAt = createdAt

        let july = PayPeriod(id: payPeriodId, startDate: "2026-07-01", endDate: "2026-07-31", payday: "2026-07-01", nextPayday: "2026-08-01", payFrequency: .monthly, incomePence: 0, status: .active, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)
        let initialIncome = OneOffIncome(id: "personal-july-2026-initial-income", payPeriodId: july.id, name: "Initial/current-period income", amountPence: 340_663, date: "2026-07-09", note: "Onboarding current-period income; not a generated paycheck.", createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)

        let cards = [
            card("card-barclays", "Barclays", 80_000, 64_544, nil, "2026-06-11", 6, createdAt),
            card("card-capital-one", "Capital One", 55_000, 20_237, nil, "2026-06-09", 2, createdAt),
            card("card-jaja", "Jaja", 25_000, 21_580, 21_580, "2026-07-07", 3, createdAt),
            card("card-zable", "Zable", 50_000, 0, nil, "2026-06-24", 1, createdAt),
            // A 21 June statement and payment day 20 produces the supplied 20 July opening obligation.
            card(aquaCardId, "Aqua", 130_000, 31_430, 12_843, "2026-06-21", 20, createdAt),
        ]
        let pots = [
            pot("pot-insurance", "Insurance", 0, nil, createdAt),
            pot("pot-jaja", "Jaja", 21_580, "card-jaja", createdAt),
            pot("pot-capital-one", "Capital One", 8_079, "card-capital-one", createdAt),
            pot("pot-zable", "Zable", 0, "card-zable", createdAt),
            // Opening values; the QA loader performs the four real checklist actions.
            pot("pot-barclays", "Barclays", 50_685, "card-barclays", createdAt),
            pot("pot-aqua", "Aqua", 17_888, aquaCardId, createdAt),
        ]
        let bills = [
            bill(appleCareBillId, "Apple Care", 899, 19, "pot-barclays", "card-barclays", createdAt),
            bill("bill-car-insurance", "Car insurance", 8_711, 1, "pot-insurance", nil, createdAt),
            bill(iCloudBillId, "iCloud+", 899, 10, "pot-barclays", "card-barclays", createdAt),
            bill("bill-chatgpt", "ChatGPT", 8_900, 7, "pot-barclays", "card-barclays", createdAt),
            bill("bill-gym", "Gym", 2_299, 1, "pot-aqua", "card-aqua", createdAt),
            bill(runnaBillId, "Runna", 1_599, 18, "pot-barclays", "card-barclays", createdAt),
            bill("bill-skin-me", "Skin+Me", 2_499, 1, "pot-barclays", "card-barclays", createdAt),
        ]
        // These are explicit source obligations. They are not derived totals.
        let aquaCurrent = CustomPayment(id: "aqua-current-2026-08-20", name: "Aqua current target", amountPence: 31_430, dueDate: "2026-08-20", creditCardId: "card-aqua", status: .unpaid, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)

        return PlannerSnapshot(settings: settings, pots: pots, recurringPayments: bills, payPeriods: [july], paychecks: [], potAllocations: [], transactions: [], debts: [], debtPayments: [], debtReserves: [], creditCards: cards, customPayments: [aquaCurrent], creditCardRepayments: [], creditCardPots: [], dailyBriefs: [], oneOffIncomes: [initialIncome])
    }

    private static func card(_ id: String, _ name: String, _ limit: Int, _ balance: Int, _ statement: Int?, _ statementDate: String, _ dueDay: Int, _ createdAt: String) -> CreditCard {
        CreditCard(id: id, name: name, provider: name, limitPence: limit, openingBalancePence: balance, openingStatementBalancePence: statement, statementDate: statementDate, designId: nil, dueDay: dueDay, dueDate: nil, color: "#2563EB", archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)
    }

    private static func pot(_ id: String, _ name: String, _ balance: Int, _ cardId: String?, _ createdAt: String) -> Pot {
        Pot(id: id, name: name, type: .reserved, category: "Cards", icon: "creditcard", balancePence: balance, targetPence: nil, color: "#2563EB", linkedCreditCardId: cardId, linkedDebtId: nil, archived: false, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)
    }

    private static func bill(_ id: String, _ name: String, _ amount: Int, _ dueDay: Int, _ potId: String, _ cardId: String?, _ createdAt: String) -> RecurringPayment {
        RecurringPayment(id: id, name: name, amountPence: amount, dueDay: dueDay, dueDate: nil, frequency: .monthly, potId: potId, creditCardId: cardId, priority: .essential, active: true, createdAt: createdAt, updatedAt: createdAt, deletedAt: nil)
    }
}
#endif
