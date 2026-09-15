import XCTest
import Combine
@testable import MiniVoice

final class PerformanceTests: XCTestCase {
    private func entry(_ name: String, artist: String = "歌手", album: String = "专辑") -> SongListEntry {
        SongListEntry(id: UUID(), url: URL(fileURLWithPath: "/missing/\(name).mp3"), title: name, artist: artist, album: album)
    }

    func testSearchSortingAndRecentOrder() async {
        let entries = [entry("歌曲10"), entry("歌曲2", artist: "Alice"), entry("歌曲1", album: "LIVE")]
        let index = SongListIndex()
        var request = SongListRequest(revision: 1, field: "title", ascending: true)
        var ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[2].id, entries[1].id, entries[0].id])
        request.ascending = false
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[0].id, entries[1].id, entries[2].id])
        request.query = "alice"
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[1].id])
        request.query = "live"
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[2].id])
        request.query = ""; request.recent = true
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, entries.map(\.id))
    }

    func testModificationDatesCachedUntilLibraryChanges() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = [root.appendingPathComponent("a"), root.appendingPathComponent("b")]
        for (i, url) in urls.enumerated() {
            try Data().write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(i + 1) * 100)], ofItemAtPath: url.path)
        }
        let entries = urls.map { SongListEntry(id: UUID(), url: $0, title: $0.lastPathComponent, artist: "", album: "") }
        let index = SongListIndex()
        var request = SongListRequest(revision: 1)
        var ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[1].id, entries[0].id])
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 300)], ofItemAtPath: urls[0].path)
        request.ascending = true
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[0].id, entries[1].id])
        request.revision = 2
        ids = await index.orderedIDs(entries, request: request)
        XCTAssertEqual(ids, [entries[1].id, entries[0].id])
    }

    @MainActor
    func testPlaybackTicksDoNotInvalidateLibrary() {
        let library = MusicLibrary(scanOnLaunch: false)
        var libraryUpdates = 0, clockUpdates = 0
        let libraryToken = library.objectWillChange.sink { libraryUpdates += 1 }
        let clockToken = library.clock.objectWillChange.sink { clockUpdates += 1 }
        for i in 1...100 { library.playbackTime = Double(i) * 0.2 }
        XCTAssertEqual(libraryUpdates, 0)
        XCTAssertEqual(clockUpdates, 100)
        XCTAssertEqual(library.playbackTime, 20)
        withExtendedLifetime((libraryToken, clockToken)) {}
    }

    @MainActor
    func testLyricsAreStableAndEditingDoesNotInvalidateOriginalCopy() {
        let original = Track(url: URL(fileURLWithPath: "/missing.mp3"), title: "", artist: "", album: "", lyrics: "[00:01]一\n[00:02]二", artwork: nil, duration: 3)
        let initial = original.lyricLines
        XCTAssertEqual(original.lyricLines, initial)
        var edited = original
        edited.lyrics = "[00:03]三"
        XCTAssertEqual(edited.lyricLines.first?.text, "三")
        XCTAssertEqual(original.lyricLines, initial)
        XCTAssertNil(MusicLibrary.activeLyricIndex(for: initial, at: 0))
        XCTAssertEqual(MusicLibrary.activeLyricIndex(for: initial, at: 2), 1)
        XCTAssertEqual(MusicLibrary.activeLyricIndex(for: initial, at: 1), 0)
    }

    func testLargeLibrarySort() async {
        let entries = (0..<10_000).reversed().map { entry("歌曲\($0)") }
        let start = ContinuousClock.now
        let ids = await SongListIndex().orderedIDs(entries, request: SongListRequest(revision: 1, field: "title", ascending: true))
        print("PERF: 10,000 song title sort: \(start.duration(to: .now))")
        XCTAssertEqual(ids.count, 10_000)
        XCTAssertEqual(ids.first, entries.last?.id)
        XCTAssertEqual(ids.last, entries.first?.id)
    }
}
