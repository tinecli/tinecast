// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TineCastKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "TineCastKit", targets: ["TineCastKit"]),
    ],
    targets: [
        .target(name: "TineCastKit"),
        .testTarget(name: "TineCastKitTests", dependencies: ["TineCastKit"]),
    ],
    swiftLanguageModes: [.v6]
)
