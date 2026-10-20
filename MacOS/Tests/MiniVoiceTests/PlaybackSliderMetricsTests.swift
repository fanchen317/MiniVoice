import XCTest
@testable import MiniVoice

final class PlaybackSliderMetricsTests: XCTestCase {
    func testPointerAndDisplayUseTheSameThumbTravel() {
        for width in [CGFloat(20), 80, 240, 600] {
            for thumbSize in [CGFloat(20), 28] {
                for fraction in [0.0, 0.25, 0.5, 1.0] {
                    let position = thumbSize / 2 + max(0, width - thumbSize) * fraction
                    let value = PlaybackSliderMetrics.value(position: position, width: width,
                        thumbSize: thumbSize, range: 0...240)
                    XCTAssertEqual(value, width <= thumbSize ? 0 : fraction * 240, accuracy: 0.001)
                }
            }
        }
    }

    func testDraggingPastEitherEdgeClampsToPlaybackRange() {
        XCTAssertEqual(PlaybackSliderMetrics.value(position: -100, width: 240, thumbSize: 20, range: 0...1), 0)
        XCTAssertEqual(PlaybackSliderMetrics.value(position: 500, width: 240, thumbSize: 20, range: 0...1), 1)
        XCTAssertEqual(PlaybackSliderMetrics.fraction(value: -10, range: 0...1), 0)
        XCTAssertEqual(PlaybackSliderMetrics.fraction(value: 2, range: 0...1), 1)
    }

    func testNonZeroRangeAndZeroDuration() {
        XCTAssertEqual(PlaybackSliderMetrics.value(position: 120, width: 240, thumbSize: 20, range: 10...20), 15)
        XCTAssertEqual(PlaybackSliderMetrics.fraction(value: 15, range: 10...20), 0.5)
        XCTAssertEqual(PlaybackSliderMetrics.fraction(value: 0, range: 0...0), 0)
    }
}
