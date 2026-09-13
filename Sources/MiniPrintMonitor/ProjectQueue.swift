import Foundation
import MiniBuildCore
import MiniGitHubCI
import MiniGitLabCI
import Observation

enum CIService: String, Codable, CaseIterable, Sendable {
  case github = "GitHub"
  case gitlab = "GitLab"
}

struct CIProject: Codable, Hashable, Identifiable, Sendable {
  let service: CIService
  let path: String
  let server: String?
  private var identityPrefix: String { service.rawValue + ":" + (server.map { $0 + ":" } ?? "") }
  var id: String { identityPrefix + (service == .github ? path.lowercased() : path) }
  // Public projects keep their original Keychain account. Custom origins get separate accounts.
  var account: String { identityPrefix + path }
  var serverAddress: String {
    server ?? (service == .github ? BuildServer.github.website : BuildServer.gitlab.website)
  }
  var label: String { service.rawValue + (server.map { " · " + $0 } ?? "") + " · " + path }
  init(service: CIService, path: String, server: String? = nil) throws {
    self.service = service
    self.path = try BuildHTTP.validateProject(
      path.trimmingCharacters(in: .whitespacesAndNewlines), github: service == .github)
    let address = try server.map { try BuildServer($0) }
    let standard: BuildServer = service == .github ? .github : .gitlab
    self.server = address == standard ? nil : address?.website
  }
  func provider() throws -> any BuildProvider {
    let server = try BuildServer(serverAddress)
    return service == .github ? GitHubProvider(server: server) : GitLabProvider(server: server)
  }
}

struct QueueFilters: Codable, Equatable {
  var branch: String?
  var workflow: String?
  var isActive: Bool { branch != nil || workflow != nil }
  func matches(_ run: BuildRun) -> Bool {
    (branch == nil || branch == run.branch) && (workflow == nil || workflow == run.workflow)
  }
}

private struct ProjectLibrary: Codable {
  let version: Int
  let projects: [CIProject]
  let selection: String?
  let filters: QueueFilters?
}

struct ProjectSnapshot {
  var runs: [BuildRun] = []
  var updated: Date?
  var error: String?
}

struct ProjectBuild: Identifiable {
  let project: CIProject
  let run: BuildRun
  var id: String { project.id + ":" + String(run.id) }
  var active: Bool { [.running, .queued, .waiting].contains(run.state) }
}

@MainActor @Observable final class ProjectQueue {
  static let limit = 12
  static let storageKey = "ci.projects"
  private(set) var projects: [CIProject] = []
  private(set) var selection: String?
  private(set) var snapshots: [String: ProjectSnapshot] = [:]
  private(set) var busy = false
  private(set) var storageError: String?
  private(set) var filters = QueueFilters()
  var paused = false
  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let fetch: @Sendable (CIProject) async throws -> [BuildRun]
  @ObservationIgnored private var lastAttempt: [String: Date] = [:]
  @ObservationIgnored private let observer: CompletionObserver

  init(
    defaults: UserDefaults = .standard, observer: CompletionObserver,
    fetch: @escaping @Sendable (CIProject) async throws -> [BuildRun] = { project in
      let token = try CIToken.read(project.account)
      let provider = try project.provider()
      return try await provider.runs(project: project.path, token: token)
    }
  ) {
    self.defaults = defaults
    self.observer = observer
    self.fetch = fetch
    do {
      if let data = defaults.data(forKey: Self.storageKey) {
        let saved = try JSONDecoder().decode(ProjectLibrary.self, from: data)
        guard (1...2).contains(saved.version), saved.projects.count <= Self.limit,
          Set(saved.projects.map(\.id)).count == saved.projects.count
        else {
          throw BuildServiceError("Unsupported or invalid saved project library.")
        }
        for project in saved.projects {
          let checked = try CIProject(
            service: project.service, path: project.path, server: project.server)
          guard checked == project else { throw BuildServiceError("Invalid saved project path.") }
        }
        if saved.version == 1 && saved.projects.contains(where: { $0.server != nil }) {
          throw BuildServiceError("Invalid legacy project library.")
        }
        filters = saved.filters ?? QueueFilters()
        projects = saved.projects
        selection = projects.contains { $0.id == saved.selection } ? saved.selection : nil
      } else if defaults.object(forKey: Self.storageKey) != nil {
        throw BuildServiceError("Unreadable saved project library.")
      } else if let path = defaults.string(forKey: "ci.project"), !path.isEmpty {
        guard let service = CIService(rawValue: defaults.string(forKey: "ci.provider") ?? "GitHub")
        else { throw BuildServiceError("Unknown saved CI provider.") }
        let project = try CIProject(service: service, path: path)
        try persist(projects: [project], selection: project.id)
        projects = [project]
        selection = project.id
      }
    } catch {
      storageError =
        "Saved projects could not be opened. Existing preferences were kept. "
        + error.localizedDescription
    }
  }

  var selectedProjects: [CIProject] {
    guard let selection else { return projects }
    return projects.filter { $0.id == selection }
  }
  var refreshInterval: TimeInterval { Double(max(1, projects.count) * 90) }
  var configurationID: String { projects.map(\.id).joined(separator: "|") }
  var builds: [ProjectBuild] {
    selectedProjects.flatMap { project in
      (snapshots[project.id]?.runs ?? []).filter(filters.matches).map {
        ProjectBuild(project: project, run: $0)
      }
    }.sorted { lhs, rhs in
      if lhs.active != rhs.active { return lhs.active }
      if lhs.run.createdAt != rhs.run.createdAt {
        return (lhs.run.createdAt ?? .distantPast) > (rhs.run.createdAt ?? .distantPast)
      }
      if lhs.project.id != rhs.project.id { return lhs.project.id < rhs.project.id }
      return lhs.run.id > rhs.run.id
    }
  }
  var jammed: Bool {
    selectedProjects.contains {
      snapshots[$0.id]?.runs.first(where: filters.matches)?.state == .failed
    }
  }

