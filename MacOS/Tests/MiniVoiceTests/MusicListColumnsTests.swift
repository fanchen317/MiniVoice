import XCTest
@testable import MiniVoice

final class MusicListColumnsTests: XCTestCase {
    func testDurationHasBreathingRoomBeforeFavorite() {
        for multi in [false, true] {
            for width in stride(from: CGFloat(740), through: 1800, by: 5) {
                let columns = MusicListColumns(width: width, multiSelecting: multi)
                XCTAssertEqual(columns.favorite.minX - columns.duration.maxX, 18, accuracy: 0.001)
                XCTAssertLessThanOrEqual(columns.album.maxX, columns.duration.minX - 8 + 0.001)
            }
        }
    }

    func testResizingWithinLayoutsDoesNotJumpText() {
        for multi in [false, true] {
            for threshold: CGFloat in [440, 520, 580, 620, 700, 780, 820] {
                let before = MusicListColumns(width: threshold - 0.001, multiSelecting: multi)
                let after = MusicListColumns(width: threshold + 0.001, multiSelecting: multi)
                for (lhs, rhs) in [(before.title, after.title), (before.artist, after.artist),
                                   (before.album, after.album), (before.favorite, after.favorite)] {
                    XCTAssertLessThan(abs(lhs.minX - rhs.minX), 0.1)
                    XCTAssertLessThan(abs(lhs.minY - rhs.minY), 0.1)
                    XCTAssertLessThan(abs(lhs.width - rhs.width), 0.1)
                }
                XCTAssertLessThan(abs(before.albumOpacity - after.albumOpacity), 0.001)
            }
        }
    }

    func testAlbumAndDurationWaitForFullSpace() {
        for multi in [false, true] {
            for width: CGFloat in [580, 620, 659.99, 660, 700, 739.99, 740, 1000] {
                let columns = MusicListColumns(width: width, multiSelecting: multi)
                XCTAssertEqual(columns.showsAlbum, width >= 660)
                XCTAssertEqual(columns.albumOpacity, width >= 660 ? 1 : 0)
                XCTAssertEqual(columns.showsDuration, width >= 740)
                XCTAssertEqual(columns.durationOpacity, width >= 740 ? 1 : 0)
            }
        }
    }

    func testEditIsHiddenUntilItsFullSpaceIsAvailable() {
        for width: CGFloat in [740, 780, 800, 819.99] {
            XCTAssertFalse(MusicListColumns(width: width, multiSelecting: false).showsEdit)
        }
        for width: CGFloat in [820, 821, 1000] {
            let columns = MusicListColumns(width: width, multiSelecting: false)
            XCTAssertTrue(columns.showsEdit)
            XCTAssertEqual(columns.editSpaceProgress, 1)
        }
    }

    func testTextColumnsRemainSeparatedThroughoutResize() {
        for multi in [false, true] {
            for width in stride(from: CGFloat(280), through: 1600, by: 1) {
                let columns = MusicListColumns(width: width, multiSelecting: multi)
                XCTAssertGreaterThanOrEqual(columns.title.width, 0)
                XCTAssertGreaterThanOrEqual(columns.artist.width, 0)
                XCTAssertGreaterThanOrEqual(columns.album.width, 0)
                XCTAssertGreaterThanOrEqual(columns.artist.minX, columns.title.maxX - 0.001)
                XCTAssertGreaterThanOrEqual(columns.album.minX, columns.artist.maxX - 0.001)
                XCTAssertLessThanOrEqual(columns.album.maxX, columns.favorite.minX - 8 + 0.001)
            }
        }
    }
}
