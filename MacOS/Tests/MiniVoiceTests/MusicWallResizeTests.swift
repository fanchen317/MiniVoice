import XCTest
@testable import MiniVoice

final class MusicWallResizeLayoutTests: XCTestCase {
    func testSidebarRemainsBesideWallAtScreenshotWidthAndNarrower() {
        for width: CGFloat in [948, 928, 880, 840, 818] {
            let layout = MusicWallWorkspaceMetrics(width: width, sidebarVisible: true)
            XCTAssertFalse(layout.overlaysSidebar)
            XCTAssertEqual(layout.leadingInset, layout.sidebarWidth + 24)
            XCTAssertGreaterThanOrEqual(width - layout.leadingInset, 540)
        }
        XCTAssertTrue(MusicWallWorkspaceMetrics(width: 817, sidebarVisible: true).overlaysSidebar)
    }

    func testSidebarBreakpointDoesNotJumpDockOrFocusedCardCenter() {
        var previous = MusicWallViewportLayout(size: CGSize(width: 1200, height: 700),
            leadingInset: MusicWallWorkspaceMetrics(width: 1200, sidebarVisible: true).leadingInset)
        for value in stride(from: 1199, through: 304, by: -1) {
            let width = CGFloat(value)
            let inset = MusicWallWorkspaceMetrics(width: width, sidebarVisible: true).leadingInset
            let layout = MusicWallViewportLayout(size: CGSize(width: width, height: 700), leadingInset: inset)
            let delta = layout.displacement(from: previous)
            XCTAssertLessThanOrEqual(abs(delta.width), 1)
            XCTAssertLessThanOrEqual(delta.width, 0)
            XCTAssertEqual(delta.height, 0)
            previous = layout
        }
    }

    func testHiddenSidebarNeverReservesContentSpace() {
        for width: CGFloat in [304, 818, 948, 1400] {
            XCTAssertEqual(MusicWallWorkspaceMetrics(width: width, sidebarVisible: false).leadingInset, 0)
        }
    }

    func testHeaderUsesSidebarEdgeUntilExactOverlayBreakpoint() {
        for width: CGFloat in [1200, 948, 928, 840, 819, 818] {
            let layout = MusicWallWorkspaceMetrics(width: width, sidebarVisible: true)
            XCTAssertFalse(layout.overlaysSidebar)
            // The sidebar starts 12pt from the edge; leave another 12pt before
            // the complete toggle, rather than borrowing the wall's shrinking inset.
            XCTAssertEqual(layout.headerLeadingInset - (12 + layout.sidebarWidth), 12)
        }
        for width: CGFloat in [817, 805, 789, 600, 304] {
            let layout = MusicWallWorkspaceMetrics(width: width, sidebarVisible: true)
            XCTAssertTrue(layout.overlaysSidebar)
            XCTAssertEqual(layout.headerLeadingInset, 12)
        }
        XCTAssertEqual(MusicWallWorkspaceMetrics(width: 928, sidebarVisible: false).headerLeadingInset, 12)
    }

    func testNarrowingOnlyRaisesSettingsOnceWithNewSidebarBreakpoint() {
        var previous = false
        var transitions = 0
        for value in stride(from: 1300, through: 304, by: -1) {
            let width = CGFloat(value)
            let workspace = MusicWallWorkspaceMetrics(width: width, sidebarVisible: true)
            let chrome = MusicWallChromeMetrics(width: width, leadingInset: workspace.leadingInset)
            if chrome.toolsAboveDock != previous {
                transitions += 1
                XCTAssertTrue(chrome.toolsAboveDock)
            }
            previous = chrome.toolsAboveDock
        }
        XCTAssertEqual(transitions, 1)
    }

    func testDockDetailsDoNotJumpAtPreviousCompactBreakpoint() {
        let before = MusicWallDockMetrics(width: 419.9)
        let after = MusicWallDockMetrics(width: 420.1)
        XCTAssertLessThan(abs(after.detailProgress - before.detailProgress), 0.01)
        XCTAssertLessThan(abs(after.playButtonSide - before.playButtonSide), 0.1)
        XCTAssertGreaterThan(before.detailProgress, 0)
        XCTAssertLessThan(after.detailProgress, 1)
        XCTAssertEqual(MusicWallDockMetrics(width: 240).detailProgress, 0)
        XCTAssertEqual(MusicWallDockMetrics(width: 460).detailProgress, 1)
    }
}

@MainActor
final class MusicWallResizeMotionTests: XCTestCase {
    func testResizeRebasesRunningFocusWithoutRestartingItsArrival() async throws {
        let clock = MusicWallTestClock()
        let motion = clock.motion
        motion.travel(to: CGSize(width: -400, height: 200), duration: 0.2)
        for _ in 0..<3 {
            clock.advance(by: 0.04)
            let before = motion.offset
            motion.shiftViewport(by: CGSize(width: -30, height: 10))
            XCTAssertEqual(motion.offset.width, before.width - 30, accuracy: 0.001)
            XCTAssertEqual(motion.offset.height, before.height + 10, accuracy: 0.001)
        }
        clock.advance(by: 0.14)
        XCTAssertEqual(motion.offset, CGSize(width: -490, height: 230))
        XCTAssertEqual(motion.settledRevision, 1)
    }

    func testNextFocusDoesNotInheritPreviousResizeShift() async throws {
        let clock = MusicWallTestClock()
        let motion = clock.motion
        motion.shiftViewport(by: CGSize(width: -150, height: 20))
        motion.travel(to: CGSize(width: 10, height: 30), duration: 0.04)
        clock.advance(by: 0.12)
        XCTAssertEqual(motion.offset, CGSize(width: 10, height: 30))
    }
}
