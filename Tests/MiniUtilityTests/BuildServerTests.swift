import Foundation
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import Testing

@Test func serverOriginsNormalizeAndRejectAmbiguousAddresses() throws {
  #expect(try BuildServer(" HTTPS://GITHUB.COM:443/ ") == .github)
  #expect(BuildServer.github.githubAPI == "https://api.github.com")
  let server = try BuildServer("https://ci.example.com:8443/")
  #expect(server.website == "https://ci.example.com:8443")
  #expect(server.githubAPI == "https://ci.example.com:8443/api/v3")
  #expect(server.gitlabAPI == "https://ci.example.com:8443/api/v4")
  #expect(try BuildServer("https://[::1]:8443").website == "https://[::1]:8443")
  for address in [
    "", "ci.example.com", "http://ci.example.com", "https://user:secret@ci.example.com",
    "https://ci.example.com/api/v4", "https://ci.example.com?token=secret",
    "https://ci.example.com#x", "https://ci.example.com:0", "https://ci.example.com:65536",
    "https://ci.example.com/../", "https://ci%2eexample.com",
    "https://ci.example.com\\@evil.example", "https://ci.\nexample.com",
  ] {
    #expect(throws: BuildServiceError.self) { try BuildServer(address) }
  }
}

@Test func redirectsCannotMoveTokensAcrossOrigins() {
  let origin = URL(string: "https://ci.example.com:8443/api/v4/projects/1")!
  #expect(
    BuildHTTP.allowsRedirect(
      from: origin, to: URL(string: "https://ci.example.com:8443/api/v4/projects/2")))
  #expect(
    BuildHTTP.allowsRedirect(
      from: URL(string: "https://ci.example.com/a"), to: URL(string: "https://ci.example.com:443/b")
    ))
  for address in [
    "https://evil.example:8443/a", "https://ci.example.com/a", "http://ci.example.com:8443/a",
    "https://user@ci.example.com:8443/a", "https://ci.example.com.evil.example:8443/a",
  ] {
    #expect(!BuildHTTP.allowsRedirect(from: origin, to: URL(string: address)))
  }
  #expect(!BuildHTTP.allowsRedirect(from: nil, to: origin))
}

private actor ServerRequests {
  var requests: [(URL, [String: String])] = []
  let runs: Data
  let jobs: Data
  init(runs: String, jobs: String) {
    self.runs = Data(runs.utf8)
    self.jobs = Data(jobs.utf8)
  }
  func data(_ url: URL, _ headers: [String: String]) -> Data {
    requests.append((url, headers))
    return url.path.hasSuffix("/jobs") ? jobs : runs
  }
}

@Test func customServersRouteRunsJobsLinksAndHeadersTogether() async throws {
  let server = try BuildServer("https://ci.example.com:8443")
  let github = ServerRequests(
    runs:
      #"{"workflow_runs":[{"id":1,"name":"CI","head_branch":"main","status":"completed","conclusion":"success","html_url":"https://evil.example"}]}"#,
    jobs:
      #"{"total_count":1,"jobs":[{"id":2,"name":"Tests","status":"completed","conclusion":"success","html_url":"https://evil.example"}]}"#
  )
  let hub = GitHubProvider(server: server) { await github.data($0, $1) }
  let runs = try await hub.runs(project: "Owner/App", token: "fixture-token")
  let jobs = try await hub.jobs(project: "Owner/App", runID: 1, page: 2, token: "fixture-token")
  #expect(runs.first?.url.absoluteString == "https://ci.example.com:8443/Owner/App/actions/runs/1")
  #expect(runs.first?.workflow == "CI")
  #expect(
    jobs.jobs.first?.url.absoluteString
      == "https://ci.example.com:8443/Owner/App/actions/runs/1/job/2")
  let requests = await github.requests
  #expect(
    requests.map { $0.0.absoluteString } == [
      "https://ci.example.com:8443/api/v3/repos/Owner/App/actions/runs?per_page=20",
      "https://ci.example.com:8443/api/v3/repos/Owner/App/actions/runs/1/jobs?filter=latest&per_page=100&page=2",
    ])
  #expect(
    requests.allSatisfy {
      $0.1["Authorization"] == "Bearer fixture-token" && $0.1["PRIVATE-TOKEN"] == nil
    })
  let gitlab = ServerRequests(
    runs: #"[{"id":1,"ref":"main","status":"success"}]"#,
    jobs: #"[{"id":2,"name":"Tests","status":"success"}]"#)
  let lab = GitLabProvider(server: server) { await gitlab.data($0, $1) }
  let pipelines = try await lab.runs(project: "group/sub/app", token: "fixture-token")
  let labJobs = try await lab.jobs(
    project: "group/sub/app", runID: 1, page: 1, token: "fixture-token")
  #expect(
    pipelines.first?.url.absoluteString == "https://ci.example.com:8443/group/sub/app/-/pipelines/1"
  )
  #expect(
    labJobs.jobs.first?.url.absoluteString == "https://ci.example.com:8443/group/sub/app/-/jobs/2")
  let labRequests = await gitlab.requests
  #expect(
    labRequests.map { $0.0.absoluteString } == [
      "https://ci.example.com:8443/api/v4/projects/group%2Fsub%2Fapp/pipelines?per_page=20",
      "https://ci.example.com:8443/api/v4/projects/group%2Fsub%2Fapp/pipelines/1/jobs?include_retried=false&per_page=100&page=1",
    ])
  #expect(
    labRequests.allSatisfy {
      $0.1["PRIVATE-TOKEN"] == "fixture-token" && $0.1["Authorization"] == nil
    })
}
