import Foundation

struct FolderScan: Sendable {
    var urls: [URL] = []
    var issues: [String] = []
}

enum FolderScanner {
    static let extensions: Set<String> = ["mp3", "flac", "m4a", "aac", "wav", "aiff", "aif"]
    static func scan(_ folders: [URL], recursive: Bool) -> FolderScan {
        var result = FolderScan()
        var found = Set<URL>()
        let manager = FileManager.default
        for folder in folders {
            var directory: ObjCBool = false
            guard manager.fileExists(atPath: folder.path, isDirectory: &directory), directory.boolValue,
                  manager.isReadableFile(atPath: folder.path) else {
                result.issues.append("文件夹无法访问：\(folder.path)"); continue
            }
            var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            if !recursive { options.insert(.skipsSubdirectoryDescendants) }
            guard let enumerator = manager.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: options, errorHandler: { url, error in
                result.issues.append("\(url.lastPathComponent)：\(error.localizedDescription)"); return true
            }) else { continue }
            for case let url as URL in enumerator {
                guard extensions.contains(url.pathExtension.lowercased()),
                      let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                      values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                found.insert(url.resolvingSymlinksInPath().standardizedFileURL)
            }
        }
        result.urls = found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return result
    }
}
