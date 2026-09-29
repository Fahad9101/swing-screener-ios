import SwiftUI

/// Loading lifecycle for a screen backed by one API call.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }
}

extension APIError {
    init(_ error: Error) {
        self = (error as? APIError) ?? .transport(error.localizedDescription)
    }
}

/// Shows when the data was produced, and a warning when it is stale. Stale data is never silent.
struct FreshnessBanner: View {
    let dataAsOf: String?
    let stale: Bool

    var body: some View {
        Label {
            Text(stale ? "Stale data. Last scan \(Format.relative(dataAsOf))." : "Scan updated \(Format.relative(dataAsOf)).")
        } icon: {
            Image(systemName: stale ? "exclamationmark.triangle.fill" : "clock")
        }
        .font(.footnote.weight(stale ? .semibold : .regular))
        .foregroundStyle(stale ? Color.orange : Color.secondary)
        .accessibilityIdentifier("freshness")
    }
}

struct DisclaimerFooter: View {
    var body: some View {
        Text(Disclaimer.text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

struct CatalystStatusBadge: View {
    let status: CatalystStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(status.tint)
    }
}

extension CatalystStatus {
    var label: String {
        switch self {
        case .confirmed: return "Confirmed"
        case .estimated: return "Estimated"
        case .speculative: return "Speculative"
        }
    }

    var tint: Color {
        switch self {
        case .confirmed: return .green
        case .estimated: return .orange
        case .speculative: return .gray
        }
    }
}

/// One catalyst with everything the plan requires: date, confirmed/estimated, source, last checked.
struct CatalystRow: View {
    let event: CatalystEvent
    var showTicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                if showTicker {
                    Text(event.ticker).font(.headline.monospaced())
                }
                Text(event.title).font(.subheadline)
                Spacer(minLength: 8)
                CatalystStatusBadge(status: event.status)
            }
            Text(dateLine).font(.caption).foregroundStyle(.secondary)
            Text("Source: \(event.source) · checked \(Format.relative(event.lastChecked))\(event.stale ? " · stale" : "")")
                .font(.caption2)
                .foregroundStyle(event.stale ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private var dateLine: String {
        if event.eventDate == nil, let start = event.windowStart {
            return "Window \(Format.day(start)) – \(Format.day(event.windowEnd ?? start))"
        }
        return [Format.day(event.eventDate), event.timing?.replacingOccurrences(of: "_", with: " ").lowercased()]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// A score component as a labeled bar out of its maximum. Unavailable components say so.
struct ScoreBar: View {
    let label: String
    let component: ScoreComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(component.score == nil ? "No data" : "\(Format.score(component.score)) / \(Format.score(component.maximum))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(component.score == nil ? .secondary : .primary)
            }
            ProgressView(value: min(component.score ?? 0, component.maximum), total: max(component.maximum, 1))
                .tint(component.score == nil ? .gray : .accentColor)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ErrorView: View {
    let error: APIError
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try again") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct WakingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading. The server may take up to a minute to wake up.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
