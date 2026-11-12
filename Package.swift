// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NXBootModern",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "NXBootModern", targets: ["NXBootModern"])],
    targets: [
        .target(name: "NXBootKit", path: "NXBootKit", publicHeadersPath: ".",
                cSettings: [.headerSearchPath(".."), .define("NXBOOTMAC_BUILDING"),
                            .unsafeFlags(["-fobjc-arc"])],
                linkerSettings: [.linkedFramework("Foundation"), .linkedFramework("IOKit")]),
        .target(name: "ModernUSB", dependencies: ["NXBootKit"], path: "ModernUSB",
                publicHeadersPath: "include", cSettings: [.headerSearchPath(".."), .unsafeFlags(["-fobjc-arc"])],
                linkerSettings: [.linkedFramework("IOKit")]),
        .executableTarget(name: "NXBootModern", dependencies: ["ModernUSB"], path: "Modern"),
        .testTarget(name: "NXBootModernTests", dependencies: ["NXBootModern", "ModernUSB"],
                    path: "Tests/NXBootModernTests")
    ],
    swiftLanguageModes: [.v5]
)
