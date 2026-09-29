import SwiftUI

@Observable
@MainActor
final class TickerDetailModel {
    let symbol: String
    var state: LoadState<TickerCard> = .idle
    private let client: APIClient

    init(symbol: String, client: APIClient = .live) {
        self.symbol = symbol
        self.client = client
    }

    func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await client.ticker(symbol)) }
        catch { state = .failed(APIError(error)) }
    }
}

/// The due-diligence card: score breakdown, catalysts with provenance, red flags and key stats.
struct TickerDetailView: View {
    @State private var model: TickerDetailModel

    init(symbol: String) { _model = State(initialValue: TickerDetailModel(symbol: symbol)) }

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading: WakingView()
            case .failed(let error): ErrorView(error: error) { await model.load() }
            case .loaded(let card): TickerCardList(card: card)
            }
        }
        .navigationTitle(model.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { WatchlistToggle(symbol: model.symbol) } }
        .refreshable { await model.load() }
        .task { if case .idle = model.state { await model.load() } }
        .safeAreaInset(edge: .bottom) { DisclaimerFooter() }
    }
}

struct TickerCardList: View {
    let card: TickerCard

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.company ?? card.ticker).font(.title3.weight(.semibold))
                    Text([card.exchange, card.sector, card.industry].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(card.onShortlist ? "On today's shortlist" : "Not on today's shortlist")
                        Spacer()
                        Text("Market cap \(Format.dollars(card.marketCap))")
                    }
                    .font(.caption)
                    FreshnessBanner(dataAsOf: card.dataAsOf, stale: card.stale)
                }
            }

            if let breakdown = card.scoreBreakdown {
                Section {
                    ForEach(breakdown.rows) { row in ScoreBar(label: row.label, component: row.component) }
                    LabeledContent("Base score", value: Format.score(breakdown.baseOpportunityScore))
                    LabeledContent("Penalties", value: "\(breakdown.penaltyPoints)")
                    LabeledContent("Multi-scanner bonus", value: "+\(breakdown.multiScannerBonus)")
                } header: {
                    HStack {
                        Text("Score breakdown")
                        Spacer()
                        Text("\(Format.score(breakdown.opportunityScore)) / 100").monospacedDigit()
                    }
                } footer: {
                    if let pct = card.dataCompleteness?.overallPct {
                        Text("Data completeness \(Format.score(pct))%. Components without data score nothing.")
                    }
                }
            } else {
                Section("Score breakdown") {
                    Text("Not scored: this ticker didn't qualify for a scanner in the latest scan.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Section("Catalysts") {
                if card.catalysts.isEmpty {
                    Text("No dated catalysts found.").foregroundStyle(.secondary)
                } else {
                    ForEach(card.catalysts) { CatalystRow(event: $0) }
                }
            }

            Section("Red flags") {
                if card.redFlags.isEmpty {
                    Label("None found", systemImage: "checkmark.seal").foregroundStyle(.secondary)
                } else {
                    ForEach(card.redFlags) { flag in
                        Label {
                            VStack(alignment: .leading) {
                                Text(flag.message)
                                Text(flag.points.map { "\(flag.code) · \($0) pts" } ?? flag.code)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }
                }
            }

            if !card.scanners.isEmpty {
                Section("Scanners") {
                    ForEach(card.scanners) { scanner in
                        LabeledContent(ScannerName.label(scanner.scanner)) {
                            Text("\(scanner.qualified ? "Qualified" : "Not qualified") · \(scanner.conditionsMet)/\(scanner.conditionsTotal)")
                                .foregroundStyle(scanner.qualified ? Color.green : Color.secondary)
                        }
                    }
                }
            }

            if let market = card.market {
                Section {
                    LabeledContent("Price", value: Format.price(market.data.price))
                    LabeledContent("RSI (14)", value: Format.score(market.data.rsi14))
                    LabeledContent("SMA 50 / 200", value: "\(Format.price(market.data.sma50)) / \(Format.price(market.data.sma200))")
                    LabeledContent("ATR (14)", value: Format.price(market.data.atr14))
                    LabeledContent("52-week range", value: "\(Format.price(market.data.low52w)) – \(Format.price(market.data.high52w))")
                    LabeledContent("20-day return", value: Format.percent(market.data.return20d))
                    LabeledContent("Avg $ volume (20d)", value: Format.dollars(market.data.avgDollarVolume20d))
                } header: {
                    Text("Market data")
                } footer: {
                    Text("Source: \(market.source) · as of \(Format.day(market.asOf))\(market.stale ? " · stale" : "")")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
