import SwiftUI
import AppKit

private let playerGreen = Color(red: 0.06, green: 0.66, blue: 0.46)

/// Corner radius for the three player panels and the app icon.
/// Matches the macOS window's rounded corner so the panels feel continuous
/// with the window chrome instead of looking like a smaller shape inside it.
private let panelCornerRadius: CGFloat = 15

/// Single source of truth for the artwork-style corner radius.
/// Mirrors the album artwork's visual language across panels and the app icon.
private let artworkCornerRadiusCap: CGFloat = 22
private func artworkCornerRadius(for size: CGFloat) -> CGFloat {
    min(artworkCornerRadiusCap, size * 0.16)
}

struct ContentView: View {
    let statusBar: StatusBarController
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var lyricsSync: LyricsSyncCoordinator
    @AppStorage(PlayerInterfaceStyle.preferenceKey) private var interfaceStyle = PlayerInterfaceStyle.simple.rawValue
    @StateObject private var collections = LibraryCollections()
    @State private var destination: LibraryDestination = .all
    @State private var browseGroup: String?
    @State private var albumPlayback = false
    @State private var showingPlaylistEditor = false
    @State private var playlistName = ""
    @State private var renamingPlaylist: UUID?
    @AppStorage("MiniVoice.followLyrics") private var followLyrics = true
    private var libraryStyle: Bool { interfaceStyle == PlayerInterfaceStyle.library.rawValue }
    @State private var sidebarVisible = true
    @State private var recent = false
    @State private var query = ""
    @State private var showingTasks = false
    @State private var unreadScan = false
    @State private var hideFinishedScan = false
    @State private var locateRequest = UUID()
    @State private var locateTarget: UUID?
    @State private var multiSelecting = false
    @State private var selectedIDs = Set<UUID>()
    @State private var editingTrack: Track?
    @State private var songInfoRequest = UUID()

    private func openSongInfo(_ track: Track) {
        editingTrack = track
        songInfoRequest = UUID()
    }
    @State private var deleteTargets: [Track] = []
    @State private var deleting = false
    @State private var deleteFiles = false
    @AppStorage("MiniVoice.trackSortOrder") private var sortOrder = "modified"
    @AppStorage("MiniVoice.trackSortField") private var sortField = "added"
    @AppStorage("MiniVoice.trackSortAscending") private var sortAscending = false

    @State private var songs: [Track] = []
    @State private var listIndex = SongListIndex()
    @State private var listEntriesRevision: Int?
    @State private var listEntries: [SongListEntry] = []
    @State private var songGroups: [(name: String, tracks: [Track])] = []

    private var listRequest: SongListRequest {
        SongListRequest(revision: library.tracksRevision, recentPaths: recent ? library.recentPaths : [],
                        recent: recent, query: query, field: sortField, ascending: sortAscending)
    }

    private var workspaceRequest: WorkspaceListRequest {
        WorkspaceListRequest(list: listRequest, destination: libraryStyle ? destination : .all,
                             group: libraryStyle ? browseGroup : nil, collectionsRevision: collections.revision)
    }

