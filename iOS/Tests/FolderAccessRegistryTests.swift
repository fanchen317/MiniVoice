import Foundation

private final class AccessProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var enabled = true
    func hit(_ key: String) { lock.lock(); counts[key, default: 0] += 1; lock.unlock() }
    func count(_ key: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[key, default: 0] }
    var grant: Bool {
        get { lock.lock(); defer { lock.unlock() }; return enabled }
        set { lock.lock(); enabled = newValue; lock.unlock() }
    }
}

@main
struct FolderAccessRegistryTests {
    static func expectFailure(file: StaticString = #file, line: UInt = #line, _ body: () throws -> Void) {
        do { try body(); preconditionFailure("unauthorized operation succeeded", file: file, line: line) } catch {}
    }
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-folder-access-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data([1]), bookmark = FolderAccessRegistry.Bookmark(id: "music", data: data)
        let probe = AccessProbe()
        let calls = FolderAccessRegistry.SystemCalls(resolve: { _ in probe.hit("resolve"); return .init(url: root, stale: false) }, start: { _ in probe.hit("start"); return probe.grant }, stop: { _ in probe.hit("stop") }, localContainer: nil)
        let access = FolderAccessRegistry(bookmarks: [bookmark], calls: calls), request = access.request(id: "music", bookmark: data)
        let hit: Data = try request.read(cached: { Data([3]) }, load: { _ in preconditionFailure("cache hit touched source") })
        precondition(hit == Data([3]) && probe.count("resolve") == 0 && probe.count("start") == 0)
        let first = try request.acquire(), second = try request.acquire()
        precondition(probe.count("resolve") == 1 && probe.count("start") == 1)
        first.close(); first.close()
        precondition(probe.count("stop") == 0, "one lease prematurely revoked another reader")
        try second.checkValidity(); second.close()
        precondition(probe.count("stop") == 1, "native grants must be balanced exactly once")
        let read: Data = try request.read(cached: { nil }, load: { lease in
            _ = try lease.file(relativePath: "song.mp3"); probe.hit("io"); return Data([4])
        })
        precondition(read == Data([4]) && probe.count("resolve") == 1 && probe.count("start") == 2 && probe.count("stop") == 2)

        // Failure is visible, memoized for this bookmark, and explicitly retryable without changing data.
        probe.grant = false
        for _ in 0..<100 {
            expectFailure { _ = try request.read(cached: { nil as Data? }, load: { _ in probe.hit("forbiddenIO"); return Data() }) }
        }
        precondition(probe.count("start") == 3 && probe.count("forbiddenIO") == 0 && probe.count("stop") == 2)
        probe.grant = true; access.retryFailures()
        let recovered = try request.acquire(); recovered.close()
        precondition(probe.count("start") == 4 && probe.count("stop") == 3)
        let old = try request.acquire()
        access.update(bookmarks: [])
        expectFailure { try old.checkValidity() }
        expectFailure { _ = try old.file(relativePath: "song.mp3") }
        expectFailure { _ = try request.read(cached: { Data([3]) }, load: { _ in Data() }) }
        old.close()
        precondition(probe.count("start") == probe.count("stop") + 1, "only the failed start may remain unbalanced")
        let replacement = Data([2])
        access.update(bookmarks: [.init(id: "music", data: replacement)], retryFailures: true)
        expectFailure { _ = try request.acquire() }
        let newer = try access.request(id: "music", bookmark: replacement).acquire(); newer.close()

        let staleProbe = AccessProbe()
        let stale = FolderAccessRegistry(bookmarks: [bookmark], calls: .init(resolve: { _ in staleProbe.hit("resolve"); return .init(url: root, stale: true) }, start: { _ in staleProbe.hit("start"); return true }, stop: { _ in staleProbe.hit("stop") }, localContainer: nil))
        for _ in 0..<3 { expectFailure { _ = try stale.request(id: "music", bookmark: data).acquire() } }
        precondition(staleProbe.count("resolve") == 1 && staleProbe.count("start") == 0)

