import Foundation
import Combine

struct LyricsSyncJob: Identifiable {
    let id = UUID()
    let track: Track
    let destination: LyricsDestination
    var detail = "等待处理"
    var finished = false
    var failed = false
}

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
    @Published private(set) var jobs: [LyricsSyncJob] = []
    @Published private(set) var modelStatus: String?
    @Published private(set) var downloadingModel = false
    @Published private(set) var installedModels: [LyricsModel] = []
    @Published var hasUnread = false
    @Published private(set) var modelFailed = false
    private var attemptedModel: LyricsModel?
    var modelProgress: Double? {
        guard let status = modelStatus, let range = status.range(of: #"\d+(?=%)"#, options: .regularExpression),
              let percent = Double(status[range]) else { return nil }
        return min(1, max(0, percent / 100))
    }

    func clearFinished() {
        jobs.removeAll { $0.finished }
        clearModelResult()
        hasUnread = false
    }
    func clear(_ id: UUID) { jobs.removeAll { $0.id == id && $0.finished } }
    func clearModelResult() {
        guard !downloadingModel else { return }
        modelStatus = nil
        modelFailed = false
    }
    func retryModel() { if let attemptedModel { download(attemptedModel) } }
    func retry(_ id: UUID, library: MusicLibrary) {
        guard let job = jobs.first(where: { $0.id == id && $0.failed }),
              let current = library.track(forPath: job.track.url.path), !downloadingModel else { return }
        clear(id)
        start(track: current, destination: job.destination, library: library)
    }
    var activeCount: Int { jobs.filter { !$0.finished }.count }

    private let alignment = LyricsAlignment()
    private var task: Task<Void, Never>?
    private var progress: AnyCancellable?
    private var modelTask: Task<Void, Never>?

    init() {
        refreshModels()
    }
    func refreshModels() { installedModels = alignment.installedModels }

    func download(_ model: LyricsModel) {
        guard activeCount == 0, !downloadingModel else { return }
        downloadingModel = true
        modelFailed = false
        attemptedModel = model
        modelStatus = "正在下载 \(model.title)…"
        hasUnread = true
        modelTask = Task { [self] in
            let subscription = alignment.$status.sink { [weak self] value in
                if !value.isEmpty { self?.modelStatus = value }
            }
            defer {
                subscription.cancel()
                downloadingModel = false
                refreshModels()
                hasUnread = true
                modelTask = nil
            }
            do {
                try await alignment.downloadModel(model)
                modelStatus = "\(model.title)模型已下载并通过校验"
            } catch { modelFailed = true; modelStatus = "模型下载失败：\(error.localizedDescription)" }
        }
    }

    func deleteModel(_ model: LyricsModel) {
        guard activeCount == 0, !downloadingModel else { return }
        do {
            try alignment.deleteModel(model)
            modelStatus = "\(model.title)资源已删除"
        } catch { modelStatus = error.localizedDescription }
        refreshModels()
        hasUnread = true
    }

    func start(track: Track, destination: LyricsDestination, library: MusicLibrary) {
        guard !downloadingModel else {
            alert = LyricsSyncAlert(kind: .warning, title: "模型正在下载", message: "原歌词已保存，请等待模型下载完成后重新同步。")
            hasUnread = true
            return
        }
        jobs.append(LyricsSyncJob(track: track, destination: destination))
        runNext(library: library)
    }

    private func runNext(library: MusicLibrary) {
        guard task == nil, let job = jobs.first(where: { !$0.finished }) else { return }
        let track = job.track
        let destination = job.destination
        let source = track.lyrics
        status = "正在为《\(track.title)》匹配歌词…"
        update(job.id, "准备同步…")
        progress = alignment.$status.sink { [weak self] value in
            if !value.isEmpty { self?.update(job.id, value) }
        }
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                self.progress = nil
                self.status = nil
                self.task = nil
                self.runNext(library: library)
            }
            do {
                var aligned = track
                aligned.lyrics = try await self.alignment.align(
                    source: source,
                    audioURL: track.url,
                    duration: track.duration,
                    title: track.title
                )
                try Task.checkCancellation()
                guard var current = library.track(forPath: track.url.path), current.lyrics == source else {
                    self.update(job.id, "歌词已被修改或歌曲已移除，本次结果未覆盖新内容", finished: true)
                    return
                }
                current.lyrics = aligned.lyrics
                current.artworkWasEdited = false
                try await library.save(current, lyricsDestination: destination)
                self.update(job.id, self.alignment.warning ?? "同步完成", finished: true)
                if let warning = self.alignment.warning {
                    self.alert = LyricsSyncAlert(kind: .warning, title: "歌词已保存，部分行待校正", message: warning)
                } else {
                    self.alert = LyricsSyncAlert(kind: .success, title: "歌词同步完成", message: "《\(track.title)》已生成可自动跟随的时间轴。")
                }
            } catch is CancellationError {
                self.update(job.id, "已取消", finished: true)
                self.alert = LyricsSyncAlert(kind: .warning, title: "歌词同步已取消", message: "原歌词已保存，稍后可再次编辑并同步。")
            } catch {
                self.update(job.id, error.localizedDescription, finished: true, failed: true)
                self.alert = LyricsSyncAlert(kind: .failure, title: "歌词同步失败", message: error.localizedDescription)
            }
        }
    }

    private func update(_ id: UUID, _ detail: String, finished: Bool = false, failed: Bool = false) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].detail = detail
        jobs[index].finished = finished
        jobs[index].failed = failed
        if finished { hasUnread = true }
    }
}
