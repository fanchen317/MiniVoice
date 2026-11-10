import Foundation

/// Only the latest pending snapshot needs to be encoded/written. A single drain serializes atomic writes,
/// so a slow older save can never overwrite the most recent library state.
actor LibraryIndexWriter {
    private let destination: URL
    private var pending: (@Sendable () throws -> Data)?
    private var waiters: [CheckedContinuation<Void, Error>] = []
    private var writing = false

    init(destination: URL) { self.destination = destination }

    func save(_ snapshot: @escaping @Sendable () throws -> Data) async throws {
        try await withCheckedThrowingContinuation { continuation in
            pending = snapshot; waiters.append(continuation)
            if !writing { writing = true; Task { await drain() } }
        }
    }

    private func drain() async {
        while let snapshot = pending {
            pending = nil
            let encoded = await Task.detached(priority: .utility) { Result { try snapshot() } }.value
            // Changes received during encoding replace that obsolete snapshot before any disk write.
            if pending != nil { continue }
            let result: Result<Void, Error>
            switch encoded {
            case .failure(let error): result = .failure(error)
            case .success(let data):
                let url = destination
                result = await Task.detached(priority: .utility) {
                    Result {
                        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try data.write(to: url, options: .atomic)
                    }
                }.value
            }
            if pending == nil {
                let completed = waiters; waiters.removeAll(keepingCapacity: true); writing = false
                for continuation in completed { continuation.resume(with: result) }
                return
            }
        }
        writing = false
    }
}
