import Foundation

/// Cold collection/lyrics fields have a separate revision from the playback clock.
/// Invalidations only mark dirty: Combine publishes before its property is assigned.
struct SnapshotMetadataCache {
    private var revision = UUID().uuidString
    private var cached: [String: Any]?

    mutating func invalidate() {
        revision = UUID().uuidString
        cached = nil
    }

    mutating func fields(ifRevision clientRevision: String?, build: () -> [String: Any]) -> [String: Any] {
        guard clientRevision != revision else { return ["snapshotRevision": revision] }
        if cached == nil { cached = build() }
        var result = cached ?? [:]
        result["snapshotRevision"] = revision
        return result
    }
}
