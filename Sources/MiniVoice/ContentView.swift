import SwiftUI
import AppKit

private let playerGreen = Color(red: 0.06, green: 0.66, blue: 0.46)

struct ContentView: View {
    let statusBar: StatusBarController
    @Environment(\.openWindow) private var openWindow
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

    private var songs: [Track] {
        let source = recent ? library.recentTracks : library.tracks
        let filtered = source.filter { query.isEmpty || "\($0.title) \($0.artist) \($0.album)".localizedCaseInsensitiveContains(query) }
        if recent { return filtered }
        return filtered.sorted {
            if sortOrder == "artist" {
                let order = $0.artist.localizedStandardCompare($1.artist)
                if order != .orderedSame { return order == .orderedAscending }
            }
            if sortOrder == "modified" {
                let left = (try? $0.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? $1.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if left != right { return left > right }
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
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
                        PlayerDetail(track: track, onEdit: { editingTrack = track }, onToggleSidebar: { sidebarVisible.toggle() })
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
        .onAppear { statusBar.start(library: library, openMainWindow: { openWindow(id: "main") }) }
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
            }.padding(10).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 4) {
                navigationItem("音乐库", symbol: "music.note", isRecent: false)
                navigationItem("最近播放", symbol: "clock", isRecent: true)
            }
            Divider().opacity(0.4)
            HStack {
                Text(recent ? "最近播放" : "我的歌曲").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(songs.count)").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
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
            }
            if library.isImporting { ProgressView("正在读取音乐…").controlSize(.small) }
        }
        .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 12)
        .frame(maxHeight: .infinity)
        .background {
            FrostedBackdrop(material: .hudWindow, blendingMode: .withinWindow)
            Color.white.opacity(0.22)
        }
    }

    private func navigationItem(_ title: String, symbol: String, isRecent: Bool) -> some View {
        Button { recent = isRecent; selectedIDs.removeAll() } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22)
                Text(title).fontWeight(recent == isRecent ? .semibold : .regular)
                Spacer()
            }.padding(12).foregroundStyle(recent == isRecent ? playerGreen : Color.primary)
                .background(recent == isRecent ? playerGreen.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private var libraryToolbar: some View {
        HStack(spacing: 16) {
            Button { library.rescan() } label: { Image(systemName: "arrow.clockwise") }
                .help("重新扫描").disabled(library.isImporting)
            Menu {
                Picker("歌曲排序", selection: $sortOrder) {
                    Text("最近添加").tag("modified")
                    Text("歌名正序").tag("title")
                    Text("歌手名称正序").tag("artist")
                }
            } label: { Image(systemName: "arrow.up.arrow.down") }
                .menuStyle(.borderlessButton).frame(width: 30).disabled(recent).help("歌曲排序")
            Button { multiSelecting.toggle(); selectedIDs.removeAll() } label: {
                Image(systemName: multiSelecting ? "checkmark.circle.fill" : "checklist")
            }.help("多选歌曲")
            Button { requestDelete(Array(selectedIDs)) } label: { Image(systemName: "trash") }
                .disabled(!multiSelecting || selectedIDs.isEmpty).help("删除所选歌曲")
            Spacer(minLength: 0)
            if recent {
                Menu { Button("清空最近播放记录") { library.clearRecentPlayback() } }
                    label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
            }
        }.buttonStyle(.plain).font(.system(size: 15)).frame(height: 24)
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
            if library.selectedID == track.id && !multiSelecting {
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
        deleteTargets = library.tracks.filter { ids.contains($0.id) }
        guard !deleteTargets.isEmpty else { return }
        deleteFiles = false
        deleting = true
    }
}

private struct PlayerDetail: View {
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let onEdit: () -> Void
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
                PlayerControls(track: track, compact: compact, onEdit: onEdit)
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
            Button { expandedLyrics = false } label: { Label("歌词", systemImage: "text.line.first.and.arrowtriangle.forward") }
                .buttonStyle(GlassButtonStyle())
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
                    .fixedSize().disabled(!track.lyricLines.contains { $0.timestamp != nil })
                Button { expandedLyrics.toggle() } label: {
                    Image(systemName: expandedLyrics ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }.buttonStyle(.plain).help("展开或收起歌词")
            }.padding(18)
            if track.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ViewThatFits(in: .vertical) {
                  VStack(spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "text.alignleft").font(.system(size: 42)).foregroundStyle(.secondary.opacity(0.22))
                        Image(nsImage: NSApplication.shared.applicationIconImage).resizable().scaledToFit().frame(width: 38, height: 38)
                    }
                    Text("尚未添加歌词").font(.title3.weight(.semibold))
                    Button("添加歌词", action: onEdit).buttonStyle(GlassButtonStyle())
                  }.fixedSize(horizontal: false, vertical: true)
                  HStack(spacing: 14) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().scaledToFit().frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("尚未添加歌词").font(.headline)
                        Button("添加歌词", action: onEdit).buttonStyle(GlassButtonStyle())
                    }
                  }.fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16).padding(.bottom, 14)
            } else {
                SyncedLyrics(track: track, follow: followLyrics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct SyncedLyrics: View {
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let follow: Bool
    private var active: Int? { library.activeLyricIndex(for: track.lyricLines) }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(track.lyricLines.enumerated()), id: \.offset) { index, line in
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
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var volume: SystemVolume
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
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: track.id) { _ in scrub = nil }
    }

    private var trackInfo: some View {
        HStack(spacing: 10) {
            Artwork(image: track.artwork, size: 48)
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
                Text(time(scrub ?? library.playbackTime))
                Slider(value: Binding(get: { scrub ?? library.playbackTime }, set: { scrub = $0 }), in: 0...max(track.duration, 1)) { editing in
                    if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
                }.accessibilityLabel("播放进度")
                Text(time(track.duration))
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 26) {
                Button { library.playbackMode = library.playbackMode == .shuffle ? .list : .shuffle } label: { Image(systemName: "shuffle") }
                    .foregroundStyle(library.playbackMode == .shuffle ? playerGreen : .secondary).help("随机播放")
                Button { library.skip(-1) } label: { Image(systemName: "backward.end.fill") }.help("上一首")
                Button { library.togglePlayback() } label: {
                    Image(systemName: library.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(playerGreen.gradient, in: Circle())
                        .shadow(color: playerGreen.opacity(0.22), radius: 8, y: 4)
                }.help("播放 / 暂停")
                Button { library.skip(1) } label: { Image(systemName: "forward.end.fill") }.help("下一首")
                Button {
                    let modes = PlaybackMode.allCases
                    let current = modes.firstIndex(of: library.playbackMode) ?? 0
                    library.playbackMode = modes[(current + 1) % modes.count]
                } label: { Image(systemName: library.playbackMode.symbolName) }
                    .help("当前：\(library.playbackMode.title)，点击切换模式")
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
            Label(volume.error ?? volume.deviceName, systemImage: "airplayaudio").lineLimit(1)
                .help(volume.error ?? volume.deviceName)
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
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
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

private enum CoverPalette {
    static func colors(for image: NSImage?) -> [Color] {
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
        return [Color(nsColor: bright), Color(nsColor: soft)]
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
