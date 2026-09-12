import Foundation
import MiniBuildCore
import Testing

@testable import MiniPrintMonitor

@Test @MainActor func serverProjectsPreserveLegacyAccountsAndIsolateCustomHosts() throws {
  let suite = "ServerProjects.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set(
    Data(
      #"{"version":1,"projects":[{"service":"GitHub","path":"Owner/App"}],"selection":"GitHub:owner/app"}"#
        .utf8), forKey: ProjectQueue.storageKey)
  let queue = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in })
  #expect(queue.storageError == nil && queue.projects.first?.account == "GitHub:Owner/App")
  try queue.add(service: .github, path: "owner/app", server: "https://GITHUB.com:443/")
  #expect(queue.projects.count == 1)
  try queue.add(service: .github, path: "Owner/App", server: "https://ci.example.com:8443/")
  try queue.add(service: .github, path: "owner/app", server: "https://CI.EXAMPLE.COM:8443")
  try queue.add(service: .github, path: "Owner/App", server: "https://other.example.com")
  #expect(queue.projects.count == 3 && Set(queue.projects.map(\.account)).count == 3)
  #expect(queue.projects[1].account == "GitHub:https://ci.example.com:8443:Owner/App")
  let restored = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in })
  #expect(restored.projects == queue.projects && restored.selection == queue.selection)
  let unsafe = Data(
    #"{"version":2,"projects":[{"service":"GitHub","path":"Owner/App","server":"http://ci.example.com"}]}"#
      .utf8)
  defaults.set(unsafe, forKey: ProjectQueue.storageKey)
  let blocked = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in })
  #expect(blocked.storageError != nil && blocked.projects.isEmpty)
  #expect(defaults.data(forKey: ProjectQueue.storageKey) == unsafe)
}

private actor FilterRuns {
  var passed = false
  var calls = 0
  func complete() { passed = true }
  func fetch(_ project: CIProject) -> [BuildRun] {
    calls += 1
    return [
      BuildRun(
        id: 3, title: "Deploy", branch: "release", state: .failed,
        url: URL(string: "https://github.com/owner/app/actions/runs/3")!,
        workflow: project.service == .github ? "Deploy" : nil),
      BuildRun(
        id: 2, title: "CI", branch: "main", state: passed ? .passed : .running,
        url: URL(string: "https://github.com/owner/app/actions/runs/2")!,
        workflow: project.service == .github ? "CI" : nil),
    ]
  }
}

@Test @MainActor func filtersPersistWithoutRequestsOrCompletionReplay() async throws {
  let suite = "QueueFilters.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let source = FilterRuns()
  var meals = 0
  let queue = ProjectQueue(defaults: defaults, observer: CompletionObserver { meals += $0 }) {
    await source.fetch($0)
  }
  try queue.add(service: .github, path: "owner/app")
  try queue.add(service: .gitlab, path: "owner/app")
  try queue.select(nil)
  await queue.refresh()
  #expect(queue.jammed && queue.builds.count == 4)
  try queue.setFilters(QueueFilters(branch: "main", workflow: "CI"))
  #expect(queue.builds.count == 1 && !queue.jammed)
  #expect(queue.branchChoices == ["main", "release"] && queue.workflowChoices == ["CI", "Deploy"])
  #expect(await source.calls == 2)
  try queue.setFilters(QueueFilters(branch: "gone", workflow: "missing"))
  #expect(
    queue.builds.isEmpty && queue.branchChoices.contains("gone")
      && queue.workflowChoices.contains("missing"))
  await source.complete()
  await queue.refresh()
  #expect(meals == 2)  // Hidden successful builds still feed once.
  let restored = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in })
  #expect(restored.filters == queue.filters)
  try queue.setFilters(QueueFilters())
  #expect(queue.builds.count == 4 && meals == 2)
  await queue.refresh()
  #expect(meals == 2)
}
