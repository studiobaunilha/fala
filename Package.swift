// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sussurro",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.15.0"),
    ],
    targets: [
        // All testable business logic lives here.
        .target(
            name: "SussurroCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/SussurroCore"
        ),
        // Thin executable shell: only main.swift + linker-embedded Info.plist.
        .executableTarget(
            name: "Sussurro",
            dependencies: ["SussurroCore"],
            path: "Sources/Sussurro",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Sussurro/Resources/Info.plist",
                ])
            ]
        ),
        // Unit + integration tests.
        .testTarget(
            name: "SussurroTests",
            dependencies: ["SussurroCore"],
            path: "Tests/SussurroTests"
        ),
    ]
)
