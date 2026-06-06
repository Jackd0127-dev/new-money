import Foundation

enum MoneyParser {
    static func parsePoundsToPence(_ value: String) -> Int {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !normalized.isEmpty else { return 0 }

        let isNegative = normalized.hasPrefix("-")
        let unsigned = isNegative ? String(normalized.dropFirst()) : normalized
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count <= 2 else { return 0 }

        let poundsPart = String(parts.first ?? "0")
        guard let wholePounds = Int(poundsPart.isEmpty ? "0" : poundsPart) else {
            return 0
        }

        var penceDigits = parts.count == 2 ? String(parts[1]) : ""
        if penceDigits.count < 2 {
            penceDigits += String(repeating: "0", count: 2 - penceDigits.count)
        }
        penceDigits = String(penceDigits.prefix(2))

        guard let fractionalPence = Int(penceDigits.isEmpty ? "0" : penceDigits) else {
            return 0
        }

        let pence = wholePounds * 100 + fractionalPence
        return isNegative ? -pence : pence
    }

    static func formatPence(_ amountPence: Int, currency: Currency = .gbp) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = Locale(identifier: "en_GB")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(amountPence) / 100)) ?? "£0.00"
    }
}
