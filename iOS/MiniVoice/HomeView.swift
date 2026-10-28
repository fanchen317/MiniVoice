import SwiftUI
import UniformTypeIdentifiers

private enum Theme {
    static let background = Color(uiColor: .systemBackground)
    static let panel = Color(uiColor: .secondarySystemBackground)
    static let mint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.91, blue: 0.67, alpha: 1)
            : UIColor(red: 0.02, green: 0.40, blue: 0.29, alpha: 1)
    })
    static let muted = Color.secondary
}

private enum BrowserSection: Hashable {
    case songs, recent, favorites, artists, albums, playlist(UUID)

    @MainActor func title(in library: MusicLibrary) -> String {
        switch self {
        case .songs: return "歌曲"
        case .recent: return "最近播放"
        case .favorites: return "收藏"
        case .artists: return "歌手"
        case .albums: return "专辑"
        case .playlist(let id): return library.playlists.first(where: { $0.id == id })?.name ?? "歌单"
        }
    }
}

private enum PresentedSheet: String, Identifiable {
    case settings, queue, player, modes
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @State private var section: BrowserSection = .songs
    @State private var groupName: String?
    @State private var selectedID: String?
    @State private var search = ""
    @State private var searchVisible = false
    @FocusState private var searchFocused: Bool
    @State private var drawerOpen = false
    @State private var sheet: PresentedSheet?
    @State private var showingNewPlaylist = false
    @State private var playlistName = ""
    @AppStorage("ios.wall.zoom") private var zoom = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sectionSongs: [Song] {
        let base: [Song]
        switch section {
        case .songs, .artists, .albums: base = library.songs
        case .recent:
            base = library.recentIDs.compactMap { id in library.songs.first(where: { $0.id == id }) }
        case .favorites: base = library.songs.filter { library.favorites.contains($0.id) }
        case .playlist(let id):
            let ids = library.playlists.first(where: { $0.id == id })?.songIDs ?? []
            base = ids.compactMap { id in library.songs.first(where: { $0.id == id }) }
        }
        let grouped: [Song]
        switch section {
        case .artists where groupName != nil: grouped = base.filter { $0.artist == groupName }
        case .albums where groupName != nil: grouped = base.filter { $0.album == groupName }
        default: grouped = base
        }
        guard !search.isEmpty else { return grouped }
        return grouped.filter { $0.title.localizedCaseInsensitiveContains(search)
            || $0.artist.localizedCaseInsensitiveContains(search)
            || $0.album.localizedCaseInsensitiveContains(search) }
    }

