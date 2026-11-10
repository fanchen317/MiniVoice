import Foundation

/// Encoded bytes only. Decoded images belong to the renderer, not a second native image cache.
/// The host limits decode concurrency and prioritizes the focused card over wall thumbnails.
actor ArtworkRequestCache {
    static let shared = ArtworkRequestCache()

    private struct Entry { let data: Data; var access: UInt64 }
    private struct Flight { let id: UUID; let memoryGeneration: UInt64; let task: Task<Data, Error> }
    private let byteLimit: Int
    private var entries: [String: Entry] = [:]
    private var flights: [String: Flight] = [:]
    private var bytes = 0
    private var clock: UInt64 = 0
    private var generation: UInt64 = 0
    private var memoryGeneration: UInt64 = 0

    init(byteLimit: Int = 8 * 1024 * 1024) { self.byteLimit = max(0, byteLimit) }

    func data(key: String, cacheInMemory: Bool = true, load: @escaping @Sendable () throws -> Data) async throws -> Data {
        try Task.checkCancellation()
        clock &+= 1
        if cacheInMemory, var entry = entries[key] {
            entry.access = clock; entries[key] = entry
            return entry.data
        }
        let revision = generation
        let flight: Flight
        if let existing = flights[key] { flight = existing }
        else {
            flight = Flight(id: UUID(), memoryGeneration: memoryGeneration, task: Task.detached(priority: .userInitiated) { try load() })
            flights[key] = flight
        }
        do {
            let result = try await flight.task.value
            if flights[key]?.id == flight.id { flights[key] = nil }
            // Clearing while a read is in flight must not resurrect bytes or publish the old resource.
            guard generation == revision else { throw CancellationError() }
            // A reader joining after memory pressure shares the pending bytes, but must not
            // make work started before the purge eligible for memory retention again.
            if cacheInMemory, flight.memoryGeneration == memoryGeneration, result.count <= byteLimit {
                if let previous = entries.removeValue(forKey: key) { bytes -= previous.data.count }
                clock &+= 1; entries[key] = Entry(data: result, access: clock); bytes += result.count
                while bytes > byteLimit, let oldest = entries.min(by: { $0.value.access < $1.value.access }) {
                    bytes -= oldest.value.data.count; entries[oldest.key] = nil
                }
            }
            try Task.checkCancellation()
            return result
        } catch {
            if flights[key]?.id == flight.id { flights[key] = nil }
            throw error
        }
    }

    func invalidateMemory() {
        memoryGeneration &+= 1; entries.removeAll(keepingCapacity: false); bytes = 0
    }

    func invalidateAll() {
        generation &+= 1; invalidateMemory()
        // Shared readers may still be finishing synchronous file I/O. Their generations prevent publication.
        flights.removeAll(keepingCapacity: false)
    }
}

/// Regenerable artwork is bounded independently of the music/index/user lyrics directories.
/// This index is built once per process/explicit maintenance, never by enumerating on every image read.
final class ArtworkDiskCache: @unchecked Sendable {
    static let shared = ArtworkDiskCache(root: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Artwork", isDirectory: true))
    private struct Entry { var bytes: Int; var access: Date; var persistedAccess: Date }
    let root: URL
    private let byteLimit: Int
    private let ageLimit: TimeInterval
    private let lock = NSLock()
    private let revisionLock = NSLock()
    private var entries: [URL: Entry] = [:]
    private var loaded = false
    private var bytes = 0
    private var revision: UInt64 = 0

    init(root: URL, byteLimit: Int = 512 * 1024 * 1024, ageLimit: TimeInterval = 30 * 86400) {
        self.root = root.standardizedFileURL; self.byteLimit = max(0, byteLimit); self.ageLimit = ageLimit
    }

    // Capturing a request revision on the UI thread never waits for disk I/O or cache enumeration.
    var generation: UInt64 { revisionLock.lock(); defer { revisionLock.unlock() }; return revision }

    private func validate(_ url: URL) throws {
        guard url.standardizedFileURL.deletingLastPathComponent().path == root.path,
              (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
              url.resolvingSymlinksInPath().deletingLastPathComponent().path == root.resolvingSymlinksInPath().path else { throw CocoaError(.fileReadNoPermission) }
    }

    private func loadIndex() throws {
        guard !loaded else { return }
        try validate(root.appendingPathComponent(".cache-boundary"))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var directory = root; try? directory.setResourceValues(values)
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey])
        entries.removeAll(keepingCapacity: true); bytes = 0
        for file in files {
            guard let value = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]), value.isRegularFile == true, value.isSymbolicLink != true else { continue }
            let date = value.contentModificationDate ?? .distantPast, size = value.fileSize ?? 0
            entries[file] = Entry(bytes: size, access: date, persistedAccess: date); bytes += size
        }
        loaded = true
        prune(now: Date())
    }

    func read(_ url: URL) -> Data? {
        lock.lock(); defer { lock.unlock() }
        do {
            try validate(url); try loadIndex()
            let result = try Data(contentsOf: url, options: .mappedIfSafe)
            let now = Date()
            var entry = entries[url] ?? Entry(bytes: result.count, access: now, persistedAccess: .distantPast)
            if entries[url] == nil { bytes += result.count }
            entry.access = now
            // Persist recency at most once a minute per file; repeated wall tiles do not cause write storms.
            if now.timeIntervalSince(entry.persistedAccess) >= 60 {
                try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
                entry.persistedAccess = now
            }
            entries[url] = entry
            return result
        } catch {
            if let missing = entries[url], !FileManager.default.fileExists(atPath: url.path) {
                bytes -= missing.bytes; entries[url] = nil
            }
            return nil
        }
    }

    /// Failure to persist a derived image must not turn a successfully decoded image into a failed request.
    @discardableResult
    func write(_ data: Data, to url: URL, generation: UInt64) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard generation == self.generation else { return false }
        try validate(url); try loadIndex()
        guard data.count <= byteLimit else { return false }
        try data.write(to: url, options: .atomic)
        if let old = entries[url] { bytes -= old.bytes }
        let now = Date(); entries[url] = Entry(bytes: data.count, access: now, persistedAccess: now); bytes += data.count
        if bytes > byteLimit { prune(now: now, protecting: url) }
        return true
    }

    private func prune(now: Date, protecting: URL? = nil) {
        let expired = now.addingTimeInterval(-ageLimit)
        let target = bytes > byteLimit ? byteLimit * 7 / 8 : byteLimit
        for (url, entry) in entries.sorted(by: { $0.value.access < $1.value.access }) {
            guard url != protecting, entry.access < expired || bytes > target else { continue }
            // Never follow symlinks, including links substituted after initial enumeration.
            guard (try? validate(url)) != nil else { continue }
            if FileManager.default.fileExists(atPath: url.path), (try? FileManager.default.removeItem(at: url)) == nil { continue }
            bytes -= entry.bytes; entries[url] = nil
        }
    }

    /// Settings enumeration observes a stable set of files while background pruning/writes are paused.
    func inspect<T>(_ body: (URL) throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try body(root)
    }

    /// Serialize cache deletion against writes; stale extraction work cannot recreate deleted files.
    func maintenance<T>(_ body: (URL) throws -> T) rethrows -> T {
        lock.lock(); defer { loaded = false; entries.removeAll(); bytes = 0; lock.unlock() }
        revisionLock.lock(); revision &+= 1; revisionLock.unlock()
        return try body(root)
    }
}
