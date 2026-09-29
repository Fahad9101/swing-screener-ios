import SwiftUI

@Observable
@MainActor
final class ShortlistModel {
    var state: LoadState<ShortlistResponse> = .idle
    var search = ""
    private let client: APIClient

    init(client: APIClient = .live) { self.client = client }

    func load() async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await client.shortlist()) }
        catch { state = .failed(APIError(error)) }
    }

    func filtered(_ items: [Opportunity]) -> [Opportunity] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { $0.ticker.localizedCaseInsensitiveContains(query) || $0.company.localizedCaseInsensitiveContains(query) }
    }
}

struct ShortlistView: View {
    @State private var model = ShortlistModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Shortlist")
                .navigationDestination(for: String.self) { TickerDetailView(symbol: $0) }
                .searchable(text: $model.search, prompt: "Ticker or company")
                .refreshable { await model.load() }
                .task { if case .idle = model.state { await model.load() } }
                .safeAreaInset(edge: .bottom) { DisclaimerFooter() }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            WakingView()
        case .failed(let error) where error.code == "NO_COMPLETED_SCAN":
            ContentUnavailableView("No scan yet", systemImage: "chart.line.uptrend.xyaxis", description: Text("Today's shortlist will appear here after the nightly scan."))
        case .failed(let error):
            ErrorView(error: error) { await model.load() }
        case .loaded(let response):
            List {
                Section {
                    ForEach(model.filtered(response.data)) { item in
                        NavigationLink(value: item.ticker) { OpportunityRow(item: item) }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        FreshnessBanner(dataAsOf: response.dataAsOf, stale: response.stale)
                        Text("\(response.count) names passed the reliability filters, ranked by score.")
                    }
                    .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct OpportunityRow: View {
    let item: Opportunity

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.ticker).font(.headline.monospaced())
                Text(item.company).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(([ScannerName.label(item.primaryScanner)] + item.secondaryScanners.map(ScannerName.label)).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.score(item.scores.opportunityScore))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text(Format.price(item.price)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ShortlistView()
        .environment(AuthStore(persist: false))
}
