import XCTest
@testable import MiniVoice

final class MusicWallLayoutTests: XCTestCase {
    func testFocusedPosterCentersInAvailableViewportAtEveryZoom() {
        let frame = CGRect(x: 820, y: -120, width: 320, height: 260)
        let viewport = CGSize(width: 1100, height: 740)
        for inset: CGFloat in [0, 274] {
            for scale: CGFloat in [0.5, 0.8, 1, 1.2] {
                let offset = MusicWallCamera.centeredOffset(frame: frame, viewport: viewport, leadingInset: inset, scale: scale)
                XCTAssertEqual(frame.midX * scale + offset.width, (viewport.width + inset) / 2, accuracy: 0.001)
                XCTAssertEqual(frame.midY * scale + offset.height, viewport.height / 2, accuracy: 0.001)
            }
        }
    }
    func testEverySongHasOneBoundedNonOverlappingPoster() {
        for width: CGFloat in [304, 800, 1280, 2560] {
            for active in [nil, 0, 19, 99] as [Int?] {
                let layout = MusicWallLayout(count: 100, activeIndex: active, width: width)
                let tiles = layout.bands.flatMap(\.tiles)
                XCTAssertEqual(Set(tiles.map(\.index)), Set(0..<100))
                XCTAssertEqual(tiles.filter { $0.slot == nil }.count, 100)
                for band in layout.bands {
                    for (index, tile) in band.tiles.enumerated() {
                        XCTAssertGreaterThanOrEqual(tile.frame.minX, 0)
                        XCTAssertGreaterThanOrEqual(tile.frame.minY, 0)
                        XCTAssertLessThanOrEqual(tile.frame.maxX, width + 0.01)
                        XCTAssertLessThanOrEqual(tile.frame.maxY, layout.bandHeight + 0.01)
                        for other in band.tiles.dropFirst(index + 1) {
                            XCTAssertFalse(tile.frame.intersects(other.frame))
                        }
                    }
                }
                if let active, let tile = tiles.first(where: { $0.index == active }) {
                    XCTAssertEqual(tile.frame.width, tile.frame.height, accuracy: 0.01)
                    XCTAssertEqual(tile.frame.height, layout.bandHeight, accuracy: 0.01)
                }
            }
        }
    }

    func testEmptyAndInvalidInputAndLargeLibrary() {
        XCTAssertTrue(MusicWallLayout(count: 0, activeIndex: nil, width: 1280).bands.isEmpty)
        XCTAssertTrue(MusicWallLayout(count: 10, activeIndex: nil, width: .nan).bands.isEmpty)
        for density: CGFloat in [0.65, 1, 1.35] {
            let layout = MusicWallLayout(count: 10_000, activeIndex: 9999, width: 1280, density: density)
            XCTAssertEqual(layout.bands.flatMap(\.tiles).filter { $0.slot == nil }.count, 10_000)
            XCTAssertLessThan(layout.bands.map { $0.tiles.count }.max() ?? 0, 40)
        }
    }

    func testStylesCycleAndKeepExistingStoredValues() {
        XCTAssertEqual(PlayerInterfaceStyle(rawValue: "simple"), .simple)
        XCTAssertEqual(PlayerInterfaceStyle(rawValue: "library"), .library)
        XCTAssertEqual(PlayerInterfaceStyle.simple.next, .library)
        XCTAssertEqual(PlayerInterfaceStyle.library.next, .wall)
        XCTAssertEqual(PlayerInterfaceStyle.wall.next, .simple)
    }
}

final class MusicWallCameraTests: XCTestCase {
    func testFocusCentersTheSamePosterWithAndWithoutSidebar() {
        let frame = CGRect(x: 1700, y: 3600, width: 200, height: 400)
        let viewport = CGSize(width: 1280, height: 800)
        for inset: CGFloat in [0, 312] {
            let offset = MusicWallCamera.centeredOffset(frame: frame, viewport: viewport, leadingInset: inset)
            XCTAssertEqual(frame.midX + offset.width, (viewport.width + inset) / 2, accuracy: 0.001)
            XCTAssertEqual(frame.midY + offset.height, viewport.height / 2, accuracy: 0.001)
        }
    }

