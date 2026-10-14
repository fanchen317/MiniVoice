import SwiftUI

// MusicWallPlayer.swift: readable clock-driven lyrics and controls inside the expanded poster.
struct MusicWallPlayer: View, @MainActor Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track.id == rhs.track.id && lhs.track.title == rhs.track.title && lhs.track.artist == rhs.track.artist
            && lhs.track.lyrics == rhs.track.lyrics && lhs.track.duration == rhs.track.duration
            && lhs.track.artworkKey == rhs.track.artworkKey && lhs.showsArtwork == rhs.showsArtwork
            && lhs.track.artwork.map(ObjectIdentifier.init) == rhs.track.artwork.map(ObjectIdentifier.init)
    }
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    var showsArtwork = true
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if showsArtwork { MusicWallCover(track: track, prefersThumbnail: false).equatable() }
                LinearGradient(stops: [.init(color: .black.opacity(0.86), location: 0),
                                       .init(color: .black.opacity(0.58), location: 0.55),
                                       .init(color: .black.opacity(0.2), location: 1)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .black.opacity(0.12), location: 0.6),
                                       .init(color: .black.opacity(0.88), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 12) {
                    Label(track.id == library.playingID ? (library.isPlaying ? "正在播放" : "已暂停") : "预览",
                          systemImage: library.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(.mint)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.mint.opacity(0.18), in: Capsule())
                        .overlay { Capsule().strokeBorder(.mint.opacity(0.6), lineWidth: 1) }
                    Text(track.title).font(.system(size: min(28, geometry.size.width * 0.05), weight: .bold)).lineLimit(2)
                    Text(track.artist).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                }.padding(22).padding(.top, geometry.size.width < 420 ? 64 : 0)
                MusicWallLyrics(track: track)
                    .padding(.horizontal, 28)
                    .frame(width: geometry.size.width, height: max(100, geometry.size.height * 0.53))
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.52)
                MusicWallTransport(track: track, onPlay: onPlay, onExpand: onExpand)
                    .padding(22).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .foregroundStyle(.white).clipped()
            .overlay { Rectangle().strokeBorder(Color.mint.opacity(0.85), lineWidth: 3).allowsHitTesting(false) }
        }
    }
}

/// Only this subtree observes the playback clock; thousands of cover cards do not redraw on ticks.
private struct MusicWallLyrics: View {
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let track: Track
    var body: some View {
        GeometryReader { geometry in
            let snapshot = track.lyricSnapshot
            let time = track.id == library.playingID ? clock.time : 0
            let active = snapshot.activeIndex(at: time) ?? 0
            let fontSize = min(58, max(24, geometry.size.width * 0.065))
            if snapshot.lines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(track.title).font(.system(size: fontSize, weight: .bold))
                    Text("暂无歌词").font(.callout).foregroundStyle(.white.opacity(0.5))
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                let rowHeight = geometry.size.height / 3
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(-1...1, id: \.self) { relative in
                        let index = active + relative
                        if snapshot.lines.indices.contains(index) {
                            let line = snapshot.lines[index]
                            Button { if let time = line.timestamp, library.playingID == track.id { library.seek(to: time) } } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TimedLyricText(line: relative == 0 ? LyricsDisplayTiming.line(line,
                                                   nextStart: snapshot.lines.dropFirst(index + 1).lazy.compactMap(\.timestamp).first(where: { $0 > (line.timestamp ?? 0) }),
                                                   trackDuration: track.duration) : line,
                                                   time: time, active: relative == 0 && track.id == library.playingID && snapshot.activeIndex(at: time) != nil,
                                                   baseColor: .white, pendingWordOpacity: 0.35, highlightColor: .white,
                                                   isPlaying: track.id == library.playingID && library.isPlaying, sampledAt: clock.sampledAt)
                                        .font(.system(size: relative == 0 ? fontSize : fontSize * 0.73, weight: .bold))
                                        .shadow(color: .black.opacity(0.75), radius: 5, y: 2)
                                        .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.leading)
                                    if let translation = line.translation, relative == 0 {
                                        Text(translation).font(.system(size: fontSize * 0.42)).foregroundStyle(.white.opacity(0.82)).lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: rowHeight - 10, alignment: .leading)
                            }.buttonStyle(.plain)
                                .opacity(relative == 0 ? 1 : 0.58)
                                .blur(radius: relative == 0 ? 0 : 0.3)
                                .frame(height: rowHeight)
                        } else { Color.clear.frame(height: rowHeight) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: active)
            }
        }
    }
}

private struct MusicWallTransport: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var clock: PlaybackClock
    let track: Track
    let onPlay: () -> Void
    let onExpand: () -> Void
    @State private var scrub: Double?
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                control(library.isPlaying && library.playingID == track.id ? "pause.fill" : "play.fill", "播放 / 暂停", action: onPlay)
                control("backward.end", "上一曲") { library.skip(-1) }
                Menu {
                    ForEach(PlaybackMode.allCases) { mode in
                        Button { library.playbackMode = mode } label: {
                            Label(mode.title, systemImage: library.playbackMode == mode ? "checkmark" : mode.symbolName)
                        }
                    }
                } label: {
                    Image(systemName: library.playbackMode.symbolName).frame(width: 32, height: 32)
                        .padding(3).background(.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                }
                    .menuStyle(.borderlessButton).fixedSize().help("播放模式：" + library.playbackMode.title)
                    .animation(.easeInOut(duration: 0.18), value: library.playbackMode)
                control("forward.end", "下一曲") { library.skip(1) }
                Spacer(minLength: 0)
                Text("\(time(scrub ?? (library.playingID == track.id ? clock.time : 0))) / \(time(track.duration))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                control("arrow.up.left.and.arrow.down.right", "展开 / 收起播放器", action: onExpand)
            }
            Slider(value: Binding(get: { scrub ?? min(max(0, library.playingID == track.id ? clock.time : 0), max(1, track.duration)) }, set: { scrub = $0 }),
                   in: 0...max(1, track.duration), onEditingChanged: { editing in
                if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
            }).tint(.white).controlSize(.mini).help("播放进度").disabled(library.playingID != track.id)
        }
        .background(MusicWallInputExclusion())
        .onChange(of: track.id) { _ in scrub = nil }
    }
    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 16)).frame(width: 32, height: 32) }
            .buttonStyle(MusicWallControlStyle()).help(label).accessibilityLabel(label)
    }
    private func time(_ value: Double) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

/// A visible hit area and immediate press feedback for the poster transport.
struct MusicWallControlStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        Feedback(configuration: configuration, reduceMotion: reduceMotion)
    }
    private struct Feedback: View {
        let configuration: ButtonStyleConfiguration
        let reduceMotion: Bool
        @State private var hovered = false
        var body: some View {
            configuration.label.padding(3)
                .background(.white.opacity(configuration.isPressed ? 0.25 : hovered ? 0.13 : 0.04),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(configuration.isPressed ? Color.mint : Color.white)
                .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.88 : hovered ? 1.06 : 1)
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
        }
    }
}
