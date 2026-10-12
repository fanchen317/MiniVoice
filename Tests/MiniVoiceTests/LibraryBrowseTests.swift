import XCTest
import AppKit
@testable import MiniVoice

final class LibraryBrowseTests: XCTestCase {
    func testDelayedSongSnapshotInvalidatesRowEvenAtSameLibraryRevision() {
        let id = UUID()
        func key(artwork: String?, title: String = "Song") -> SongRowRenderKey {
            SongRowRenderKey(id: id, revision: 7, title: title, artist: "Artist", album: "Album", duration: 10,
                artworkKey: artwork, artworkIdentity: nil, columns: nil, selected: false,
                multiSelecting: false, playing: false, isPlaying: false, collectionsRevision: 0, destination: .all)
        }
        XCTAssertNotEqual(key(artwork: "old"), key(artwork: "new"))
        XCTAssertNotEqual(key(artwork: "old"), key(artwork: nil))
        XCTAssertNotEqual(key(artwork: "old"), key(artwork: "old", title: "Edited"))
        XCTAssertEqual(key(artwork: "new"), key(artwork: "new"))
    }
    func testAlbumSortingDoesNotReadFilesystemAndSupportsBothDirections() async {
        let entries = [entry("a", artist: "", album: "Zebra"), entry("z", artist: "", album: "Alpha")]
        let index = SongListIndex { _, _ in
            XCTFail("Album sorting must not read file dates")
            return .distantPast
        }
        let ascending = await index.orderedIDs(entries, request: SongListRequest(revision: 1, field: "album", ascending: true))
        let descending = await index.orderedIDs(entries, request: SongListRequest(revision: 1, field: "album", ascending: false))
        XCTAssertEqual(ascending, entries.reversed().map(\.id))
        XCTAssertEqual(descending, entries.map(\.id))
    }

    private func entry(_ title: String, artist: String, album: String) -> SongListEntry {
        SongListEntry(id: UUID(), url: URL(fileURLWithPath: "/\(title).mp3"), title: title, artist: artist, album: album)
    }
    func testGroupNamesMatchDetailMembershipAndResetScrollLocation() {
        let entries = [entry("a", artist: " Alice ", album: " One "), entry("b", artist: "Alice", album: "One"),
                       entry("c", artist: " ", album: "")]
        for artist in [true, false] {
            let groups = LibraryBrowseIndex.groups(entries, artist: artist, field: "name", ascending: true)
            for group in groups {
                let matching = entries.filter { LibraryBrowseIndex.name(artist ? $0.artist : $0.album, artist: artist) == group.name }
                XCTAssertEqual(Set(matching.map(\.id)), Set(group.ids))
                XCTAssertFalse(matching.isEmpty)
            }
        }
        XCTAssertNotEqual(LibraryListLocation(destination: .artists, group: nil), LibraryListLocation(destination: .artists, group: "Alice"))
        XCTAssertNotEqual(LibraryListLocation(destination: .artists, group: "Alice"), LibraryListLocation(destination: .albums, group: "Alice"))
    }
    func testClassificationSortingUsesNameArtistAndCount() {
        let entries = [entry("a", artist: "Z", album: "Alpha"), entry("b", artist: "A", album: "Beta"),
                       entry("c", artist: "A", album: "Beta")]
        XCTAssertEqual(LibraryBrowseIndex.groups(entries, artist: false, field: "name", ascending: false).map(\.name), ["Beta", "Alpha"])
        XCTAssertEqual(LibraryBrowseIndex.groups(entries, artist: false, field: "artist", ascending: true).map(\.name), ["Beta", "Alpha"])
        XCTAssertEqual(LibraryBrowseIndex.groups(entries, artist: true, field: "count", ascending: false).map(\.name), ["A", "Z"])
    }
    func testSourceAddedDateHasIndependentCacheFromModifiedDate() async {
        let entries = [entry("a", artist: "", album: ""), entry("b", artist: "", album: "")]
        let index = SongListIndex { url, field in
            let first = url.lastPathComponent == "a.mp3"
            return Date(timeIntervalSince1970: field == "sourceAdded" ? (first ? 10 : 20) : (first ? 200 : 100))
        }
        let added = await index.orderedIDs(entries, request: SongListRequest(revision: 1, field: "sourceAdded", ascending: true))
        let modified = await index.orderedIDs(entries, request: SongListRequest(revision: 1, field: "added", ascending: true))
        XCTAssertEqual(added, entries.map(\.id))
        XCTAssertEqual(modified, entries.reversed().map(\.id))
    }
    @MainActor func testBrowseCardsUse512PixelArtworkNot96PixelListImage() async throws {
        let image = NSImage(size: NSSize(width: 1400, height: 1400), flipped: false) { rect in
            NSColor.systemTeal.setFill(); rect.fill(); return true
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("BrowseArt-\(UUID())")
        let track = Track(url: root.appendingPathComponent("a.mp3"), title: "", artist: "", album: "", lyrics: "", artwork: image, duration: 2)
        var snapshot = try await CachedTrack.snapshot(track: track, root: root)
        try snapshot.splitResources()
        let key = try XCTUnwrap(snapshot.artworkKey)
        defer {
            try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/List"))
            try? FileManager.default.removeItem(at: ResourceCache.url(key, kind: "Artwork/Detail"))
        }
        let largeResult = await BrowseArtworkLoader.shared.image(key, source: track.url)
        let smallResult = await ThumbnailLoader.shared.image(key, source: track.url)
        let large = try XCTUnwrap(largeResult)
        let small = try XCTUnwrap(smallResult)
        XCTAssertEqual(large.image.width, 512)
        XCTAssertEqual(small.image.width, 96)
        let row = ListArtworkLoader()
        row.load(key: key, source: track.url, browse: true)
        XCTAssertEqual(row.image?.size.width, 512)
        XCTAssertNotNil(row.currentImage(key: key, source: track.url, browse: true))
        XCTAssertNil(row.currentImage(key: "replacement", source: track.url, browse: true))
        XCTAssertNil(row.currentImage(key: nil, source: track.url, browse: true))
    }
}
