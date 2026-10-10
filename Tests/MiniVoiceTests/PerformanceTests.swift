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

    func testLetterBucketSortsLettersBeforeDigitsAndSymbols() async {
        let titles = ["7 Years", "爱你没差", "(Intro)", "2002", "阿刁", "11"]
        let entries = titles.map { entry($0) }
        let byID = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($1.id, $0) })
        let index = SongListIndex()
        var request = SongListRequest(revision: 1, field: "title", ascending: true)
        var ids = await index.orderedIDs(entries, request: request)
        let ascending = ids.map { titles[byID[$0]!] }
        XCTAssertEqual(Set(ascending.prefix(2)), Set(["阿刁", "爱你没差"]))
        XCTAssertEqual(Set(ascending.suffix(4)), Set(["7 Years", "(Intro)", "2002", "11"]))
        request.ascending = false
        ids = await index.orderedIDs(entries, request: request)
        let descending = ids.map { titles[byID[$0]!] }
        XCTAssertEqual(Set(descending.prefix(4)), Set(["7 Years", "(Intro)", "2002", "11"]))
        XCTAssertEqual(Set(descending.suffix(2)), Set(["阿刁", "爱你没差"]))
    }

    func testLetterBucketAppliesToArtistSort() async {
        let artists = ["9 位", "Alice", "周杰伦"]
        let entries = artists.map { entry("t", artist: $0) }
        let byID = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($1.id, $0) })
        let index = SongListIndex()
        var request = SongListRequest(revision: 1, field: "artist", ascending: true)
        var ids = await index.orderedIDs(entries, request: request)
        let ascending = ids.map { artists[byID[$0]!] }
        XCTAssertEqual(ascending.last, "9 位")
        XCTAssertEqual(Set(ascending.prefix(2)), Set(["Alice", "周杰伦"]))
        request.ascending = false
        ids = await index.orderedIDs(entries, request: request)
        let descending = ids.map { artists[byID[$0]!] }
        XCTAssertEqual(descending.first, "9 位")
        XCTAssertEqual(Set(descending.suffix(2)), Set(["Alice", "周杰伦"]))
    }

    func testLetterBucketDoesNotAffectDateSort() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let urls = [root.appendingPathComponent("a"), root.appendingPathComponent("b")]
        for (i, url) in urls.enumerated() {
            try Data().write(to: url)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: Double(i + 1) * 100)], ofItemAtPath: url.path)
        }
        let entries = [
            SongListEntry(id: UUID(), url: urls[0], title: "9 位", artist: "", album: ""),
            SongListEntry(id: UUID(), url: urls[1], title: "阿刁", artist: "", album: "")
        ]
        let ids = await SongListIndex().orderedIDs(entries, request: SongListRequest(revision: 1, ascending: true))
        XCTAssertEqual(ids, [entries[0].id, entries[1].id])
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
    func testSearchPrefixesReuseOrderingAndRevisionInvalidatesCache() async {
        let entries = (0..<1000).map { entry("歌曲\($0)", artist: "Artist\($0 % 10)") }
        let index = SongListIndex()
        var request = SongListRequest(revision: 1, field: "title", ascending: true)
        let ordered = await index.orderedIDs(entries, request: request)
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for query in ["歌", "歌曲", "歌曲1", "ARTIST2", "不存在"] {
            request.query = query
            let actual = await index.orderedIDs(entries, request: request)
            let expected = ordered.filter { id in
                let item = byID[id]!
                return "\(item.title) \(item.artist) \(item.album)".localizedCaseInsensitiveContains(query)
            }
            XCTAssertEqual(actual, expected)
        }
        let count = await index.cachedOrderingCount
        XCTAssertEqual(count, 1, "Typing must not retain a sorted copy for every query")
        request.revision = 2
        request.query = "新歌曲"
        let updated = [entry("新歌曲")]
        let actual = await index.orderedIDs(updated, request: request)
        XCTAssertEqual(actual, updated.map(\.id))
        let updatedCount = await index.cachedOrderingCount
        XCTAssertEqual(updatedCount, 1)
    }

    func testLyricTimingIndexPreservesDuplicatesMixedLinesAndUnsortedPrecedence() {
        let cases: [[LyricLine]] = [
            [],
            [LyricLine(timestamp: nil, text: "普通文本")],
            [LyricLine(timestamp: nil, text: "说明"), LyricLine(timestamp: 1, text: "一"),
             LyricLine(timestamp: 1, text: "重复"), LyricLine(timestamp: nil, text: "未打点"),
             LyricLine(timestamp: 3, text: "三")],
            [LyricLine(timestamp: 3, text: "三"), LyricLine(timestamp: nil, text: "说明"),
             LyricLine(timestamp: 1, text: "一"), LyricLine(timestamp: 2, text: "二")]
        ]
        for lines in cases {
            let snapshot = LyricsPlaybackSnapshot(lines: lines)
            for time in [-1.0, 0, 1, 1.5, 2, 3, 10, .nan] {
                XCTAssertEqual(snapshot.activeIndex(at: time), MusicLibrary.activeLyricIndex(for: lines, at: time))
            }
        }
    }

    func testLargeLyricIndexMatchesReferenceDuringSeek() {
        let lines = (0..<10_000).map { LyricLine(timestamp: Double($0) * 0.5, text: "第\($0)句") }
        let snapshot = LyricsPlaybackSnapshot(lines: lines)
        let start = ContinuousClock.now
        var checksum = 0
        for i in 0..<100_000 { checksum += snapshot.activeIndex(at: Double(i % 10_000) * 0.5) ?? 0 }
        print("PERF: 100,000 indexed lyric lookups: \(start.duration(to: .now))")
        XCTAssertEqual(checksum, 499_950_000)
        for time in [0.0, 123.75, 4999.5, 100.0, 1.0] {
            XCTAssertEqual(snapshot.activeIndex(at: time), MusicLibrary.activeLyricIndex(for: lines, at: time))
        }
    }

}
