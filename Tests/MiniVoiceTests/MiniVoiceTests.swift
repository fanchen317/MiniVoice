import XCTest
import AVFoundation
@testable import MiniVoice

final class MiniVoiceTests: XCTestCase {
    func testMultipleTimestampsMetadataAndOffset() {
        let lines = LRCParser.parse("[ar:Artist]\n[offset:-500]\n[00:20.00][00:10.50]重复\n[00:03.00]开头")
        XCTAssertEqual(lines.map(\.text), ["开头", "重复", "重复"])
        XCTAssertEqual(lines.compactMap(\.timestamp), [2.5, 10, 19.5])
    }

    func testPlainTextAndBlankLines() {
        XCTAssertEqual(LRCParser.parse("第一行\n\n第二行").map(\.text), ["第一行", "第二行"])
        XCTAssertEqual(LRCParser.timestamped("第一行\n\n第二行"), "[00:00.00] 第一行\n[00:04.00] 第二行")
    }

    func testUnsupportedWritePreservesOriginal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-\(UUID()).wav")
        let original = Data("original".utf8)
        try original.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try FFMpegTagWriter.write(TagPayload(url: url, title: "", artist: "", album: "", lyrics: "", artwork: nil)))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testFailedWritePreservesOriginal() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-\(UUID()).mp3")
        let original = Data("not a valid audio file".utf8)
        try original.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try FFMpegTagWriter.write(TagPayload(url: url, title: "", artist: "", album: "", lyrics: "", artwork: nil)))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testTagAndArtworkRoundTrip() throws {
        _ = try MediaTools.executable("ffmpeg")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoiceTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let artwork = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "color=c=blue:s=32x32", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"])
        for ext in ["mp3", "flac", "m4a"] {
            let url = directory.appendingPathComponent("sample.\(ext)")
            _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:duration=1", url.path])
            let original = try Data(contentsOf: url)
            func audioHash() throws -> Data {
                try MediaTools.run("ffmpeg", ["-v", "error", "-i", url.path, "-map", "0:a:0", "-c", "copy", "-f", "hash", "-hash", "sha256", "pipe:1"])
            }
            let hash = try audioHash()
            for cover in [Optional(artwork), nil] {
                try FFMpegTagWriter.write(TagPayload(url: url, title: "测试歌曲", artist: "歌手甲 / 歌手乙", album: "测试专辑", lyrics: "[00:00.00] 测试歌词", artwork: cover))
                let data = try MediaTools.run("ffprobe", ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path])
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                let format = try XCTUnwrap(json["format"] as? [String: Any])
                let tags = try XCTUnwrap(format["tags"] as? [String: String]).reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
                XCTAssertEqual(tags["title"], "测试歌曲", ext)
                XCTAssertEqual(tags["artist"], "歌手甲 / 歌手乙", ext)
                XCTAssertEqual(tags["album"], "测试专辑", ext)
                XCTAssertEqual(tags["lyrics"], "[00:00.00] 测试歌词", ext)
                let streams = try XCTUnwrap(json["streams"] as? [[String: Any]])
                XCTAssertEqual(streams.filter { ($0["disposition"] as? [String: Int])?["attached_pic"] == 1 }.count, cover == nil ? 0 : 1, ext)
                XCTAssertEqual(try audioHash(), hash, "Audio stream must remain unchanged: \(ext)")
                let player = try AVAudioPlayer(contentsOf: url)
                XCTAssertGreaterThan(player.duration, 0, ext)
            }
            let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("sample.\(ext).minivoice-backup-") }
            XCTAssertEqual(backups.count, 2)
            XCTAssertTrue(try backups.contains { try Data(contentsOf: $0) == original })
        }
    }
}
