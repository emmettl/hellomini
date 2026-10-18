import Foundation
import MiniBuildCore

extension GitHubProvider {
  public func history(project: String, branch: String, page: Int, token: String?) async throws
    -> BuildRunPage
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    try BuildRunPage.validate(page: page, branch: branch)
    var components = URLComponents(string: "\(server.githubAPI)/repos/\(project)/actions/runs")!
    components.queryItems = [
      URLQueryItem(name: "per_page", value: "20"), URLQueryItem(name: "page", value: String(page)),
    ]
    if !branch.isEmpty {
      components.queryItems?.append(URLQueryItem(name: "branch", value: branch))
    }
    let runs = try Self.decode(
      await fetchData(components.url!, Self.downloadHeaders(token)), project: project,
      server: server)
    return BuildRunPage(runs: Array(runs.prefix(20)), hasMore: runs.count >= 20)
  }
  public func artifacts(project: String, runID: Int, page: Int, token: String?) async throws
    -> BuildArtifactPage
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    try BuildJobPage.validate(runID: runID, page: page)
    let url = URL(
      string:
        "\(server.githubAPI)/repos/\(project)/actions/runs/\(runID)/artifacts?per_page=100&page=\(page)"
    )!
    return try Self.decodeArtifacts(await fetchData(url, Self.downloadHeaders(token)))
  }
  public static func decodeArtifacts(_ data: Data) throws -> BuildArtifactPage {
    struct Artifact: Decodable {
      let id: Int
      let name: String
      let sizeInBytes: Int64?
      let expired: Bool
    }
    struct Response: Decodable { let artifacts: [Artifact] }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let entries = try decoder.decode(Response.self, from: data).artifacts
    return BuildArtifactPage(
      artifacts: entries.prefix(100).filter { $0.id > 0 }.map {
        BuildArtifact(
          id: $0.id, name: String($0.name.prefix(200)), size: $0.sizeInBytes, expired: $0.expired)
      }, hasMore: entries.count >= 100)
  }
  public func artifactRequest(project: String, artifactID: Int, token: String?) throws -> URLRequest
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    guard artifactID > 0 else { throw BuildServiceError("Invalid artifact identifier.") }
    var request = URLRequest(
      url: URL(string: "\(server.githubAPI)/repos/\(project)/actions/artifacts/\(artifactID)/zip")!)
    for (key, value) in Self.downloadHeaders(token) {
      request.setValue(value, forHTTPHeaderField: key)
    }
    return request
  }
  private static func downloadHeaders(_ token: String?) -> [String: String] {
    var headers = ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
    if let token, !token.isEmpty { headers["Authorization"] = "Bearer " + token }
    return headers
  }
}
