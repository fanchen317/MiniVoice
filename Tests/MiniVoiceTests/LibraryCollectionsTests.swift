import XCTest
@testable import MiniVoice

final class LibraryCollectionsTests: XCTestCase {
    @MainActor
    func testCollectionsSurviveReloadAndPlaylistDeletionPreservesFavorites() throws {
        let name = "MiniVoiceCollections-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryCollections(defaults: defaults)
        let path = "/Music/歌曲.flac"
        store.toggleFavorite(path)
        let id = try XCTUnwrap(store.createPlaylist(name: "  工作时听  "))
        store.add([path, path, "/Music/second.mp3"], to: id)
        let restored = LibraryCollections(defaults: defaults)
        XCTAssertTrue(restored.isFavorite(path))
        XCTAssertEqual(restored.playlists.first?.name, "工作时听")
        XCTAssertEqual(restored.playlists.first?.paths, [path, "/Music/second.mp3"])
        restored.renamePlaylist(id, name: "睡前音乐")
        restored.remove(path, from: id)
        let renamed = LibraryCollections(defaults: defaults)
        XCTAssertEqual(renamed.playlists.first?.name, "睡前音乐")
        XCTAssertEqual(renamed.playlists.first?.paths, ["/Music/second.mp3"])
        renamed.deletePlaylist(id)
        let deleted = LibraryCollections(defaults: defaults)
        XCTAssertTrue(deleted.playlists.isEmpty)
        XCTAssertTrue(deleted.isFavorite(path))
        deleted.toggleFavorite(path)
        XCTAssertFalse(LibraryCollections(defaults: defaults).isFavorite(path))
    }

    @MainActor
    func testBlankNamesAndUnknownPlaylistCannotAlterCollections() throws {
        let name = "MiniVoiceCollections-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryCollections(defaults: defaults)
        XCTAssertNil(store.createPlaylist(name: " \n "))
        let id = try XCTUnwrap(store.createPlaylist(name: "歌单"))
        store.renamePlaylist(id, name: " ")
        store.add(["/Music/one.mp3"], to: UUID())
        XCTAssertEqual(store.playlists.first?.name, "歌单")
        XCTAssertEqual(store.playlists.first?.paths, [])
    }
}
