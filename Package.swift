// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebWrap",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "WebWrap", targets: ["WebWrap"]),
        .executable(name: "WebWrapRuntime", targets: ["WebWrapRuntime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
    ],
    targets: [
        .executableTarget(
            name: "WebWrap",
            dependencies: ["SwiftSoup"],
            path: "Sources/WebWrap"
        ),
        .executableTarget(
            name: "WebWrapRuntime",
            path: "Sources/WebWrapRuntime"
        ),
        .testTarget(
            name: "WebWrapTests",
            dependencies: ["WebWrap"],
            path: "Tests/WebWrapTests"
        ),
    ]
)
