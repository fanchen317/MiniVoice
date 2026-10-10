import XCTest
@testable import MiniVoice

final class LyricsTranslationTests: XCTestCase {
    func testTimedTranslationKeepsWordTimingAndSplitPhrases() throws {
        let original = "[00:01.00]<00:01.00>Hello <00:02.00>world<00:03.00>\n[00:05.00]Next line"
        let translation = "[00:01.10]你好世界\n[00:02.50]续译\n[00:05.00]下一行"
        let document = LyricsTranslation.attaching(translation, to: original)
        let lines = LRCParser.parse(document)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].translation, "你好世界\n续译")
        XCTAssertEqual(lines[1].translation, "下一行")
        XCTAssertEqual(lines[0].words.map(\.start), [1, 2])
        XCTAssertEqual(LyricsTranslation.original(document), original)
        XCTAssertEqual(LyricsTranslation.text(in: document), translation)
    }

    func testTranslationSurvivesOffsetsAndImport() {
        let source = LyricsTranslation.attaching("[00:01.00]你好", to: "[offset:100]\n[00:01.00]<00:01.00>Hello<00:02.00>")
        XCTAssertEqual(LRCParser.parse(source).first?.translation, "你好")
        let shifted = LRCParser.shifted(source, by: 0.5)
        XCTAssertEqual(LRCParser.parse(shifted).first?.timestamp, 1.6)
        XCTAssertEqual(LRCParser.parse(shifted).first?.translation, "你好")
        XCTAssertEqual(LRCParser.parse(LyricsTranslation.text(in: shifted) ?? "").first?.timestamp, 1.6)
        let yrc = LyricsTranslation.attaching("[00:01.00]你好", to: "[1000,1000](1000,1000,0)Hello")
        XCTAssertEqual(LRCParser.parse(LyricsText.normalized(yrc)).first?.translation, "你好")
    }

    func testMissingOrInvalidTranslationLeavesOriginalUntouched() {
        XCTAssertNil(LRCParser.parse("[00:01.00]Hello").first?.translation)
        XCTAssertNil(LRCParser.parse("[translation:aA==]\n[00:01.00]Hello").first?.translation)
        XCTAssertNil(LRCParser.parse("[translation:invalid]\n[00:01.00]Hello").first?.translation)
        let plain = LyricsTranslation.attaching("你好\n世界", to: "Hello\nWorld")
        XCTAssertEqual(LRCParser.parse(plain).map(\.translation), ["你好", "世界"])
    }

    func testNetEaseWordVersionUsesCorrespondingTranslationTimeline() throws {
        let song = NetEaseLyrics.Song(id: 1, name: "Song", artists: [], album: nil, duration: nil)
        let payload: [String: Any] = ["code": 200, "yrc": ["lyric": "[1000,1000](1000,1000,0)Hello"],
                                    "ytlrc": ["lyric": "[00:01.00]对应逐字译文"], "tlyric": ["lyric": "[00:09.00]其他版本"]]
        let result = try XCTUnwrap(NetEaseLyrics.parseLyrics(JSONSerialization.data(withJSONObject: payload), song: song))
        XCTAssertTrue(result.hasTranslation)
        XCTAssertEqual(LRCParser.parse(try XCTUnwrap(result.usableLyrics)).first?.translation, "对应逐字译文")
        let qq = try JSONSerialization.data(withJSONObject: ["retcode": 0, "lyric": "[00:01.00]Hello", "trans": "[00:01.00]你好"])
        XCTAssertEqual(LRCParser.parse(try XCTUnwrap(AdditionalLyricsSources.parseQQ(qq))).first?.translation, "你好")
    }

    func testKRCTranslationIndexesAndOffset() throws {
        let language = try JSONSerialization.data(withJSONObject: ["content": [["type": 1, "lyricContent": [["你好"], ["世界"]]]]])
        let source = "[language:\(language.base64EncodedString())]\n[offset:100]\n[1000,1000]<0,1000,0>Hello\n[3000,1000]<0,1000,0>World"
        let text = LyricsTranslation.attaching(LyricsTranslation.fromKRC(source), to: LyricsTiming.krc(source))
        XCTAssertEqual(LRCParser.parse(text).map(\.translation), ["你好", "世界"])
        XCTAssertEqual(LRCParser.parse(text).map(\.timestamp), [1.1, 3.1])
    }

    func testTranslationIsSavedWithSidecar() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = LyricsStorage.sidecarURL(for: directory.appendingPathComponent("song.mp3"))
        let source = LyricsTranslation.attaching("[00:01.00]你好", to: "[00:01.00]Hello")
        try LyricsStorage.write(source, to: url)
        XCTAssertEqual(LRCParser.parse(try XCTUnwrap(LyricsStorage.read(url))).first?.translation, "你好")
    }

    func testLiveBilingualSourcesWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else { throw XCTSkip("Enable live translation checks") }
        let netease = try await NetEaseLyrics.search(title: "Numb", artist: "Linkin Park", duration: 187.52)
        XCTAssertTrue(netease.contains { $0.hasTranslation && $0.timingKind == .word })
        let kugou = try await AdditionalLyricsSources.kugou(title: "Numb", artist: "Linkin Park", duration: 187.52)
        XCTAssertTrue(kugou.contains { $0.hasTranslation && $0.timingKind == .word })
    }
}