    private var groupedNames: [String]? {
        guard groupName == nil else { return nil }
        let names: [String]
        switch section {
        case .artists: names = Array(Set(library.songs.map(\.artist)))
        case .albums: names = Array(Set(library.songs.map(\.album)))
        default: return nil
        }
        return names.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var focusedSong: Song? {
        guard let selectedID else { return nil }
        return sectionSongs.first { $0.id == selectedID }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Theme.background.ignoresSafeArea()
                Circle()
                    .fill(Theme.mint.opacity(0.09))
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(x: geometry.size.width * 0.55, y: -170)
                    .allowsHitTesting(false)

                content(width: geometry.size.width)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 16)
                    if let focusedSong {
                        VStack(spacing: 8) {
                            HStack {
                                Text("歌曲详情").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                roundButton("xmark", label: "关闭歌曲详情") { selectedID = nil }
                            }
                            focusCard(focusedSong)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
                        .padding(16)
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        if player.current != nil {
                            WallPlaybackDock(width: WallControlMetrics.dockWidth(viewport: geometry.size.width),
                                             blocked: drawerOpen || sheet != nil || searchVisible || focusedSong != nil,
                                             showPlayer: { sheet = .player }, showQueue: { sheet = .queue })
                        }
                        Spacer(minLength: 0)
                        roundButton("gearshape", label: "设置") { sheet = .settings }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                }

                if drawerOpen { drawer(width: geometry.size.width) }
            }
            .accessibilityHidden(sheet != nil && sheet != .player)

        }
        .overlay {
            if let panel = sheet, panel != .player {
                IOSDialogPanel(close: { sheet = nil }) {
                    switch panel {
                    case .settings: SettingsView { sheet = nil }
                    case .modes: ModePickerView(zoom: $zoom, close: { sheet = nil })
                    case .queue: QueueView(close: { sheet = nil })
                    case .player: EmptyView()
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { sheet == .player }, set: { if !$0, sheet == .player { sheet = nil } })) {
            PlayerDetailView()
        }
        .task {
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--mv-ui-fixture") {
                let args = ProcessInfo.processInfo.arguments
                drawerOpen = args.contains("--mv-ui-drawer")
                if args.contains("--mv-ui-settings") { sheet = .settings }
                if args.contains("--mv-ui-modes") { sheet = .modes }
                if args.contains("--mv-ui-queue") { sheet = .queue }
                if args.contains("--mv-ui-focus") { selectedID = library.songs.first?.id }
            }
            #endif
        }
        .onChange(of: drawerOpen) { _, open in if open { searchFocused = false } }
        .onChange(of: sheet) { _, panel in if panel != nil { searchFocused = false } }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: drawerOpen)
        .alert("新建歌单", isPresented: $showingNewPlaylist) {
            TextField("歌单名称", text: $playlistName)
            Button("创建") { library.createPlaylist(name: playlistName); playlistName = "" }
            Button("取消", role: .cancel) { playlistName = "" }
        }
        .alert("提示", isPresented: Binding(get: { library.errorMessage != nil || player.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil; player.errorMessage = nil } })) {
            Button("知道了", role: .cancel) { library.errorMessage = nil; player.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? player.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            roundButton("line.3.horizontal", label: "打开侧栏") { withAnimation(.easeOut(duration: 0.22)) { drawerOpen = true } }
            if searchVisible {
                EmptyView()
            } else if let groupName {
                Button { self.groupName = nil; selectedID = nil } label: {
                    Image(systemName: "chevron.left").font(.headline).foregroundStyle(.primary)
                }
                .accessibilityLabel("返回分类")
                Text(groupName).font(.headline).lineLimit(1)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title(in: library)).font(.headline)
                    Text("\(sectionSongs.count) 首歌曲").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            if searchVisible {
                TextField("搜索歌曲、歌手或专辑", text: $search)
                    .focused($searchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityLabel("搜索音乐库")
            }
            roundButton(searchVisible ? "xmark" : "magnifyingglass", label: searchVisible ? "关闭搜索" : "搜索") {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    searchVisible.toggle()
                    searchFocused = searchVisible
                    if !searchVisible { search = "" }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        if library.isScanning && library.songs.isEmpty {
            ContentUnavailableView("正在扫描音乐", systemImage: "waveform", description: Text("正在读取所选文件夹"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if library.folders.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "music.note.house.fill").font(.system(size: 62)).foregroundStyle(Theme.mint)
                Text("从音乐文件夹开始").font(.title2.bold())
                Text("在“设置”中选择 iPhone、iCloud 云盘或文件提供方中的音乐目录。")
                    .foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("打开设置") { sheet = .settings }
                    .padding(.horizontal, 22).frame(minHeight: 48)
                    .background(Theme.mint.opacity(0.18), in: Capsule())
                    .buttonStyle(IOSActionButtonStyle())
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let names = groupedNames {
            if names.isEmpty {
                ContentUnavailableView("这里还没有内容", systemImage: "music.note.list")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(names, id: \.self) { name in
                            let songs = library.songs.filter { section == .artists ? $0.artist == name : $0.album == name }
                            Button {
                                groupName = name
                                selectedID = nil
                            } label: {
                                HStack(spacing: 14) {
                                    ArtworkView(song: songs.first, size: 56).frame(width: 56, height: 56)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(name).font(.headline).foregroundStyle(.primary)
                                        Text("\(songs.count) 首歌曲").font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                                }
                                .padding(10)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16).padding(.top, 72).padding(.bottom, 110)
                }
            }
        } else if sectionSongs.isEmpty {
            ContentUnavailableView(search.isEmpty ? "这里还没有歌曲" : "没有找到歌曲", systemImage: "music.note.list")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WeightedWallView(songs: sectionSongs, selectedID: $selectedID, zoom: $zoom) { song in
                player.play(song, queue: sectionSongs, library: library)
            }
            .overlay(alignment: .topTrailing) {
                roundButton("slider.horizontal.3", label: "音乐墙设置") { sheet = .modes }
                    .padding(.top, 122).padding(.trailing, 18)
            }
        }
    }

    private func focusCard(_ song: Song) -> some View {
        HStack(spacing: 12) {
            ArtworkView(song: song, size: 70).frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title).font(.headline).lineLimit(1)
                Text(song.artist).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                if player.current?.id == song.id, let line = LRCParser.parse(library.lyrics(for: song)).last(where: { $0.time <= player.position }) {
                    Text(line.text).font(.caption).foregroundStyle(Theme.mint).lineLimit(1)
                }
            }
            Spacer(minLength: 2)
            Button { library.toggleFavorite(song) } label: {
                Image(systemName: library.isFavorite(song) ? "heart.fill" : "heart")
                    .foregroundStyle(Theme.mint).frame(width: 36, height: 44)
            }
            .accessibilityLabel(library.isFavorite(song) ? "取消收藏" : "收藏")
            Button {
                if player.current?.id == song.id { player.toggle() }
                else { player.play(song, queue: sectionSongs, library: library) }
            } label: {
                Image(systemName: player.current?.id == song.id && player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline).foregroundStyle(Theme.background)
                    .frame(width: 44, height: 44).background(Theme.mint, in: Circle())
            }
            .accessibilityLabel(player.current?.id == song.id && player.isPlaying ? "暂停" : "播放")
        }
        .padding(10)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(Theme.mint.opacity(0.32)))
    }

    private func drawer(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture { withAnimation { drawerOpen = false } }
            ScrollView {
              VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 11) {
                    Image("AppIconPreview").resizable().frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MiniVoice").font(.title3.bold())
                        Text("音乐让生活更美好").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { withAnimation { drawerOpen = false } } label: { Image(systemName: "xmark").frame(width: 36, height: 36) }
                        .accessibilityLabel("关闭侧栏")
                }
                .padding(.bottom, 20)
                drawerRow("歌曲", symbol: "music.note.list", target: .songs)
                drawerRow("最近播放", symbol: "clock", target: .recent)
                drawerRow("收藏", symbol: "heart", target: .favorites)
                drawerRow("歌手", symbol: "person.2", target: .artists)
                drawerRow("专辑", symbol: "square.stack", target: .albums)
                Divider().padding(.vertical, 12)
                HStack {
                    Text("歌单").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { withAnimation { drawerOpen = false }; showingNewPlaylist = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("新建歌单")
                }
                ForEach(library.playlists) { playlist in
                    drawerRow(playlist.name, symbol: "music.note", target: .playlist(playlist.id))
                        .contextMenu {
                            Button("删除歌单", role: .destructive) {
                                if section == .playlist(playlist.id) { section = .songs }
                                library.deletePlaylist(playlist.id)
                            }
                        }
                }
                Spacer()
                Button {
                    withAnimation { drawerOpen = false }
                    sheet = .settings
                } label: {
                    Label("设置", systemImage: "gearshape")
                        .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
            }
              .padding(18)
            }
            .frame(width: min(width * 0.86, 340))
            .frame(maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(.primary.opacity(0.10)))
            .padding(.vertical, 8).padding(.leading, 8)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private func drawerRow(_ title: String, symbol: String, target: BrowserSection) -> some View {
        Button {
            section = target
            groupName = nil
            selectedID = nil
            search = ""
            withAnimation { drawerOpen = false }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(section == target ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .foregroundStyle(section == target ? Theme.mint : .primary)
                .background(section == target ? Theme.mint.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary).frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14)))
        }
        .buttonStyle(IOSActionButtonStyle())
        .accessibilityLabel(label)
    }

    private func transport(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

private struct ArtworkView: View {
    let song: Song?
    let size: CGFloat

    var body: some View {
        Group {
            if let path = song?.artworkFile, let image = LocalArtwork.image(at: path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Theme.mint.opacity(0.38), Color(red: 0.07, green: 0.15, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: max(20, size * 0.28), weight: .light)).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

private enum LocalArtwork {
    static let cache = NSCache<NSString, UIImage>()

    static func image(at path: String) -> UIImage? {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

private struct WeightedWallView: View {
    let songs: [Song]
    @Binding var selectedID: String?
    @Binding var zoom: Double
    let play: (Song) -> Void
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @State private var scene = WeightedWallScene(count: 0)
    @AppStorage("ios.wall.cameraX") private var storedCameraX = 12.0
    private var cameraX: CGFloat { CGFloat(storedCameraX) }
    @AppStorage("ios.wall.cameraY") private var storedCameraY = 40.0
    private var cameraY: CGFloat { CGFloat(storedCameraY) }
    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: MagnifyGesture.Value?

    var body: some View {
        GeometryReader { geometry in
            let camera = WallCamera(offset: CGPoint(x: cameraX, y: cameraY), scale: CGFloat(zoom))
            let anchor = CGPoint(x: (pinch?.startAnchor.x ?? 0.5) * geometry.size.width,
                                 y: (pinch?.startAnchor.y ?? 0.5) * geometry.size.height)
            let preview = camera.zoomed(to: CGFloat(zoom) * (pinch?.magnification ?? 1), around: anchor)
            let scale = preview.scale
            let activeScene = scene.tiles.count == songs.count ? scene : WeightedWallScene(count: songs.count)
            let visible = activeScene.visible(cameraX: preview.offset.x + drag.width, cameraY: preview.offset.y + drag.height,
                                              scale: scale, viewport: geometry.size)
            ZStack(alignment: .topLeading) {
                Theme.background
                ForEach(visible) { instance in
                    let song = songs[instance.tile.index]
                    let width = instance.frame.width * scale
                    let height = instance.frame.height * scale
                    wallTile(song, width: width, height: height)
                        .frame(width: width, height: height)
                        .position(x: preview.offset.x + drag.width + instance.frame.midX * scale,
                                  y: preview.offset.y + drag.height + instance.frame.midY * scale)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 5)
                .updating($drag) { value, state, _ in state = value.translation }
                .onEnded { value in
                    storedCameraX += Double(value.translation.width)
                    storedCameraY += Double(value.translation.height)
                })
            .simultaneousGesture(MagnifyGesture()
                .updating($pinch) { value, state, _ in state = value }
                .onEnded { value in
                    let anchor = CGPoint(x: value.startAnchor.x * geometry.size.width,
                                         y: value.startAnchor.y * geometry.size.height)
                    let committed = WallCamera(offset: CGPoint(x: cameraX, y: cameraY), scale: CGFloat(zoom))
                        .zoomed(to: CGFloat(zoom) * value.magnification, around: anchor)
                    storedCameraX = Double(committed.offset.x)
                    storedCameraY = Double(committed.offset.y)
                    zoom = Double(committed.scale)
                })
        }
        .onAppear { scene = WeightedWallScene(count: songs.count) }
        .onChange(of: songs.count) { _, count in scene = WeightedWallScene(count: count) }
        .accessibilityLabel("可拖动和缩放的音乐墙")
    }

    private func wallTile(_ song: Song, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(song: song, size: min(width, height))
                .frame(width: width, height: height)
            LinearGradient(colors: [.black.opacity(0.08), .black.opacity(0.12), .black.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
            if width > 80 && height > 70 {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.system(size: min(19, max(12, width * 0.09)), weight: .semibold)).lineLimit(1)
                    Text(song.artist).font(.system(size: min(12, max(9, width * 0.055)))).lineLimit(1).foregroundStyle(.white.opacity(0.75))
                }
                .padding(min(12, width * 0.06))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(selectedID == song.id ? Theme.mint : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .foregroundStyle(.white)
        .onTapGesture(count: 2) { selectedID = song.id; play(song) }
        .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { selectedID = song.id } }
        .contextMenu {
            Button(player.current?.id == song.id && player.isPlaying ? "暂停" : "播放", systemImage: "play.fill") {
                if player.current?.id == song.id { player.toggle() } else { play(song) }
            }
            Button(library.isFavorite(song) ? "取消收藏" : "收藏", systemImage: library.isFavorite(song) ? "heart.slash" : "heart") { library.toggleFavorite(song) }
            if !library.playlists.isEmpty {
                Menu("加入歌单", systemImage: "text.badge.plus") {
                    ForEach(library.playlists) { playlist in
                        Button(playlist.name) { library.togglePlaylistSong(song, playlistID: playlist.id) }
                    }
                }
            }
        }
        .accessibilityLabel("\(song.title)，\(song.artist)")
    }
}

/// Preview belongs to the gesture; cancellation restores the live position without seeking.
private struct SeekBar: View {
    let position: TimeInterval
    let duration: TimeInterval
    let seek: (TimeInterval) -> Void
    @GestureState private var preview: Double?

    private var valid: Bool { duration.isFinite && duration > 0 }
    private var displayed: Double { min(max(0, preview ?? (position.isFinite ? position : 0)), valid ? duration : 0) }

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 20)
            let fraction = valid ? displayed / duration : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.14)).frame(height: 3)
                Capsule().fill(Theme.mint).frame(width: width * fraction, height: 3)
                Circle().fill(Theme.mint).frame(width: preview == nil ? 12 : 18, height: preview == nil ? 12 : 18)
                    .offset(x: width * fraction - (preview == nil ? 6 : 9))
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .updating($preview) { value, state, _ in
                    state = WallControlMetrics.seekTime(x: value.location.x - 10, width: width, duration: duration)
                }
                .onEnded { value in
                    if let time = WallControlMetrics.seekTime(x: value.location.x - 10, width: width, duration: duration) { seek(time) }
                })
            .allowsHitTesting(valid)
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("播放进度")
        .accessibilityValue("\(Int(displayed)) 秒，共 \(Int(valid ? duration : 0)) 秒")
        .accessibilityAdjustableAction { direction in
            guard valid else { return }
            switch direction {
            case .increment: seek(min(duration, displayed + 5))
            case .decrement: seek(max(0, displayed - 5))
            @unknown default: break
            }
        }
    }
}

private struct IOSDialogPanel<Content: View>: View {
    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.32).ignoresSafeArea().onTapGesture(perform: close)
                    .accessibilityHidden(true)
                content()
                    .frame(width: min(520, max(0, geometry.size.width - 32)),
                           height: min(680, max(0, geometry.size.height - 24)))
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.12)))
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }
}

