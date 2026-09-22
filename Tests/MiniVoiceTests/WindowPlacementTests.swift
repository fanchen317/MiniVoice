import XCTest
@testable import MiniVoice

final class WindowPlacementTests: XCTestCase {
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 944)
    private let left = CGRect(x: -1920, y: 0, width: 1920, height: 1080)

    func testMainWindowAndLyricsKeepSecondaryDisplayCoordinates() {
        for frame in [CGRect(x: -1800, y: 160, width: 1280, height: 800),
                      CGRect(x: -1620, y: 86, width: 760, height: 118)] {
            XCTAssertEqual(WindowPlacementStore.visibleFrame(frame, screens: [main, left]), frame)
            XCTAssertEqual(WindowPlacementStore.visibleFrame(frame, screens: [left, main]), frame)
        }
    }

    func testDisconnectedDisplayFallsBackToReachablePosition() {
        let frame = CGRect(x: -1800, y: 160, width: 1280, height: 800)
        let restored = WindowPlacementStore.visibleFrame(frame, screens: [main])
        XCTAssertTrue(main.contains(restored))
        XCTAssertEqual(restored.size, frame.size)
    }

    func testWindowBelowOrAboveScreenRemainsDraggable() {
        for y: CGFloat in [-790, 1100] {
            let restored = WindowPlacementStore.visibleFrame(CGRect(x: 20, y: y, width: 1280, height: 800), screens: [main])
            XCTAssertTrue(main.contains(restored))
        }
    }

    func testPositionsPersistIndependentlyAcrossStoreInstances() throws {
        let name = "WindowPlacementTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let player = CGRect(x: -1800, y: 160, width: 1280, height: 800)
        let lyrics = CGRect(x: 200, y: 86, width: 760, height: 118)
        WindowPlacementStore(key: "player", defaults: defaults).save(player)
        WindowPlacementStore(key: "lyrics", defaults: defaults).save(lyrics)
        XCTAssertEqual(WindowPlacementStore(key: "player", defaults: defaults).load(), player)
        XCTAssertEqual(WindowPlacementStore(key: "lyrics", defaults: defaults).load(), lyrics)
        defaults.set([0, 0, -1, 800], forKey: "player")
        XCTAssertNil(WindowPlacementStore(key: "player", defaults: defaults).load())
    }
}
