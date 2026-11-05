import Foundation
import XCTest
#if canImport(CoreText) && canImport(ImageIO)
import CoreText
import ImageIO
import UniformTypeIdentifiers
#endif
@testable import MiniVoiceShared

final class ArtworkSubjectsTests: XCTestCase {
    func testExtremeCoverCropReceivesMoreDetailButNeverUpscalesSource() {
        let normal = ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(imageWidth: 2400, imageHeight: 2400, viewportWidth: 1000, viewportHeight: 1000)
        let ultraWide = ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(imageWidth: 2400, imageHeight: 2400, viewportWidth: 3440, viewportHeight: 1440)
        let portrait = ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(imageWidth: 3200, imageHeight: 1800, viewportWidth: 430, viewportHeight: 932)
        XCTAssertGreaterThan(ultraWide, normal)
        XCTAssertGreaterThanOrEqual(portrait, ultraWide)
        XCTAssertLessThanOrEqual(portrait, 1536)
        XCTAssertEqual(ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(imageWidth: 96, imageHeight: 96, viewportWidth: 3440, viewportHeight: 1440), 96)
        XCTAssertEqual(ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(imageWidth: .nan, imageHeight: 1000, viewportWidth: 0, viewportHeight: 1), 640)
    }

    func testVisionCoordinatesAreClippedThenFlippedToOrientedImageTopLeft() throws {
        let region = try XCTUnwrap(ArtworkSubjectRegion(visionRect: CGRect(x: -0.1, y: 0.7, width: 0.4, height: 0.5), kind: .face, confidence: 1.2))
        XCTAssertEqual(region.rect.minX, 0, accuracy: 0.000001)
        XCTAssertEqual(region.rect.minY, 0, accuracy: 0.000001)
        XCTAssertEqual(region.rect.width, 0.3, accuracy: 0.000001)
        XCTAssertEqual(region.rect.height, 0.3, accuracy: 0.000001)
        XCTAssertEqual(region.dictionary["face"], 1)
        XCTAssertEqual(region.confidence, 1)
        XCTAssertNil(ArtworkSubjectRegion(visionRect: CGRect(x: 1.1, y: 0, width: 0.1, height: 0.1), kind: .text, confidence: 0.9))
        XCTAssertNil(ArtworkSubjectRegion(visionRect: CGRect(x: 0, y: 0, width: 0, height: 1), kind: .text, confidence: 0.9))
    }

    func testLargeAlbumTitleSurvivesCreditLinesAndDuplicateDetections() throws {
        let title = try XCTUnwrap(ArtworkSubjectRegion(visionRect: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.14), kind: .text, confidence: 0.9))
        let duplicate = try XCTUnwrap(ArtworkSubjectRegion(visionRect: CGRect(x: 0.102, y: 0.102, width: 0.798, height: 0.138), kind: .text, confidence: 0.88))
        let credits = (0..<16).compactMap { index in
            ArtworkSubjectRegion(visionRect: CGRect(x: 0.1, y: 0.4 + Double(index) * 0.02, width: 0.2, height: 0.012), kind: .text, confidence: 0.95)
        }
        let selected = ArtworkSubjectRegion.selected(credits + [duplicate, title], limit: 8)
        XCTAssertEqual(selected.first?.rect, title.rect)
        XCTAssertEqual(selected.filter { $0.rect.intersects(title.rect) }.count, 1)
        XCTAssertEqual(selected.count, 8)
        XCTAssertTrue(ArtworkSubjectRegion.selected([title], limit: 0).isEmpty)
    }

    func testDuplicateFaceAndBodyRemainDifferentSemanticRegions() throws {
        let face = try XCTUnwrap(ArtworkSubjectRegion(visionRect: CGRect(x: 0.3, y: 0.4, width: 0.3, height: 0.4), kind: .face, confidence: 0.9))
        let body = try XCTUnwrap(ArtworkSubjectRegion(visionRect: CGRect(x: 0.3, y: 0.4, width: 0.3, height: 0.4), kind: .person, confidence: 0.9))
        let regions = ArtworkSubjectRegion.selected([face, face, body], limit: 8)
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions.filter { $0.kind == .face }.count, 1)
        XCTAssertEqual(regions.filter { $0.kind == .person }.count, 1)
    }

    func testInvalidImageReturnsNoInventedSubjects() async throws {
        let result = try await ArtworkSubjects.detect(Data("not an image".utf8), viewportWidth: 3440, viewportHeight: 1440)
        XCTAssertTrue(result.isEmpty)
    }

    #if canImport(CoreText) && canImport(ImageIO)
    func testGeneratedCoverTitleThroughActualVisionPipeline() async throws {
        guard ProcessInfo.processInfo.environment["MINIVOICE_TEST_VISION"] == "1" else {
            throw XCTSkip("Set MINIVOICE_TEST_VISION=1 to exercise local Vision with a generated cover")
        }
        let color = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                                             bytesPerRow: 1024 * 4, space: color,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 90, nil)
        let title = NSAttributedString(string: "ALBUM TITLE", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
        ])
        context.textPosition = CGPoint(x: 130, y: 750)
        CTLineDraw(CTLineCreateWithAttributedString(title), context)
        let image = try XCTUnwrap(context.makeImage()), data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let first = try await ArtworkSubjects.detect(data as Data, viewportWidth: 3440, viewportHeight: 1440)
        let second = try await ArtworkSubjects.detect(data as Data, viewportWidth: 3440, viewportHeight: 1440)
        XCTAssertEqual(first, second, "A repeated request must use the same quality-keyed analysis")
        let text = first.filter { $0["text"] == 1 }
        XCTAssertTrue(text.contains { region in
            (region["x"] ?? 1) < 0.2 && (region["width"] ?? 0) > 0.45 &&
            (region["y"] ?? 1) > 0.1 && (region["y"] ?? 1) < 0.3
        }, "Real OCR must retain the generated title at its known top-left coordinates. Actual: \(first)")
        for region in first {
            XCTAssertGreaterThanOrEqual(region["x"] ?? -1, 0)
            XCTAssertGreaterThanOrEqual(region["y"] ?? -1, 0)
            XCTAssertLessThanOrEqual((region["x"] ?? 0) + (region["width"] ?? 2), 1.000001)
            XCTAssertLessThanOrEqual((region["y"] ?? 0) + (region["height"] ?? 2), 1.000001)
        }
    }
    #endif

}
