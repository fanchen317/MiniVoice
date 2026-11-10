import Foundation

private final class Probe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

@main
struct ArtworkCacheTests {
    static func main() async throws {
        let cache = ArtworkRequestCache(byteLimit: 10), probe = Probe(), gate = DispatchSemaphore(value: 0)
        let first = Task { try await cache.data(key: "same") { probe.increment(); gate.wait(); return Data(repeating: 1, count: 6) } }
        for _ in 0..<100 where probe.value == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
        let second = Task { try await cache.data(key: "same") { probe.increment(); return Data([9]) } }
        try await Task.sleep(nanoseconds: 10_000_000); gate.signal()
        let a = try await first.value, b = try await second.value
        precondition(a == b && probe.value == 1, "concurrent same-image requests must merge")
        _ = try await cache.data(key: "same") { preconditionFailure("memory hit missed") }
        _ = try await cache.data(key: "second") { Data(repeating: 2, count: 6) }
        _ = try await cache.data(key: "same") { probe.increment(); return Data([3]) }
        precondition(probe.value == 2, "encoded-byte budget must evict the least recently used image")
        let failed = ArtworkRequestCache()
        do { _ = try await failed.data(key: "retry") { throw CocoaError(.fileReadCorruptFile) }; preconditionFailure("failure lost") } catch {}
        let retry = try await failed.data(key: "retry") { Data([4]) }
        precondition(retry == Data([4]), "failures must not be cached")
        await cache.invalidateMemory()
        _ = try await cache.data(key: "same") { probe.increment(); return Data([5]) }
        precondition(probe.value == 3)
        let pressure = ArtworkRequestCache(byteLimit: 100), pressureProbe = Probe(), pressureGate = DispatchSemaphore(value: 0)
        let beforePressure = Task { try await pressure.data(key: "pending") { pressureProbe.increment(); pressureGate.wait(); return Data([8]) } }
        for _ in 0..<100 where pressureProbe.value == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(pressureProbe.value == 1)
        await pressure.invalidateMemory()
        let afterPressure = Task { try await pressure.data(key: "pending") { pressureProbe.increment(); return Data([9]) } }
        try await Task.sleep(nanoseconds: 10_000_000); pressureGate.signal()
        let beforePressureData = try await beforePressure.value, afterPressureData = try await afterPressure.value
        precondition(beforePressureData == Data([8]) && afterPressureData == beforePressureData && pressureProbe.value == 1,
                     "memory purge must preserve shared readers without starting duplicate I/O")
        let fresh = try await pressure.data(key: "pending") { pressureProbe.increment(); return Data([9]) }
        precondition(fresh == Data([9]) && pressureProbe.value == 2,
                     "a reader joining after memory pressure must not repopulate purged memory from an old flight")
        _ = try await pressure.data(key: "pending") { preconditionFailure("new-generation image was not retained") }
        let staleGate = DispatchSemaphore(value: 0), staleProbe = Probe()
        let stale = Task { try await cache.data(key: "stale") { staleProbe.increment(); staleGate.wait(); return Data([6]) } }
        for _ in 0..<100 where staleProbe.value == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
        await cache.invalidateAll(); staleGate.signal()
        do { _ = try await stale.value; preconditionFailure("cleared in-flight image was published") } catch is CancellationError {} catch { throw error }
        _ = try await cache.data(key: "stale") { Data([7]) }
        let noMemory = ArtworkRequestCache(byteLimit: 100), originalProbe = Probe()
        for _ in 0..<2 { _ = try await noMemory.data(key: "original", cacheInMemory: false) { originalProbe.increment(); return Data([1]) } }
        precondition(originalProbe.value == 2, "original encodings must not occupy thumbnail memory")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-artwork-cache-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = ArtworkDiskCache(root: root, byteLimit: 10)
        let one = root.appendingPathComponent("one.jpg"), two = root.appendingPathComponent("two.jpg")
        let wroteOne = try disk.write(Data(repeating: 1, count: 6), to: one, generation: disk.generation)
        precondition(wroteOne)
        precondition(disk.read(one)?.count == 6)
        let wroteTwo = try disk.write(Data(repeating: 2, count: 6), to: two, generation: disk.generation)
        precondition(wroteTwo)
        precondition(disk.read(one) == nil && disk.read(two)?.count == 6, "disk budget must evict oldest bytes")
        let restored = ArtworkDiskCache(root: root, byteLimit: 10)
        precondition(restored.read(two)?.count == 6, "disk cache must survive a new instance")
        let old = disk.generation
        try disk.maintenance { root in try FileManager.default.removeItem(at: root) }
        let wroteStale = try disk.write(Data([1]), to: one, generation: old)
        precondition(!wroteStale, "old extraction must not recreate a cleared cache")
        let wroteNew = try disk.write(Data([3]), to: one, generation: disk.generation)
        precondition(wroteNew)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -40 * 86400)], ofItemAtPath: one.path)
        let expiry = ArtworkDiskCache(root: root, byteLimit: 10)
        precondition(expiry.read(one) == nil, "old regenerable artwork should expire")
        let outside = root.deletingLastPathComponent().appendingPathComponent("MiniVoice-cache-outside-" + UUID().uuidString)
        try Data([9]).write(to: outside); defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: one, withDestinationURL: outside)
        precondition(disk.read(one) == nil, "cache read must reject symlinks")
        do { _ = try disk.write(Data([8]), to: one, generation: disk.generation); preconditionFailure("cache write followed symlink") } catch {}
        let unchanged = try Data(contentsOf: outside)
        precondition(unchanged == Data([9]))
        let total = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        precondition(total.count == 1)
        let linkRoot = root.appendingPathExtension("linked")
        try FileManager.default.createSymbolicLink(at: linkRoot, withDestinationURL: root)
        defer { try? FileManager.default.removeItem(at: linkRoot) }
        let linked = ArtworkDiskCache(root: linkRoot, byteLimit: 10)
        precondition(linked.read(linkRoot.appendingPathComponent("one.jpg")) == nil)
        do { _ = try linked.write(Data([1]), to: linkRoot.appendingPathComponent("new.jpg"), generation: linked.generation); preconditionFailure("symlink cache root was accepted") } catch {}
        print("PASS artwork cache coalescing, byte LRU, failed-read retry, original bypass, memory purge/join race, clear race, disk restart/expiry/budget and symlink boundary")
    }
}
