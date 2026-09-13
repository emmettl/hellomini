import Foundation

/// One source at a time. The initial snapshot is history, not a completion notification.
public struct BuildCompletionTracker {
  private var source: String?
  private var highestID = 0
  private var states: [Int: BuildState] = [:]
  private var rewarded = Set<Int>()
  private let terminalState: BuildState
  public init(terminalState: BuildState = .passed) { self.terminalState = terminalState }

  public mutating func observe(_ runs: [BuildRun], source: String) -> Int {
    if self.source != source {
      self.source = source
      highestID = runs.map(\.id).max() ?? 0
      states = [:]
      rewarded = Set(runs.filter { $0.state == terminalState }.map(\.id))
      for run in runs { states[run.id] = run.state }
      return 0
    }
    var completions = 0
    for run in runs {
      let changedToSuccess = states[run.id].map { $0 != terminalState } ?? false
      // Provider run IDs increase over time. Older runs resurfacing in the list aren't new builds.
      if run.state == terminalState, !rewarded.contains(run.id),
        changedToSuccess || run.id > highestID
      {
        completions += 1
        rewarded.insert(run.id)
      }
      states[run.id] = run.state
    }
    highestID = max(highestID, runs.map(\.id).max() ?? 0)
    let retained = Set(states.keys.sorted(by: >).prefix(200))
    states = states.filter { retained.contains($0.key) }
    rewarded.formIntersection(retained)
    return completions
  }
}
