import AppKit
import SwiftUI

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
    static var reopenMainWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // A floating lyrics panel also counts as a visible window. Look for the
        // actual player instead of relying on AppKit's hasVisibleWindows flag.
        if let main = sender.windows.first(where: {
            $0.identifier?.rawValue == "MiniVoice.main" && ($0.isVisible || $0.isMiniaturized)
        }) {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
        } else {
            Self.reopenMainWindow?()
        }
        sender.activate(ignoringOtherApps: true)
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppearance()
        NotificationCenter.default.addObserver(self, selector: #selector(applyAppearance), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func applyAppearance() {
        let preference = AppAppearance(rawValue: UserDefaults.standard.string(forKey: "MiniVoice.appearance") ?? "system") ?? .system
        let appearance: NSAppearance?
        switch preference {
        case .system: appearance = nil
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        }
        if NSApp.appearance?.name != appearance?.name { NSApp.appearance = appearance }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

struct WindowCloseObserver: NSViewRepresentable {
    let library: MusicLibrary
    func makeNSView(context: Context) -> CloseView { CloseView(library: library) }
    func updateNSView(_ nsView: CloseView, context: Context) {}

    final class CloseView: NSView {
        let library: MusicLibrary
        private static let frameName = "MiniVoice.MainPlayerWindow"
        private weak var configuredWindow: NSWindow?
        private let placement = WindowPlacementStore(key: "MiniVoice.mainWindowFrame")
        private var restoringFrame = false
        init(library: MusicLibrary) { self.library = library; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError() }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                guard configuredWindow !== window else { return }
                NotificationCenter.default.removeObserver(self)
                configuredWindow = window
                window.identifier = NSUserInterfaceItemIdentifier("MiniVoice.main")
                // Keep the content pane opaque; only the sidebar's behind-window
                // material samples the desktop and windows beneath it.
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.windowController?.shouldCascadeWindows = false
                // Read before SwiftUI's initial layout can emit move/resize events.
                var savedFrame = placement.load()
                if savedFrame == nil,
                   let legacy = UserDefaults.standard.string(forKey: "NSWindow Frame \(Self.frameName)") {
                    window.setFrame(from: legacy)
                    savedFrame = window.frame
                }
                restoringFrame = true
                if let savedFrame { restore(savedFrame, in: window) }
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self, let window, self.configuredWindow === window else { return }
                    if let savedFrame { self.restore(savedFrame, in: window) }
                    self.restoringFrame = false
                    self.saveFrame()
                }
                let center = NotificationCenter.default
                center.addObserver(self, selector: #selector(closing), name: NSWindow.willCloseNotification, object: window)
                center.addObserver(self, selector: #selector(saveFrame), name: NSWindow.didMoveNotification, object: window)
                center.addObserver(self, selector: #selector(saveFrame), name: NSWindow.didResizeNotification, object: window)
                center.addObserver(self, selector: #selector(saveFrame), name: NSApplication.willTerminateNotification, object: nil)
            }
        }
        private func restore(_ frame: NSRect, in window: NSWindow) {
            let restored = WindowPlacementStore.visibleFrame(frame, screens: NSScreen.screens.map(\.visibleFrame))
            window.setFrame(restored, display: false)
        }
        @objc private func saveFrame() {
            guard !restoringFrame, let window = configuredWindow,
                  !window.styleMask.contains(.fullScreen), !window.isMiniaturized else { return }
            placement.save(window.frame)
        }
        @objc private func closing() {
            saveFrame()
            let behavior = CloseBehavior(rawValue: UserDefaults.standard.string(forKey: "MiniVoice.closeBehavior") ?? "background") ?? .background
            switch behavior {
            case .background: break
            case .pause: library.pause()
            case .quit: NSApp.terminate(nil)
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
