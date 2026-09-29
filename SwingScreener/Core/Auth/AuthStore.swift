import Foundation

/// A signed-in session plus the time its access token expires.
struct StoredSession: Codable, Equatable {
    var session: AuthSession
    var expiresAt: Date

    init(_ session: AuthSession, now: Date = .now) {
        self.session = session
        self.expiresAt = now.addingTimeInterval(session.expiresIn ?? 3600)
    }

    /// Refresh a minute early so a request never goes out with an about-to-expire token.
    func needsRefresh(now: Date = .now) -> Bool { now >= expiresAt.addingTimeInterval(-60) }
}

/// Email one-time-code sign-in. Codes and tokens come from Supabase Auth through the SOE API.
@Observable
@MainActor
final class AuthStore {
    private(set) var stored: StoredSession?
    private let client: APIClient
    private let persist: Bool
    static let account = "session"

    var isSignedIn: Bool { stored != nil }
    var email: String? { stored?.session.user.email }

    init(client: APIClient = .live, persist: Bool = true) {
        self.client = client
        self.persist = persist
        if persist, let data = Keychain.load(account: Self.account) {
            stored = try? JSONDecoder().decode(StoredSession.self, from: data)
        }
    }

    func sendCode(to email: String) async throws {
        try await client.sendEmailCode(to: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func verify(email: String, code: String) async throws {
        let session = try await client.verify(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), code: code.trimmingCharacters(in: .whitespaces))
        save(StoredSession(session))
    }

    /// A usable access token, refreshing it first when needed. Signs out if the refresh is rejected.
    func accessToken() async throws -> String {
        guard let current = stored else { throw APIError.server(code: "AUTH_REQUIRED", message: "Sign in to use the watchlist.", status: 401) }
        guard current.needsRefresh() else { return current.session.accessToken }
        do {
            let renewed = try await client.refresh(current.session.refreshToken)
            save(StoredSession(renewed))
            return renewed.accessToken
        } catch let error as APIError where error.needsSignIn {
            signOut()
            throw error
        }
    }

    /// Error from the last sign-in link, shown on the sign-in screen.
    var linkError: String?

    /// Completes sign-in from the email's Log In link:
    /// swingscreener://auth-callback#access_token=…&refresh_token=…&expires_in=3600
    @discardableResult
    func handle(url: URL) -> Bool {
        guard let result = SignInLink.parse(url) else { return false }
        switch result {
        case .success(let session):
            linkError = nil
            save(StoredSession(session))
        case .failure(let message):
            linkError = message
        }
        return true
    }

    func signOut() {
        stored = nil
        if persist { Keychain.delete(account: Self.account) }
    }

    private func save(_ session: StoredSession) {
        stored = session
        if persist, let data = try? JSONEncoder().encode(session) { Keychain.save(data, account: Self.account) }
    }
}


/// Parses the redirect Supabase sends after the user taps the email's Log In link.
enum SignInLink {
    enum Result: Equatable {
        case success(AuthSession)
        case failure(String)
    }

    static let scheme = "swingscreener"
    static let host = "auth-callback"

    static func parse(_ url: URL) -> Result? {
        guard url.scheme == scheme, url.host == host else { return nil }
        var items: [String: String] = [:]
        for raw in [url.fragment, URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery].compactMap({ $0 }) {
            var components = URLComponents()
            components.percentEncodedQuery = raw
            for item in components.queryItems ?? [] { items[item.name] = item.value }
        }
        if let description = items["error_description"] ?? items["error"] {
            return .failure(description.replacingOccurrences(of: "+", with: " "))
        }
        guard let access = items["access_token"], let refresh = items["refresh_token"] else {
            return .failure("The sign-in link was incomplete. Request a new one.")
        }
        let claims = JWTClaims(access)
        return .success(AuthSession(accessToken: access, refreshToken: refresh, expiresIn: items["expires_in"].flatMap(Double.init), user: .init(id: claims?.sub, email: claims?.email)))
    }
}

/// Reads (does not verify) the `sub` and `email` claims of an access token for display.
struct JWTClaims {
    let sub: String?
    let email: String?

    init?(_ token: String) {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64), let claims = try? JSONDecoder().decode(Claims.self, from: data) else { return nil }
        sub = claims.sub
        email = claims.email
    }

    private struct Claims: Decodable {
        let sub: String?
        let email: String?
    }
}
