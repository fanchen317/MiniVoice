import SwiftUI

// MusicWallPreview.swift: browsing expands a poster without displaying another song's playback state.
struct MusicWallPreview: View {
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    var body: some View {
        GeometryReader { geometry in
            let sizing = MusicWallCardSizing(size: geometry.size)
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [.black.opacity(0.12), .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text(track.title).font(.system(size: sizing.title, weight: .bold)).lineLimit(2)
                    Text(track.artist).font(.system(size: sizing.artist)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    HStack {
                        Button(action: onPlay) { Image(systemName: "play.fill").font(.system(size: max(13, sizing.title * 0.6))).frame(width: 28, height: 30) }
                            .buttonStyle(MusicWallControlStyle()).help("播放歌曲").accessibilityLabel("播放歌曲")
                        Spacer()
                        Button(action: onExpand) { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: max(13, sizing.title * 0.6))).frame(width: 28, height: 30) }
                            .buttonStyle(MusicWallControlStyle()).help("展开播放器")
                    }.padding(.top, 12)
                }.padding(sizing.padding)
            }.foregroundStyle(.white)
        }
    }
}