  func add(service: CIService, path: String, server: String? = nil) throws {
    try writable()
    let project = try CIProject(service: service, path: path, server: server)
    if let existing = projects.first(where: { $0.id == project.id }) {
      try select(existing.id)
      return
    }
    guard projects.count < Self.limit else {
      throw BuildServiceError("The printer has room for \(Self.limit) projects.")
    }
    try persist(projects: projects + [project], selection: project.id)
    projects.append(project)
    selection = project.id
  }
  func remove(_ project: CIProject) throws {
    try writable()
    let remaining = projects.filter { $0.id != project.id }
    let selection = selection == project.id ? nil : selection
    try persist(projects: remaining, selection: selection)
    projects = remaining
    self.selection = selection
    snapshots[project.id] = nil
    lastAttempt[project.id] = nil
    observer.forget(project.id)
  }
  func select(_ id: String?) throws {
    guard storageError == nil, id == nil || projects.contains(where: { $0.id == id }) else {
      return
    }
    try persist(projects: projects, selection: id)
    selection = id
  }
  var branchChoices: [String] {
    Array(
      Set(
        selectedProjects.flatMap { snapshots[$0.id]?.runs.map(\.branch) ?? [] }
          + [filters.branch].compactMap { $0 })
    ).sorted()
  }
  var workflowChoices: [String] {
    Array(
      Set(
        selectedProjects.flatMap { snapshots[$0.id]?.runs.compactMap(\.workflow) ?? [] }
          + [filters.workflow].compactMap { $0 })
    ).sorted()
  }
  func setFilters(_ value: QueueFilters) throws {
    if let storageError { throw BuildServiceError(storageError) }
    try persist(projects: projects, selection: selection, filters: value)
    filters = value
  }
  private func writable() throws {
    if let storageError { throw BuildServiceError(storageError) }
    if busy { throw BuildServiceError("Wait for the current refresh to finish.") }
  }
  private func persist(projects: [CIProject], selection: String?, filters: QueueFilters? = nil)
    throws
  {
    defaults.set(
      try JSONEncoder().encode(
        ProjectLibrary(
          version: 2, projects: projects, selection: selection, filters: filters ?? self.filters)),
      forKey: Self.storageKey)
  }

  /// At most three requests run together. One failure retains that project's last good snapshot.
  func refresh(onlyDue: Bool = false) async {
    guard !busy, !projects.isEmpty, !Task.isCancelled else { return }
    let now = Date.now
    let pending = projects.filter {
      !onlyDue || now.timeIntervalSince(lastAttempt[$0.id] ?? .distantPast) >= refreshInterval
    }
    guard !pending.isEmpty else { return }
    busy = true
    defer { busy = false }
    let fetch = fetch
    var successful: [(String, [BuildRun])] = []
    await withTaskGroup(of: (CIProject, Result<[BuildRun], BuildServiceError>).self) { group in
      var iterator = pending.makeIterator()
      let load: @Sendable (CIProject) async -> (CIProject, Result<[BuildRun], BuildServiceError>) =
        { project in
          do { return (project, .success(try await fetch(project))) } catch {
            return (project, .failure(BuildServiceError(error.localizedDescription)))
          }
        }
      // Mutate the task group directly. Capturing it in a nested enqueue function loses
      // results under the release optimizer; the release-configuration tests cover this.
      for _ in 0..<min(3, pending.count) {
        if let project = iterator.next() { group.addTask { await load(project) } }
      }
      for await (project, result) in group {
        guard !Task.isCancelled else {
          group.cancelAll()
          break
        }
        lastAttempt[project.id] = .now
        switch result {
        case .success(let runs):
          // Protect row identity against repeated entries from a provider response.
          var seen = Set<Int>()
          let unique = runs.filter { seen.insert($0.id).inserted }.prefix(20)
          snapshots[project.id] = ProjectSnapshot(runs: Array(unique), updated: .now)
          successful.append((project.id, Array(unique)))
        case .failure(let error):
          var snapshot = snapshots[project.id] ?? ProjectSnapshot()
          snapshot.error = error.localizedDescription
          snapshots[project.id] = snapshot
        }
        if let project = iterator.next() { group.addTask { await load(project) } }
      }
    }
    // Account for successful responses already displayed even if a later request was cancelled.
    observer.observeBatch(successful)
  }
}

@MainActor final class CompletionObserver {
  private var trackers: [String: BuildCompletionTracker] = [:]
  let notify: @MainActor (Int) -> Void
  init(notify: @escaping @MainActor (Int) -> Void) { self.notify = notify }
  func observe(_ runs: [BuildRun], source: String) { observeBatch([(source, runs)]) }
  func observeBatch(_ snapshots: [(String, [BuildRun])]) {
    var count = 0
    for (source, runs) in snapshots {
      var tracker = trackers[source] ?? BuildCompletionTracker()
      count += tracker.observe(runs, source: source)
      trackers[source] = tracker
    }
    if count > 0 { notify(count) }
  }
  func forget(_ source: String) { trackers[source] = nil }
}