    private func updateSongs() async {
        let workspace = workspaceRequest
        if !workspace.list.query.isEmpty {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
        }
        if recent {
            let matches = library.recentTracks(matching: query)
            if !Task.isCancelled { songs = matches }
            return
        }
        let request = workspace.list
        if listEntriesRevision != request.revision {
            listEntries = library.tracks.map { SongListEntry(id: $0.id, url: $0.url, title: $0.title, artist: $0.artist, album: $0.album) }
            listEntriesRevision = request.revision
        }
        let entries = listEntries
        // Only metadata crosses to the worker; AppKit artwork stays on the main actor.
        let ids = await listIndex.orderedIDs(entries, request: request)
        guard !Task.isCancelled, workspaceRequest == workspace else { return }
        let ordered = ids.compactMap { library.track(for: $0) }
        guard libraryStyle else { songs = ordered; return }
        switch destination {
        case .favorites: songs = ordered.filter { collections.isFavorite($0.url.path) }
        case .playlist(let id):
            let paths = collections.playlists.first(where: { $0.id == id })?.paths ?? []
            let matches = Set(ids)
            songs = paths.compactMap { library.track(forPath: $0) }.filter { matches.contains($0.id) }
        case .artists:
            songs = ordered.filter { browseGroup == nil || artistName($0) == browseGroup }
        case .albums:
            songs = ordered.filter { browseGroup == nil || albumName($0) == browseGroup }
        default: songs = ordered
        }
        if browsingGroups {
            songGroups = Dictionary(grouping: songs, by: { destination == .artists ? artistName($0) : albumName($0) })
                .map { (name: $0.key, tracks: $0.value) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } else { songGroups = [] }
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
          if libraryStyle {
            libraryWorkspace(size: geometry.size)
          } else {
            let sidebarWidth = min(288, max(250, geometry.size.width * 0.25))
            let availableWidth = geometry.size.width - 24
            let playerWidth = sidebarVisible
                ? max(280, availableWidth - sidebarWidth - 12)
                : availableWidth
            let overlap = max(0, sidebarWidth + 12 + 280 - availableWidth)
            let depth = sidebarVisible ? min(1, overlap / 60) : 0
            ZStack(alignment: .topLeading) {
                Group {
                    if let track = library.selectedTrack {
                        let playbackTrack = library.playingTrack ?? track
                        PlayerDetail(track: track, playbackTrack: playbackTrack, onEdit: { openSongInfo(track) }, onEditPlayback: { openSongInfo(playbackTrack) }, onToggleSidebar: toggleSidebar)
                    } else {
                        VStack(spacing: 14) {
                            Image(systemName: "music.note.list").font(.largeTitle)
                            Text("添加你的音乐文件夹").font(.title2)
                            OpenSettingsButton()
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: playerWidth, height: geometry.size.height - 46)
                .scaleEffect(1 - 0.025 * depth, anchor: .trailing)
                .offset(y: 8 * depth)
                .position(x: geometry.size.width - 12 - playerWidth / 2,
                          y: 34 + (geometry.size.height - 46) / 2)

                // Keep the dimmer in the hierarchy so its opacity animates
                // with the player instead of appearing all at once.
                Color.black.opacity(0.18 * depth)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .contentShape(Rectangle())
                    .allowsHitTesting(sidebarVisible && overlap > 0)
                    .onTapGesture(perform: toggleSidebar)
                    .accessibilityHidden(depth == 0)

                // Keep the panel mounted through the entire exit animation.
                // Removing it conditionally made it vanish before reaching the edge.
                sidebar(closeProgress: min(1, overlap / 24))
                    .frame(width: sidebarWidth)
                    .frame(height: geometry.size.height - 46)
                    .modifier(PlayerPanelSurface())
                    .position(x: 12 + sidebarWidth / 2,
                              y: 34 + (geometry.size.height - 46) / 2)
                    .offset(x: sidebarVisible ? 0 : -sidebarWidth - 12)
                    .allowsHitTesting(sidebarVisible)
                    .accessibilityHidden(!sidebarVisible)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background { CoverBackdrop(image: library.selectedTrack?.artwork) }
          }
        }
        .ignoresSafeArea()
        // The player needs 280pt plus 24pt of outer margins.
        .frame(minWidth: 304, minHeight: 600)
        .tint(playerGreen)
        .background(PlayerInitialFocus())
        .task(id: workspaceRequest) { await updateSongs() }
        .onChange(of: interfaceStyle) { _ in
            recent = false; destination = .all; browseGroup = nil
            albumPlayback = false; selectedIDs.removeAll(); multiSelecting = false
        }
        .sheet(isPresented: $showingPlaylistEditor) {
            VStack(alignment: .leading, spacing: 18) {
                Text(renamingPlaylist == nil ? "新建歌单" : "重命名歌单").font(.title3.bold())
                TextField("歌单名称", text: $playlistName).textFieldStyle(.roundedBorder)
                    .onSubmit { savePlaylistName() }
                HStack {
                    Spacer()
                    Button("取消") { showingPlaylistEditor = false }
                        .keyboardShortcut(.cancelAction)
                    Button("保存") { savePlaylistName() }
                        .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 340)
        }
        .onAppear {
            migrateSortPreferenceIfNeeded()
            AppDelegate.reopenMainWindow = { openWindow(id: "main") }
            statusBar.start(library: library, openMainWindow: { openWindow(id: "main") })
        }
        .background(SongInfoWindowPresenter(track: $editingTrack, request: songInfoRequest, library: library, lyricsSync: lyricsSync))
        .sheet(isPresented: $deleting) {
            VStack(alignment: .leading, spacing: 18) {
                Text("删除 \(deleteTargets.count) 首歌曲？").font(.title3.bold())
                Text(deleteFiles ? "本地文件将移至废纸篓。" : "仅从音乐库移除，保留本地文件。")
                Toggle("同时移至废纸篓", isOn: $deleteFiles)
                HStack {
                    Spacer()
                    Button("取消") { deleting = false }
                        .keyboardShortcut(.cancelAction)
                    Button("确认删除", role: .destructive) {
                        library.deleteTracks(ids: Set(deleteTargets.map(\.id)), moveFilesToTrash: deleteFiles)
                        selectedIDs.removeAll()
                        deleting = false
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 360)
        }
        .alert("操作失败", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
        .alert("歌词同步", item: $lyricsSync.alert) { notice in
            Button("好", role: .cancel) { lyricsSync.alert = nil }
        } message: { notice in
            Text(notice.message)
        }
    }

    private func toggleSidebar() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.36)) {
            sidebarVisible.toggle()
        }
    }

    private var backgroundTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("后台任务").font(.headline)
                Spacer()
                Button("一键清理") {
                    lyricsSync.clearFinished()
                    hideFinishedScan = !library.isImporting
                    unreadScan = false
                }.buttonStyle(.borderless).font(.caption)
            }
            Text("\(lyricsSync.activeCount + (library.isImporting ? 1 : 0) + (lyricsSync.downloadingModel ? 1 : 0)) 项进行中").foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let status = lyricsSync.modelStatus {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                            Text(status).font(.callout).lineLimit(1).truncationMode(.tail)
                            if lyricsSync.downloadingModel {
                                if let progress = lyricsSync.modelProgress {
                                    ProgressView(value: progress).frame(width: 70)
                                    Text("\(Int(progress * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                } else {
                                    ProgressView().controlSize(.small)
                                }
                            } else {
                                Spacer(minLength: 0)
                                if lyricsSync.modelFailed {
                                    Button { lyricsSync.retryModel() } label: { Image(systemName: "arrow.clockwise") }
                                        .help("重试下载").disabled(lyricsSync.activeCount > 0)
                                }
                                Button { lyricsSync.clearModelResult() } label: { Image(systemName: "xmark") }.help("清理记录")
                            }
                        }.buttonStyle(.borderless)
                        Divider()
                    }
                    if library.isImporting || !hideFinishedScan {
                    HStack(alignment: .top) {
                        Image(systemName: "folder.badge.gearshape")
                        VStack(alignment: .leading) {
                            Text("扫描音乐库").fontWeight(.medium)
                            Text(library.scanSummary).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if library.isImporting { ProgressView().controlSize(.small) }
                        else {
                            if !library.scanIssues.isEmpty {
                                Button { library.rescan() } label: { Image(systemName: "arrow.clockwise") }.help("重新扫描")
                            }
                            Button { hideFinishedScan = true; unreadScan = false } label: { Image(systemName: "xmark") }.help("清理扫描记录")
                        }
                    }
                    }
                    ForEach(lyricsSync.jobs.reversed()) { job in
                        Divider()
                        HStack(alignment: .top) {
                            Image(systemName: "text.alignleft")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.track.title).fontWeight(.medium)
                                Text(job.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer()
                            if !job.finished { ProgressView().controlSize(.small) }
                            else {
                                if job.failed {
                                    Button { lyricsSync.retry(job.id, library: library) } label: { Image(systemName: "arrow.clockwise") }
                                        .help("重试歌词匹配").disabled(lyricsSync.downloadingModel)
                                }
                                Button { lyricsSync.clear(job.id) } label: { Image(systemName: "xmark") }.help("清理记录")
                            }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 340)
        }.padding(18).frame(width: 360)
    }

    private func sidebar(closeProgress: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sidebarBrand(closeProgress: closeProgress)
            .onChange(of: library.isImporting) { importing in
                if importing { hideFinishedScan = false } else { unreadScan = true }
            }
            .onChange(of: showingTasks) { showing in
                if !showing { lyricsSync.hasUnread = false; unreadScan = false }
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
                .background(SearchFocusBoundary())
            VStack(spacing: 4) {
                navigationItem("音乐库", symbol: "music.note", isRecent: false)
                navigationItem("最近播放", symbol: "clock", isRecent: true)
            }
            Divider().opacity(0.4)
            libraryToolbar
            ScrollViewReader { proxy in
              PlayerScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(songs) { track in
                        songRow(track).id(track.id)
                    }
                    if songs.isEmpty {
                        Text(recent ? "播放歌曲后，记录会保存在这里" : "没有找到歌曲")
                            .font(.caption).foregroundStyle(.secondary).padding(.vertical, 30)
                    }
                }
              }
              .onChange(of: locateRequest) { _ in
                  if let target = locateTarget, songs.contains(where: { $0.id == target }) {
                      withAnimation { proxy.scrollTo(target, anchor: .center) }
                  }
              }
              .onChange(of: songs.map(\.id)) { ids in
                  if let target = locateTarget, ids.contains(target) {
                      withAnimation { proxy.scrollTo(target, anchor: .center) }
                      locateTarget = nil
                  }
              }
            }
        }
        // 12pt inner padding keeps the sidebar's first row visually flush with the
        // header buttons on the right - both share the same Y so the eye reads them
        // as a single horizontal band across the top of the window.
        .padding(12)
        .frame(maxHeight: .infinity)
    }

    private func sidebarBrand(closeProgress: CGFloat) -> some View {
            HStack(spacing: 0) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().scaledToFit().frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                    .accessibilityLabel("MiniVoice")
                VStack(alignment: .leading, spacing: 4) {
                    Text("MiniVoice").font(.title3.weight(.bold)).lineLimit(1)
                    Text("音乐让生活更美好").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                if showingTasks || lyricsSync.activeCount > 0 || library.isImporting || lyricsSync.downloadingModel || lyricsSync.hasUnread || unreadScan {
                  Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 19)).foregroundStyle(playerGreen)
                    .frame(width: 22, height: 24)
                    .padding(.leading, 8)
                    .help("后台任务").accessibilityLabel("后台任务")
                    .onTapGesture { showingTasks.toggle() }
                    .popover(isPresented: $showingTasks) {
                        backgroundTasks.onExitCommand { showingTasks = false }
                    }
                }
                Button(action: toggleSidebar) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .frame(width: 32 * closeProgress, alignment: .trailing)
                .opacity(closeProgress)
                .clipped()
                .allowsHitTesting(closeProgress >= 1)
                .accessibilityHidden(closeProgress < 1)
                .help("收起侧栏")
                .accessibilityLabel("收起侧栏")
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
        HStack(spacing: 4) {
            if libraryStyle {
                HStack(spacing: 8) {
                    Text(destinationTitle).font(.caption.weight(.semibold))
                        .lineLimit(1).truncationMode(.tail).help(destinationTitle)
                    Text(browsingGroups ? "\(songGroups.count) \(destination == .artists ? "位" : "张")" : "\(songs.count) 首")
                        .font(.caption.monospacedDigit()).lineLimit(1).truncationMode(.tail)
                }.foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recent ? "最近播放" : "我的歌曲").font(.caption.weight(.semibold))
                    Text("\(songs.count) 首").font(.caption2.monospacedDigit())
                }.foregroundStyle(.secondary).fixedSize(horizontal: true, vertical: false)
            }
            Spacer(minLength: 0)
            Button {
                guard let id = library.playingID else { return }
                locateTarget = id
                library.selectedID = id
                if !songs.contains(where: { $0.id == id }) {
                    query = ""; recent = false; destination = .all; browseGroup = nil
                }
                if libraryStyle { albumPlayback = false }
                locateRequest = UUID()
            } label: {
                ZStack {
                    Circle().stroke(style: StrokeStyle(lineWidth: 1.5, dash: [9, 3])).frame(width: 17, height: 17)
                    Circle().fill().frame(width: 8, height: 8)
                }.modifier(LibraryToolbarSurface(showBorder: false))
            }
            .buttonStyle(.plain).disabled(library.playingID == nil)
            .help("定位正在播放的歌曲").accessibilityLabel("定位正在播放的歌曲")
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
        .frame(height: libraryStyle ? 28 : 36)
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

