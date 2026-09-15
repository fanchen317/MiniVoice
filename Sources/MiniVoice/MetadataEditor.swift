import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ArtistEntry: Identifiable {
    let id = UUID()
    var name: String
}

struct MetadataEditor: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.dismiss) private var dismiss
    let track: Track
    @State private var title: String
    @State private var artists: [ArtistEntry]
    @State private var album: String
    @State private var lyrics: String
    @State private var artwork: NSImage?
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

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artists = State(initialValue: track.artist.components(separatedBy: " / ").map { ArtistEntry(name: $0) })
        _album = State(initialValue: track.album)
        _lyrics = State(initialValue: track.lyrics)
        _artwork = State(initialValue: track.artwork)

        let sidecarLyrics = LyricsStorage.read(LyricsStorage.sidecarURL(for: track.url))
        let hasSidecar = sidecarLyrics != nil
        if !track.canWriteTags {
            _lyricsDestination = State(initialValue: .sidecar)
            self.lyricsSourceLabel = hasSidecar ? "当前歌词来自同目录 lrc/ 下的 .lrc 文件。" : "此格式不支持写入标签，歌词将保存到同目录 lrc/ 下。"
        } else if hasSidecar {
            _lyricsDestination = State(initialValue: .sidecar)
            self.lyricsSourceLabel = "当前歌词来自同目录 lrc/ 下的 .lrc 文件。"
        } else if !track.lyrics.isEmpty {
            _lyricsDestination = State(initialValue: .tags)
            self.lyricsSourceLabel = "当前歌词来自音频文件标签。"
        } else {
            _lyricsDestination = State(initialValue: .tags)
            self.lyricsSourceLabel = "当前暂无歌词。"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑歌曲信息").font(.title2.weight(.bold))
                Spacer()
            }.padding(24)
            Divider()
            Form {
                Section("文件信息") {
                    readOnlyRow("文件名称", track.url.lastPathComponent, selectable: true)
                    readOnlyRow("文件路径", track.url.path, selectable: true)
                    readOnlyRow("播放时长", formattedDuration(track.duration))
                }
                Section {
                    TextField("歌曲名称", text: $title)
                    ForEach($artists) { $entry in
                        HStack {
                            TextField("歌手", text: $entry.name)
                            Button { artists.removeAll { $0.id == entry.id } } label: { Image(systemName: "minus.circle") }
                                .disabled(artists.count == 1)
                        }
                    }
                    Button { artists.append(ArtistEntry(name: "")) } label: { Label("添加歌手", systemImage: "plus") }
                    TextField("专辑名称", text: $album)
                } header: {
                    HStack {
                        Text("基本信息")
                        Spacer()
                        Button(action: applyFilenameParsing) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("从文件名解析歌手与歌曲名称")
                    }
                }
                Section("封面") {
                    HStack(spacing: 16) {
                        Button {
                            showArtworkZoom = true
                        } label: {
                            ArtworkPreview(image: artwork)
                        }
                        .buttonStyle(.plain)
                        .disabled(artwork == nil)
                        .help(artwork == nil ? "" : "查看大图")
                        VStack(alignment: .leading) {
                            Button("自定义") { choosingArtwork = true }
                            if artwork != nil { Button("移除封面", role: .destructive) { artwork = nil; artworkChanged = true } }
                        }
                    }
                    .padding(8)
                    .background(isArtworkDropTarget ? Color.accentColor.opacity(0.14) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onDrop(of: [.image], isTargeted: $isArtworkDropTarget, perform: importArtwork)
                    Text("也可将图片直接拖到这里。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("导入歌词文件（LRC / SRT / TXT）") { choosingLyrics = true }
                    let timed = LRCParser.parse(lyrics).filter { $0.timestamp != nil }.count
                    Text(timed > 0 ? "已识别 \(timed) 行时间标签，保存后可自动滚动。" : "纯文本无时间标签；可播放歌曲并逐行打点。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(library.isPlaying ? "暂停试听" : "播放试听") {
                            if library.playingID == track.id { library.togglePlayback() }
                            else { library.play(track.id) }
                        }
                        Button("标记第 \(timingIndex + 1) 行时间") { stampNextLine() }
                            .disabled(lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || timingIndex >= LRCParser.parse(lyrics).count || library.playingID != track.id)
                        Button("从第一行重新打点") { timingIndex = 0 }
                    }
                    HStack(spacing: 8) {
                        Text("保存到").foregroundStyle(.secondary)
                        if track.canWriteTags {
                            Picker("", selection: $lyricsDestination) {
                                Text("音频文件标签").tag(LyricsDestination.tags)
                                Text("同目录 lrc/ 下的 .lrc").tag(LyricsDestination.sidecar)
                                Text("两者都写").tag(LyricsDestination.both)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        } else {
                            Text("同目录 lrc/ 下的 .lrc").foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    Text(lyricsSourceLabel)
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $lyrics)
                        .font(.body)
                        .frame(minHeight: 210)
                } header: {
                    Text("歌词（支持 LRC 时间标签，例如 [00:12.50]）")
                }
            }.formStyle(.grouped).padding(.horizontal, 12).disabled(isSaving)
            Divider()
            HStack(spacing: 12) {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSaving)
                    .buttonStyle(EditorSecondaryButtonStyle())
                Button(isSaving ? "保存中…" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving)
                    .buttonStyle(EditorPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 660, height: 730)
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
                lyrics = LRCParser.imported(try String(contentsOf: url, usedEncoding: &encoding))
                timingIndex = 0
            } catch { saveError = "无法读取歌词，请使用 UTF-8 编码：\(error.localizedDescription)" }
        }
        .alert("操作失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("好", role: .cancel) { saveError = nil }
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
                        .background(.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
                .frame(width: 600, height: 640)
            }
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
        updated.lyrics = lyrics
        updated.artwork = artwork
        updated.artworkWasEdited = artworkChanged
        guard updated.hasFileChanges(comparedTo: track) else {
            dismiss()
            return
        }
        isSaving = true
        let destination: LyricsDestination = track.canWriteTags ? lyricsDestination : .sidecar
        Task {
            do { try await library.save(updated, lyricsDestination: destination); dismiss() }
            catch { saveError = error.localizedDescription }
            isSaving = false
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
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").font(.title).foregroundStyle(.secondary) }
        }.frame(width: 86, height: 86).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct EditorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(height: 34)
            .background(Color.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.38), in: Capsule())
    }
}

private struct EditorSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, 22)
            .frame(height: 34)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.20 : 0.13), in: Capsule())
    }
}
