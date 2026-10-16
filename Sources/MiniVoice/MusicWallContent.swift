import AppKit

/// The wall always maps poster indices against the same content that produced
/// its scene. SwiftUI change callbacks receive this whole value, rather than
/// reading song arrays captured by an earlier GeometryReader invocation.
struct MusicWallContent: Equatable {
    enum Update: Equatable {
        case waiting
        case metadata
        case rebuild(preserveViewport: Bool)
    }
    let tracks: [Track]
    let groups: [(name: String, tracks: [Track])]
    let isGrouping: Bool
    let query: String
    let isReady: Bool

    var posters: [Track] { isGrouping ? groups.compactMap { $0.tracks.first } : tracks }

    func update(from previous: Self?) -> Update {
        guard isReady else { return .waiting }
        if let previous, query == previous.query, previous.hasSameLayout(as: self) { return .metadata }
        let preserve = previous.map { !$0.posters.isEmpty && $0.query == query && $0.isGrouping == isGrouping } ?? false
        return .rebuild(preserveViewport: preserve)
    }

    func hasSameLayout(as other: Self) -> Bool {
        isGrouping == other.isGrouping && posters.map(\.id) == other.posters.map(\.id)
            && groups.map(\.name) == other.groups.map(\.name)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.isReady == rhs.isReady, lhs.query == rhs.query,
              lhs.hasSameLayout(as: rhs), lhs.tracks.count == rhs.tracks.count else { return false }
        return zip(lhs.tracks, rhs.tracks).allSatisfy(sameTrack)
            && zip(lhs.posters, rhs.posters).allSatisfy(sameTrack)
            && zip(lhs.groups, rhs.groups).allSatisfy { $0.tracks.map(\.id) == $1.tracks.map(\.id) }
    }

    private static func sameTrack(_ pair: (Track, Track)) -> Bool {
        let (lhs, rhs) = pair
        return lhs.id == rhs.id && lhs.title == rhs.title && lhs.artist == rhs.artist
            && lhs.album == rhs.album && lhs.duration == rhs.duration
            && lhs.artworkKey == rhs.artworkKey && lhs.lyricsKey == rhs.lyricsKey
            && lhs.resourcesLoaded == rhs.resourcesLoaded && lhs.lyrics == rhs.lyrics
            && lhs.artwork.map(ObjectIdentifier.init) == rhs.artwork.map(ObjectIdentifier.init)
    }
}

struct MusicWallFocusCommand: Equatable {
    let id: UUID?
    let token: UUID
    let animated: Bool
}