    private func songRow(_ track: Track, columns: MusicListColumns? = nil) -> some View {
        Group {
            if let columns {
                workspaceSongCells(track, columns: columns)
            } else {
                HStack(spacing: 10) {
                    if multiSelecting {
                        Image(systemName: selectedIDs.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(playerGreen)
                    }
                    Artwork(image: track.artwork, size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).lineLimit(1).truncationMode(.tail).help(track.title)
                        Text(track.artist).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.tail).help(track.artist)
                    }
                    Spacer(minLength: 0)
                    if library.playingID == track.id && !multiSelecting {
                        NowPlayingIndicator(isPlaying: library.isPlaying)
                    }
                }
            }
        }
        .padding(7)
        .background((multiSelecting ? selectedIDs.contains(track.id) : library.selectedID == track.id) ? playerGreen.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 11))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !multiSelecting { library.play(track.id, in: songs.map(\.id)) } }
        .onTapGesture {
            if multiSelecting {
                if selectedIDs.contains(track.id) { selectedIDs.remove(track.id) } else { selectedIDs.insert(track.id) }
            } else { library.select(track.id) }
        }
        .contextMenu {
            Button("播放") { library.play(track.id, in: songs.map(\.id)) }
            Button("编辑歌曲信息与歌词") { openSongInfo(track) }
            if libraryStyle {
                Button(collections.isFavorite(track.url.path) ? "取消收藏" : "收藏歌曲") { collections.toggleFavorite(track.url.path) }
                Menu("加入歌单") {
                    ForEach(collections.playlists) { playlist in
                        Button(playlist.name) { collections.add([track.url.path], to: playlist.id) }
                    }
                    if collections.playlists.isEmpty { Text("请先在侧栏新建歌单") }
                }
                if case .playlist(let id) = destination {
                    Button("从此歌单移除") { collections.remove(track.url.path, from: id) }
                }
                Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([track.url]) }
                Divider()
            }
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

private extension ContentView {
    var destinationTitle: String {
        switch destination {
        case .all: return "音乐库"
        case .recent: return "最近播放"
        case .favorites: return "收藏"
        case .artists: return browseGroup ?? "歌手"
        case .albums: return browseGroup ?? "专辑"
        case .playlist(let id): return collections.playlists.first(where: { $0.id == id })?.name ?? "歌单"
        }
    }

    func artistName(_ track: Track) -> String { track.artist.isEmpty ? "未知歌手" : track.artist }
    func albumName(_ track: Track) -> String { track.album.isEmpty ? "未知专辑" : track.album }
    var browsingGroups: Bool { (destination == .artists || destination == .albums) && browseGroup == nil }

    func navigate(_ target: LibraryDestination) {
        destination = target; recent = target == .recent
        browseGroup = nil; albumPlayback = false
        selectedIDs.removeAll(); multiSelecting = false
    }

    func savePlaylistName() {
        if let id = renamingPlaylist { collections.renamePlaylist(id, name: playlistName) }
        else if let id = collections.createPlaylist(name: playlistName) { navigate(.playlist(id)) }
        showingPlaylistEditor = false
    }

    func libraryWorkspace(size: CGSize) -> some View {
        let sidebarWidth: CGFloat = min(288, max(250, size.width * 0.25))
        let availableWidth = size.width - 24
        let playerWidth = sidebarVisible ? max(280, availableWidth - sidebarWidth - 12) : availableWidth
        let overlap = max(0, sidebarWidth + 12 + 280 - availableWidth)
        let depth = sidebarVisible ? min(1, overlap / 60) : 0
        let height = size.height - 46
        return ZStack(alignment: .topLeading) {
            workspaceDetail(width: playerWidth, height: height)
                .frame(width: playerWidth, height: height)
                .scaleEffect(1 - 0.025 * depth, anchor: .trailing)
                .offset(y: 8 * depth)
                .position(x: size.width - 12 - playerWidth / 2, y: 34 + height / 2)
            // Keep exposed header controls clickable above the sidebar's dismiss layer.
            Color.black.opacity(0.18 * depth)
                .frame(width: size.width, height: max(0, size.height - 84))
                .offset(y: 84)
                .contentShape(Rectangle())
                .allowsHitTesting(sidebarVisible && overlap > 0)
                .onTapGesture(perform: toggleSidebar)
                .accessibilityHidden(depth == 0)
            workspaceSidebar(closeProgress: min(1, overlap / 24))
                .frame(width: sidebarWidth, height: height)
                .modifier(PlayerPanelSurface())
                .position(x: 12 + sidebarWidth / 2, y: 34 + height / 2)
                .offset(x: sidebarVisible ? 0 : -sidebarWidth - 12)
                .allowsHitTesting(sidebarVisible)
                .accessibilityHidden(!sidebarVisible)
        }
        .frame(width: size.width, height: size.height)
        .background { CoverBackdrop(image: (library.playingTrack ?? library.selectedTrack)?.artwork) }
    }

