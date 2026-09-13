import XCTest
@testable import MiniVoice

final class CacheTests: XCTestCase {
    @MainActor
    func testCacheStartupWithoutRescanningAndRefresh() async throws {
        let name = "MiniVoiceCache-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("one.wav")
        _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "1", audio.path])
        func wait(_ library: MusicLibrary) async throws {
            for _ in 0..<500 {
                if !library.isImporting { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("Library load timed out")
        }
        let library = MusicLibrary(defaults: defaults, scanOnLaunch: false)
        library.addFolders([root]); try await wait(library)
        XCTAssertEqual(library.tracks.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(PlaylistCache.filename).path))
        let data = try PlaylistCache.read(root: root, recursive: true)
        XCTAssertEqual(data.tracks.first?.path, "one.wav")
        // If launch were scanning audio, removing it would remove the row. Cached launch must not scan.
        try FileManager.default.removeItem(at: audio)
        let restored = MusicLibrary(defaults: defaults)
        try await wait(restored)
        XCTAssertEqual(restored.tracks.count, 1)
        restored.rescan(); try await wait(restored)
        XCTAssertTrue(restored.tracks.isEmpty)
        XCTAssertTrue(try PlaylistCache.read(root: root, recursive: true).tracks.isEmpty)
        try Data("invalid cache".utf8).write(to: root.appendingPathComponent(PlaylistCache.filename))
        let recovered = MusicLibrary(defaults: defaults)
        try await wait(recovered)
        XCTAssertTrue(recovered.tracks.isEmpty)
        XCTAssertNoThrow(try PlaylistCache.read(root: root, recursive: true))
    }

    func testImportedSubtitleTimingAndEnhancedLRC() {
        let source = "1\n00:00:02,500 --> 00:00:04,000\n第一行\n\n2\n00:01:02,000 --> 00:01:04,000\n第二行"
        let parsed = LRCParser.parse(LRCParser.imported(source))
        XCTAssertEqual(parsed.compactMap(\.timestamp), [2.5, 62])
        XCTAssertEqual(parsed.map(\.text), ["第一行", "第二行"])
        XCTAssertEqual(LRCParser.parse("[00:02.00]<00:02.00>你好<00:03.00>世界").first?.text, "你好世界")
        XCTAssertNil(LRCParser.parse(LRCParser.imported("纯文本歌词")).first?.timestamp)
    }

    func testUneditedArtworkPreserved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoiceCover-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("sample.mp3")
        _ = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-t", "1", url.path])
        let art = try MediaTools.run("ffmpeg", ["-v", "error", "-f", "lavfi", "-i", "color=c=red:s=600x600", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"])
        try FFMpegTagWriter.write(TagPayload(url: url, title: "before", artist: "", album: "", lyrics: "", artwork: art))
        try FFMpegTagWriter.write(TagPayload(url: url, title: "after", artist: "", album: "", lyrics: "", artwork: nil, preserveArtwork: true))
        let preserved = try MediaTools.run("ffmpeg", ["-v", "error", "-i", url.path, "-map", "0:v:0", "-c", "copy", "-f", "image2pipe", "pipe:1"])
        XCTAssertEqual(preserved, art)
    }
}