/// One persistent material shell changes size; collapsing never changes playback.
private struct WallPlaybackDock: View {
    let width: CGFloat
    let blocked: Bool
    let showPlayer: () -> Void
    let showQueue: () -> Void
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var expanded = true
    @State private var activity = 0
    @GestureState private var touching = false

    private var mayCollapse: Bool { expanded && !blocked && !touching && !voiceOver && scenePhase == .active }
    private var idleKey: String { "\(mayCollapse)-\(activity)-\(player.current?.id ?? "")" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    if expanded { showPlayer() } else { expanded = true; activity += 1 }
                } label: {
                    ArtworkView(song: player.current, size: 40).frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: expanded ? 11 : 20))
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel(expanded ? "打开正在播放" : "展开播放条")
                HStack(spacing: 0) {
                    Button(action: showPlayer) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(player.current?.title ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(player.current?.artist ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    IOSActionButton(symbol: player.isPlaying ? "pause.fill" : "play.fill", label: player.isPlaying ? "暂停" : "播放", action: player.toggle)
                    IOSActionButton(symbol: "list.bullet", label: "播放队列", action: showQueue)
                }
                .frame(width: max(0, width - 72))
                .opacity(expanded ? 1 : 0)
                .allowsHitTesting(expanded).accessibilityHidden(!expanded)
            }
            .frame(height: 48, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            SeekBar(position: player.position, duration: player.duration, seek: player.seek)
                .id(player.current?.id)
                .frame(width: max(0, width - 16))
                .opacity(expanded ? 1 : 0).allowsHitTesting(expanded).accessibilityHidden(!expanded)
        }
        .padding(expanded ? 8 : 0)
        .frame(width: expanded ? width : 48, height: expanded ? 108 : 48, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: expanded ? 26 : 24))
        .overlay(RoundedRectangle(cornerRadius: expanded ? 26 : 24).stroke(.primary.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 26 : 24))
        .buttonStyle(IOSActionButtonStyle())
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .updating($touching) { _, state, _ in state = true }
            .onEnded { _ in activity += 1 })
        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: expanded)
        .onChange(of: player.current?.id) { _, _ in expanded = true; activity += 1 }
        .task(id: idleKey) {
            guard mayCollapse else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, mayCollapse else { return }
            expanded = false
        }
    }
}

