import Foundation

/// Owns the original resolved URL and balances one native grant per overlapping group of readers.
/// Cached URLs do not keep grants alive; the last lease immediately relinquishes its native access.
final class FolderAccessRegistry: @unchecked Sendable {
    struct Bookmark: Hashable, Sendable { let id: String; let data: Data }
    struct Resolution: Sendable { let url: URL; let stale: Bool }
    struct SystemCalls: @unchecked Sendable {
        var resolve: (Data) throws -> Resolution
        var start: (URL) -> Bool
        var stop: (URL) -> Void
        var localContainer: URL?

        static var live: SystemCalls {
            #if os(iOS)
            let container: URL? = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            #else
            let container: URL? = nil
            #endif
            return SystemCalls(resolve: { data in
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                return Resolution(url: url, stale: stale)
            }, start: { $0.startAccessingSecurityScopedResource() }, stop: { $0.stopAccessingSecurityScopedResource() }, localContainer: container)
        }
    }

    enum Failure: LocalizedError {
        case revoked, stale, denied
        var errorDescription: String? {
            switch self {
            case .revoked: return "音乐文件夹已移除或授权已更换，请重新选择文件夹。"
            case .stale: return "音乐文件夹书签已失效，请在设置中重新选择文件夹。"
            case .denied: return "音乐文件夹授权不可用，请重扫重试或在设置中重新选择文件夹。"
            }
        }
    }

    fileprivate final class Entry {
        let bookmark: Bookmark
        var root: URL?
        var failure: Error?
        var busy = false
        var valid = true
        var readers = 0
        var started = false
        init(_ bookmark: Bookmark) { self.bookmark = bookmark }
    }

    struct Request: Sendable {
        fileprivate let registry: FolderAccessRegistry
        fileprivate let bookmark: Bookmark
        func acquire() throws -> Lease { try registry.acquire(bookmark) }
        func checkAuthorization() throws { try registry.check(bookmark) }
        func read<Value>(cached: () throws -> Value?, load: (Lease) throws -> Value) throws -> Value {
            try checkAuthorization()
            if let value = try cached() { try checkAuthorization(); return value }
            let lease = try acquire()
            defer { lease.close() }
            let value = try load(lease)
            try lease.checkValidity()
            return value
        }
    }

    final class Lease: @unchecked Sendable {
        let rootURL: URL
        private let registry: FolderAccessRegistry
        private let entry: Entry
        private let closeLock = NSLock()
        private var closed = false
        fileprivate init(root: URL, registry: FolderAccessRegistry, entry: Entry) {
            rootURL = root; self.registry = registry; self.entry = entry
        }
        func checkValidity() throws {
            closeLock.lock(); let ended = closed; closeLock.unlock()
            guard !ended else { throw Failure.revoked }
            try registry.check(entry.bookmark, entry: entry)
        }
        func file(relativePath: String) throws -> URL {
            try checkValidity()
            guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..") else { throw CocoaError(.fileReadNoPermission) }
            let file = rootURL.appendingPathComponent(relativePath).standardizedFileURL
            let canonicalRoot = try FolderAccessRegistry.canonical(rootURL).path
            guard try FolderAccessRegistry.canonical(file).path.hasPrefix(canonicalRoot + "/") else { throw CocoaError(.fileReadNoPermission) }
            return file
        }
        func close() {
            closeLock.lock(); let release = !closed; closed = true; closeLock.unlock()
            if release { registry.release(entry) }
        }
        deinit { close() }
    }

    private let condition = NSCondition()
    private let calls: SystemCalls
    private var allowed: [String: Data] = [:]
    private var entries: [Bookmark: Entry] = [:]
    private var retryEpoch: UInt64 = 0

    init(bookmarks: [Bookmark] = [], calls: SystemCalls = .live) {
        self.calls = calls
        allowed = Dictionary(bookmarks.map { ($0.id, $0.data) }, uniquingKeysWith: { _, last in last })
    }

    func request(id: String, bookmark: Data) -> Request { Request(registry: self, bookmark: Bookmark(id: id, data: bookmark)) }

