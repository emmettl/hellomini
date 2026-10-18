import Foundation
import MiniBuildCore
import Testing

@testable import MiniPrintMonitor

private actor HistoryCalls {
  var queries: [(String, Int)] = []
  func fetch(_ branch: String, _ page: Int) -> BuildRunPage {
    queries.append((branch, page))
    return BuildRunPage(
      runs: [
        BuildRun(
          id: page, title: "Historic build", branch: branch, state: .passed,
          url: URL(string: "https://example.invalid/run")!)
      ], hasMore: page < 2)
  }
  func values() -> [(String, Int)] { queries }
}
@Test @MainActor func historyPaginationKeepsTheSearchedBranchUntilNewSearch() async throws {
  let calls = HistoryCalls()
  let model = BuildHistoryModel(
    project: try CIProject(service: .github, path: "owner/repo"),
    fetch: { _, branch, page in await calls.fetch(branch, page) })
  model.branch = "main"
  await model.load(reset: true)
  model.branch = "different"
  await model.load(reset: false)
  let queries = await calls.values()
  #expect(queries.map(\.0) == ["main", "main"])
  #expect(model.runs.count == 2 && model.searchedBranch == "main")
  await model.load(reset: true)
  #expect(model.runs.count == 1 && model.searchedBranch == "different")
}