    func workspaceSidebar(closeProgress: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sidebarBrand(closeProgress: closeProgress)
            PlayerScrollView(contentTrailingInset: 0, thumbOffset: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    workspaceNavigation("音乐库", symbol: "music.note", target: .all)
                    workspaceNavigation("最近播放", symbol: "clock", target: .recent)
                    workspaceNavigation("收藏", symbol: "heart", target: .favorites)
                    workspaceNavigation("歌手", symbol: "mic", target: .artists)
                    workspaceNavigation("专辑", symbol: "opticaldisc", target: .albums)
                    Text("我的歌单").font(.callout).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.top, 22).padding(.bottom, 8)
                    ForEach(collections.playlists) { playlist in
                        workspaceNavigation(playlist.name, symbol: "list.bullet", target: .playlist(playlist.id))
                            .contextMenu {
                                Button("重命名歌单") {
                                    renamingPlaylist = playlist.id; playlistName = playlist.name
                                    showingPlaylistEditor = true
                                }
                                Button("删除歌单", role: .destructive) {
                                    collections.deletePlaylist(playlist.id)
                                    if destination == .playlist(playlist.id) { navigate(.all) }
                                }
                            }
                    }
                    Button {
                        renamingPlaylist = nil; playlistName = ""; showingPlaylistEditor = true
                    } label: {
                        Label("新建歌单", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .onChange(of: library.isImporting) { importing in
            if importing { hideFinishedScan = false } else { unreadScan = true }
        }
        .onChange(of: showingTasks) { showing in
            if !showing { lyricsSync.hasUnread = false; unreadScan = false }
        }
    }

    func workspaceNavigation(_ title: String, symbol: String, target: LibraryDestination) -> some View {
        Button { navigate(target) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 22)
                Text(title).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .foregroundStyle(destination == target ? playerGreen : Color.primary)
            .background(destination == target ? playerGreen.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).help(title)
            .accessibilityAddTraits(destination == target ? [.isSelected] : [])
    }

    func workspaceDetail(width: CGFloat, height: CGFloat) -> some View {
        let track = library.playingTrack ?? library.selectedTrack
        let controlsHeight = track == nil ? 0 : PlayerControlsGeometry(width: width, expanded: albumPlayback).height
        return VStack(spacing: 12) {
            workspaceHeader(width: width, track: track).frame(height: 38).zIndex(1)
            ZStack {
                // Keep the list and its native scroll view mounted while lyrics are shown.
                workspaceSongs(width: width)
                    .opacity(albumPlayback ? 0 : 1)
                    .scaleEffect(albumPlayback && !reduceMotion ? 0.98 : 1)
                    .allowsHitTesting(!albumPlayback)
                    .accessibilityHidden(albumPlayback)
                if albumPlayback, let track {
                    WorkspaceLyricsPanel(track: track, follow: $followLyrics, onEdit: { openSongInfo(track) })
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Clip the entire panel transition, including its shadow, to the
            // same contour. A rectangular clip cuts the shadow into four corners.
            .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
            if let track {
                PlayerControls(track: track, albumExpanded: albumPlayback, onToggleAlbum: toggleAlbumPlayback)
                    .frame(height: controlsHeight)
            }
        }
        .frame(width: width, height: height)
    }

    func toggleAlbumPlayback() { setAlbumPlayback(!albumPlayback) }

    func setAlbumPlayback(_ expanded: Bool) {
        guard albumPlayback != expanded else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9)) {
            albumPlayback = expanded
        }
    }

    func workspaceHeader(width: CGFloat, track: Track?) -> some View {
        HStack(spacing: 10) {
            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.left").font(.system(size: 22, weight: .medium))
                    .frame(width: 38, height: 38).contentShape(Rectangle())
            }.buttonStyle(PressScaleButtonStyle()).modifier(HeaderButtonSurface())
                .help("显示或隐藏侧栏").accessibilityLabel("显示或隐藏侧栏")
            Spacer(minLength: 0)
            if albumPlayback, let track {
                Button { openSongInfo(track) } label: {
                    Image(systemName: "info.circle").font(.system(size: 22, weight: .medium))
                        .frame(width: 38, height: 38)
                }.buttonStyle(.plain).modifier(HeaderButtonSurface())
                    .help("编辑歌曲信息与歌词").accessibilityLabel("编辑歌曲信息与歌词")
                Button { setAlbumPlayback(false) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 20, weight: .medium))
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }.buttonStyle(PressScaleButtonStyle()).modifier(HeaderButtonSurface())
                    .help("关闭专辑播放模式，返回歌曲列表").accessibilityLabel("返回歌曲列表")
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("搜索歌曲、歌手或专辑", text: $query).textFieldStyle(.plain)
                        .accessibilityLabel("搜索歌曲、歌手或专辑")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).help("清空搜索").accessibilityLabel("清空搜索")
                    }
                }.padding(.horizontal, 12).frame(width: min(320, width - 58), height: 36)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.58 : 0.65),
                                in: RoundedRectangle(cornerRadius: 12))
                    .background(SearchFocusBoundary())
            }
        }
    }

    func workspaceSongs(width: CGFloat) -> some View {
        let columns = MusicListColumns(width: width, multiSelecting: multiSelecting)
        return VStack(alignment: .leading, spacing: 4) {
            if browseGroup != nil {
                HStack {
                    Button { self.browseGroup = nil; selectedIDs.removeAll() } label: {
                        Label(destination == .artists ? "所有歌手" : "所有专辑", systemImage: "chevron.left")
                    }.buttonStyle(.plain).foregroundStyle(playerGreen)
                    Spacer()
                    Text("\(songs.count) 首歌曲").font(.caption).foregroundStyle(.secondary)
                }
            }
            libraryToolbar
            Divider().opacity(0.4)
            ScrollViewReader { proxy in
                PlayerScrollView(contentTrailingInset: 16, thumbOffset: 8) {
                    if browsingGroups {
                        let groups = songGroups
                        let availableWidth = max(1, width - 56)
                        if width < 480 {
                            LazyVStack(spacing: 4) {
                                ForEach(groups, id: \.name) { group in
                                    LibraryBrowseCard(name: group.name, tracks: group.tracks,
                                                      isArtist: destination == .artists, width: availableWidth,
                                                      compact: true) {
                                        browseGroup = group.name; selectedIDs.removeAll()
                                    }
                                }
                            }.padding(8)
                        } else {
                            let columnCount = max(2, Int((availableWidth + 16) / 166))
                            let cardWidth = (availableWidth - CGFloat(columnCount - 1) * 16) / CGFloat(columnCount)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 16, alignment: .top), count: columnCount),
                                      alignment: .leading, spacing: 16) {
                                ForEach(groups, id: \.name) { group in
                                    LibraryBrowseCard(name: group.name, tracks: group.tracks,
                                                      isArtist: destination == .artists, width: cardWidth) {
                                        browseGroup = group.name; selectedIDs.removeAll()
                                    }
                                }
                            }.padding(8)
                        }

                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(songs) { track in songRow(track, columns: columns).id(track.id) }
                        }
                        // Fixed row geometry keeps the lazy document extent stable while dragging.
                        .frame(height: CGFloat(songs.count) * 58 + CGFloat(max(0, songs.count - 1)) * 4, alignment: .top)
                    }
                    if songs.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: destination == .favorites ? "heart" : "music.note.list").font(.largeTitle)
                            Text(emptyListMessage).font(.callout)
                            if library.folders.isEmpty { OpenSettingsButton() }
                        }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 40)
                    }
                }
                .onChange(of: locateRequest) { _ in
                    if let target = locateTarget, songs.contains(where: { $0.id == target }) {
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                    }
                }
                .onChange(of: songs.map(\.id)) { ids in
                    if let target = locateTarget, ids.contains(target) {
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                        locateTarget = nil
                    }
                }
            }
            if case .playlist(let id) = destination, multiSelecting, !selectedIDs.isEmpty {
                Button("从歌单移除所选歌曲") {
                    for track in songs where selectedIDs.contains(track.id) { collections.remove(track.url.path, from: id) }
                    selectedIDs.removeAll()
                }.buttonStyle(.plain).foregroundStyle(playerGreen)
            }
        }.padding(.horizontal, 12).padding(.vertical, 8).modifier(PlayerPanelSurface())
    }

    func workspaceSongCells(_ track: Track, columns: MusicListColumns) -> some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: selectedIDs.contains(track.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(playerGreen)
                .modifier(SongCellFrame(rect: columns.selection))
                .opacity(multiSelecting ? 1 : 0).accessibilityHidden(!multiSelecting)
            Artwork(image: track.artwork, size: 44)
                .modifier(SongCellFrame(rect: columns.artwork))
                .overlay(alignment: .bottomTrailing) {
                    if library.playingID == track.id {
                        NowPlayingIndicator(isPlaying: library.isPlaying)
                            .padding(3).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                            .offset(x: columns.artwork.minX)
                    }
                }
            Text(track.title).lineLimit(1).truncationMode(.tail).help(track.title)
                .modifier(SongCellFrame(rect: columns.title))
            Text(track.artist).font(columns.isCompact ? .caption : .callout).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail).help(track.artist)
                .modifier(SongCellFrame(rect: columns.artist))
            Text(track.album).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.tail).help(track.album)
                .modifier(SongCellFrame(rect: columns.album))
                .opacity(columns.showsAlbum ? 1 : 0).accessibilityHidden(!columns.showsAlbum)
            Text(String(format: "%d:%02d", Int(max(0, track.duration)) / 60, Int(max(0, track.duration)) % 60))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .modifier(SongCellFrame(rect: columns.duration, alignment: .trailing))
                .opacity(columns.showsDuration ? 1 : 0).accessibilityHidden(!columns.showsDuration)
        }
        // Animate changes of presentation, not every pixel of a live window resize.
        .animation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.20, 1, duration: 0.48), value: columns.isCompact)
        .animation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.20, 1, duration: 0.48), value: columns.showsAlbum)
        .animation(reduceMotion ? nil : .timingCurve(0.22, 0.68, 0.20, 1, duration: 0.48), value: columns.showsDuration)
        .frame(width: columns.width, height: 44, alignment: .topLeading)
        .overlay(alignment: .trailing) {
            Button { collections.toggleFavorite(track.url.path) } label: {
                Image(systemName: collections.isFavorite(track.url.path) ? "heart.fill" : "heart")
                    .foregroundStyle(collections.isFavorite(track.url.path) ? playerGreen : Color.secondary)
                    .frame(width: 28, height: 28)
            }.buttonStyle(.plain)
                .help(collections.isFavorite(track.url.path) ? "取消收藏" : "收藏歌曲")
                .accessibilityLabel(collections.isFavorite(track.url.path) ? "取消收藏" : "收藏歌曲")
                .offset(x: 6)
                .transaction { $0.animation = nil }
        }
    }

    var emptyListMessage: String {
        if !query.isEmpty { return "没有找到匹配的歌曲" }
        if library.folders.isEmpty { return "在设置中添加你的音乐文件夹" }
        switch destination {
        case .favorites: return "点击歌曲旁的爱心，将喜欢的音乐收藏在这里"
        case .playlist: return "右键点击歌曲，选择“加入歌单”"
        case .recent: return "播放歌曲后，记录会保存在这里"
        default: return "没有找到歌曲"
        }
    }
}

