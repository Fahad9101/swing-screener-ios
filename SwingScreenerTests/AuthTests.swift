import XCTest
@testable import SwingScreener

final class AuthTests: XCTestCase {
    private let session = AuthSession(accessToken: "a", refreshToken: "r", expiresIn: 3600, user: .init(id: "u", email: "fahad@example.com"))

    func testStoredSessionRefreshesOneMinuteEarly() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let stored = StoredSession(session, now: now)
        XCTAssertFalse(stored.needsRefresh(now: now.addingTimeInterval(3000)))
        XCTAssertTrue(stored.needsRefresh(now: now.addingTimeInterval(3541)))
    }

    func testAuthSessionDecodesFromAPI() throws {
        let json = #"{"access_token":"x.y.z","refresh_token":"r1","expires_in":3600,"token_type":"bearer","user":{"id":"u1","email":"a@b.co"}}"#
        let decoded = try APIClient.decoder.decode(AuthSession.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.accessToken, "x.y.z")
        XCTAssertEqual(decoded.user.email, "a@b.co")
    }

    func testStoredSessionRoundTripsForKeychain() throws {
        let stored = StoredSession(session)
        let data = try JSONEncoder().encode(stored)
        XCTAssertEqual(try JSONDecoder().decode(StoredSession.self, from: data), stored)
    }

    func testOnlyUnauthorizedErrorsForceSignIn() {
        XCTAssertTrue(APIError.server(code: "AUTH_EXPIRED", message: "", status: 401).needsSignIn)
        XCTAssertFalse(APIError.server(code: "AUTH_RATE_LIMITED", message: "", status: 429).needsSignIn)
        XCTAssertFalse(APIError.transport("offline").needsSignIn)
    }

    @MainActor
    func testSignedOutStoreRefusesToIssueAToken() async {
        let store = AuthStore(persist: false)
        XCTAssertFalse(store.isSignedIn)
        do {
            _ = try await store.accessToken()
            XCTFail("expected AUTH_REQUIRED")
        } catch {
            XCTAssertEqual((error as? APIError)?.code, "AUTH_REQUIRED")
        }
    }

    func testWatchlistDecodesNextCatalyst() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "watchlist", withExtension: "json"))
        let response = try APIClient.decode(WatchlistResponse.self, data: Data(contentsOf: url), status: 200)
        let item = try XCTUnwrap(response.data.first)
        XCTAssertEqual(item.ticker, "RERATE")
        XCTAssertEqual(item.note, "breakout")
        XCTAssertEqual(item.nextCatalyst?.status, .confirmed)
    }

    func testEmptyResponseSkipsDecoding() throws {
        XCTAssertNoThrow(try APIClient.decode(EmptyResponse.self, data: Data(), status: 204))
    }
}
