import SwiftUI
import UniformTypeIdentifiers

private enum Theme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.06)
    static let panel = Color(red: 0.10, green: 0.14, blue: 0.14)
    static let mint = Color(red: 0.36, green: 0.91, blue: 0.67)
    static let muted = Color(red: 0.62, green: 0.69, blue: 0.68)
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
    @State private var drawerOpen = false
    @State private var sheet: PresentedSheet?
    @State private var showingNewPlaylist = false
    @State private var playlistName = ""
    @State private var zoom = 1.0

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

                VStack(spacing: 0) {
                    header
                    if let focusedSong { focusCard(focusedSong).padding(.horizontal, 16).padding(.top, 12) }
                    content(width: geometry.size.width)
                    if player.current != nil { playerDock.padding(.horizontal, 14).padding(.bottom, 8) }
                }

                if drawerOpen { drawer(width: geometry.size.width) }
            }
        }
        .sheet(item: $sheet) { value in
            switch value {
            case .settings: SettingsView()
            case .queue: QueueView()
            case .player: PlayerDetailView()
            case .modes: ModePickerView(zoom: $zoom)
            }
        }
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
            if let groupName {
                Button { self.groupName = nil; selectedID = nil } label: {
                    Image(systemName: "chevron.left").font(.headline).foregroundStyle(.white)
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
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(.white.opacity(0.10), in: Capsule())
                    .accessibilityLabel("搜索音乐库")
            }
            roundButton(searchVisible ? "xmark" : "magnifyingglass", label: searchVisible ? "关闭搜索" : "搜索") {
                withAnimation { searchVisible.toggle(); if !searchVisible { search = "" } }
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
                    .buttonStyle(.borderedProminent).tint(Theme.mint)
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
                                        Text(name).font(.headline).foregroundStyle(.white)
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
                    .padding(16)
                }
            }
        } else if sectionSongs.isEmpty {
            ContentUnavailableView(search.isEmpty ? "这里还没有歌曲" : "没有找到歌曲", systemImage: "music.note.list")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WeightedWallView(songs: sectionSongs, selectedID: $selectedID, zoom: $zoom) { song in
                player.play(song, queue: sectionSongs, library: library)
            }
            .overlay(alignment: .bottomTrailing) {
                roundButton("slider.horizontal.3", label: "音乐墙设置") { sheet = .modes }
                    .padding(18)
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

    private var playerDock: some View {
        VStack(spacing: 2) {
            HStack(spacing: 10) {
                Button { sheet = .player } label: {
                    HStack(spacing: 9) {
                        ArtworkView(song: player.current, size: 42).frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(player.current?.title ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(player.current?.artist ?? "").font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                transport("backward.end.fill", label: "上一首", action: player.previous)
                transport(player.isPlaying ? "pause.fill" : "play.fill", label: player.isPlaying ? "暂停" : "播放", action: player.toggle)
                transport("forward.end.fill", label: "下一首", action: player.next)
                transport("list.bullet", label: "播放队列") { sheet = .queue }
            }
            SeekBar(position: player.position, duration: player.duration, seek: player.seek)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.18)))
    }

    private func drawer(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.66).ignoresSafeArea().onTapGesture { withAnimation { drawerOpen = false } }
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
            .frame(width: min(width * 0.82, 340))
            .frame(maxHeight: .infinity)
            .background(Color(red: 0.06, green: 0.08, blue: 0.09))
        }
        .transition(.opacity)
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
                .foregroundStyle(section == target ? Theme.mint : .white)
                .background(section == target ? Theme.mint.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white).frame(width: 46, height: 46)
                .background(.white.opacity(0.11), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.14)))
        }
        .accessibilityLabel(label)
    }

    private func transport(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(width: 32, height: 42) }
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
    @State private var cameraX: CGFloat = 12
    @State private var cameraY: CGFloat = 40
    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        GeometryReader { geometry in
            let scale = CGFloat(zoom) * pinch
            let activeScene = scene.tiles.count == songs.count ? scene : WeightedWallScene(count: songs.count)
            let visible = activeScene.visible(cameraX: cameraX + drag.width, cameraY: cameraY + drag.height,
                                              scale: scale, viewport: geometry.size)
            ZStack(alignment: .topLeading) {
                Theme.background
                ForEach(visible) { instance in
                    let song = songs[instance.tile.index]
                    let width = instance.frame.width * scale
                    let height = instance.frame.height * scale
                    wallTile(song, width: width, height: height)
                        .frame(width: width, height: height)
                        .position(x: cameraX + drag.width + instance.frame.midX * scale,
                                  y: cameraY + drag.height + instance.frame.midY * scale)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 5)
                .updating($drag) { value, state, _ in state = value.translation }
                .onEnded { value in
                    cameraX += value.translation.width
                    cameraY += value.translation.height
                })
            .simultaneousGesture(MagnificationGesture()
                .updating($pinch) { value, state, _ in state = value }
                .onEnded { value in zoom = min(1.2, max(0.6, zoom * Double(value))) })
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

private struct SeekBar: View {
    let position: TimeInterval
    let duration: TimeInterval
    let seek: (TimeInterval) -> Void
    @State private var dragging: Double?

    var body: some View {
        Slider(value: Binding(get: { dragging ?? min(position, max(duration, 1)) }, set: { dragging = $0 }),
               in: 0...max(duration, 1), onEditingChanged: { editing in
            if !editing, let dragging { seek(dragging); self.dragging = nil }
        })
        .tint(Theme.mint)
        .accessibilityLabel("播放进度")
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("音乐文件夹") {
                    if library.folders.isEmpty { Text("尚未添加文件夹").foregroundStyle(.secondary) }
                    ForEach(library.folders) { folder in
                        HStack {
                            Label(folder.name, systemImage: "folder")
                            Spacer()
                            Button("移除", role: .destructive) { library.removeFolder(folder) }
                        }
                    }
                    Button { importing = true } label: { Label("添加文件夹", systemImage: "folder.badge.plus") }
                }
                Section("扫描") {
                    Toggle("包含子文件夹", isOn: $library.includesSubfolders)
                        .onChange(of: library.includesSubfolders) { _, _ in library.rescan() }
                    HStack { Text("已找到歌曲"); Spacer(); Text("\(library.songs.count)").foregroundStyle(.secondary) }
                    if library.isScanning { ProgressView("正在扫描音乐…") }
                    Button("重新扫描") { library.rescan() }.disabled(library.isScanning)
                    Button("清理封面缓存并重扫") { library.clearArtworkCache() }.disabled(library.isScanning)
                }
                Section {
                    Text("从系统“文件”选择音乐目录。应用只读取音乐和歌词，不修改原文件；请保留所选目录的访问权限。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): urls.forEach(library.addFolder)
                case .failure(let error): library.errorMessage = "无法选择文件夹：\(error.localizedDescription)"
                }
            }
        }
    }
}

