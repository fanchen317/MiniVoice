import SwiftUI

@main
struct MiniVoiceApp: App {
    @StateObject private var library = MusicLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .onOpenURL { library.importFiles([$0]) }
                .frame(minWidth: 980, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
