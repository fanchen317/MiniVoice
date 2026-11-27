import MediaPlayer
import XCTest
@testable import MiniVoice

final class SystemMediaControlsTests: XCTestCase {
    func testNowPlayingInfoSanitizesValuesAndReflectsPlaybackRate() {
        let playing = SystemMediaControls.nowPlayingInfo(
            title: "Track A",
            artist: "Artist A",
            album: "Album A",
            duration: 215.5,
            elapsedTime: 42.0,
            isPlaying: true
        )
        XCTAssertEqual(playing[MPMediaItemPropertyTitle] as? String, "Track A")
        XCTAssertEqual(playing[MPMediaItemPropertyArtist] as? String, "Artist A")
        XCTAssertEqual(playing[MPMediaItemPropertyAlbumTitle] as? String, "Album A")
        XCTAssertEqual(playing[MPMediaItemPropertyPlaybackDuration] as? Double, 215.5)
        XCTAssertEqual(playing[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 42.0)
        XCTAssertEqual(playing[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 1.0)

        let paused = SystemMediaControls.nowPlayingInfo(
            title: "Track B",
            artist: "Artist B",
            album: "Album B",
            duration: .nan,
            elapsedTime: -5.0,
            isPlaying: false
        )
        XCTAssertEqual(paused[MPMediaItemPropertyPlaybackDuration] as? Double, 0.0)
        XCTAssertEqual(paused[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double, 0.0)
        XCTAssertEqual(paused[MPNowPlayingInfoPropertyPlaybackRate] as? Double, 0.0)
    }
}
