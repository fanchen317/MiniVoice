import XCTest
@testable import MiniVoice

final class PlayerControlsGeometryTests: XCTestCase {
    func testControlsStayInsidePanelAndNeverOverlapAcrossResizeRange() {
        for scenario in [false, true].flatMap({ expanded in
            stride(from: CGFloat(280), through: 1600, by: 1).map { (width: $0, expanded: expanded) }
        }) {
            let width = scenario.width
            let layout = PlayerControlsGeometry(width: width, expanded: scenario.expanded)
            let panel = CGRect(x: 0, y: 0, width: width, height: layout.height)
            XCTAssertLessThanOrEqual(layout.height, PlayerControlsGeometry.twoRowHeight)
            if width < PlayerControlsGeometry.singleRowMinimumWidth {
                XCTAssertEqual(layout.height, PlayerControlsGeometry.twoRowHeight)
                XCTAssertEqual(layout.artworkSize, 44)
            }
            let frames = [layout.center, layout.song, layout.output]
            for frame in frames {
                XCTAssertTrue(panel.contains(frame), "Control outside panel at width \(width): \(frame)")
            }
            for i in frames.indices {
                for j in frames.indices where j > i {
                    XCTAssertFalse(frames[i].intersects(frames[j]), "Controls overlap at width \(width)")
                }
            }
            XCTAssertEqual(layout.buttons.midX, width / 2, accuracy: 0.001)
            if width >= 680 {
                XCTAssertEqual(layout.buttons.minX - layout.song.maxX,
                               layout.output.minX - layout.buttons.maxX, accuracy: 0.001)
            }
            XCTAssertEqual(layout.progress.midX, layout.buttons.midX)
            XCTAssertLessThanOrEqual(layout.buttons.width, 300)
            XCTAssertLessThanOrEqual(layout.buttonSpacing, 26)
            XCTAssertLessThanOrEqual(layout.output.width, 240)
            if width >= 680 {
                XCTAssertEqual(layout.progress.width, 300)
            } else {
                XCTAssertEqual(layout.progress.width, width - 24)
                XCTAssertGreaterThanOrEqual(layout.output.minX - layout.song.maxX, 16)
                XCTAssertEqual(layout.output.maxX, width - 12)
            }
            XCTAssertGreaterThanOrEqual(layout.buttonSpacing, 15)
        }
    }

    func testLayoutSwitchesDirectlyAtSingleRowBoundary() {
        for expanded in [false, true] {
            let before = PlayerControlsGeometry(width: 679.99, expanded: expanded)
            let after = PlayerControlsGeometry(width: 680, expanded: expanded)
            XCTAssertEqual(before.center.minY - before.song.maxY, 8, accuracy: 0.001)
            XCTAssertEqual(before.center.width, 679.99 - 24, accuracy: 0.001)
            XCTAssertEqual(after.center.minY, after.song.minY)
            XCTAssertEqual(after.center.maxY, after.song.maxY)
            XCTAssertEqual(after.center.width, 300)
        }
    }

    func testExpandedArtworkAndBalancedWideColumns() {
        for width in [CGFloat(680), 840, 1000, 1400] {
            for expanded in [false, true] {
                let layout = PlayerControlsGeometry(width: width, expanded: expanded)
                let leftGap = layout.buttons.minX - layout.song.maxX
                let rightGap = layout.output.minX - layout.buttons.maxX
                XCTAssertEqual(leftGap, rightGap, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(leftGap, 12)
                XCTAssertEqual(layout.buttons.midX, width / 2)
                XCTAssertEqual(layout.progress.midX, layout.buttons.midX)
                XCTAssertEqual(layout.song.midY, layout.output.midY)
                XCTAssertEqual(layout.song.minY, layout.center.minY)
                XCTAssertEqual(layout.song.maxY, layout.center.maxY)
                XCTAssertEqual(layout.output.minY, layout.center.minY)
                XCTAssertEqual(layout.output.maxY, layout.center.maxY)
                XCTAssertGreaterThanOrEqual(layout.buttons.minY - layout.progress.maxY, 8)
                XCTAssertEqual(layout.artworkSize, expanded ? 96 : 82)
                XCTAssertGreaterThanOrEqual(layout.song.height, layout.artworkSize)
            }
        }
    }

    func testNarrowLayoutPlacesSongAndOutputAboveTransport() {
        for width in [CGFloat(280), 400, 540, 620] {
            for expanded in [false, true] {
                let layout = PlayerControlsGeometry(width: width, expanded: expanded)
                XCTAssertEqual(layout.song.minY, 12)
                XCTAssertEqual(layout.output.minY, 12)
                XCTAssertEqual(layout.center.minY - layout.song.maxY, 8, accuracy: 0.001)
                XCTAssertEqual(layout.center.minY - layout.output.maxY, 8, accuracy: 0.001)
            }
        }
    }
}
