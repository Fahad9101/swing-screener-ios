import Foundation

enum APIError: LocalizedError, Equatable {
    case server(code: String, message: String, status: Int)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .server(_, let message, _): return message
        case .transport(let message): return "Couldn't reach the server. \(message)"
        case .decoding: return "The server sent data this version of the app can't read."
        }
    }

    var code: String? {
        if case .server(let code, _, _) = self { return code }
        return nil
    }
}

/// Thin async client for the read-only SOE API.
struct APIClient {
    let baseURL: URL
    var session: URLSession = .shared

    /// The hosted API. Render's free plan sleeps when idle, so the first request can take ~50s.
    static let live = APIClient(baseURL: APIClient.configuredBaseURL)

    static var configuredBaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "SSAPIBaseURL") as? String
        return URL(string: raw ?? "") ?? URL(string: "https://soe-api-7eyh.onrender.com")!
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func shortlist(limit: Int = 200) async throws -> ShortlistResponse {
        try await get("opportunities", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    func ticker(_ symbol: String) async throws -> TickerCard {
        try await get("ticker/\(symbol.uppercased())")
    }

    func catalysts(days: Int = 30, shortlistOnly: Bool = false) async throws -> CatalystCalendarResponse {
        try await get("catalysts", query: [
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "shortlist_only", value: shortlistOnly ? "true" : "false"),
        ])
    }

    func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/\(path)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: url(path, query: query))
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        return try Self.decode(T.self, data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func decode<T: Decodable>(_ type: T.Type, data: Data, status: Int) throws -> T {
        guard (200..<300).contains(status) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw APIError.server(code: envelope.error.code, message: envelope.error.message, status: status)
            }
            throw APIError.server(code: "HTTP_\(status)", message: "The server returned an error (\(status)).", status: status)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
