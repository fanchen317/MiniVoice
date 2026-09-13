import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum CloseBehavior: String, CaseIterable, Identifiable {
    case background, pause, quit
    var id: String { rawValue }
    var title: String {
        switch self {
        case .background: return "关闭窗口，继续后台播放"
        case .pause: return "关闭窗口，暂停播放"
        case .quit: return "退出 MiniVoice"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct WindowCloseObserver: NSViewRepresentable {
    let library: MusicLibrary
    func makeNSView(context: Context) -> CloseView { CloseView(library: library) }
    func updateNSView(_ nsView: CloseView, context: Context) {}

    final class CloseView: NSView {
        let library: MusicLibrary
        init(library: MusicLibrary) { self.library = library; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: nil)
            if let window { NotificationCenter.default.addObserver(self, selector: #selector(closing), name: NSWindow.willCloseNotification, object: window) }
        }
        @objc private func closing() {
            let behavior = CloseBehavior(rawValue: UserDefaults.standard.string(forKey: "MiniVoice.closeBehavior") ?? "background") ?? .background
            switch behavior {
            case .background: break
            case .pause: library.pause()
            case .quit: NSApp.terminate(nil)
            }
        }
    }
}

struct AppSettings: View {
    @EnvironmentObject private var library: MusicLibrary
    @AppStorage("MiniVoice.closeBehavior") private var closeBehavior = CloseBehavior.background.rawValue
    @State private var choosingFolders = false

    var body: some View {
        TabView {
            VStack(alignment: .leading, spacing: 16) {
                Text("音乐文件夹").font(.title2.bold())
                Text("启动优先读取文件夹中的隐藏歌单；重新扫描时更新。移除文件夹不会删除歌曲。")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                List {
                    ForEach(library.folders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                            Text(folder.path).lineLimit(2).help(folder.path)
                            Spacer()
                            Button { library.removeFolder(folder) } label: { Image(systemName: "minus.circle") }.help("移除文件夹")
                        }.padding(.vertical, 4)
                    }
                }.frame(minHeight: 120)
                HStack {
                    Button("添加文件夹…") { choosingFolders = true }
                    Button("重新扫描") { library.rescan() }.disabled(library.isImporting || library.folders.isEmpty)
                    Spacer()
                    if library.isImporting { ProgressView().controlSize(.small) }
                }
                Toggle("包含子文件夹", isOn: $library.recursiveScan)
                Text(library.scanSummary).font(.caption).foregroundStyle(.secondary)
                if !library.scanIssues.isEmpty {
                    ScrollView {
                        Text(library.scanIssues.joined(separator: "\n")).font(.caption).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }.frame(height: 65)
                }
            }.padding(24).tabItem { Label("音乐库", systemImage: "folder") }
            VStack(alignment: .leading, spacing: 20) {
                Picker("点击左上角关闭按钮", selection: $closeBehavior) {
                    ForEach(CloseBehavior.allCases) { item in Text(item.title).tag(item.rawValue) }
                }
                Text("关闭窗口后，可通过 Dock 或状态栏重新打开。⌘Q 始终退出应用。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                AppearanceSettings()
                Spacer()
            }.padding(24).tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(width: 620, height: 460)
        .fileImporter(isPresented: $choosingFolders, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): library.addFolders(urls)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
    }
}

/// A real Settings scene menu action, compatible with macOS 13 and newer.
struct OpenSettingsButton: View {
    var body: some View {
        if #available(macOS 14, *) {
            SettingsLink { Label("设置", systemImage: "gearshape") }
        } else {
            Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: { Label("设置", systemImage: "gearshape") }
        }
    }
}
