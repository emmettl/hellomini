import Foundation
import MiniBuildCore
import Testing

@testable import MiniPrintMonitor

@Test func copiesRequireObservedActivityAndFailureAndRespectLimit() {
  var progress = RetryProgress(copies: 2)
  progress.didSubmit()
  let decision1 = !progress.shouldRetry(after: .failed)
  #expect(decision1)
  let decision2 = !progress.shouldRetry(after: .unknown)
  #expect(decision2)
  let decision3 = !progress.shouldRetry(after: .running)
  #expect(decision3)
  let decision4 = !progress.shouldRetry(after: .passed)
  #expect(decision4)
  let decision5 = progress.shouldRetry(after: .failed)
  #expect(decision5)
  progress.didSubmit()
  let decision6 = !progress.shouldRetry(after: .running)
  #expect(decision6)
  let decision7 = !progress.shouldRetry(after: .failed)
  #expect(decision7)
}

@Test @MainActor func failuresIgnoreHistoryDuplicatePollsAndForgottenProjects() {
  var failures = 0
  let observer = CompletionObserver(notify: { _ in }, failed: { failures += $0 })
  func run(_ id: Int, _ state: BuildState) -> BuildRun {
    BuildRun(
      id: id, title: "Build", branch: "main", state: state, url: URL(string: "https://example.com")!
    )
  }
  observer.observe([run(1, .failed), run(2, .running)], source: "a")
  #expect(failures == 0)
  observer.observe([run(1, .failed), run(2, .failed)], source: "a")
  #expect(failures == 1)
  observer.observe([run(1, .failed), run(2, .failed)], source: "a")
  #expect(failures == 1)
  observer.observe([run(3, .failed)], source: "a")
  #expect(failures == 2)
  observer.forget("a")
  observer.observe([run(4, .failed)], source: "a")
  #expect(failures == 2)
}