/// Equal text slots keep rows aligned even when names wrap or artwork is missing.
private struct LibraryBrowseCard: View {
    let name: String
    let tracks: [Track]
    let isArtist: Bool
    let width: CGFloat
    var compact = false
    let action: () -> Void
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var image: NSImage? { tracks.first(where: { $0.artwork != nil })?.artwork }
    private var artists: String {
        let names = Set(tracks.map(\.artist).filter { !$0.isEmpty }).sorted()
        return names.isEmpty ? "未知歌手" : names.joined(separator: " / ")
    }

    private func cover(size: CGFloat) -> some View {
        ZStack {
            if let image {
                Artwork(image: image, size: size)
            } else {
                Color.clear.background(playerGreen.opacity(0.09))
                Image(systemName: isArtist ? "person.fill" : "opticaldisc")
                    .font(.system(size: size * 0.32, weight: .light))
                    .foregroundStyle(playerGreen.opacity(0.6))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: isArtist ? size / 2 : 10, style: .continuous))
        .scaleEffect(hovered && !reduceMotion ? 1.025 : 1)
    }

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    HStack(spacing: 12) {
                        cover(size: 54)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).font(.system(size: 13, weight: .semibold))
                                .lineLimit(1).truncationMode(.tail).help(name)
                            if !isArtist {
                                Text(artists).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.tail).help(artists)
                            }
                            Text("\(tracks.count) 首歌曲").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }.frame(height: 54)
                } else {
                    VStack(alignment: isArtist ? .center : .leading, spacing: 6) {
                        cover(size: max(1, min(width - 16, isArtist ? 140 : 160)))
                            .frame(maxWidth: .infinity).padding(.bottom, 4)
                        Text(name).font(.system(size: 13, weight: .semibold))
                            .lineLimit(2).truncationMode(.tail).help(name)
                            .multilineTextAlignment(isArtist ? .center : .leading)
                            .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32,
                                   alignment: isArtist ? .top : .topLeading)
                        if !isArtist {
                            Text(artists).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail).help(artists)
                        }
                        Text("\(tracks.count) 首歌曲").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
            .frame(width: width, alignment: .leading)
            .background(hovered ? Color.primary.opacity(0.045) : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hovered)
        .accessibilityLabel("\(name)，\(tracks.count) 首歌曲")
    }
}

private struct SongCellFrame: ViewModifier {
    let rect: CGRect
    var alignment: Alignment = .leading
    func body(content: Content) -> some View {
        content.frame(width: rect.width, height: rect.height, alignment: alignment)
            .clipped().offset(x: rect.minX, y: rect.minY)
    }
}

private struct WorkspaceLyricsPanel: View {
    let track: Track
    @Binding var follow: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("歌词").font(.headline)
                Spacer()
                TranslationDisplayToggle(lines: track.lyricLines)
                Toggle("自动跟随", isOn: $follow).toggleStyle(.switch).controlSize(.small)
                    .fixedSize().disabled(!track.lyricLines.contains { $0.timestamp != nil })
            }.padding(12)
            if track.lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "text.alignleft").font(.largeTitle).foregroundStyle(.secondary)
                    Text("尚未添加歌词").font(.headline)
                    Button("添加歌词", action: onEdit).buttonStyle(GlassButtonStyle())
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SyncedLyrics(track: track, follow: follow)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).modifier(PlayerPanelSurface())
    }
}

private struct PlayerDetail: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let track: Track
    let playbackTrack: Track
    let onEdit: () -> Void
    let onEditPlayback: () -> Void
    let onToggleSidebar: () -> Void
    @State private var expandedLyrics = false
    @AppStorage("MiniVoice.followLyrics") private var followLyrics = true

    var body: some View {
        GeometryReader { geometry in
            let controlsHeight = PlayerControlsGeometry(width: geometry.size.width, expanded: expandedLyrics).height
            let headerHeight: CGFloat = 38
            let gap: CGFloat = 12
            // Fix the top and bottom sections first. Lyrics take the remaining
            // space, with identical gaps above and below the card.
            let artworkBudget = geometry.size.height - headerHeight - controlsHeight - gap * 3 - 150
            let artworkSize = max(88, min(260, min(geometry.size.width * 0.34,
                min(geometry.size.height * 0.23, artworkBudget))))
            let lyricsHeight = max(0, geometry.size.height - headerHeight - controlsHeight
                - (expandedLyrics ? gap * 2 : artworkSize + gap * 3))
            VStack(spacing: 12) {
                header
                    .frame(height: headerHeight)
                if !expandedLyrics {
                    hero(size: artworkSize)
                        .frame(height: artworkSize)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topLeading)))
                }
                lyrics.frame(height: lyricsHeight)
                PlayerControls(track: playbackTrack, albumExpanded: expandedLyrics)
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .modifier(HeaderButtonSurface())
            .help("显示或隐藏侧栏")
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "info.circle")
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .modifier(HeaderButtonSurface())
            .help("歌曲信息")
            .accessibilityLabel("歌曲信息")
        }
    }

    private func hero(size: CGFloat) -> some View {
        HStack(spacing: 22) {
            Artwork(image: track.artwork, size: size, showsBorder: true)
                .shadow(color: .black.opacity(0.10), radius: 16, y: 6)
            VStack(alignment: .leading, spacing: size < 160 ? 6 : 12) {
                Text(track.title).font(.system(size: size < 160 ? 20 : (size < 180 ? 23 : 30), weight: .bold)).lineLimit(2).minimumScaleFactor(0.85)
                Text(track.artist).font(.headline).lineLimit(1)
                Text(track.album).foregroundStyle(.secondary).lineLimit(size < 160 ? 1 : 2)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lyrics: some View {
        VStack(spacing: 0) {
            HStack {
                Text("歌词").font(.headline)
                Spacer()
                TranslationDisplayToggle(lines: playbackTrack.lyricLines)
                Toggle("自动跟随", isOn: $followLyrics).toggleStyle(.switch).controlSize(.small)
                    .fixedSize().disabled(!playbackTrack.lyricLines.contains { $0.timestamp != nil })
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.90)) {
                        expandedLyrics.toggle()
                    }
                } label: {
                    ZStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .opacity(expandedLyrics ? 0 : 1)
                            .scaleEffect(expandedLyrics ? 0.7 : 1)
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .opacity(expandedLyrics ? 1 : 0)
                            .scaleEffect(expandedLyrics ? 1 : 0.7)
                    }
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .help(expandedLyrics ? "收起歌词" : "展开歌词")
                .accessibilityLabel(expandedLyrics ? "收起歌词" : "展开歌词")
            }
            // 12pt internal padding keeps the lyrics header flush with the 12pt
            // gaps between the surrounding panels.
            .padding(12)
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
        .foregroundStyle(.primary)
        .modifier(PlayerPanelSurface())
    }
}

/// Inactive lyric rows do not rebuild attributed text or relayout on each playback tick.
private struct PlayerLyricRow: View, Equatable {
    let line: LyricLine
    // -1: before playback, 0: active, 1: adjacent, 2: distant.
    let emphasis: Int
    let time: Double
    let fontSize: CGFloat
    let rowHeight: CGFloat
    let bilingual: Bool
    let showTranslation: Bool
    let baseColor: Color
    let reduceMotion: Bool
    private var isActive: Bool { emphasis == 0 }
    private var beforeFirstLine: Bool { emphasis == -1 }
    private var distance: Int { emphasis }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
          TimedLyricText(line: line, time: time, active: isActive,
                       baseColor: baseColor)
            .font(.system(size: fontSize, weight: .bold))
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.leading)
          if showTranslation, let translation = line.translation {
            Text(translation)
                .font(.system(size: max(13, fontSize * 0.58), weight: .medium))
                .lineLimit(2).minimumScaleFactor(0.75)
                .foregroundStyle(isActive ? Color.primary.opacity(0.85) : Color.secondary)
          }
        }
            .foregroundStyle(baseColor
                .opacity(beforeFirstLine ? 0.78 : (isActive ? 1 : (distance == 1 ? 0.54 : 0.36))))
            .blur(radius: beforeFirstLine || isActive ? 0 : (distance == 1 ? 0.2 : 0.6))
            .scaleEffect(isActive || beforeFirstLine ? 1 : 0.97, anchor: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: rowHeight, maxHeight: bilingual ? nil : rowHeight)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: emphasis)
    }
}

