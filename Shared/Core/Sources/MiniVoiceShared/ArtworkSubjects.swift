import Foundation
#if canImport(Vision) && canImport(ImageIO)
import Vision
import ImageIO
#endif

/// Offline, bounded subject analysis. One utility queue prevents parallel model work.
public enum ArtworkSubjects {
    private static let queue = DispatchQueue(label: "MiniVoice.artwork-subjects", qos: .utility)
    public static func detect(_ data: Data) async throws -> [[String: Double]] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try analyze(data)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
    private static func analyze(_ data: Data) throws -> [[String: Double]] {
        #if canImport(Vision) && canImport(ImageIO)
        return try autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache:false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true, kCGImageSourceCreateThumbnailWithTransform:true, kCGImageSourceThumbnailMaxPixelSize:640] as CFDictionary) else { return [] }
            let faces = VNDetectFaceRectanglesRequest(); faces.preferBackgroundProcessing = true
            let handler = VNImageRequestHandler(cgImage:image)
            try handler.perform([faces])
            let observations = (faces.results ?? []).filter { $0.confidence >= 0.45 }
            var regions: [[String: Double]] = observations.prefix(8).map { let r = $0.boundingBox; return ["x":r.minX,"y":1-r.maxY,"width":r.width,"height":r.height,"face":1,"confidence":Double($0.confidence)] }
            // Text is composition information on typography-heavy album art.
            // Fast local OCR supplies rectangles only; no text leaves this process.
            let text = VNRecognizeTextRequest(); text.recognitionLevel = .accurate
            if let supported = try? text.supportedRecognitionLanguages() {
                let languages = ["zh-Hans", "zh-Hant", "en-US"].filter { supported.contains($0) }
                if !languages.isEmpty { text.recognitionLanguages = languages }
            }
            text.usesLanguageCorrection = false; text.preferBackgroundProcessing = true
            if (try? handler.perform([text])) != nil {
                regions += (text.results ?? []).filter { ($0.topCandidates(1).first?.confidence ?? 0) >= 0.5 }.prefix(8).map { let r = $0.boundingBox; return ["x":r.minX,"y":1-r.maxY,"width":r.width,"height":r.height,"face":0,"text":1,"confidence":Double($0.topCandidates(1).first?.confidence ?? 0)] }
            }
            let humans = VNDetectHumanRectanglesRequest(); humans.upperBodyOnly = false
            humans.preferBackgroundProcessing = true
            if (try? handler.perform([humans])) != nil {
                regions += (humans.results ?? []).filter { $0.confidence >= 0.55 }.prefix(6).map { let r = $0.boundingBox; return ["x":r.minX,"y":1-r.maxY,"width":r.width,"height":r.height,"face":0,"person":1,"confidence":Double($0.confidence)] }
            }
            do {
                let objects = VNGenerateObjectnessBasedSaliencyImageRequest(); objects.preferBackgroundProcessing = true
                try? handler.perform([objects])
                regions += (objects.results?.first?.salientObjects ?? []).prefix(4).map { let r = $0.boundingBox; return ["x":r.minX,"y":1-r.maxY,"width":r.width,"height":r.height,"face":0] }
            }
            return regions
        }
        #else
        return []
        #endif
    }
}
