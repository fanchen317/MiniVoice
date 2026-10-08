import XCTest
@testable import MiniVoice

final class PlayerControlsGeometryTests: XCTestCase {
    func testControlsStayInsidePanelAndNeverOverlapAcrossResizeRange() {
        for width in stride(from: CGFloat(280), through: 1600, by: 1) {
            let layout = PlayerControlsGeometry(width: width)
            let panel = CGRect(x: 0, y: 0, width: width, height: layout.height)
            let frames = [layout.progress, layout.buttons, layout.song, layout.output]
            for frame in frames {
                XCTAssertTrue(panel.contains(frame), "Control outside panel at width \(width): \(frame)")
            }
            for i in frames.indices {
                for j in frames.indices where j > i {
                    XCTAssertFalse(frames[i].intersects(frames[j]), "Controls overlap at width \(width)")
                }
            }
            if width <= 720 { XCTAssertEqual(layout.buttons.midX, width / 2, accuracy: 0.001) }
            if width >= 840 {
                XCTAssertEqual(layout.buttons.minX - layout.song.maxX,
                               layout.output.minX - layout.buttons.maxX, accuracy: 0.001)
            }
            XCTAssertEqual(layout.progress.minX, 12)
            XCTAssertEqual(width - layout.progress.maxX, 12)
            XCTAssertGreaterThanOrEqual(layout.buttonSpacing, 15)
        }
    }

    func testLayoutHasNoJumpAtResponsiveBoundaries() {
        for width in [CGFloat(620), 720, 840] {
            let before = PlayerControlsGeometry(width: width - 0.01)
            let after = PlayerControlsGeometry(width: width + 0.01)
            XCTAssertEqual(before.height, after.height, accuracy: 0.1)
            for (a, b) in zip([before.progress, before.buttons, before.song, before.output],
                              [after.progress, after.buttons, after.song, after.output]) {
                XCTAssertEqual(a.minX, b.minX, accuracy: 0.1)
                XCTAssertEqual(a.minY, b.minY, accuracy: 0.1)
                XCTAssertEqual(a.width, b.width, accuracy: 0.1)
            }
        }
    }

    func testWideLayoutBalancesGapsForShortAndLongSongNames() {
        for width in [CGFloat(840), 1000, 1400] {
            for songWidth in [CGFloat(100), 170, 300] {
                let layout = PlayerControlsGeometry(width: width, songIdealWidth: songWidth)
                let leftGap = layout.buttons.minX - layout.song.maxX
                let rightGap = layout.output.minX - layout.buttons.maxX
                XCTAssertEqual(leftGap, rightGap, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(leftGap, 12)
            }
        }
    }
}
