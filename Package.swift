// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Fala",
    defaultLocalization: "pt-BR",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.15.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "2.29.1"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.7.9"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.4"),
    ],
    targets: [
        // All testable business logic lives here.
        .target(
            name: "FalaCore",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/FalaCore",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        // Thin executable shell: only main.swift + linker-embedded Info.plist.
        .executableTarget(
            name: "Fala",
            dependencies: ["FalaCore"],
            path: "Sources/Fala",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Fala/Resources/Info.plist",
                ])
            ]
        ),
        // Unit + integration tests.
        .testTarget(
            name: "FalaTests",
            dependencies: ["FalaCore"],
            path: "Tests/FalaTests"
        ),
    ]
)
