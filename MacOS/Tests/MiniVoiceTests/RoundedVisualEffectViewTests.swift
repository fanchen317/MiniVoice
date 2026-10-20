import AppKit
import XCTest
@testable import MiniVoice

final class RoundedVisualEffectViewTests: XCTestCase {
    @MainActor
    func testMaskTracksFrameBeforeLayout() throws {
        let view = RoundedVisualEffectView()
        view.effectCornerRadius = 15
        XCTAssertNil(view.maskImage)
        for size in [NSSize(width: 320, height: 200), NSSize(width: 640, height: 400)] {
            view.setFrameSize(size)
            let mask = try XCTUnwrap(view.maskImage)
            XCTAssertEqual(mask.size, size)
            let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(mask.tiffRepresentation)))
            for point in [(0, 0), (bitmap.pixelsWide - 1, 0), (0, bitmap.pixelsHigh - 1), (bitmap.pixelsWide - 1, bitmap.pixelsHigh - 1)] {
                XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: point.0, y: point.1)).alphaComponent, 0, accuracy: 0.01)
            }
            XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)).alphaComponent, 1, accuracy: 0.01)
        }
    }

    @MainActor
    func testMaskTracksBoundsAndRadius() throws {
        let view = RoundedVisualEffectView()
        view.effectCornerRadius = 15
        view.setFrameSize(NSSize(width: 320, height: 200))
        view.setBoundsSize(NSSize(width: 200, height: 100))
        XCTAssertEqual(try XCTUnwrap(view.maskImage).size, view.bounds.size)
        view.effectCornerRadius = 0
        XCTAssertNil(view.maskImage)
        XCTAssertFalse(try XCTUnwrap(view.layer).masksToBounds)
    }
}
