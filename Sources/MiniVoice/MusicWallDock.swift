import SwiftUI

// MusicWallDock.swift: fixed minimal controls stay reachable while the wall camera moves.
struct MusicWallDock: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var clock: PlaybackClock
    let track: Track?
    let onPlay: () -> Void
    let onLocate: () -> Void
    @State private var scrub: Double?
    @State private var showingQueue = false
    private var isPlaying: Bool { library.isPlaying && library.playingID == track?.id }
    private var currentTime: Double { library.playingID == track?.id ? clock.time : 0 }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 420
            HStack(spacing: compact ? 8 : 12) {
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: compact ? 18 : 21, weight: .bold))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)
                        .background(.white.opacity(0.94), in: Circle())
                }.buttonStyle(.plain).disabled(track == nil).help("播放 / 暂停").accessibilityLabel("播放 / 暂停")
                VStack(spacing: 4) {
                    HStack(spacing: 10) {
                        Button { library.skip(-1) } label: { Image(systemName: "chevron.left").frame(width: 22, height: 20) }
                            .buttonStyle(.plain).help("上一曲").disabled(library.playingTrack == nil)
                        Button(action: onLocate) {
                            Text(track?.title ?? "选择一首音乐").font(.system(size: 13, weight: .semibold))
                                .lineLimit(1).frame(maxWidth: .infinity)
                        }.buttonStyle(.plain).help("定位歌曲")
                        Button { library.skip(1) } label: { Image(systemName: "chevron.right").frame(width: 22, height: 20) }
                            .buttonStyle(.plain).help("下一曲").disabled(library.playingTrack == nil)
                    }
                    HStack(spacing: 8) {
                        if !compact { Text(time(scrub ?? currentTime)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
                        PlaybackGlassSlider(value: Binding(get: {
                            scrub ?? min(max(0, currentTime), max(1, track?.duration ?? 1))
                        }, set: { scrub = $0 }), range: 0...max(1, track?.duration ?? 1),
                        tint: .white.opacity(0.85), label: "播放进度", onEditingChanged: { editing in
                            if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
                        })
                        .disabled(track == nil || library.playingID != track?.id)
                        if !compact { Text(time(track?.duration ?? 0)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
                    }.frame(height: 18)
                }
                Menu {
                    ForEach(PlaybackMode.allCases) { mode in
                        Button { library.playbackMode = mode } label: {
                            Label(mode.title, systemImage: library.playbackMode == mode ? "checkmark" : mode.symbolName)
                        }
                    }
                } label: { Image(systemName: library.playbackMode.symbolName).font(.system(size: 20)).frame(width: 28) }
                    .menuStyle(.borderlessButton).fixedSize().help("播放模式")
                if !compact {
                    Button { showingQueue.toggle() } label: { Image(systemName: "list.bullet").font(.system(size: 20)).frame(width: 25) }
                        .buttonStyle(.plain).help("播放队列")
                        .popover(isPresented: $showingQueue) {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 4) {
                                    ForEach(library.playbackIDs, id: \.self) { id in
                                        if let song = library.track(for: id) {
                                            Button { library.play(id); showingQueue = false } label: {
                                                HStack {
                                                    Image(systemName: id == library.playingID ? "speaker.wave.2.fill" : "music.note")
                                                        .frame(width: 20).foregroundStyle(id == library.playingID ? .mint : .secondary)
                                                    VStack(alignment: .leading) {
                                                        Text(song.title).lineLimit(1)
                                                        Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                                    }
                                                    Spacer()
                                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }.padding(10)
                            }.frame(width: 300, height: 360)
                        }
                }
            }
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, 8)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .modifier(MusicWallGlass(radius: 45))
        }
        .frame(height: 64)
        .foregroundStyle(.white)
        .onChange(of: track?.id) { _ in scrub = nil }
    }
    private func time(_ value: Double) -> String {
        let seconds = Int(max(0, value.isFinite ? value : 0))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
