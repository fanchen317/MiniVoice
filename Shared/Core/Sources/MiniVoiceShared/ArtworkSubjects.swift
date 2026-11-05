import Foundation
#if canImport(Vision) && canImport(ImageIO) && canImport(CryptoKit)
import Vision
import ImageIO
import CryptoKit
#endif

/// Analysis stays in source-image coordinates. The final viewport controls the
/// sampling budget; the shared composition solver decides the visible crop.
enum ArtworkSubjectAnalysisPolicy {
    static func thumbnailMaxPixelSize(imageWidth: Double, imageHeight: Double,
                                      viewportWidth: Double?, viewportHeight: Double?) -> Int {
        guard imageWidth.isFinite, imageHeight.isFinite, imageWidth > 0, imageHeight > 0 else { return 640 }
        var visibleFraction = 1.0
        if let width = viewportWidth, let height = viewportHeight,
           width.isFinite, height.isFinite, width > 0, height > 0 {
            let sourceAspect = imageWidth / imageHeight, targetAspect = width / height
            visibleFraction = min(sourceAspect / targetAspect, targetAspect / sourceAspect)
        }
        // A 32:9 crop needs more source detail than a square cover. Keep the
        // visible strip useful for OCR/faces without decoding an unbounded original.
        let needed = 640 / sqrt(max(0.17, visibleFraction))
        let budget = [640, 768, 1024, 1536].first { Double($0) >= needed } ?? 1536
        return max(1, Int(min(Double(budget), max(imageWidth, imageHeight))))
    }
}

struct ArtworkSubjectRegion {
    enum Kind: String { case face, text, person, object, attention }
    let rect: CGRect  // Top-left origin, normalized to the complete oriented image.
    let kind: Kind
    let confidence: Double

    init?(visionRect: CGRect, kind: Kind, confidence: Double) {
        guard [visionRect.minX, visionRect.minY, visionRect.width, visionRect.height].allSatisfy({ $0.isFinite }),
              visionRect.width > 0, visionRect.height > 0, confidence.isFinite else { return nil }
        let clipped = visionRect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        rect = CGRect(x: clipped.minX, y: 1 - clipped.maxY, width: clipped.width, height: clipped.height)
        self.kind = kind
        self.confidence = min(1, max(0, confidence))
    }
    var area: Double { Double(rect.width * rect.height) }
    var importance: Double { confidence * sqrt(area) }
    var dictionary: [String: Double] {
        var value = ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width),
                     "height": Double(rect.height), "face": kind == .face ? 1.0 : 0.0, "confidence": confidence]
        switch kind {
        case .face: break
        case .text: value["text"] = 1
        case .person: value["person"] = 1
        case .object: value["saliency"] = 1
        case .attention: value["saliency"] = 1; value["attention"] = 1
        }
        return value
    }
    static func selected(_ regions: [ArtworkSubjectRegion], limit: Int) -> [ArtworkSubjectRegion] {
        guard limit > 0 else { return [] }
        var result: [ArtworkSubjectRegion] = []
        for region in regions.sorted(by: { $0.importance > $1.importance }) {
            let duplicate = result.contains { existing in
                guard existing.kind == region.kind else { return false }
                let intersection = existing.rect.intersection(region.rect)
                if intersection.isNull { return false }
                let common = Double(intersection.width * intersection.height)
                return common / max(0.000001, existing.area + region.area - common) > 0.72
            }
            if !duplicate { result.append(region) }
            if result.count >= limit { break }
        }
        return result
    }
}

