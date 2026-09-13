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

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artists = State(initialValue: track.artist.components(separatedBy: " / ").map { ArtistEntry(name: $0) })
        _album = State(initialValue: track.album)
        _lyrics = State(initialValue: track.lyrics)
        _artwork = State(initialValue: track.artwork)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑歌曲信息").font(.title2.weight(.bold))
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction).disabled(isSaving)
                Button(isSaving ? "写入中…" : "保存到歌曲文件") { save() }
                    .keyboardShortcut(.defaultAction).disabled(isSaving || !track.canWriteTags)
            }.padding(24)
            Divider()
            Form {
                Section("基本信息") {
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
                }
                Section("封面") {
                    HStack(spacing: 16) {
                        ArtworkPreview(image: artwork)
                        VStack(alignment: .leading) {
                            Button("选择自定义封面") { choosingArtwork = true }
                            if artwork != nil { Button("移除封面", role: .destructive) { artwork = nil; artworkChanged = true } }
                        }
                    }
                }
                Section {
                    Button("导入歌词文件（LRC / SRT / TXT）") { choosingLyrics = true }
                    let timed = LRCParser.parse(lyrics).filter { $0.timestamp != nil }.count
                    Text(timed > 0 ? "已识别 \(timed) 行时间标签，保存后可自动滚动。" : "纯文本无时间标签；可播放歌曲并逐行打点。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(library.isPlaying ? "暂停试听" : "播放试听") {
                            if library.selectedID != track.id { library.select(track.id) }
                            library.togglePlayback()
                        }
                        Button("标记第 \(timingIndex + 1) 行时间") { stampNextLine() }
                            .disabled(lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || timingIndex >= LRCParser.parse(lyrics).count || library.selectedID != track.id)
                        Button("从第一行重新打点") { timingIndex = 0 }
                    }
                    TextEditor(text: $lyrics)
                        .font(.body)
                        .frame(minHeight: 210)
                } header: {
                    Text("歌词（支持 LRC 时间标签，例如 [00:12.50]）")
                }
            }.formStyle(.grouped).padding(.horizontal, 12).disabled(isSaving)
            Text(track.canWriteTags ? "保存会写回原歌曲，并在同目录保留 .minivoice-backup 备份。" : "此格式可播放；完整信息编辑支持 MP3、FLAC、M4A。")
                .font(.caption).foregroundStyle(.secondary).padding(12)
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

    private func save() {
        var updated = track
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.artist = artists.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " / ")
        updated.album = album
        updated.lyrics = lyrics
        updated.artwork = artwork
        updated.artworkWasEdited = artworkChanged
        isSaving = true
        Task {
            do { try await library.save(updated); dismiss() }
            catch { saveError = error.localizedDescription }
            isSaving = false
        }
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
