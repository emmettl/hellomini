import MiniBuildCore
import MiniUI
import Observation
import SwiftUI

/// A second copy requires observing the first become active and then fail.
/// Missing runs, uncertain writes and missed transitions stop the sequence instead of guessing.
struct RetryProgress {
  let copies: Int
  private(set) var submitted = 0
  private(set) var sawActive = false
  mutating func didSubmit() {
    submitted += 1
    sawActive = false
  }
  mutating func shouldRetry(after state: BuildState) -> Bool {
    if [.running, .queued, .waiting].contains(state) { sawActive = true }
    return sawActive && state == .failed && submitted < copies
  }
}

@MainActor @Observable final class PaperJamRetry {
  private(set) var busy = false
  private(set) var message = ""
  @ObservationIgnored private var task: Task<Void, Never>?
  func resetMessage() { if !busy { message = "" } }
  func stop() {
    task?.cancel()
    task = nil
    if busy {
      message = "Remaining copies stopped. Any jobs already submitted continue on the provider."
    }
  }
  func start(build: ProjectBuild, copies: Int) {
    guard !busy, build.run.state == .failed, (1...3).contains(copies) else { return }
    busy = true
    message = "Checking the paper tray…"
    task = Task {
      defer {
        busy = false
        task = nil
      }
      do {
        guard let token = try CIToken.read(build.project.account), !token.isEmpty else {
          throw BuildServiceError("Save a token with write access in Projects → Token first.")
        }
        let provider = try build.project.provider()
        let runs = try await provider.runs(project: build.project.path, token: token)
        guard runs.first(where: { $0.id == build.run.id })?.state == .failed else {
          throw BuildServiceError(
            "This run is no longer failed or is outside the recent queue. Refresh and inspect it on the provider."
          )
        }
        var progress = RetryProgress(copies: copies)
        while !Task.isCancelled {
          try Task.checkCancellation()
          try await provider.retryFailed(
            project: build.project.path, runID: build.run.id, token: token)
          progress.didSubmit()
          message =
            "Copy \(progress.submitted) of \(copies) submitted. The provider is retrying jobs."
          if progress.submitted == copies { return }
          let limit = Date.now.addingTimeInterval(1800)
          var retry = false
          while Date.now < limit {
            try await Task.sleep(for: .seconds(15))
            let runs = try await provider.runs(project: build.project.path, token: token)
            guard let run = runs.first(where: { $0.id == build.run.id }) else {
              throw BuildServiceError(
                "Run left the recent queue. Remaining copies stopped; inspect the provider.")
            }
            retry = progress.shouldRetry(after: run.state)
            if retry { break }
            if [.passed, .cancelled, .skipped].contains(run.state) {
              message = "Run is \(run.state.rawValue). No more copies needed."
              return
            }
          }
          guard retry else {
            throw BuildServiceError(
              "Could not confirm a completed retry within 30 minutes. Remaining copies stopped.")
          }
        }
      } catch is CancellationError {
        message = "Remaining copies stopped. Already submitted jobs continue on the provider."
      } catch {
        message =
          error.localizedDescription
          + " No further copies will be submitted; check the provider before trying again."
      }
    }
  }
}

struct ClearPaperJam: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  let build: ProjectBuild
  let retry: PaperJamRetry
  @State private var copies = 1
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Clear the paper jam").font(theme.typography.display(23))
      Text(build.project.label).font(theme.typography.title).textSelection(.enabled)
      Text(build.run.title + " · #" + String(build.run.id) + " · " + build.run.branch)
      Stepper("Copies: \(copies)", value: $copies, in: 1...3).disabled(retry.busy)
      Text(
        "Copies means the maximum number of retries. A further copy waits for an observed retry to fail. Stops on success, cancellation, uncertainty, or closing this window."
      )
      .font(theme.typography.small)
      Text(
        build.project.service == .github
          ? "Retries failed jobs and their dependents. Requires GitHub Actions write access."
          : "Retries failed and cancelled pipeline jobs. Requires a GitLab API token and permission to retry this pipeline."
      )
      .font(theme.typography.small)
      if !retry.message.isEmpty {
        Text(retry.message).font(theme.typography.small).textSelection(.enabled)
      }
      HStack {
        Button("Clear jam") { retry.start(build: build, copies: copies) }.disabled(retry.busy)
        Link("View on provider", destination: build.run.url)
        Spacer()
        Button(retry.busy ? "Stop remaining copies" : "Done") {
          retry.stop()
          dismiss()
        }
      }.buttonStyle(RetroButtonStyle())
    }.padding(20).frame(width: 520).foregroundStyle(theme.ink).background(theme.paper)
      .interactiveDismissDisabled(retry.busy)
      .onAppear { retry.resetMessage() }
      .onDisappear { retry.stop() }
  }
}
