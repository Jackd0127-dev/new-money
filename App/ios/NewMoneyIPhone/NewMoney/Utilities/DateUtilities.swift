import Foundation

enum DateUtilities {
    private static func makeIsoDateTimeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static func nowIsoString() -> String {
        makeIsoDateTimeFormatter().string(from: Date())
    }

    static func newId(prefix: String) -> String {
        "\(prefix)-\(UUID().uuidString.lowercased())"
    }
}
