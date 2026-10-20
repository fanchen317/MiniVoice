import XCTest
@testable import MiniVoice

final class OnlineLyricsTests: XCTestCase {
    func testNetEaseSearchAndWordLyricsPreserveMetadataAndTimings() throws {
        let search = Data(#"{"code":200,"result":{"songs":[{"id":123,"name":"Numb","artists":[{"name":"Linkin Park"}],"album":{"name":"Meteora"},"duration":187520}]}}"#.utf8)
        let song = try XCTUnwrap(NetEaseLyrics.parseSearch(search).first)
        let payload: [String: Any] = ["code": 200,
            "lrc": ["lyric": "[00:21.61]I'm tired"],
            "yrc": ["lyric": "{\"t\":0,\"c\":[{\"tx\":\"作词: \"},{\"tx\":\"Artist\",\"li\":\"https://example.com\"}]}\n[21610,630](21610,180,0)I'm (21790,450,0)tired"]]
        let result = try XCTUnwrap(NetEaseLyrics.parseLyrics(JSONSerialization.data(withJSONObject: payload), song: song))
        XCTAssertEqual(result.source, "网易云")
        XCTAssertEqual(result.timingKind, .word)
        XCTAssertEqual(result.duration, 187.52)
        let lyrics = try XCTUnwrap(result.usableLyrics)
        XCTAssertFalse(lyrics.contains("https://"))
        let lines = LRCParser.parse(lyrics)
        XCTAssertEqual(lines.first?.text, "作词: Artist")
        XCTAssertEqual(lines.last?.text, "I'm tired")
        XCTAssertEqual(lines.last?.words.map(\.start), [21.61, 21.79])
        XCTAssertEqual(lines.last?.words.map(\.end), [21.79, 22.24])
    }

    func testNetEaseFallsBackAndRejectsErrorPayloads() throws {
        let song = NetEaseLyrics.Song(id: 1, name: "歌曲", artists: [], album: nil, duration: nil)
        let line = try XCTUnwrap(NetEaseLyrics.parseLyrics(Data(#"{"code":200,"yrc":{"lyric":""},"lrc":{"lyric":"[00:01.00]逐行"}}"#.utf8), song: song))
        XCTAssertEqual(line.timingKind, .line)
        let plain = try XCTUnwrap(NetEaseLyrics.parseLyrics(Data(#"{"code":200,"lrc":{"lyric":"普通文本"}}"#.utf8), song: song))
        XCTAssertEqual(plain.timingKind, .plain)
        XCTAssertNil(try NetEaseLyrics.parseLyrics(Data(#"{"code":200,"nolyric":true}"#.utf8), song: song))
        XCTAssertThrowsError(try NetEaseLyrics.parseLyrics(Data(#"{"code":403}"#.utf8), song: song))
        XCTAssertThrowsError(try NetEaseLyrics.parseSearch(Data(#"{"code":403}"#.utf8)))
    }

    func testLiveNetEaseWordLyricsWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else {
            throw XCTSkip("Set MINIVOICE_TEST_ONLINE=1 to query public lyric services")
        }
        let results = try await NetEaseLyrics.search(title: "Numb", artist: "Linkin Park", duration: 187.52)
        let match = try XCTUnwrap(results.first { $0.trackName == "Numb" && $0.artistName == "Linkin Park" && $0.timingKind == .word })
        XCTAssertTrue(LRCParser.parse(try XCTUnwrap(match.usableLyrics)).contains { $0.words.count > 5 })
    }

    func testSimplifiedVariantsPreserveTimingAndLanguage() {
        let source = "[offset:-120]\r\n[01:23.456]妳們在山峯 說愛我\r\n[01:30.00]佢喺度嘅 祂與祢"
        let result = ChineseLyricsScript.simplified(source)
        XCTAssertEqual(result, "[offset:-120]\r\n[01:23.456]你们在山峰 说爱我\r\n[01:30.00]佢喺度嘅 祂与祢")
        XCTAssertEqual(ChineseLyricsScript.simplified(result), result)
        XCTAssertEqual(ChineseLyricsScript.simplified("[00:01.00]君の夢を見た"), "[00:01.00]君の夢を見た")
        XCTAssertEqual(ChineseLyricsScript.simplified("[00:01.00]Don't leave me"), "[00:01.00]Don't leave me")
    }
    func testLiveChineseSourceWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else {
            throw XCTSkip("Set MINIVOICE_TEST_ONLINE=1 to query public lyric services")
        }
        let results = try await OnlineLyricsSearch.search(title: "庐州月", artist: "许嵩", duration: 254)
        XCTAssertTrue(results.contains { $0.source == "LrcAPI" && $0.hasTimeline })
    }

    func testTraditionalLyricsBecomeSimplifiedWithoutChangingTimestamps() throws {
        let original = "[00:12.50] 兒時鑿壁偷了誰家的光\n[00:20.00] 許嵩"
        let converted = ChineseLyricsScript.simplified(original)
        XCTAssertEqual(converted, "[00:12.50] 儿时凿壁偷了谁家的光\n[00:20.00] 许嵩")
        XCTAssertEqual(LRCParser.parse(converted).compactMap(\.timestamp), [12.5, 20])
        XCTAssertEqual(ChineseLyricsScript.traditional("许嵩"), "許嵩")
    }

    func testTraditionalTitleAndArtistRankAsEquivalent() throws {
        let payload = """
        {"id":1,"trackName":"廬州月","artistName":"許嵩","albumName":null,"duration":254,"syncedLyrics":"[00:01.00]歌詞","plainLyrics":null,"instrumental":false}
        """
        let result = try JSONDecoder().decode(OnlineLyricsResult.self, from: Data(payload.utf8))
        XCTAssertEqual(result.score(title: "庐州月", artist: "许嵩", duration: 254), 280)
    }

    func testPreviewPrefersMatchingTimedRecording() throws {
        let payload = """
        [
          {"id":1,"trackName":"Same Song","artistName":"Right Artist","albumName":"Live","duration":261,"syncedLyrics":"[00:10.00]live","plainLyrics":"live","instrumental":false},
          {"id":2,"trackName":"Same Song","artistName":"Right Artist","albumName":"Album","duration":200,"syncedLyrics":"[00:01.00]studio","plainLyrics":"studio","instrumental":false},
          {"id":3,"trackName":"Same Song","artistName":"Other Artist","albumName":null,"duration":200,"syncedLyrics":null,"plainLyrics":"text only","instrumental":false}
        ]
        """
        let results = try JSONDecoder().decode([OnlineLyricsResult].self, from: Data(payload.utf8))
        XCTAssertEqual(results.sorted { $0.score(title: "Same Song", artist: "Right Artist", duration: 200) > $1.score(title: "Same Song", artist: "Right Artist", duration: 200) }.first?.id, "lrclib:2")
        XCTAssertEqual(results[2].usableLyrics, "text only")
        XCTAssertFalse(results[2].hasTimeline)
        XCTAssertTrue(results[1].hasTimeline)
        XCTAssertEqual(results[1].usableLyrics, "[00:01.00]studio")
    }

    func testLrcAPIResultsUseDistinctSourceAndSkipEmptyLyrics() throws {
        let payload = """
        [
          {"id":"abc","title":"庐州月","artist":"许嵩","album":"寻雾启示","lrc":"[00:12.50]儿时凿壁偷了谁家的光"},
          {"id":"empty","title":"庐州月","artist":"许嵩","album":null,"lrc":null}
        ]
        """
        let results = try OnlineLyricsSearch.parseLrcAPI(Data(payload.utf8))
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "lrcapi:abc")
        XCTAssertEqual(results[0].source, "LrcAPI")
        XCTAssertTrue(results[0].hasTimeline)
    }
}
