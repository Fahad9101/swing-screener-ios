import XCTest
@testable import SwingScreener

/// Decodes JSON captured from the SOE API's fixture scan (SwingScreenerTests/Fixtures).
final class APIDecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"), "missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    func testShortlistDecodesScoresAndFreshness() throws {
        let response = try APIClient.decode(ShortlistResponse.self, data: fixture("opportunities"), status: 200)
        XCTAssertFalse(response.stale)
        XCTAssertNotNil(response.dataAsOf)
        XCTAssertEqual(response.data.count, 3)
        let top = try XCTUnwrap(response.data.first)
        XCTAssertEqual(top.ticker, "RERATE")
        XCTAssertEqual(top.scores.opportunityScore, 75)
        XCTAssertEqual(top.scores.rows.count, 7)
        XCTAssertEqual(top.scores.rows.compactMap(\.component.score).reduce(0, +), top.scores.baseOpportunityScore)
    }

    func testTickerCardDecodesCatalystProvenanceAndMarketData() throws {
        let card = try APIClient.decode(TickerCard.self, data: fixture("ticker"), status: 200)
        XCTAssertEqual(card.ticker, "RERATE")
        XCTAssertEqual(card.disclaimer, Disclaimer.text)
        XCTAssertTrue(card.onShortlist)
        XCTAssertNotNil(card.scoreBreakdown)
        let catalyst = try XCTUnwrap(card.catalysts.first)
        XCTAssertEqual(catalyst.status, .confirmed)
        XCTAssertEqual(catalyst.source, "synthetic_fixture")
        XCTAssertNotNil(APIDate.parse(catalyst.lastChecked))
        XCTAssertNotNil(card.market?.data.price)
        XCTAssertNotNil(card.market?.data.avgDollarVolume20d)
        XCTAssertFalse(card.scanners.isEmpty)
    }

    func testCatalystCalendarDecodesAndGroupsByDay() throws {
        let response = try APIClient.decode(CatalystCalendarResponse.self, data: fixture("catalysts"), status: 200)
        XCTAssertEqual(response.count, response.data.count)
        let days = CatalystCalendarModel.grouped(response.data).map(\.day)
        XCTAssertEqual(days, days.sorted())
        XCTAssertEqual(Set(days).count, days.count)
    }

    func testServerErrorEnvelopeBecomesAPIError() throws {
        XCTAssertThrowsError(try APIClient.decode(TickerCard.self, data: fixture("error"), status: 404)) { error in
            XCTAssertEqual((error as? APIError)?.code, "TICKER_NOT_IN_SCAN")
        }
        XCTAssertThrowsError(try APIClient.decode(TickerCard.self, data: Data("oops".utf8), status: 502)) { error in
            XCTAssertEqual((error as? APIError)?.code, "HTTP_502")
        }
    }

    func testUnknownCatalystStatusFallsBackToSpeculative() throws {
        let json = #"{"ticker":"A","kind":"catalyst","type":"X","title":"t","status":"rumoured","verified":false,"source":"s","stale":false}"#
        let event = try APIClient.decoder.decode(CatalystEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.status, .speculative)
    }
}
