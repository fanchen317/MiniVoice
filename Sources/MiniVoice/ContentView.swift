import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var library: MusicLibrary
    @State private var importing = false
    @State private var editing = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 12) {
                HStack {
                    Text("音乐库").font(.title2.weight(.bold))
                    Spacer()
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .help("导入本地音频").disabled(library.isImporting)
                }
                .padding([.top, .horizontal])
                List(selection: Binding(get: { library.selectedID }, set: { if let id = $0 { library.select(id) } })) {
                    ForEach(library.tracks) { track in
                        TrackRow(track: track).tag(track.id)
                    }
                }
                if library.isImporting { ProgressView("正在读取音乐…").controlSize(.small) }
                Text("支持 MP3 · FLAC · M4A · WAV")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if let track = library.selectedTrack {
                PlayerDetail(track: track, onEdit: { editing = true })
            } else { EmptyLibraryView(onImport: { importing = true }) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): library.importFiles(urls)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $editing) { if let track = library.selectedTrack { MetadataEditor(track: track) } }
        .alert("操作失败", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好", role: .cancel) { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct TrackRow: View {
    let track: Track
    var body: some View {
        HStack(spacing: 10) {
            Artwork(image: track.artwork, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title).lineLimit(1)
                Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }.padding(.vertical, 3)
    }
}

private struct PlayerDetail: View {
    @EnvironmentObject private var library: MusicLibrary
    let track: Track
    let onEdit: () -> Void
    var lines: [LyricLine] { track.lyricLines }

    var body: some View {
        let lines = self.lines
        let activeIndex = library.activeLyricIndex(for: lines)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 28) {
                Artwork(image: track.artwork, size: 190)
                VStack(alignment: .leading, spacing: 10) {
                    Text(track.title).font(.largeTitle.weight(.bold)).lineLimit(2)
                    Text(track.artist).font(.title3).foregroundStyle(.secondary)
                    Text(track.album).font(.subheadline).foregroundStyle(.tertiary)
                    Spacer()
                    Button("编辑歌曲信息", action: onEdit).buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(36)

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(activeIndex == index ? .primary : .secondary)
                            .opacity(line.timestamp == nil || activeIndex == index ? 1 : 0.45)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture { if let time = line.timestamp { library.seek(to: time) } }
                            .help(line.timestamp == nil ? "手动滚动查看歌词" : "点击跳转到这一句")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(36)
            }
            Spacer(minLength: 0)
            PlayerControls(duration: track.duration).padding(24).background(.bar)
        }
    }
}

private struct PlayerControls: View {
    @EnvironmentObject private var library: MusicLibrary
    let duration: TimeInterval
    var body: some View {
        VStack(spacing: 10) {
            Slider(value: Binding(get: { library.playbackTime }, set: { value in library.seek(to: value) }), in: 0...max(duration, 1))
            HStack {
                Text(format(library.playbackTime)).monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button { library.skip(-1) } label: { Image(systemName: "backward.end.fill") }
                Button { library.togglePlayback() } label: {
                    Image(systemName: library.isPlaying ? "pause.fill" : "play.fill").font(.title2)
                }.buttonStyle(.borderedProminent).clipShape(Circle())
                Button { library.skip(1) } label: { Image(systemName: "forward.end.fill") }
                Spacer()
                Image(systemName: "speaker.wave.2")
                Slider(value: $library.volume, in: 0...1).frame(width: 80)
                Text(format(duration)).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }
    private func format(_ seconds: TimeInterval) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

private struct Artwork: View {
    let image: NSImage?; let size: CGFloat
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "music.note").font(.system(size: size / 2)).foregroundStyle(.secondary) }
        }.frame(width: size, height: size).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: size > 100 ? 18 : 8))
    }
}

private struct EmptyLibraryView: View {
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("导入你的音乐").font(.title2.weight(.semibold))
            Text("选择本地 MP3、FLAC 或其他通用音频格式开始。").foregroundStyle(.secondary)
            Button("导入音频", action: onImport)
        }
    }
}