private struct SyncedLyrics: View {
    @AppStorage("MiniVoice.showLyricsTranslation") private var showTranslation = true
    let track: Track
    let follow: Bool

    var body: some View {
        if track.lyricSnapshot.kind == .plain {
            PlayerScrollView(fadesEdges: true) {
                Text(track.lyricLines.map { line in
                    [line.text, showTranslation ? line.translation : nil].compactMap { $0 }.joined(separator: "\n")
                }.joined(separator: "\n\n"))
                    .font(.system(size: 22, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .textSelection(.enabled)
            }
        } else {
            TimedLyrics(track: track, follow: follow)
        }
    }
}

private struct TimedLyrics: View {
    @AppStorage("MiniVoice.showLyricsTranslation") private var showTranslation = true
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let follow: Bool
    @EnvironmentObject private var clock: PlaybackClock
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previousScrollTarget: ScrollTarget?

    private struct ScrollTarget: Equatable {
        let trackID: UUID
        let active: Int?
        let follow: Bool
        let size: CGSize
        let lyrics: String
        let showTranslation: Bool
    }

    private var active: Int? { track.lyricSnapshot.activeIndex(at: clock.time) }
    var body: some View { timedBody }

    private var timedBody: some View {
        let active = active
        let lines = track.lyricLines
        return GeometryReader { geometry in
            let bilingual = showTranslation && track.lyricSnapshot.hasTranslation
            let baseHeight = min(92.0, max(28.0, (geometry.size.height - 36) / 5))
            let rowHeight = bilingual ? max(62.0, baseHeight * 1.45) : baseHeight
            let fontSize = min(34.0, max(19.0, baseHeight * 0.56))
            ScrollViewReader { proxy in
                PlayerScrollView(fadesEdges: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            PlayerLyricRow(line: line, emphasis: active.map { min(2, abs(index - $0)) } ?? -1,
                                           time: active == index && !line.words.isEmpty ? clock.time : 0,
                                           fontSize: fontSize, rowHeight: rowHeight, bilingual: bilingual,
                                           showTranslation: showTranslation, baseColor: colorScheme == .dark ? .white : Color(red: 0.23, green: 0.27, blue: 0.31),
                                           reduceMotion: reduceMotion)
                                .equatable()
                                .contentShape(Rectangle()).id(index)
                                .onTapGesture { if let time = line.timestamp { library.seek(to: time) } }
                        }
                    }
                    .padding(.horizontal, 32)
                    // Smaller bottom padding keeps the lyrics visually flush with the
                    // panel edge instead of leaving a wide gap to the controls below.
                    .padding(.top, geometry.size.height / 2)
                    .padding(.bottom, 8)
                }
                .task(id: ScrollTarget(trackID: track.id, active: active, follow: follow,
                                       size: geometry.size, lyrics: track.lyrics, showTranslation: showTranslation)) {
                    // Wait for new text/viewport geometry before resolving the line's scroll frame.
                    await Task.yield()
                    guard !Task.isCancelled, follow else { return }
                    let target = ScrollTarget(trackID: track.id, active: active, follow: follow,
                                              size: geometry.size, lyrics: track.lyrics, showTranslation: showTranslation)
                    let animate = !reduceMotion && previousScrollTarget?.trackID == target.trackID
                        && previousScrollTarget?.size == target.size
                        && previousScrollTarget?.active != target.active
                    previousScrollTarget = target
                    // Live resize must follow the viewport immediately. Starting
                    // another 0.4s animation for every pixel made scrolling lag
                    // behind the window and the changing player-panel height.
                    withAnimation(animate ? .easeInOut(duration: 0.4) : nil) {
                        proxy.scrollTo(active ?? 0, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct NowPlayingIndicator: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4) { index in
                    let phase = time * (3.8 + Double(index) * 0.7) + Double(index) * 1.6
                    let height = isPlaying && !reduceMotion
                        ? 5 + 13 * (sin(phase) + 1) / 2
                        : [7.0, 14.0, 18.0, 10.0][index]
                    Capsule().fill(playerGreen).frame(width: 3, height: height)
                }
            }
            .frame(width: 20, height: 20, alignment: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "正在播放" : "当前歌曲已暂停")
    }
}

private struct AdaptivePlayerControlsLayout: Layout {
    var expanded: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 840
        return CGSize(width: width, height: PlayerControlsGeometry(width: width, expanded: expanded).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let layout = PlayerControlsGeometry(width: bounds.width, expanded: expanded)
        for (view, frame) in zip(subviews, [layout.song, layout.center, layout.output]) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(frame.size))
        }
    }
}

private struct PlayerControls: View {
    @EnvironmentObject private var clock: PlaybackClock
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var volume: SystemVolume
    @EnvironmentObject private var desktopLyrics: DesktopLyricsController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let track: Track
    var albumExpanded = false
    var onToggleAlbum: (() -> Void)? = nil
    @State private var hoveringArtwork = false
    @State private var scrub: Double?
    var body: some View {
        GeometryReader { geometry in
            let layout = PlayerControlsGeometry(width: geometry.size.width, expanded: albumExpanded)
            AdaptivePlayerControlsLayout(expanded: albumExpanded) {
                trackInfo(artworkSize: layout.artworkSize)
                    .frame(height: layout.song.height, alignment: .leading)
                VStack(spacing: 0) {
                    progress.frame(height: 22)
                    Spacer(minLength: 8)
                    transport(spacing: layout.buttonSpacing).frame(height: 52)
                }
                .frame(height: layout.center.height)
                output.frame(height: layout.output.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(PlayerPanelSurface())
        .onChange(of: track.id) { _ in scrub = nil }
    }

    private func trackInfo(artworkSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            if let onToggleAlbum {
                Button(action: onToggleAlbum) {
                    Artwork(image: track.artwork, size: artworkSize)
                        .overlay {
                            Image(systemName: albumExpanded ? "chevron.down" : "chevron.up")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 26, height: 26)
                                .background(.regularMaterial, in: Circle())
                                .opacity(hoveringArtwork ? 1 : 0)
                                .offset(y: hoveringArtwork && !reduceMotion ? (albumExpanded ? 3 : -3) : 0)
                                .accessibilityHidden(true)
                        }
                        .scaleEffect(hoveringArtwork && !reduceMotion ? (albumExpanded ? 0.98 : 1.04) : 1)
                        .offset(y: hoveringArtwork && !reduceMotion ? (albumExpanded ? 3 : -4) : 0)
                        .shadow(color: .black.opacity(hoveringArtwork ? 0.18 : 0), radius: hoveringArtwork ? 6 : 0, y: 3)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(albumExpanded ? "收起专辑播放模式" : "打开专辑播放模式")
                .onHover { hoveringArtwork = $0 }
                .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8), value: hoveringArtwork)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: albumExpanded)
            } else {
                Artwork(image: track.artwork, size: artworkSize)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.subheadline.weight(.semibold))
                    .lineLimit(1).help(track.title)
                Text(track.artist).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).help(track.artist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progress: some View {
        HStack(spacing: 8) {
            Text(time(scrub ?? clock.time))
                .frame(width: 34, alignment: .leading)
            Slider(value: Binding(get: { scrub ?? clock.time }, set: { scrub = $0 }), in: 0...max(track.duration, 1)) { editing in
                if !editing, let scrub { library.seek(to: scrub); self.scrub = nil }
            }.accessibilityLabel("播放进度")
            Text(time(track.duration))
                .frame(width: 34, alignment: .trailing)
        }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }

    private func transport(spacing: CGFloat) -> some View {
            HStack(spacing: spacing) {
                Button {
                    let modes = PlaybackMode.allCases
                    let current = modes.firstIndex(of: library.playbackMode) ?? 0
                    library.playbackMode = modes[(current + 1) % modes.count]
                } label: { Image(systemName: library.playbackMode.symbolName) }
                    .foregroundStyle(library.playbackMode == .list ? .secondary : playerGreen)
                    .help("当前：\(library.playbackMode.title)，点击切换模式")
                Button { library.skip(-1) } label: { Image(systemName: "backward.end.fill") }.help("上一首")
                Button { library.togglePlayback() } label: {
                    ZStack {
                        Image(systemName: "play.fill")
                            .opacity(library.isPlaying ? 0 : 1)
                            .scaleEffect(library.isPlaying ? 0.65 : 1)
                            .offset(x: 1)
                        Image(systemName: "pause.fill")
                            .opacity(library.isPlaying ? 1 : 0)
                            .scaleEffect(library.isPlaying ? 1 : 0.65)
                    }
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(playerGreen.gradient, in: Circle())
                        .shadow(color: playerGreen.opacity(0.22), radius: 8, y: 4)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: library.isPlaying)
                }
                .buttonStyle(TransportButtonStyle(isPrimary: true))
                .help("播放 / 暂停")
                .accessibilityLabel(library.isPlaying ? "暂停" : "播放")
                Button { library.skip(1) } label: { Image(systemName: "forward.end.fill") }.help("下一首")
                Button { desktopLyrics.toggle() } label: {
                    Image(systemName: desktopLyrics.isEnabled ? "text.bubble.fill" : "text.bubble")
                }
                .foregroundStyle(desktopLyrics.isEnabled ? playerGreen : .primary)
                .help(desktopLyrics.isEnabled ? "关闭桌面歌词" : "显示桌面歌词")
            }.buttonStyle(TransportButtonStyle()).font(.system(size: 17))
    }

