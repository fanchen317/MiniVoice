import AppKit
import CryptoKit
import ImageIO
import Combine

enum ResourceCache {
    static let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MiniVoice")
    static let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("com.xcosmos.MiniVoice/Resources-v2")
    private static let lock = NSRecursiveLock()
    static func withDiskLock<T>(_ work: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try work()
    }
    static func key(_ string: String) -> String { key(Data(string.utf8)) }
    static func key(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func trackID(_ url: URL) -> UUID {
        let s = Array(key(url.standardizedFileURL.path).prefix(32))
        return UUID(uuidString: String(s[0..<8]) + "-" + String(s[8..<12]) + "-" + String(s[12..<16]) + "-" + String(s[16..<20]) + "-" + String(s[20..<32]))!
    }
    static func url(_ key: String, kind: String) -> URL {
        let safe = key.count == 64 && key.allSatisfy { $0.isHexDigit } ? key : "invalid"
        return directory.appendingPathComponent("\(kind)/\(safe)")
    }
    static func atomicWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    static func saveLyrics(_ lyrics: String) throws -> String {
        let data = Data(lyrics.utf8), id = key(data)
        try atomicWrite(data, to: url(id, kind: "Lyrics")); return id
    }
    static func saveArtwork(_ data: Data, includeDetail: Bool = true) throws -> String {
        try withDiskLock { try saveArtworkUnlocked(data, includeDetail: includeDetail) }
    }
    static func isValidArtwork(_ data: Data?) -> Bool {
        guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceCreateImageAtIndex(source, 0, nil) != nil
    }
    private static func saveArtworkUnlocked(_ data: Data, includeDetail: Bool) throws -> String {
        let id = key(data)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw CocoaError(.fileReadCorruptFile) }
        for (kind, size) in [("Artwork/List", 96), ("Artwork/Detail", 1024)] {
            if !includeDetail && kind == "Artwork/Detail" { continue }
            let target = url(id, kind: kind)
            if isValidArtwork(try? Data(contentsOf: target)) { continue }
            let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: size, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true]
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
            let clean = ArtworkPresentation.removingWhiteMargins(NSImage(cgImage: cg, size: .zero))
            guard let result = clean.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw CocoaError(.fileReadCorruptFile) }
            let bitmap = NSBitmapImageRep(cgImage: result)
            let opaque = [.none, .noneSkipFirst, .noneSkipLast].contains(result.alphaInfo)
            guard let encoded = bitmap.representation(using: opaque ? .jpeg : .png,
                    properties: opaque ? [.compressionFactor: 0.85] : [:]) else { throw CocoaError(.fileWriteUnknown) }
            try atomicWrite(encoded, to: target)
        }
        return id
    }
    static func lyrics(_ id: String?) -> String? {
        id.flatMap { try? String(contentsOf: url($0, kind: "Lyrics"), encoding: .utf8) }
    }
    static func artworkData(_ id: String?, detail: Bool) -> Data? {
        id.flatMap { try? Data(contentsOf: url($0, kind: detail ? "Artwork/Detail" : "Artwork/List")) }
    }
    static func touch(_ url: URL) {
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }
    static func prune(maxBytes: Int = 300 * 1024 * 1024) {
        withDiskLock {
            guard let e = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]) else { return }
            let files = e.compactMap { $0 as? URL }.compactMap { u -> (URL, Int, Date)? in
                guard let v = try? u.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]), v.isRegularFile == true else { return nil }
                return (u, v.fileSize ?? 0, v.contentModificationDate ?? .distantPast)
            }
            var total = files.reduce(0) { $0 + $1.1 }
            for f in files.sorted(by: { $0.2 < $1.2 }) where total > maxBytes {
                if (try? FileManager.default.removeItem(at: f.0)) != nil { total -= f.1 }
            }
        }
    }
}

final class CachedArtwork: @unchecked Sendable {
    // CGImage is immutable after construction; no AppKit object crosses actors.
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
    @MainActor private var presentation: NSImage?
    @MainActor func displayImage() -> NSImage {
        if let presentation { return presentation }
        let result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        presentation = result
        return result
    }
}

/// NSCache is thread-safe; synchronous lookups never perform disk I/O or wait for an actor.
private final class ThumbnailMemory: @unchecked Sendable {
    static let shared = ThumbnailMemory()
    private let cache = NSCache<NSString, CachedArtwork>()
    init() { cache.totalCostLimit = 64 * 1024 * 1024 }
    func image(_ key: String) -> CachedArtwork? { cache.object(forKey: key as NSString) }
    func insert(_ image: CachedArtwork, key: String) {
        cache.setObject(image, forKey: key as NSString, cost: image.image.bytesPerRow * image.image.height)
    }
}

