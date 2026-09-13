import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MetadataEditor: View {
    @EnvironmentObject private var library: MusicLibrary
    @Environment(\.dismiss) private var dismiss
    let track: Track
    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var lyrics: String
    @State private var artwork: NSImage?
    @State private var choosingArtwork = false
    @State private var isSaving = false
    @State private var saveError: String?

    init(track: Track) {
        self.track = track
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
        _lyrics = State(initialValue: track.lyrics)
        _artwork = State(initialValue: track.artwork)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑歌曲信息").font(.title2.weight(.bold))
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isSaving ? "写入中…" : "保存到歌曲文件") { save() }
                    .keyboardShortcut(.defaultAction).disabled(isSaving)
            }.padding(24)
            Divider()
            Form {
                Section("基本信息") {
                    TextField("歌曲名称", text: $title)
                    TextField("歌手（多个歌手可用 / 分隔）", text: $artist)
                    TextField("专辑名称", text: $album)
                }
                Section("封面") {
                    HStack(spacing: 16) {
                        ArtworkPreview(image: artwork)
                        VStack(alignment: .leading) {
                            Button("选择自定义封面") { choosingArtwork = true }
                            if artwork != nil { Button("移除封面", role: .destructive) { artwork = nil } }
                        }
                    }
                }
                Section {
                    TextEditor(text: $lyrics)
                        .font(.body)
                        .frame(minHeight: 210)
                } header: {
                    Text("歌词（支持 LRC 时间标签，例如 [00:12.50]）")
                } footer: {
                    Button("将纯文本按每行 4 秒生成 LRC 时间标签") { lyrics = LRCParser.timestamped(lyrics) }
                        .font(.caption)
                }
            }.formStyle(.grouped).padding(.horizontal, 12)
        }
        .frame(width: 620, height: 630)
        .fileImporter(isPresented: $choosingArtwork, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            artwork = NSImage(contentsOf: url)
        }
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("好", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private func save() {
        library.updateSelected(title: title, artist: artist, album: album, lyrics: lyrics, artwork: artwork)
        isSaving = true
        library.saveSelectedToFile { result in
            isSaving = false
            switch result {
            case .success: dismiss()
            case .failure(let error): saveError = error.localizedDescription
            }
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
