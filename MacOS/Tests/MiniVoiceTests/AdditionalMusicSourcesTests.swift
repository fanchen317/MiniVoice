import XCTest
import zlib
@testable import MiniVoice

final class AdditionalMusicSourcesTests: XCTestCase {
    func testQQAndKugouCoverOriginalURLs() throws {
        let qq = Data(#"{"code":0,"data":{"album":{"list":[{"albumMID":"abc123","albumName":"专辑","albumPic":"http://y.gtimg.cn/music/photo_new/T002R180x180M000abc123_1.jpg","singerName":"歌手"}]}}}"#.utf8)
        let cover = try XCTUnwrap(AdditionalArtworkSources.parseQQ(qq).first)
        XCTAssertEqual(cover.imageURL.absoluteString, "https://y.gtimg.cn/music/photo_new/T002M000abc123_1.jpg")
        let kg = Data(#"{"status":1,"data":{"lists":[{"albumid":1,"albumname":"专辑","singer":"歌手","img":"http://imge.kugou.com/stdmusic/240/path.jpg"}]}}"#.utf8)
        XCTAssertEqual(try AdditionalArtworkSources.parseKugou(kg).first?.imageURL.absoluteString, "https://imge.kugou.com/stdmusic/0/path.jpg")
        XCTAssertThrowsError(try AdditionalArtworkSources.parseQQ(Data(#"{"code":403}"#.utf8)))
        XCTAssertThrowsError(try AdditionalArtworkSources.parseKugou(Data(#"{"status":0}"#.utf8)))
    }

    func testQQSongSearchAndEscapedLyrics() throws {
        let search = Data(#"{"code":0,"data":{"song":{"list":[{"albummid":"abc123","albumname":"专辑","singer":[{"name":"歌手"}]}]}}}"#.utf8)
        XCTAssertEqual(try AdditionalArtworkSources.parseQQ(search).first?.artist, "歌手")
        let payload = try JSONSerialization.data(withJSONObject: ["retcode": 0, "code": 0, "lyric": "[00:01.00]第一行\\n[00:02.00]第二行"])
        let text = try XCTUnwrap(AdditionalLyricsSources.parseQQ(payload))
        XCTAssertEqual(LRCParser.parse(text).map(\.timestamp), [1, 2])
        XCTAssertEqual(LRCParser.parse(text).map(\.text), ["第一行", "第二行"])
        XCTAssertThrowsError(try AdditionalLyricsSources.parseQQ(Data(#"{"retcode":-1310}"#.utf8)))
    }

    func testKRCDecodingPreservesRelativeWordTimesAndOffset() throws {
        let source = "[offset:100]\n[1000,2000]<0,500,0>你<700,1300,0>好\n[4000,1000]逐行兜底"
        let data = try krcPayload(source)
        let text = try XCTUnwrap(AdditionalLyricsSources.parseKugouDownload(data))
        let lines = LRCParser.parse(text)
        XCTAssertEqual(LyricTimingKind.detect(lines), .word)
        XCTAssertEqual(lines[0].words.map(\.start), [1.1, 1.8])
        XCTAssertEqual(lines[0].words.map(\.end), [1.6, 3.1])
        XCTAssertEqual(lines[0].text, "你好")
        XCTAssertTrue(lines[1].words.isEmpty)
        XCTAssertEqual(lines[1].timestamp, 4.1)
    }

    func testKugouPlainLRCAndMalformedKRC() throws {
        let payload = try JSONSerialization.data(withJSONObject: ["status": 200, "fmt": "lrc", "content": Data("[00:01.00]逐行".utf8).base64EncodedString()])
        XCTAssertEqual(try AdditionalLyricsSources.parseKugouDownload(payload), "[00:01.00]逐行")
        let invalid = try JSONSerialization.data(withJSONObject: ["status": 200, "fmt": "krc", "content": Data("krc1invalid".utf8).base64EncodedString()])
        XCTAssertThrowsError(try AdditionalLyricsSources.parseKugouDownload(invalid))
        let malformed = LyricsTiming.krc("[1000,1000]<700,800,0>无效时间")
        XCTAssertEqual(LyricTimingKind.detect(LRCParser.parse(malformed)), .line)
    }

    func testLiveQQAndKugouLyricsWhenRequested() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_ONLINE"] == "1" else { throw XCTSkip("Enable online source checks") }
        let qq = try await AdditionalLyricsSources.qq(title: "Numb", artist: "Linkin Park")
        XCTAssertTrue(qq.contains { $0.source == "QQ 音乐" && $0.hasTimeline })
        let kg = try await AdditionalLyricsSources.kugou(title: "Numb", artist: "Linkin Park", duration: 187.52)
        XCTAssertTrue(kg.contains { $0.source == "酷狗音乐" && $0.timingKind == .word })
    }

    private func krcPayload(_ text: String) throws -> Data {
        let source = Array(text.utf8)
        var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(source.count))))
        var count = uLongf(compressed.count)
        XCTAssertEqual(compress(&compressed, &count, source, uLong(source.count)), Z_OK)
        let key: [UInt8] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
        let encrypted = compressed.prefix(Int(count)).enumerated().map { $0.element ^ key[$0.offset % key.count] }
        let data = Data("krc1".utf8) + Data(encrypted)
        return try JSONSerialization.data(withJSONObject: ["status": 200, "fmt": "krc", "content": data.base64EncodedString()])
    }
}
