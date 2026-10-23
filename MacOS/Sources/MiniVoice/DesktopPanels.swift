import AppKit
import SwiftUI

/// The desktop shell keeps the original auxiliary windows and their complete
/// editing workflows. Only the main scrolling surface is rendered by Chromium.
@MainActor
final class DesktopPanels: NSObject, NSWindowDelegate {
    private let library: MusicLibrary
    private let lyricsSync: LyricsSyncCoordinator
    private let volume: SystemVolume
    private let shortcuts = PlaybackShortcutController()
    private let windowToggle = WindowToggleController()
    private let statusBar = StatusBarController()
    private var appearanceValue: String?
    private var settingsWindow: NSWindow?
    private var editorWindow: NSWindow?
    private var editorID: UUID?
    private var editorRequest = UUID()
    private let shell: (String) -> Void

    init(library: MusicLibrary, lyricsSync: LyricsSyncCoordinator, volume: SystemVolume,
         shell: @escaping (String) -> Void) {
        self.library = library; self.lyricsSync = lyricsSync; self.volume = volume; self.shell = shell
        super.init()
        shortcuts.connect(library: library)
        windowToggle.onToggle = { shell("toggleWindow") }
        statusBar.onQuit = { shell("quit") }
        statusBar.activatesNativeApp = false
        statusBar.start(library: library, openMainWindow: { shell("showWindow") })
    }

    private func prepare() {
        NSApp.setActivationPolicy(.accessory)
        guard NSApp.mainMenu == nil else { return }
        // NSTextField / NSTextView use the responder chain for native editing.
        let menu = NSMenu()
        let application = NSMenuItem(title: "MiniVoice", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "MiniVoice")
        let settings = applicationMenu.addItem(withTitle: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        applicationMenu.addItem(.separator())
        let quit = applicationMenu.addItem(withTitle: "退出 MiniVoice", action: #selector(quitShell), keyEquivalent: "q")
        quit.target = self
        application.submenu = applicationMenu; menu.addItem(application)
        let edit = NSMenuItem(title: "编辑", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "编辑")
        for (title, action, key) in [("撤销", "undo:", "z"), ("剪切", "cut:", "x"),
                                     ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            submenu.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        edit.submenu = submenu; menu.addItem(edit)
        let windows = NSMenuItem(title: "窗口", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windows.submenu = windowMenu; menu.addItem(windows)
        NSApp.mainMenu = menu; NSApp.windowsMenu = windowMenu
    }

    @objc private func openSettings() { showSettings() }
    @objc private func quitShell() { shell("quit") }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === settingsWindow else { return }
        shortcuts.recordingAction = nil
        if windowToggle.recording { windowToggle.cancelRecording() }
        shell("focusWindow")
    }

    func applyAppearance(_ value: String) {
        guard appearanceValue != value else { return }; appearanceValue = value
        NSApp.appearance = value == "dark" ? NSAppearance(named: .darkAqua) : value == "light" ? NSAppearance(named: .aqua) : nil
    }

    private func raise(_ window: NSWindow) {
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.attachedSheet?.makeKeyAndOrderFront(nil)
    }

    func configureWindowShortcut(_ shortcut: PlaybackShortcut) { windowToggle.configure(shortcut) }

    func showSettings() {
        prepare()
        if let window = settingsWindow { raise(window); return }
        let window = TextInputTabWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "设置"
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier("MiniVoice.desktop.settings")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 608)
        window.contentView = NSHostingView(rootView: AppSettings()
            .environmentObject(library).environmentObject(library.clock)
            .environmentObject(volume).environmentObject(lyricsSync)
            .environmentObject(shortcuts).environmentObject(windowToggle))
        settingsWindow = window
        window.center(); raise(window)
    }

    func showEditor(_ track: Track) {
        prepare()
        if editorID == track.id, let window = editorWindow { raise(window); return }
        // Keep an existing draft until the user explicitly saves or cancels it.
        if let window = editorWindow { raise(window); NSSound.beep(); return }
        let request = UUID(); editorRequest = request; editorID = track.id
        let window = TextInputTabWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 680),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "歌曲信息"
        window.identifier = NSUserInterfaceItemIdentifier("MiniVoice.desktop.editor")
        window.isReleasedWhenClosed = false
        editorWindow = window
        window.contentView = NSHostingView(rootView: VStack {
            Spacer()
            ProgressView("正在读取歌曲信息…")
            Spacer()
            HStack { Spacer(); Button("取消") { [weak self] in self?.closeEditor() }.keyboardShortcut(.cancelAction) }
        }.padding(20).frame(width: 620, height: 680).background(Color(nsColor: .windowBackgroundColor)))
        window.center(); raise(window)
        Task { [weak self] in
            guard let self else { return }
            guard let resolved = await library.resolveTrack(track.id, fullResolution: true) else {
                if editorRequest == request { closeEditor() }; return
            }
            guard editorRequest == request, editorWindow === window else { return }
            window.contentView = NSHostingView(rootView: MetadataEditor(track: resolved, onClose: { [weak self] in self?.closeEditor() })
                .environmentObject(library).environmentObject(lyricsSync))
        }
    }

    private func closeEditor() {
        editorRequest = UUID(); editorWindow?.close(); editorWindow = nil; editorID = nil
        shell("focusWindow")
    }
}

/// Auxiliary forms use Tab for editable text only, never for navigation or actions.
@MainActor
private final class TextInputTabWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, event.keyCode == 48,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
              attachedSheet == nil else { super.sendEvent(event); return }
        func inputs(in view: NSView) -> [NSView] {
            guard !view.isHiddenOrHasHiddenAncestor else { return [] }
            if let field = view as? NSTextField, field.isEditable, field.isEnabled { return [field] }
            if let text = view as? NSTextView, text.isEditable, !text.isFieldEditor { return [text] }
            return view.subviews.flatMap { inputs(in: $0) }
        }
        let fields = contentView.map { inputs(in: $0) } ?? []
        guard !fields.isEmpty else { makeFirstResponder(nil); return }
        let responder: NSView? = {
            if let editor = firstResponder as? NSTextView, editor.isFieldEditor {
                return editor.delegate as? NSView
            }
            return firstResponder as? NSView
        }()
        let backwards = event.modifierFlags.contains(.shift)
        let current = fields.firstIndex { $0 === responder }
        let index = current.map { ($0 + (backwards ? -1 : 1) + fields.count) % fields.count }
            ?? (backwards ? fields.count - 1 : 0)
        let field = fields[index]
        field.scrollToVisible(field.bounds)
        makeFirstResponder(field)
    }
}
