import SwiftUI
import UniformTypeIdentifiers

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general, library, lyrics, audio, shortcuts
    var id: Self { self }
    var title: String {
        switch self {
        case .general: return "通用"
        case .library: return "音乐库"
        case .lyrics: return "歌词匹配"
        case .audio: return "音频设备"
        case .shortcuts: return "快捷键"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .library: return "music.note.list"
        case .lyrics: return "text.alignleft"
        case .audio: return "speaker.wave.2"
        case .shortcuts: return "keyboard"
        }
    }
    var subtitle: String {
        switch self {
        case .general: return "让 MiniVoice 更符合你的使用习惯。"
        case .library: return "管理音乐所在的位置与扫描方式。"
        case .lyrics: return "在本机为歌词匹配时间轴。"
        case .audio: return "选择音乐播放的输出设备。"
        case .shortcuts: return "用熟悉的组合键控制播放。"
        }
    }
}

struct AppSettings: View {
    @State private var selection: SettingsPage = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image(nsImage: BrandIcon.image(size: 32, appIcon: false, monochrome: false))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MiniVoice").font(.headline)
                        Text("设置").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 10).padding(.top, 8)
                VStack(spacing: 5) {
                    ForEach(SettingsPage.allCases) { page in
                        Button { selection = page } label: {
                            HStack(spacing: 10) {
                                Image(systemName: page.symbol).font(.system(size: 15)).frame(width: 22)
                                Text(page.title).font(.system(size: 13, weight: selection == page ? .semibold : .regular))
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).frame(height: 38)
                            .foregroundStyle(selection == page ? Color.accentColor : Color.primary)
                            .background(selection == page ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == page ? [.isSelected] : [])
                    }
                }
                Spacer()
                Text("更改会自动保存").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
            }
            .padding(14).frame(width: 180).frame(maxHeight: .infinity)
            .background(.regularMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(selection.title).font(.system(size: 25, weight: .bold))
                    Text(selection.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                }.padding(28)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch selection {
                        case .general: GeneralSettingsPage()
                        case .library: LibrarySettingsPage()
                        case .lyrics: LyricsSettingsPage()
                        case .audio: AudioSettingsPage()
                        case .shortcuts: ShortcutSettingsPage()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28).padding(.bottom, 28)
                }.id(selection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(Color(red: 0.06, green: 0.55, blue: 0.40))
        .accentColor(Color(red: 0.06, green: 0.55, blue: 0.40))
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .frame(minWidth: 800, idealWidth: 840, maxWidth: .infinity, minHeight: 580, idealHeight: 620, maxHeight: .infinity)
    }
}

/// Shared spacing, surfaces and label hierarchy for every settings category.
struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).padding(.leading, 2)
            VStack(spacing: 0) { content }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07)))
            if let footer {
                Text(footer).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 2)
            }
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            control
        }.padding(16).frame(minHeight: 62)
    }
}

private struct GeneralSettingsPage: View {
    @AppStorage("MiniVoice.closeBehavior") private var closeBehavior = CloseBehavior.background.rawValue
    @AppStorage("MiniVoice.appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage(StatusBarController.preferenceKey) private var iconStyle = StatusIconStyle.colored.rawValue

    var body: some View {
        SettingsGroup(title: "外观") {
            SettingsRow(title: "界面外观") {
                Picker("界面外观", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0.rawValue) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 280)
            }
            Divider().padding(.horizontal, 16)
            SettingsRow(title: "菜单栏图标", detail: "在菜单栏快速控制播放") {
                Picker("菜单栏图标", selection: $iconStyle) {
                    ForEach(StatusIconStyle.allCases) { Text($0 == .hidden ? "隐藏图标" : $0.title).tag($0.rawValue) }
                }.labelsHidden().frame(width: 180)
            }
        }
        SettingsGroup(title: "窗口与播放", footer: "关闭窗口后，可通过 Dock 或菜单栏重新打开。⌘Q 始终退出应用。") {
            SettingsRow(title: "关闭主窗口时") {
                Picker("关闭主窗口时", selection: $closeBehavior) {
                    ForEach(CloseBehavior.allCases) { Text($0.title).tag($0.rawValue) }
                }.labelsHidden().frame(width: 250)
            }
        }
    }
}

