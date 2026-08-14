// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "DSHIsland",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .library(name: "DSHIslandCore", targets: ["DSHIslandCore"]),
    .executable(name: "dsh-island", targets: ["DSHIslandApp"]),
  ],
  targets: [
    .target(name: "DSHIslandCore"),
    .executableTarget(
      name: "DSHIslandApp",
      dependencies: ["DSHIslandCore"]
    ),
    .testTarget(
      name: "DSHIslandCoreTests",
      dependencies: ["DSHIslandCore"]
    ),
  ],
  swiftLanguageModes: [.v5]
)
