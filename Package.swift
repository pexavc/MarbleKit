// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MarbleKit",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "MarbleKit",
            targets: ["MarbleKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/pexavc/FFmpegKit.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "MarbleKit",
            dependencies: [.product(name: "FFmpegKit", package: "FFmpegKit")],
            resources: [.process("Engine/Core/WebGL/Shaders")]
        ),
        .testTarget(
            name: "MarbleKitTests",
            dependencies: ["MarbleKit"]),
    ]
)
