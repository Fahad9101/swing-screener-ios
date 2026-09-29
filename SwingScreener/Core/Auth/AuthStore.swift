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

    func signOut() {
        stored = nil
        if persist { Keychain.delete(account: Self.account) }
    }

    private func save(_ session: StoredSession) {
        stored = session
        if persist, let data = try? JSONEncoder().encode(session) { Keychain.save(data, account: Self.account) }
    }
}
