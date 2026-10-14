import SwiftUI
import AppKit

// MusicWallPoster.swift: cached artwork and cover captions shared by the wall and player.
struct MusicWallCover: View, @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.prefersThumbnail == rhs.prefersThumbnail
            && lhs.track.id == rhs.track.id && lhs.track.artworkKey == rhs.track.artworkKey
            && lhs.track.artwork.map(ObjectIdentifier.init) == rhs.track.artwork.map(ObjectIdentifier.init)
    }
    let track: Track
    var prefersThumbnail = true
    @StateObject private var loader = ListArtworkLoader()
    @EnvironmentObject private var library: MusicLibrary
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(red: 0.22, green: 0.3, blue: 0.29), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let image = (prefersThumbnail ? nil : track.artwork)
                    ?? PreparedBrowseArtwork.shared.image(track.artworkKey)
                    ?? loader.currentImage(key: track.artworkKey, source: track.url, browse: true) ?? track.artwork {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Image(systemName: "music.note").font(.system(size: min(geometry.size.width, geometry.size.height) * 0.25))
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
        }
        .onAppear { load() }
        .onChange(of: track.artworkKey) { _ in load() }
        .onChange(of: library.browseArtworkRevision) { _ in load() }
        .onDisappear { loader.cancel() }
    }
    private func load() { loader.load(key: track.artworkKey, source: track.url, browse: true) }
}

struct MusicWallPoster: View, @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id && lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
            && lhs.number == rhs.number && lhs.size == rhs.size && lhs.showsArtwork == rhs.showsArtwork
    }
    let track: Track
    let title: String
    let subtitle: String
    let number: Int
    let size: CGSize
    var showsArtwork = true
    @State private var hovering = false
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if showsArtwork { MusicWallCover(track: track).equatable() }
            Color.black.opacity(hovering ? 0.08 : 0.28)
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: min(30, max(18, size.width * 0.105)), weight: .bold)).lineLimit(2)
                Text(subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
            }.padding(14).padding(.bottom, 3)
        }
        .overlay(alignment: .topLeading) {
            Text(String(format: "%03d", number)).font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2).padding(6).background(.black.opacity(0.45)).padding(10)
        }
        .foregroundStyle(.white.opacity(hovering ? 1 : 0.8))
        .clipped().contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}
