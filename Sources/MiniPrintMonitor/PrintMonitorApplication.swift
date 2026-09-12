import AppKit
import MiniBuildCore
import MiniCore
import MiniGitHubCI
import MiniGitLabCI
import MiniUI
import Security
import SwiftUI

private enum CIToken {
  static func query(_ account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "HelloMini.CI",
      kSecAttrAccount as String: account,
    ]
  }
  static func read(_ account: String) throws -> String? {
    var query = query(account)
    query[kSecReturnData as String] = true
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw BuildServiceError("Could not read the CI token from Keychain (\(status)).")
    }
    return String(data: data, encoding: .utf8)
  }
  static func save(_ token: String, account: String) throws {
    let query = query(account)
    let value = [kSecValueData as String: Data(token.utf8)]
    var status = SecItemUpdate(query as CFDictionary, value as CFDictionary)
    if status == errSecItemNotFound {
      status = SecItemAdd(query.merging(value) { _, new in new } as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw BuildServiceError("Could not save the CI token to Keychain (\(status)).")
    }
  }
  static func forget(_ account: String) throws {
    let status = SecItemDelete(query(account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw BuildServiceError("Could not remove the token (\(status)).")
    }
  }
}

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
  private let observer: CompletionObserver
  public init(
    playfulness: PlayfulnessSettings,
    onSuccessfulBuilds: @escaping @MainActor (Int) -> Void = { _ in }
  ) {
    self.playfulness = playfulness
    observer = CompletionObserver(notify: onSuccessfulBuilds)
  }
  public func content() -> AnyView {
    AnyView(PrintMonitorView(playfulness: playfulness, observer: observer))
  }
}

@MainActor final class CompletionObserver {
  private var tracker = BuildCompletionTracker()
  let notify: @MainActor (Int) -> Void
  init(notify: @escaping @MainActor (Int) -> Void) { self.notify = notify }
  func observe(_ runs: [BuildRun], source: String) {
    let count = tracker.observe(runs, source: source)
    if count > 0 { notify(count) }
  }
}

