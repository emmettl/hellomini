// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "HelloMini",
  platforms: [.macOS(.v26)],
  products: [.executable(name: "HelloMini", targets: ["HelloMini"])],
  targets: [
    .target(name: "MiniCore"),
    .target(name: "MiniAquaTheme", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniSystem7Theme", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniScreensaver", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniToasters", dependencies: ["MiniCore", "MiniUI", "MiniScreensaver"]),
    .target(name: "MiniUI", dependencies: ["MiniCore"], resources: [.copy("Resources")]),
    .target(name: "MiniDesktop", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniFinder", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniAbout", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniActivityMonitor", dependencies: ["MiniCore", "MiniUI"]),
    .target(
      name: "MiniAquarium", dependencies: ["MiniCore", "MiniUI"], resources: [.copy("Resources")]),
    .target(
      name: "MiniTeapot", dependencies: ["MiniCore", "MiniUI"], resources: [.copy("Resources")]),
    .target(name: "MiniClock", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniScrapbook", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniCalculator", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniPuzzle", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniStorage"),
    .target(name: "MiniDiskFirstAid", dependencies: ["MiniCore", "MiniUI", "MiniStorage"]),
    .target(name: "MiniWastebasket", dependencies: ["MiniCore", "MiniUI", "MiniStorage"]),
    .target(name: "MiniChooser", dependencies: ["MiniCore", "MiniUI"]),
    .target(name: "MiniBuildCore"),
    .target(name: "MiniGitHubCI", dependencies: ["MiniBuildCore"]),
    .target(name: "MiniGitLabCI", dependencies: ["MiniBuildCore"]),
    .target(
      name: "MiniPrintMonitor",
      dependencies: ["MiniCore", "MiniUI", "MiniBuildCore", "MiniGitHubCI", "MiniGitLabCI"]),
    .target(name: "MiniControlPanel", dependencies: ["MiniCore", "MiniUI"]),
    .executableTarget(
      name: "HelloMini",
      dependencies: [
        "MiniDesktop", "MiniFinder", "MiniAbout", "MiniActivityMonitor", "MiniClock",
        "MiniControlPanel", "MiniUI", "MiniTeapot", "MiniAquarium", "MiniScrapbook",
        "MiniCalculator", "MiniPuzzle", "MiniChooser", "MiniDiskFirstAid", "MiniWastebasket",
        "MiniPrintMonitor", "MiniScreensaver", "MiniToasters", "MiniSystem7Theme", "MiniAquaTheme",
      ]),
    .testTarget(name: "MiniUITests", dependencies: ["MiniUI"], resources: [.process("Resources")]),
    .testTarget(name: "MiniTeapotTests", dependencies: ["MiniTeapot"]),
    .testTarget(name: "MiniAquariumTests", dependencies: ["MiniAquarium"]),
    .testTarget(name: "MiniScrapbookTests", dependencies: ["MiniScrapbook"]),
    .testTarget(name: "MiniCalculatorTests", dependencies: ["MiniCalculator"]),
    .testTarget(name: "MiniClockTests", dependencies: ["MiniClock"]),
    .testTarget(name: "MiniPuzzleTests", dependencies: ["MiniPuzzle"]),
    .testTarget(
      name: "MiniPrintMonitorTests",
      dependencies: ["MiniPrintMonitor", "MiniAquarium", "MiniGitHubCI", "MiniBuildCore"]),
    .testTarget(
      name: "MiniUtilityTests",
      dependencies: ["MiniStorage", "MiniChooser", "MiniBuildCore", "MiniGitHubCI", "MiniGitLabCI"]),
    .testTarget(name: "MiniAquaThemeTests", dependencies: ["MiniAquaTheme", "MiniUI", "MiniCore"]),
    .testTarget(
      name: "MiniSystem7ThemeTests", dependencies: ["MiniSystem7Theme", "MiniUI", "MiniCore"]),
    .testTarget(name: "MiniCoreTests", dependencies: ["MiniCore"]),
    .testTarget(name: "MiniDesktopTests", dependencies: ["MiniDesktop"]),
    .testTarget(name: "MiniFinderTests", dependencies: ["MiniFinder"]),
    .testTarget(name: "MiniActivityMonitorTests", dependencies: ["MiniActivityMonitor"]),
  ]
)
