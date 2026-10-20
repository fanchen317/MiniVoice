import AppKit
import XCTest
@testable import MiniVoice

final class ArtworkPresentationTests: XCTestCase {
    private func artwork(content: CGRect?) -> NSImage {
        let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        if let content {
            context.setFillColor(NSColor.red.cgColor)
            context.fill(content)
        }
        return NSImage(cgImage: context.makeImage()!, size: NSSize(width: 128, height: 128))
    }

    func testPairedWhiteMarginsRemovedWithoutCroppingContent() {
        let portrait = ArtworkPresentation.removingWhiteMargins(artwork(content: CGRect(x: 20, y: 0, width: 88, height: 128)))
        XCTAssertEqual(portrait.size.width, 88)
        XCTAssertEqual(portrait.size.height, 128)
        let landscape = ArtworkPresentation.removingWhiteMargins(artwork(content: CGRect(x: 0, y: 20, width: 128, height: 88)))
        XCTAssertEqual(landscape.size.width, 128)
        XCTAssertEqual(landscape.size.height, 88)
    }

    func testAmbiguousAndWhiteCoversAreUnchanged() {
        for rect in [nil, CGRect(x: 0, y: 0, width: 128, height: 128), CGRect(x: 20, y: 0, width: 108, height: 128)] {
            let source = artwork(content: rect)
            XCTAssertTrue(ArtworkPresentation.removingWhiteMargins(source) === source)
        }
    }
    func testSampledPaletteKeepsColorChannels() throws {
        let source = artwork(content: CGRect(x: 0, y: 0, width: 128, height: 128))
        let color = try XCTUnwrap(ArtworkPresentation.averageColor(of: source)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(color.redComponent, 1, accuracy: 0.02)
        XCTAssertEqual(color.greenComponent, 0, accuracy: 0.02)
        XCTAssertEqual(color.blueComponent, 0, accuracy: 0.02)
    }

    @MainActor
    func testBackdropIsBoundedCachedAndPreservesSourceAspectRatio() throws {
        let source = artwork(content: CGRect(x: 0, y: 0, width: 128, height: 128))
        source.size = NSSize(width: 256, height: 128)
        let backdrop = ArtworkPresentation.backdrop(for: source)
        XCTAssertTrue(ArtworkPresentation.backdrop(for: source) === backdrop)
        XCTAssertEqual(backdrop.size, source.size)
        let raster = try XCTUnwrap(backdrop.cgImage(forProposedRect: nil, context: nil, hints: nil))
        XCTAssertLessThanOrEqual(raster.width, 512)
        XCTAssertLessThanOrEqual(raster.height, 512)
        XCTAssertEqual(source.size, NSSize(width: 256, height: 128))
    }

}
