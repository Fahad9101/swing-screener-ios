import XCTest
@testable import SwingScreener

final class FormattingTests: XCTestCase {
    func testParsesPostgresSqliteAndZuluTimestamps() throws {
        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-29T07:16:00Z"))
        for raw in ["2026-09-29T07:16:00+00:00", "2026-09-29T07:16:00.123456+00:00", "2026-09-29T07:16:00.123456", "2026-09-29T07:16:00Z", "2026-09-29T03:16:00-04:00"] {
            let parsed = try XCTUnwrap(APIDate.parse(raw), raw)
            XCTAssertEqual(parsed.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1, raw)
        }
    }

    func testParsesDayOnlyDates() {
        XCTAssertNotNil(APIDate.parse("2026-10-17"))
        XCTAssertNil(APIDate.parse(nil))
        XCTAssertNil(APIDate.parse(""))
    }

    func testNormalizesMicrosecondsToMilliseconds() {
        XCTAssertEqual(APIDate.normalizeFraction("2026-09-29T07:16:00.123456+00:00"), "2026-09-29T07:16:00.123+00:00")
        XCTAssertEqual(APIDate.normalizeFraction("2026-09-29T07:16:00.5Z"), "2026-09-29T07:16:00.500Z")
        XCTAssertEqual(APIDate.normalizeFraction("2026-09-29T07:16:00Z"), "2026-09-29T07:16:00Z")
    }

    func testCompactDollars() {
        XCTAssertEqual(Format.dollars(12_000_000_000), "$12B")
        XCTAssertEqual(Format.dollars(190_005_834.9), "$190M")
        XCTAssertEqual(Format.dollars(nil), "–")
    }

    func testMissingScoresShowADash() {
        XCTAssertEqual(Format.score(nil), "–")
        XCTAssertEqual(Format.score(51.5), "51.5")
        XCTAssertEqual(Format.score(75), "75")
    }
}
