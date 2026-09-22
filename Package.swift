// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiniVoice",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MiniVoice", targets: ["MiniVoice"])],
    targets: [
        .executableTarget(
            name: "MiniVoice",
            path: "Sources/MiniVoice",
            resources: [.copy("Resources/align_lyrics.py")],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(name: "MiniVoiceTests", dependencies: ["MiniVoice"])
    ]
)
