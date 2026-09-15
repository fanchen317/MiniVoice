import SwiftUI
import AppKit

private let playerGreen = Color(red: 0.06, green: 0.66, blue: 0.46)

struct ContentView: View {
    let statusBar: StatusBarController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var library: MusicLibrary
    @State private var sidebarVisible = true
    @State private var recent = false
    @State private var query = ""
    @State private var multiSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var editingTrack: Track?
    @State private var deleteTargets: [Track] = []
    @State private var deleting = false
    @State private var deleteFiles = false
    @AppStorage("MiniVoice.trackSortOrder") private var sortOrder = "modified"
    @AppStorage("MiniVoice.trackSortField") private var sortField = "added"
    @AppStorage("MiniVoice.trackSortAscending") private var sortAscending = false

    @State private var songs: [Track] = []
    @State private var listIndex = SongListIndex()

    private var listRequest: SongListRequest {
        SongListRequest(revision: library.tracksRevision, recentPaths: recent ? library.recentPaths : [],
                        recent: recent, query: query, field: sortField, ascending: sortAscending)
    }

    private func updateSongs() async {
        if recent {
            let matches = library.recentTracks(matching: query)
            if !Task.isCancelled { songs = matches }
            return
        }
        let source = library.tracks
        let request = listRequest
        let entries = source.map { SongListEntry(id: $0.id, url: $0.url, title: $0.title, artist: $0.artist, album: $0.album) }
        // Only metadata crosses to the worker; AppKit artwork stays on the main actor.
        let ids = await listIndex.orderedIDs(entries, request: request)
        guard !Task.isCancelled else { return }
        songs = ids.compactMap { library.track(for: $0) }
    }

