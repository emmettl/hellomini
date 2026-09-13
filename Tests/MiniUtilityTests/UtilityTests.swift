import Foundation
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import MiniStorage
import Testing

@testable import MiniChooser

@Test func cacheScanStaysInsideRootAndRejectsReplacements() async throws {
  let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    .appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let cache = root.appendingPathComponent("cache")
  try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
  try Data(repeating: 42, count: 8192).write(to: cache.appendingPathComponent("object"))
  try FileManager.default.createSymbolicLink(
    at: root.appendingPathComponent("outside"), withDestinationURL: root.deletingLastPathComponent()
  )
  try FileManager.default.createSymbolicLink(
    at: cache.appendingPathComponent("cycle"), withDestinationURL: root)
  let reader = StorageReader()
  let items = try await reader.caches(in: root)
  #expect(items.count == 1)
  let item = try #require(items.first)
  #expect(item.bytes >= 8192 && !item.partial)
  try await reader.validate(item)
  try FileManager.default.moveItem(at: cache, to: root.appendingPathComponent("moved"))
  try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
  do {
    try await reader.validate(item)
    Issue.record("Replaced cache accepted")
  } catch {}
  do {
    _ = try await reader.caches(in: root.appendingPathComponent("outside"))
    Issue.record("Symlink root accepted")
  } catch {}
}

@Test @MainActor func chooserOpensOnlyServiceURLs() {
  #expect(
    ChooserModel.connectionURL(host: "mini.local", port: 22, kind: .ssh)?.absoluteString
      == "ssh://mini.local:22")
  #expect(
    ChooserModel.connectionURL(host: "192.168.1.2", port: 5900, kind: .screen)?.scheme == "vnc")
  for host in [
    "", "ssh://mini.local", "user@host", "host/path", "host?command=bad", "host\n--argument",
  ] {
    #expect(ChooserModel.connectionURL(host: host, port: nil, kind: .ssh) == nil)
  }
  #expect(ChooserModel.connectionURL(host: "mini.local", port: 0, kind: .http) == nil)
}

@Test func buildProvidersValidatePathsAndNormalizeStates() throws {
  #expect(try BuildHTTP.validateProject("team/subgroup/app", github: false) == "team/subgroup/app")
  for path in ["https://github.com/a/b", "../app", "a//b", "a/b?token=x", "a/b#x", "a/b/c"] {
    #expect(throws: BuildServiceError.self) { try BuildHTTP.validateProject(path, github: true) }
  }
  let github = Data(
    #"{"workflow_runs":[{"id":1,"name":"Build","head_branch":"main","status":"completed","conclusion":"success","html_url":"https://evil.example"},{"id":2,"status":"in_progress"},{"id":3,"status":"completed","conclusion":"timed_out"},{"id":4,"status":"waiting"}]}"#
      .utf8)
  let runs = try GitHubProvider.decode(github, project: "owner/app")
  #expect(runs.map(\.state) == [.passed, .running, .failed, .waiting])
  #expect(runs.first?.url.absoluteString == "https://github.com/owner/app/actions/runs/1")
  let gitlab = Data(
    #"[{"id":1,"ref":"main","status":"success"},{"id":2,"ref":"main","status":"canceled"},{"id":3,"ref":"main","status":"manual"},{"id":4,"ref":"main","status":"pending"}]"#
      .utf8)
  let pipelines = try GitLabProvider.decode(gitlab, project: "team/group/app")
  #expect(pipelines.map(\.state) == [.passed, .cancelled, .waiting, .queued])
  #expect(pipelines.first?.url.absoluteString == "https://gitlab.com/team/group/app/-/pipelines/1")
  #expect(throws: (any Error).self) {
    try GitHubProvider.decode(Data("{}".utf8), project: "owner/app")
  }
}
