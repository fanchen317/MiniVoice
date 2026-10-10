import XCTest
@testable import MiniVoice

final class WordLyricsTests: XCTestCase {
    func testEnhancedLRCUnicodeOffsetsAndEndMarkers() throws {
        let source = "[offset:-100]\n[00:10.00]<00:10.00>你<00:10.40>好 👨‍👩‍👧‍👦<00:11.00> world<00:12.00>"
        let line = try XCTUnwrap(LRCParser.parse(source).first)
        XCTAssertEqual(line.text, "你好 👨‍👩‍👧‍👦 world")
        XCTAssertEqual(line.words.map(\.start), [9.9, 10.3, 10.9])
        XCTAssertEqual(line.words.map(\.end), [10.3, 10.9, 11.9])
        XCTAssertEqual(line.endTime, 11.9)
        XCTAssertEqual(LyricTimingKind.detect([line]), .word)
        let restored = try XCTUnwrap(LRCParser.parse(LyricsTiming.encoded([line])).first)
        XCTAssertEqual(restored.text, line.text)
        XCTAssertEqual(restored.words, line.words)
    }

    func testMalformedWordsFallBackToLineAndTextIsNotLost() {
        let lines = LRCParser.parse("[00:10.00]<00:11.00>一<00:09.00>二\n[00:20.00]普通逐行")
        XCTAssertTrue(lines.allSatisfy { $0.words.isEmpty })
        XCTAssertEqual(lines.map(\.text), ["一二", "普通逐行"])
        XCTAssertEqual(LyricTimingKind.detect(lines), .line)
        XCTAssertEqual(LyricTimingKind.detect(LRCParser.parse("没有时间轴\n正常显示")), .plain)
    }

    func testRepeatedLineTimestampsShiftWordTimes() {
        let lines = LRCParser.parse("[00:10.00][00:20.00]<00:10.00>重<00:10.50>复<00:11.00>")
        XCTAssertEqual(lines.map { $0.words.map(\.start) }, [[10, 10.5], [20, 20.5]])
    }

    func testMillisecondPrecisionSurvivesSavingAndOffset() throws {
        let source = "[00:01.236]<00:01.236>你<00:01.789>好<00:02.345>"
        let lines = LRCParser.parse(source)
        XCTAssertEqual(LRCParser.parse(LyricsTiming.encoded(lines)).first?.words, lines.first?.words)
        let shifted = LRCParser.parse(LRCParser.shifted(source, by: 0.001))
        XCTAssertEqual(try XCTUnwrap(shifted.first?.words.first?.start), 1.237, accuracy: 0.00001)
    }

    func testYRCImportShiftAndSavingKeepRealDurations() throws {
        let source = "[10000,2000](10000,500,0)你(10500,1500,0)好"
        let line = try XCTUnwrap(LRCParser.parse(source).first)
        XCTAssertEqual(line.words.map(\.start), [10, 10.5])
        XCTAssertEqual(line.words.map(\.end), [10.5, 12])
        let imported = LyricsText.normalized(source)
        XCTAssertEqual(LRCParser.parse(imported).first?.words, line.words)
        let shifted = LRCParser.parse(LRCParser.shifted(source, by: 1.25))
        XCTAssertEqual(shifted.first?.words.map(\.start), [11.25, 11.75])
        XCTAssertEqual(shifted.first?.words.last?.end, 13.25)
    }

    func testMixedLyricsUseWordsOnlyWhereAvailable() {
        let lines = LRCParser.parse("[00:01.00]<00:01.00>你<00:02.00>好\n[00:04.00]没有逐字的行\n未对齐文本")
        XCTAssertEqual(LyricTimingKind.detect(lines), .word)
        XCTAssertEqual(lines[0].words.count, 2)
        XCTAssertTrue(lines[1].words.isEmpty)
        XCTAssertNil(lines[2].timestamp)
    }

    func testLRCLIBLyricsfilePreferredAndInvalidWordTextDegrades() throws {
        let yaml = """
        version: '1.0'
        lines:
          - text: 'Hello world'
            start_ms: 1000
            end_ms: 3000
            words:
              - text: 'Hello '
                start_ms: 1000
                end_ms: 2000
              - text: 'world'
                start_ms: 2100
                end_ms: 3000
        """
        let object: [String: Any] = ["id": 1, "trackName": "Song", "artistName": "Artist", "instrumental": false,
                                   "syncedLyrics": "[00:01.00]Hello world", "lyricsfile": yaml]
        let result = try JSONDecoder().decode(OnlineLyricsResult.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(result.timingKind, .word)
        let source = try XCTUnwrap(result.usableLyrics)
        XCTAssertEqual(LRCParser.parse(source).first?.words.map(\.end), [2, 3])
        XCTAssertEqual(LRCParser.parse(source).first?.words.map(\.start), [1, 2.1])
        let bad = yaml.replacingOccurrences(of: "text: 'world'", with: "text: 'different'")
        XCTAssertEqual(LyricTimingKind.detect(LRCParser.parse(try XCTUnwrap(LyricsTiming.lyricsfile(bad)))), .line)
        XCTAssertNil(LyricsTiming.lyricsfile("version: '2.0'\nplain: unsupported"))
        XCTAssertNil(LyricsTiming.lyricsfile("not: [valid yaml"))
    }

    func testOnlineYRCAndEnhancedLRCRemainAvailable() throws {
        let payload = """
        [{"id":"word","title":"歌曲","artist":"歌手","lrc":"[00:01.00]你好", "yrc":"[1000,1000](1000,500,0)你(1500,500,0)好"}]
        """
        let result = try XCTUnwrap(OnlineLyricsSearch.parseLrcAPI(Data(payload.utf8)).first)
        XCTAssertEqual(result.timingKind, .word)
        XCTAssertEqual(LRCParser.parse(try XCTUnwrap(result.usableLyrics)).first?.words.count, 2)
    }

    @MainActor func testSeekingReevaluatesActiveLine() {
        let lines = LRCParser.parse("[00:01.00]<00:01.00>一<00:02.00>二\n[00:04.00]<00:04.00>三")
        XCTAssertEqual(MusicLibrary.activeLyricIndex(for: lines, at: 4.1), 1)
        XCTAssertEqual(MusicLibrary.activeLyricIndex(for: lines, at: 1.1), 0)
        XCTAssertNil(MusicLibrary.activeLyricIndex(for: lines, at: 0))
    }
}