/// Only tiny thumbnails use this worker. Expensive source extraction has its own worker.
private actor ThumbnailDiskReader {
    static let shared = ThumbnailDiskReader()
    func image(_ key: String) -> CachedArtwork? {
        if let hit = ThumbnailMemory.shared.image(key) { return hit }
        guard let data = ResourceCache.artworkData(key, detail: false),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0,
                    [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        let image = CachedArtwork(cg)
        ThumbnailMemory.shared.insert(image, key: key)
        ResourceCache.touch(ResourceCache.url(key, kind: "Artwork/List"))
        return image
    }
}

/// Keep the request alive independently of SwiftUI's lazy-row task lifecycle.
/// A disappearing/reappearing row must be able to retry a cancelled request.
@MainActor
final class ListArtworkLoader: ObservableObject {
    @Published private(set) var image: NSImage?
    private var request: Task<Void, Never>?
    private var identity: String?
    private var generation = 0

    func currentImage(key: String?, source: URL, browse: Bool = false) -> NSImage? {
        let expected = (browse ? "browse:" : "list:") + (key ?? "") + source.path
        return identity == expected ? image : nil
    }

    func load(key: String?, source: URL, browse: Bool = false) {
        let next = (browse ? "browse:" : "list:") + (key ?? "") + source.path
        if identity == next, image != nil || request != nil { return }
        cancel()
        identity = next
        image = (browse ? BrowseArtworkLoader.shared.cachedImage(key) : ThumbnailLoader.shared.cachedImage(key))?.displayImage()
        guard let key, image == nil else { return }
        let token = generation
        request = Task { [weak self] in
            let result = browse ? await BrowseArtworkLoader.shared.image(key, source: source)
                : await ThumbnailLoader.shared.image(key, source: source)
            guard let self, !Task.isCancelled, self.generation == token else { return }
            self.image = result?.displayImage()
            self.request = nil
        }
    }

    func cancel() {
        generation += 1
        request?.cancel()
        request = nil
    }
}

/// Large classification cards must never upscale the 96px song-list cache.
actor BrowseArtworkLoader {
    static let shared = BrowseArtworkLoader()
    private nonisolated let memory = ThumbnailMemory()
    private var pending: [String: Task<CachedArtwork?, Never>] = [:]
    private var failures: [String: Date] = [:]
    nonisolated func cachedImage(_ key: String?) -> CachedArtwork? { key.flatMap { memory.image($0) } }
    func image(_ key: String, source: URL) async -> CachedArtwork? {
        if let hit = cachedImage(key) { return hit }
        if let failed = failures[key], Date().timeIntervalSince(failed) < 60 { return nil }
        if let task = pending[key] { return await task.value }
        let task = Task.detached(priority: .utility) { await BrowseArtworkWorker.shared.image(key, source: source) }
        pending[key] = task
        let result = await task.value
        pending[key] = nil
        if let result { memory.insert(result, key: key); failures[key] = nil }
        else {
            failures = failures.filter { Date().timeIntervalSince($0.value) < 60 }
            failures[key] = Date()
        }
        return result
    }
}

private actor BrowseArtworkWorker {
    static let shared = BrowseArtworkWorker()
    func image(_ key: String, source: URL) -> CachedArtwork? {
        var data = ResourceCache.artworkData(key, detail: true)
        if !ResourceCache.isValidArtwork(data) {
            guard let original = try? MediaTools.run("ffmpeg", ["-v", "error", "-i", source.path, "-map", "0:v:0",
                "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"]),
                  let newKey = try? ResourceCache.saveArtwork(original) else { return nil }
            data = ResourceCache.artworkData(newKey, detail: true)
            if let data { try? ResourceCache.atomicWrite(data, to: ResourceCache.url(key, kind: "Artwork/Detail")) }
        }
        guard let data, let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 512,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return nil }
        ResourceCache.touch(ResourceCache.url(key, kind: "Artwork/Detail"))
        return CachedArtwork(cg)
    }
}

actor ThumbnailLoader {
    static let shared = ThumbnailLoader()
    private var pending: [String: Task<CachedArtwork?, Never>] = [:]
    private var failures: [String: Date] = [:]
    nonisolated func cachedImage(_ key: String?) -> CachedArtwork? {
        key.flatMap { ThumbnailMemory.shared.image($0) }
    }
    /// Warm every existing small cover before publishing the list. Never extract full media here.
    nonisolated func prefetch(_ keys: [String]) async {
        var seen = Set<String>()
        for key in keys where seen.insert(key).inserted {
            guard !Task.isCancelled else { return }
            if cachedImage(key) == nil { _ = await ThumbnailDiskReader.shared.image(key) }
        }
    }
    func image(_ id: String, source: URL) async -> CachedArtwork? {
        if let hit = cachedImage(id) { return hit }
        if let failed = failures[id], Date().timeIntervalSince(failed) < 60 { return nil }
        if let task = pending[id] { return await task.value }
        let task = Task.detached(priority: .userInitiated) { () -> CachedArtwork? in
            if let image = await ThumbnailDiskReader.shared.image(id) { return image }
            return await ThumbnailRepair.shared.image(id, source: source)
        }
        pending[id] = task
        let result = await task.value
        pending[id] = nil
        if result == nil {
            failures = failures.filter { Date().timeIntervalSince($0.value) < 60 }
            failures[id] = Date()
        } else { failures[id] = nil }
        return result
    }
}

private actor ThumbnailRepair {
    static let shared = ThumbnailRepair()
    func image(_ id: String, source: URL) -> CachedArtwork? {
        if let hit = ThumbnailMemory.shared.image(id) { return hit }
        var bytes = ResourceCache.artworkData(id, detail: false)
        if !ResourceCache.isValidArtwork(bytes) {
            // Reconstruct an evicted/corrupt resource on this bounded worker.
            let detail = ResourceCache.artworkData(id, detail: true)
            let original = ResourceCache.isValidArtwork(detail) ? detail
                : (try? MediaTools.run("ffmpeg", ["-v", "error", "-i", source.path, "-map", "0:v:0", "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "pipe:1"]))
            if let original, let newID = try? ResourceCache.saveArtwork(original) {
                bytes = ResourceCache.artworkData(newID, detail: false)
                if let bytes { try? ResourceCache.atomicWrite(bytes, to: ResourceCache.url(id, kind: "Artwork/List")) }
            }
        }
        guard let data = bytes,
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(imageSource, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
            return nil
        }
        ResourceCache.touch(ResourceCache.url(id, kind: "Artwork/List"))
        let image = CachedArtwork(cg)
        ThumbnailMemory.shared.insert(image, key: id)
        return image
    }
}