    private func migrateSortPreferenceIfNeeded() {
        guard UserDefaults.standard.object(forKey: "MiniVoice.trackSortField") == nil else { return }
        switch sortOrder {
        case "artist":
            sortField = "artist"; sortAscending = true
        case "title":
            sortField = "title"; sortAscending = true
        default:
            sortField = "added"; sortAscending = false
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 14) {
                if sidebarVisible {
                    sidebar
                        .frame(width: min(288, max(240, geometry.size.width * 0.25)))
                        .frame(maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.55), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                }
                Group {
                    if let track = library.selectedTrack {
                        let playbackTrack = library.playingTrack ?? track
                        PlayerDetail(track: track, playbackTrack: playbackTrack, onEdit: { editingTrack = track }, onEditPlayback: { editingTrack = playbackTrack }, onToggleSidebar: { sidebarVisible.toggle() })
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "music.note.list").font(.largeTitle)
                            Text("添加你的音乐文件夹").font(.title2)
                            OpenSettingsButton()
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.top, 42)
            .padding(.bottom, 12)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background { CoverBackdrop(image: library.selectedTrack?.artwork) }
        }
        .ignoresSafeArea()
        .tint(playerGreen)
        .task(id: listRequest) { await updateSongs() }
        .onAppear {
            migrateSortPreferenceIfNeeded()
            statusBar.start(library: library, openMainWindow: { openWindow(id: "main") })
        }
        .sheet(item: $editingTrack) { MetadataEditor(track: $0) }
        .sheet(isPresented: $deleting) {
            VStack(alignment: .leading, spacing: 18) {
                Text("删除 \(deleteTargets.count) 首歌曲？").font(.title3.bold())
                Text(deleteFiles ? "本地文件将移至废纸篓。" : "仅从音乐库移除，保留本地文件。")
                Toggle("同时移至废纸篓", isOn: $deleteFiles)
                HStack {
                    Spacer()
                    Button("取消") { deleting = false }
                    Button("确认删除", role: .destructive) {
                        library.deleteTracks(ids: Set(deleteTargets.map(\.id)), moveFilesToTrash: deleteFiles)
                        selectedIDs.removeAll()
                        deleting = false
                    }
                }
            }.padding(24).frame(width: 360)
        }
        .alert("操作失败", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 46, height: 46)
                    .accessibilityLabel("MiniVoice")
                VStack(alignment: .leading, spacing: 4) {
                    Text("MiniVoice").font(.title3.weight(.bold))
                    Text("音乐让生活更美好").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索歌曲、歌手或专辑", text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("清空搜索").accessibilityLabel("清空搜索")
                }
            }.padding(10).background(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.58 : 0.65), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 4) {
                navigationItem("音乐库", symbol: "music.note", isRecent: false)
                navigationItem("最近播放", symbol: "clock", isRecent: true)
            }
            Divider().opacity(0.4)
            libraryToolbar
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(songs) { track in
                        songRow(track)
                    }
                    if songs.isEmpty {
                        Text(recent ? "播放歌曲后，记录会保存在这里" : "没有找到歌曲")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 30)
                    }
                }
                .background(HiddenScrollerConfigurator())
            }
            if library.isImporting { ProgressView("正在读取音乐…").controlSize(.small) }
        }
        .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 12)
        .frame(maxHeight: .infinity)
        .background {
            FrostedBackdrop(material: .hudWindow, blendingMode: .withinWindow)
            Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.34 : 0.22)
        }
    }

    private func navigationItem(_ title: String, symbol: String, isRecent: Bool) -> some View {
        Button {
            recent = isRecent
            selectedIDs.removeAll()
            if isRecent { multiSelecting = false }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22)
                Text(title).fontWeight(recent == isRecent ? .semibold : .regular)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .contentShape(Rectangle())
            .foregroundStyle(recent == isRecent ? playerGreen : Color.primary)
            .background(recent == isRecent ? playerGreen.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var libraryToolbar: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(recent ? "最近播放" : "我的歌曲")
                    .font(.caption.weight(.semibold))
                Text("\(songs.count) 首")
                    .font(.caption2.monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 0)
            if !recent {
                Button { library.rescan() } label: {
                    LibraryToolbarIcon(symbol: "arrow.clockwise", showBorder: false)
                }
                .help("重新扫描").accessibilityLabel("重新扫描")
                .disabled(library.isImporting)
            }
            if !recent {
                Menu {
                    sortFieldButton("添加时间", field: "added")
                    sortFieldButton("歌曲名称", field: "title")
                    sortFieldButton("歌手姓名", field: "artist")
                    Divider()
                    sortDirectionButton("正序", ascending: true)
                    sortDirectionButton("降序", ascending: false)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .modifier(LibraryToolbarSurface())
                .help("歌曲排序").accessibilityLabel("歌曲排序")
                .disabled(songs.isEmpty)
                Button { multiSelecting.toggle(); selectedIDs.removeAll() } label: {
                    LibraryToolbarIcon(symbol: multiSelecting ? "checkmark.circle.fill" : "checklist", showBorder: false)
                }
                .help(multiSelecting ? "退出多选" : "多选歌曲")
                .accessibilityLabel(multiSelecting ? "退出多选" : "多选歌曲")
                .disabled(songs.isEmpty && !multiSelecting)
                Button { requestDelete(Array(selectedIDs)) } label: {
                    LibraryToolbarIcon(symbol: "trash")
                }
                .disabled(!multiSelecting || selectedIDs.isEmpty)
                .help("删除所选歌曲").accessibilityLabel("删除所选歌曲")
            } else {
                Menu { Button("清空最近播放记录") { library.clearRecentPlayback() } }
                    label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .fixedSize().modifier(LibraryToolbarSurface())
                    .disabled(songs.isEmpty)
            }
        }
        .buttonStyle(.plain)
        .frame(height: 36)
    }

    private func sortFieldButton(_ title: String, field: String) -> some View {
        Button {
            sortField = field
            sortOrder = field == "added" ? "modified" : field
        } label: {
            HStack {
                if sortField == field {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
        }
    }

    private func sortDirectionButton(_ title: String, ascending: Bool) -> some View {
        Button { sortAscending = ascending } label: {
            HStack {
                if sortAscending == ascending {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
        }
    }

    private func songRow(_ track: Track) -> some View {
        HStack(spacing: 10) {
            if multiSelecting {
                Image(systemName: selectedIDs.contains(track.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(playerGreen)
            }
            Artwork(image: track.artwork, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if library.playingID == track.id && !multiSelecting {
                Image(systemName: library.isPlaying ? "waveform" : "music.note").foregroundStyle(playerGreen)
            }
        }
        .padding(7)
        .background((multiSelecting ? selectedIDs.contains(track.id) : library.selectedID == track.id) ? playerGreen.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 11))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !multiSelecting { library.play(track.id) } }
        .onTapGesture {
            if multiSelecting {
                if selectedIDs.contains(track.id) { selectedIDs.remove(track.id) } else { selectedIDs.insert(track.id) }
            } else { library.select(track.id) }
        }
        .contextMenu {
            Button("播放") { library.play(track.id) }
            Button("编辑歌曲信息与歌词") { editingTrack = track }
            Button("删除歌曲") { requestDelete([track.id]) }
        }
    }

    private func requestDelete(_ ids: [UUID]) {
        let requested = Set(ids)
        deleteTargets = library.tracks.filter { requested.contains($0.id) }
        guard !deleteTargets.isEmpty else { return }
        deleteFiles = false
        deleting = true
    }
}

private struct PlayerDetail: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.colorScheme) private var colorScheme
    let track: Track
    let playbackTrack: Track
    let onEdit: () -> Void
    let onEditPlayback: () -> Void
    let onToggleSidebar: () -> Void
    @State private var expandedLyrics = false
    @AppStorage("MiniVoice.followLyrics") private var followLyrics = true

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 720
            let controlsHeight: CGFloat = compact ? 166 : 116
            let contentHeight = max(0, geometry.size.height - controlsHeight - 64)
            // Reserve space for the lyric card before sizing the artwork.
            let artworkSize = max(112, min(260, min(geometry.size.width * 0.34, min(geometry.size.height * 0.30, contentHeight - 206))))
            VStack(spacing: 12) {
                header
                    .frame(height: 40)
                if !expandedLyrics {
                    hero(size: artworkSize)
                        .frame(height: artworkSize)
                        .padding(.horizontal, 16)
                }
                lyrics.frame(maxHeight: .infinity).layoutPriority(1)
                PlayerControls(track: playbackTrack, compact: compact, onEdit: onEditPlayback)
                    .frame(height: controlsHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onToggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 22, weight: .medium))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(SidebarToggleStyle())
            .help("显示或隐藏侧栏")
            Spacer()
            Button(action: onEdit) { Image(systemName: "ellipsis") }
                .buttonStyle(GlassButtonStyle()).help("编辑歌曲")
        }.padding(.horizontal, 8)
    }

    private func hero(size: CGFloat) -> some View {
        HStack(spacing: 22) {
            Artwork(image: track.artwork, size: size)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.8), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            VStack(alignment: .leading, spacing: size < 160 ? 6 : 12) {
                Text(track.title).font(.system(size: size < 160 ? 20 : (size < 180 ? 23 : 30), weight: .bold)).lineLimit(2).minimumScaleFactor(0.85)
                Text(track.artist).font(.headline).lineLimit(1)
                Text(track.album).foregroundStyle(.secondary).lineLimit(size < 160 ? 1 : 2)
                if size >= 160 {
                    Button(action: onEdit) { Image(systemName: "ellipsis") }
                        .buttonStyle(GlassButtonStyle()).padding(.top, 6)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lyrics: some View {
        VStack(spacing: 0) {
            HStack {
                Text("歌词").font(.headline)
                Spacer()
                Toggle("自动跟随", isOn: $followLyrics).toggleStyle(.switch).controlSize(.small)
                    .fixedSize().disabled(!playbackTrack.lyricLines.contains { $0.timestamp != nil })
                Button { expandedLyrics.toggle() } label: {
                    Image(systemName: expandedLyrics ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }.buttonStyle(.plain).help("展开或收起歌词")
            }.padding(18)
            if playbackTrack.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ViewThatFits(in: .vertical) {
                  VStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "text.alignleft").font(.system(size: 42)).foregroundStyle(.secondary.opacity(0.22))
                        Image(nsImage: NSApplication.shared.applicationIconImage).resizable().scaledToFit().frame(width: 38, height: 38)
                    }
                    Text("尚未添加歌词").font(.title3.weight(.semibold))
                    Button("添加歌词", action: onEditPlayback).buttonStyle(GlassButtonStyle())
                  }.fixedSize(horizontal: false, vertical: true)
                  HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().scaledToFit().frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("尚未添加歌词").font(.headline)
                        Button("添加歌词", action: onEditPlayback).buttonStyle(GlassButtonStyle())
                    }
                  }.fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16).padding(.bottom, 14)
            } else {
                SyncedLyrics(track: playbackTrack, follow: followLyrics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.58 : 0.65), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SyncedLyrics: View {
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let follow: Bool
    @EnvironmentObject private var clock: PlaybackClock
    private var active: Int? { MusicLibrary.activeLyricIndex(for: track.lyricLines, at: clock.time) }
    var body: some View {
        let active = active
        let lines = track.lyricLines
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line.text.isEmpty ? "•••" : line.text)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(active == index ? Color.primary : Color.secondary.opacity(0.52))
                                .blur(radius: line.timestamp != nil && active != index ? 0.7 : 0)
                                .scaleEffect(active == index ? 1 : 0.96, anchor: .leading)
                                .animation(.easeInOut(duration: 0.35), value: active)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle()).id(index)
                                .onTapGesture { if let time = line.timestamp { library.seek(to: time) } }
                        }
                    }.padding(.horizontal, 32).padding(.vertical, geometry.size.height * 0.32)
                }
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1), .init(color: .black, location: 0.9), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                .onChange(of: active) { index in
                    if follow, let index { withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo(index, anchor: .center) } }
                }
                .onChange(of: follow) { enabled in
                    if enabled, let active { withAnimation { proxy.scrollTo(active, anchor: .center) } }
                }
                .onChange(of: track.id) { _ in proxy.scrollTo(0, anchor: .top) }
            }
        }
    }
}

