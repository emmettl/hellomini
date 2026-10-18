import AppKit
import MiniAquaTheme
import MiniBuildCore
import MiniCore
import MiniPlatinumTheme
import MiniSystem7Theme
import MiniUI
import SwiftUI
import Testing

@testable import MiniFinder
@testable import MiniNetwork
@testable import MiniPrintMonitor

@MainActor private final class LayoutEvidence {
  var frames: [String: CGRect] = [:]
}
@Test @MainActor func populatedFinderAndNetworkKeepPrimaryControlsReachable() async throws {
  let suite = "AccessibleLayout-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "LayoutFixture-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  try Data("Demonstration".utf8).write(
    to: root.appendingPathComponent("A very long demonstration file name.txt"))
  defaults.set(root.path, forKey: "finder.location")
  let settings = PlayfulnessSettings(defaults: defaults, effects: [])
  let finder = FinderModel(defaults: defaults)
  let network = NetworkModel()
  network.host = "a-very-long-demonstration-hostname.example.invalid"
  network.port = "65535"
  let views: [(AnyView, [String])] = [
    (AnyView(FinderView(model: finder, findFile: {})), ["finder.find", "finder.back"]),
    (
      AnyView(NetworkView(model: network, playfulness: settings)),
      ["network.call", "network.host", "network.port"]
    ),
  ]
  for theme in MiniThemeRegistry.builtIns.themes + [
    System7Theme.definition, PlatinumTheme.definition, AquaTheme.definition,
  ] {
    for size in [CGSize(width: 440, height: 240), CGSize(width: 496, height: 250)] {
      for (view, required) in views {
        let evidence = LayoutEvidence()
        let host = NSHostingView(
          rootView: view.environment(\.miniTheme, theme).environment(
            \.colorScheme, theme.colorScheme
          )
          .frame(width: size.width, height: size.height).coordinateSpace(
            name: "mini-control-layout"
          )
          .onPreferenceChange(MiniControlFrames.self) { evidence.frames = $0 })
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        host.layoutSubtreeIfNeeded()
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1)
        for id in required {
          let frame = try #require(evidence.frames[id], "Missing primary control \(id)")
          #expect(frame.width > 10 && frame.height > 10)
          #expect(
            bounds.contains(frame), "Clipped primary control \(id): \(frame) outside \(bounds)")
        }
      }
    }
  }
}

@Test @MainActor func archiveArtifactAndFileReviewFootersFitTinyScreenSheets() async throws {
  let suite = "SheetFrames-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let project = try CIProject(service: .github, path: "example/demonstration")
  let history = BuildHistoryModel(
    project: project,
    fetch: { _, _, _ in
      throw BuildServiceError(
        "An explanatory access error, without hiding the return-to-live action.")
    })
  let run = BuildRun(
    id: 1, title: "A very long demonstration workflow title", branch: "feature/long-name",
    state: .passed, url: URL(string: "https://example.invalid/run")!)
  let artifact = ArtifactListModel(build: ProjectBuild(project: project, run: run))
  artifact.busy = true
  artifact.artifacts = (1...20).map {
    BuildArtifact(id: $0, name: "A very long artifact name \($0)", size: 12345, expired: false)
  }
  let finder = FinderModel(defaults: defaults)
  let draft = FileOperationDraft(
    kind: .copy, source: URL(fileURLWithPath: "/tmp/Original.txt"),
    folder: URL(fileURLWithPath: "/tmp/Destination"), name: "Copy.txt")
  let views: [(AnyView, CGFloat, [String])] = [
    (AnyView(BuildHistoryView(model: history)), 480, ["history.search", "history.live"]),
    (AnyView(ArtifactListView(model: artifact)), 480, ["artifacts.done"]),
    (
      AnyView(FileOperationView(model: finder, draft: draft)), 400,
      ["files.cancel", "files.confirm"]
    ),
  ]
  for theme in [System7Theme.definition, AquaTheme.definition] {
    for (view, width, required) in views {
      let evidence = LayoutEvidence()
      let size = CGSize(width: width, height: 328)
      let host = NSHostingView(
        rootView: view.environment(\.miniTheme, theme).environment(\.colorScheme, theme.colorScheme)
          .frame(width: width, height: 328).coordinateSpace(name: "mini-control-layout")
          .onPreferenceChange(MiniControlFrames.self) { evidence.frames = $0 })
      host.frame = CGRect(origin: .zero, size: size)
      host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(100))
      host.layoutSubtreeIfNeeded()
      for id in required {
        let frame = try #require(evidence.frames[id], "Missing sheet action \(id)")
        #expect(
          CGRect(origin: .zero, size: size).insetBy(dx: -1, dy: -1).contains(frame),
          "Sheet action \(id) is outside the small-display viewport")
      }
    }
  }
}

@Test @MainActor func projectManagerActionsFitThePuristSheetWidth() async throws {
  let suite = "ProjectSheetFrames-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let model = ProjectQueue(defaults: defaults, observer: CompletionObserver(notify: { _ in }))
  try model.add(service: .github, path: "example/a-long-demonstration-project-name")
  let project = try #require(model.projects.first)
  for display in [
    MiniDisplayContext(scale: 1, logicalSize: CGSize(width: 512, height: 384)),
    MiniDisplayContext(scale: 2, logicalSize: CGSize(width: 640, height: 360)),
  ] {
    let width = min(550, display.logicalSize.width - 24)
    let evidence = LayoutEvidence()
    let host = NSHostingView(
      rootView: ProjectManager(model: model, added: {})
        .environment(\.miniDisplay, display)
        .frame(width: width).coordinateSpace(name: "mini-control-layout")
        .onPreferenceChange(MiniControlFrames.self) { evidence.frames = $0 })
    host.frame = CGRect(x: 0, y: 0, width: width, height: 600)
    host.layoutSubtreeIfNeeded()
    try await Task.sleep(for: .milliseconds(100))
    host.layoutSubtreeIfNeeded()
    for id in ["projects.add", "projects.done", "projects.remove." + project.id] {
      let frame = try #require(evidence.frames[id])
      #expect(frame.width > 10)
      #expect(
        frame.minX >= -1 && frame.maxX <= width + 1,
        "Project sheet action \(id) is clipped horizontally: \(frame)")
    }
  }
}
