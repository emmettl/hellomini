import AppKit
import Observation

@MainActor @Observable
final class FinderModel {
  var history: NavigationHistory
  var entries: [FileEntry] = []
  var selection: URL?
  var showHidden: Bool { didSet { defaults.set(showHidden, forKey: "finder.showHidden") } }
  var listView: Bool { didSet { defaults.set(listView, forKey: "finder.listView") } }
  var isLoading = false
  var error: String?
  private let reader = DirectoryReader()
  private var loadTask: Task<Void, Never>?
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let path = defaults.string(forKey: "finder.location")
    let location =
      path.flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }
      ?? FileManager.default.homeDirectoryForCurrentUser
    history = NavigationHistory(start: location)
    showHidden = defaults.bool(forKey: "finder.showHidden")
    listView = defaults.bool(forKey: "finder.listView")
  }

  var location: URL { history.current }
  var selectedEntry: FileEntry? { entries.first { $0.url == selection } }
  var title: String { location.path == "/" ? "Macintosh HD" : location.lastPathComponent }

  func navigate(to url: URL) {
    history.visit(url)
    reload()
  }

  func goBack() {
    history.goBack()
    reload()
  }

  func goUp() {
    guard history.canGoUp else { return }
    navigate(to: location.deletingLastPathComponent())
  }

  func reload() {
    defaults.set(location.path, forKey: "finder.location")
    loadTask?.cancel()
    selection = nil
    error = nil
    entries = []
    isLoading = true
    let directory = location
    let includeHidden = showHidden
    loadTask = Task {
      do {
        let result = try await reader.entries(at: directory, showHidden: includeHidden)
        guard !Task.isCancelled else { return }
        entries = result
        isLoading = false
      } catch {
        guard !Task.isCancelled else { return }
        self.error = error.localizedDescription
        isLoading = false
      }
    }
  }

  func setLabel(_ number: Int, entry: FileEntry) {
    Task {
      do {
        try await reader.setLabel(number, at: entry.url)
        reload()
      } catch { self.error = "Could not change the Finder label: " + error.localizedDescription }
    }
  }
  func open(_ entry: FileEntry) {
    if entry.isBrowsable {
      navigate(to: entry.url)
    } else if !NSWorkspace.shared.open(entry.url) {
      error = "macOS could not open \(entry.name). Try revealing it in Finder."
    }
  }

  func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Open Folder"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    navigate(to: url)
  }

  func revealSelection() {
    NSWorkspace.shared.activateFileViewerSelecting([selection ?? location])
  }
}
