import Foundation

/// Parses the API's ISO-8601 timestamps and dates. Postgres sends an offset;
/// SQLite (tests) sends none, which the API treats as UTC.
enum APIDate {
    static func parse(_ raw: String?) -> Date? {
        guard var value = raw, !value.isEmpty else { return nil }
        if value.count == 10 { return dayFormatter.date(from: value) }
        value = normalizeFraction(value)
        if !(value.hasSuffix("Z") || value.dropFirst(19).contains("+") || value.dropFirst(19).contains("-")) {
            value += "Z"
        }
        return withFraction.date(from: value) ?? withoutFraction.date(from: value)
    }

    /// Python sends microseconds (".459667"); trim fractions to milliseconds for ISO8601DateFormatter.
    static func normalizeFraction(_ value: String) -> String {
        guard let dot = value.firstIndex(of: ".") else { return value }
        let afterDot = value[value.index(after: dot)...]
        let digits = afterDot.prefix(while: \.isNumber)
        let rest = afterDot.dropFirst(digits.count)
        let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return String(value[..<dot]) + "." + millis + rest
    }

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum Format {
    static func score(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func price(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        return fraction.formatted(.percent.precision(.fractionLength(1)))
    }

    /// Compact dollars: 12000000000 -> "$12B".
    static func dollars(_ value: Double?) -> String {
        guard let value else { return "–" }
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (size, suffix) in units where abs(value) >= size {
            return "$" + (value / size).formatted(.number.precision(.fractionLength(0...1))) + suffix
        }
        return "$" + value.formatted(.number.precision(.fractionLength(0)))
    }

    static func day(_ raw: String?) -> String {
        guard let date = APIDate.parse(raw) else { return raw ?? "–" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func relative(_ raw: String?, now: Date = .now) -> String {
        guard let date = APIDate.parse(raw) else { return "unknown" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
