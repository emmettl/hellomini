import Foundation
import MiniBuildCore

extension GitLabProvider {
  public func history(project: String, branch: String, page: Int, token: String?) async throws
    -> BuildRunPage
  {
    let project = try BuildHTTP.validateProject(project, github: false)
    try BuildRunPage.validate(page: page, branch: branch)
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    var components = URLComponents(string: "\(server.gitlabAPI)/projects/\(encoded)/pipelines")!
    components.queryItems = [
      URLQueryItem(name: "per_page", value: "20"), URLQueryItem(name: "page", value: String(page)),
    ]
    if !branch.isEmpty { components.queryItems?.append(URLQueryItem(name: "ref", value: branch)) }
    let runs = try Self.decode(
      await fetchData(components.url!, Self.downloadHeaders(token)), project: project,
      server: server)
    return BuildRunPage(runs: Array(runs.prefix(20)), hasMore: runs.count >= 20)
  }
  public func artifacts(project: String, runID: Int, page: Int, token: String?) async throws
    -> BuildArtifactPage
  {
    let project = try BuildHTTP.validateProject(project, github: false)
    try BuildJobPage.validate(runID: runID, page: page)
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    let url = URL(
      string:
        "\(server.gitlabAPI)/projects/\(encoded)/pipelines/\(runID)/jobs?include_retried=true&per_page=100&page=\(page)"
    )!
    return try Self.decodeArtifacts(await fetchData(url, Self.downloadHeaders(token)))
  }
  public static func decodeArtifacts(_ data: Data) throws -> BuildArtifactPage {
    struct File: Decodable {
      let filename: String?
      let size: Int64?
    }
    struct Job: Decodable {
      let id: Int
      let name: String
      let artifactsFile: File?
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let entries = try decoder.decode([Job].self, from: data)
    return BuildArtifactPage(
      artifacts: entries.prefix(100).filter { $0.id > 0 && $0.artifactsFile?.filename != nil }.map {
        BuildArtifact(
          id: $0.id, name: String($0.name.prefix(200)), size: $0.artifactsFile?.size, expired: false
        )
      }, hasMore: entries.count >= 100)
  }
  public func artifactRequest(project: String, artifactID: Int, token: String?) throws -> URLRequest
  {
    let project = try BuildHTTP.validateProject(project, github: false)
    guard artifactID > 0 else { throw BuildServiceError("Invalid artifact identifier.") }
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    var request = URLRequest(
      url: URL(string: "\(server.gitlabAPI)/projects/\(encoded)/jobs/\(artifactID)/artifacts")!)
    for (key, value) in Self.downloadHeaders(token) {
      request.setValue(value, forHTTPHeaderField: key)
    }
    return request
  }
  private static func downloadHeaders(_ token: String?) -> [String: String] {
    var headers = ["Accept": "application/json"]
    if let token, !token.isEmpty { headers["PRIVATE-TOKEN"] = token }
    return headers
  }
}
