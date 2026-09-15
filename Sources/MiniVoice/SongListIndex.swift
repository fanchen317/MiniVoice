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

    func orderedIDs(_ entries: [SongListEntry], request: SongListRequest) -> [UUID] {
        if revision != request.revision {
            dates.removeAll(keepingCapacity: true)
            revision = request.revision
        }
        var filtered = entries.filter {
            request.query.isEmpty || "\($0.title) \($0.artist) \($0.album)".localizedCaseInsensitiveContains(request.query)
        }
        guard !request.recent else { return filtered.map(\.id) }
        if request.field != "artist" && request.field != "title" {
            for entry in filtered where dates[entry.url] == nil {
                guard !Task.isCancelled else { return [] }
                var url = entry.url
                url.removeCachedResourceValue(forKey: .contentModificationDateKey)
                dates[entry.url] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            }
        }
        filtered.sort { left, right in
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
        return filtered.map(\.id)
    }
}