    func testDraggingAcrossAllEdgesRepeatsWithoutMountingWholeLibrary() {
        let layout = MusicWallLayout(count: 1040, activeIndex: nil, width: 2400)
        let tiles = layout.bands.flatMap { band in
            band.tiles.map { MusicWallTile(index: $0.index, frame: $0.frame.offsetBy(dx: 0, dy: CGFloat(band.id) * (layout.bandHeight + layout.gap)), slot: $0.slot) }
        }
        let world = CGSize(width: 2405, height: CGFloat(layout.bands.count) * (layout.bandHeight + layout.gap))
        for offset in [CGSize.zero, CGSize(width: 2800, height: 1800), CGSize(width: -5800, height: -world.height - 1800)] {
            let visible = MusicWallCamera.visibleInstances(tiles: tiles, world: world,
                viewport: CGSize(width: 1280, height: 800), offset: offset, focusedID: nil)
            XCTAssertFalse(visible.isEmpty)
            XCTAssertLessThan(visible.count, 200)
            XCTAssertEqual(Set(visible.map(\.id)).count, visible.count)
        }
    }

    func testEveryRepeatingBlockHasNoUnfilledCells() {
        for count in [1, 2, 37, 1040] {
            let layout = MusicWallLayout(count: count, activeIndex: nil, width: 2400)
            let columns = 12
            let unit = (CGFloat(2400) + layout.gap) / CGFloat(columns)
            for band in layout.bands {
                for y in 0..<3 { for x in 0..<columns {
                    let center = CGPoint(x: (CGFloat(x) + 0.5) * unit, y: (CGFloat(y) + 0.5) * unit)
                    XCTAssertEqual(band.tiles.filter { $0.frame.contains(center) }.count, 1)
                } }
                XCTAssertEqual(Set(band.tiles.map(\.id)).count, band.tiles.count)
            }
        }
    }

    func testCameraDoesNotChangePosterGeometry() {
        let tile = MusicWallTile(index: 42, frame: CGRect(x: 50, y: 80, width: 200, height: 200))
        let visible = MusicWallCamera.visibleInstances(tiles: [tile], world: CGSize(width: 500, height: 500),
            viewport: CGSize(width: 800, height: 600), offset: CGSize(width: -300, height: -400), focusedID: nil)
        for instance in visible {
            XCTAssertEqual(instance.frame.size, tile.frame.size)
            XCTAssertEqual(instance.frame.minX, tile.frame.minX + CGFloat(instance.copyX) * 500)
            XCTAssertEqual(instance.frame.minY, tile.frame.minY + CGFloat(instance.copyY) * 500)
        }
    }
}

final class MusicWallReflowTests: XCTestCase {
    func testSelectedSlotExpandsInPlaceAndNeighboursRemainSeparate() {
        let layout = MusicWallLayout(count: 37, activeIndex: nil, width: 2400)
        let tiles = layout.bands[0].tiles
        let selected = tiles[3].frame
        let size = CGSize(width: 640, height: 640)
        let expanded = MusicWallReflow.frame(selected, focus: selected, size: size)
        XCTAssertEqual(expanded.midX, selected.midX, accuracy: 0.001)
        XCTAssertEqual(expanded.midY, selected.midY, accuracy: 0.001)
        XCTAssertEqual(expanded.size, size)
        let frames = tiles.map { MusicWallReflow.frame($0.frame, focus: selected, size: size) }
        for (index, frame) in frames.enumerated() {
            XCTAssertGreaterThan(frame.width, 0)
            XCTAssertGreaterThan(frame.height, 0)
            for other in frames.dropFirst(index + 1) { XCTAssertFalse(frame.intersects(other)) }
        }
    }

