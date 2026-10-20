import XCTest
@testable import MiniVoice

final class LyricsDisplayTimingTests: XCTestCase {
    func testEstimateIsDisplayOnlyAndPreservesGraphemes() {
        let original = LyricLine(timestamp: 10, text: "你好 👨‍👩‍👧‍👦")
        let display = LyricsDisplayTiming.line(original, nextStart: 11, trackDuration: 100)
        XCTAssertEqual(display.words.map(\.text), ["你", "好", " ", "👨‍👩‍👧‍👦"])
        XCTAssertEqual(display.words.first?.start, 10)
        XCTAssertEqual(display.words.last!.end!, 10.88, accuracy: 0.000001)
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

    func testEstimatedSweepFinishesBeforeNextLineAndHoldsHighlight() {
        let source = LyricLine(timestamp: 10, text: "最后一个字")
        for interval in [0.1, 1, 3, 7] {
            let next = 10 + interval
            let display = LyricsDisplayTiming.line(source, nextStart: next, trackDuration: 100)
            let last = display.words.last!
            let end = last.end!
            XCTAssertEqual(next - end, min(0.3, interval * 0.12), accuracy: 0.000001)
            XCTAssertTrue(display.words.allSatisfy { $0.end! > $0.start })
            XCTAssertEqual(LyricsSweep.progress(time: (end + next) / 2, start: last.start, end: end), 1)
            XCTAssertEqual(LyricsPlaybackSnapshot(lines: [source, LyricLine(timestamp: next, text: "下一句")])
                .activeIndex(at: (end + next) / 2), 0)
        }
    }

    func testExistingPauseAndInvalidNextBoundaryArePreserved() {
        let source = LyricLine(timestamp: 10, text: "你好", endTime: 11)
        XCTAssertEqual(LyricsDisplayTiming.line(source, nextStart: 12, trackDuration: 100).words.last?.end, 11)
        for next in [Double.nan, .infinity, 9, 10] {
            XCTAssertEqual(LyricsDisplayTiming.line(source, nextStart: next, trackDuration: 100).words.last?.end, 11)
        }
    }
}
