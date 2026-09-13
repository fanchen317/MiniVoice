import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    let statusBar: StatusBarController
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var library: MusicLibrary
    @State private var query = ""
    @State private var editingTrack: Track?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                HStack {
                    Text("音乐库").font(.title2.weight(.bold))
                    Spacer()
                    OpenSettingsButton().labelStyle(.iconOnly)
                    Button { library.rescan() } label: { Image(systemName: "arrow.clockwise") }
                        .help("重新扫描文件夹").disabled(library.isImporting)
                }
                .padding([.top, .horizontal])
                TextField("搜索歌曲、歌手或专辑", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal)
                List(selection: Binding(get: { library.selectedID }, set: { if let id = $0 { library.select(id) } })) {
                    ForEach(library.tracks.filter { query.isEmpty || "\($0.title) \($0.artist) \($0.album)".localizedCaseInsensitiveContains(query) }) { track in
                        TrackRow(track: track).tag(track.id)
                            .simultaneousGesture(TapGesture(count: 2).onEnded { library.select(track.id); library.play() })
                    }
                }
                if library.isImporting { ProgressView("正在读取音乐…").controlSize(.small) }
                Text("\(library.tracks.count) 首歌曲 · \(library.folders.count) 个文件夹")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if let track = library.selectedTrack {
                PlayerDetail(track: track, onEdit: { editingTrack = track })
            } else { EmptyLibraryView() }
        }
        .onAppear { statusBar.start(library: library, openMainWindow: { openWindow(id: "main") }) }
        .sheet(item: $editingTrack) { track in MetadataEditor(track: track) }
        .alert("操作失败", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct TrackRow: View {
    let track: Track
    var body: some View {
        HStack(spacing: 10) {
            Artwork(image: track.artwork, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(.vertical, 3)
    }
}

private struct PlayerDetail: View {
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let onEdit: () -> Void
    @AppStorage("MiniVoice.followLyrics") private var followLyrics = true
    var lines: [LyricLine] { track.lyricLines }

    var body: some View {
        let lines = self.lines
        let activeIndex = library.activeLyricIndex(for: lines)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 28) {
                Artwork(image: track.artwork, size: 190)
                VStack(alignment: .leading, spacing: 10) {
                    Text(track.title).font(.largeTitle.weight(.bold)).lineLimit(2)
                    Text(track.artist).font(.title3).foregroundStyle(.secondary)
                    Text(track.album).font(.subheadline).foregroundStyle(.tertiary)
                    Spacer()
                    Button("编辑歌曲信息", action: onEdit).buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(36)

            Divider()
            HStack {
                Toggle("歌词自动跟随", isOn: $followLyrics).toggleStyle(.switch).controlSize(.small)
                    .disabled(!lines.contains { $0.timestamp != nil })
                Spacer()
                Text(lines.contains { $0.timestamp != nil } ? "已识别时间标签 · 点击歌词可跳转" : "纯文本歌词：添加时间标签后可同步滚动")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 36).padding(.top, 12)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line.text)
                                .id(index)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(activeIndex == index ? .primary : .secondary)
                                .opacity(line.timestamp == nil || activeIndex == index ? 1 : 0.45)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture { if let time = line.timestamp { library.seek(to: time) } }
                                .help(line.timestamp == nil ? "手动滚动查看歌词" : "点击跳转到这一句")
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(36)
                }
                .onChange(of: activeIndex) { index in
                    guard followLyrics, let index else { return }
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(index, anchor: .center) }
                }
                .onChange(of: followLyrics) { follow in
                    if follow, let activeIndex { withAnimation { proxy.scrollTo(activeIndex, anchor: .center) } }
                }
                .onChange(of: track.id) { _ in proxy.scrollTo(0, anchor: .top) }
            }
            Spacer(minLength: 0)
            PlayerControls(duration: track.duration).padding(24).background(.bar)
        }
    }
}

private struct PlayerControls: View {
    @EnvironmentObject private var systemVolume: SystemVolume
    @EnvironmentObject private var library: MusicLibrary
    let duration: TimeInterval
    var body: some View {
        VStack(spacing: 10) {
            Picker("播放模式", selection: $library.playbackMode) {
                ForEach(PlaybackMode.allCases) { mode in Text(mode.title).tag(mode) }
            }.pickerStyle(.menu).frame(width: 210).help(library.playbackMode.explanation)
            Slider(value: Binding(get: { library.playbackTime }, set: { value in library.seek(to: value) }), in: 0...max(duration, 1))
            HStack {
                Text(format(library.playbackTime)).monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button { library.skip(-1) } label: { Image(systemName: "backward.end.fill") }
                Button { library.togglePlayback() } label: {
                    Image(systemName: library.isPlaying ? "pause.fill" : "play.fill").font(.title2)
                }.buttonStyle(.borderedProminent).clipShape(Circle())
                Button { library.skip(1) } label: { Image(systemName: "forward.end.fill") }
                Spacer()
                Image(systemName: systemVolume.isMuted ? "speaker.slash" : "speaker.wave.2")
                Slider(value: Binding(get: { systemVolume.value }, set: { systemVolume.set($0) }), in: 0...1)
                    .frame(width: 90).disabled(!systemVolume.canSetVolume)
                    .help(systemVolume.canSetVolume ? "Mac 系统音量 · \(systemVolume.deviceName)" : "当前输出设备不支持软件调音，请使用设备音量键")
                Text(systemVolume.canSetVolume ? "\(Int(systemVolume.value * 100))%" : "设备音量").font(.caption).monospacedDigit()
                Text(format(duration)).monospacedDigit().foregroundStyle(.secondary)
            }
            Text(systemVolume.error ?? (systemVolume.canSetVolume ? "系统输出：\(systemVolume.deviceName)" : "\(systemVolume.deviceName) 不支持软件调音，请使用设备音量键"))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func format(_ seconds: TimeInterval) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

private struct Artwork: View {
    let image: NSImage?; let size: CGFloat
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.system(size: size / 2)).foregroundStyle(.secondary) }
        }.frame(width: size, height: size).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: size > 100 ? 18 : 8))
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("配置你的音乐文件夹").font(.title2.weight(.semibold))
            Text("在设置中添加文件夹，MiniVoice 会扫描其中的音频。").foregroundStyle(.secondary)
            OpenSettingsButton()
        }
    }
}
