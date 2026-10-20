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
    private struct DateKey: Hashable { let url: URL; let field: String }
    private var dates: [DateKey: Date] = [:]
    private let fileDate: @Sendable (URL, String) -> Date
    init(fileDate: @escaping @Sendable (URL, String) -> Date = SongListIndex.sourceDate) { self.fileDate = fileDate }
    nonisolated static func sourceDate(_ url: URL, field: String) -> Date {
        var url = url
        url.removeAllCachedResourceValues()
        if field == "sourceAdded" {
            let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .creationDateKey])
            return (values?.allValues[.addedToDirectoryDateKey] as? Date) ?? values?.creationDate ?? .distantPast
        }
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
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
        if !["artist", "title", "album"].contains(request.field) {
            for entry in filtered where dates[DateKey(url: entry.url, field: request.field)] == nil {
                guard !Task.isCancelled else { return [] }
                dates[DateKey(url: entry.url, field: request.field)] = fileDate(entry.url, request.field)
            }
        }
        filtered.sort { left, right in
            if ["artist", "title", "album"].contains(request.field) {
                let leftValue = request.field == "artist" ? left.artist : (request.field == "album" ? left.album : left.title)
                let rightValue = request.field == "artist" ? right.artist : (request.field == "album" ? right.album : right.title)
                let leftBucket = Self.letterBucket(leftValue), rightBucket = Self.letterBucket(rightValue)
                if leftBucket != rightBucket {
                    return request.ascending ? leftBucket < rightBucket : leftBucket > rightBucket
                }
            }
            let result: ComparisonResult
            switch request.field {
            case "artist": result = left.artist.localizedStandardCompare(right.artist)
            case "title": result = left.title.localizedStandardCompare(right.title)
            case "album": result = left.album.localizedStandardCompare(right.album)
            default:
                let a = dates[DateKey(url: left.url, field: request.field)] ?? .distantPast
                let b = dates[DateKey(url: right.url, field: request.field)] ?? .distantPast
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
