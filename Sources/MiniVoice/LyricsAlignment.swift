import Foundation
import NaturalLanguage
import Darwin

enum LyricsModel: String, CaseIterable, Identifiable {
    case small, medium
    var id: String { rawValue }
    var title: String { self == .small ? "快速（small）" : "精准（medium）" }
    static var selected: LyricsModel {
        LyricsModel(rawValue: UserDefaults.standard.string(forKey: "MiniVoice.lyricsModel") ?? "medium") ?? .medium
    }
}

struct AlignedLyric: Codable, Sendable {
    let text: String
    let start: Double?
    let end: Double?
}

enum LyricsAlignmentError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

/// All model work runs in a separate process. The main actor only polls its status.
@MainActor
final class LyricsAlignment: ObservableObject {
    @Published private(set) var status = ""
    @Published private(set) var warning: String?
    private static var isBusy = false
    private static let runtimeVersion = "stable-ts-2.19.1-v1"
    private let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MiniVoice/LyricsAI", isDirectory: true)

    var installedModels: [LyricsModel] {
        LyricsModel.allCases.filter {
            let size = (try? FileManager.default.attributesOfItem(atPath: modelURL($0).path)[.size] as? NSNumber)?.int64Value ?? 0
            return size >= ($0 == .small ? 480_000_000 : 1_500_000_000)
        }
    }

    private func modelURL(_ model: LyricsModel) -> URL {
        root.appendingPathComponent("models").appendingPathComponent(model.rawValue + ".pt")
    }

    func deleteModel(_ model: LyricsModel) throws {
        guard !Self.isBusy else { throw LyricsAlignmentError.failed("请等待当前模型任务完成后再删除。") }
        if FileManager.default.fileExists(atPath: modelURL(model).path) { try FileManager.default.removeItem(at: modelURL(model)) }
    }

    func downloadModel(_ model: LyricsModel) async throws {
        guard !Self.isBusy else { throw LyricsAlignmentError.failed("请等待当前歌词任务完成后再下载。") }
        Self.isBusy = true
        defer { Self.isBusy = false; status = "" }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-model-\(UUID())")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let python = try await prepareRuntime(work: work)
        guard let worker = Bundle.module.url(forResource: "align_lyrics", withExtension: "py") else {
            throw LyricsAlignmentError.failed("应用缺少模型下载组件。")
        }
        status = "下载 \(model.rawValue) 模型…"
        do {
            let progress = work.appendingPathComponent("download-status.txt")
            try await run(python, [worker.path, "--download-model", model.rawValue, root.appendingPathComponent("models").path, progress.path], work: work, statusFile: progress, timeout: 7200)
        } catch {
            try? FileManager.default.removeItem(at: modelURL(model))
            throw error
        }
    }

    nonisolated static func needsAlignment(_ source: String) -> Bool {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return LRCParser.parse(LRCParser.imported(source), placeholder: false).contains { !$0.text.isEmpty && $0.timestamp == nil }
    }

