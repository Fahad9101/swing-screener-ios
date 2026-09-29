import Foundation

// Codable mirrors of the SOE API (https://github.com/Fahad9101/swing-opportunity-engine).
// Keys arrive in snake_case and are decoded with `.convertFromSnakeCase`.
// Timestamps stay as strings and are parsed for display by `APIDate`.

/// Fields every screen shows so stale data is never silent.
protocol Freshness {
    var dataAsOf: String? { get }
    var stale: Bool { get }
}

struct ShortlistResponse: Decodable, Freshness {
    let scanRunId: String?
    let dataAsOf: String?
    let stale: Bool
    let count: Int
    let data: [Opportunity]
}

struct Opportunity: Decodable, Identifiable, Hashable {
    var id: String { ticker }
    let ticker: String
    let company: String
    let sector: String?
    let isBiotech: Bool
    let price: Double?
    let marketCap: Double?
    let primaryScanner: String
    let secondaryScanners: [String]
    let scores: ScoreBreakdown
    let marketRegime: String?
    let penalties: [Penalty]
    let automaticRejections: [String]
}

struct ScoreBreakdown: Decodable, Hashable {
    let catalyst: ScoreComponent
    let fundamental: ScoreComponent
    let valuation: ScoreComponent
    let technical: ScoreComponent
    let revisions: ScoreComponent
    let balanceSheet: ScoreComponent
    let liquidity: ScoreComponent
    let baseOpportunityScore: Double
    let penaltyPoints: Int
    let multiScannerBonus: Int
    let opportunityScore: Double

    /// Components in display order, with their labels.
    var rows: [ScoreRow] {
        [ScoreRow(label: "Catalyst", component: catalyst), ScoreRow(label: "Fundamentals", component: fundamental),
         ScoreRow(label: "Valuation", component: valuation), ScoreRow(label: "Technical", component: technical),
         ScoreRow(label: "Revisions", component: revisions), ScoreRow(label: "Balance sheet", component: balanceSheet),
         ScoreRow(label: "Liquidity", component: liquidity)]
    }
}

struct ScoreRow: Identifiable, Hashable {
    var id: String { label }
    let label: String
    let component: ScoreComponent
}

struct ScoreComponent: Decodable, Hashable {
    let score: Double?
    let maximum: Double
    let available: Bool
}

struct Penalty: Decodable, Hashable {
    let code: String
    let reason: String
    let points: Int
}

struct DataCompleteness: Decodable, Hashable {
    let overallPct: Double?
    let availability: [String: String]
    let missingFields: [String: [String]]
}

struct CatalystEvent: Decodable, Identifiable, Hashable {
    var id: String { [ticker, kind, type, eventDate ?? windowStart ?? "", title].joined(separator: "|") }
    let ticker: String
    let kind: String
    let type: String
    let title: String
    let eventDate: String?
    let windowStart: String?
    let windowEnd: String?
    let timing: String?
    let status: CatalystStatus
    let dateConfidence: String?
    let verified: Bool
    let source: String
    let sourceUrl: String?
    let lastChecked: String?
    let stale: Bool
    let summary: String?

    /// The day the event sorts and groups under: its date, or the start of its estimated window.
    var day: String? { eventDate ?? windowStart }
}

enum CatalystStatus: String, Decodable, Hashable {
    case confirmed, estimated, speculative

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CatalystStatus(rawValue: raw) ?? .speculative
    }
}

struct CatalystCalendarResponse: Decodable, Freshness {
    let dataAsOf: String?
    let stale: Bool
    let disclaimer: String
    let count: Int
    let data: [CatalystEvent]
}

struct TickerCard: Decodable, Freshness {
    let dataAsOf: String?
    let stale: Bool
    let ticker: String
    let disclaimer: String
    let company: String?
    let exchange: String?
    let sector: String?
    let industry: String?
    let marketCap: Double?
    let isBiotech: Bool
    let onShortlist: Bool
    let opportunityScore: Double?
    let scoreBreakdown: ScoreBreakdown?
    let dataCompleteness: DataCompleteness?
    let scanners: [ScannerResult]
    let catalysts: [CatalystEvent]
    let redFlags: [RedFlag]
    let market: Snapshot<MarketData>?
}

struct ScannerResult: Decodable, Hashable, Identifiable {
    var id: String { scanner }
    let scanner: String
    let qualified: Bool
    let conditionsMet: Int
    let conditionsTotal: Int
}

struct RedFlag: Decodable, Hashable, Identifiable {
    var id: String { kind + code }
    let kind: String
    let code: String
    let message: String
    let points: Int?
}

struct Snapshot<T: Decodable & Hashable>: Decodable, Hashable {
    let source: String
    let asOf: String
    let fetchedAt: String
    let stale: Bool
    let data: T
}

struct MarketData: Decodable, Hashable {
    let price: Double?
    let sma20: Double?
    let sma50: Double?
    let sma200: Double?
    let rsi14: Double?
    let atr14: Double?
    let high52w: Double?
    let low52w: Double?
    let avgDollarVolume20d: Double?
    let return20d: Double?
    let relativeVolume: Double?
}

struct APIErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String
        let message: String
        let retryable: Bool
    }
    let error: Body
}

enum ScannerName {
    /// Human names for SOE scanner codes.
    static func label(_ code: String) -> String {
        switch code {
        case "RERATING": return "Re-rating"
        case "GROWTH_PULLBACK": return "Growth pullback"
        case "BIOTECH_CATALYST": return "Biotech catalyst"
        default: return code.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
