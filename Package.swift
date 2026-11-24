// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MindmapMarkdown",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MindmapMarkdown", path: "Sources/MindmapMarkdown")
    ]
)
