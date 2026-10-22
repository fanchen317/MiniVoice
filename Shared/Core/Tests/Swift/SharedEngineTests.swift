import XCTest
@testable import MiniVoiceShared
final class SharedEngineTests: XCTestCase {
    func testBilingualWordsAndPause() throws {
        let lines = try SharedEngine.parseLyrics("[offset:-100]\n[1000,4000](1000,500,0)你(2000,500,0)好\n[00:01.000]Hello")
        XCTAssertEqual(lines.count, 1); XCTAssertEqual(lines[0].ms, 900)
        XCTAssertEqual(lines[0].displayText, "你好\nHello"); XCTAssertEqual(lines[0].words[0].endMs, 1400)
    }
    func testUnicodeAndPortableState() throws {
        XCTAssertEqual(try SharedEngine.execute(["op": "artist.key", "value": "  ＪＡＹ　 Chou "]) as? String, "jay chou")
        let value = try SharedEngine.execute(["op": "page.restore", "items": ["B", "A"], "identity": "A", "index": 0, "offset": -27]) as? [String: Any]
        XCTAssertEqual(value?["index"] as? Int, 1); XCTAssertEqual(value?["offset"] as? Int, -27)
        let invalid = try SharedEngine.executeJSON("{\"version\":99,\"op\":\"lyrics.parse\"}")
        XCTAssertTrue(invalid.contains("Unsupported contract version"))
    }
}