private struct IOSActionButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
        }.buttonStyle(IOSActionButtonStyle()).accessibilityLabel(label)
    }
}

// iOS content panel: controlled dismissal, immediate persisted preferences, system file picker only.
private struct SettingsView: View {
    @EnvironmentObject private var library: MusicLibrary
    @AppStorage("ios.appearance") private var appearance = "dark"
    let close: () -> Void
    @State private var importing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置").font(.title2.bold())
                    Text("让音乐按你的方式呈现").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("关闭设置")
            }.padding(22)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("外观").font(.headline)
                    HStack(spacing: 8) {
                        choice("跟随系统", value: "system", symbol: "circle.lefthalf.filled")
                        choice("浅色", value: "light", symbol: "sun.max")
                        choice("深色", value: "dark", symbol: "moon")
                    }
                    Divider()
                    Text("音乐文件夹").font(.headline)
                    if library.folders.isEmpty {
                        Text("添加本地音乐目录，封面会自动出现在音乐墙上。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(library.folders) { folder in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(Theme.mint)
                            Text(folder.name).lineLimit(2)
                            Spacer()
                            Button { library.removeFolder(folder) } label: {
                                Image(systemName: "minus.circle").frame(width: 44, height: 44)
                            }.accessibilityLabel("移除文件夹：" + folder.name)
                        }
                    }
                    action("添加音乐文件夹", symbol: "folder.badge.plus") { importing = true }
                    Divider()
                    Text("音乐库").font(.headline)
                    Button {
                        library.includesSubfolders.toggle()
                        library.rescan()
                    } label: {
                        HStack {
                            Text("包含子文件夹")
                            Spacer()
                            Image(systemName: library.includesSubfolders ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Theme.mint)
                        }.frame(minHeight: 44)
                    }
                    .disabled(library.isScanning)
                    .accessibilityValue(library.includesSubfolders ? "已开启" : "已关闭")
                    Text("已找到 \(library.songs.count) 首歌曲").font(.subheadline).foregroundStyle(.secondary)
                    if library.isScanning { ProgressView("正在扫描音乐…") }
                    action("重新扫描", symbol: "arrow.clockwise", disabled: library.isScanning, action: library.rescan)
                    action("清理封面缓存并重扫", symbol: "externaldrive", disabled: library.isScanning, action: library.clearArtworkCache)
                    Text("音乐文件保留在原位置。云端文件请先下载到设备；目录移动后需重新添加。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(22)
            }
        }
        .buttonStyle(IOSActionButtonStyle())
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).stroke(.primary.opacity(0.12)))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): urls.forEach(library.addFolder)
            case .failure(let error): library.errorMessage = "无法选择文件夹：\(error.localizedDescription)"
            }
        }
    }

    private func choice(_ title: String, value: String, symbol: String) -> some View {
        Button { appearance = value } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(appearance == value ? Theme.mint.opacity(0.18) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(appearance == value ? Theme.mint : .clear))
        }.accessibilityAddTraits(appearance == value ? .isSelected : [])
    }

    private func action(_ title: String, symbol: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .padding(.horizontal, 14)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }.disabled(disabled)
    }
}

