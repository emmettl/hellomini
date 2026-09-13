import Foundation
import MiniBuildCore
import MiniGitHubCI
import Testing

@testable import MiniPrintMonitor

private func run(_ id: Int, _ state: BuildState, date: TimeInterval = 0) -> BuildRun {
  BuildRun(
    id: id, title: "Build", branch: "main", state: state,
    url: URL(string: "https://github.com/owner/app/actions/runs/\(id)")!,
    createdAt: Date(timeIntervalSince1970: date))
}

@Test @MainActor func projectLibraryMigratesOnceAndKeepsLegacyTokenIdentity() throws {
  let suite = "ProjectQueueTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set("GitHub", forKey: "ci.provider")
  defaults.set("Owner/MyApp", forKey: "ci.project")
  let observer = CompletionObserver { _ in }
  let queue = ProjectQueue(defaults: defaults, observer: observer)
  #expect(queue.projects.first?.account == "GitHub:Owner/MyApp")
  try queue.add(service: .github, path: "owner/myapp")
  #expect(queue.projects.count == 1 && queue.projects.first?.path == "Owner/MyApp")
  try queue.add(service: .gitlab, path: "group/subgroup/app")
  try queue.select(nil)
  let restored = ProjectQueue(defaults: defaults, observer: observer)
  #expect(restored.projects == queue.projects && restored.selection == nil)
  #expect(restored.snapshots.isEmpty && restored.refreshInterval == 180)
  for project in restored.projects { try restored.remove(project) }
  #expect(ProjectQueue(defaults: defaults, observer: observer).projects.isEmpty)
}

@Test @MainActor func malformedProjectLibrariesStayUntouched() throws {
  let suite = "ProjectQueueTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  for source in [
    "bad json", #"{"version":3,"projects":[]}"#,
    #"{"version":1,"projects":[{"service":"GitHub","path":"https://example.com"}]}"#,
    #"{"version":1,"projects":[{"service":"GitHub","path":"a/b"},{"service":"GitHub","path":"A/B"}]}"#,
  ] {
    let data = Data(source.utf8)
    defaults.set(data, forKey: ProjectQueue.storageKey)
    let queue = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in })
    #expect(queue.storageError != nil)
    #expect(throws: BuildServiceError.self) { try queue.add(service: .github, path: "owner/app") }
    #expect(defaults.data(forKey: ProjectQueue.storageKey) == data)
  }
}

private actor Responses {
  var values: [String: Result<[BuildRun], BuildServiceError>] = [:]
  func set(_ id: String, _ value: Result<[BuildRun], BuildServiceError>) { values[id] = value }
  func fetch(_ project: CIProject) throws -> [BuildRun] { try values[project.id]!.get() }
}

@Test @MainActor func combinedQueuesIsolateFailuresAndBatchIndependentCompletions() async throws {
  let suite = "ProjectQueueTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let responses = Responses()
  var meals: [Int] = []
  let queue = ProjectQueue(defaults: defaults, observer: CompletionObserver { meals.append($0) }) {
    try await responses.fetch($0)
  }
  try queue.add(service: .github, path: "owner/one")
  try queue.add(service: .gitlab, path: "owner/two")
  let one = queue.projects[0]
  let two = queue.projects[1]
  await responses.set(one.id, .success([run(1, .running, date: 10), run(1, .running)]))
  await responses.set(two.id, .success([run(1, .passed, date: 20)]))
  await queue.refresh()
  #expect(meals.isEmpty)
  let firstUpdate = queue.snapshots[one.id]?.updated
  await queue.refresh(onlyDue: true)
  #expect(queue.snapshots[one.id]?.updated == firstUpdate)
  try queue.select(nil)
  #expect(queue.builds.count == 2 && Set(queue.builds.map(\.id)).count == 2)
  #expect(queue.builds.first?.project.id == one.id)  // Active work outranks newer completed work.
  await responses.set(one.id, .success([run(1, .passed, date: 10)]))
  await responses.set(two.id, .success([run(2, .passed, date: 30)]))
  await queue.refresh()
  #expect(meals == [2] && queue.builds.first?.project.id == two.id)
  let priorUpdate = queue.snapshots[one.id]?.updated
  await responses.set(one.id, .failure(BuildServiceError("offline")))
  await responses.set(two.id, .success([run(3, .passed)]))
  await queue.refresh()
  #expect(meals == [2, 1])
  #expect(queue.snapshots[one.id]?.updated == priorUpdate)
  #expect(queue.snapshots[one.id]?.runs.first?.state == .passed)
  #expect(queue.snapshots[one.id]?.error == "offline")
  try queue.select(one.id)
  #expect(queue.builds.count == 1)
  try queue.select(two.id)
  await queue.refresh()
  #expect(meals == [2, 1])  // Merely changing the visible queue cannot reset history.
  try queue.remove(two)
  try queue.add(service: .gitlab, path: two.path)
  await queue.refresh()
  #expect(meals == [2, 1])  // Re-added projects establish a fresh baseline.
}

private actor ConcurrentFetcher {
  var active = 0
  var peak = 0
  var blocking = false
  var waiter: CheckedContinuation<Void, Never>?
  func blockRequests() { blocking = true }
  func waitForBlockedRequest() async {
    if active > 0 { return }
    await withCheckedContinuation { waiter = $0 }
  }
  func fetch(_ project: CIProject) async throws -> [BuildRun] {
    active += 1
    peak = max(peak, active)
    defer { active -= 1 }
    if blocking {
      waiter?.resume()
      waiter = nil
      try await Task.sleep(for: .seconds(60))
    } else {
      try await Task.sleep(for: .milliseconds(25))
    }
    return [run(1, .passed)]
  }
}

@Test @MainActor func projectRefreshBoundsConcurrencyAndIgnoresCancelledResults() async throws {
  let suite = "ProjectQueueTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let fetcher = ConcurrentFetcher()
  let queue = ProjectQueue(defaults: defaults, observer: CompletionObserver { _ in }) {
    try await fetcher.fetch($0)
  }
  for i in 0..<12 { try queue.add(service: .github, path: "owner/app\(i)") }
  #expect(throws: BuildServiceError.self) { try queue.add(service: .github, path: "owner/extra") }
  await queue.refresh()
  #expect(await fetcher.peak == 3 && queue.snapshots.count == 12 && !queue.busy)
  let previous = queue.snapshots.mapValues(\.updated)
  await fetcher.blockRequests()
  let task = Task { await queue.refresh() }
  await fetcher.waitForBlockedRequest()
  task.cancel()
  await task.value
  #expect(!queue.busy && queue.snapshots.mapValues(\.updated) == previous)
}

@Test func providerDatesSupportBothISOFormatsAndMissingValues() throws {
  #expect(BuildHTTP.date("2026-09-12T12:00:00Z") == BuildHTTP.date("2026-09-12T12:00:00.000Z"))
  #expect(BuildHTTP.date("invalid") == nil && BuildHTTP.date(nil) == nil)
  let data = Data(
    #"{"workflow_runs":[{"id":1,"status":"in_progress","created_at":"2026-09-12T12:00:00Z"}]}"#.utf8
  )
  #expect(try GitHubProvider.decode(data, project: "a/b").first?.createdAt != nil)
}
