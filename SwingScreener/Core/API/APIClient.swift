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

    /// The access token was missing, expired or rejected, so the user must sign in again.
    var needsSignIn: Bool {
        guard case .server(_, _, let status) = self else { return false }
        return status == 401
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

    // MARK: Sign-in (relayed by the API to Supabase Auth; the app holds no key)

    func sendEmailCode(to email: String) async throws {
        _ = try await send(EmptyResponse.self, "POST", "auth/email-code", body: ["email": email])
    }

    func verify(email: String, code: String) async throws -> AuthSession {
        try await send(AuthSession.self, "POST", "auth/verify", body: ["email": email, "code": code])
    }

    func refresh(_ refreshToken: String) async throws -> AuthSession {
        try await send(AuthSession.self, "POST", "auth/refresh", body: ["refresh_token": refreshToken])
    }

    // MARK: Watchlist (needs a signed-in access token)

    func watchlist(token: String) async throws -> WatchlistResponse {
        try await send(WatchlistResponse.self, "GET", "watchlist", token: token)
    }

    func addToWatchlist(_ symbol: String, note: String? = nil, token: String) async throws -> WatchlistItem {
        try await send(WatchlistItem.self, "PUT", "watchlist/\(symbol.uppercased())", body: note.map { ["note": $0] }, token: token)
    }

    func removeFromWatchlist(_ symbol: String, token: String) async throws {
        _ = try await send(EmptyResponse.self, "DELETE", "watchlist/\(symbol.uppercased())", token: token)
    }

    func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/v1/\(path)"), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        return components.url!
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await send(T.self, "GET", path, query: query)
    }

    func send<T: Decodable>(_ type: T.Type, _ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: String]? = nil, token: String? = nil) async throws -> T {
        var request = URLRequest(url: url(path, query: query))
        request.httpMethod = method
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
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
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
