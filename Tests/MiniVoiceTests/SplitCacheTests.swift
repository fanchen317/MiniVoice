import XCTest
import AppKit
import ImageIO
@testable import MiniVoice

final class SplitCacheTests: XCTestCase {
    @MainActor func testAllPrefetchedArtworkDisplaysSynchronouslyWithoutDiskRead() async throws {
        var keys: [String] = []
        defer {
            for key in keys {
                try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/List"))
                try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/Detail"))
            }
        }
        for i in 0..<80 {
            let label = "\(UUID())-\(i)"
            let art = NSImage(size: NSSize(width: 96, height: 96), flipped: false) { rect in
                NSColor.systemBlue.setFill(); rect.fill()
                (label as NSString).draw(at: .zero, withAttributes: [.font: NSFont.systemFont(ofSize: 9)])
                return true
            }
            keys.append(try ResourceCache.saveArtwork(XCTUnwrap(art.tiffRepresentation)))
        }
        await ThumbnailLoader.shared.prefetch(keys + keys) // Duplicate album covers are decoded once.
        for key in keys {
            let cached = try XCTUnwrap(ThumbnailLoader.shared.cachedImage(key))
            XCTAssertTrue(cached.displayImage() === cached.displayImage())
            // Only the test's own thumbnail is deleted; a memory hit must not rely on its file.
            try FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/List"))
            let row = ListArtworkLoader()
            row.load(key: key, source: URL(fileURLWithPath: "/unavailable.mp3"))
            XCTAssertNotNil(row.image, "The first row render must not wait for an async completion")
            row.cancel()
            row.load(key: key, source: URL(fileURLWithPath: "/unavailable.mp3"))
            XCTAssertNotNil(row.image, "Scrolling back must display immediately")
        }
        if let path = ProcessInfo.processInfo.environment["MINIVOICE_PERF_LIBRARY_INDEX"] {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
            let rows = json["tracks"] as! [[String: Any]]
            let realKeys = rows.compactMap { $0["artworkKey"] as? String }
            let start = Date()
            await ThumbnailLoader.shared.prefetch(realKeys)
            let hits = realKeys.filter { ThumbnailLoader.shared.cachedImage($0) != nil }.count
            print("PERF: warmed \(hits)/\(realKeys.count) real library covers in \(Date().timeIntervalSince(start)) seconds")
            XCTAssertEqual(hits, realKeys.count)
        }
    }

    func testPrefetchDoesNotAttemptMissingCoverReconstruction() async {
        let missing = ResourceCache.key(UUID().uuidString)
        await ThumbnailLoader.shared.prefetch([missing])
        XCTAssertNil(ThumbnailLoader.shared.cachedImage(missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ResourceCache.url(missing, kind: "Artwork/List").path))
    }

