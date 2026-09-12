import Foundation
import MiniBuildCore

extension GitHubProvider {
  public func jobs(project: String, runID: Int, page: Int, token: String?) async throws
    -> BuildJobPage
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    try BuildJobPage.validate(runID: runID, page: page)
    let url = URL(
      string:
        "\(server.githubAPI)/repos/\(project)/actions/runs/\(runID)/jobs?filter=latest&per_page=100&page=\(page)"
    )!
    var headers = ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
    if let token, !token.isEmpty { headers["Authorization"] = "Bearer " + token }
    return try Self.decodeJobs(
      await fetchData(url, headers), project: project, runID: runID, page: page,
      server: server)
  }

  public static func decodeJobs(
    _ data: Data, project: String, runID: Int, page: Int = 1, server: BuildServer = .github
  ) throws
    -> BuildJobPage
  {
    let project = try BuildHTTP.validateProject(project, github: true)
    try BuildJobPage.validate(runID: runID, page: page)
    struct Step: Decodable {
      let number: Int
      let name: String
      let status: String
      let conclusion: String?
    }
    struct Job: Decodable {
      let id: Int
      let name: String
      let status: String
      let conclusion: String?
      let startedAt: String?
      let completedAt: String?
      let steps: [Step]?
    }
    struct Response: Decodable {
      let totalCount: Int
      let jobs: [Job]
    }
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let response = try decoder.decode(Response.self, from: data)
    let jobs = response.jobs.prefix(BuildJobPage.pageSize).map { job in
      let steps = (job.steps ?? []).map {
        BuildStep(id: $0.number, name: $0.name, state: state($0.conclusion ?? $0.status))
      }
      let result = state(job.conclusion ?? job.status)
      let failedSteps = steps.filter { $0.state == .failed }.map(\.name)
      let failure: String? =
        result == .failed
        ? (failedSteps.isEmpty
          ? "GitHub reported \(job.conclusion ?? job.status). Open the job logs for details."
          : "Failed steps: " + failedSteps.joined(separator: ", ")) : nil
      return BuildJob(
        id: job.id, name: job.name, state: result,
        url: URL(string: "\(server.website)/\(project)/actions/runs/\(runID)/job/\(job.id)")!,
        startedAt: BuildHTTP.date(job.startedAt), finishedAt: BuildHTTP.date(job.completedAt),
        failure: failure, steps: steps)
    }
    return BuildJobPage(jobs: jobs, hasMore: page * BuildJobPage.pageSize < response.totalCount)
  }
}
