import SwiftUI

// MusicWallPreview.swift: browsing expands a poster without displaying another song's playback state.
struct MusicWallPreview: View {
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [.black.opacity(0.12), .clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text(track.title).font(.system(size: 27, weight: .bold)).lineLimit(2)
                Text(track.artist).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                HStack {
                    Button(action: onPlay) { Image(systemName: "play.fill").font(.system(size: 17)).frame(width: 28, height: 30) }
                        .buttonStyle(MusicWallControlStyle()).help("播放歌曲").accessibilityLabel("播放歌曲")
                    Spacer()
                    Button(action: onExpand) { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 28, height: 30) }
                        .buttonStyle(MusicWallControlStyle()).help("展开播放器")
                }.padding(.top, 12).background(MusicWallInputExclusion())
            }.padding(22)
        }.foregroundStyle(.white)
    }
}
