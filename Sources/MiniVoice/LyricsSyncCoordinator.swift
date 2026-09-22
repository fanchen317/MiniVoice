import Foundation

struct LyricsSyncAlert: Identifiable {
    enum Kind { case success, warning, failure }
    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
}

/// Keeps lengthy local AI alignment independent from the metadata editor sheet.
@MainActor
final class LyricsSyncCoordinator: ObservableObject {
    @Published private(set) var status: String?
    @Published var alert: LyricsSyncAlert?

    private let alignment = LyricsAlignment()
    private var task: Task<Void, Never>?

    func start(track: Track, destination: LyricsDestination, library: MusicLibrary) {
        guard task == nil else {
            alert = LyricsSyncAlert(kind: .failure, title: "歌词同步未开始", message: "另一首歌曲正在同步，请完成后再试。")
            return
        }
        let source = track.lyrics
        status = "正在为《\(track.title)》匹配歌词…"
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.status = nil; self.task = nil }
            do {
                var aligned = track
                aligned.lyrics = try await self.alignment.align(
                    source: source,
                    audioURL: track.url,
                    duration: track.duration,
                    title: track.title
                )
                try Task.checkCancellation()
                try await library.save(aligned, lyricsDestination: destination)
                if let warning = self.alignment.warning {
                    self.alert = LyricsSyncAlert(kind: .warning, title: "歌词已保存，部分行待校正", message: warning)
                } else {
                    self.alert = LyricsSyncAlert(kind: .success, title: "歌词同步完成", message: "《\(track.title)》已生成可自动跟随的时间轴。")
                }
            } catch is CancellationError {
                self.alert = LyricsSyncAlert(kind: .warning, title: "歌词同步已取消", message: "原歌词已保存，稍后可再次编辑并同步。")
            } catch {
                self.alert = LyricsSyncAlert(kind: .failure, title: "歌词同步失败", message: error.localizedDescription)
            }
        }
    }
}
