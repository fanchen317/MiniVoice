// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MiniVoiceShared",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MiniVoiceShared", targets: ["MiniVoiceShared"]), .executable(name: "SharedCoreCLI", targets: ["SharedCoreCLI"])],
    targets: [
        .target(name: "MiniVoiceCore", path: "Sources/MiniVoiceCore", sources: ["core.cpp", "vendor/utf8proc.c"], publicHeadersPath: "include", cSettings: [.define("UTF8PROC_STATIC")], cxxSettings: [.define("UTF8PROC_STATIC")]),
        .target(name: "MiniVoiceShared", dependencies: ["MiniVoiceCore"]),
        .executableTarget(name: "SharedCoreCLI", dependencies: ["MiniVoiceShared"], path: "Tools/CLI"),
        .testTarget(name: "MiniVoiceSharedTests", dependencies: ["MiniVoiceShared"], path: "Tests/Swift")
    ], cxxLanguageStandard: .cxx17)
