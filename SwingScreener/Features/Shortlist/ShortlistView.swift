import SwiftUI

/// Placeholder until the SOE `/opportunities` endpoint is hosted (Phase 1).
struct ShortlistView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No scan yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Today's shortlist will appear here after the nightly scan.")
            )
            .navigationTitle("Shortlist")
            .safeAreaInset(edge: .bottom) {
                Text(Disclaimer.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
    }
}

#Preview {
    ShortlistView()
}
