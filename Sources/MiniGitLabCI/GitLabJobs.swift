import Foundation
import MiniBuildCore

extension GitLabProvider {
  public func jobs(project: String, runID: Int, page: Int, token: String?) async throws
    -> BuildJobPage
  {
    let project = try BuildHTTP.validateProject(project, github: false)
    try BuildJobPage.validate(runID: runID, page: page)
    let encoded = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    let url = URL(
      string:
        "https://gitlab.com/api/v4/projects/\(encoded)/pipelines/\(runID)/jobs?include_retried=false&per_page=100&page=\(page)"
    )!
    var headers = ["Accept": "application/json"]
    if let token, !token.isEmpty { headers["PRIVATE-TOKEN"] = token }
    return try Self.decodeJobs(await BuildHTTP.data(url: url, headers: headers), project: project)
  }

  public static func decodeJobs(_ data: Data, project: String) throws -> BuildJobPage {
    let project = try BuildHTTP.validateProject(project, github: false)
    struct Job: Decodable {
      let id: Int
      let name: String
      let status: String
      let stage: String?
      let startedAt: String?
      let finishedAt: String?
      let failureReason: String?
      let allowFailure: Bool?
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let response = try decoder.decode([Job].self, from: data)
    let jobs = response.prefix(BuildJobPage.pageSize).map { job in
      let result = state(job.status)
      return BuildJob(
        id: job.id, name: job.name, state: result,
        url: URL(string: "https://gitlab.com/\(project)/-/jobs/\(job.id)")!, stage: job.stage,
        startedAt: BuildHTTP.date(job.startedAt), finishedAt: BuildHTTP.date(job.finishedAt),
        failure: result == .failed
          ? job.failureReason.map {
            "GitLab reports: " + $0.replacingOccurrences(of: "_", with: " ")
          } ?? "No failure reason supplied. Open the job logs for details." : nil,
        allowsFailure: job.allowFailure ?? false)
    }
    // A full page may have a successor; an empty final page is harmless.
    return BuildJobPage(jobs: jobs, hasMore: response.count >= BuildJobPage.pageSize)
  }
}
