import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

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
            if let window {
                // Keep the content pane opaque; only the sidebar's behind-window
                // material samples the desktop and windows beneath it.
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                NotificationCenter.default.addObserver(self, selector: #selector(closing), name: NSWindow.willCloseNotification, object: window)
            }
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
    @EnvironmentObject private var systemVolume: SystemVolume
    @EnvironmentObject private var shortcuts: PlaybackShortcutController
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
            AudioDeviceSettings()
                .tabItem { Label("音频设备", systemImage: "speaker.wave.2") }
            ShortcutSettings()
                .tabItem { Label("快捷键", systemImage: "keyboard") }
        }
        .frame(width: 620, height: 500)
        .fileImporter(isPresented: $choosingFolders, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): library.addFolders(urls)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AudioDeviceSettings: View {
    @EnvironmentObject private var systemVolume: SystemVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("音频设备").font(.title2.bold())
            Text("选择后会更改 Mac 的默认播放输出设备。")
                .foregroundStyle(.secondary)
            Picker("播放输出设备", selection: Binding(get: { systemVolume.outputDeviceID }, set: { systemVolume.selectOutputDevice($0) })) {
                ForEach(systemVolume.outputDevices) { device in Text(device.name).tag(device.id) }
            }
            if let error = systemVolume.error { Text(error).font(.caption).foregroundStyle(.red) }
            Spacer()
        }.padding(24)
    }
}

private struct ShortcutSettings: View {
    @EnvironmentObject private var shortcuts: PlaybackShortcutController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("播放快捷键").font(.title2.bold())
            Text("点击快捷键后直接按下新组合键；按 Esc 取消。快捷键在 MiniVoice 前台且未输入文字时生效。")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(PlaybackShortcutAction.allCases) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    Button(shortcuts.recordingAction == action ? "按下快捷键…" : shortcuts.shortcut(for: action).description) {
                        shortcuts.beginRecording(action)
                    }.frame(minWidth: 120)
                    Button("恢复默认") { shortcuts.reset(action) }
                }
            }
            Spacer()
        }.padding(24)
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
