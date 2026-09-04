import Foundation

enum AssistantLocalResponseBuilder {
    static func response(
        to prompt: String,
        snapshot: PlannerSnapshot,
        selectedPayPeriod: PayPeriod?
    ) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: String

        if isGreeting(trimmedPrompt) {
            response = "Hi. Ask me about your money left, income, payday, bills, cards, or debts."
        } else if matches(trimmedPrompt, phrases: ["credit card", "card balance", "cards", "credit"]) {
            response = cardsResponse(snapshot: snapshot)
        } else if matches(trimmedPrompt, phrases: ["debt", "loan", "owe", "repayment"]) {
            response = debtsResponse(snapshot: snapshot)
        } else if matches(trimmedPrompt, phrases: ["bill", "subscription", "direct debit"]) {
            response = billsResponse(snapshot: snapshot)
        } else if matches(trimmedPrompt, phrases: ["money left", "spendable", "balance", "how much money", "cash"]) {
            let currentMoney = PlannerDerivedData.currentTotalMoneyPence(
                snapshot: snapshot,
                payPeriod: selectedPayPeriod
            )
            response = "Your current money total is \(MoneyParser.formatPence(currentMoney))."
        } else if matches(trimmedPrompt, phrases: ["income", "payday", "pay check", "paycheck", "paid"]) {
            response = incomeResponse(for: selectedPayPeriod)
        } else {
            let currentMoney = PlannerDerivedData.currentTotalMoneyPence(
                snapshot: snapshot,
                payPeriod: selectedPayPeriod
            )
            let activeBills = snapshot.recurringPayments.count { $0.active && $0.deletedAt == nil }
            response = "I can answer only about the saved planner. From your planner, you currently have \(MoneyParser.formatPence(currentMoney)) total money and \(activeBills) active bill\(activeBills == 1 ? "" : "s"). Ask me about money left, income, payday, bills, cards, or debts for a more specific answer."
        }

        return applyResponseStyle(response, style: snapshot.settings.assistantResponseStyle ?? .straightToThePoint)
    }

    private static func isGreeting(_ prompt: String) -> Bool {
        let normalized = prompt.lowercased()
        return ["hi", "hello", "hey", "hiya"].contains(normalized)
    }

    private static func matches(_ prompt: String, phrases: [String]) -> Bool {
        phrases.contains { prompt.localizedStandardContains($0) }
    }

    private static func incomeResponse(for period: PayPeriod?) -> String {
        guard let period else {
            return "There is no current pay period yet. Add income to create one."
        }

        let payday = FinanceEngine.parseDate(period.payday)
            .formatted(.dateTime.day().month(.abbreviated))
        return "The current plan has \(MoneyParser.formatPence(period.incomePence)) income, with payday on \(payday)."
    }

    private static func billsResponse(snapshot: PlannerSnapshot) -> String {
        let activeBills = snapshot.recurringPayments.filter { $0.active && $0.deletedAt == nil }
        let templateTotal = activeBills.reduce(0) { $0 + $1.amountPence }
        return "You have \(activeBills.count) active bill\(activeBills.count == 1 ? "" : "s"). Their saved payment amounts total \(MoneyParser.formatPence(templateTotal)); frequencies can vary."
    }

    private static func cardsResponse(snapshot: PlannerSnapshot) -> String {
        let activeCards = snapshot.creditCards.filter { !$0.archived && $0.deletedAt == nil }
        let totalBalance = activeCards.reduce(0) {
            $0 + PlannerDerivedData.cardBalance(card: $1, snapshot: snapshot)
        }
        return "You have \(activeCards.count) active card\(activeCards.count == 1 ? "" : "s") with a combined current balance of \(MoneyParser.formatPence(totalBalance))."
    }

    private static func debtsResponse(snapshot: PlannerSnapshot) -> String {
        let activeDebts = snapshot.debts.filter {
            $0.deletedAt == nil && $0.status.isActiveLike && $0.currentBalancePence > 0
        }
        let totalBalance = activeDebts.reduce(0) { $0 + $1.currentBalancePence }
        return "You have \(activeDebts.count) active debt\(activeDebts.count == 1 ? "" : "s") with \(MoneyParser.formatPence(totalBalance)) remaining."
    }

    private static func applyResponseStyle(_ response: String, style: AssistantResponseStyle) -> String {
        switch style {
        case .straightToThePoint:
            response
        case .affirmative:
            "Absolutely. \(response)"
        case .enthusiastic:
            "Good question. \(response)"
        case .friendly:
            "Of course. \(response)"
        case .flirty:
            "I've got you. \(response)"
        }
    }
}
