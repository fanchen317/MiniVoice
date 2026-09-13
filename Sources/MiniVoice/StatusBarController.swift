import AppKit
import SwiftUI

enum StatusIconStyle: String, CaseIterable, Identifiable {
    case hidden, colored, monochrome
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hidden: return "隐藏（空）"
        case .colored: return "彩色图标"
        case .monochrome: return "纯色图标"
        }
    }
}

@MainActor
final class StatusBarController: NSObject, ObservableObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private weak var library: MusicLibrary?
    private var openMainWindow: (() -> Void)?
    private var observer: NSObjectProtocol?
    static let preferenceKey = "MiniVoice.statusIconStyle"
    var style: StatusIconStyle {
        StatusIconStyle(rawValue: UserDefaults.standard.string(forKey: Self.preferenceKey) ?? "colored") ?? .colored
    }

    func start(library: MusicLibrary, openMainWindow: @escaping () -> Void) {
        self.openMainWindow = openMainWindow
        guard observer == nil else { return }
        self.library = library
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    private func refresh() {
        if style == .hidden {
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
            return
        }
        if item == nil {
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let menu = NSMenu(); menu.delegate = self; item?.menu = menu
        }
        item?.button?.image = BrandIcon.image(size: 20, appIcon: false, monochrome: style == .monochrome)
        item?.button?.toolTip = "MiniVoice"
        item?.button?.setAccessibilityLabel("MiniVoice")
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector?) -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry); return entry
        }
        let title = add(library?.selectedTrack?.title ?? "MiniVoice", nil); title.isEnabled = false
        _ = add("打开 MiniVoice", #selector(showApp))
        let play = add(library?.isPlaying == true ? "暂停" : "播放", #selector(togglePlayback)); play.isEnabled = library?.selectedTrack != nil
        menu.addItem(.separator())
        let styleItem = add("状态栏图标样式", nil)
        let styles = NSMenu()
        for style in StatusIconStyle.allCases {
            let entry = NSMenuItem(title: style.title, action: #selector(changeStyle(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = style.rawValue; entry.state = self.style == style ? .on : .off
            styles.addItem(entry)
        }
        styleItem.submenu = styles
        menu.addItem(.separator())
        _ = add("退出 MiniVoice", #selector(quit))
    }

    @objc private func showApp() {
        openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func togglePlayback() { library?.togglePlayback() }
    @objc private func changeStyle(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: Self.preferenceKey)
        refresh()
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

struct AppearanceSettings: View {
    @AppStorage(StatusBarController.preferenceKey) private var style = StatusIconStyle.colored.rawValue
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("状态栏图标", selection: $style) {
                ForEach(StatusIconStyle.allCases) { item in Text(item.title).tag(item.rawValue) }
            }
            Text("彩色使用浅绿色 MV 音符；纯色自动适应系统明暗外观。隐藏后可在此重新开启。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(24).frame(width: 430)
    }
}