private struct ModePickerView: View {
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.dismiss) private var dismiss
    @Binding var zoom: Double

    var body: some View {
        NavigationStack {
            List {
                Section("音乐墙比例") {
                    Slider(value: $zoom, in: 0.6...1.2).tint(Theme.mint)
                    HStack {
                        Text("60%")
                        Spacer()
                        Button("恢复 100%") { zoom = 1.0 }
                        Spacer()
                        Text("120%")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Section("播放模式") {
                    ForEach(PlaybackMode.allCases) { mode in
                        Button {
                            player.mode = mode
                            dismiss()
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: mode.symbol).frame(width: 28).foregroundStyle(Theme.mint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mode.title).foregroundStyle(.primary)
                                    Text(mode.detail).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if player.mode == mode { Image(systemName: "checkmark").foregroundStyle(Theme.mint) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("音乐墙设置")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

private struct QueueView: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var player: MusicPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(player.queue) { song in
                Button {
                    player.play(song, queue: player.queue, library: library)
                } label: {
                    HStack(spacing: 10) {
                        ArtworkView(song: song, size: 44).frame(width: 44, height: 44)
                        VStack(alignment: .leading) {
                            Text(song.title).foregroundStyle(.primary).lineLimit(1)
                            Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        if player.current?.id == song.id { Image(systemName: "waveform").foregroundStyle(Theme.mint) }
                    }
                }
            }
            .navigationTitle("播放队列")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
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