    @MainActor func testListArtworkLoadsFromLightweightIndexAndRetriesAfterDisappearing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ListArtwork-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let artwork = NSImage(size: NSSize(width: 120, height: 80), flipped: false) { rect in
            NSColor.systemPurple.setFill(); rect.fill(); return true
        }
        var entry = CachedTrack(track: Track(url: root.appendingPathComponent("song.mp3"),
            title: "歌名", artist: "歌手", album: "专辑", lyrics: "", artwork: artwork, duration: 10), root: root)
        try entry.splitResources()
        let key = try XCTUnwrap(entry.artworkKey)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: PlaylistCache.indexURL(root: root))
            try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/List"))
            try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/Detail"))
        }
        try PlaylistCache(recursive: true, tracks: [entry]).write(root: root)
        let restored = try PlaylistCache.read(root: root, recursive: true)
        let track = try XCTUnwrap(restored.tracks.first?.track(root: root))
        XCTAssertNil(track.artwork)
        XCTAssertEqual(track.artworkKey, key)
        let loader = ListArtworkLoader()
        loader.load(key: track.artworkKey, source: track.url)
        loader.cancel() // Lazy row disappears before its actor request completes.
        loader.load(key: track.artworkKey, source: track.url)
        for _ in 0..<100 where loader.image == nil { try await Task.sleep(for: .milliseconds(10)) }
        let loaded = try XCTUnwrap(loader.image)
        XCTAssertEqual(loaded.size.width, 96)
        XCTAssertEqual(loaded.size.height, 64)
        loader.cancel()
        loader.load(key: nil, source: track.url)
        XCTAssertNil(loader.image, "A reused row must not display another song's artwork")
    }

    @MainActor func testMigrationPreservesLegacyAndLoadsOnlyReferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SplitCache-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let indexURL = PlaylistCache.indexURL(root: root)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: indexURL) }
        let legacy: [String: Any] = ["version": 1, "recursive": true, "updatedAt": Date().timeIntervalSinceReferenceDate,
            "tracks": [["path": "song.mp3", "title": "歌名", "artist": "歌手", "album": "专辑", "lyrics": "[00:01]测试\(UUID())", "duration": 3]]]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let oldURL = root.appendingPathComponent(PlaylistCache.filename)
        try data.write(to: oldURL)
        let migrated = try PlaylistCache.read(root: root, recursive: true)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(try Data(contentsOf: oldURL), data)
        let entry = try XCTUnwrap(migrated.tracks.first)
        XCTAssertNil(entry.lyrics); XCTAssertNil(entry.artwork)
        let key = try XCTUnwrap(entry.lyricsKey)
        defer { try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Lyrics")) }
        XCTAssertTrue(ResourceCache.lyrics(key)?.hasPrefix("[00:01]测试") == true)
        let track = try XCTUnwrap(entry.track(root: root))
        XCTAssertFalse(track.resourcesLoaded); XCTAssertEqual(track.lyrics, "")
        XCTAssertEqual(track.id, entry.track(root: root)?.id)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: indexURL)) as! [String: Any]
        let entries = json["tracks"] as! [[String: Any]]
        XCTAssertNil(entries[0]["lyrics"]); XCTAssertNil(entries[0]["artwork"])
    }

    @MainActor func testFingerprintAndSidecarInvalidation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SplitStamp-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("song.mp3")
        try Data([1]).write(to: audio)
        let track = Track(url: audio, title: "", artist: "", album: "", lyrics: "", artwork: nil, duration: 2)
        let cached = CachedTrack(track: track, root: root)
        XCTAssertTrue(cached.isCurrent(root: root))
        let sidecar = LyricsStorage.sidecarURL(for: audio)
        try LyricsStorage.write("歌词", to: sidecar)
        XCTAssertFalse(cached.isCurrent(root: root))
        let updated = CachedTrack(track: track, root: root)
        XCTAssertTrue(updated.isCurrent(root: root))
        try Data([1,2]).write(to: audio)
        XCTAssertFalse(updated.isCurrent(root: root))
    }

    func testThumbnailIsBoundedAndMissingResourceRecovers() async throws {
        let id = UUID().uuidString
        let image = NSImage(size: NSSize(width: 400, height: 200), flipped: false) { rect in
            NSColor.systemBlue.setFill(); rect.fill()
            (id as NSString).draw(at: .zero, withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
            return true
        }
        let data = try XCTUnwrap(image.tiffRepresentation)
        let key = try ResourceCache.saveArtwork(data)
        let list = ResourceCache.url(key, kind: "Artwork/List"), detail = ResourceCache.url(key, kind: "Artwork/Detail")
        defer { try? FileManager.default.removeItem(at: list); try? FileManager.default.removeItem(at: detail) }
        let source = try XCTUnwrap(CGImageSourceCreateWithData(try Data(contentsOf: list) as CFData, nil))
        let cg = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(cg.width, 96); XCTAssertEqual(cg.height, 48)
        try FileManager.default.removeItem(at: list)
        let recovered = await ThumbnailLoader.shared.image(key, source: URL(fileURLWithPath: "/missing.mp3"))
        XCTAssertNotNil(recovered)
        XCTAssertTrue(FileManager.default.fileExists(atPath: list.path))
        XCTAssertEqual(ResourceCache.trackID(URL(fileURLWithPath: "/a/song.mp3")), ResourceCache.trackID(URL(fileURLWithPath: "/a/song.mp3")))
        XCTAssertNotEqual(ResourceCache.trackID(URL(fileURLWithPath: "/a/song.mp3")), ResourceCache.trackID(URL(fileURLWithPath: "/b/song.mp3")))
    }
}
