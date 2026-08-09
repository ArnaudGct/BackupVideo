// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BackupVideo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BackupVideo", targets: ["BackupVideo"])
    ],
    targets: [
        .executableTarget(
            name: "BackupVideo",
            path: ".",
            exclude: [
                "README.md",
                "build_and_run.sh"
            ],
            sources: [
                "Models",
                "Services",
                "ViewModels",
                "Views",
                "BackupVideoApp.swift"
            ]
        )
    ]
)
