import AppKit
import SwiftUI
import XCTest
@testable import MiniVoice

@MainActor
final class DisplaySynchronizedMotionTests: XCTestCase {
    func testCoastingMatchesAt60And120HzIncludingDroppedFrames() {
        func simulate(_ times: [Double]) -> CGSize {
            let motion = MusicWallCameraMotion(automaticallyTicks: false, now: { 10 })
            motion.coast(velocity: CGSize(width: 1800, height: -900))
            for time in times { motion.advanceFrame(at: 10 + time) }
            return motion.offset
        }
        let sixty = simulate((1...30).map { Double($0) / 60 })
        let fast = simulate((1...60).map { Double($0) / 120 })
        let stalled = simulate([0.01, 0.02, 0.2, 0.5])
        XCTAssertEqual(sixty.width, fast.width, accuracy: 0.0001)
        XCTAssertEqual(sixty.height, fast.height, accuracy: 0.0001)
        XCTAssertEqual(sixty.width, stalled.width, accuracy: 0.0001)
    }

    func testWheelDistanceAndReversalAreIndependentOfRefreshRate() {
        for rate in [60, 120] {
            let motion = MusicWallCameraMotion(automaticallyTicks: false, now: { 10 })
            for _ in 0..<100 { motion.wheel(by: CGSize(width: 3, height: -2)) }
            motion.wheel(by: CGSize(width: -90, height: 60))
            for frame in 1...rate { motion.advanceFrame(at: 10 + Double(frame) / Double(rate)) }
            XCTAssertEqual(motion.offset.width, 210, accuracy: 0.0001)
            XCTAssertEqual(motion.offset.height, -140, accuracy: 0.0001)
        }
    }

    func testFoliaReleaseProjectionCapsVectorSpeedWithoutChangingDirection() {
        let clock = MusicWallTestClock()
        let motion = clock.motion
        motion.coast(velocity: CGSize(width: 6000, height: -8000))
        clock.advance(by: 3)
        XCTAssertEqual(motion.offset.width, 720, accuracy: 0.001)
        XCTAssertEqual(motion.offset.height, -960, accuracy: 0.001)
        XCTAssertEqual(hypot(motion.offset.width, motion.offset.height), 1200, accuracy: 0.001)
    }

    func testLongWheelFrameIsCappedAndFocusCurveLandsExactly() {
        let motion = MusicWallCameraMotion(automaticallyTicks: false, now: { 10 })
        motion.wheel(by: CGSize(width: 200, height: 0))
        motion.advanceFrame(at: 15)
        XCTAssertEqual(motion.offset.width, 200 * (1 - exp(-0.05 / 0.08)), accuracy: 0.001)
        XCTAssertGreaterThan(MusicWallMotionTuning.focusProgress(0.5), 0.9)
        XCTAssertEqual(MusicWallMotionTuning.focusProgress(0), 0)
        XCTAssertEqual(MusicWallMotionTuning.focusProgress(1), 1)
        let reflow = (0...60).map { MusicWallMotionTuning.reflowProgress(Double($0) / 100) }
        XCTAssertEqual(reflow, reflow.sorted())
        XCTAssertEqual(reflow.first, 0)
        XCTAssertEqual(reflow.last, 1)
    }

    func testNativeProjectionMovesWithoutRebuildingPostersAndRebasesWithoutJump() async throws {
        typealias Viewport = MusicWallCompositedViewport<AnyView>
        let motion = MusicWallCameraMotion(automaticallyTicks: false)
        let size = CGSize(width: 256, height: 192)
        let padding = Viewport.overscan
        let documentSize = CGSize(width: size.width + padding * 2, height: size.height + padding * 2)
        let worldCenter = CGPoint(x: 8400, y: 5600)
        let initial = CGSize(width: 128 - worldCenter.x, height: 96 - worldCenter.y)
        motion.jump(to: initial)
        let surface = Viewport.Surface(frame: CGRect(origin: .zero, size: size))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = surface
        surface.bind(motion.translation)
        defer { surface.observation = nil; window.close() }
        var builds = 0
        func install(anchor: CGSize) {
            let root = Viewport.ReflowContent(reflow: motion.reflow,
                offset: CGSize(width: anchor.width + padding, height: anchor.height + padding), size: documentSize,
                content: { offset, _, size in
                    builds += 1
                    return AnyView(ZStack(alignment: .topLeading) {
                        Color.black
                        Color.green.frame(width: 40, height: 40)
                            .position(x: worldCenter.x + offset.width, y: worldCenter.y + offset.height)
                    }.frame(width: size.width, height: size.height))
                })
            surface.install(root, anchor: anchor, size: documentSize)
        }
        install(anchor: initial)
        try await Task.sleep(for: .milliseconds(30))
        let before = builds
        for x in 1...120 { motion.dragOffset = CGSize(width: CGFloat(x), height: -20) }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(builds, before, "Translation must not evaluate the SwiftUI poster tree")
        let host = try XCTUnwrap(surface.host)
        let documentPoint = CGPoint(x: padding + 128, y: padding + 96)
        let projected = surface.convert(documentPoint, from: host)
        XCTAssertEqual(projected.x, 248, accuracy: 0.001)
        XCTAssertEqual(projected.y, 76, accuracy: 0.001)
        let anchor = CGSize(width: initial.width + 120, height: initial.height - 20)
        install(anchor: anchor)
        try await Task.sleep(for: .milliseconds(30))
        let rebasedPoint = surface.convert(CGPoint(x: padding + 248, y: padding + 76), from: host)
        XCTAssertEqual(rebasedPoint, projected, "Cull-boundary rebases must preserve the displayed position")
        // Verify the distant-world regression through the actual AppKit renderer.
        let bitmap = try XCTUnwrap(surface.bitmapImageRepForCachingDisplay(in: surface.bounds))
        surface.cacheDisplay(in: surface.bounds, to: bitmap)
        let color = try XCTUnwrap(bitmap.colorAt(x: Int(248 * CGFloat(bitmap.pixelsWide) / size.width),
                                                 y: Int(76 * CGFloat(bitmap.pixelsHigh) / size.height))?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(color.greenComponent, color.redComponent)
    }
}
