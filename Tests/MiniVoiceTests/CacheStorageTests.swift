import XCTest
@testable import MiniVoice

final class CacheStorageTests: XCTestCase {
    func testAllManagedCachesUseOneRoot() {
        for folder in [CacheStorage.indexes, ResourceCache.directory, CacheStorage.artworkExports] {
            XCTAssertTrue(folder.path.hasPrefix(CacheStorage.root.path + "/"))
        }
        XCTAssertTrue(PlaylistCache.indexURL(root: URL(fileURLWithPath: "/music")).path.hasPrefix(CacheStorage.root.path + "/"))
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
