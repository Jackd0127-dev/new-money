import Foundation

enum MoneyParser {
    static func parsePoundsToPence(_ value: String) -> Int {
        pence(from: value) ?? 0
    }

    /// Parses an exact GBP amount without treating invalid input as a zero balance.
    /// The compatibility entry point above remains available to existing forms.
    static func pence(from value: String) -> Int? {
        var normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        let hasLeadingCurrency = normalized.hasPrefix("£")
        if hasLeadingCurrency { normalized.removeFirst() }
        let isNegative = normalized.hasPrefix("-")
        if isNegative { normalized.removeFirst() }
        if !hasLeadingCurrency, normalized.hasPrefix("£") { normalized.removeFirst() }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !normalized.isEmpty else { return nil }
        let poundsPart = String(parts[0])
        let fraction = parts.count == 2 ? String(parts[1]) : ""
        let isDigits: (String) -> Bool = { !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }
        guard fraction.isEmpty || isDigits(fraction), fraction.count <= 2,
              !poundsPart.isEmpty || !fraction.isEmpty
        else { return nil }

        let groups = poundsPart.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        if groups.count > 1 {
            guard (1...3).contains(groups[0].count), groups.allSatisfy(isDigits),
                  groups.dropFirst().allSatisfy({ $0.count == 3 })
            else { return nil }
        } else if !poundsPart.isEmpty, !isDigits(poundsPart) {
            return nil
        }
        guard let wholePounds = Int(poundsPart.isEmpty ? "0" : groups.joined()) else { return nil }
        let fractionalPence = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        let whole = wholePounds.multipliedReportingOverflow(by: 100)
        guard !whole.overflow else { return nil }
        let total = whole.partialValue.addingReportingOverflow(fractionalPence)
        guard !total.overflow else { return nil }
        return isNegative ? -total.partialValue : total.partialValue
    }

    static func formatPence(_ amountPence: Int, currency: Currency = .gbp) -> String {
        (Decimal(amountPence) / 100).formatted(
            .currency(code: currency.rawValue)
                .locale(Locale(identifier: "en_GB"))
                .precision(.fractionLength(2))
        )
    }
}