        let brokenProbe = AccessProbe()
        let broken = FolderAccessRegistry(bookmarks: [bookmark], calls: .init(resolve: { _ in
            brokenProbe.hit("resolve"); throw CocoaError(.fileReadCorruptFile)
        }, start: { _ in brokenProbe.hit("start"); return true }, stop: { _ in brokenProbe.hit("stop") }, localContainer: nil))
        for _ in 0..<3 { expectFailure { _ = try broken.request(id: "music", bookmark: data).acquire() } }
        precondition(brokenProbe.count("resolve") == 1 && brokenProbe.count("start") == 0 && brokenProbe.count("stop") == 0)
        broken.retryFailures()
        expectFailure { _ = try broken.request(id: "music", bookmark: data).acquire() }
        precondition(brokenProbe.count("resolve") == 2, "corrupt bookmarks must remain explicitly retryable")

        // Retrying a scan must preserve a valid resolution/grant being prepared concurrently.
        let entered = DispatchSemaphore(value: 0), continueResolve = DispatchSemaphore(value: 0), pendingProbe = AccessProbe()
        let pending = FolderAccessRegistry(bookmarks: [bookmark], calls: .init(resolve: { _ in
            pendingProbe.hit("resolve"); entered.signal(); continueResolve.wait(); return .init(url: root, stale: false)
        }, start: { _ in pendingProbe.hit("start"); return true }, stop: { _ in pendingProbe.hit("stop") }, localContainer: nil))
        let task = Task.detached { try pending.request(id: "music", bookmark: data).acquire() }
        precondition(entered.wait(timeout: .now() + 3) == .success)
        let queued = Task.detached { try pending.request(id: "music", bookmark: data).acquire() }
        pending.retryFailures(); pending.update(bookmarks: [bookmark], retryFailures: true)
        continueResolve.signal()
        let prepared = try await task.value, overlapping = try await queued.value
        try prepared.checkValidity(); try overlapping.checkValidity()
        precondition(pendingProbe.count("start") == 1, "concurrent requests consumed duplicate native grants")
        prepared.close(); overlapping.close()
        let cachedResolution = try pending.request(id: "music", bookmark: data).acquire(); cachedResolution.close()
        precondition(pendingProbe.count("resolve") == 1 && pendingProbe.count("start") == 2 && pendingProbe.count("stop") == 2)
        expectFailure {
            _ = try pending.request(id: "music", bookmark: data).read(cached: { nil as Data? }, load: { _ in throw CocoaError(.fileReadCorruptFile) })
        }
        precondition(pendingProbe.count("start") == 3 && pendingProbe.count("stop") == 3, "failed file I/O leaked its native grant")

        // Only the app's canonical data container bypasses security-scoped access.
        let localProbe = AccessProbe()
        let local = FolderAccessRegistry(bookmarks: [bookmark], calls: .init(resolve: { _ in .init(url: root, stale: false) }, start: { _ in localProbe.hit("start"); return false }, stop: { _ in localProbe.hit("stop") }, localContainer: root))
        let localLease = try local.request(id: "music", bookmark: data).acquire()
        precondition(localProbe.count("start") == 0)
        expectFailure { _ = try localLease.file(relativePath: "../outside.mp3") }
        expectFailure { _ = try localLease.file(relativePath: "/outside.mp3") }
        let outside = root.appendingPathExtension("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"), withDestinationURL: outside)
        expectFailure { _ = try localLease.file(relativePath: "escape/song.mp3") }
        localLease.close()
        let sibling = FolderAccessRegistry(bookmarks: [bookmark], calls: .init(resolve: { _ in .init(url: outside, stale: false) }, start: { _ in localProbe.hit("start"); return false }, stop: { _ in localProbe.hit("stop") }, localContainer: root))
        expectFailure { _ = try sibling.request(id: "music", bookmark: data).acquire() }
        precondition(localProbe.count("start") == 1 && localProbe.count("stop") == 0)
        print("PASS folder access cache-hit bypass, one-grant shared leases, start-false no-I/O, explicit retry, stale/error memo, revoke/new bookmark, pending-scan retry, exact release and canonical container/path boundaries")
    }
}
