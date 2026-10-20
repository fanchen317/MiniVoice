import Foundation

/// All regenerable MiniVoice data shares one Finder-visible cache root.
enum CacheStorage {
    static let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(AppIdentity.bundleIdentifier, isDirectory: true)
    static let indexes = root.appendingPathComponent("LibraryIndex", isDirectory: true)
    static let resources = root.appendingPathComponent("Resources-v2", isDirectory: true)
    static let artworkExports = root.appendingPathComponent("Exports/Artwork", isDirectory: true)

    static func migrateLegacyCaches() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MiniVoice/LibraryIndex", isDirectory: true)
        try mergeDirectory(from: support, to: indexes, backup: root.appendingPathComponent("MigrationBackup/LibraryIndex"))
        try PlaylistCache.consolidateLegacyIndexes()
        let caches = root.deletingLastPathComponent()
        for identity in AppIdentity.legacyBundleIdentifiers {
            try mergeDirectory(from: caches.appendingPathComponent("\(identity)/Resources-v2"), to: resources,
                               backup: root.appendingPathComponent("MigrationBackup/\(identity)"))
        }
    }

    /// Preserve destination entries and keep conflicting legacy files inside the
    /// same root for recovery. Repeated launches can safely finish an interrupted move.
    static func mergeDirectory(from source: URL, to destination: URL, backup: URL) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: source.path), source.standardizedFileURL != destination.standardizedFileURL else { return }
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: destination.path) {
            try manager.moveItem(at: source, to: destination)
            return
        }
        for file in try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey]) {
            let target = destination.appendingPathComponent(file.lastPathComponent)
            if !manager.fileExists(atPath: target.path) {
                try manager.moveItem(at: file, to: target)
            } else if try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try mergeDirectory(from: file, to: target, backup: backup.appendingPathComponent(file.lastPathComponent))
            } else {
                try manager.createDirectory(at: backup, withIntermediateDirectories: true)
                try manager.moveItem(at: file, to: backup.appendingPathComponent("\(UUID())-\(file.lastPathComponent)"))
            }
        }
        try manager.removeItem(at: source) // Only the emptied legacy directory remains.
    }
}
