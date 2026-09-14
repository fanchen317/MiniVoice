import AppKit
import SwiftUI

enum PlaybackShortcutAction: String, CaseIterable, Identifiable {
    case togglePlayback, previousTrack, nextTrack

    var id: String { rawValue }
    var title: String {
        switch self {
        case .togglePlayback: return "播放 / 暂停"
        case .previousTrack: return "上一曲"
        case .nextTrack: return "下一曲"
        }
    }
    var defaultShortcut: PlaybackShortcut {
        switch self {
        case .togglePlayback: return PlaybackShortcut(keyCode: 49, modifiers: [])
        case .previousTrack: return PlaybackShortcut(keyCode: 123, modifiers: [.command])
        case .nextTrack: return PlaybackShortcut(keyCode: 124, modifiers: [.command])
        }
    }
}

struct PlaybackShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
    }

    var description: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        let prefix = [
            flags.contains(.control) ? "⌃" : "",
            flags.contains(.option) ? "⌥" : "",
            flags.contains(.shift) ? "⇧" : "",
            flags.contains(.command) ? "⌘" : ""
        ].joined()
        return prefix + Self.keyName(keyCode)
    }

    private static func keyName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "空格"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            return "按键 \(keyCode)"
        }
    }
}

@MainActor
final class PlaybackShortcutController: ObservableObject {
    @Published var recordingAction: PlaybackShortcutAction?
    private weak var library: MusicLibrary?
    // AppKit's monitor token is an untyped, non-Sendable object.  Its lifecycle is
    // confined to the main thread by NSEvent, including this controller's teardown.
    private nonisolated(unsafe) var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    func connect(library: MusicLibrary) { self.library = library }

    func shortcut(for action: PlaybackShortcutAction) -> PlaybackShortcut {
        let key = "MiniVoice.playbackShortcut.\(action.rawValue)"
        guard let data = UserDefaults.standard.data(forKey: key), let saved = try? JSONDecoder().decode(PlaybackShortcut.self, from: data) else {
            return action.defaultShortcut
        }
        return saved
    }

    func beginRecording(_ action: PlaybackShortcutAction) { recordingAction = action }
    func reset(_ action: PlaybackShortcutAction) { save(action.defaultShortcut, for: action) }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if let recordingAction {
            if event.keyCode == 53 { self.recordingAction = nil; return nil }
            save(PlaybackShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags), for: recordingAction)
            self.recordingAction = nil
            return nil
        }
        guard !isEditingText(), let action = PlaybackShortcutAction.allCases.first(where: { shortcut(for: $0).matches(event) }) else { return event }
        switch action {
        case .togglePlayback: library?.togglePlayback()
        case .previousTrack: library?.skip(-1)
        case .nextTrack: library?.skip(1)
        }
        return nil
    }

    private func save(_ shortcut: PlaybackShortcut, for action: PlaybackShortcutAction) {
        let key = "MiniVoice.playbackShortcut.\(action.rawValue)"
        if let data = try? JSONEncoder().encode(shortcut) { UserDefaults.standard.set(data, forKey: key) }
        objectWillChange.send()
    }

    private func isEditingText() -> Bool {
        var responder = NSApp.keyWindow?.firstResponder
        while let current = responder {
            if current is NSTextView || current is NSTextField { return true }
            responder = current.nextResponder
        }
        return false
    }
}

private extension PlaybackShortcut {
    func matches(_ event: NSEvent) -> Bool {
        keyCode == event.keyCode && modifiers == event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
    }
}
