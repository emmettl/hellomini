import AppKit
import MiniBuildCore
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable final class BuildHistoryModel {
  let project: CIProject
  var branch = ""
  private(set) var runs: [BuildRun] = []
  private(set) var searchedBranch = ""
  private(set) var page = 0
  private(set) var more = false
  private(set) var busy = false
  private(set) var error: String?
  @ObservationIgnored private let fetch:
    @Sendable (CIProject, String, Int) async throws -> BuildRunPage
  init(
    project: CIProject,
    fetch: @escaping @Sendable (CIProject, String, Int) async throws -> BuildRunPage = {
      try await $0.provider().history(
        project: $0.path, branch: $1, page: $2, token: CIToken.read($0.account))
    }
  ) {
    self.project = project
    self.fetch = fetch
  }
  func load(reset: Bool) async {
    guard !busy, reset || (more && page < 50) else { return }
    busy = true
    defer { busy = false }
    do {
      let next = reset ? 1 : page + 1
      let result = try await fetch(
        project, reset ? branch.trimmingCharacters(in: .whitespacesAndNewlines) : searchedBranch,
        next)
      try Task.checkCancellation()
      var seen = Set<Int>()
      runs = ((reset ? [] : runs) + result.runs).filter { seen.insert($0.id).inserted }
      if reset { searchedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines) }
      page = next
      more = result.hasMore
      error = nil
    } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
  }
}
struct BuildHistoryView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @FocusState private var branchFocused: Bool
  @State private var focusRequest = 0
  @State private var model: BuildHistoryModel
  @State private var request: Task<Void, Never>?
  @State private var inspecting: ProjectBuild?
  @State private var artifacts: ProjectBuild?
  init(project: CIProject) { _model = State(initialValue: BuildHistoryModel(project: project)) }
  init(model: BuildHistoryModel) { _model = State(initialValue: model) }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Print Archive").font(theme.typography.title)
      Text(model.project.label).font(theme.typography.small).lineLimit(2)
      HStack {
        TextField("Exact branch (blank for all)", text: $model.branch).accessibilityLabel(
          "History branch"
        )
        .focused($branchFocused).disabled(model.busy)
        Button("Search") { load(reset: true) }.disabled(model.busy).miniControlBounds(
          "history.search")
      }.onSubmit { load(reset: true) }
      Text("Showing: " + (model.searchedBranch.isEmpty ? "all branches" : model.searchedBranch))
        .font(theme.typography.small)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if let error = model.error {
            Text(error).font(theme.typography.small).textSelection(.enabled)
          }
          ForEach(model.runs) { run in
            VStack(alignment: .leading, spacing: 4) {
              Text(run.title).font(theme.typography.title)
              Text("#\(run.id) · \(run.branch) · \(run.state.rawValue.uppercased())").font(
                theme.typography.small)
              if let date = run.createdAt { Text(date.formatted()).font(theme.typography.small) }
              HStack {
                Button("Open") { NSWorkspace.shared.open(run.url) }
                if let attempt = run.attempt, attempt > 1 {
                  Menu("Open Attempt") {
                    ForEach(1...min(attempt, 100), id: \.self) { number in
                      Button("Attempt \(number)") {
                        NSWorkspace.shared.open(
                          run.url.appendingPathComponent("attempts/\(number)"))
                      }
                    }
                  }
                }
                Button("Jobs…") { inspecting = ProjectBuild(project: model.project, run: run) }
                Button("Artifacts…") { artifacts = ProjectBuild(project: model.project, run: run) }
              }
            }
            Divider()
          }
          if model.runs.isEmpty {
            Text(
              model.busy
                ? "Reading the archive…"
                : "No builds found. Search an exact branch or leave it blank.")
          }
        }
      }.frame(height: 110)
      Text(
        "Older attempts remain separate runs. This archive does not change live status or replay build alerts."
      ).font(theme.typography.small)
      HStack {
        if model.more && model.page < 50 {
          Button("More") { load(reset: false) }.disabled(model.busy)
        }
        if model.busy { Button("Cancel") { request?.cancel() } }
        Spacer()
        Button("Live Queue") { dismiss() }.keyboardShortcut(.cancelAction).miniControlBounds(
          "history.live")
      }
    }.padding(12).frame(width: 480).foregroundStyle(theme.ink).background(theme.paper).buttonStyle(
      RetroButtonStyle()
    )
    .onAppear { load(reset: true) }.onDisappear { request?.cancel() }
    .background(
      MiniSheetFocusRestoration(request: focusRequest, active: true) { branchFocused = true }
    )
    .sheet(item: $inspecting, onDismiss: restoreFocus) { build in
      JobDetailsView(build: build).environment(\.miniTheme, theme).miniSheet(width: 580)
    }
    .sheet(item: $artifacts, onDismiss: restoreFocus) { build in
      ArtifactListView(build: build).environment(\.miniTheme, theme).miniSheet(width: 480)
    }
  }
  private func restoreFocus() {
    branchFocused = false
    focusRequest += 1
  }
  private func load(reset: Bool) {
    request?.cancel()
    request = Task { await model.load(reset: reset) }
  }
}
