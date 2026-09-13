import Foundation
import MiniBuildCore
import Testing

@testable import MiniPrintMonitor

private func job(_ id: Int) -> BuildJob {
  BuildJob(
    id: id, name: "Build", state: .passed,
    url: URL(string: "https://github.com/owner/app/actions/runs/1/job/\(id)")!)
}

private actor JobResponses {
  var calls: [(CIProject, Int, Int)] = []
  var fail = false
  func setFailure(_ value: Bool) { fail = value }
  func fetch(_ project: CIProject, _ runID: Int, _ page: Int) throws -> BuildJobPage {
    calls.append((project, runID, page))
    if fail { throw BuildServiceError("Unavailable") }
    return BuildJobPage(jobs: [job(page), job(page + 1)], hasMore: true)
  }
}

@Test @MainActor func jobDetailsScopePagingFailureAndRefresh() async throws {
  let project = try CIProject(service: .github, path: "Owner/App")
  let build = ProjectBuild(
    project: project,
    run: BuildRun(
      id: 42, title: "CI", branch: "main", state: .passed,
      url: URL(string: "https://github.com/Owner/App/actions/runs/42")!))
  let responses = JobResponses()
  let model = JobDetails(build: build) { try await responses.fetch($0, $1, $2) }
  await model.load(reset: true)
  #expect(model.jobs.map(\.id) == [1, 2])
  let updated = model.updated
  await responses.setFailure(true)
  await model.load(reset: false)
  #expect(model.page == 1 && model.error == "Unavailable" && model.updated == updated)
  #expect(model.jobs.map(\.id) == [1, 2])
  await responses.setFailure(false)
  for _ in 0..<8 { await model.load(reset: false) }
  #expect(model.page == 5 && !model.canLoadMore && model.hasMore)
  #expect(model.jobs.map(\.id) == [1, 2, 3, 4, 5, 6])
  #expect(model.error == nil && !model.busy)
  let calls = await responses.calls
  #expect(calls.map { $0.2 } == [1, 2, 2, 3, 4, 5])
  #expect(calls.allSatisfy { $0.0.account == "GitHub:Owner/App" && $0.1 == 42 })
  await model.load(reset: true)
  #expect(model.page == 1 && model.jobs.map(\.id) == [1, 2])
}

private actor SuspendedJobs {
  var completion: CheckedContinuation<BuildJobPage, Never>?
  var ready: CheckedContinuation<Void, Never>?
  func fetch() async -> BuildJobPage {
    await withCheckedContinuation {
      completion = $0
      ready?.resume()
      ready = nil
    }
  }
  func waitForRequest() async {
    if completion != nil { return }
    await withCheckedContinuation { ready = $0 }
  }
  func finish() {
    completion?.resume(returning: BuildJobPage(jobs: [job(1)], hasMore: false))
    completion = nil
  }
}

@Test @MainActor func cancelledJobRequestDiscardsEvenNonCooperativeResponse() async throws {
  let project = try CIProject(service: .gitlab, path: "owner/app")
  let build = ProjectBuild(
    project: project,
    run: BuildRun(
      id: 1, title: "CI", branch: "main", state: .running,
      url: URL(string: "https://gitlab.com/owner/app/-/pipelines/1")!))
  let server = SuspendedJobs()
  let model = JobDetails(build: build) { _, _, _ in await server.fetch() }
  let task = Task { await model.load(reset: true) }
  await server.waitForRequest()
  #expect(model.busy)
  await model.load(reset: true)  // A duplicate request must not replace the in-flight one.
  task.cancel()
  await server.finish()
  await task.value
  #expect(model.jobs.isEmpty && model.updated == nil && model.error == nil && !model.busy)
}
