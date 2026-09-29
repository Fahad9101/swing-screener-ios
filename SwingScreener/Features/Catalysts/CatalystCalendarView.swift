import SwiftUI

@Observable
@MainActor
final class CatalystCalendarModel {
    var state: LoadState<CatalystCalendarResponse> = .idle
    var days = 30
    var shortlistOnly = true
    private let client: APIClient

    init(client: APIClient = .live) { self.client = client }

    func load() async {
        state = .loading
        do { state = .loaded(try await client.catalysts(days: days, shortlistOnly: shortlistOnly)) }
        catch { state = .failed(APIError(error)) }
    }

    /// Events grouped by day, in date order.
    static func grouped(_ events: [CatalystEvent]) -> [CatalystDay] {
        let groups = Dictionary(grouping: events) { $0.day ?? "Undated" }
        return groups.keys.sorted().map { CatalystDay(day: $0, events: groups[$0] ?? []) }
    }
}

struct CatalystDay: Identifiable {
    var id: String { day }
    let day: String
    let events: [CatalystEvent]
}

struct CatalystCalendarView: View {
    @State private var model = CatalystCalendarModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Catalysts")
                .navigationDestination(for: String.self) { TickerDetailView(symbol: $0) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Window", selection: $model.days) {
                                Text("Next 7 days").tag(7)
                                Text("Next 30 days").tag(30)
                                Text("Next 90 days").tag(90)
                            }
                            Toggle("Shortlist only", isOn: $model.shortlistOnly)
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .onChange(of: model.days) { Task { await model.load() } }
                .onChange(of: model.shortlistOnly) { Task { await model.load() } }
                .refreshable { await model.load() }
                .task { if case .idle = model.state { await model.load() } }
                .safeAreaInset(edge: .bottom) { DisclaimerFooter() }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            WakingView()
        case .failed(let error):
            ErrorView(error: error) { await model.load() }
        case .loaded(let response) where response.data.isEmpty:
            ContentUnavailableView("No catalysts", systemImage: "calendar", description: Text("Nothing dated in the next \(model.days) days\(model.shortlistOnly ? " for shortlist names" : "")."))
        case .loaded(let response):
            List {
                Section { FreshnessBanner(dataAsOf: response.dataAsOf, stale: response.stale) }
                ForEach(CatalystCalendarModel.grouped(response.data)) { group in
                    Section(Format.day(group.day)) {
                        ForEach(group.events) { event in
                            NavigationLink(value: event.ticker) { CatalystRow(event: event, showTicker: true) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
