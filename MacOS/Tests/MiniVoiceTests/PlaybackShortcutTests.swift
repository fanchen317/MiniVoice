import AppKit
import XCTest
@testable import MiniVoice

final class PlaybackShortcutTests: XCTestCase {
    private func event(_ code: UInt16, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                        timestamp: 0, windowNumber: 0, context: nil,
                        characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!
    }

    func testArrowShortcutsIgnoreSystemFlags() {
        for action in [PlaybackShortcutAction.previousTrack, .nextTrack] {
            let shortcut = action.defaultShortcut
            XCTAssertTrue(shortcut.matches(event(shortcut.keyCode, [.command])))
            XCTAssertTrue(shortcut.matches(event(shortcut.keyCode, [.command, .numericPad, .function, .capsLock])))
            XCTAssertFalse(shortcut.matches(event(shortcut.keyCode, [.command, .shift])))
            XCTAssertFalse(shortcut.matches(event(shortcut.keyCode, [])))
        }
    }

    func testExistingRecordedShortcutsRemainCompatible() throws {
        let saved = try JSONDecoder().decode(PlaybackShortcut.self,
            from: Data(#"{"keyCode":124,"modifiers":11534336}"#.utf8))
        XCTAssertTrue(saved.matches(event(124, [.command])))
        XCTAssertEqual(saved, PlaybackShortcutAction.nextTrack.defaultShortcut)
        XCTAssertFalse(saved.matches(event(123, [.command])))
    }

    func testRecordingOnlyStoresChordModifiers() {
        let recorded = PlaybackShortcut(keyCode: 123, modifiers: [.command, .numericPad, .function, .capsLock])
        XCTAssertEqual(recorded.modifiers, NSEvent.ModifierFlags.command.rawValue)
    }
}
