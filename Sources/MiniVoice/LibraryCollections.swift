import Foundation
import Combine

enum PlayerInterfaceStyle: String, CaseIterable, Identifiable {
    case simple, library
    static let preferenceKey = "MiniVoice.interfaceStyle"
    var id: Self { self }
    var title: String { self == .simple ? "简易样式" : "音乐库样式" }
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

struct WorkspaceListRequest: Equatable {
    let list: SongListRequest
    let destination: LibraryDestination
    let group: String?
    let collectionsRevision: Int
    var groupSortField = "name"
    var groupSortAscending = true
}