    func update(bookmarks: [Bookmark], retryFailures: Bool = false) {
        condition.lock(); defer { condition.broadcast(); condition.unlock() }
        allowed = Dictionary(bookmarks.map { ($0.id, $0.data) }, uniquingKeysWith: { _, last in last })
        if retryFailures { retryEpoch &+= 1 }
        for (key, entry) in entries where allowed[key.id] != key.data || retryFailures && entry.failure != nil && !entry.busy && entry.readers == 0 {
            entry.valid = false; entries[key] = nil
        }
    }

    func retryFailures() {
        condition.lock(); defer { condition.broadcast(); condition.unlock() }
        retryEpoch &+= 1
        for (key, entry) in entries where entry.failure != nil && !entry.busy && entry.readers == 0 {
            entry.valid = false; entries[key] = nil
        }
    }

    func isInsideLocalContainer(_ url: URL) -> Bool {
        guard let container = calls.localContainer, url.isFileURL else { return false }
        guard let base = try? Self.canonical(container).path, let path = try? Self.canonical(url).path else { return false }
        return path == base || path.hasPrefix(base + "/")
    }

    /// Foundation's resolvingSymlinksInPath may leave every link unresolved if the final item
    /// doesn't exist. Resolve each ancestor, including dangling links, before applying a boundary.
    private static func canonical(_ url: URL) throws -> URL {
        var pending = url.path.split(separator: "/").map(String.init)
        var current = URL(fileURLWithPath: "/", isDirectory: true), links = 0
        while !pending.isEmpty {
            let component = pending.removeFirst()
            if component == "." { continue }
            if component == ".." { current.deleteLastPathComponent(); continue }
            let next = current.appendingPathComponent(component)
            if let destination = try? FileManager.default.destinationOfSymbolicLink(atPath: next.path) {
                links += 1
                guard links <= 40 else { throw CocoaError(.fileReadNoPermission) }
                if destination.hasPrefix("/") { current = URL(fileURLWithPath: "/", isDirectory: true) }
                pending = destination.split(separator: "/").map(String.init) + pending
            } else { current = next }
        }
        return current
    }

    private func check(_ bookmark: Bookmark, entry: Entry? = nil) throws {
        condition.lock(); defer { condition.unlock() }
        guard allowed[bookmark.id] == bookmark.data, entry?.valid != false else { throw Failure.revoked }
    }

    private func acquire(_ bookmark: Bookmark) throws -> Lease {
        condition.lock()
        while true {
            guard allowed[bookmark.id] == bookmark.data else { condition.unlock(); throw Failure.revoked }
            let entry = entries[bookmark] ?? Entry(bookmark)
            entries[bookmark] = entry
            if entry.busy { condition.wait(); continue }
            if let error = entry.failure { condition.unlock(); throw error }
            if entry.readers > 0, let root = entry.root {
                entry.readers += 1; condition.unlock()
                return Lease(root: root, registry: self, entry: entry)
            }
            entry.busy = true
            let cached = entry.root
            let attemptEpoch = retryEpoch
            condition.unlock()
            var started = false
            var root: URL?
            do {
                let resolution = try cached.map { Resolution(url: $0, stale: false) } ?? calls.resolve(bookmark.data)
                root = resolution.url
                guard !resolution.stale else { throw Failure.stale }
                guard resolution.url.isFileURL else { throw Failure.denied }
                if !isInsideLocalContainer(resolution.url) {
                    started = calls.start(resolution.url)
                    guard started else { throw Failure.denied }
                }
                condition.lock()
                guard entry.valid, allowed[bookmark.id] == bookmark.data else {
                    condition.unlock(); throw Failure.revoked
                }
                entry.root = resolution.url; entry.started = started; entry.readers = 1; entry.busy = false
                condition.broadcast(); condition.unlock()
                return Lease(root: resolution.url, registry: self, entry: entry)
            } catch {
                if started, let root { calls.stop(root) }
                condition.lock(); entry.busy = false
                if entry.valid, attemptEpoch == retryEpoch { entry.failure = error }
                condition.broadcast(); condition.unlock()
                throw error
            }
        }
    }

    private func release(_ entry: Entry) {
        condition.lock()
        entry.readers -= 1
        guard entry.readers == 0, entry.started, let root = entry.root else { condition.unlock(); return }
        entry.started = false; entry.busy = true
        condition.unlock(); calls.stop(root)
        condition.lock(); entry.busy = false; condition.broadcast(); condition.unlock()
    }
}
