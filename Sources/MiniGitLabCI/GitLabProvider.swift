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
    }
    return try JSONDecoder().decode([Run].self, from: data).map { run in
      let state: BuildState
      switch run.status {
      case "success": state = .passed
      case "failed": state = .failed
      case "canceled": state = .cancelled
      case "skipped": state = .skipped
      case "running": state = .running
      case "created", "waiting_for_resource", "preparing", "pending", "scheduled": state = .queued
      case "manual": state = .waiting
      default: state = .unknown
      }
      return BuildRun(
        id: run.id, title: "Pipeline #\(run.id)", branch: run.ref, state: state,
        url: URL(string: "https://gitlab.com/\(project)/-/pipelines/\(run.id)")!)
    }
  }
}
