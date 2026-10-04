// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nextpage",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.3.0"),
        .package(url: "https://github.com/stackotter/swift-cmark-gfm", from: "1.0.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/simonbs/Prettier.git", from: "0.2.1"),
    ],
    targets: []
)
