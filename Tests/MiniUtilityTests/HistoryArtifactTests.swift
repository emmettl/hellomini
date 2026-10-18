import Foundation
import MiniGitHubCI
import MiniGitLabCI
import Testing

@testable import MiniBuildCore

@Test func historyQueriesEncodeBranchesAndKeepSelfHostedOrigins() async throws {
  let branch = "feature/a&b#c"
  let github = GitHubProvider(
    server: try BuildServer("https://github.example:8443"),
    fetchData: { url, headers in
      #expect(url.host == "github.example" && url.port == 8443)
      #expect(url.path == "/api/v3/repos/owner/repo/actions/runs")
      let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
      #expect(query?.first(where: { $0.name == "branch" })?.value == branch)
      #expect(query?.first(where: { $0.name == "page" })?.value == "2")
      #expect(headers["Authorization"] == "Bearer example")
      return Data(#"{"workflow_runs":[]}"#.utf8)
    })
  let _ = try await github.history(project: "owner/repo", branch: branch, page: 2, token: "example")
  let gitlab = GitLabProvider(
    server: try BuildServer("https://gitlab.example"),
    fetchData: { url, headers in
      #expect(url.host == "gitlab.example")
      #expect(url.absoluteString.contains("group%2Fsub%2Frepo"))
      #expect(
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: {
          $0.name == "ref"
        })?.value == branch)
      #expect(headers["PRIVATE-TOKEN"] == "example")
      return Data("[]".utf8)
    })
  let _ = try await gitlab.history(
    project: "group/sub/repo", branch: branch, page: 2, token: "example")
  #expect(throws: BuildServiceError.self) { try BuildRunPage.validate(page: 51, branch: "") }
}
@Test func artifactsKeepExpiredEvidenceAndDeriveURLsRatherThanTrustingRemoteURLs() throws {
  let github = try GitHubProvider.decodeArtifacts(
    Data(
      #"{"artifacts":[{"id":5,"name":"Build","size_in_bytes":42,"expired":true,"archive_download_url":"https://evil.invalid"}]}"#
        .utf8))
  #expect(github.artifacts.first?.expired == true)
  let request = try GitHubProvider().artifactRequest(
    project: "owner/repo", artifactID: 5, token: "secret")
  #expect(
    request.url?.absoluteString == "https://api.github.com/repos/owner/repo/actions/artifacts/5/zip"
  )
  let gitlab = try GitLabProvider.decodeArtifacts(
    Data(
      #"[{"id":7,"name":"build","artifacts_file":{"filename":"artifacts.zip","size":42}},{"id":8,"name":"test"}]"#
        .utf8))
  #expect(gitlab.artifacts.map(\.id) == [7])
  var redirected = URLRequest(url: URL(string: "https://storage.example/zip?signature=example")!)
  redirected.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
  redirected.setValue("secret", forHTTPHeaderField: "PRIVATE-TOKEN")
  redirected.setValue("session", forHTTPHeaderField: "Cookie")
  let cleaned = ArtifactDownload.redirected(redirected, from: request.url)
  #expect(cleaned?.allHTTPHeaderFields?["Authorization"] == nil)
  #expect(cleaned?.allHTTPHeaderFields?["PRIVATE-TOKEN"] == nil)
  #expect(cleaned?.allHTTPHeaderFields?["Cookie"] == nil)
  #expect(cleaned?.url?.query == "signature=example")
  redirected.url = URL(string: "http://storage.example/zip")
  #expect(ArtifactDownload.redirected(redirected, from: request.url) == nil)
}
@Test func artifactCommitKeepsExistingFilesAndRejectsNonZipPayloads() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ArtifactCommit-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("incoming.zip")
  let destination = root.appendingPathComponent("saved.zip")
  try Data("HTML login page".utf8).write(to: source)
  #expect(throws: (any Error).self) { try ArtifactDownload.commitFile(source, to: destination) }
  #expect(!FileManager.default.fileExists(atPath: destination.path))
  let zip = Data([0x50, 0x4b, 0x05, 0x06] + [UInt8](repeating: 0, count: 18))
  try zip.write(to: source)
  try Data("keep".utf8).write(to: destination)
  #expect(throws: (any Error).self) { try ArtifactDownload.commitFile(source, to: destination) }
  #expect(try String(contentsOf: destination, encoding: .utf8) == "keep")
  let other = root.appendingPathComponent("other.zip")
  try ArtifactDownload.commitFile(source, to: other)
  #expect(try Data(contentsOf: other) == zip)
  #expect(try other.resourceValues(forKeys: [.quarantinePropertiesKey]).quarantineProperties != nil)
}
@Test(
  .enabled(if: ProcessInfo.processInfo.environment["HELLO_MINI_LIVE_GITHUB_TOKEN"] != nil),
  .timeLimit(.minutes(2)))
func liveGitHubHistoryAndArtifactDownload() async throws {
  let env = ProcessInfo.processInfo.environment
  let token = try #require(env["HELLO_MINI_LIVE_GITHUB_TOKEN"])
  let run = try #require(env["HELLO_MINI_LIVE_GITHUB_RUN"].flatMap(Int.init))
  let provider = GitHubProvider()
  let history = try await provider.history(
    project: "emmettl/hellomini", branch: "main", page: 1, token: token)
  #expect(!history.runs.isEmpty)
  let artifacts = try await provider.artifacts(
    project: "emmettl/hellomini", runID: run, page: 1, token: token)
  let artifact = try #require(artifacts.artifacts.first(where: { !$0.expired }))
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("LiveArtifact-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let destination = root.appendingPathComponent("artifact.zip")
  try await ArtifactDownload().download(
    provider.artifactRequest(project: "emmettl/hellomini", artifactID: artifact.id, token: token),
    to: destination
  ) { _, _ in }
  #expect(try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 > 0)
}
