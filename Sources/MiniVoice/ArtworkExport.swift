import AppKit
import CryptoKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Exports the source pixels, independently of the size or cropping of the preview.
struct ArtworkExport {
    let data: Data
    let type: UTType
    let image: NSImage

    init(image: NSImage, originalData: Data? = nil) throws {
        let bytes: Data
        if let originalData {
            bytes = originalData
        } else {
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw ExportError.invalidImage
            }
            bytes = png
        }
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let identifier = CGImageSourceGetType(source),
              let type = UTType(identifier as String), type.conforms(to: .image),
              let decoded = NSImage(data: bytes) else { throw ExportError.invalidImage }
        self.data = bytes
        self.type = type
        self.image = decoded
    }

    func fileURL(name: String) throws -> URL {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let directory = CacheStorage.artworkExports
            .appendingPathComponent(digest, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/\\:\n\r\t").union(.controlCharacters))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        let filename = cleaned.isEmpty ? "专辑封面" : String(cleaned.prefix(100))
        let url = directory.appendingPathComponent(filename).appendingPathExtension(type.preferredFilenameExtension ?? "png")
        if !FileManager.default.fileExists(atPath: url.path) { try data.write(to: url, options: .atomic) }
        return url
    }

    @MainActor func copy(name: String, to pasteboard: NSPasteboard = .general) throws {
        let url = try fileURL(name: name)
        let item = NSPasteboardItem()
        item.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
        if let tiff = image.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        item.setString(url.absoluteString, forType: .fileURL)
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ExportError.clipboardUnavailable }
    }

    func itemProvider(name: String) throws -> NSItemProvider {
        let url = try fileURL(name: name)
        let provider = NSItemProvider(object: url as NSURL)
        provider.suggestedName = url.lastPathComponent
        let bytes = data
        provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(bytes, nil)
            return nil
        }
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { completion in
            completion(url, false, nil)
            return nil
        }
        return provider
    }

    enum ExportError: LocalizedError {
        case invalidImage, clipboardUnavailable
        var errorDescription: String? {
            switch self {
            case .invalidImage: "无法导出这张封面。"
            case .clipboardUnavailable: "无法复制封面，请重试。"
            }
        }
    }
}

struct CopyArtworkButton: View {
    let image: NSImage
    var originalData: Data? = nil
    let name: String
    @State private var copied = false
    @State private var error: String?

    var body: some View {
        Button {
            do {
                try ArtworkExport(image: image, originalData: originalData).copy(name: name)
                copied = true
            } catch { self.error = error.localizedDescription }
        } label: {
            Label(copied ? "已复制" : "复制封面", systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .keyboardShortcut("c", modifiers: .command)
        .task(id: copied) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(2)); copied = false } catch {}
        }
        .alert("复制失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct ArtworkExportModifier: ViewModifier {
    let image: NSImage
    var originalData: Data? = nil
    let name: String
    @State private var error: String?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onDrag {
                do { return try ArtworkExport(image: image, originalData: originalData).itemProvider(name: name) }
                catch { self.error = error.localizedDescription; return NSItemProvider() }
            }
            .contextMenu { CopyArtworkButton(image: image, originalData: originalData, name: name) }
            .help("可拖拽到文件夹或聊天窗口，或右键复制封面")
            .alert("导出失败", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("好", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }
}
