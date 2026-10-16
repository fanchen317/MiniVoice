import XCTest
@testable import MiniVoice

final class MusicWallContentTests: XCTestCase {
    func testFirstLoadedPagePositionsPlayingTrackInsteadOfPreservingEmptyCamera() {
        let empty = content([])
        XCTAssertEqual(content([song("Current")]).update(from: empty), .rebuild(preserveViewport: false))
    }

    func testSavingMetadataRefreshesCardWithoutRefocusing() {
        let original = song("Current")
        var edited = original
        edited.lyrics = "[00:00]Updated lyrics"
        edited.title = "Edited title"
        let previous = content([original])
        let refreshed = content([edited])
        XCTAssertNotEqual(previous, refreshed)
        XCTAssertEqual(refreshed.update(from: previous), .metadata)
    }

    func testSavingMetadataThatChangesSortPreservesCurrentViewport() {
        let first = song("First"), second = song("Second")
        XCTAssertEqual(content([second, first]).update(from: content([first, second])),
                       .rebuild(preserveViewport: true))
    }

    func testLoadingNewSearchWaitsForMatchingSnapshotBeforeRebuilding() {
        let previous = content([song("Current")])
        let loading = MusicWallContent(tracks: [], groups: [], isGrouping: false, query: "Other", isReady: false)
        XCTAssertEqual(loading.update(from: previous), .waiting)
        let result = MusicWallContent(tracks: [song("Other")], groups: [], isGrouping: false, query: "Other", isReady: true)
        XCTAssertEqual(result.update(from: previous), .rebuild(preserveViewport: false))
    }

    func testReorderedFocusKeepsSameScreenPositionAtEveryZoom() {
        let previous = CGRect(x: 100, y: 200, width: 300, height: 400)
        let current = CGRect(x: 800, y: 900, width: 200, height: 150)
        let original = CGSize(width: -40, height: 75)
        for scale: CGFloat in [0.8, 1, 1.2] {
            let offset = MusicWallCamera.preservingFocusOffset(original: original, previous: previous, current: current, scale: scale)
            XCTAssertEqual(previous.midX * scale + original.width, current.midX * scale + offset.width, accuracy: 0.001)
            XCTAssertEqual(previous.midY * scale + original.height, current.midY * scale + offset.height, accuracy: 0.001)
        }
    }

    private func song(_ title: String) -> Track {
        Track(url: URL(fileURLWithPath: "/tmp/\(title).mp3"), title: title, artist: "Artist", album: "Album",
              lyrics: "", artwork: nil, duration: 120)
    }

    private func content(_ tracks: [Track]) -> MusicWallContent {
        MusicWallContent(tracks: tracks, groups: [], isGrouping: false, query: "", isReady: true)
    }
}
