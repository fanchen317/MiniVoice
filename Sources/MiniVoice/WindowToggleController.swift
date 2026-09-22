import AppKit
import Carbon.HIToolbox

/// Owns a single system-wide hotkey that shows / hides the main window.
/// Uses Carbon's `RegisterEventHotKey` (the same approach WeChat uses on macOS),
/// which does NOT require Accessibility permission and properly "owns" the
/// chord so other apps don't also receive the keystroke.
@MainActor
final class WindowToggleController: ObservableObject {
    @Published private(set) var configuredShortcut: PlaybackShortcut
    @Published private(set) var hasRegistrationConflict: Bool = false
    @Published var recording: Bool = false
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var eventHandler: EventHandlerRef?
    private nonisolated(unsafe) var localMonitor: Any?
    private static let signature: OSType = OSType(0x4D564348) // 'MVCH'

    static let preferenceKey = "MiniVoice.toggleWindowShortcut"
    static let defaultShortcut = PlaybackShortcut(keyCode: 4, modifiers: [.command, .option])

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.preferenceKey),
           let saved = try? JSONDecoder().decode(PlaybackShortcut.self, from: data) {
            self.configuredShortcut = saved
        } else {
            self.configuredShortcut = Self.defaultShortcut
        }
        installEventHandler()
        registerCurrent()
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }

    func beginRecording() {
        recording = true
        // Drop the Carbon registration so the next captured chord isn't eaten by us.
        unregister()
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleLocal(event) ?? event
            }
        }
    }

    func cancelRecording() {
        recording = false
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        localMonitor = nil
        // Restore the previous registration so the user isn't left without a hotkey.
        registerCurrent()
    }

    func resetToDefault() { save(Self.defaultShortcut) }

    private func save(_ shortcut: PlaybackShortcut) {
        configuredShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.preferenceKey)
        }
        recording = false
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        localMonitor = nil
        objectWillChange.send()
        registerCurrent()
    }

    private func handleLocal(_ event: NSEvent) -> NSEvent? {
        guard recording else { return event }
        if event.keyCode == 53 { cancelRecording(); return nil }
        save(PlaybackShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags))
        return nil
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let controller = Unmanaged<WindowToggleController>.fromOpaque(userData).takeUnretainedValue()
                controller.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        if status != noErr { eventHandler = nil }
    }

    private func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
    }

    private func registerCurrent() {
        unregister()
        hasRegistrationConflict = false
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        let modifiers = Self.carbonModifiers(from: configuredShortcut.modifierFlags)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(configuredShortcut.keyCode),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKeyRef = ref
        // eventHotKeyExistsErr means another app owns this chord already.
        // Surface it as a soft conflict - the keystroke will still go to the
        // owning app, so the user should pick a different shortcut.
        if status != noErr || ref == nil {
            hasRegistrationConflict = true
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    fileprivate func handleHotkey() {
        guard !recording else { return }
        toggleMainWindow()
    }

    private func toggleMainWindow() {
        let main = NSApp.windows.first(where: { $0.identifier?.rawValue == "MiniVoice.main" })
        if let main, main.isVisible, !main.isMiniaturized {
            main.orderOut(nil)
        } else if let main {
            if main.isMiniaturized { main.deminiaturize(nil) }
            main.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            AppDelegate.reopenMainWindow?()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private extension PlaybackShortcut {
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }
}

extension WindowToggleController {
    /// Conflicts this shortcut would have, formatted for the settings UI.
    /// Combines known macOS system shortcuts with the live Carbon registration result.
    func conflicts() -> [String] {
        var result: [String] = []
        if let label = PlaybackShortcutSystemConflict.label(for: configuredShortcut) {
            result.append(label)
        }
        if hasRegistrationConflict {
            result.append("其他应用已占用此组合键")
        }
        return result
    }
}