private struct IOSActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary)
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct ModePickerView: View {
    @EnvironmentObject private var player: MusicPlayer
    @Binding var zoom: Double
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("音乐墙设置").font(.title2.bold())
                Spacer()
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("关闭音乐墙设置")
            }
            HStack {
                Text("封面比例").font(.headline)
                Spacer()
                Button { zoom = max(0.6, zoom - 0.1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .accessibilityLabel("缩小封面").disabled(zoom <= 0.6)
                Text("\(Int((zoom * 100).rounded()))% ").monospacedDigit().frame(width: 58)
                Button { zoom = min(1.2, zoom + 0.1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("放大封面").disabled(zoom >= 1.2)
            }
            Text("也可以在墙上双指缩放、单指拖动。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("播放模式").font(.headline)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(PlaybackMode.allCases) { mode in
                        Button { player.mode = mode } label: {
                            HStack(spacing: 13) {
                                Image(systemName: mode.symbol).frame(width: 28).foregroundStyle(Theme.mint)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.title)
                                    Text(mode.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if player.mode == mode { Image(systemName: "checkmark").foregroundStyle(Theme.mint) }
                            }
                            .frame(minHeight: 48).padding(12)
                            .background(player.mode == mode ? Theme.mint.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                        }.accessibilityAddTraits(player.mode == mode ? .isSelected : [])
                    }
                }
            }
        }
        .padding(22)
        .buttonStyle(IOSActionButtonStyle())

    }
}

