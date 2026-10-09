import XCTest
@testable import MiniVoice

final class PreferencesMigrationTests: XCTestCase {
    func testCopiesFoldersPlaybackShortcutsAndNativeWindowSettingsWithoutRemovingSource() throws {
        let target = "MiniVoiceMigration-\(UUID())"
        let source = "\(target)-legacy"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: target))
        defer {
            defaults.removePersistentDomain(forName: target)
            defaults.removePersistentDomain(forName: source)
        }
        let shortcut = Data([1, 2, 3])
        defaults.setPersistentDomain([
            "MiniVoice.musicFolders": ["/test/music"],
            "MiniVoice.lastPlaybackTime": 57.5,
            "MiniVoice.desktopLyrics": false,
            "MiniVoice.playbackShortcut.next": shortcut,
            "NSWindow Frame MiniVoice.MainPlayerWindow": "100 100 800 600"
        ], forName: source)

        XCTAssertEqual(PreferencesMigration.migrate(defaults: defaults, targetDomain: target, legacyDomains: [source]), 5)
        XCTAssertEqual(defaults.stringArray(forKey: "MiniVoice.musicFolders"), ["/test/music"])
        XCTAssertEqual(defaults.double(forKey: "MiniVoice.lastPlaybackTime"), 57.5)
        XCTAssertEqual(defaults.object(forKey: "MiniVoice.desktopLyrics") as? Bool, false)
        XCTAssertEqual(defaults.data(forKey: "MiniVoice.playbackShortcut.next"), shortcut)
        XCTAssertEqual(defaults.string(forKey: "NSWindow Frame MiniVoice.MainPlayerWindow"), "100 100 800 600")
        XCTAssertEqual(defaults.persistentDomain(forName: source)?.count, 5)
    }

    func testDestinationWinsAndLatestLegacyDomainHasPriority() throws {
        let target = "MiniVoiceMigration-\(UUID())"
        let sources = ["\(target)-recent", "\(target)-oldest"]
        let defaults = try XCTUnwrap(UserDefaults(suiteName: target))
        defer { for name in [target] + sources { defaults.removePersistentDomain(forName: name) } }
        defaults.setPersistentDomain(["MiniVoice.appearance": "light"], forName: target)
        defaults.setPersistentDomain(["MiniVoice.appearance": "dark", "MiniVoice.playbackMode": "shuffle"], forName: sources[0])
        defaults.setPersistentDomain(["MiniVoice.playbackMode": "list", "MiniVoice.followLyrics": false], forName: sources[1])
        XCTAssertEqual(PreferencesMigration.migrate(defaults: defaults, targetDomain: target, legacyDomains: sources), 2)
        XCTAssertEqual(defaults.string(forKey: "MiniVoice.appearance"), "light")
        XCTAssertEqual(defaults.string(forKey: "MiniVoice.playbackMode"), "shuffle")
        XCTAssertFalse(defaults.bool(forKey: "MiniVoice.followLyrics"))
    }

    func testSecondLaunchDoesNotRestoreASettingUserResetAfterMigration() throws {
        let target = "MiniVoiceMigration-\(UUID())"
        let source = "\(target)-legacy"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: target))
        defer {
            defaults.removePersistentDomain(forName: target)
            defaults.removePersistentDomain(forName: source)
        }
        defaults.setPersistentDomain(["MiniVoice.appearance": "dark"], forName: source)
        PreferencesMigration.migrate(defaults: defaults, targetDomain: target, legacyDomains: [source])
        defaults.removeObject(forKey: "MiniVoice.appearance")
        XCTAssertEqual(PreferencesMigration.migrate(defaults: defaults, targetDomain: target, legacyDomains: [source]), 0)
        XCTAssertNil(defaults.object(forKey: "MiniVoice.appearance"))
    }
}