private struct PlayerControls: View {
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var volume: SystemVolume
    @EnvironmentObject private var desktopLyrics: DesktopLyricsController
    @Environment(\.colorScheme) private var colorScheme
    let track: Track
    let compact: Bool
    let onEdit: () -> Void
    @State private var scrub: Double?
    var body: some View {
        Group {
            if compact {
                VStack(spacing: 12) {
                    transport
                    HStack(spacing: 18) {
                        trackInfo.frame(maxWidth: .infinity, alignment: .leading)
                        output.frame(width: 150)
                    }
                }
            } else {
                HStack(spacing: 18) {
                    trackInfo.frame(width: 160)
                    transport.frame(maxWidth: .infinity)
                    output.frame(width: 160)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.74 : 0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: track.id) { _ in scrub = nil }
    }

    private var trackInfo: some View {
        HStack(spacing: 10) {
            Artwork(image: track.artwork, size: compact ? 58 : 62)
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Button(action: onEdit) { Image(systemName: "ellipsis") }.buttonStyle(.plain).help("编辑歌曲")
        }
    }

    private var transport: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(time(scrub ?? clock.time))
                Slider(value: Binding(get: { scrub ?? clock.time }, set: { scrub = $0 }), in: 0...max(track.duration, 1)) { editing in
                    if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
                }.accessibilityLabel("播放进度")
                Text(time(track.duration))
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 26) {
                Button {
                    let modes = PlaybackMode.allCases
                    let current = modes.firstIndex(of: library.playbackMode) ?? 0
                    library.playbackMode = modes[(current + 1) % modes.count]
                } label: { Image(systemName: library.playbackMode.symbolName) }
                    .foregroundStyle(library.playbackMode == .list ? .secondary : playerGreen)
                    .help("当前：\(library.playbackMode.title)，点击切换模式")
                Button { library.skip(-1) } label: { Image(systemName: "backward.end.fill") }.help("上一首")
                Button { library.togglePlayback() } label: {
                    Image(systemName: library.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(playerGreen.gradient, in: Circle())
                        .shadow(color: playerGreen.opacity(0.22), radius: 8, y: 4)
                }.help("播放 / 暂停")
                Button { library.skip(1) } label: { Image(systemName: "forward.end.fill") }.help("下一首")
                Button { desktopLyrics.toggle() } label: {
                    Image(systemName: desktopLyrics.isEnabled ? "text.bubble.fill" : "text.bubble")
                }
                .foregroundStyle(desktopLyrics.isEnabled ? playerGreen : .primary)
                .help(desktopLyrics.isEnabled ? "关闭桌面歌词" : "显示桌面歌词")
            }.buttonStyle(.plain).font(.system(size: 17))
        }
    }

