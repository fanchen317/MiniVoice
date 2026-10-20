import Foundation
import Combine

enum PlayerInterfaceStyle: String, CaseIterable, Identifiable {
    case simple, library, wall
    static let preferenceKey = "MiniVoice.interfaceStyle"
    var id: Self { self }
    var title: String {
        switch self {
        case .simple: "简易样式"
        case .library: "音乐库样式"
        case .wall: "音乐墙样式"
        }
    }
    var next: Self {
        switch self {
        case .simple: .library
        case .library: .wall
        case .wall: .simple
        }
    }
}

struct UserPlaylist: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var paths: [String]
}

/// User organization lives separately from the audio files and folder caches.
/// Paths survive cache rebuilds that create new transient Track identifiers.
@MainActor
final class LibraryCollections: ObservableObject {
    private struct Snapshot: Codable {
        var favorites: Set<String> = []
        var playlists: [UserPlaylist] = []
    }
    private static let key = "MiniVoice.libraryCollections"
    private let defaults: UserDefaults
    @Published private var snapshot: Snapshot
    @Published private(set) var revision = 0
    var playlists: [UserPlaylist] { snapshot.playlists }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snapshot = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } ?? Snapshot()
    }

    func isFavorite(_ path: String) -> Bool { snapshot.favorites.contains(path) }
    func toggleFavorite(_ path: String) {
        if !snapshot.favorites.insert(path).inserted { snapshot.favorites.remove(path) }
        save()
    }

    func setFavorites(_ paths: [String], favorite: Bool) {
        let paths = Set(paths)
        guard !paths.isEmpty else { return }
        let updated = favorite ? snapshot.favorites.union(paths) : snapshot.favorites.subtracting(paths)
        guard updated != snapshot.favorites else { return }
        snapshot.favorites = updated
        save()
    }

    @discardableResult
    func createPlaylist(name: String) -> UUID? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let id = UUID()
        snapshot.playlists.append(UserPlaylist(id: id, name: name, paths: []))
        save()
        return id
    }

    func renamePlaylist(_ id: UUID, name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = snapshot.playlists.firstIndex(where: { $0.id == id }) else { return }
        snapshot.playlists[index].name = name
        save()
    }

    func deletePlaylist(_ id: UUID) {
        snapshot.playlists.removeAll { $0.id == id }
        save()
    }

    @discardableResult
    func add(_ paths: [String], to id: UUID) -> Int {
        guard let index = snapshot.playlists.firstIndex(where: { $0.id == id }) else { return 0 }
        var seen = Set(snapshot.playlists[index].paths)
        let additions = paths.filter { seen.insert($0).inserted }
        guard !additions.isEmpty else { return 0 }
        snapshot.playlists[index].paths.append(contentsOf: additions)
        save()
        return additions.count
    }

    func remove(_ path: String, from id: UUID) {
        guard let index = snapshot.playlists.firstIndex(where: { $0.id == id }) else { return }
        snapshot.playlists[index].paths.removeAll { $0 == path }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
        revision += 1
    }
}

enum LibraryDestination: Hashable, Sendable {
    case all, recent, favorites, artists, albums, playlist(UUID)
}

extension LibraryDestination {
    func locationForTrack(_ track: Track, isFavorite: Bool, isRecent: Bool,
                          isInPlaylist: Bool) -> LibraryListLocation {
        switch self {
        case .all: return LibraryListLocation(destination: .all, group: nil)
        case .recent where isRecent, .favorites where isFavorite:
            return LibraryListLocation(destination: self, group: nil)
        case .playlist where isInPlaylist:
            return LibraryListLocation(destination: self, group: nil)
        case .artists:
            return LibraryListLocation(destination: .artists, group: LibraryBrowseIndex.name(track.artist, artist: true))
        case .albums:
            return LibraryListLocation(destination: .albums, group: LibraryBrowseIndex.name(track.album, artist: false))
        default: return LibraryListLocation(destination: .all, group: nil)
        }
    }
}

/// A location is a one-time command. Its completion may arrive after the user
/// has selected another page, so only the matching command can clear it.
struct TrackLocationRequest: Equatable {
    var target: UUID?
    var token = UUID()

    mutating func complete(_ completedToken: UUID) {
        guard token == completedToken else { return }
        target = nil
    }
}

struct WorkspaceListRequest: Equatable {
    let list: SongListRequest
    let destination: LibraryDestination
    let group: String?
    let collectionsRevision: Int
    var groupSortField = "name"
    var groupSortAscending = true

    /// Background metadata/cache revisions refresh the same page in place.
    /// Only a different search or location must hide the previous results.
    func canDisplayResults(from previous: Self?) -> Bool {
        guard let previous else { return false }
        return destination == previous.destination && group == previous.group
            && list.query == previous.list.query && list.recent == previous.list.recent
    }
}