    /// Keep credits/section labels in metadata, but do not ask the model to hear them.
    nonisolated static func alignmentSource(_ source: String, title: String) -> String {
        var sawLyrics = false
        let annotated = LRCParser.imported(source).components(separatedBy: .newlines).map { raw in
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let heading = text.components(separatedBy: " - ").first ?? text
            let baseHeading = heading.replacingOccurrences(of: #"\s*[（(].*?[）)]"#, with: "", options: .regularExpression)
            let baseTitle = title.replacingOccurrences(of: #"\s*[（(].*?[）)]"#, with: "", options: .regularExpression)
            let isTitle = !sawLyrics && !title.isEmpty && (baseHeading.localizedCaseInsensitiveCompare(baseTitle) == .orderedSame ||
                (text.contains(" - ") && baseHeading.lowercased().hasPrefix(baseTitle.lowercased() + " ")))
            let isCredit = Self.isCredit(text)
            let isSection = text.range(of: #"^\[(?i:verse|chorus|bridge|intro|outro|instrumental|pre-chorus|副歌|主歌|间奏|間奏)[^\]]*\]$"#, options: .regularExpression) != nil
            if !text.isEmpty && !text.hasPrefix("[") && !isTitle && !isCredit && !isSection { sawLyrics = true }
            return isTitle || isCredit || isSection ? "[note:\(text)]" : raw
        }.joined(separator: "\n")
        return LyricsText.normalized(annotated)
    }

    private nonisolated static func isCredit(_ text: String) -> Bool {
        guard let separator = text.firstIndex(where: { $0 == ":" || $0 == "：" }) else { return false }
        let role = text[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !role.isEmpty, role.count <= 24 else { return false }
        let keywords = [
            "词", "詞", "曲", "编曲", "編曲", "制作", "製作", "总监", "總監", "监制", "監製",
            "统筹", "統籌", "策划", "策劃", "企划", "企劃", "出品", "发行", "發行", "宣发",
            "录音", "錄音", "混音", "母带", "母帶", "工程师", "工程師", "工作室", "录音棚", "錄音棚",
            "吉他", "贝斯", "貝斯", "鼓", "钢琴", "鋼琴", "弦乐", "弦樂", "和声", "和聲", "人声", "人聲",
            "伴唱", "童声", "童聲", "原唱", "演唱", "歌手", "rap填词", "rap填詞", "program",
            "lyrics", "composer", "arranger", "produced by", "op", "sp"
        ]
        return keywords.contains { role.localizedCaseInsensitiveContains($0) }
    }

    /// Validate again at the application boundary; preserve any manually supplied anchors.
    nonisolated static func merge(_ result: [AlignedLyric], source: String, duration: Double) throws -> String {
        let lines = LRCParser.parse(LRCParser.imported(source), placeholder: false).filter { !$0.text.isEmpty }
        guard duration.isFinite, duration > 0, !lines.isEmpty, result.count == lines.count else {
            throw LyricsAlignmentError.failed("歌词未能完整匹配，原歌词未改动。")
        }
        let matchedCount = zip(lines, result).filter { $0.0.timestamp != nil || $0.1.start != nil }.count
        guard Double(matchedCount) / Double(lines.count) >= 0.65 else {
            throw LyricsAlignmentError.failed("较多歌词未能匹配，请检查歌曲版本后重试，或先保存文本。")
        }
        var previous = -1.0
        let metadata = source.components(separatedBy: .newlines).filter {
            $0.range(of: #"^\s*\[(?!offset:)[A-Za-z]+:.*\]\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil
        }
        let timed = try zip(lines, result).map { line, aligned in
            guard aligned.text == line.text else {
                throw LyricsAlignmentError.failed("对齐结果与歌词原文不一致，请重试。")
            }
            // Unmatched lines remain readable plain text; never fabricate their timestamps.
            if aligned.start == nil && aligned.end == nil && line.timestamp == nil { return line.text }
            if let start = aligned.start, let end = aligned.end {
                guard start.isFinite, end.isFinite, start >= 0, end > start, end <= duration + 0.5 else {
                    throw LyricsAlignmentError.failed("部分歌词时间无效，请重试同步。")
                }
            } else if aligned.start != nil || aligned.end != nil {
                throw LyricsAlignmentError.failed("歌词时间轴不完整，请重试同步。")
            }
            guard let time = line.timestamp ?? aligned.start, time.isFinite, time >= 0, time < duration,
                  (time * 100).rounded() > previous else {
                throw LyricsAlignmentError.failed("已有时间点与新时间轴冲突，请检查手动打点。")
            }
            previous = (time * 100).rounded()
            return LRCParser.stamp(time, text: line.text)
        }
        return (metadata + timed).joined(separator: "\n")
    }

    func align(source: String, audioURL: URL, duration: Double, title: String = "") async throws -> String {
        warning = nil
        let normalized = Self.alignmentSource(source, title: title)
        guard Self.needsAlignment(normalized) else { return normalized }
        try Task.checkCancellation()
        let model = LyricsModel.selected
        guard installedModels.contains(model) else {
            throw LyricsAlignmentError.failed("尚未下载\(model.title)模型，请在设置的“歌词匹配”中下载后重试。原歌词已保存。")
        }
        guard !Self.isBusy else { throw LyricsAlignmentError.failed("另一首歌曲正在同步，请完成或取消后重试。") }
        Self.isBusy = true
        defer { Self.isBusy = false }
        try Task.checkCancellation()
        guard duration.isFinite, duration > 0 else { throw LyricsAlignmentError.failed("无法读取歌曲时长。") }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("MiniVoice-align-\(UUID())")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work); status = "" }
        let python = try await prepareRuntime(work: work)
        guard let worker = Bundle.module.url(forResource: "align_lyrics", withExtension: "py") else {
            throw LyricsAlignmentError.failed("应用缺少歌词同步组件，请重新安装。")
        }
        let lines = LRCParser.parse(normalized, placeholder: false).filter { !$0.text.isEmpty }.map(\.text)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(lines.joined(separator: "\n"))
        let detected = recognizer.dominantLanguage?.rawValue ?? "en"
        let language = detected.hasPrefix("zh") ? "zh" : detected
        let request: [String: Any] = ["audioPath": audioURL.path, "lines": lines,
                                     "duration": duration, "language": language,
                                     "modelDirectory": root.appendingPathComponent("models").path, "model": model.rawValue]
        let requestURL = work.appendingPathComponent("request.json")
        try JSONSerialization.data(withJSONObject: request).write(to: requestURL)
        let output = work.appendingPathComponent("result.json")
        let progress = work.appendingPathComponent("status.txt")
        status = "正在加载 AI 模型（首次使用需要下载）…"
        try await run(python, [worker.path, requestURL.path, output.path, progress.path], work: work,
                      statusFile: progress, timeout: 3600)
        let result = try JSONDecoder().decode([AlignedLyric].self, from: Data(contentsOf: output))
        let merged = try Self.merge(result, source: normalized, duration: duration)
        let unmatched = LRCParser.parse(merged, placeholder: false).filter { $0.timestamp == nil }.count
        if unmatched > 0 {
            warning = "已保存可同步的歌词。还有 \(unmatched) 行未能匹配，已保留原文，不会自动高亮。可在编辑窗口为这些行手动打点，或检查歌词版本后重新同步。"
        }
        return merged
    }

    private func prepareRuntime(work: URL) async throws -> URL {
        let environment = root.appendingPathComponent("venv")
        let python = environment.appendingPathComponent("bin/python3")
        let marker = root.appendingPathComponent("runtime-version")
        if (try? String(contentsOf: marker, encoding: .utf8)) == Self.runtimeVersion,
           FileManager.default.isExecutableFile(atPath: python.path) { return python }
        status = "首次使用：准备 AI 环境…"
        if !FileManager.default.isExecutableFile(atPath: python.path) {
            let candidates = ["/opt/homebrew/bin/python3.12", "/usr/local/bin/python3.12",
                              "/opt/homebrew/bin/python3.11", "/usr/local/bin/python3.11", "/usr/bin/python3"]
            guard let systemPython = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                throw LyricsAlignmentError.failed("请先安装 Python 3.11 或 3.12，再重试歌词同步。")
            }
            try await run(URL(fileURLWithPath: systemPython), ["-m", "venv", environment.path], work: work)
        }
        try await run(python, ["-m", "pip", "install", "--disable-pip-version-check", "stable-ts==2.19.1"], work: work)
        try await run(python, ["-c", "import stable_whisper"], work: work)
        try Self.runtimeVersion.write(to: marker, atomically: true, encoding: .utf8)
        return python
    }

    private func run(_ executable: URL, _ arguments: [String], work: URL,
                     statusFile: URL? = nil, timeout: TimeInterval = 1800) async throws {
        try Task.checkCancellation()
        let log = work.appendingPathComponent("process-\(UUID()).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment
        process.standardOutput = handle
        process.standardError = handle
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        do {
            while process.isRunning {
                try await Task.sleep(nanoseconds: 200_000_000)
                if let statusFile, let message = try? String(contentsOf: statusFile, encoding: .utf8), !message.isEmpty {
                    status = message
                }
                if Date() > deadline { throw LyricsAlignmentError.failed("歌词同步超时，请稍后重试。") }
            }
            try Task.checkCancellation()
        } catch {
            if process.isRunning {
                process.terminate()
                // A model library can delay SIGTERM; do not leave inference running after cancellation.
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                await Task.detached { process.waitUntilExit() }.value
            }
            throw error
        }
        guard process.terminationStatus == 0 else {
            let detail = (try? String(contentsOf: log, encoding: .utf8)) ?? "未知错误"
            try? detail.write(to: root.appendingPathComponent("last-error.log"), atomically: true, encoding: .utf8)
            let errorURL = work.appendingPathComponent("result.error.json")
            let errorData = try? Data(contentsOf: errorURL)
            let errorInfo = errorData.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            throw LyricsAlignmentError.failed(errorInfo?["message"] ?? "本地 AI 暂时无法完成同步。请检查网络与本地 AI 环境后重试，也可以先保存歌词文本。详细诊断已记录到 LyricsAI/last-error.log。")
        }
    }
}
