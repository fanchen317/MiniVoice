import AppKit
import SwiftUI

struct OnlineArtworkPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var results: [OnlineArtworkResult] = []
    @State private var selectedID: String?
    @State private var downloaded: DownloadedArtwork?
    @State private var searching = false
    @State private var downloading = false
    @State private var searchError: String?
    @State private var imageError: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var imageTask: Task<Void, Never>?
    let onApply: (NSImage) -> Void

    init(title: String, artist: String, album: String, onApply: @escaping (NSImage) -> Void) {
        _title = State(initialValue: title)
        _artist = State(initialValue: artist == "未知歌手" ? "" : artist)
        _album = State(initialValue: ["未归类专辑", "未知专辑"].contains(album) ? "" : album)
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("在线查找高清封面").font(.title2.bold())
                Spacer()
                Button("重新查询", action: search).disabled(searching)
                Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 12) {
                field("专辑", value: $album)
                field("歌手", value: $artist)
                field("歌名（专辑未知时）", value: $title)
            }
            Text("查询 Apple Music、网易云、QQ 音乐与酷狗音乐，获取大尺寸封面或原图。下载后显示实际像素尺寸，不同发行版本的封面可能不同。")
                .font(.caption).foregroundStyle(.secondary)
            if let searchError { Text(searchError).font(.callout).foregroundStyle(.secondary) }
            HStack(alignment: .top, spacing: 20) {
                List(results, selection: $selectedID) { item in
                    HStack(alignment: .top, spacing: 10) {
                        AsyncImage(url: item.thumbnailURL) { image in image.resizable().scaledToFit() } placeholder: {
                            RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
                        }.frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.album).font(.headline).lineLimit(2)
                            Text(item.artist).font(.caption).lineLimit(2)
                            Text(item.source).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4).tag(item.id)
                }.frame(width: 270)
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
            .opacity(searching ? 0 : 1).disabled(searching).accessibilityHidden(searching)
            .overlay {
                if searching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在查找专辑封面…").font(.headline)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            HStack {
                Text("应用后预览封面，点击歌曲信息页的“保存更改”才写入文件。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("使用这张封面") {
                    guard let downloaded, let image = NSImage(data: downloaded.data) else { return }
                    onApply(image)
                    dismiss()
                }.buttonStyle(.borderedProminent)
                    .disabled(downloaded == nil || downloading || searching)
            }
        }
        .padding(20).frame(width: 800, height: 610)
        .onAppear(perform: search)
        .onChange(of: selectedID) { _ in loadSelectedImage() }
        .onDisappear { searchTask?.cancel(); imageTask?.cancel() }
    }

    @ViewBuilder private var preview: some View {
        if downloading {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在下载高清封面…").foregroundStyle(.secondary)
            }
        } else if let downloaded, let image = NSImage(data: downloaded.data) {
            VStack(spacing: 10) {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .modifier(ArtworkExportModifier(image: image, originalData: downloaded.data, name: selectedArtworkName))
                CopyArtworkButton(image: image, originalData: downloaded.data, name: selectedArtworkName)
                Text("\(downloaded.width) × \(downloaded.height) 像素 · \(ByteCountFormatter.string(fromByteCount: Int64(downloaded.data.count), countStyle: .file))")
                    .font(.callout.monospacedDigit().weight(.medium))
                if min(downloaded.width, downloaded.height) < 1000 {
                    Text("此来源的原图尺寸较小，可选择其他来源或发行版本。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } else if let imageError {
            VStack(spacing: 12) {
                Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
                Text(imageError).multilineTextAlignment(.center)
                Button("重新下载", action: loadSelectedImage)
            }
        } else {
            Text(results.isEmpty ? "没有找到封面，可修改专辑或歌手后重试。" : "选择左侧封面查看大图")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var selectedArtworkName: String {
        results.first(where: { $0.id == selectedID })?.album ?? (album.isEmpty ? title : album)
    }

    private func field(_ label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: value).textFieldStyle(.roundedBorder).accessibilityLabel(label)
                .onSubmit { if !searching { search() } }
        }
    }

    private func search() {
        guard !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchError = "请填写专辑名称或歌曲名称。"
            return
        }
        searchTask?.cancel()
        imageTask?.cancel()
        searching = true
        downloading = false
        searchError = nil
        imageError = nil
        downloaded = nil
        selectedID = nil
        results = []
        let queryTitle = title, queryArtist = artist, queryAlbum = album
        searchTask = Task { @MainActor in
            do {
                let found = try await OnlineArtworkSearch.search(title: queryTitle, artist: queryArtist, album: queryAlbum)
                guard !Task.isCancelled else { return }
                results = found
                searching = false
                selectedID = found.first?.id
            } catch {
                guard !Task.isCancelled else { return }
                searching = false
                searchError = "查询失败：\(error.localizedDescription)"
            }
        }
    }

    private func loadSelectedImage() {
        imageTask?.cancel()
        downloaded = nil
        imageError = nil
        guard let item = results.first(where: { $0.id == selectedID }) else { downloading = false; return }
        downloading = true
        imageTask = Task { @MainActor in
            do {
                let image = try await OnlineArtworkSearch.download(item)
                guard !Task.isCancelled, selectedID == item.id else { return }
                downloaded = image
                downloading = false
            } catch {
                guard !Task.isCancelled, selectedID == item.id else { return }
                downloading = false
                imageError = "封面下载失败，请重试或选择其他结果。"
            }
        }
    }
}
