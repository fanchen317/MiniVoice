import Foundation

struct LibraryListLocation: Hashable {
    let destination: LibraryDestination
    let group: String?
}

struct LibraryBrowseGroup: Sendable, Equatable {
    let name: String
    let ids: [UUID]
    let artist: String
}

enum LibraryBrowseIndex {
    static func name(_ value: String, artist: Bool) -> String {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? (artist ? "未知歌手" : "未知专辑") : value
    }
    static func groups(_ entries: [SongListEntry], artist: Bool, field: String, ascending: Bool) -> [LibraryBrowseGroup] {
        Dictionary(grouping: entries, by: { name(artist ? $0.artist : $0.album, artist: artist) })
            .map { key, entries in
                LibraryBrowseGroup(name: key, ids: entries.map(\.id),
                    artist: Set(entries.map { name($0.artist, artist: true) }).sorted().joined(separator: " / "))
            }
            .sorted { a, b in
                if field == "count", a.ids.count != b.ids.count {
                    return ascending ? a.ids.count < b.ids.count : a.ids.count > b.ids.count
                }
                let compared = (field == "artist" ? a.artist : a.name)
                    .localizedStandardCompare(field == "artist" ? b.artist : b.name)
                if compared != .orderedSame { return ascending ? compared == .orderedAscending : compared == .orderedDescending }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }
}
