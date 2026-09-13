import AppKit
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import MiniUI
import Observation
import SwiftUI

@MainActor @Observable final class JobDetails {
  let build: ProjectBuild
  private(set) var jobs: [BuildJob] = []
  private(set) var busy = false
  private(set) var error: String?
  private(set) var updated: Date?
  private(set) var page = 0
  private(set) var hasMore = false
  var canLoadMore: Bool { hasMore && page < BuildJobPage.maximumPage }
  @ObservationIgnored private let fetch:
    @Sendable (CIProject, Int, Int) async throws -> BuildJobPage

  init(
    build: ProjectBuild,
    fetch: @escaping @Sendable (CIProject, Int, Int) async throws -> BuildJobPage = {
      project, runID, page in
      let token = try CIToken.read(project.account)
      let provider = try project.provider()
      return try await provider.jobs(project: project.path, runID: runID, page: page, token: token)
    }
  ) {
    self.build = build
    self.fetch = fetch
  }

  func load(reset: Bool) async {
    guard !busy, !Task.isCancelled, reset || canLoadMore else { return }
    busy = true
    defer { busy = false }
    let requestedPage = reset ? 1 : page + 1
    do {
      let result = try await fetch(build.project, build.run.id, requestedPage)
      try Task.checkCancellation()
      var seen = Set<Int>()
      jobs = ((reset ? [] : jobs) + Array(result.jobs.prefix(BuildJobPage.pageSize))).filter {
        seen.insert($0.id).inserted
      }
      page = requestedPage
      hasMore = result.hasMore
      updated = Date()
      error = nil
    } catch {
      guard !Task.isCancelled else { return }
      self.error = error.localizedDescription
    }
  }
}

struct JobDetailsView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.dismiss) private var dismiss
  @State private var model: JobDetails
  @State private var request: Task<Void, Never>?
  init(build: ProjectBuild) { _model = State(initialValue: JobDetails(build: build)) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Inspect print job").font(theme.typography.display(22))
      Text(model.build.project.label)
        .font(theme.typography.small).lineLimit(1).miniHelp(model.build.project.label)
      Text(model.build.run.title).font(theme.typography.title).lineLimit(2).miniHelp(
        model.build.run.title)
      Text("#\(String(model.build.run.id)) · \(model.build.run.branch)")
        .font(theme.typography.small).lineLimit(1).miniHelp(model.build.run.branch)
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          ForEach(model.jobs) { job in
            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .top) {
                Text(job.name).font(theme.typography.title).textSelection(.enabled)
                Spacer(minLength: 4)
                Text(job.state.rawValue.uppercased()).font(theme.typography.small)
              }
              HStack {
                Text("Job #\(String(job.id))" + (job.stage.map { " · " + $0 } ?? ""))
                if let duration = job.duration { Text("· \(Int(duration))s") }
              }.font(theme.typography.small)
              if job.allowsFailure {
                Text("Allowed to fail without failing the pipeline.").font(theme.typography.small)
              }
              if let failure = job.failure {
                Text(failure).font(theme.typography.small).textSelection(.enabled)
              }
              if !job.steps.isEmpty {
                DisclosureGroup("Steps (\(job.steps.count))") {
                  ForEach(Array(job.steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top) {
                      Text(step.name).textSelection(.enabled)
                      Spacer(minLength: 4)
                      Text(step.state.rawValue.uppercased())
                    }.font(theme.typography.small).padding(.vertical, 2)
                  }
                }
              }
              Button("Open job logs") { NSWorkspace.shared.open(job.url) }
                .buttonStyle(RetroButtonStyle()).accessibilityLabel("Open logs for " + job.name)
            }
            Rectangle().frame(height: 1)
          }
          if model.jobs.isEmpty {
            Text(
              model.busy
                ? "Fetching the paperwork…"
                : model.updated == nil
                  ? "Job details have not loaded."
                  : "No jobs returned. They may not have started yet; try Refresh or open the build page."
            )
            .font(theme.typography.small)
          }
          if model.canLoadMore {
            Button("Load more jobs") { load(reset: false) }.buttonStyle(RetroButtonStyle())
              .disabled(model.busy)
          } else if model.hasMore {
            Text("Showing up to 500 jobs. Open the build page for the rest.").font(
              theme.typography.small)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.frame(height: 250)
      if let error = model.error {
        Text(error + (model.updated == nil ? "" : " Previously loaded jobs are still shown."))
          .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      }
      Text(
        model.busy
          ? "Checking jobs…"
          : model.updated.map {
            "Loaded " + $0.formatted(date: .omitted, time: .standard) + " · Refresh to check again"
          } ?? "Loaded on demand"
      )
      .font(theme.typography.small)
      Text(
        model.build.project.service == .github
          ? "Latest workflow execution. Full logs open on GitHub."
          : "Latest job attempts. Trigger jobs and child pipelines are available on the build page."
      )
      .font(theme.typography.small)
      HStack {
        Button("Refresh") { load(reset: true) }.buttonStyle(RetroButtonStyle()).disabled(model.busy)
        Button("Build & artifacts") { NSWorkspace.shared.open(model.build.run.url) }.buttonStyle(
          RetroButtonStyle())
        Spacer()
        Button("Done") { dismiss() }.buttonStyle(RetroButtonStyle()).keyboardShortcut(.cancelAction)
      }
    }.padding(20).frame(width: 580).foregroundStyle(theme.ink).background(theme.paper)
      .task { await model.load(reset: true) }
      .onDisappear { request?.cancel() }
  }
  private func load(reset: Bool) {
    request = Task { await model.load(reset: reset) }
  }
}
