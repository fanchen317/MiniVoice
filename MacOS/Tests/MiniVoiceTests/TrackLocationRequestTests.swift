import XCTest
@testable import MiniVoice

final class TrackLocationRequestTests: XCTestCase {
    func testCompletedNavigationCannotReplayAfterMetadataRefreshOrPlaybackChanges() {
        let previousSong = UUID()
        var location = TrackLocationRequest(target: previousSong)
        location.complete(location.token)

        // updateSongs only retries pending targets after a refresh. A completed
        // wall/list location must no longer point at the previously playing song.
        XCTAssertNil(location.target)
    }

    func testPreviousPageCompletionDoesNotConsumeNewPageLocation() {
        var location = TrackLocationRequest(target: UUID())
        let previousToken = location.token
        let currentSong = UUID()
        location = TrackLocationRequest(target: currentSong)

        location.complete(previousToken)
        XCTAssertEqual(location.target, currentSong)

        location.complete(location.token)
        XCTAssertNil(location.target)
    }

    func testSameTabCanRequestCurrentSongAgainAfterPlaybackChanges() {
        var location = TrackLocationRequest(target: UUID())
        let previousToken = location.token
        location.complete(previousToken)

        let currentSong = UUID()
        location = TrackLocationRequest(target: currentSong)
        XCTAssertEqual(location.target, currentSong)
        XCTAssertNotEqual(location.token, previousToken)
    }

    func testDockLocationFindsSongOutsideCurrentCollection() {
        let track = sampleTrack
        let all = LibraryListLocation(destination: .all, group: nil)
        for destination: LibraryDestination in [.favorites, .recent, .playlist(UUID())] {
            XCTAssertEqual(destination.locationForTrack(track, isFavorite: false,
                isRecent: false, isInPlaylist: false), all)
        }
    }

    func testDockLocationKeepsMatchingCollectionAndOpensArtistOrAlbum() {
        let track = sampleTrack
        let playlist = LibraryDestination.playlist(UUID())
        for destination: LibraryDestination in [.all, .favorites, .recent, playlist] {
            XCTAssertEqual(destination.locationForTrack(track, isFavorite: true,
                isRecent: true, isInPlaylist: true), LibraryListLocation(destination: destination, group: nil))
        }
        XCTAssertEqual(LibraryDestination.artists.locationForTrack(track, isFavorite: false,
            isRecent: false, isInPlaylist: false), LibraryListLocation(destination: .artists, group: "Artist"))
        XCTAssertEqual(LibraryDestination.albums.locationForTrack(track, isFavorite: false,
            isRecent: false, isInPlaylist: false), LibraryListLocation(destination: .albums, group: "Album"))
    }

    private var sampleTrack: Track {
        Track(url: URL(fileURLWithPath: "/tmp/song.mp3"), title: "Song", artist: "Artist",
              album: "Album", lyrics: "", artwork: nil, duration: 60)
    }
}
