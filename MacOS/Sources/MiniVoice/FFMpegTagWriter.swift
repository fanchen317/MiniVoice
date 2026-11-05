import AppKit
import Foundation
import CryptoKit

enum TagWriteError: LocalizedError {
    case missingFFmpeg
    case artworkEncodingFailed
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingFFmpeg: return "未找到 ffmpeg / ffprobe。若使用安装版，请重新安装应用；若通过 swift run 启动，请先安装本机 FFmpeg。"
        case .artworkEncodingFailed: return "无法将封面转换为 PNG。"
        case .failed(let message): return message
        }
    }
}

private func tagFileDigest(_ url: URL) throws -> SHA256.Digest {
 let handle = try FileHandle(forReadingFrom: url)
 defer { try? handle.close() }
 var hash = SHA256()
 while let bytes = try handle.read(upToCount: 1024 * 1024), !bytes.isEmpty { hash.update(data: bytes) }
 return hash.finalize()
}

enum MediaTools {
    static func executable(_ name: String) throws -> URL {
        let paths = [Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(name)").path,
                     Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/lyrics-worker/_internal/\(name)").path,
                     "/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
        guard let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw TagWriteError.missingFFmpeg
        }
        return URL(fileURLWithPath: path)
    }

    // Read output while the process runs; waiting first can deadlock when a pipe fills.
    static func run(_ name: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = try executable(name)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer { try? errorHandle.close(); try? FileManager.default.removeItem(at: errorURL) }
        process.standardError = errorHandle
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? "未知错误"
            throw TagWriteError.failed(String(detail.suffix(1200)))
        }
        return data
    }
}

struct TagPayload: Sendable {
    let url: URL
    let title: String
    let artist: String
    let album: String
    let lyrics: String
    let artwork: Data?
    var preserveArtwork = false
}

enum FFMpegTagWriter {
    static func write(_ track: TagPayload) throws {
        let ext = track.url.pathExtension.lowercased()
        guard ["mp3", "flac", "m4a"].contains(ext) else {
            throw TagWriteError.failed("此格式支持播放；完整标签和封面写入目前支持 MP3、FLAC、M4A。")
        }
        let directory = track.url.deletingLastPathComponent()
        let output = directory.appendingPathComponent(".minivoice-\(UUID().uuidString).\(ext)")
        let originalDigest = try tagFileDigest(track.url)
        let cover = directory.appendingPathComponent(".minivoice-cover-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: output); try? FileManager.default.removeItem(at: cover) }
        var args = ["-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", track.url.path]
        if let artwork = track.artwork {
            try artwork.write(to: cover)
            args += ["-i", cover.path]
        }
        // Map audio only so replacing/removing artwork really removes the old attachment.
        args += ["-map", "0:a", "-map_metadata", "0", "-c", "copy"]
        if track.preserveArtwork { args += ["-map", "0:v?"] }
        if track.artwork != nil {
            args += ["-map", "1:v:0", "-disposition:v:0", "attached_pic",
                     "-metadata:s:v:0", "title=Cover", "-metadata:s:v:0", "comment=Cover (front)"]
        }
        if ext == "mp3" { args += ["-id3v2_version", "3"] }
        args += ["-metadata", "title=\(track.title)", "-metadata", "artist=\(track.artist)",
                 "-metadata", "album=\(track.album)", "-metadata", "lyrics=\(track.lyrics)", output.path]
        _ = try MediaTools.run("ffmpeg", args)
        let checkData = try MediaTools.run("ffprobe", ["-v", "error", "-show_format", "-of", "json", output.path])
        guard let check = try JSONSerialization.jsonObject(with: checkData) as? [String: Any],
              let format = check["format"] as? [String: Any] else { throw TagWriteError.failed("标签回读失败，原文件未更改") }
        let tags = (format["tags"] as? [String: String] ?? [:]).reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
        guard (tags["title"] ?? "") == track.title, (tags["artist"] ?? "") == track.artist,
              (tags["album"] ?? "") == track.album, (tags["lyrics"] ?? tags["unsyncedlyrics"] ?? "") == track.lyrics else {
            throw TagWriteError.failed("标签内容校验失败，原文件未更改")
        }
        let audioHashArgs = ["-v", "error", "-i"]
        let originalAudio = try MediaTools.run("ffmpeg", audioHashArgs + [track.url.path, "-map", "0:a", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"])
        let outputAudio = try MediaTools.run("ffmpeg", audioHashArgs + [output.path, "-map", "0:a", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"])
        guard originalAudio == outputAudio, try tagFileDigest(track.url) == originalDigest else {
            throw TagWriteError.failed("音频或原文件校验失败，原文件未更改")
        }
        // Keep recoverable originals together and out of the music library scan.
        let backupDirectory = directory.appendingPathComponent("backup", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let backup = backupDirectory.appendingPathComponent("\(track.url.lastPathComponent).minivoice-backup-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: track.url, to: backup)
        guard try tagFileDigest(backup) == originalDigest, try tagFileDigest(track.url) == originalDigest else {
            throw TagWriteError.failed("备份或原文件校验失败，原文件未更改")
        }
        _ = try FileManager.default.replaceItemAt(track.url, withItemAt: output)
    }
}