private struct PrintMonitorView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let playfulness: PlayfulnessSettings
  let observer: CompletionObserver
  @AppStorage("ci.provider") private var savedProvider = "GitHub"
  @AppStorage("ci.project") private var savedProject = ""
  @State private var provider = "GitHub"
  @State private var project = ""
  @State private var token = ""
  @State private var credentials = false
  @State private var runs: [BuildRun] = []
  @State private var error: String?
  @State private var updated: Date?
  @State private var busy = false
  @State private var active = NSApp.isActive
  @State private var paused = false
  @State private var manualRefreshTask: Task<Void, Never>?
  private var account: String { savedProvider + ":" + savedProject }
  private var taskID: String { "\(savedProvider)|\(savedProject)|\(active)|\(paused)" }
  private var printing: Bool { runs.contains { $0.state == .running } }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Picker("Provider", selection: $provider) {
          Text("GitHub").tag("GitHub")
          Text("GitLab").tag("GitLab")
        }.labelsHidden().frame(width: 110)
        TextField("owner/project", text: $project).accessibilityLabel("CI project path")
          .onSubmit { if !busy { configure() } }
        Button("Load") { configure() }.disabled(busy)
        Button("Token…") { credentials = true }.disabled(savedProject.isEmpty || busy)
      }.buttonStyle(RetroButtonStyle())
      HStack(spacing: 14) {
        printer.frame(width: 130, height: 76)
        VStack(alignment: .leading, spacing: 4) {
          Text(
            runs.first?.state == .failed
              ? "Paper jam." : printing ? "Printing software…" : "Printer ready."
          ).font(theme.typography.display(23))
          Text(
            savedProject.isEmpty
              ? "Choose a project to load its build queue." : savedProvider + " · " + savedProject
          ).font(theme.typography.small).lineLimit(2).help(savedProject)
          if let updated {
            Text("Updated " + updated.formatted(date: .omitted, time: .standard)).font(
              theme.typography.small)
          }
        }
        Spacer()
        Button(paused ? "Resume" : "Pause") { paused.toggle() }.buttonStyle(RetroButtonStyle())
        Button("Refresh", action: refreshManually).buttonStyle(RetroButtonStyle()).disabled(
          savedProject.isEmpty || busy)
      }
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(runs) { run in
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(run.title).font(theme.typography.title).lineLimit(2).help(run.title)
                Text("#\(String(run.id)) · \(run.branch)").font(theme.typography.small).lineLimit(1)
                  .help(run.branch)
              }
              Spacer()
              Text(run.state.rawValue.uppercased()).font(theme.typography.small)
              Button("Build & artifacts") { NSWorkspace.shared.open(run.url) }.buttonStyle(
                RetroButtonStyle())
            }
            Rectangle().frame(height: 1)
          }
          if runs.isEmpty && updated != nil {
            MiniEmptyState(
              "An exceptionally tidy print queue.",
              message: "No recent builds were returned for this project.")
          } else if runs.isEmpty {
            MiniEmptyState(
              busy ? "Checking the queue…" : "Software, printed to order.",
              message: savedProject.isEmpty
                ? "Enter a GitHub or GitLab project above and choose Load. Public projects usually need no token."
                : "Use Refresh to check the project. Any connection problem appears below.")
          }
        }
      }
      if let error { Text(error).font(theme.typography.small) }
      Text(
        busy
          ? "Checking the queue…"
          : "Latest 20 builds · refreshes every 90 seconds while active · logs and artifacts open on the build page"
      )
      .font(theme.typography.small)
    }.padding(16)
      .onDisappear { manualRefreshTask?.cancel() }
      .onAppear {
        provider = savedProvider
        project = savedProject
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
      ) { _ in active = true }
      .onReceive(
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
      ) { _ in active = false }
      .task(id: taskID) {
        guard active && !paused && !savedProject.isEmpty else { return }
        while !Task.isCancelled {
          while busy {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
          }
          guard !Task.isCancelled else { return }
          await refresh()
          do { try await Task.sleep(for: .seconds(90)) } catch { return }
        }
      }
      .sheet(isPresented: $credentials) {
        VStack(alignment: .leading, spacing: 14) {
          Text("Token for \(account)").font(theme.typography.title)
          Text(
            "Optional for public projects. Use Actions read access on GitHub or read_api access on GitLab. Stored in this Mac's Keychain."
          )
          .font(theme.typography.small)
          SecureField("Token", text: $token)
          HStack {
            Button("Save token") {
              do {
                try CIToken.save(token, account: account)
                token = ""
                credentials = false
                error = nil
              } catch { self.error = error.localizedDescription }
            }.disabled(token.isEmpty)
            Button("Forget token") {
              do {
                try CIToken.forget(account)
                token = ""
                credentials = false
                error = nil
              } catch { self.error = error.localizedDescription }
            }
            Spacer()
            Button("Cancel") {
              token = ""
              credentials = false
            }
          }.buttonStyle(RetroButtonStyle())
          if let error { Text(error).font(theme.typography.small) }
        }.padding(20).frame(width: 470).foregroundStyle(theme.ink).background(theme.paper)
      }
  }
  private func configure() {
    do {
      let path = try BuildHTTP.validateProject(
        project.trimmingCharacters(in: .whitespacesAndNewlines), github: provider == "GitHub")
      let changed = savedProvider != provider || savedProject != path
      savedProvider = provider
      savedProject = path
      runs = []
      updated = nil
      error = nil
      if !changed || paused { refreshManually() }
    } catch { self.error = error.localizedDescription }
  }
  private func refreshManually() {
    manualRefreshTask?.cancel()
    manualRefreshTask = Task { await refresh() }
  }
  private func refresh() async {
    guard !busy, !savedProject.isEmpty else { return }
    busy = true
    defer { busy = false }
    let identity = account
    let project = savedProject
    do {
      let service: any BuildProvider =
        savedProvider == "GitHub" ? GitHubProvider() : GitLabProvider()
      let token = try CIToken.read(identity)
      let result = try await service.runs(project: project, token: token)
      guard !Task.isCancelled, identity == account else { return }
      runs = result
      observer.observe(result, source: identity)
      updated = .now
      error = nil
    } catch is CancellationError {} catch {
      if !Task.isCancelled, identity == account { self.error = error.localizedDescription }
    }
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
