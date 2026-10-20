import XCTest
@testable import MiniVoice

final class CacheStorageTests: XCTestCase {
    func testAllManagedCachesUseOneRoot() {
        for folder in [CacheStorage.indexes, ResourceCache.directory, CacheStorage.artworkExports] {
            XCTAssertTrue(folder.path.hasPrefix(CacheStorage.root.path + "/"))
        }
        XCTAssertTrue(PlaylistCache.indexURL(root: URL(fileURLWithPath: "/music")).path.hasPrefix(CacheStorage.root.path + "/"))
    }

    @MainActor func testMultipleMusicFoldersShareOneIndexAndEditsPreserveOtherFolder() throws {
        let first = FileManager.default.temporaryDirectory.appendingPathComponent("SingleIndexA-\(UUID())")
        let second = FileManager.default.temporaryDirectory.appendingPathComponent("SingleIndexB-\(UUID())")
        let file = PlaylistCache.indexURL(root: first)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(file, PlaylistCache.indexURL(root: second))
        let a = CachedTrack(track: Track(url: first.appendingPathComponent("a.mp3"), title: "A", artist: "Artist", album: "Album", lyrics: "", artwork: nil, duration: 3), root: first)
        let b = CachedTrack(track: Track(url: second.appendingPathComponent("b.mp3"), title: "B", artist: "Artist", album: "Album", lyrics: "", artwork: nil, duration: 4), root: second)
        try PlaylistCache(recursive: true, tracks: [a]).write(root: first)
        try PlaylistCache(recursive: false, tracks: [b]).write(root: second)
        var edited = a; edited.title = "Edited"; edited.artist = "New Artist"; edited.album = "New Album"
        try PlaylistCache(recursive: true, tracks: [edited]).write(root: first)
        XCTAssertEqual(try PlaylistCache.read(root: first, recursive: true).tracks.first?.title, "Edited")
        XCTAssertEqual(try PlaylistCache.read(root: second, recursive: false).tracks.first?.title, "B")
    }

    func testMigrationPreservesCurrentEntriesAndMovesLegacyConflictsToBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CacheMigration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old"), current = root.appendingPathComponent("new")
        let backup = root.appendingPathComponent("backup")
        try FileManager.default.createDirectory(at: old.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        let oldData = Data("old".utf8), newData = Data("new".utf8)
        try oldData.write(to: old.appendingPathComponent("same.json"))
        try newData.write(to: current.appendingPathComponent("same.json"))
        try oldData.write(to: old.appendingPathComponent("nested/cover"))
        try CacheStorage.mergeDirectory(from: old, to: current, backup: backup)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertEqual(try Data(contentsOf: current.appendingPathComponent("same.json")), newData)
        XCTAssertEqual(try Data(contentsOf: current.appendingPathComponent("nested/cover")), oldData)
        let preserved = try FileManager.default.contentsOfDirectory(at: backup, includingPropertiesForKeys: nil)
        XCTAssertEqual(preserved.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(preserved.first)), oldData)
        try CacheStorage.mergeDirectory(from: old, to: current, backup: backup)
        XCTAssertEqual(try Data(contentsOf: current.appendingPathComponent("same.json")), newData)
    }
}
