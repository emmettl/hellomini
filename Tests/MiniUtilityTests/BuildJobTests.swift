import Foundation
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import Testing

@Test func githubJobsReportFailedStepsAndUseTrustedURLs() throws {
  let data = Data(
    #"{"total_count":101,"jobs":[{"id":8,"name":"Tests","status":"completed","conclusion":"failure","html_url":"https://evil.example","started_at":"2026-09-12T12:00:00Z","completed_at":"2026-09-12T12:00:09Z","steps":[{"number":1,"name":"Compile","status":"completed","conclusion":"success"},{"number":2,"name":"Unit tests","status":"completed","conclusion":"failure"}]},{"id":9,"name":"Deploy","status":"queued","steps":null}]}"#
      .utf8)
  let page = try GitHubProvider.decodeJobs(data, project: "owner/app", runID: 7)
  let job = try #require(page.jobs.first)
  #expect(job.state == .failed)
  #expect(job.failure == "Failed steps: Unit tests")
  #expect(job.steps.map(\.state) == [.passed, .failed])
  #expect(job.duration == 9)
  #expect(job.url.absoluteString == "https://github.com/owner/app/actions/runs/7/job/8")
  #expect(page.jobs.last?.state == .queued)
  #expect(page.hasMore)
  #expect(try !GitHubProvider.decodeJobs(data, project: "owner/app", runID: 7, page: 2).hasMore)
  for page in [0, 6] {
    #expect(throws: BuildServiceError.self) {
      try GitHubProvider.decodeJobs(data, project: "owner/app", runID: 7, page: page)
    }
  }
  #expect(throws: BuildServiceError.self) {
    try GitHubProvider.decodeJobs(data, project: "owner/app", runID: -1)
  }
  #expect(throws: BuildServiceError.self) {
    try GitHubProvider.decodeJobs(data, project: "owner/app?token=bad", runID: 7)
  }
  #expect(throws: (any Error).self) {
    try GitHubProvider.decodeJobs(Data("{}".utf8), project: "owner/app", runID: 7)
  }
}

@Test func gitlabJobsKeepAllowedFailuresAndMissingReasonsHonest() throws {
  let data = Data(
    #"[{"id":4,"name":"Lint","status":"failed","stage":"test","failure_reason":"script_failure","allow_failure":true,"web_url":"file:///tmp/bad","started_at":"2026-09-12T12:00:09Z","finished_at":"2026-09-12T12:00:00Z"},{"id":5,"name":"Deploy","status":"manual","runner":null},{"id":6,"name":"Test","status":"failed"}]"#
      .utf8)
  let page = try GitLabProvider.decodeJobs(data, project: "team/subgroup/app")
  let job = try #require(page.jobs.first)
  #expect(job.failure == "GitLab reports: script failure")
  #expect(job.stage == "test" && job.allowsFailure)
  #expect(job.duration == nil)
  #expect(job.url.absoluteString == "https://gitlab.com/team/subgroup/app/-/jobs/4")
  #expect(page.jobs[1].state == .waiting && page.jobs[1].failure == nil)
  #expect(page.jobs[2].failure?.contains("No failure reason supplied") == true)
  #expect(!page.hasMore)
  let full = try JSONSerialization.data(
    withJSONObject: (1...100).map {
      ["id": $0, "name": "Build", "status": "success"] as [String: Any]
    })
  #expect(try GitLabProvider.decodeJobs(full, project: "owner/app").hasMore)
  #expect(try GitLabProvider.decodeJobs(Data("[]".utf8), project: "owner/app").jobs.isEmpty)
}