private struct LibrarySettingsPage: View {
    @EnvironmentObject private var library: MusicLibrary
    @State private var choosingFolders = false

    var body: some View {
        SettingsGroup(title: "音乐文件夹", footer: "移除文件夹只会将它移出音乐库，不会删除原始歌曲。") {
            if library.folders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("添加你的第一个音乐文件夹").font(.headline)
                    Text("选择本机文件夹，即可在音乐库中浏览和播放。")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ForEach(library.folders, id: \.self) { folder in
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill").font(.system(size: 21)).foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.lastPathComponent).font(.system(size: 13, weight: .medium))
                            Text(folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }.help(folder.path)
                        Spacer(minLength: 8)
                        Button("移除", role: .destructive) { library.removeFolder(folder) }
                            .accessibilityLabel("移除文件夹 \(folder.lastPathComponent)")
                    }.padding(16)
                    Divider().padding(.horizontal, 16)
                }
            }
            HStack {
                Text("\(library.folders.count) 个文件夹").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { choosingFolders = true } label: { Label("添加文件夹…", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
            }.padding(16)
        }
        SettingsGroup(title: "扫描", footer: "启动时优先读取已保存的歌单。文件夹内容变化后，重新扫描以更新音乐库。") {
            SettingsRow(title: "包含子文件夹", detail: "同时读取所选文件夹内的音乐") {
                Toggle("包含子文件夹", isOn: $library.recursiveScan).labelsHidden().toggleStyle(.switch)
            }
            Divider().padding(.horizontal, 16)
            SettingsRow(title: library.isImporting ? "正在更新音乐库" : "音乐库状态", detail: library.scanSummary) {
                if library.isImporting { ProgressView().controlSize(.small) }
                Button("重新扫描") { library.rescan() }.disabled(library.isImporting || library.folders.isEmpty)
            }
        }
        if !library.scanIssues.isEmpty {
            SettingsGroup(title: "需要留意 · \(library.scanIssues.count) 项") {
                DisclosureGroup("查看无法读取的项目") {
                    Text(library.scanIssues.joined(separator: "\n")).font(.caption).foregroundStyle(.secondary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.padding(16)
            }
        }
        // Keep the importer attached to this page, independent of the folder list.
        Color.clear.frame(height: 0)
            .fileImporter(isPresented: $choosingFolders, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): library.addFolders(urls)
                case .failure(let error): library.errorMessage = error.localizedDescription
                }
            }
    }
}

private struct LyricsSettingsPage: View {
    @EnvironmentObject private var sync: LyricsSyncCoordinator
    @AppStorage("MiniVoice.lyricsModel") private var model = "medium"
    @State private var pendingDeletion: LyricsModel?

