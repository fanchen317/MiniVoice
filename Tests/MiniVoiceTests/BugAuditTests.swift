import XCTest
import AppKit
@testable import MiniVoice

final class BugAuditTests: XCTestCase {
    @MainActor func testLateCacheUpdateCannotOverwriteChangedFileOrRestoreRemovedRow() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LateUpdate-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = PlaylistCache.indexURL(root: root)
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: index) }
        let audio = root.appendingPathComponent("song.mp3")
        try Data([1]).write(to: audio)
        let original = Track(url: audio, title: "原信息", artist: "", album: "", lyrics: "", artwork: nil, duration: 3)
        let stale = CachedTrack(track: original, root: root)
        try PlaylistCache(recursive: true, tracks: [stale]).write(root: root)
        try Data([1, 2]).write(to: audio)
        XCTAssertNil(try PlaylistCache.update(root: root, recursive: true, entry: stale))
        XCTAssertEqual(try PlaylistCache.read(root: root, recursive: true).tracks.first?.title, "原信息")
        let current = CachedTrack(track: original, root: root)
        XCTAssertNotNil(try PlaylistCache.update(root: root, recursive: true, entry: current))
        try PlaylistCache(recursive: true, tracks: []).write(root: root)
        XCTAssertNil(try PlaylistCache.update(root: root, recursive: true, entry: current))
        XCTAssertTrue(try PlaylistCache.read(root: root, recursive: true).tracks.isEmpty)
    }

    @MainActor func testLightweightSnapshotDoesNotCertifyChangedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StampAudit-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("song.mp3")
        try Data([1]).write(to: audio)
        let original = CachedTrack(track: Track(url: audio, title: "Original", artist: "", album: "",
            lyrics: "", artwork: nil, duration: 3), root: root)
        let light = try XCTUnwrap(original.track(root: root))
        try Data([1, 2]).write(to: audio)
        try LyricsStorage.write("新歌词", to: LyricsStorage.sidecarURL(for: audio))
        let copied = CachedTrack(track: light, root: root)
        XCTAssertEqual(copied.stamp, original.stamp)
        XCTAssertNil(copied.sidecarStamp)
        XCTAssertFalse(copied.isCurrent(root: root))
    }

    @MainActor func testCorruptArtworkCanBeRewrittenUnderSameKey() throws {
        let image = NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            NSColor.systemOrange.setFill(); rect.fill(); return true
        }
        let bytes = try XCTUnwrap(image.tiffRepresentation)
        let key = try ResourceCache.saveArtwork(bytes)
        let list = ResourceCache.url(key, kind: "Artwork/List")
        let detail = ResourceCache.url(key, kind: "Artwork/Detail")
        defer { try? FileManager.default.removeItem(at: list); try? FileManager.default.removeItem(at: detail) }
        try Data("corrupt".utf8).write(to: list)
        try Data("corrupt".utf8).write(to: detail)
        XCTAssertFalse(ResourceCache.isValidArtwork(try Data(contentsOf: list)))
        XCTAssertEqual(try ResourceCache.saveArtwork(bytes), key)
        XCTAssertTrue(ResourceCache.isValidArtwork(try Data(contentsOf: list)))
        XCTAssertTrue(ResourceCache.isValidArtwork(try Data(contentsOf: detail)))
    }

    @MainActor func testDuplicateIndexEntriesDoNotReachLibraryDictionaries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DuplicateAudit-\(UUID())")
        let index = PlaylistCache.indexURL(root: root)
        defer { try? FileManager.default.removeItem(at: index) }
        let entry = CachedTrack(track: Track(url: root.appendingPathComponent("song.mp3"), title: "", artist: "",
            album: "", lyrics: "", artwork: nil, duration: 3), root: root)
        var alias = entry; alias.path = "./song.mp3"
        var invalid = entry; invalid.path = "../outside.mp3"
        try PlaylistCache(recursive: true, tracks: [entry, entry, alias, invalid]).write(root: root)
        XCTAssertEqual(try PlaylistCache.read(root: root, recursive: true).tracks.count, 1)
    }

    func testShuffleDoesNotReturnRemovedHistory() throws {
        let ids = (0..<8).map { _ in UUID() }
        var queue = PlaybackQueue()
        queue.reset(current: ids[0], ids: ids)
        var history = [ids[0]]
        for _ in 1..<ids.count {
            history.append(try XCTUnwrap(queue.destination(current: history.last, ids: ids, mode: .shuffle)))
        }
        let current = try XCTUnwrap(history.last)
        // Remove the whole played history except current and one allowed song.
        let allowed = [ids[0], current]
        for _ in 0..<12 {
            let previous = try XCTUnwrap(queue.destination(current: current, ids: allowed, mode: .shuffle, direction: -1))
            XCTAssertTrue(allowed.contains(previous))
        }
    }

    @MainActor func testLyricsSyncComparisonHydratesLightweightTrack() async throws {
        let name = "SyncAudit-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = PlaylistCache.indexURL(root: root)
        var entry = CachedTrack(track: Track(url: root.appendingPathComponent("unavailable.mp3"),
            title: "歌曲", artist: "歌手", album: "专辑", lyrics: "[00:01]真实歌词", artwork: nil, duration: 4), root: root)
        try entry.splitResources()
        let lyricsURL = ResourceCache.url(try XCTUnwrap(entry.lyricsKey), kind: "Lyrics")
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: index)
            try? FileManager.default.removeItem(at: lyricsURL)
        }
        try PlaylistCache(recursive: true, tracks: [entry]).write(root: root)
        defaults.set([root.path], forKey: "MiniVoice.musicFolders")
        let library = MusicLibrary(defaults: defaults)
        for _ in 0..<500 where library.isImporting { try await Task.sleep(for: .milliseconds(10)) }
        let listed = try XCTUnwrap(library.tracks.first)
        XCTAssertTrue(listed.lyrics.isEmpty)
        let matching = await LyricsSyncCoordinator.currentTrack(matching: "[00:01]真实歌词", url: listed.url, library: library)
        XCTAssertEqual(matching?.lyrics, "[00:01]真实歌词")
        let stale = await LyricsSyncCoordinator.currentTrack(matching: "旧歌词", url: listed.url, library: library)
        XCTAssertNil(stale)
        library.deleteTracks(ids: [listed.id], moveFilesToTrash: false)
        let removed = await LyricsSyncCoordinator.currentTrack(matching: "[00:01]真实歌词", url: listed.url, library: library)
        XCTAssertNil(removed)
    }
}
