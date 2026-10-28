import AppKit

/// The Swift executable is an internal service, never a second player app.
/// Main-window startup, menus and lifecycle belong to the MiniVoice shell.
@main
struct MiniVoiceEntry {
    @MainActor static func main() {
        guard CommandLine.arguments.contains("--desktop-engine") else {
            print("MiniVoice 原生服务由主应用启动。请运行 Scripts/build/build-app.sh，再打开 .build/dist/MiniVoice.app。")
            return
        }
        if ProcessInfo.processInfo.environment["MINIVOICE_ENGINE_TEST_DOMAIN"] == nil {
            PreferencesMigration.runIfNeeded()
        }
        DesktopEngine.run()
    }
}
