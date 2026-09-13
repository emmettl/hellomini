import Foundation
import MiniBuildCore
import MiniCore
import MiniGitHubCI
import Testing

@testable import MiniAquarium
@testable import MiniPrintMonitor

@Test @MainActor func successfulRefreshFeedsOnceAndRespectsPlayfulnessWithoutBacklog() throws {
  let suite = "BuildFeedingTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: AquariumApplication.effects)
  let aquarium = AquariumApplication(playfulness: settings)
  let observer = CompletionObserver(notify: aquarium.feedFromSuccessfulBuilds)
  func refresh(_ status: String, conclusion: String? = nil, id: Int = 1) throws {
    let run: [String: Any] = [
      "id": id, "status": status, "conclusion": conclusion as Any? ?? NSNull(),
    ]
    let data = try JSONSerialization.data(withJSONObject: ["workflow_runs": [run]])
    observer.observe(
      try GitHubProvider.decode(data, project: "owner/app"), source: "GitHub:owner/app")
  }
  try refresh("in_progress")
  #expect(aquarium.model.feedRevision == 0)
  try refresh("completed", conclusion: "success")
  #expect(aquarium.model.feedRevision == 1)
  #expect(aquarium.model.feedingNote == "A build passed. Lunch is served.")
  aquarium.model.simulation.advance(
    now: 1, animate: false, feedRevision: aquarium.model.feedRevision)
  #expect(aquarium.model.simulation.foodAge == 0)
  try refresh("completed", conclusion: "success")
  #expect(aquarium.model.feedRevision == 1)
  settings.setSelected(false, for: AquariumApplication.buildFeeding.id)
  try refresh("completed", conclusion: "success", id: 2)
  settings.setSelected(true, for: AquariumApplication.buildFeeding.id)
  try refresh("completed", conclusion: "success", id: 2)
  #expect(aquarium.model.feedRevision == 1)
  settings.setEnabled(false)
  try refresh("completed", conclusion: "success", id: 3)
  settings.setEnabled(true)
  try refresh("completed", conclusion: "success", id: 3)
  #expect(aquarium.model.feedRevision == 1)
  try refresh("completed", conclusion: "failure", id: 4)
  #expect(aquarium.model.feedRevision == 1)
  try refresh("completed", conclusion: "success", id: 4)
  #expect(aquarium.model.feedRevision == 2)
}

@Test func completionTrackingIgnoresHistoryAndHandlesPollingGapsAndSourceChanges() {
  var tracker = BuildCompletionTracker()
  func run(_ id: Int, _ state: BuildState) -> BuildRun {
    BuildRun(
      id: id, title: "Build", branch: "main", state: state,
      url: URL(string: "https://github.com/owner/app/actions/runs/\(id)")!)
  }
  #expect(tracker.observe([run(100, .passed), run(99, .running)], source: "one") == 0)
  #expect(
    tracker.observe(
      [run(101, .passed), run(100, .passed), run(99, .passed), run(98, .passed)], source: "one")
      == 2)
  #expect(tracker.observe([run(101, .passed), run(99, .passed)], source: "one") == 0)
  #expect(tracker.observe([run(99, .running)], source: "one") == 0)
  #expect(tracker.observe([run(99, .passed)], source: "one") == 0)
  #expect(tracker.observe([run(300, .passed)], source: "two") == 0)
  #expect(tracker.observe([run(301, .passed), run(302, .passed)], source: "two") == 2)
  #expect(tracker.observe([run(301, .passed)], source: "two") == 0)
  #expect(tracker.observe([run(102, .passed)], source: "one") == 0)
}
