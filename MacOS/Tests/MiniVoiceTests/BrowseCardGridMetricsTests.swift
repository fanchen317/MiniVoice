import XCTest
@testable import MiniVoice

final class BrowseCardGridMetricsTests: XCTestCase {
    func testAddsEachColumnAsSoonAsItFits() {
        for count in 2...12 {
            let threshold = CGFloat(count) * 136 + CGFloat(count - 1) * 16
            XCTAssertEqual(BrowseCardGridMetrics.columnCount(availableWidth: threshold - 1), count - 1)
            XCTAssertEqual(BrowseCardGridMetrics.columnCount(availableWidth: threshold), count)
            XCTAssertEqual(BrowseCardGridMetrics.cardWidth(availableWidth: threshold), 136)
        }
    }

    func testColumnsAndGapsExactlyFillAvailableWidth() {
        for width in stride(from: CGFloat(288), through: 1600, by: 13) {
            let count = BrowseCardGridMetrics.columnCount(availableWidth: width)
            let card = BrowseCardGridMetrics.cardWidth(availableWidth: width)
            XCTAssertGreaterThanOrEqual(card, 136)
            XCTAssertEqual(card * CGFloat(count) + CGFloat(count - 1) * 16, width, accuracy: 0.001)
        }
    }
}
