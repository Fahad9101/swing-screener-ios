import XCTest
@testable import SwingScreener

final class DisclaimerTests: XCTestCase {
    func testDisclaimerStatesNotFinancialAdvice() {
        XCTAssertTrue(Disclaimer.text.localizedCaseInsensitiveContains("not financial advice"))
    }
}