    var body: some View {
        SettingsGroup(title: "匹配偏好", footer: "歌曲和歌词在本机处理，无需 API Key，也不会上传。") {
            SettingsRow(title: "匹配模式", detail: "应用于下一次歌词匹配") {
                Picker("匹配模式", selection: $model) {
                    ForEach(LyricsModel.allCases) { Text($0.title).tag($0.rawValue) }
                }.labelsHidden().pickerStyle(.segmented).frame(width: 210)
            }
        }
        SettingsGroup(title: "本地资源", footer: "两种资源可以同时保留。首次使用会下载对应资源，下载完成后可离线使用。") {
            ForEach(LyricsModel.allCases) { resource in
                SettingsRow(title: resource.title, detail: resource.rawValue == "small" ? "约 460 MB · 处理更快" : "约 1.5 GB · 适合更复杂的歌曲") {
                    if sync.installedModels.contains(resource) {
                        Label("已下载", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
                        Button("删除", role: .destructive) { pendingDeletion = resource }
                            .disabled(sync.downloadingModel || sync.activeCount > 0)
                            .accessibilityLabel("删除\(resource.title)资源")
                    } else {
                        Button("下载") { sync.download(resource) }
                            .disabled(sync.downloadingModel || sync.activeCount > 0)
                            .accessibilityLabel("下载\(resource.title)资源")
                    }
                }
                if resource.id != LyricsModel.allCases.last?.id { Divider().padding(.horizontal, 16) }
            }
        }
        if sync.downloadingModel || sync.modelStatus != nil || sync.activeCount > 0 {
            HStack(alignment: .top, spacing: 10) {
                if sync.downloadingModel { ProgressView().controlSize(.small) }
                else { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 6) {
                    if let status = sync.modelStatus { Text(status) }
                    if sync.downloadingModel { Text("正在后台下载，可以继续使用播放器。") }
                    if sync.activeCount > 0 { Text("歌词匹配中，完成后可管理资源。") }
                }.font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }.padding(.horizontal, 2)
        }
        Color.clear.frame(height: 0)
            .onAppear { sync.refreshModels() }
            .alert("删除本地资源？", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
                Button("取消", role: .cancel) { pendingDeletion = nil }
                Button("删除", role: .destructive) {
                    if let resource = pendingDeletion { sync.deleteModel(resource) }
                    pendingDeletion = nil
                }
            } message: { Text("删除后，再次使用该匹配模式需要重新下载。已有歌词不受影响。") }
    }
}

private struct AudioSettingsPage: View {
    @EnvironmentObject private var systemVolume: SystemVolume
    var body: some View {
        SettingsGroup(title: "播放输出", footer: "此设置会更改 Mac 的默认输出设备，其他 App 的声音也会切换到所选设备。") {
            SettingsRow(title: "输出设备", detail: systemVolume.outputDevices.isEmpty ? "暂未发现可用设备" : "使用 Mac 系统音频输出") {
                Picker("输出设备", selection: Binding(get: { systemVolume.outputDeviceID }, set: { systemVolume.selectOutputDevice($0) })) {
                    ForEach(systemVolume.outputDevices) { Text($0.name).tag($0.id) }
                }.labelsHidden().frame(width: 240).disabled(systemVolume.outputDevices.isEmpty)
            }
        }
        if let error = systemVolume.error {
            Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ShortcutSettingsPage: View {
    @EnvironmentObject private var shortcuts: PlaybackShortcutController
    @EnvironmentObject private var windowToggle: WindowToggleController

    var body: some View {
        SettingsGroup(title: "播放控制", footer: "点击组合键后按下新快捷键，按 Esc 取消。在 MiniVoice 位于前台且未输入文字时生效。") {
            ForEach(PlaybackShortcutAction.allCases) { action in
                ShortcutRow(title: action.title, shortcut: shortcuts.shortcut(for: action), isRecording: shortcuts.recordingAction == action, conflicts: shortcuts.conflicts(for: shortcuts.shortcut(for: action), excluding: action)) {
                    shortcuts.beginRecording(action)
                } onReset: {
                    shortcuts.recordingAction = nil
                    shortcuts.reset(action)
                }
                if action.id != PlaybackShortcutAction.allCases.last?.id { Divider().padding(.horizontal, 16) }
            }
        }
        SettingsGroup(title: "窗口", footer: "全局快捷键可在任何应用下唤起 MiniVoice 主窗口。无需额外权限。") {
            ShortcutRow(
                title: "显示 / 隐藏主窗口",
                shortcut: windowToggle.configuredShortcut,
                isRecording: windowToggle.recording,
                conflicts: windowToggle.conflicts(),
                showsRecordingHint: false,
                onTap: { windowToggle.beginRecording() },
                onReset: { windowToggle.resetToDefault() }
            )
        }
        Color.clear.frame(height: 0).onDisappear {
            shortcuts.recordingAction = nil
            windowToggle.cancelRecording()
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: PlaybackShortcut
    let isRecording: Bool
    let conflicts: [String]
    var showsRecordingHint: Bool = true
    let onTap: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            SettingsRow(title: title) {
                Button(action: onTap) {
                    Text(displayText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced)).frame(width: 112)
                        .foregroundStyle(isRecording ? Color.accentColor : Color.primary)
                }.accessibilityLabel("\(title)：\(displayText)")
                Button("恢复默认", action: onReset)
            }
            if !conflicts.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.system(size: 12))
                    Text("与 \(conflicts.joined(separator: "、")) 冲突")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.bottom, 10).padding(.top, -2)
            }
        }
    }

    private var displayText: String {
        if isRecording, showsRecordingHint { return "按下快捷键…" }
        return shortcut.description
    }
}
