import Foundation
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import Testing

@Test func retryProvidersUseConfiguredOriginsAndCorrectWriteEndpoints() async throws {
  let github = GitHubProvider(
    server: try BuildServer("https://github.example.com"),
    post: { url, headers in
      #expect(
        url.absoluteString
          == "https://github.example.com/api/v3/repos/owner/repo/actions/runs/42/rerun-failed-jobs")
      #expect(headers["Authorization"] == "Bearer fake-test-token")
    })
  try await github.retryFailed(project: "owner/repo", runID: 42, token: "fake-test-token")
  let gitlab = GitLabProvider(
    server: try BuildServer("https://gitlab.example.com"),
    post: { url, headers in
      #expect(
        url.absoluteString
          == "https://gitlab.example.com/api/v4/projects/group%2Fsub%2Frepo/pipelines/43/retry")
      #expect(headers["PRIVATE-TOKEN"] == "fake-test-token")
    })
  try await gitlab.retryFailed(project: "group/sub/repo", runID: 43, token: "fake-test-token")
}

@Test func retryProvidersRejectInvalidInputsBeforeSending() async {
  let github = GitHubProvider(post: { _, _ in Issue.record("Invalid retry must not be sent") })
  let gitlab = GitLabProvider(post: { _, _ in Issue.record("Invalid retry must not be sent") })
  await #expect(throws: (any Error).self) {
    try await github.retryFailed(project: "../repo", runID: 1, token: "test")
  }
  await #expect(throws: (any Error).self) {
    try await github.retryFailed(project: "owner/repo", runID: 0, token: "test")
  }
  await #expect(throws: (any Error).self) {
    try await gitlab.retryFailed(project: "group/repo", runID: 1, token: " ")
  }
}
