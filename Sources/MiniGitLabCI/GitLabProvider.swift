import Foundation
import MiniBuildCore

public struct GitLabProvider: BuildProvider {
  public init() {}
  public func runs(project: String, token: String?) async throws -> [BuildRun] {
    let project = try BuildHTTP.validateProject(project, github: false)
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    let url = URL(string: "https://gitlab.com/api/v4/projects/\(encoded)/pipelines?per_page=20")!
    var headers = ["Accept": "application/json"]
    if let token, !token.isEmpty { headers["PRIVATE-TOKEN"] = token }
    return try Self.decode(await BuildHTTP.data(url: url, headers: headers), project: project)
  }
  public static func decode(_ data: Data, project: String) throws -> [BuildRun] {
    let project = try BuildHTTP.validateProject(project, github: false)
    struct Run: Decodable {
      let id: Int
      let status: String
      let ref: String
      let createdAt: String?
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode([Run].self, from: data).map { run in
      let state = Self.state(run.status)
      return BuildRun(
        id: run.id, title: "Pipeline #\(run.id)", branch: run.ref, state: state,
        url: URL(string: "https://gitlab.com/\(project)/-/pipelines/\(run.id)")!,
        createdAt: BuildHTTP.date(run.createdAt))
    }
  }
  static func state(_ value: String) -> BuildState {
    switch value {
    case "success": return .passed
    case "failed": return .failed
    case "canceled": return .cancelled
    case "skipped": return .skipped
    case "running", "canceling": return .running
    case "created", "waiting_for_resource", "preparing", "pending", "scheduled": return .queued
    case "manual", "waiting_for_callback": return .waiting
    default: return .unknown
    }
  }
}
