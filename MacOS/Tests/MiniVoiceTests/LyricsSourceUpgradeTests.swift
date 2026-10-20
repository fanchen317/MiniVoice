import XCTest
@testable import MiniVoice

final class LyricsSourceUpgradeTests: XCTestCase {
    func testQRCIndependentCipherFixtureAndLiteralXMLNewlines() throws {
        // Synthetic lyric encrypted by an independent QRC implementation.
        let cipher = "ee7befb746f93831d42dcdf2e21f0d5d977de00c85449a7c535da3bcf1beb3cab3c931d93ce72b440bfe19313eb11e7934d2ad1d6d43e1f3ae5a311f15c7e49bb2ce50eb9d2a9cc9c04e5ca0db3b91bbf58ad5532f2866beb7c7d7a10888f81e0eb071f9ce5b07d7fac6a18fb34b2b5ed6cb2d82f6c22276"
        let lines = LRCParser.parse(try QRCLyrics.convert(QRCLyrics.decrypt(cipher)), placeholder: false)
        XCTAssertEqual(lines.map(\.text), ["你好", "结束"])
        XCTAssertEqual(lines[0].words.map(\.start), [1, 1.7])
        XCTAssertEqual(lines[1].words.first?.end, 5)
    }

    func testSearchKeepsLiveVersionAndNormalizesEquivalentTitles() {
        XCTAssertEqual(LyricsSearchText.title("杨丞琳 - 年轮说", artist: "杨丞琳"), "年轮说")
        XCTAssertEqual(LyricsSearchText.key("最佳歌手（Live）"), LyricsSearchText.key("最佳歌手 (live)"))
        let studio = OnlineLyricsResult(id: "studio", source: "test", trackName: "最佳歌手", artistName: "许嵩", albumName: nil, duration: 240, syncedLyrics: "[00:01.00]一", plainLyrics: nil)
        let live = OnlineLyricsResult(id: "live", source: "test", trackName: "最佳歌手 (Live)", artistName: "许嵩", albumName: nil, duration: 240, syncedLyrics: "[00:01.00]一", plainLyrics: nil)
        XCTAssertGreaterThan(live.score(title: "最佳歌手（Live）", artist: "许嵩", duration: 240), studio.score(title: "最佳歌手（Live）", artist: "许嵩", duration: 240))
    }

    func testTTMLRetainsWordTimesSpacesAndTranslation() throws {
        let source = """
        <tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><body><div>
        <p begin="00:01.125" end="00:03.500"><span begin="1.125s" end="2s">Hello</span> <span begin="2000ms" end="3.5s">world</span><span ttm:role="x-translation">你好世界</span><span ttm:role="x-roman">excluded</span></p>
        <p begin="00:04.000" end="00:05.000">Only line timing</p>
        </div></body></tt>
        """
        let lines = LRCParser.parse(try TTMLLyrics.convert(source), placeholder: false)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Hello world")
        XCTAssertEqual(lines[0].words.map(\.start), [1.125, 2])
        XCTAssertEqual(lines[0].words.map(\.end), [2, 3.5])
        XCTAssertEqual(lines[0].translation, "你好世界")
        XCTAssertTrue(lines[1].words.isEmpty)
        XCTAssertEqual(lines[1].timestamp, 4)
    }

    func testTTMLRejectsExternalEntitiesAndInvalidTimingDegrades() throws {
        XCTAssertThrowsError(try TTMLLyrics.convert("<!DOCTYPE tt [<!ENTITY test SYSTEM 'file:///etc/passwd'>]><tt/>"))
        let source = "<tt><body><p begin='1s' end='3s'><span begin='2s' end='3s'>一</span><span begin='1s' end='2s'>二</span></p></body></tt>"
        let line = try XCTUnwrap(LRCParser.parse(try TTMLLyrics.convert(source), placeholder: false).first)
        XCTAssertEqual(line.text, "一二")
        XCTAssertTrue(line.words.isEmpty)
    }

    func testQRCUsesTrailingAbsoluteWordTimingAndXMLAttributes() throws {
        let source = "<QrcInfos><LyricInfo><Lyric_1 LyricContent=\"[1000,2000]你(1000,500)好(1700,1300)&#10;[4000,1000]逐行\"/></LyricInfo></QrcInfos>"
        let lines = LRCParser.parse(try QRCLyrics.convert(source))
        XCTAssertEqual(lines[0].text, "你好")
        XCTAssertEqual(lines[0].words.map(\.start), [1, 1.7])
        XCTAssertEqual(lines[0].words.map(\.end), [1.5, 3])
        XCTAssertEqual(lines[1].timestamp, 4)
        XCTAssertThrowsError(try QRCLyrics.decrypt("not hex"))
        XCTAssertThrowsError(try QRCLyrics.decrypt(String(repeating: "0", count: 16)))
    }

    func testKugouPlainEnhancedResponseDoesNotRequireFmt() throws {
        let source = "[00:01.000]<00:01.000>一<00:02.000>二<00:03.000>"
        let data = try JSONSerialization.data(withJSONObject: ["status": 200, "contenttype": 2, "content": Data(source.utf8).base64EncodedString()])
        let text = try XCTUnwrap(AdditionalLyricsSources.parseKugouDownload(data))
        XCTAssertEqual(LyricTimingKind.detect(LRCParser.parse(text)), .word)
    }

    func testLiveNativeWordSourcesWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else { throw XCTSkip("Enable live lyric checks") }
        let qq = try await QQWordLyrics.search(title: "年轮说", artist: "杨丞琳", duration: 266.45)
        print("QQ native:", qq.map { "\($0.trackName):\($0.timingKind)" })
        XCTAssertTrue(qq.contains { $0.trackName == "年轮说" && $0.timingKind == .word })
        let amll = try await AMLLLyrics.search(title: "晴天", artist: "周杰伦")
        print("AMLL:", amll.map { "\($0.trackName):\($0.timingKind)" })
        XCTAssertTrue(amll.contains { $0.timingKind == .word })
        let kugou = try await AdditionalLyricsSources.kugou(title: "年轮说", artist: "杨丞琳", duration: 266.45)
        print("Kugou:", kugou.map { "\($0.trackName):\($0.timingKind)" })
        XCTAssertTrue(kugou.contains { $0.timingKind == .word })
    }
}
