import XCTest
@testable import MiniVoice

final class PlayerStyleTransitionTests: XCTestCase {
    @MainActor
    func testRepeatedSwitchesKeepOnlyTheFinalToggle() async throws {
        let transition = PlayerStyleTransition()
        var switches = 0
        transition.queueSwitch { switches += 1 }
        transition.queueSwitch { switches += 1 }
        transition.finish()
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(switches, 0)
        transition.queueSwitch { switches += 1 }
        transition.queueSwitch { switches += 1 }
        transition.queueSwitch { switches += 1 }
        transition.finish()
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(switches, 1)
    }

    func testFragmentsCoverTheWindowAndStayBounded() {
        for size in [CGSize(width: 304, height: 600), CGSize(width: 1280, height: 800), CGSize(width: 3840, height: 2160)] {
            let cells = StyleFragmentMotion.cells(size: size)
            XCTAssertLessThanOrEqual(cells.count, 224)
            XCTAssertEqual(cells.reduce(CGFloat.zero) { $0 + $1.width * $1.height },
                           size.width * size.height, accuracy: 0.01)
            for cell in cells {
                XCTAssertGreaterThanOrEqual(cell.minX, 0)
                XCTAssertGreaterThanOrEqual(cell.minY, 0)
                XCTAssertLessThanOrEqual(cell.maxX, size.width + 0.001)
                XCTAssertLessThanOrEqual(cell.maxY, size.height + 0.001)
            }
        }
        XCTAssertTrue(StyleFragmentMotion.cells(size: .zero).isEmpty)
    }

    func testWaveStartsAtIconAndFinishesEveryFragment() {
        let size = CGSize(width: 1280, height: 800)
        let origin = CGPoint(x: 36, y: 60)
        let near = StyleFragmentMotion.progress(elapsed: 0.2, center: origin, origin: origin, size: size)
        let far = StyleFragmentMotion.progress(elapsed: 0.2, center: CGPoint(x: 1200, y: 760), origin: origin, size: size)
        XCTAssertGreaterThan(near, far)
        for cell in StyleFragmentMotion.cells(size: size) {
            let center = CGPoint(x: cell.midX, y: cell.midY)
            XCTAssertEqual(StyleFragmentMotion.progress(elapsed: 0, center: center, origin: origin, size: size), 0)
            XCTAssertEqual(StyleFragmentMotion.progress(elapsed: StyleFragmentMotion.duration,
                center: center, origin: origin, size: size), 1)
        }
    }
}
