import SwiftUI

@main
struct SwingScreenerApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .onOpenURL { url in _ = auth.handle(url: url) }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ShortlistView()
                .tabItem { Label("Shortlist", systemImage: "list.number") }
            CatalystCalendarView()
                .tabItem { Label("Catalysts", systemImage: "calendar") }
            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "star") }
        }
    }
}
