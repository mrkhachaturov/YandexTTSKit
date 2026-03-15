// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YandexTTSKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "YandexTTSKit", targets: ["YandexTTSKit"]),
    ],
    targets: [
        .target(name: "YandexTTSKit"),
        .testTarget(name: "YandexTTSKitTests", dependencies: ["YandexTTSKit"]),
    ]
)