    private var output: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                Slider(value: Binding(get: { volume.value }, set: { volume.set($0) }), in: 0...1)
                    .disabled(!volume.canSetVolume).accessibilityLabel("系统音量")
                Text(volume.canSetVolume ? "\(Int(volume.value * 100))%" : "—").monospacedDigit()
            }
            Menu {
                ForEach(volume.outputDevices) { device in
                    Button {
                        volume.selectOutputDevice(device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                            if device.id == volume.outputDeviceID { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Label(volume.error ?? volume.deviceName, systemImage: "airplayaudio")
                    .lineLimit(1)
            }
            .menuStyle(.borderlessButton)
            .help(volume.error ?? "切换播放输出设备")
        }.font(.caption).foregroundStyle(.secondary)
    }
    private func time(_ value: Double) -> String { String(format: "%d:%02d", Int(max(0, value)) / 60, Int(max(0, value)) % 60) }
}

private struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(playerGreen.opacity(0.6)) }
        }.frame(width: size, height: size)
            .background(playerGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: size > 100 ? 22 : 9))
    }
}

private struct FrostedBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // Keep the artwork-tinted glass consistent when the window loses focus.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

/// A shared, cover-driven background.  The actual artwork is deliberately
/// enlarged and blurred so that it supplies colour and atmosphere without
/// competing with controls or text placed above it.
private struct CoverBackdrop: View {
    let image: NSImage?

