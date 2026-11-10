import Foundation

@main struct SnapshotMetadataCacheTests {
    static func main() throws {
        var cache = SnapshotMetadataCache()
        var builds = 0
        let queue = (0..<1037).map { "synthetic-song-\($0)" }
        let lyrics = String(repeating: "[00:01]合成歌词\n", count: 1000)
        let first = cache.fields(ifRevision: nil) {
            builds += 1
            return ["queue": queue, "rawLyrics": lyrics, "favorites": ["synthetic-song-0"]]
        }
        let revision = first["snapshotRevision"] as? String
        precondition(revision != nil && first["queue"] as? [String] == queue)
        for _ in 0..<100 {
            let tick = cache.fields(ifRevision: revision) { builds += 1; return [:] }
            precondition(tick.count == 1 && tick["queue"] == nil && tick["rawLyrics"] == nil)
            let encoded = try JSONSerialization.data(withJSONObject: tick)
            precondition(encoded.count < 100)
        }
        precondition(builds == 1)
        // A second consumer without a revision still receives all metadata.
        let cold = cache.fields(ifRevision: nil) { builds += 1; return [:] }
        precondition(cold["rawLyrics"] as? String == lyrics && builds == 1)
        cache.invalidate()
        let next = cache.fields(ifRevision: revision) {
            builds += 1; return ["queue": [], "rawLyrics": "", "favorites": []]
        }
        precondition(next["snapshotRevision"] as? String != revision && builds == 2)
        precondition(next["rawLyrics"] as? String == "")
        var restarted = SnapshotMetadataCache()
        let restored = restarted.fields(ifRevision: next["snapshotRevision"] as? String) { ["queue": queue] }
        precondition(restored["queue"] as? [String] == queue)
        print("PASS: 1037-song metadata, 100 small clock replies, invalidation, cold reader and host restart")
    }
}
