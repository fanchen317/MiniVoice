import AppKit
import Foundation

enum TagWriteError: LocalizedError {
    case missingFFmpeg
    case artworkEncodingFailed
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingFFmpeg: return "未找到 ffmpeg。请先通过 Homebrew 安装：brew install ffmpeg"
        case .artworkEncodingFailed: return "无法将封面转换为 PNG。"
        case .failed(let message): return message
        }
    }
}

enum FFMpegTagWriter {
    static func write(track: Track, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/ffmpeg") || FileManager.default.isExecutableFile(atPath: "/usr/local/bin/ffmpeg") else {
                completion(.failure(TagWriteError.missingFFmpeg)); return
            }
            let directory = track.url.deletingLastPathComponent()
            let output = directory.appendingPathComponent(".audiocanvas-\(UUID().uuidString).\(track.url.pathExtension)")
            let cover = directory.appendingPathComponent(".audiocanvas-cover-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: output); try? FileManager.default.removeItem(at: cover) }
            var inputArguments = ["-y", "-i", track.url.path]
            if let artwork = track.artwork {
                guard let tiff = artwork.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else {
                    completion(.failure(TagWriteError.artworkEncodingFailed)); return
                }
                do { try png.write(to: cover); inputArguments += ["-i", cover.path] }
                catch { completion(.failure(error)); return }
            }
            var arguments = inputArguments
            if track.artwork != nil {
                arguments += ["-map", "0:a:0", "-map", "1:v:0", "-disposition:v", "attached_pic"]
            } else {
                arguments += ["-map", "0"]
            }
            arguments += ["-c", "copy", "-metadata", "title=\(track.title)", "-metadata", "artist=\(track.artist)", "-metadata", "album=\(track.album)", "-metadata", "lyrics=\(track.lyrics)", output.path]
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["ffmpeg"] + arguments
            let pipe = Pipe(); process.standardError = pipe
            do {
                try process.run(); process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    let detail = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "未知错误"
                    completion(.failure(TagWriteError.failed("写入失败：\(detail.suffix(500))"))); return
                }
                _ = try FileManager.default.replaceItemAt(track.url, withItemAt: output)
                completion(.success(()))
            } catch { completion(.failure(error)) }
        }
    }
}
