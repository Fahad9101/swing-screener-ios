import SwiftUI

@main
struct SwingScreenerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
        }
    }
}
