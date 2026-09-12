import Foundation
import MiniBuildCore

public struct GitLabProvider: BuildProvider {
  public let server: BuildServer
  let fetchData: @Sendable (URL, [String: String]) async throws -> Data
  public init(
    server: BuildServer = .gitlab,
    fetchData: @escaping @Sendable (URL, [String: String]) async throws -> Data = {
      try await BuildHTTP.data(url: $0, headers: $1)
    }
  ) {
    self.server = server
    self.fetchData = fetchData
  }
  public func runs(project: String, token: String?) async throws -> [BuildRun] {
    let project = try BuildHTTP.validateProject(project, github: false)
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    let url = URL(string: "\(server.gitlabAPI)/projects/\(encoded)/pipelines?per_page=20")!
    var headers = ["Accept": "application/json"]
    if let token, !token.isEmpty { headers["PRIVATE-TOKEN"] = token }
    return try Self.decode(
      await fetchData(url, headers), project: project, server: server)
  }
  public static func decode(_ data: Data, project: String, server: BuildServer = .gitlab) throws
    -> [BuildRun]
  {
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
        url: URL(string: "\(server.website)/\(project)/-/pipelines/\(run.id)")!,
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
