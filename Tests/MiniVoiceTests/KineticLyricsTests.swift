import XCTest
import SwiftUI
@testable import MiniVoice

final class KineticLyricsTests: XCTestCase {
    @MainActor
    func testRenderForVisualInspection() throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_RENDER_KINETIC"] == "1" else {
            throw XCTSkip("Opt-in visual rendering")
        }
        let suite = "MiniVoice.KineticPreview.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("kinetic", forKey: "MiniVoice.musicWallLyricsStyle")
        let track = Track(url: URL(fileURLWithPath: "/tmp/kinetic-preview.mp3"), title: "7千3百多天", artist: "林俊杰", album: "", lyrics: "[00:00.00]乐行者是我 压力不闪躲\n[00:06.00]亲爱的我话 不多", artwork: nil, duration: 223)
        let library = MusicLibrary(defaults: defaults, scanOnLaunch: false)
        library.play(track.id)
        library.playbackTime = 3.3
        for expanded in [true, false] {
            let content = MusicWallPlayer(track: track, onPlay: {}, onExpand: {}, isExpanded: expanded)
                .environmentObject(library).environmentObject(library.clock).defaultAppStorage(defaults)
                .frame(width: expanded ? 570 : 280, height: expanded ? 740 : 370)
                .background(Color(white: 0.12))
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.nsImage)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "/tmp/minivoice-kinetic-\(expanded ? "expanded" : "compact").png"))
        }
        let line = LyricsDisplayTiming.line(LyricLine(timestamp: 0, text: "下雨这天好安静"), nextStart: 6, trackDuration: 100)
        let content = VStack(spacing: 0) {
            ForEach([1.4, 3.3, 5.8], id: \.self) { time in
                KineticLyricsGlyphs(characters: KineticLyricsTiming.characters(in: line),
                    size: CGSize(width: 500, height: 180), time: time)
                    .frame(width: 500, height: 180)
            }
        }.background(Color(white: 0.08))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(image.tiffRepresentation)))
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: URL(fileURLWithPath: "/tmp/minivoice-kinetic-frames.png"))
    }

    func testSplitsWordsWithoutLosingGraphemesOrTimingGaps() {
        let line = LyricLine(timestamp: 10, text: "你好👨‍👩‍👧‍👦", words: [
            LyricWord(text: "你好", start: 10, end: 12),
            LyricWord(text: "👨‍👩‍👧‍👦", start: 15, end: 16)
        ])
        let characters = KineticLyricsTiming.characters(in: line)
        XCTAssertEqual(characters.map(\.text), ["你", "好", "👨‍👩‍👧‍👦"])
        XCTAssertEqual(characters.map(\.start), [10, 11, 15])
        XCTAssertEqual(characters.map(\.end), [11, 12, 16])
        XCTAssertEqual(line.words.count, 2)
    }

    func testMissingWordEndUsesNextBoundary() {
        let line = LyricLine(timestamp: 10, text: "你好", endTime: 14, words: [
            LyricWord(text: "你", start: 10, end: nil),
            LyricWord(text: "好", start: 12, end: nil)
        ])
        XCTAssertEqual(KineticLyricsTiming.characters(in: line).map(\.end), [12, 14])
    }

    func testLongPhrasesFitNarrowAndShortViewports() {
        let line = LyricsDisplayTiming.line(LyricLine(timestamp: 0, text: String(repeating: "创作是氧气 生活 Music ", count: 8)), nextStart: 10, trackDuration: 100)
        let characters = KineticLyricsTiming.characters(in: line)
        for size in [CGSize(width: 220, height: 140), CGSize(width: 500, height: 500), CGSize(width: 900, height: 180)] {
            let layout = KineticLyricsLayout(characters: characters, size: size)
            XCTAssertEqual(layout.glyphs.count, characters.count)
            XCTAssertGreaterThan(layout.fontSize, 0)
            for glyph in layout.glyphs {
                XCTAssertGreaterThanOrEqual(glyph.x, 0)
                XCTAssertLessThanOrEqual(glyph.x, size.width)
                XCTAssertGreaterThanOrEqual(glyph.y - layout.fontSize * 0.8, 0)
                XCTAssertLessThanOrEqual(glyph.y + layout.fontSize * 0.8, size.height)
            }
        }
    }
}
