import XCTest
import Combine
@testable import MiniVoice

@MainActor
final class MusicWallScrollPerformanceTests: XCTestCase {
    func testWheelBurstPublishesOnceAndPreservesAllDeltas() async throws {
        let motion = MusicWallCameraMotion()
        var updates = 0
        let observation = motion.$offset.dropFirst().sink { _ in updates += 1 }
        for _ in 0..<100 { motion.pan(by: CGSize(width: 3, height: -2)) }
        XCTAssertEqual(updates, 0)
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(motion.offset, CGSize(width: 300, height: -200))
        XCTAssertEqual(updates, 1)
        withExtendedLifetime(observation) {}
    }

    func testDirectionReversalPreservesNetMovement() async throws {
        let motion = MusicWallCameraMotion()
        motion.pan(by: CGSize(width: 80, height: -120))
        motion.pan(by: CGSize(width: -110, height: 160))
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(motion.offset, CGSize(width: -30, height: 40))
    }

    func testJumpCancelsQueuedWheelMovement() async throws {
        let motion = MusicWallCameraMotion()
        motion.pan(by: CGSize(width: 100, height: 200))
        motion.jump(to: CGSize(width: 7, height: 9))
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(motion.offset, CGSize(width: 7, height: 9))
    }

    func testStopFlushesQueuedWheelMovement() async throws {
        let motion = MusicWallCameraMotion()
        motion.pan(by: CGSize(width: -30, height: 60))
        motion.stop()
        XCTAssertEqual(motion.offset, CGSize(width: -30, height: 60))
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(motion.offset, CGSize(width: -30, height: 60))
    }
}
