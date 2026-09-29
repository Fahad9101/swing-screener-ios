import XCTest
@testable import SwingScreener

final class SignInLinkTests: XCTestCase {
    /// A token whose payload is {"sub":"user-1","email":"fahad@example.com"} (signature irrelevant here).
    private let token = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ1c2VyLTEiLCJlbWFpbCI6ImZhaGFkQGV4YW1wbGUuY29tIn0.sig"

    func testParsesSessionFromFragment() throws {
        let url = try XCTUnwrap(URL(string: "swingscreener://auth-callback#access_token=\(token)&expires_in=3600&refresh_token=r1&token_type=bearer&type=magiclink"))
        guard case .success(let session) = SignInLink.parse(url) else { return XCTFail("expected a session") }
        XCTAssertEqual(session.accessToken, token)
        XCTAssertEqual(session.refreshToken, "r1")
        XCTAssertEqual(session.expiresIn, 3600)
        XCTAssertEqual(session.user.email, "fahad@example.com")
        XCTAssertEqual(session.user.id, "user-1")
    }

    func testReportsErrorsFromSupabase() throws {
        let url = try XCTUnwrap(URL(string: "swingscreener://auth-callback#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired"))
        XCTAssertEqual(SignInLink.parse(url), .failure("Email link is invalid or has expired"))
    }

    func testIgnoresOtherURLsAndFlagsIncompleteLinks() throws {
        XCTAssertNil(SignInLink.parse(try XCTUnwrap(URL(string: "https://example.com/auth-callback#access_token=x"))))
        XCTAssertNil(SignInLink.parse(try XCTUnwrap(URL(string: "swingscreener://other#access_token=x"))))
        XCTAssertEqual(SignInLink.parse(try XCTUnwrap(URL(string: "swingscreener://auth-callback#access_token=x"))), .failure("The sign-in link was incomplete. Request a new one."))
    }

    @MainActor
    func testHandlingALinkSignsIn() throws {
        let store = AuthStore(persist: false)
        let url = try XCTUnwrap(URL(string: "swingscreener://auth-callback#access_token=\(token)&expires_in=3600&refresh_token=r1"))
        XCTAssertTrue(store.handle(url: url))
        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.email, "fahad@example.com")
    }
}