    func testSharedEdgesStayConnectedAndCollapseRestoresCoordinates() {
        let focus = CGRect(x: 200, y: 200, width: 200, height: 200)
        let left = CGRect(x: 0, y: 200, width: 200, height: 200)
        let right = CGRect(x: 400, y: 200, width: 200, height: 200)
        let size = CGSize(width: 600, height: 600)
        let center = MusicWallReflow.frame(focus, focus: focus, size: size)
        XCTAssertEqual(MusicWallReflow.frame(left, focus: focus, size: size).maxX, center.minX)
        XCTAssertEqual(MusicWallReflow.frame(right, focus: focus, size: size).minX, center.maxX)
        XCTAssertEqual(MusicWallReflow.frame(left, focus: nil, size: size), left)
        XCTAssertEqual(MusicWallReflow.frame(focus, focus: focus, size: focus.size), focus)
    }
}

final class MusicWallSequenceTests: XCTestCase {
    func testHorizontalPagesAdvanceAndBothDirectionsWrapAtLibraryBoundary() {
        XCTAssertEqual(MusicWallSequence.index(base: 0, horizontalCopy: 0, stride: 27, count: 1040), 0)
        XCTAssertEqual(MusicWallSequence.index(base: 0, horizontalCopy: 1, stride: 27, count: 1040), 27)
        XCTAssertEqual(MusicWallSequence.index(base: 0, horizontalCopy: 2, stride: 27, count: 1040), 54)
        XCTAssertEqual(MusicWallSequence.index(base: 0, horizontalCopy: -1, stride: 27, count: 1040), 1013)
        XCTAssertEqual(MusicWallSequence.index(base: 0, horizontalCopy: 1040, stride: 27, count: 1040), 0)
        XCTAssertNil(MusicWallSequence.index(base: 0, horizontalCopy: 1, stride: 27, count: 0))
    }

    func testHorizontalTravelCanReachEverySongInsteadOfSmallSubset() {
        let indices = (0..<1040).compactMap {
            MusicWallSequence.index(base: 0, horizontalCopy: $0, stride: 27, count: 1040)
        }
        XCTAssertEqual(Set(indices), Set(0..<1040))
    }
}

final class MusicWallSceneTests: XCTestCase {
    func testFirstSceneIsReadyWithoutWaitingForViewAppearance() {
        let scene = MusicWallScene(count: 1040, viewport: CGSize(width: 1032, height: 628), density: 1)
        let visible = MusicWallCamera.visibleInstances(tiles: scene.tiles, world: scene.world,
            viewport: CGSize(width: 1032, height: 628), offset: .zero, focusedID: nil)
        XCTAssertFalse(visible.isEmpty)
        XCTAssertEqual(scene.tiles.filter { $0.slot == nil }.count, 1040)
        XCTAssertGreaterThan(scene.world.height, 0)
    }
    func testToolsMoveAboveDockBeforeTheyOverlap() {
        for width: CGFloat in [304, 420, 800, 1280] {
            for inset: CGFloat in [0, 284] where inset < width - 240 {
                let chrome = MusicWallChromeMetrics(width: width, leadingInset: inset)
                let dockRight = (width + inset + chrome.dockWidth) / 2
                let toolsLeft = width - 112
                if !chrome.toolsAboveDock { XCTAssertGreaterThanOrEqual(toolsLeft, dockRight) }
                else { XCTAssertGreaterThan(chrome.toolsBottom, 82) }
            }
        }
    }
}

