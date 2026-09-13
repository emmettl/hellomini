import Foundation
import MiniBuildCore

public struct GitHubProvider: BuildProvider {
  public let server: BuildServer
  let fetchData: @Sendable (URL, [String: String]) async throws -> Data
  private let post: @Sendable (URL, [String: String]) async throws -> Void
  public init(
    server: BuildServer = .github,
    fetchData: @escaping @Sendable (URL, [String: String]) async throws -> Data = {
      try await BuildHTTP.data(url: $0, headers: $1)
    },
    post: @escaping @Sendable (URL, [String: String]) async throws -> Void = {
      try await BuildRetryHTTP.post(url: $0, headers: $1)
    }
  ) {
    self.server = server
    self.post = post
    self.fetchData = fetchData
  }
  public func retryFailed(project: String, runID: Int, token: String) async throws {
    guard runID > 0, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw BuildServiceError("A valid run and a token with write access are required.")
    }
    let project = try BuildHTTP.validateProject(project, github: true)
    let url = URL(
      string: "\(server.githubAPI)/repos/\(project)/actions/runs/\(runID)/rerun-failed-jobs")!
    try await post(
      url,
      [
        "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
        "Authorization": "Bearer " + token,
      ])
  }
  public func runs(project: String, token: String?) async throws -> [BuildRun] {
    let project = try BuildHTTP.validateProject(project, github: true)
    let url = URL(string: "\(server.githubAPI)/repos/\(project)/actions/runs?per_page=20")!
    var headers = ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
    if let token, !token.isEmpty { headers["Authorization"] = "Bearer " + token }
    return try Self.decode(
      await fetchData(url, headers), project: project, server: server)
  }
  public static func decode(_ data: Data, project: String, server: BuildServer = .github) throws
    -> [BuildRun]
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    struct Run: Decodable {
      let id: Int
      let name: String?
      let headBranch: String?
      let status: String
      let conclusion: String?
      let createdAt: String?
    }
    struct Response: Decodable { let workflowRuns: [Run] }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(Response.self, from: data).workflowRuns.map { run in
      let state = Self.state(run.conclusion ?? run.status)
      return BuildRun(
        id: run.id, title: run.name ?? "Workflow #\(run.id)", branch: run.headBranch ?? "—",
        state: state, url: URL(string: "\(server.website)/\(project)/actions/runs/\(run.id)")!,
        createdAt: BuildHTTP.date(run.createdAt), workflow: run.name)
    }
  }
  static func state(_ value: String) -> BuildState {
    switch value {
    case "success": return .passed
    case "failure", "timed_out", "startup_failure", "action_required": return .failed
    case "cancelled": return .cancelled
    case "skipped", "neutral": return .skipped
    case "in_progress": return .running
    case "queued", "requested", "pending": return .queued
    case "waiting": return .waiting
    default: return .unknown
    }
  }
}
