import AppKit
import MiniBuildCore
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class PrintMonitorApplication: MiniApplication {
  public let id = "print-monitor"
  public let name = "Print Monitor"
  public let icon = MiniApplicationIcon.printer
  public let defaultSize = CGSize(width: 740, height: 500)
  public let minimumSize = CGSize(width: 640, height: 420)
  public static let effect = MiniPlayfulEffect(
    id: "printer.paper", name: "Print Monitor paper",
    description: "Feed imaginary paper through the printer while CI runs.")
  private let playfulness: PlayfulnessSettings
  private let model: ProjectQueue
  public init(
    playfulness: PlayfulnessSettings,
    onSuccessfulBuilds: @escaping @MainActor (Int) -> Void = { _ in }
  ) {
    self.playfulness = playfulness
    model = ProjectQueue(observer: CompletionObserver(notify: onSuccessfulBuilds))
  }
  public func content() -> AnyView {
    AnyView(PrintMonitorView(playfulness: playfulness, model: model))
  }
}

private struct PrintMonitorView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let playfulness: PlayfulnessSettings
  let model: ProjectQueue
  @State private var managing = false
  @State private var inspecting: ProjectBuild?
  @State private var error: String?
  @State private var active = NSApp.isActive
  @State private var manualRefreshTask: Task<Void, Never>?
  private var printing: Bool { model.builds.contains { $0.run.state == .running } }
  private var taskID: String { "\(model.configurationID)|\(active)|\(model.paused)" }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Picker(
          "Queue",
          selection: Binding(
            get: { model.selection ?? "" },
            set: { value in
              do { try model.select(value.isEmpty ? nil : value) } catch {
                self.error = error.localizedDescription
              }
            })
        ) {
          Text("All projects").tag("")
          ForEach(model.projects) { project in
            Text(project.label).tag(project.id)
          }
        }.accessibilityLabel("Build queue")
        Button("Projects…") { managing = true }.buttonStyle(RetroButtonStyle())
      }
      HStack {
        Picker(
          "Branch",
          selection: Binding(get: { model.filters.branch }, set: { setFilter(branch: $0) })
        ) {
          Text("All branches").tag(String?.none)
          ForEach(model.branchChoices, id: \.self) { Text($0).tag(Optional($0)) }
        }.accessibilityLabel("Filter by branch")
        Picker(
          "Workflow",
          selection: Binding(get: { model.filters.workflow }, set: { setFilter(workflow: $0) })
        ) {
          Text("All workflows").tag(String?.none)
          ForEach(model.workflowChoices, id: \.self) { Text($0).tag(Optional($0)) }
        }.accessibilityLabel("Filter by GitHub workflow")
        Button("Clear") { updateFilters(QueueFilters()) }.buttonStyle(RetroButtonStyle())
          .disabled(!model.filters.isActive)
      }
      if model.filters.isActive {
        Text(
          "Filtering the latest 20 builds per project"
            + (model.filters.workflow == nil ? "" : " · GitHub workflows only")
        )
        .font(theme.typography.small)
      }
      HStack(spacing: 14) {
        printer.frame(width: 130, height: 76)
        VStack(alignment: .leading, spacing: 4) {
          Text(model.jammed ? "Paper jam." : printing ? "Printing software…" : "Printer ready.")
            .font(theme.typography.display(23))
          Text(
            model.projects.isEmpty
              ? "Add a project to load its build queue."
              : "\(model.selectedProjects.count) \(model.selectedProjects.count == 1 ? "project" : "projects") · \(model.builds.filter { $0.active }.count) active builds"
          )
          .font(theme.typography.small)
        }
        Spacer(minLength: 0)
        Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
          .buttonStyle(RetroButtonStyle())
        Button("Refresh all", action: refreshManually).buttonStyle(RetroButtonStyle())
          .disabled(model.projects.isEmpty || model.busy)
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(model.selectedProjects) { project in
            VStack(alignment: .leading, spacing: 3) {
              Text(project.label)
                .font(theme.typography.title).lineLimit(1).help(project.label)
              let snapshot = model.snapshots[project.id]
              if let updated = snapshot?.updated {
                Text("Updated " + updated.formatted(date: .abbreviated, time: .shortened))
                  .font(theme.typography.small)
              } else {
                Text("Awaiting first successful refresh").font(theme.typography.small)
              }
              if let error = snapshot?.error {
                Text(
                  error + (snapshot?.updated == nil ? "" : " Showing the last successful refresh.")
                )
                .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().frame(height: 1)
          }
          ForEach(model.builds) { build in
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                if model.selection == nil {
                  Text(build.project.label)
                    .font(theme.typography.small).lineLimit(1).help(build.project.label)
                }
                Text(build.run.title).font(theme.typography.title).lineLimit(2).help(
                  build.run.title)
                Text("#\(String(build.run.id)) · \(build.run.branch)")
                  .font(theme.typography.small).lineLimit(1).help(build.run.branch)
              }
              Spacer()
              Text(build.run.state.rawValue.uppercased()).font(theme.typography.small)
              Button("Jobs…") { inspecting = build }
                .accessibilityLabel(
                  "Inspect jobs for " + build.run.title + " #" + String(build.run.id)
                )
                .buttonStyle(RetroButtonStyle())
            }
            Rectangle().frame(height: 1)
          }
          if model.builds.isEmpty {
            MiniEmptyState(
              model.busy ? "Checking the queues…" : "An exceptionally tidy print queue.",
              message: model.projects.isEmpty
                ? "Choose Projects… to add GitHub or GitLab projects. Public projects usually need no token."
                : model.filters.isActive
                  ? "No recent builds match. Clear the filters to see all loaded builds."
                  : "No builds to show. Each project's refresh status appears above.")
          }
        }
      }
      if let error = model.storageError ?? error { Text(error).font(theme.typography.small) }
      Text(
        model.busy
          ? "Checking all projects…"
          : "20 builds/project · refresh every \(Int(model.refreshInterval))s while active · active builds first"
      )
      .font(theme.typography.small)
    }.padding(16)
      .onDisappear { manualRefreshTask?.cancel() }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in active = true }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in active = false }
      .task(id: taskID) {
        guard active && !model.paused && !model.projects.isEmpty else { return }
        while !Task.isCancelled {
          while model.busy {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
          }
          guard !Task.isCancelled else { return }
          await model.refresh(onlyDue: true)
          do { try await Task.sleep(for: .seconds(model.refreshInterval)) } catch { return }
        }
      }
      .sheet(item: $inspecting) { build in
        JobDetailsView(build: build).id(build.id).environment(\.miniTheme, theme)
      }
      .sheet(isPresented: $managing) {
        ProjectManager(model: model) { if model.paused { refreshManually() } }
          .environment(\.miniTheme, theme)
      }
  }
  private func setFilter(branch: String?) {
    var value = model.filters
    value.branch = branch
    updateFilters(value)
  }
  private func setFilter(workflow: String?) {
    var value = model.filters
    value.workflow = workflow
    updateFilters(value)
  }
  private func updateFilters(_ value: QueueFilters) {
    do {
      try model.setFilters(value)
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  private func refreshManually() {
    guard !model.busy else { return }
    manualRefreshTask = Task { await model.refresh() }
  }
  private var printer: some View {
    TimelineView(
      .animation(
        minimumInterval: 1 / 15,
        paused: !printing || !active || !visible || reduceMotion
          || !playfulness.allows(PrintMonitorApplication.effect.id))
    ) { context in
      Canvas { graphics, size in
        let motion =
          printing && active && visible && !reduceMotion
            && playfulness.allows(PrintMonitorApplication.effect.id)
          ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) * 7 : 0
        let paper = CGRect(x: 34, y: 4 + motion, width: 62, height: 36)
        graphics.fill(Path(paper), with: .color(theme.paper))
        graphics.stroke(Path(paper), with: .color(theme.ink), lineWidth: 2)
        let box = CGRect(x: 12, y: 32, width: size.width - 24, height: 34)
        graphics.fill(Path(box), with: .color(theme.paper))
        graphics.stroke(Path(box), with: .color(theme.ink), lineWidth: 3)
        graphics.fill(Path(CGRect(x: 26, y: 53, width: 78, height: 3)), with: .color(theme.ink))
        graphics.fill(Path(CGRect(x: 98, y: 40, width: 5, height: 5)), with: .color(theme.ink))
      }
    }.accessibilityLabel("An imaginary printer for software builds")
  }
}
