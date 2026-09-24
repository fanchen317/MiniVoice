import XCTest
@testable import MiniVoice

final class DesktopLyricScrollTests: XCTestCase {
    func testShortAndLongLinesFinishBeforeNextTimestamp() {
        for duration in [0.5, 1.0, 3.0, 15.0] {
            XCTAssertEqual(DesktopLyricScroll.progress(time: 10, start: 10, end: 10 + duration), 0)
            XCTAssertEqual(DesktopLyricScroll.progress(time: 10 + duration * 0.81, start: 10, end: 10 + duration), 1)
            XCTAssertEqual(DesktopLyricScroll.progress(time: 10 + duration, start: 10, end: 10 + duration), 1)
        }
    }

    func testSeekingUsesPlaybackTimeNotWallClock() {
        let middle = DesktopLyricScroll.progress(time: 12, start: 10, end: 14)
        XCTAssertGreaterThan(middle, 0)
        XCTAssertLessThan(middle, 1)
        XCTAssertEqual(DesktopLyricScroll.progress(time: 12, start: 10, end: 14), middle)
        XCTAssertEqual(DesktopLyricScroll.progress(time: 9, start: 10, end: 14), 0)
        XCTAssertEqual(DesktopLyricScroll.progress(time: 12, start: 10, end: 10), 0)
    }
}
