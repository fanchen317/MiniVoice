import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let songInfoWindowSize = NSSize(width: 620, height: 680)

private struct ArtistEntry: Identifiable {
    let id = UUID()
    var name: String
}

struct MetadataEditor: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var lyricsSync: LyricsSyncCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let track: Track
    var onClose: (() -> Void)?
    private let openOnlineSearch: Bool
    @State private var title: String
    @State private var artists: [ArtistEntry]
    @State private var album: String
    @State private var lyrics: String
    @State private var lyricsAnalysis = LyricsDraftAnalysis()
    @State private var translation: String
    @State private var artwork: NSImage?
    @State private var selectedPage = EditorPage.details
    @State private var hoveredPage: EditorPage?
    @State private var showTimingTools = false
    @State private var timingIndex = 0
    @State private var timingShiftSeconds = 0.0
    @State private var artworkChanged = false
    @State private var choosingArtwork = false
    @State private var choosingLyrics = false
    @State private var searchingLyrics = false
    @State private var onlineSearchTask: Task<Void, Never>?
    @State private var onlineSearchRequestID: UUID?
    @State private var onlineResults: [OnlineLyricsResult] = []
    @State private var onlineError: String?
    @State private var showingOnlineLyrics = false
    @State private var onlineSearchTitle: String
    @State private var onlineSearchArtist: String
    @AppStorage("MiniVoice.onlineLyricsPreferSimplified") private var preferSimplifiedOnlineLyrics = true
    @State private var selectedOnlineID: String?
    @State private var alignAfterSave = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isArtworkDropTarget = false
    @State private var isArtworkHovered = false
    @State private var showArtworkZoom = false
    @State private var showingOnlineArtwork = false
    @State private var lyricsDestination: LyricsDestination
    private let lyricsSourceLabel: String

    init(track: Track, onClose: (() -> Void)? = nil, openOnlineSearch: Bool = false) {
        self.track = track
        self.onClose = onClose
        self.openOnlineSearch = openOnlineSearch
        _selectedPage = State(initialValue: openOnlineSearch ? .lyrics : .details)
        _title = State(initialValue: track.title)
        _artists = State(initialValue: track.artist.components(separatedBy: " / ").map { ArtistEntry(name: $0) })
        _album = State(initialValue: track.album)
        _lyrics = State(initialValue: LyricsTranslation.original(track.lyrics))
        _translation = State(initialValue: LyricsTranslation.text(in: track.lyrics) ?? "")
        _onlineSearchTitle = State(initialValue: track.title)
        _onlineSearchArtist = State(initialValue: track.artist)
        _artwork = State(initialValue: track.artwork)

        _lyricsDestination = State(initialValue: .sidecar)
        let sidecarLyrics = LyricsStorage.read(LyricsStorage.sidecarURL(for: track.url))
        let hasSidecar = sidecarLyrics != nil
        if !track.canWriteTags {
            self.lyricsSourceLabel = hasSidecar ? "当前歌词来自同目录 lrc/ 下的 .lrc 文件。" : "此格式不支持写入标签，歌词将保存到同目录 lrc/ 下。"
        } else if hasSidecar {
            self.lyricsSourceLabel = "当前歌词来自同目录 lrc/ 下的 .lrc 文件。"
        } else if !track.lyrics.isEmpty {
            self.lyricsSourceLabel = "当前歌词来自音频文件标签。"
        } else {
            self.lyricsSourceLabel = "当前暂无歌词。"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            navigation
                .padding(.bottom, 14).disabled(isSaving)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedPage {
                    case .details: detailsPage
                    case .lyrics: lyricsPage
                    case .file: filePage
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .id(selectedPage)
            .disabled(isSaving)
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(Color(red: 0.06, green: 0.55, blue: 0.40))
        .accentColor(Color(red: 0.06, green: 0.55, blue: 0.40))
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(width: songInfoWindowSize.width, height: songInfoWindowSize.height)
        .interactiveDismissDisabled(isSaving)
        .fileImporter(isPresented: $choosingArtwork, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            if let image = NSImage(contentsOf: url) { artwork = image; artworkChanged = true }
            else { saveError = "无法读取这张图片，请选择 PNG 或 JPEG。" }
        }
        .fileImporter(isPresented: $choosingLyrics, allowedContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, UTType(filenameExtension: "yrc") ?? .plainText, UTType(filenameExtension: "srt") ?? .plainText, .plainText]) { result in
            do {
                let url = try result.get()
                var encoding = String.Encoding.utf8
                let imported = LyricsText.normalized(try String(contentsOf: url, usedEncoding: &encoding))
                lyrics = LyricsTranslation.original(imported)
                translation = LyricsTranslation.text(in: imported) ?? ""
                timingIndex = 0
            } catch { saveError = "无法读取歌词，请使用 UTF-8 编码：\(error.localizedDescription)" }
        }
        .alert("操作失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("返回编辑", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .sheet(isPresented: $showArtworkZoom) {
            if let artwork {
                VStack(spacing: 12) {
                    HStack {
                        Text("预览").font(.headline)
                        Spacer()
                        Button("关闭") { showArtworkZoom = false }
                            .keyboardShortcut(.cancelAction)
                    }
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 560, maxHeight: 560)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .modifier(ArtworkExportModifier(image: artwork, name: album.isEmpty ? title : album))
                }
                .padding(20)
                .frame(width: 600, height: 640)
            }
        }
        .sheet(isPresented: $showingOnlineLyrics, onDismiss: cancelOnlineLyricsSearch) {
            onlineLyricsSheet.onAppear { searchOnlineLyrics() }
        }
        .sheet(isPresented: $showingOnlineArtwork) {
            OnlineArtworkPicker(title: title, artist: artists.map(\.name).filter { !$0.isEmpty }.joined(separator: " / "), album: album) { image in
                artwork = image
                artworkChanged = true
            }
        }
        .onAppear {
            if openOnlineSearch { openOnlineLyricsSearch() }
        }
    }

    private func closeEditor() {
        if let onClose { onClose() } else { dismiss() }
    }

    private var navigation: some View {
        HStack(spacing: 3) {
            ForEach(EditorPage.allCases) { page in
                let isSelected = selectedPage == page
                Button {
                    selectedPage = page
                } label: {
                    Text(page.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.white :
                            (colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.68)))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected
                                    ? Color(red: 0.10, green: colorScheme == .dark ? 0.40 : 0.52, blue: 0.39)
                                    : (hoveredPage == page ? Color.primary.opacity(0.07) : .clear))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .onHover { hoveredPage = $0 ? page : nil }
            }
        }
        .padding(4)
        .frame(width: 320)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08))
                }
        }
        .animation(.easeInOut(duration: 0.16), value: selectedPage)
        .accessibilityLabel("编辑内容")
    }

    private var header: some View {
        HStack(spacing: 14) {
            ArtworkPreview(image: artwork, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? track.url.deletingPathExtension().lastPathComponent : title)
                    .font(.system(size: 19, weight: .bold)).lineLimit(1)
                Text(artists.map(\.name).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }.joined(separator: " / "))
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 16)
            Text(track.url.pathExtension.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }.padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if isSaving {
                ProgressView().controlSize(.small)
                Text("正在保存更改…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("取消") { closeEditor() }
                .keyboardShortcut(.cancelAction).disabled(isSaving)
            Button(isSaving ? "保存中…" : "保存") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction).disabled(isSaving)
        }
        .controlSize(.large)
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private var detailsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !track.canWriteTags {
                Label("此格式暂不支持修改基本信息和封面，你仍可在「歌词」中编辑并保存歌词。", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsGroup(title: "基本信息") {
                VStack(spacing: 0) {
                    inputRow("歌曲名称", placeholder: "输入歌曲名称", text: $title)
                    Divider().padding(.horizontal, 16)
                    HStack(alignment: .top, spacing: 16) {
                        Text("歌手").font(.system(size: 13, weight: .medium))
                            .frame(width: 72, alignment: .leading).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($artists) { $entry in
                                HStack(spacing: 10) {
                                    TextField("输入歌手名称", text: $entry.name)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("歌手名称")
                                    Button("移除") { artists.removeAll { $0.id == entry.id } }
                                        .disabled(artists.count == 1)
                                        .accessibilityLabel("移除歌手 \(entry.name)")
                                }
                            }
                            Button { artists.append(ArtistEntry(name: "")) } label: {
                                Label("添加歌手", systemImage: "plus")
                            }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                    Divider().padding(.horizontal, 16)
                    inputRow("专辑名称", placeholder: "输入专辑名称", text: $album)
                    Divider().padding(.horizontal, 16)
                    SettingsRow(title: "源文件名智能识别") {
                        Button("识别", action: applyFilenameParsing)
                    }
                }.disabled(!track.canWriteTags)
            }
            SettingsGroup(title: "专辑封面") {
                HStack(spacing: 16) {
                    Button { showArtworkZoom = true } label: {
                        ArtworkPreview(image: artwork, size: 80)
                            .scaleEffect(isArtworkHovered ? 1.06 : 1)
                            .animation(.easeOut(duration: 0.18), value: isArtworkHovered)
                    }
                        .buttonStyle(.plain).disabled(artwork == nil)
                        .onHover { isArtworkHovered = $0 && artwork != nil }
                        .help(artwork == nil ? "尚未设置封面" : "点击预览封面")
                        .accessibilityLabel("查看封面大图")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(artwork == nil ? "尚未设置封面" : "自定义歌曲封面")
                            .font(.system(size: 13, weight: .medium))
                        Button { showingOnlineArtwork = true } label: {
                            Label("在线查找", systemImage: "magnifyingglass")
                        }.disabled(!track.canWriteTags)
                        HStack(spacing: 10) {
                            Button(artwork == nil ? "添加" : "更换") { choosingArtwork = true }
                            Button("移除", role: .destructive) { artwork = nil; artworkChanged = true }
                                .disabled(artwork == nil)
                        }.disabled(!track.canWriteTags)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(isArtworkDropTarget ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onDrop(of: [.image], isTargeted: $isArtworkDropTarget) { providers in
                    guard track.canWriteTags, !isSaving else { return false }
                    return importArtwork(providers)
                }
            }
        }
    }

    private func inputRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Text(label).font(.system(size: 13, weight: .medium)).frame(width: 72, alignment: .leading)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(label)
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var lyricsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup(title: "查找与导入") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("在线查找并预览同步歌词，或导入本地文件。缺少时间轴时，可在下方手动标记或使用本地匹配。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("在线查找歌词…") { openOnlineLyricsSearch() }
                            .buttonStyle(.borderedProminent)
                        Button("导入 LRC / SRT / TXT…") { choosingLyrics = true }
                    }
                }.padding(16)
            }
            SettingsGroup(title: "歌词内容") {
                HStack {
                    Label("支持 LRC、YRC、SRT、TXT", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16)
                Divider().padding(.horizontal, 16)
                ZStack(alignment: .topLeading) {
                    if lyrics.isEmpty {
                        Text("在这里粘贴歌词，或导入歌词文件…")
                            .font(.system(size: 13)).foregroundStyle(.tertiary)
                            .padding(.leading, 5).padding(.top, 8).allowsHitTesting(false)
                    }
                    TextEditor(text: $lyrics)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("歌词内容")
                        .frame(height: 230)
                }.padding(12)
                Divider().padding(.horizontal, 16)
                Label(lyricsStatus, systemImage: "text.alignleft")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
            SettingsGroup(title: "歌词保存", footer: lyricsSourceLabel) {
                SettingsRow(title: "保存位置") {
                    if track.canWriteTags {
                        Picker("歌词保存位置", selection: $lyricsDestination) {
                            Text("音频文件标签").tag(LyricsDestination.tags)
                            Text("同目录 lrc/ 文件夹").tag(LyricsDestination.sidecar)
                            Text("标签与 LRC 文件").tag(LyricsDestination.both)
                        }.labelsHidden().frame(width: 230)
                    } else {
                        Text("同目录 lrc/ 文件夹").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
            }
            SettingsGroup(title: "译文") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("在线结果含译文时会一并导入，并按时间轴显示在原文下方。也可粘贴带时间标签的译文；没有译文时保留原文显示。")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $translation)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(height: 120).accessibilityLabel("歌词译文")
                }.padding(16)
            }
            SettingsGroup(title: "进阶工具") {
                if lyricsAnalysis.lines(for: lyrics).contains(where: { $0.timestamp != nil }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("整体校正时间轴").font(.system(size: 13, weight: .medium))
                        Text("正数让歌词晚出现，负数让歌词早出现；只修改编辑框，点击保存后才写入歌曲。")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("秒数", value: $timingShiftSeconds, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder).frame(width: 90)
                            Text("秒").foregroundStyle(.secondary)
                            Button("应用偏移") {
                                let shifted = LRCParser.shifted(LyricsTranslation.attaching(translation, to: lyrics), by: timingShiftSeconds)
                                lyrics = LyricsTranslation.original(shifted)
                                translation = LyricsTranslation.text(in: shifted) ?? ""
                                timingIndex = 0
                            }.disabled(!timingShiftSeconds.isFinite || timingShiftSeconds == 0 || abs(timingShiftSeconds) > 60)
                        }
                    }.padding(16)
                    Divider().padding(.horizontal, 16)
                }
                if lyricsAnalysis.needsAlignment(for: lyrics) {
                    Button("使用本地 AI 匹配当前歌词") {
                        alignAfterSave = true
                        save()
                    }
                    .disabled(isSaving || lyricsSync.installedModels.isEmpty)
                    if lyricsSync.installedModels.isEmpty {
                        Text("本地 AI 需要先在设置 → 歌词匹配下载运行环境和模型。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                DisclosureGroup("手动调整时间轴", isExpanded: $showTimingTools) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("试听当前歌曲，在对应歌词开始时标记时间。LRC 格式示例：[00:12.50] 歌词")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button(library.playingID == track.id && library.isPlaying ? "暂停试听" : "播放试听") {
                                if library.playingID == track.id { library.togglePlayback() }
                                else { library.play(track.id) }
                            }
                            Button("标记第 \(timingIndex + 1) 行") { stampNextLine() }
                                .disabled(lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || timingIndex >= lyricsAnalysis.lines(for: lyrics).count || library.playingID != track.id)
                            Button("从头打点") { timingIndex = 0 }
                        }
                    }.padding(.top, 12)
                }.padding(16)
            }
        }
    }

    private var lyricsStatus: String {
        if lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "粘贴或导入歌词后，即可查看时间轴识别结果。"
        }
        if lyricsAnalysis.needsAlignment(for: lyrics) {
            return "未检测到时间轴，可在线查找同步歌词或在下方匹配。"
        }
        let lines = lyricsAnalysis.lines(for: lyrics)
        let timed = lines.filter { $0.timestamp != nil }.count
        let words = lines.reduce(0) { $0 + $1.words.count }
        return words > 0 ? "已识别 \(timed) 行歌词、\(words) 个逐字时间点；其余行按行同步。"
            : "已识别 \(timed) 行同步歌词。"
    }

    private var filePage: some View {
        SettingsGroup(title: "原始文件", footer: "文件信息仅供查看，可以选择并复制文件名称与路径。") {
            VStack(alignment: .leading, spacing: 16) {
                readOnlyRow("文件名称", track.url.lastPathComponent, selectable: true)
                Divider()
                readOnlyRow("文件路径", track.url.path, selectable: true)
                Divider()
                readOnlyRow("播放时长", formattedDuration(track.duration))
                Divider()
                readOnlyRow("标签编辑", track.canWriteTags ? "支持编辑基本信息、封面和歌词" : "仅支持将歌词保存到 LRC 文件")
            }.padding(16)
        }
    }

    private func stampNextLine() {
        var lines = LRCParser.parse(LyricsTranslation.attaching(translation, to: lyrics))
        guard lines.indices.contains(timingIndex) else { return }
        let delta = library.playbackTime - (lines[timingIndex].timestamp ?? library.playbackTime)
        lines[timingIndex].timestamp = library.playbackTime
        lines[timingIndex].words = lines[timingIndex].words.map { LyricWord(text: $0.text, start: max(0, $0.start + delta), end: $0.end.map { max(0, $0 + delta) }) }
        lines[timingIndex].endTime = lines[timingIndex].endTime.map { max(0, $0 + delta) }
        lyrics = LyricsTiming.encoded(lines)
        translation = lines.flatMap { line -> [String] in
            guard let text = line.translation, let time = line.timestamp else { return [] }
            return text.components(separatedBy: "\n").map { LRCParser.stamp(time, text: $0) }
        }.joined(separator: "\n")
        timingIndex += 1
    }

    private func importArtwork(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSImage.self) { image, _ in
            guard let image = image as? NSImage else { return }
            DispatchQueue.main.async {
                artwork = image
                artworkChanged = true
            }
        }
        return true
    }

    private func save() {
        var updated = track
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.artist = artists.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " / ")
        updated.album = album
        updated.lyrics = LyricsTranslation.attaching(translation, to: LyricsAlignment.alignmentSource(lyrics, title: updated.title))
        lyrics = LyricsTranslation.original(updated.lyrics)
        updated.artwork = artwork
        updated.artworkWasEdited = artworkChanged
        let shouldAlign = alignAfterSave && LyricsAlignment.needsAlignment(updated.lyrics)
        guard updated.hasFileChanges(comparedTo: track) || shouldAlign else {
            closeEditor()
            return
        }
        isSaving = true
        let destination: LyricsDestination = track.canWriteTags ? lyricsDestination : .sidecar
        Task {
            defer { isSaving = false }
            do {
                try await library.save(updated, lyricsDestination: destination)
                lyrics = LyricsTranslation.original(updated.lyrics)
                if shouldAlign { lyricsSync.start(track: updated, destination: destination, library: library) }
                alignAfterSave = false
                closeEditor()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private var onlineLyricsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("在线查找歌词").font(.title2.bold())
                Spacer()
                Button("重新查询") { searchOnlineLyrics() }.disabled(searchingLyrics)
                Button("关闭") { showingOnlineLyrics = false }
                    .keyboardShortcut(.cancelAction)
            }
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("歌名").font(.caption).foregroundStyle(.secondary)
                    TextField("输入歌曲名称", text: $onlineSearchTitle)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("歌名")
                }.frame(width: 280)
                VStack(alignment: .leading, spacing: 6) {
                    Text("歌手（可留空）").font(.caption).foregroundStyle(.secondary)
                    TextField("输入歌手姓名", text: $onlineSearchArtist)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("歌手")
                }.frame(width: 220)
                Spacer(minLength: 0)
            }
            Toggle("简体预览并应用", isOn: $preferSimplifiedOnlineLyrics)
                .toggleStyle(.checkbox)
            Text("查询 QQ 音乐、网易云、酷狗、AMLL TTML、LRCLIB 等来源，优先匹配原生逐字歌词。简体选项仅用于本次预览和应用，保留粤语用词与日文歌词。")
                .font(.caption).foregroundStyle(.secondary)
            if let onlineError { Text(onlineError).foregroundStyle(.secondary) }
            if let candidate = onlineResults.first(where: { $0.id == selectedOnlineID }),
               let duration = candidate.duration, track.duration > 0, abs(duration - track.duration) > 10 {
                Label("这个版本与歌曲时长相差 \(Int(abs(duration - track.duration))) 秒，可能是不同演唱或剪辑版本；请先预览确认。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let candidate = onlineResults.first(where: { $0.id == selectedOnlineID }), !candidate.hasTimeline {
                Label("这份歌词没有时间轴；应用后可手动打点或使用本地 AI 匹配。", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ZStack {
                if searchingLyrics {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                            .accessibilityLabel("正在搜索歌词")
                        Text("正在搜索歌词…").font(.headline)
                        Text("正在查询歌词来源，请稍候")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        List(onlineResults, selection: $selectedOnlineID) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preferSimplifiedOnlineLyrics ? ChineseLyricsScript.simplified(item.trackName) : item.trackName).font(.headline)
                                Text("\(item.source) · \(preferSimplifiedOnlineLyrics ? ChineseLyricsScript.simplified(item.artistName) : item.artistName)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(item.timingKind.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(item.timingKind == .word ? Color.accentColor : Color.secondary)
                                if item.hasTranslation { Text("含译文").font(.caption).foregroundStyle(Color.accentColor) }
                                let album = item.albumName?.trimmingCharacters(in: .whitespacesAndNewlines)
                                let albumLabel = album.flatMap { $0.isEmpty ? nil : $0 } ?? "未知专辑"
                                Text("\(preferSimplifiedOnlineLyrics ? ChineseLyricsScript.simplified(albumLabel) : albumLabel)\(item.duration.map { " · \(Int($0) / 60):\(String(format: "%02d", Int($0) % 60))" } ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(2).help(albumLabel)
                            }.tag(item.id)
                        }.frame(width: 250)
                        if let candidate = onlineResults.first(where: { $0.id == selectedOnlineID }),
                           let source = displayedOnlineLyrics(candidate) {
                            OnlineLyricsPreview(source: source).id(source)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("选择左侧结果预览歌词").frame(maxWidth: .infinity)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text("确认后替换编辑框中的歌词，点击“保存”才写入歌曲。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("使用这份歌词") {
                    guard let result = onlineResults.first(where: { $0.id == selectedOnlineID }),
                          let text = displayedOnlineLyrics(result) else { return }
                    let imported = LyricsText.normalized(text)
                    lyrics = LyricsTranslation.original(imported)
                    translation = LyricsTranslation.text(in: imported) ?? ""
                    timingIndex = 0
                    showingOnlineLyrics = false
                }.buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(searchingLyrics || selectedOnlineID == nil)
            }
        }.padding(20).frame(width: 790, height: 540)
    }

    private func displayedOnlineLyrics(_ result: OnlineLyricsResult) -> String? {
        guard let text = result.usableLyrics else { return nil }
        guard preferSimplifiedOnlineLyrics else { return text }
        return LyricsTranslation.attaching(LyricsTranslation.text(in: text).map(ChineseLyricsScript.simplified),
                                          to: ChineseLyricsScript.simplified(LyricsTranslation.original(text)))
    }

    private func cancelOnlineLyricsSearch() {
        onlineSearchRequestID = nil
        onlineSearchTask?.cancel()
        onlineSearchTask = nil
        searchingLyrics = false
    }

    private func searchOnlineLyrics() {
        cancelOnlineLyricsSearch()
        let searchTitle = onlineSearchTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchArtist = onlineSearchArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTitle.isEmpty else {
            onlineError = "请先填写歌曲名称。"
            return
        }
        let requestID = UUID()
        onlineSearchRequestID = requestID
        searchingLyrics = true
        onlineError = nil
        onlineResults = []
        selectedOnlineID = nil
        onlineSearchTask = Task { @MainActor in
            defer {
                if onlineSearchRequestID == requestID {
                    searchingLyrics = false
                    onlineSearchTask = nil
                }
            }
            do {
                let results = try await OnlineLyricsSearch.search(title: searchTitle, artist: searchArtist, duration: track.duration)
                guard !Task.isCancelled, onlineSearchRequestID == requestID else { return }
                onlineResults = results
                if results.isEmpty { onlineError = "没有找到歌词，可去掉歌名后缀或修改歌手后重试。" }
                else { selectedOnlineID = results.first?.id }
            } catch {
                guard !Task.isCancelled, onlineSearchRequestID == requestID else { return }
                onlineError = "查询失败：\(error.localizedDescription)"
            }
        }
    }

    private func openOnlineLyricsSearch() {
        cancelOnlineLyricsSearch()
        onlineSearchTitle = title
        onlineSearchArtist = artists.map(\.name).filter { !$0.isEmpty }.joined(separator: " / ")
        onlineResults = []
        selectedOnlineID = nil
        onlineError = nil
        searchingLyrics = true
        showingOnlineLyrics = true
    }

    private func applyFilenameParsing() {
        var name = track.url.deletingPathExtension().lastPathComponent
        name = name.replacingOccurrences(of: #"^\d{1,3}[.\s_\-]+"#, with: "", options: .regularExpression)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let primarySeparators = [" - ", " – ", " — "]
        var artistPart: String?
        var titlePart: String?

        for separator in primarySeparators {
            if let range = name.range(of: separator) {
                artistPart = String(name[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                titlePart = String(name[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if let titlePart, !titlePart.isEmpty {
            title = titlePart
        }

        guard let artistPart, !artistPart.isEmpty else { return }

        let artistSeparators = [" featuring ", " feat. ", " ft. ", " & ", " / ", ", ", "、"]
        var entries = [artistPart]
        for separator in artistSeparators {
            entries = entries.flatMap { $0.components(separatedBy: separator) }
        }

        let parsed = entries
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if !parsed.isEmpty {
            artists = parsed.map { ArtistEntry(name: $0) }
        }
    }

    private func readOnlyRow(_ title: String, _ value: String, selectable: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            if selectable {
                Text(value)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(value)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.callout)
    }

    private func formattedDuration(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "未知" }
        let total = Int(value.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct ArtworkPreview: View {
    let image: NSImage?
    var size: CGFloat = 86
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").font(.title).foregroundStyle(.secondary) }
        }.frame(width: size, height: size).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private enum EditorPage: String, CaseIterable, Identifiable {
    case details = "基本信息"
    case lyrics = "歌词"
    case file = "文件信息"
    var id: Self { self }
}

/// Present independently of the main window so the information panel can move.
struct SongInfoWindowPresenter: NSViewRepresentable {
    @Binding var track: Track?
    let request: UUID
    let isLoading: Bool
    let library: MusicLibrary
    let lyricsSync: LyricsSyncCoordinator
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        guard let track else {
            coordinator.window?.close()
            coordinator.window = nil
            coordinator.trackID = nil
            coordinator.isLoading = nil
            return
        }
        coordinator.window?.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        // A repeated explicit request must raise the existing editor without
        // recreating it (and losing edits). Ordinary playback updates must not.
        guard coordinator.trackID != track.id else {
            if coordinator.isLoading != isLoading {
                coordinator.window?.contentView = contentView(for: track)
                coordinator.isLoading = isLoading
            }
            if coordinator.lastRequest != request, let window = coordinator.window {
                coordinator.lastRequest = request
                if window.isMiniaturized { window.deminiaturize(nil) }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.attachedSheet?.makeKeyAndOrderFront(nil)
            }
            return
        }
        coordinator.window?.close()
        // Use the explicit Cancel/Save controls; saving cannot be interrupted
        // by an independent native close button.
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: songInfoWindowSize),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "歌曲信息"
        window.isReleasedWhenClosed = false
        window.isMovable = true
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = contentView(for: track)
        coordinator.window = window
        coordinator.trackID = track.id
        coordinator.isLoading = isLoading
        coordinator.lastRequest = request
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func contentView(for track: Track) -> NSView {
        if isLoading {
            return NSHostingView(rootView:
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large)
                        Text("正在读取歌曲信息…")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Button("取消") { self.track = nil }
                            .keyboardShortcut(.cancelAction)
                    }
                }
                .padding(20)
                .frame(width: songInfoWindowSize.width, height: songInfoWindowSize.height)
                .background(Color(nsColor: .windowBackgroundColor)))
        }
        return NSHostingView(rootView:
            MetadataEditor(track: track, onClose: { self.track = nil })
                .environmentObject(library)
                .environmentObject(lyricsSync))
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.window?.close()
        coordinator.window = nil
    }

    final class Coordinator {
        var window: NSWindow?
        var trackID: UUID?
        var lastRequest: UUID?
        var isLoading: Bool?
    }
}

/// Reuse the draft's parse across status labels and tools, including unrelated playback updates.
private final class LyricsDraftAnalysis {
    private var source: String?
    private var parsed: [LyricLine] = []
    func lines(for text: String) -> [LyricLine] {
        if source != text {
            parsed = LRCParser.parse(LRCParser.imported(text), placeholder: false)
            source = text
        }
        return parsed
    }
    func needsAlignment(for text: String) -> Bool {
        lines(for: text).contains { !$0.text.isEmpty && $0.timestamp == nil }
    }
}
