import XCTest
@testable import MiniVoice

final class LyricsDisplayTimingTests: XCTestCase {
    func testEstimateIsDisplayOnlyAndPreservesGraphemes() {
        let original = LyricLine(timestamp: 10, text: "你好 👨‍👩‍👧‍👦")
        let display = LyricsDisplayTiming.line(original, nextStart: 11, trackDuration: 100)
        XCTAssertEqual(display.words.map(\.text), ["你", "好", " ", "👨‍👩‍👧‍👦"])
        XCTAssertEqual(display.words.first?.start, 10)
        XCTAssertEqual(display.words.last?.end, 11)
        XCTAssertTrue(original.words.isEmpty)
        XCTAssertEqual(LyricTimingKind.detect([original]), .line)
        XCTAssertFalse(LyricsTiming.encoded([original]).contains("<"))
        // No wall clock or accumulated state: seeking back yields the same schedule.
        XCTAssertEqual(display, LyricsDisplayTiming.line(original, nextStart: 11, trackDuration: 100))
    }

    func testRealTimingAndPlainTextAreUntouched() {
        let real = LyricLine(timestamp: 10, text: "你好", endTime: 12,
                             words: [LyricWord(text: "你好", start: 10.5, end: 12)])
        XCTAssertEqual(LyricsDisplayTiming.line(real, nextStart: 11, trackDuration: 11), real)
        for line in [LyricLine(timestamp: nil, text: "普通文本"), LyricLine(timestamp: 0, text: " ")] {
            XCTAssertEqual(LyricsDisplayTiming.line(line, nextStart: 10, trackDuration: 100), line)
        }
    }

    func testEndBoundsAndLongInstrumentalGap() {
        let line = LyricLine(timestamp: 10, text: "你好")
        XCTAssertEqual(LyricsDisplayTiming.line(line, nextStart: 100, trackDuration: 200).words.last?.end, 12)
        XCTAssertEqual(LyricsDisplayTiming.line(line, nextStart: nil, trackDuration: 11).words.last?.end, 11)
        XCTAssertEqual(LyricsDisplayTiming.line(line, nextStart: nil, trackDuration: .nan).words.last?.end, 12)
        let bounded = LyricLine(timestamp: 10, text: "你好", endTime: 10.5)
        XCTAssertEqual(LyricsDisplayTiming.line(bounded, nextStart: 20, trackDuration: 100).words.last?.end, 10.5)
    }
}