private struct QueueView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("播放队列").font(.title2.bold())
                    Text("\(player.queue.count) 首歌曲").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                IOSActionButton(symbol: "xmark", label: "关闭播放队列", action: close)
            }.padding(22)
            Divider()
            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list").font(.largeTitle)
                    Text("还没有待播放的歌曲").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(player.queue) { song in
                                Button {
                                    player.play(song, queue: player.queue, library: library)
                                } label: {
                                    HStack(spacing: 12) {
                                        ArtworkView(song: song, size: 48).frame(width: 48, height: 48)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(song.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                            Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 4)
                                        if player.current?.id == song.id {
                                            Image(systemName: player.isPlaying ? "waveform" : "pause.fill").foregroundStyle(Theme.mint)
                                        }
                                    }
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(player.current?.id == song.id ? Theme.mint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .accessibilityAddTraits(player.current?.id == song.id ? .isSelected : [])
                                .id(song.id)
                            }
                        }.padding(12)
                    }
                    .onAppear { if let id = player.current?.id { proxy.scrollTo(id, anchor: .center) } }
                }
            }
        }.buttonStyle(IOSActionButtonStyle())
    }
}

private struct PlayerDetailView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var importingLyrics = false

    private var lines: [LyricLine] { LRCParser.parse(library.lyrics(for: player.current)) }
    private var active: Int { lines.lastIndex(where: { $0.time >= 0 && $0.time <= player.position }) ?? -1 }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    VStack(spacing: 18) {
                        ArtworkView(song: player.current, size: 300)
                            .frame(width: min(geometry.size.width - 70, 320), height: min(geometry.size.width - 70, 320))
                            .shadow(color: Theme.mint.opacity(0.18), radius: 26)
                        VStack(spacing: 4) {
                            Text(player.current?.title ?? "").font(.title2.bold()).lineLimit(2)
                            Text(player.current?.artist ?? "").foregroundStyle(Theme.muted)
                        }
                        HStack(spacing: 28) {
                            Button { player.previous() } label: { Image(systemName: "backward.end.fill") }
                            Button { player.toggle() } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundStyle(Theme.background).frame(width: 60, height: 60).background(Theme.mint, in: Circle())
                            }
                            Button { player.next() } label: { Image(systemName: "forward.end.fill") }
                        }
                        .font(.title2)
                        .buttonStyle(.plain)
                        VStack(spacing: 0) {
                            SeekBar(position: player.position, duration: player.duration, seek: player.seek)
                                .id(player.current?.id)
                            HStack {
                                Text(Self.time(player.position))
                                Spacer()
                                Text(Self.time(player.duration))
                            }
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 20)
                        if lines.isEmpty {
                            Text("暂无歌词").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, minHeight: 90)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(lines) { line in
                                        Text(line.text)
                                            .font(.system(size: line.id == active ? 21 : 17, weight: line.id == active ? .semibold : .regular))
                                            .foregroundStyle(line.id == active ? Theme.mint : Theme.muted)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity)
                                            .id(line.id)
                                            .onTapGesture { if line.time >= 0 { player.seek(to: line.time) } }
                                    }
                                }
                                .padding(20)
                            }
                            .frame(maxHeight: .infinity)
                            .onChange(of: active) { _, index in
                                if index >= 0 { withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) } }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("正在播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let song = player.current {
                        Button { library.toggleFavorite(song) } label: { Image(systemName: library.isFavorite(song) ? "heart.fill" : "heart") }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importingLyrics = true } label: { Image(systemName: "text.badge.plus") }
                        .accessibilityLabel("导入 LRC 歌词")
                }
            }
            .fileImporter(isPresented: $importingLyrics,
                          allowedContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, .plainText]) { result in
                guard let song = player.current else { return }
                switch result {
                case .success(let url): library.importLyrics(from: url, for: song)
                case .failure(let error): library.errorMessage = "无法选择歌词：\(error.localizedDescription)"
                }
            }
        }
    }

    private static func time(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }
}
