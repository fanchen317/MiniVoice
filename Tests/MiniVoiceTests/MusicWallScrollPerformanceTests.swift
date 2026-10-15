import XCTest
import Combine
@testable import MiniVoice

@MainActor
final class MusicWallScrollPerformanceTests: XCTestCase {
    func testReflowFramesOnlyInvalidateTheirOwnContent() async throws {
        let motion = MusicWallCameraMotion()
        var wallUpdates = 0
        var reflowUpdates = 0
        let wall = motion.objectWillChange.sink { wallUpdates += 1 }
        let reflow = motion.reflow.$progress.dropFirst().sink { _ in reflowUpdates += 1 }
        motion.beginReflow(animated: true)
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertEqual(motion.reflowProgress, 1)
        XCTAssertGreaterThan(reflowUpdates, 5)
        XCTAssertEqual(wallUpdates, 0)
        withExtendedLifetime((wall, reflow)) {}
    }

    func testFocusRefreshesContentOnArrivalEvenWithinOneCullBucket() async throws {
        let motion = MusicWallCameraMotion()
        motion.travel(to: CGSize(width: 40, height: 40), duration: 0.04)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(motion.offset, CGSize(width: 40, height: 40))
        XCTAssertEqual(motion.settledRevision, 1)
        motion.travel(to: motion.offset)
        XCTAssertEqual(motion.settledRevision, 2)
    }

    func testTranslationFramesDoNotInvalidateWallUntilCullingBoundary() {
        let motion = MusicWallCameraMotion()
        var wallUpdates = 0
        var displayUpdates = 0
        let wall = motion.objectWillChange.sink { wallUpdates += 1 }
        let display = motion.translation.$offset.dropFirst().sink { _ in displayUpdates += 1 }
        for x in 1...120 { motion.jump(to: CGSize(width: x * 8, height: 0)) }
        XCTAssertEqual(displayUpdates, 120)
        XCTAssertEqual(wallUpdates, 5)
        XCTAssertEqual(motion.offset.width, 960)
        withExtendedLifetime((wall, display)) {}
    }

    func testDraggingUsesSameIndependentTranslationAndRequestsNewTiles() {
        let motion = MusicWallCameraMotion()
        var wallUpdates = 0
        let observation = motion.objectWillChange.sink { wallUpdates += 1 }
        for x in 1...120 { motion.dragOffset = CGSize(width: x * 8, height: 0) }
        XCTAssertEqual(wallUpdates, 5)
        XCTAssertEqual(motion.translation.drag.width, 960)
        withExtendedLifetime(observation) {}
    }

    func testNewClickFreezesCameraAndReflowAtIntermediateFrame() async throws {
        let motion = MusicWallCameraMotion()
        motion.beginReflow(animated: true)
        motion.travel(to: CGSize(width: -400, height: 200), duration: 0.48)
        try await Task.sleep(for: .milliseconds(80))
        motion.freezeForInteraction()
        let offset = motion.offset
        let progress = motion.reflowProgress
        XCTAssertGreaterThan(progress, 0)
        XCTAssertLessThan(progress, 1)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(motion.offset, offset)
        XCTAssertEqual(motion.reflowProgress, progress)
        motion.beginReflow(animated: true)
        motion.travel(to: .zero, duration: 0.48)
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertEqual(motion.reflowProgress, 1)
        XCTAssertEqual(motion.offset, .zero)
    }

    func testDoubleClickKeepsOriginalTargetOnlyAtOriginalPointerPosition() {
        let origin = CGPoint(x: 500, y: 300)
        XCTAssertTrue(MusicWallClickTarget.isContinuation(clicks: 2, point: origin, previous: origin))
        XCTAssertFalse(MusicWallClickTarget.isContinuation(clicks: 1, point: origin, previous: origin))
        XCTAssertFalse(MusicWallClickTarget.isContinuation(clicks: 2, point: CGPoint(x: 530, y: 300), previous: origin))
        XCTAssertFalse(MusicWallClickTarget.isContinuation(clicks: 2, point: origin, previous: nil))
    }

    func testContinuousMouseWheelAccumulatesAndSettlesWithoutLosingDistance() async throws {
        let motion = MusicWallCameraMotion()
        for _ in 0..<12 {
            motion.wheel(by: CGSize(width: 10, height: -20))
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertGreaterThan(motion.offset.width, 0)
        XCTAssertLessThan(motion.offset.width, 120)
        try await Task.sleep(for: .milliseconds(700))
        XCTAssertEqual(motion.offset.width, 120, accuracy: 0.001)
        XCTAssertEqual(motion.offset.height, -240, accuracy: 0.001)
    }

    func testDirectTrackpadPanInterruptsMouseWheelTail() async throws {
        let motion = MusicWallCameraMotion()
        motion.wheel(by: CGSize(width: 100, height: 0))
        try await Task.sleep(for: .milliseconds(30))
        let before = motion.offset
        motion.pan(by: CGSize(width: -10, height: 20))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(motion.offset.width, before.width - 10, accuracy: 0.001)
        XCTAssertEqual(motion.offset.height, before.height + 20, accuracy: 0.001)
    }

    func testWheelBurstPublishesOnceAndPreservesAllDeltas() async throws {
        let motion = MusicWallCameraMotion()
        var updates = 0
        let observation = motion.translation.$offset.dropFirst().sink { _ in updates += 1 }
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
