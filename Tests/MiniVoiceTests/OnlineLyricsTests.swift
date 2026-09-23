import XCTest
@testable import MiniVoice

final class OnlineLyricsTests: XCTestCase {
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
