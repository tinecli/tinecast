// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TinecastKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "TinecastKit", targets: ["TinecastKit"]),
    ],
    targets: [
        .target(name: "TinecastKit"),
        .testTarget(name: "TinecastKitTests", dependencies: ["TinecastKit"]),
    ],
    swiftLanguageModes: [.v6]
)
