// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickyNote",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "StickyNote", targets: ["StickyNote"]),
               .executable(name: "DeleteStickyNote", targets: ["DeleteStickyNote"])],
    targets: [
        .target(name: "NoteCore"),
        .executableTarget(name: "StickyNote", dependencies: ["NoteCore"]),
        .executableTarget(name: "DeleteStickyNote"),
        .executableTarget(name: "NoteCoreChecks", dependencies: ["NoteCore"], path: "Tests/NoteCoreTests")
    ]
)
