import Foundation

private final class WriterProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    func begin() { lock.lock(); started = true; lock.unlock() }
    var didBegin: Bool { lock.lock(); defer { lock.unlock() }; return started }
}

@main
struct LibraryIndexWriterTests {
    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-index-writer-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("library.json"), writer = LibraryIndexWriter(destination: destination)
        try await writer.save { Data("seed".utf8) }
        let probe = WriterProbe(), gate = DispatchSemaphore(value: 0)
        let old = Task { try await writer.save { probe.begin(); gate.wait(); return Data("old".utf8) } }
        for _ in 0..<100 where !probe.didBegin { try await Task.sleep(nanoseconds: 1_000_000) }
        precondition(probe.didBegin)
        let newest = Task {
            try await writer.save {
                let existing = try Data(contentsOf: destination)
                precondition(existing == Data("seed".utf8), "obsolete encoded snapshot should be skipped before disk write")
                return Data("newest".utf8)
            }
        }
        try await Task.sleep(nanoseconds: 20_000_000); gate.signal()
        try await old.value; try await newest.value
        let final = try Data(contentsOf: destination)
        precondition(final == Data("newest".utf8), "older write overwrote the latest library")
        do { try await writer.save { throw CocoaError(.coderInvalidValue) }; preconditionFailure("encoding error suppressed") } catch {}
        let preserved = try Data(contentsOf: destination)
        precondition(preserved == final, "failed encoding replaced the previous index")
        try await writer.save { Data("recovered".utf8) }
        let restored = try Data(contentsOf: destination)
        precondition(restored == Data("recovered".utf8), "writer failed to drain after an error")
        let invalid = LibraryIndexWriter(destination: destination.appendingPathComponent("impossible.json"))
        do { try await invalid.save { Data([1]) }; preconditionFailure("disk error suppressed") } catch {}
        let intact = try Data(contentsOf: destination)
        precondition(intact == restored)
        print("PASS library index background snapshots, coalescing, last-write ordering, atomic readback and encoding/disk failure recovery")
    }
}