    var body: some View {
        GeometryReader { geometry in
          ZStack {
            FrostedBackdrop(material: .underWindowBackground)
            LinearGradient(
                colors: CoverPalette.colors(for: image),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.66)

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.24)
                    .blur(radius: 52)
                    .opacity(0.38)
            }

            Color.white.opacity(0.06)
          }
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

@MainActor
private enum CoverPalette {
    private static let cache = NSCache<NSImage, NSArray>()
    static func colors(for image: NSImage?) -> [Color] {
        cache.countLimit = 8
        if let image, let cached = cache.object(forKey: image) as? [NSColor] {
            return cached.map { Color(nsColor: $0) }
        }
        guard let data = image?.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data), bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0
        else {
            return [Color(red: 0.90, green: 0.97, blue: 0.98), Color(red: 0.94, green: 0.99, blue: 0.97)]
        }
        let sampleStep = max(1, min(bitmap.pixelsWide, bitmap.pixelsHigh) / 18)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, count: CGFloat = 0
        for x in Swift.stride(from: 0, to: bitmap.pixelsWide, by: sampleStep) {
            for y in Swift.stride(from: 0, to: bitmap.pixelsHigh, by: sampleStep) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                red += color.redComponent; green += color.greenComponent; blue += color.blueComponent; count += 1
            }
        }
        guard count > 0 else { return [Color.white, Color(red: 0.91, green: 0.97, blue: 0.97)] }
        let base = NSColor(red: red / count, green: green / count, blue: blue / count, alpha: 1)
        let bright = NSColor(red: min(1, base.redComponent * 0.38 + 0.62), green: min(1, base.greenComponent * 0.38 + 0.62), blue: min(1, base.blueComponent * 0.38 + 0.62), alpha: 1)
        let soft = NSColor(red: min(1, base.redComponent * 0.20 + 0.80), green: min(1, base.greenComponent * 0.20 + 0.80), blue: min(1, base.blueComponent * 0.20 + 0.80), alpha: 1)
        if let image { cache.setObject([bright, soft] as NSArray, forKey: image) }
        return [Color(nsColor: bright), Color(nsColor: soft)]
    }
}

/// Shared visual treatment for both ordinary buttons and the sorting menu.
private struct LibraryToolbarIcon: View {
    let symbol: String
    var showBorder: Bool = true
    var body: some View {
        Image(systemName: symbol).modifier(LibraryToolbarSurface(showBorder: showBorder))
    }
}

private struct LibraryToolbarSurface: ViewModifier {
    var showBorder: Bool = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isEnabled ? playerGreen : Color.secondary.opacity(0.42))
            .frame(width: 32, height: 32)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isEnabled && hovered ? playerGreen.opacity(0.18) : .clear)
            }
            .overlay {
                if showBorder && hovered {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(playerGreen.opacity(0.15), lineWidth: 0.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { hovered = $0 }
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.white.opacity(configuration.isPressed ? 0.4 : 0.7), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SidebarToggleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(.white.opacity(configuration.isPressed ? 0.48 : 0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
