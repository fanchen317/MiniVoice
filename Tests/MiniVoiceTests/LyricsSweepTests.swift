import AppKit
import SwiftUI
import XCTest
@testable import MiniVoice

final class LyricsSweepTests: XCTestCase {
    func testProgressIncludesPartialGlyphAndSeekBack() {
        XCTAssertEqual(LyricsSweep.progress(time: 10, start: 10, end: 12), 0)
        XCTAssertEqual(LyricsSweep.progress(time: 10.7, start: 10, end: 12), 0.35, accuracy: 0.0001)
        XCTAssertEqual(LyricsSweep.progress(time: 20, start: 10, end: 12), 1)
        XCTAssertEqual(LyricsSweep.progress(time: 8, start: 10, end: 12), 0)
        XCTAssertEqual(LyricsSweep.progress(time: .nan, start: 10, end: 12), 0)
    }

    func testInterpolationStopsOnPauseAndDoesNotRunAwayWhenSamplesStop() {
        let sampled = Date(timeIntervalSinceReferenceDate: 100)
        XCTAssertEqual(LyricsSweep.displayTime(10, sampledAt: sampled, now: sampled.addingTimeInterval(0.1), playing: true), 10.1, accuracy: 0.0001)
        XCTAssertEqual(LyricsSweep.displayTime(10, sampledAt: sampled, now: sampled.addingTimeInterval(10), playing: true), 10.24, accuracy: 0.0001)
        XCTAssertEqual(LyricsSweep.displayTime(10, sampledAt: sampled, now: sampled.addingTimeInterval(0.1), playing: false), 10)
        XCTAssertEqual(LyricsSweep.displayTime(10, sampledAt: nil, now: sampled, playing: true), 10)
    }

    func testLineUsesNextTimestampForNormalPhraseInterval() {
        let source = LyricLine(timestamp: 10, text: "让你收下 我最美的年华")
        let display = LyricsDisplayTiming.line(source, nextStart: 17, trackDuration: 200)
        XCTAssertEqual(display.words.last!.end!, 16.7, accuracy: 0.000001)
        XCTAssertTrue(source.words.isEmpty)
        XCTAssertEqual(LyricTimingKind.detect([source]), .line)
    }

    @MainActor
    func testRenderSweepForVisualInspection() throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_RENDER_LYRICS"] == "1" else {
            throw XCTSkip("Opt-in visual rendering")
        }
        guard #available(macOS 15.0, *) else { throw XCTSkip("Native glyph sweep requires macOS 15") }
        let source = LyricLine(timestamp: 0, text: "让你收下 我最美的年华")
        let line = LyricsDisplayTiming.line(source, nextStart: 7, trackDuration: 100)
        let content = VStack(alignment: .leading, spacing: 20) {
            ForEach([0.0, 0.22, 1.4, 3.5, 5.2, 7.0], id: \.self) { time in
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%.2f s", time)).font(.system(size: 12)).foregroundStyle(.gray)
                    TimedLyricText(line: line, time: time, active: true, baseColor: .white,
                                   pendingWordOpacity: 0.35, highlightColor: .white)
                        .font(.system(size: 32, weight: .bold)).lineLimit(2)
                }
            }
            TimedLyricText(line: LyricsDisplayTiming.line(LyricLine(timestamp: 0, text: "中文与 English words 一起换行显示，也应继续按阅读顺序扫过。"),
                                                         nextStart: 8, trackDuration: 100),
                           time: 5.4, active: true, baseColor: .white, highlightColor: .white)
                .font(.system(size: 32, weight: .bold)).lineLimit(2).minimumScaleFactor(0.7)
        }.frame(width: 560, alignment: .leading).padding(24).background(.black)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/tmp/minivoice-sweep-render.png"))
    }
}
