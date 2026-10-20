import Foundation
@testable import MiniVoice

/// Motion tests drive real frame updates without depending on a visible/unlocked
/// display. Sleeping in XCTest does not guarantee CADisplayLink will be delivered.
@MainActor
final class MusicWallTestClock {
    private var time: TimeInterval = 10
    lazy var motion = MusicWallCameraMotion(automaticallyTicks: false, now: { [unowned self] in self.time })

    func advance(by duration: TimeInterval) {
        let end = time + duration
        while time < end {
            time = min(end, time + 1.0 / 120)
            motion.advanceFrame(at: time)
        }
    }
}