    private var output: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                outputIcon(library.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                Slider(value: Binding(get: { Double(library.volume) }, set: { library.volume = Float($0) }), in: 0...1)
                    .accessibilityLabel("播放器音量")
                // Reserve a width just wide enough for "100%" so the slider
                // doesn't shrink/grow as the digit count changes.
                Text("\(Int((library.volume * 100).rounded()))%")
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(width: 32, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .frame(maxHeight: .infinity)
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
                HStack(spacing: 6) {
                    outputIcon("airplayaudio")
                    Text(volume.error ?? volume.deviceName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 32, alignment: .trailing)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
            .frame(maxHeight: .infinity)
            .help(volume.error ?? volume.deviceName)
        }.font(.system(size: 12)).foregroundStyle(.secondary)
    }

    private func outputIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .frame(width: 20, height: 24)
            .accessibilityHidden(true)
    }
    private func time(_ value: Double) -> String { String(format: "%d:%02d", Int(max(0, value)) / 60, Int(max(0, value)) % 60) }
}

private struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    var showsBorder = false
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: showsBorder ? panelCornerRadius : artworkCornerRadius(for: size), style: .continuous)
    }
    var body: some View {
        Group {
            if let image {
                let cover = ArtworkPresentation.image(for: image)
                ZStack {
                    Image(nsImage: cover).resizable().scaledToFill()
                        .frame(width: size, height: size).clipped()
                        .blur(radius: max(4, size * 0.08))
                        .overlay(Color.black.opacity(0.12))
                    Image(nsImage: cover).resizable().scaledToFit()
                        .frame(width: size, height: size)
                }
            }
            else { Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(playerGreen.opacity(0.6)) }
        }.frame(width: size, height: size)
            .background(playerGreen.opacity(0.08))
            .clipShape(shape)
            .overlay {
                if showsBorder { shape.strokeBorder(.white.opacity(0.45), lineWidth: 0.75) }
            }
    }
}

private final class ScrollbarHiderView: NSView {
    var onMetrics: ((CGFloat, CGFloat) -> Void)?
    var onScrollView: ((NSScrollView) -> Void)?
    var onUserScroll: (() -> Void)?
    private nonisolated(unsafe) var scrollMonitor: Any?
    private weak var observedScroll: NSScrollView?
    private var metricsPending = false
    private var lastMetrics: ScrollMetrics?

    @objc private func scrollMetricsChanged(_ notification: Notification) {
        publishMetrics()
    }

    private func publishMetrics() {
        guard observedScroll != nil else { return }
        guard !metricsPending else { return }
        metricsPending = true
        // Coalesce layout and bounds notifications; read the latest values at delivery.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.metricsPending = false
            guard let scroll = self.observedScroll else { return }
            let latest = ScrollMetrics(offset: scroll.contentView.bounds.minY,
                                       height: scroll.documentView?.frame.height ?? 0)
            guard latest != self.lastMetrics else { return }
            self.lastMetrics = latest
            self.onMetrics?(latest.offset, latest.height)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        scrollMonitor = nil
        guard window != nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let scroll = self.observedScroll,
                  let window = scroll.window, event.window === window,
                  scroll.bounds.contains(scroll.convert(event.locationInWindow, from: nil)),
                  event.scrollingDeltaY != 0 else { return event }
            // Bounds changes also occur during automatic lyric following. Only
            // real wheel/trackpad events reveal the scrollbar, including momentum.
            self.onUserScroll?()
            return event
        }
        applyConfig()
    }

    deinit {
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        applyConfig()
    }

    func applyConfig() {
        var current: NSView? = self
        while let v = current {
            if let scrollView = v as? NSScrollView {
                onScrollView?(scrollView)
                if observedScroll !== scrollView {
                    NotificationCenter.default.removeObserver(self)
                    observedScroll = scrollView
                    scrollView.contentView.postsBoundsChangedNotifications = true
                    NotificationCenter.default.addObserver(self, selector: #selector(scrollMetricsChanged(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
                    if let document = scrollView.documentView {
                        document.postsFrameChangedNotifications = true
                        NotificationCenter.default.addObserver(self, selector: #selector(scrollMetricsChanged(_:)), name: NSView.frameDidChangeNotification, object: document)
                    }
                }
                scrollView.scrollerStyle = .overlay
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
                scrollView.verticalScroller?.alphaValue = 0
                scrollView.horizontalScroller?.alphaValue = 0
                scrollView.verticalScroller?.isHidden = true
                scrollView.horizontalScroller?.isHidden = true
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
                scrollView.contentView.backgroundColor = .clear
                publishMetrics()
                return
            }
            current = v.superview
        }
    }
}

private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var height: CGFloat = 0
}

private final class ScrollViewReference {
    weak var view: NSScrollView?
}

/// Scroll notifications only invalidate the thumb, never the list or lyric content.
@MainActor
private final class PlayerScrollState: ObservableObject {
    @Published var metrics = ScrollMetrics()
    @Published var isThumbVisible = false
    var isDragging = false
    private var lastInteraction = ProcessInfo.processInfo.systemUptime
    private var hideTask: Task<Void, Never>?

    func revealThumb() {
        lastInteraction = ProcessInfo.processInfo.systemUptime
        if !isThumbVisible { isThumbVisible = true }
        guard hideTask == nil else { return }
        hideTask = Task { [weak self] in
            // One task per scroll session, rather than canceling and spawning at every wheel event.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled, let self else { return }
                if !self.isDragging && ProcessInfo.processInfo.systemUptime - self.lastInteraction >= 1.4 {
                    self.isThumbVisible = false
                    self.hideTask = nil
                    return
                }
            }
        }
    }

    func cancelHide() { hideTask?.cancel(); hideTask = nil }
    func reset() { cancelHide(); isDragging = false; isThumbVisible = false }
}

