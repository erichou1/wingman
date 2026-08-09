// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Wingman",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "WingmanHistoryCore", targets: ["WingmanHistoryCore"]),
    .library(name: "WingmanCore", targets: ["WingmanCore"]),
    .executable(name: "wingman-history", targets: ["WingmanHistoryCLI"]),
    .executable(name: "wingman-history-selftest", targets: ["WingmanHistorySelfTest"]),
    .executable(name: "wingman-core-selftest", targets: ["WingmanCoreSelfTest"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/openclaw/imsg.git",
      revision: "be5b490531000000abc079e26512b23709e16d84"
    )
  ],
  targets: [
    .target(
      name: "WingmanCore",
      path: "App/Shared/WingmanCore"
    ),
    .target(
      name: "WingmanHistoryCore",
      dependencies: [
        .product(name: "IMsgCore", package: "imsg")
      ]
    ),
    .executableTarget(
      name: "WingmanHistoryCLI",
      dependencies: [
        "WingmanHistoryCore",
        .product(name: "IMsgCore", package: "imsg"),
      ]
    ),
    .executableTarget(
      name: "WingmanHistorySelfTest",
      dependencies: [
        "WingmanHistoryCore",
        .product(name: "IMsgCore", package: "imsg"),
      ]
    ),
    .executableTarget(
      name: "WingmanCoreSelfTest",
      dependencies: ["WingmanCore"],
      path: "Sources/WingmanCoreSelfTest"
    ),
  ]
)
