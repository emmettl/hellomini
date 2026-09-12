import Foundation
import MiniBuildCore

public struct GitHubProvider: BuildProvider {
  public init() {}
  public func runs(project: String, token: String?) async throws -> [BuildRun] {
    let project = try BuildHTTP.validateProject(project, github: true)
    let url = URL(string: "https://api.github.com/repos/\(project)/actions/runs?per_page=20")!
    var headers = ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
    if let token, !token.isEmpty { headers["Authorization"] = "Bearer " + token }
    return try Self.decode(await BuildHTTP.data(url: url, headers: headers), project: project)
  }
  public static func decode(_ data: Data, project: String) throws -> [BuildRun] {
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
        state: state, url: URL(string: "https://github.com/\(project)/actions/runs/\(run.id)")!,
        createdAt: BuildHTTP.date(run.createdAt))
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
