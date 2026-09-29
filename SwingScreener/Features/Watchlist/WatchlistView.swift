import SwiftUI

@Observable
@MainActor
final class WatchlistModel {
    var state: LoadState<WatchlistResponse> = .idle
    private let client: APIClient

    init(client: APIClient = .live) { self.client = client }

    func load(auth: AuthStore) async {
        if state.value == nil { state = .loading }
        do { state = .loaded(try await client.watchlist(token: auth.accessToken())) }
        catch { fail(error, auth: auth) }
    }

    func remove(_ symbol: String, auth: AuthStore) async {
        do {
            try await client.removeFromWatchlist(symbol, token: auth.accessToken())
            await load(auth: auth)
        } catch { fail(error, auth: auth) }
    }

    private func fail(_ error: Error, auth: AuthStore) {
        let apiError = APIError(error)
        if apiError.needsSignIn { auth.signOut() }
        state = .failed(apiError)
    }
}

struct WatchlistView: View {
    @Environment(AuthStore.self) private var auth
    @State private var model = WatchlistModel()

    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn { content } else { SignInView() }
            }
            .navigationTitle("Watchlist")
            .navigationDestination(for: String.self) { TickerDetailView(symbol: $0) }
            .toolbar {
                if auth.isSignedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let email = auth.email { Text(email) }
                            Button("Sign out", role: .destructive) { auth.signOut(); model.state = .idle }
                        } label: {
                            Image(systemName: "person.crop.circle")
                        }
                    }
                }
            }
            .task(id: auth.isSignedIn) { if auth.isSignedIn { await model.load(auth: auth) } }
            .refreshable { await model.load(auth: auth) }
            .safeAreaInset(edge: .bottom) { DisclaimerFooter() }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            WakingView()
        case .failed(let error):
            ErrorView(error: error) { await model.load(auth: auth) }
        case .loaded(let response) where response.data.isEmpty:
            ContentUnavailableView("No tickers yet", systemImage: "star", description: Text("Tap the star on any stock card to add it here."))
        case .loaded(let response):
            List {
                Section { FreshnessBanner(dataAsOf: response.dataAsOf, stale: response.stale) }
                Section {
                    ForEach(response.data) { item in
                        NavigationLink(value: item.ticker) { WatchlistRow(item: item) }
                    }
                    .onDelete { offsets in
                        let symbols = offsets.map { response.data[$0].ticker }
                        Task { for symbol in symbols { await model.remove(symbol, auth: auth) } }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

struct WatchlistRow: View {
    let item: WatchlistItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.ticker).font(.headline.monospaced())
                if item.onShortlist == true {
                    Text("On shortlist").font(.caption2.weight(.semibold)).foregroundStyle(.green)
                }
                Spacer()
                Text(item.opportunityScore.map { Format.score($0) } ?? "Not scored")
                    .font(item.opportunityScore == nil ? .caption : .title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(item.opportunityScore == nil ? .secondary : .primary)
            }
            if let note = item.note, !note.isEmpty {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            if let catalyst = item.nextCatalyst {
                HStack(spacing: 6) {
                    Text("Next: \(catalyst.title), \(Format.day(catalyst.day))").font(.caption)
                    CatalystStatusBadge(status: catalyst.status)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Star button on the stock card that adds or removes the ticker from the watchlist.
struct WatchlistToggle: View {
    let symbol: String
    @Environment(AuthStore.self) private var auth
    @State private var onList: Bool?
    @State private var working = false
    private let client = APIClient.live

    var body: some View {
        Button {
            Task { await toggle() }
        } label: {
            Image(systemName: onList == true ? "star.fill" : "star")
        }
        .disabled(!auth.isSignedIn || working || onList == nil)
        .accessibilityLabel(onList == true ? "Remove from watchlist" : "Add to watchlist")
        .task(id: auth.isSignedIn) { await refresh() }
    }

    private func refresh() async {
        guard auth.isSignedIn else { onList = nil; return }
        let token = try? await auth.accessToken()
        guard let token, let list = try? await client.watchlist(token: token) else { return }
        onList = list.data.contains { $0.ticker == symbol.uppercased() }
    }

    private func toggle() async {
        working = true
        defer { working = false }
        do {
            let token = try await auth.accessToken()
            if onList == true {
                try await client.removeFromWatchlist(symbol, token: token)
                onList = false
            } else {
                _ = try await client.addToWatchlist(symbol, token: token)
                onList = true
            }
        } catch {
            if APIError(error).needsSignIn { auth.signOut() }
        }
    }
}
