import AppKit
import SwiftUI
import XCTest
@testable import MiniVoice

@MainActor
final class MusicWallViewportRenderingTests: XCTestCase {
    func testDistantPostersRenderInViewportAfterFocusAndDrag() throws {
        let motion = MusicWallCameraMotion()
        let worldCenter = CGPoint(x: 8400, y: 5600)
        motion.jump(to: CGSize(width: 128 - worldCenter.x, height: 96 - worldCenter.y), refreshContent: true)
        for drag in [CGSize.zero, CGSize(width: 12, height: -8), CGSize(width: -20, height: 16)] {
            motion.dragOffset = drag
            let content = MusicWallViewportContent(translation: motion.translation, reflow: motion.reflow) { offset, _ in
                ZStack(alignment: .topLeading) {
                    Color.black
                    Color.green.frame(width: 40, height: 40)
                        .position(x: worldCenter.x + offset.width, y: worldCenter.y + offset.height)
                }.frame(width: 256, height: 192)
            }
            let renderer = ImageRenderer(content: content)
            renderer.scale = 1
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let pixel = try XCTUnwrap(bitmap.colorAt(x: Int(128 + drag.width), y: Int(96 + drag.height))?.usingColorSpace(.deviceRGB))
            XCTAssertGreaterThan(pixel.greenComponent, 0.4, "Focused artwork must be visible without another input event")
            XCTAssertGreaterThan(pixel.greenComponent, pixel.redComponent)
        }
    }
}
