import Foundation

struct SongListEntry: Sendable {
    let id: UUID
    let url: URL
    let title: String
    let artist: String
    let album: String
}

struct SongListRequest: Equatable, Sendable {
    var revision: Int
    var recentPaths: [String] = []
    var recent = false
    var query = ""
    var field = "added"
    var ascending = false
}

/// Sorting and filesystem reads never run in SwiftUI's body or on the main actor.
actor SongListIndex {
    private var revision: Int?
    private var dates: [URL: Date] = [:]
    private struct CacheKey: Hashable {
        let revision: Int
        let field: String
        let ascending: Bool
    }
    private var searchText: [UUID: String] = [:]
    var cachedOrderingCount: Int { sortedCache.count }
    private var sortedCache: [CacheKey: [UUID]] = [:]

    func orderedIDs(_ entries: [SongListEntry], request: SongListRequest) -> [UUID] {
        if revision != request.revision {
            dates.removeAll(keepingCapacity: true)
            sortedCache.removeAll(keepingCapacity: true)
            revision = request.revision
            searchText = Dictionary(entries.map { ($0.id, "\($0.title) \($0.artist) \($0.album)") },
                                    uniquingKeysWith: { _, latest in latest })
        }
        guard !Task.isCancelled else { return [] }
        if request.recent {
            return entries.filter { matches($0, query: request.query) }.map(\.id)
        }
        // Search reuses one complete ordering. Query prefixes never create a new sort or cache entry.
        let key = CacheKey(revision: request.revision, field: request.field, ascending: request.ascending)
        if let cached = sortedCache[key] { return matchingIDs(cached, query: request.query) }
        var filtered = entries
        if request.field != "artist" && request.field != "title" {
            for entry in filtered where dates[entry.url] == nil {
                guard !Task.isCancelled else { return [] }
                var url = entry.url
                url.removeCachedResourceValue(forKey: .contentModificationDateKey)
                dates[entry.url] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            }
        }
        filtered.sort { left, right in
            if request.field == "artist" || request.field == "title" {
                let leftValue = request.field == "artist" ? left.artist : left.title
                let rightValue = request.field == "artist" ? right.artist : right.title
                let leftBucket = Self.letterBucket(leftValue), rightBucket = Self.letterBucket(rightValue)
                if leftBucket != rightBucket {
                    return request.ascending ? leftBucket < rightBucket : leftBucket > rightBucket
                }
            }
            let result: ComparisonResult
            switch request.field {
            case "artist": result = left.artist.localizedStandardCompare(right.artist)
            case "title": result = left.title.localizedStandardCompare(right.title)
            default:
                let a = dates[left.url] ?? .distantPast, b = dates[right.url] ?? .distantPast
                result = a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
            }
            if result != .orderedSame {
                return request.ascending ? result == .orderedAscending : result == .orderedDescending
            }
            let title = left.title.localizedStandardCompare(right.title)
            if title != .orderedSame { return title == .orderedAscending }
            return left.url.path < right.url.path
        }
        let ids = filtered.map(\.id)
        guard !Task.isCancelled else { return [] }
        sortedCache[key] = ids
        return matchingIDs(ids, query: request.query)
    }

    private func matches(_ entry: SongListEntry, query: String) -> Bool {
        query.isEmpty || (searchText[entry.id] ?? "\(entry.title) \(entry.artist) \(entry.album)")
            .localizedCaseInsensitiveContains(query)
    }

    private func matchingIDs(_ ordered: [UUID], query: String) -> [UUID] {
        guard !query.isEmpty else { return ordered }
        return ordered.filter { id in
            searchText[id]?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private static func letterBucket(_ string: String) -> Int {
        guard let firstScalar = string.unicodeScalars.first,
              CharacterSet.letters.contains(firstScalar) else {
            return 1
        }
        return 0
    }
}
