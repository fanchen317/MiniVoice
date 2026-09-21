import Foundation
import NaturalLanguage
import Darwin

struct AlignedLyric: Codable, Sendable {
    let text: String
    let start: Double
    let end: Double
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
    private static var isBusy = false
    private static let runtimeVersion = "stable-ts-2.19.1-v1"
    private let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MiniVoice/LyricsAI", isDirectory: true)

    nonisolated static func needsAlignment(_ source: String) -> Bool {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return LRCParser.parse(LRCParser.imported(source), placeholder: false).contains { !$0.text.isEmpty && $0.timestamp == nil }
    }

    /// Keep credits/section labels in metadata, but do not ask the model to hear them.
    nonisolated static func alignmentSource(_ source: String, title: String) -> String {
        LRCParser.imported(source).components(separatedBy: .newlines).map { raw in
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let heading = text.components(separatedBy: " - ").first ?? text
            let isTitle = !title.isEmpty && heading.localizedCaseInsensitiveCompare(title) == .orderedSame
            let isCredit = text.range(of: #"^(词|詞|曲|作词|作詞|作曲|编曲|編曲|演唱|歌手|制作人|製作人|混音|录音|錄音|和声|和聲|母带|母帶|出品|发行|發行|监制|監製|制作|製作|词曲|詞曲|专辑|專輯|OP|SP|Lyrics|Composer|Arranger|Produced by)\s*[:：]"#, options: [.regularExpression, .caseInsensitive]) != nil
            let isSection = text.range(of: #"^\[(?i:verse|chorus|bridge|intro|outro|instrumental|pre-chorus|副歌|主歌|间奏|間奏)[^\]]*\]$"#, options: .regularExpression) != nil
            return isTitle || isCredit || isSection ? "[note:\(text)]" : raw
        }.joined(separator: "\n")
    }

    /// Validate again at the application boundary; preserve any manually supplied anchors.
    nonisolated static func merge(_ result: [AlignedLyric], source: String, duration: Double) throws -> String {
        let lines = LRCParser.parse(LRCParser.imported(source), placeholder: false).filter { !$0.text.isEmpty }
        guard duration.isFinite, duration > 0, !lines.isEmpty, result.count == lines.count else {
            throw LyricsAlignmentError.failed("歌词未能完整匹配，原歌词未改动。")
        }
        var previous = -1.0
        let metadata = source.components(separatedBy: .newlines).filter {
            $0.range(of: #"^\s*\[(?!offset:)[A-Za-z]+:.*\]\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil
        }
        let timed = try zip(lines, result).map { line, aligned in
            let time = line.timestamp ?? aligned.start
            guard aligned.text == line.text, aligned.start.isFinite, aligned.end.isFinite,
                  aligned.start >= 0, aligned.end > aligned.start, aligned.end <= duration + 0.5,
                  time.isFinite, time >= 0, time < duration,
                  (time * 100).rounded() > previous else {
                throw LyricsAlignmentError.failed("时间轴存在未匹配或冲突的歌词，请检查歌词版本或使用手动打点。")
            }
            previous = (time * 100).rounded()
            return LRCParser.stamp(time, text: line.text)
        }
        return (metadata + timed).joined(separator: "\n")
    }

    func align(source: String, audioURL: URL, duration: Double, title: String = "") async throws -> String {
        let normalized = Self.alignmentSource(source, title: title)
        guard Self.needsAlignment(normalized) else { return normalized }
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
                                     "modelDirectory": root.appendingPathComponent("models").path]
        let requestURL = work.appendingPathComponent("request.json")
        try JSONSerialization.data(withJSONObject: request).write(to: requestURL)
        let output = work.appendingPathComponent("result.json")
        let progress = work.appendingPathComponent("status.txt")
        status = "正在加载 AI 模型（首次使用需要下载）…"
        try await run(python, [worker.path, requestURL.path, output.path, progress.path], work: work,
                      statusFile: progress, timeout: 3600)
        let result = try JSONDecoder().decode([AlignedLyric].self, from: Data(contentsOf: output))
        return try Self.merge(result, source: normalized, duration: duration)
    }

    private func prepareRuntime(work: URL) async throws -> URL {
        let environment = root.appendingPathComponent("venv")
        let python = environment.appendingPathComponent("bin/python3")
        let marker = root.appendingPathComponent("runtime-version")
        if (try? String(contentsOf: marker, encoding: .utf8)) == Self.runtimeVersion,
           FileManager.default.isExecutableFile(atPath: python.path) { return python }
        status = "首次使用：正在准备本地 AI 环境，需要联网下载…"
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
            throw LyricsAlignmentError.failed("本地 AI 同步失败，可重试或仅保存原歌词。\n\(detail.suffix(800))")
        }
    }
}
