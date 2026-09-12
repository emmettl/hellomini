// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "HelloMini",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "HelloMini", targets: ["HelloMini"])],
  targets: [
    .target(name: "MiniCore"),
    .target(name: "MiniUI", dependencies: ["MiniCore"]),
    .target(name: "MiniDesktop", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniFinder", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniAbout", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniActivityMonitor", dependencies: ["MiniCore", "MiniUI"]),
    .target(
      name: "MiniTeapot", dependencies: ["MiniCore", "MiniUI"], resources: [.copy("Resources")]),
    .target(name: "MiniClock", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniControlPanel", dependencies: ["MiniCore", "MiniUI"]),
    .executableTarget(
      name: "HelloMini",
      dependencies: [
        "MiniDesktop", "MiniFinder", "MiniAbout", "MiniActivityMonitor", "MiniClock",
        "MiniControlPanel", "MiniUI", "MiniTeapot",
      ]),
    .testTarget(name: "MiniUITests", dependencies: ["MiniUI"], resources: [.process("Resources")]),
    .testTarget(name: "MiniTeapotTests", dependencies: ["MiniTeapot"]),
    .testTarget(name: "MiniCoreTests", dependencies: ["MiniCore"]),
    .testTarget(name: "MiniDesktopTests", dependencies: ["MiniDesktop"]),
    .testTarget(name: "MiniFinderTests", dependencies: ["MiniFinder"]),
    .testTarget(name: "MiniActivityMonitorTests", dependencies: ["MiniActivityMonitor"]),
  ]
)