/// Offline, bounded subject analysis. Cached and queued work share one utility
/// lane; neither repeated focus changes nor larger originals multiply model work.
public enum ArtworkSubjects {
    private enum AnalysisError: Error { case oversizedInput, busy, detectorsUnavailable }
    private final class Storage: @unchecked Sendable {
        let queue = DispatchQueue(label: "MiniVoice.artwork-subjects", qos: .utility)
        private let lock = NSLock()
        private var queued = 0
        // Only accessed from queue.
        var cache: [String: [[String: Double]]] = [:]
        var order: [String] = []
        func reserve() -> Bool {
            lock.lock(); defer { lock.unlock() }
            guard queued < 8 else { return false }
            queued += 1; return true
        }
        func release() { lock.lock(); queued -= 1; lock.unlock() }
        func remember(_ regions: [[String: Double]], key: String) {
            if cache[key] == nil { order.append(key) }
            cache[key] = regions
            if order.count > 48 { cache.removeValue(forKey: order.removeFirst()) }
        }
    }
    private static let storage = Storage()
    public static func detect(_ data: Data, viewportWidth: Double? = nil,
                              viewportHeight: Double? = nil) async throws -> [[String: Double]] {
        try Task.checkCancellation()
        guard data.count <= 32 * 1024 * 1024 else { throw AnalysisError.oversizedInput }
        return try await withCheckedThrowingContinuation { continuation in
            guard storage.reserve() else { continuation.resume(throwing: AnalysisError.busy); return }
            storage.queue.async {
                defer { storage.release() }
                do { continuation.resume(returning: try analyze(data, viewportWidth: viewportWidth, viewportHeight: viewportHeight)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    private static func analyze(_ data: Data, viewportWidth: Double?, viewportHeight: Double?) throws -> [[String: Double]] {
        #if canImport(Vision) && canImport(ImageIO) && canImport(CryptoKit)
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return [] }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
            let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
            let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
            let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            let rotated = (5...8).contains(orientation)
            let pixels = ArtworkSubjectAnalysisPolicy.thumbnailMaxPixelSize(
                imageWidth: rotated ? rawHeight : rawWidth, imageHeight: rotated ? rawWidth : rawHeight,
                viewportWidth: viewportWidth, viewportHeight: viewportHeight)
            let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + ":\(pixels)"
            if let cached = storage.cache[key] { return cached }
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0,
                [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                 kCGImageSourceThumbnailMaxPixelSize: pixels, kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return [] }
            let handler = VNImageRequestHandler(cgImage: image)
            var successfulDetectors = 0, failedDetectors = 0
            func perform(_ request: VNRequest) {
                do { try handler.perform([request]); successfulDetectors += 1 }
                catch { failedDetectors += 1 }
            }
            // Isolate detector failures. A stylized face or unavailable OCR language
            // must not suppress usable saliency/human results from the same cover.
            let faces = VNDetectFaceRectanglesRequest(); faces.preferBackgroundProcessing = true
            perform(faces)
            let faceRegions = (faces.results ?? []).filter { $0.confidence >= 0.45 }.compactMap {
                ArtworkSubjectRegion(visionRect: $0.boundingBox, kind: .face, confidence: Double($0.confidence))
            }
            var regions = ArtworkSubjectRegion.selected(faceRegions, limit: 8)

            let text = VNRecognizeTextRequest(); text.recognitionLevel = .accurate
            text.minimumTextHeight = Float(max(0.008, min(0.016, 8.0 / Double(max(1, image.height)))))
            if let supported = try? text.supportedRecognitionLanguages() {
                let languages = ["zh-Hans", "zh-Hant", "en-US"].filter { supported.contains($0) }
                if !languages.isEmpty { text.recognitionLanguages = languages }
            }
            text.usesLanguageCorrection = false; text.preferBackgroundProcessing = true
            perform(text)
            // Sort by confidence and visual area, not OCR reading order. Otherwise
            // eight tiny credit lines can displace the large album title below them.
            let textRegions = (text.results ?? []).filter { ($0.topCandidates(1).first?.confidence ?? 0) >= 0.5 }.compactMap {
                ArtworkSubjectRegion(visionRect: $0.boundingBox, kind: .text, confidence: Double($0.topCandidates(1).first?.confidence ?? 0))
            }
            regions += ArtworkSubjectRegion.selected(textRegions, limit: 10)

            let humans = VNDetectHumanRectanglesRequest(); humans.upperBodyOnly = false; humans.preferBackgroundProcessing = true
            perform(humans)
            let humanRegions = (humans.results ?? []).filter { $0.confidence >= 0.55 }.compactMap {
                ArtworkSubjectRegion(visionRect: $0.boundingBox, kind: .person, confidence: Double($0.confidence))
            }
            regions += ArtworkSubjectRegion.selected(humanRegions, limit: 6)

            let objects = VNGenerateObjectnessBasedSaliencyImageRequest(); objects.preferBackgroundProcessing = true
            perform(objects)
            let objectRegions = (objects.results?.first?.salientObjects ?? []).compactMap {
                ArtworkSubjectRegion(visionRect: $0.boundingBox, kind: .object, confidence: $0.confidence > 0 ? Double($0.confidence) : 0.65)
            }
            regions += ArtworkSubjectRegion.selected(objectRegions, limit: 4)
            let attention = VNGenerateAttentionBasedSaliencyImageRequest(); attention.preferBackgroundProcessing = true
            perform(attention)
            let attentionRegions = (attention.results?.first?.salientObjects ?? []).compactMap {
                ArtworkSubjectRegion(visionRect: $0.boundingBox, kind: .attention, confidence: $0.confidence > 0 ? Double($0.confidence) : 0.55)
            }
            regions += ArtworkSubjectRegion.selected(attentionRegions, limit: 4)
            guard successfulDetectors > 0 else { throw AnalysisError.detectorsUnavailable }
            let result = regions.map(\.dictionary)
            // Do not permanently remember transient model/service failures as an
            // apparently successful "no subject" result.
            if failedDetectors == 0 { storage.remember(result, key: key) }
            return result
        }
        #else
        return []
        #endif
    }
}