@MainActor
final class MusicWallCameraMotionTests: XCTestCase {
    func testDragReleaseDecaysAndNewPanCancelsMomentum() async throws {
        let motion = MusicWallCameraMotion()
        motion.coast(velocity: CGSize(width: 1000, height: -500))
        try await Task.sleep(for: .milliseconds(80))
        let first = motion.offset
        XCTAssertGreaterThan(first.width, 0)
        XCTAssertLessThan(first.height, 0)
        try await Task.sleep(for: .milliseconds(80))
        let second = motion.offset
        XCTAssertGreaterThan(second.width, first.width)
        XCTAssertLessThan(second.width - first.width, first.width)
        motion.pan(by: CGSize(width: 10, height: 20))
        try await Task.sleep(for: .milliseconds(30))
        let stopped = motion.offset
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(motion.offset, stopped)
    }
    func testToolsReturnBesideDockWhenSpaceIsAvailable() {
        XCTAssertTrue(MusicWallChromeMetrics(width: 600, leadingInset: 0).toolsAboveDock)
        XCTAssertFalse(MusicWallChromeMetrics(width: 1400, leadingInset: 260).toolsAboveDock)
    }
    func testZoomKeepsPointUnderPointerAndDoesNotRebuildGeometry() {
        let motion = MusicWallCameraMotion()
        motion.jump(to: CGSize(width: -500, height: -800))
        let anchor = CGPoint(x: 400, y: 300)
        let before = CGPoint(x: (anchor.x - motion.offset.width) / motion.scale,
                             y: (anchor.y - motion.offset.height) / motion.scale)
        motion.zoom(to: 1.5, anchor: anchor, animated: false)
        XCTAssertEqual((anchor.x - motion.offset.width) / motion.scale, before.x, accuracy: 0.001)
        XCTAssertEqual((anchor.y - motion.offset.height) / motion.scale, before.y, accuracy: 0.001)
        motion.zoom(to: 0.8, anchor: anchor, animated: false)
        XCTAssertEqual((anchor.x - motion.offset.width) / motion.scale, before.x, accuracy: 0.001)
    }
    func testLocateTravelsThroughIntermediateCoordinatesAndCanBeInterrupted() async throws {
        let motion = MusicWallCameraMotion()
        motion.travel(to: CGSize(width: -1000, height: -600), duration: 0.12)
        try await Task.sleep(for: .milliseconds(55))
        XCTAssertLessThan(motion.offset.width, 0)
        XCTAssertGreaterThan(motion.offset.width, -1000)
        motion.jump(to: CGSize(width: 30, height: 40))
        try await Task.sleep(for: .milliseconds(140))
        XCTAssertEqual(motion.offset, CGSize(width: 30, height: 40))
    }
}

final class MusicWallStabilityTests: XCTestCase {
    func testFullscreenAndWindowResizeKeepCoverGeometryStable() {
        let small = MusicWallScene(count: 100, viewport: CGSize(width: 600, height: 600), density: 1)
        let full = MusicWallScene(count: 100, viewport: CGSize(width: 2560, height: 1440), density: 1)
        XCTAssertEqual(small.tiles.map(\.frame), full.tiles.map(\.frame))
        XCTAssertEqual(small.world, full.world)
    }
    func testActualHorizontalStrideVisitsEntireLibrary() {
        let scene = MusicWallScene(count: 1040, viewport: CGSize(width: 1280, height: 800), density: 1)
        let ids = (0..<1040).compactMap {
            MusicWallSequence.index(base: 0, horizontalCopy: $0, stride: scene.horizontalStride, count: 1040)
        }
        XCTAssertEqual(Set(ids).count, 1040)
    }
    func testIntermediateReflowFramesDoNotOverlap() {
        let layout = MusicWallLayout(count: 37, activeIndex: nil, width: 1920)
        let tiles = layout.bands[0].tiles
        let oldFocus = tiles[1].frame, newFocus = tiles[3].frame
        for progress: CGFloat in [0, 0.25, 0.5, 0.75, 1] {
            let frames = tiles.map {
                MusicWallReflow.interpolate(
                    MusicWallReflow.frame($0.frame, focus: oldFocus, size: CGSize(width: 480, height: 480)),
                    MusicWallReflow.frame($0.frame, focus: newFocus, size: CGSize(width: 480, height: 480)), progress: progress)
            }
            for (index, frame) in frames.enumerated() {
                for other in frames.dropFirst(index + 1) { XCTAssertFalse(frame.intersects(other)) }
            }
        }
    }
    @MainActor func testEveryZoomInputIsClampedToUserRange() {
        let motion = MusicWallCameraMotion()
        motion.zoom(to: 0.1, anchor: .zero, animated: false)
        XCTAssertEqual(motion.scale, 0.8)
        motion.zoom(to: 3, anchor: .zero, animated: false)
        XCTAssertEqual(motion.scale, 1.2)
    }
}
