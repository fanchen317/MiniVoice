// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiniVoice",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MiniVoice", targets: ["MiniVoice"])],
    dependencies: [.package(path: "../Shared/Core"), .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2")],
    targets: [
        .executableTarget(
            name: "MiniVoice",
            dependencies: [.product(name: "Yams", package: "Yams"), .product(name: "MiniVoiceShared", package: "Core")],
            path: "Sources/MiniVoice",
            exclude: ["Resources/__pycache__"],
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