/// One thumb geometry and interaction model for both songs and lyrics.
private struct PlayerScrollView<Content: View>: View {
    var fadesEdges = false
    var contentTrailingInset: CGFloat = 24
    var thumbOffset: CGFloat = 0
    @ViewBuilder var content: () -> Content
    // Retain without observing: only PlayerScrollThumb subscribes to publications.
    @State private var scrollState = PlayerScrollState()
    @State private var scrollReference = ScrollViewReference()
    @Namespace private var coordinateSpace

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .padding(.trailing, contentTrailingInset)
                    .background(HiddenScrollerConfigurator(onMetrics: { offset, height in
                        let updated = ScrollMetrics(offset: offset, height: height)
                        if scrollState.metrics != updated { scrollState.metrics = updated }
                    }, onScrollView: { scrollReference.view = $0 }, onUserScroll: { scrollState.revealThumb() })
                        .frame(width: 0, height: 0).allowsHitTesting(false))
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: coordinateSpace)
            .mask {
                if fadesEdges {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                           .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                } else { Rectangle() }
            }
            .overlay(alignment: .trailing) {
                PlayerScrollThumb(state: scrollState, scrollReference: scrollReference,
                                  height: viewport.size.height, thumbOffset: thumbOffset, coordinateSpace: coordinateSpace)
            }
            .onDisappear { scrollState.reset(); scrollReference.view = nil }
        }
    }
}

private struct PlayerScrollThumb: View {
    @ObservedObject var state: PlayerScrollState
    let scrollReference: ScrollViewReference
    let height: CGFloat
    let thumbOffset: CGFloat
    let coordinateSpace: Namespace.ID
    @State private var isDragging = false
    @State private var grabOffset: CGFloat?
    @State private var dragThumbHeight: CGFloat?
    @State private var dragProgress: CGFloat?
    private var metrics: ScrollMetrics { state.metrics }

    var body: some View {
        Group {
            if metrics.height > height, height > 0 {
                let thumbHeight = dragThumbHeight ?? min(height, max(44, height * height / metrics.height))
                let travel = height - thumbHeight
                let progress = dragProgress ?? min(1, max(0, metrics.offset / (metrics.height - height)))
                Capsule()
                    .fill(Color.primary.opacity(0.55))
                    .frame(width: isDragging ? 12 : 10, height: thumbHeight)
                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                    .offset(y: progress * travel)
                    .opacity(state.isThumbVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: state.isThumbVisible)
                    .frame(width: 24, height: height, alignment: .top)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering && state.isThumbVisible { state.cancelHide() }
                        else if !hovering && state.isThumbVisible { state.revealThumb() }
                    }
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace))
                        .onChanged { value in
                            if grabOffset == nil {
                                dragThumbHeight = thumbHeight
                                let withinThumb = value.startLocation.y - progress * travel
                                grabOffset = (0...thumbHeight).contains(withinThumb) ? withinThumb : thumbHeight / 2
                            }
                            isDragging = true
                            state.isDragging = true
                            state.revealThumb()
                            guard let scroll = scrollReference.view else { return }
                            let fraction = min(1, max(0, (value.location.y - (grabOffset ?? thumbHeight / 2)) / max(1, travel)))
                            // The thumb follows the pointer directly, independent of queued metrics.
                            dragProgress = fraction
                            let documentHeight = scroll.documentView?.frame.height ?? metrics.height
                            let offset = fraction * max(0, documentHeight - scroll.contentView.bounds.height)
                            scroll.contentView.scroll(to: NSPoint(x: scroll.contentView.bounds.minX, y: offset))
                            scroll.reflectScrolledClipView(scroll.contentView)
                        }
                        .onEnded { _ in
                            isDragging = false
                            state.isDragging = false
                            grabOffset = nil
                            dragThumbHeight = nil
                            dragProgress = nil
                            if let scroll = scrollReference.view {
                                state.metrics = ScrollMetrics(offset: scroll.contentView.bounds.minY,
                                                        height: scroll.documentView?.frame.height ?? 0)
                            }
                            state.revealThumb()
                        })
                    .clipped()
                    .offset(x: thumbOffset)
            }
        }
    }
}

private struct HiddenScrollerConfigurator: NSViewRepresentable {
    var onMetrics: ((CGFloat, CGFloat) -> Void)? = nil
    var onScrollView: ((NSScrollView) -> Void)? = nil
    var onUserScroll: (() -> Void)? = nil
    func makeNSView(context: Context) -> NSView {
        let view = ScrollbarHiderView(frame: .zero)
        view.onMetrics = onMetrics
        view.onScrollView = onScrollView
        view.onUserScroll = onUserScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollbarHiderView)?.onMetrics = onMetrics
        (nsView as? ScrollbarHiderView)?.onScrollView = onScrollView
        (nsView as? ScrollbarHiderView)?.onUserScroll = onUserScroll
        DispatchQueue.main.async {
            (nsView as? ScrollbarHiderView)?.applyConfig()
        }
    }
}

/// Shared sidebar material, tint, contour and shadow for all three player panels.
private struct PlayerPanelSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
        content
            .background {
                FrostedBackdrop(material: .hudWindow, blendingMode: .withinWindow, cornerRadius: panelCornerRadius)
                    .opacity(colorScheme == .dark ? 0.76 : 1)
                Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 0.18 : 0.22)
            }
            .clipShape(shape)
            .overlay { shape.stroke(.white.opacity(colorScheme == .dark ? 0.14 : 0.55), lineWidth: 1).allowsHitTesting(false) }
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }
}

private struct FrostedBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = RoundedVisualEffectView()
        view.effectCornerRadius = cornerRadius
        view.material = material
        view.blendingMode = blendingMode
        // Keep the artwork-tinted glass consistent when the window loses focus.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        (nsView as? RoundedVisualEffectView)?.effectCornerRadius = cornerRadius
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
          ZStack {
            FrostedBackdrop(material: .underWindowBackground)
            LinearGradient(
                colors: CoverPalette.colors(for: image),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(colorScheme == .dark ? 0.42 : 0.66)

            if let image {
                Image(nsImage: ArtworkPresentation.backdrop(for: image))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.24)
                    .blur(radius: colorScheme == .dark ? 28 : 52)
                    .opacity(colorScheme == .dark ? 0.40 : 0.38)
            }

            if colorScheme == .dark {
                Color.black.opacity(0.20)
            } else {
                Color.white.opacity(0.06)
            }
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
        guard let image, let base = ArtworkPresentation.averageColor(of: image) else {
            return [Color(red: 0.90, green: 0.97, blue: 0.98), Color(red: 0.94, green: 0.99, blue: 0.97)]
        }
        let bright = NSColor(red: min(1, base.redComponent * 0.38 + 0.62), green: min(1, base.greenComponent * 0.38 + 0.62), blue: min(1, base.blueComponent * 0.38 + 0.62), alpha: 1)
        let soft = NSColor(red: min(1, base.redComponent * 0.20 + 0.80), green: min(1, base.greenComponent * 0.20 + 0.80), blue: min(1, base.blueComponent * 0.20 + 0.80), alpha: 1)
        cache.setObject([bright, soft] as NSArray, forKey: image)
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
            .frame(width: 28, height: 28)
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

/// Header buttons (sidebar toggle, edit track) sit on the right panel's frosted
/// background, so they stay invisible at rest and only gain a light fill + thin
/// outline on hover - matching the library toolbar buttons.
private struct HeaderButtonSurface: ViewModifier {
    @State private var hovered = false
    func body(content: Content) -> some View {
        content
            .frame(width: 38, height: 38)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(hovered ? Color.primary.opacity(0.08) : .clear)
                    .allowsHitTesting(false)
            }
            .overlay {
                if hovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onHover { hovered = $0 }
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.88 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct TransportButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPrimary: Bool

    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: isPrimary ? 52 : 36, height: 52)
            .background {
                if !isPrimary {
                    Circle()
                        .fill(playerGreen.opacity(configuration.isPressed ? 0.13 : 0))
                        .frame(width: 34, height: 34)
                }
            }
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? (isPrimary ? 0.91 : 0.82) : 1)
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : (configuration.isPressed
                ? .easeOut(duration: 0.08)
                : .spring(response: 0.28, dampingFraction: 0.72)), value: configuration.isPressed)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.medium))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.4 : 0.7), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct SidebarToggleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(Color(nsColor: .controlBackgroundColor).opacity(configuration.isPressed ? 0.48 : 0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}
