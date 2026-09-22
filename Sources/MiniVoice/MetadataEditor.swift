import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ArtistEntry: Identifiable {
    let id = UUID()
    var name: String
}

struct MetadataEditor: View {
    @EnvironmentObject private var library: MusicLibrary
    @EnvironmentObject private var lyricsSync: LyricsSyncCoordinator
    @Environment(\.dismiss) private var dismiss
    let track: Track
    var onClose: (() -> Void)?
    @State private var title: String
    @State private var artists: [ArtistEntry]
    @State private var album: String
    @State private var lyrics: String
    @State private var artwork: NSImage?
    @State private var selectedPage = EditorPage.details
    @State private var showTimingTools = false
    @State private var timingIndex = 0
    @State private var artworkChanged = false
    @State private var choosingArtwork = false
    @State private var choosingLyrics = false
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var isArtworkDropTarget = false
    @State private var showArtworkZoom = false
    @State private var lyricsDestination: LyricsDestination
    private let lyricsSourceLabel: String

    init(track: Track, onClose: (() -> Void)? = nil) {
        self.track = track
        self.onClose = onClose
        _title = State(initialValue: track.title)
        _artists = State(initialValue: track.artist.components(separatedBy: " / ").map { ArtistEntry(name: $0) })
        _album = State(initialValue: track.album)
        _lyrics = State(initialValue: track.lyrics)
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
            Picker("编辑内容", selection: $selectedPage) {
                ForEach(EditorPage.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 360)
            .padding(.bottom, 20).disabled(isSaving)
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
                .padding(24)
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
        .frame(width: 760, height: 700)
        .interactiveDismissDisabled(isSaving)
        .fileImporter(isPresented: $choosingArtwork, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            if let image = NSImage(contentsOf: url) { artwork = image; artworkChanged = true }
            else { saveError = "无法读取这张图片，请选择 PNG 或 JPEG。" }
        }
        .fileImporter(isPresented: $choosingLyrics, allowedContentTypes: [UTType(filenameExtension: "lrc") ?? .plainText, UTType(filenameExtension: "srt") ?? .plainText, .plainText]) { result in
            do {
                let url = try result.get()
                var encoding = String.Encoding.utf8
                lyrics = LyricsText.normalized(try String(contentsOf: url, usedEncoding: &encoding))
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
                        Text("封面预览").font(.headline)
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
                }
                .padding(20)
                .frame(width: 600, height: 640)
            }
        }
    }

    private func closeEditor() {
        if let onClose { onClose() } else { dismiss() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ArtworkPreview(image: artwork, size: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text("歌曲信息").font(.system(size: 21, weight: .bold))
                Text(title.isEmpty ? track.url.deletingPathExtension().lastPathComponent : title)
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 16)
            Text(track.url.pathExtension.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }.padding(24)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if isSaving {
                ProgressView().controlSize(.small)
                Text("正在保存更改…").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("点击保存后应用更改").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("取消") { closeEditor() }
                .keyboardShortcut(.cancelAction).disabled(isSaving)
            Button(isSaving ? "保存中…" : "保存更改") { save() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction).disabled(isSaving)
        }
        .controlSize(.large)
        .padding(.horizontal, 24).padding(.vertical, 16)
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
                    }.padding(16)
                    Divider().padding(.horizontal, 16)
                    inputRow("专辑名称", placeholder: "输入专辑名称", text: $album)
                    Divider().padding(.horizontal, 16)
                    SettingsRow(title: "从文件名填充", detail: "识别「歌手 - 歌曲名」格式") {
                        Button("解析文件名", action: applyFilenameParsing)
                    }
                }.disabled(!track.canWriteTags)
            }
            SettingsGroup(title: "专辑封面", footer: "支持拖入图片；点击已有封面可查看大图。") {
                HStack(spacing: 20) {
                    Button { showArtworkZoom = true } label: { ArtworkPreview(image: artwork, size: 96) }
                        .buttonStyle(.plain).disabled(artwork == nil)
                        .accessibilityLabel("查看封面大图")
                    VStack(alignment: .leading, spacing: 12) {
                        Text(artwork == nil ? "尚未设置封面" : "自定义歌曲封面")
                            .font(.system(size: 13, weight: .medium))
                        HStack(spacing: 10) {
                            Button(artwork == nil ? "添加封面…" : "更换封面…") { choosingArtwork = true }
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
        }.padding(16)
    }

    private var lyricsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup(title: "歌词内容") {
                HStack {
                    Label("支持 LRC、SRT、TXT", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("导入歌词…") { choosingLyrics = true }
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
            SettingsGroup(title: "进阶工具") {
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
                                .disabled(lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || timingIndex >= LRCParser.parse(lyrics).count || library.playingID != track.id)
                            Button("从头打点") { timingIndex = 0 }
                        }
                    }.padding(.top, 12)
                }.padding(16)
            }
        }
    }

    private var lyricsStatus: String {
        if lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "保存时自动整理空行；已有时间标签保持不变。"
        }
        if LyricsAlignment.needsAlignment(lyrics) {
            return "保存后将在本机自动匹配时间轴。首次使用需联网下载模型，歌曲不会上传。"
        }
        let timed = LRCParser.parse(lyrics).filter { $0.timestamp != nil }.count
        return "已识别 \(timed) 行时间标签，保存后可自动跟随播放。"
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
        var lines = LRCParser.parse(lyrics)
        guard lines.indices.contains(timingIndex) else { return }
        lines[timingIndex].timestamp = library.playbackTime
        lyrics = lines.map { line in
            line.timestamp.map { LRCParser.stamp($0, text: line.text) } ?? line.text
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
        updated.lyrics = LyricsAlignment.alignmentSource(lyrics, title: updated.title)
        lyrics = updated.lyrics
        updated.artwork = artwork
        updated.artworkWasEdited = artworkChanged
        let shouldAlign = LyricsAlignment.needsAlignment(updated.lyrics)
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
                lyrics = updated.lyrics
                if shouldAlign { lyricsSync.start(track: updated, destination: destination, library: library) }
                closeEditor()
            } catch {
                saveError = error.localizedDescription
            }
        }
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
                    .lineLimit(3)
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
            return
        }
        coordinator.window?.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        guard coordinator.trackID != track.id else { return }
        coordinator.window?.close()
        // Use the explicit Cancel/Save controls; saving cannot be interrupted
        // by an independent native close button.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 700),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "歌曲信息"
        window.isReleasedWhenClosed = false
        window.isMovable = true
        window.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        window.contentView = NSHostingView(rootView:
            MetadataEditor(track: track, onClose: { self.track = nil })
                .environmentObject(library)
                .environmentObject(lyricsSync))
        coordinator.window = window
        coordinator.trackID = track.id
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.window?.close()
        coordinator.window = nil
    }

    final class Coordinator {
        var window: NSWindow?
        var trackID: UUID?
    }
}
