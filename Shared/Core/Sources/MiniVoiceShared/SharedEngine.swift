import Foundation
import MiniVoiceCore

public enum SharedEngine {
    public struct Word: Codable, Equatable, Sendable {public let ms: Int64; public let endMs: Int64; public let text: String}
    public struct Line: Codable, Equatable, Sendable {
        public let ms: Int64; public let text: String; public let translation: String; public let words: [Word]
        public var displayText: String {translation.isEmpty ? text : text + "\n" + translation}
    }
    public enum Failure: Error {case allocation, invalidResponse, rejected(String)}
    /// C ABI transports UTF-8 JSON only; platform storage/audio/window objects stay outside this module.
    public static func executeJSON(_ request: String) throws -> String {
        guard let response = request.withCString({ mv_core_execute($0) }) else {throw Failure.allocation}
        defer {mv_core_free(response)}
        return String(cString: response)
    }
    public static func execute(_ request: [String: Any]) throws -> Any {
        let data = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
        let response = try executeJSON(String(decoding: data, as: UTF8.self))
        guard let row = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any] else {throw Failure.invalidResponse}
        guard row["ok"] as? Bool == true else {throw Failure.rejected(row["error"] as? String ?? "Unknown error")}
        return row["value"] ?? NSNull()
    }
    public static func parseLyrics(_ source: String) throws -> [Line] {
        let value = try execute(["version": 1, "op": "lyrics.parse", "raw": source])
        return try JSONDecoder().decode([Line].self, from: JSONSerialization.data(withJSONObject: value))
    }
}
