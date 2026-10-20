import XCTest
@testable import MiniVoice

final class BrowseCardTransitionTests: XCTestCase {
    @MainActor
    func testReturnKeepsDetailUntilAnimationFinishesAndRejectsRepeatedClicks() async throws {
        let motion = BrowseCardTransition(duration: 0.03)
        let rect = CGRect(x: 20, y: 70, width: 136, height: 180)
        var preparations = 0
        var completions = 0
        motion.open(origin: rect, reduceMotion: false) { preparations += 1 }
        motion.open(origin: .zero, reduceMotion: false) { preparations += 1 }
        XCTAssertEqual(preparations, 1)
        XCTAssertEqual(motion.origin, rect)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(motion.phase, .open)
        let resized = CGRect(x: 180, y: 70, width: 140, height: 180)
        motion.close(origin: resized, reduceMotion: false) { completions += 1 }
        motion.close(origin: nil, reduceMotion: false) { completions += 1 }
        XCTAssertEqual(motion.phase, .closing)
        XCTAssertEqual(completions, 0)
        XCTAssertEqual(motion.origin, resized)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(motion.phase, .closed)
    }

    @MainActor
    func testNavigationCancelsPendingReturn() async throws {
        let motion = BrowseCardTransition(duration: 0.03)
        motion.open(origin: .zero, reduceMotion: true) {}
        try await Task.sleep(for: .milliseconds(60))
        var completed = false
        motion.close(origin: nil, reduceMotion: false) { completed = true }
        motion.reset()
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertFalse(completed)
        XCTAssertEqual(motion.phase, .closed)
        XCTAssertEqual(motion.progress, 0)
    }
}
