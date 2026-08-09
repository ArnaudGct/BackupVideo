// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoBackupMaster",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VideoBackupMaster", targets: ["VideoBackupMaster"])
    ],
    targets: [
        .executableTarget(
            name: "VideoBackupMaster",
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
                "VideoBackupMasterApp.swift"
            ]
        )
    ]
)
