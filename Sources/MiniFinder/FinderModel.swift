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
  var inspection: FileInspection?
  var fileDraft: FileOperationDraft?
  private(set) var fileBusy = false
  private(set) var copiedBytes: Int64 = 0
  private(set) var undoReceipt: FileUndoReceipt?
  var undoTitle: String { undoReceipt?.title ?? "Undo" }
  var canUndo: Bool { undoReceipt != nil && !fileBusy }
  func undoFileOperation() {
    guard canUndo, let receipt = undoReceipt else { return }
    fileBusy = true
    fileTask = Task {
      defer { fileBusy = false }
      do {
        try await reader.undo(receipt)
        undoReceipt = nil
        reload()
      } catch {
        self.error = error.localizedDescription
        undoReceipt = nil
      }
    }
  }
  @ObservationIgnored private var fileTask: Task<Void, Never>?
  func cancelFileOperation() { fileTask?.cancel() }
  private(set) var fileOperationError: String?
  func prepareNewFolder() {
    fileOperationError = nil
    fileDraft = FileOperationDraft(
      kind: .newFolder, source: nil, folder: location, name: "New Folder")
  }
  func prepareRename() {
    guard let entry = selectedEntry else { return }
    fileOperationError = nil
    fileDraft = FileOperationDraft(
      kind: .rename, source: entry.url, folder: location, name: entry.name)
  }
  func prepareMove() { prepareTransfer(move: true) }
  func prepareCopy() { prepareTransfer(move: false) }
  private func prepareTransfer(move: Bool) {
    guard let entry = selectedEntry else { return }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = move ? "Choose Move Destination" : "Choose Copy Destination"
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    fileOperationError = nil
    fileDraft = FileOperationDraft(
      kind: move ? .move : .copy, source: entry.url, folder: destination, name: entry.name)
  }
  func performFileOperation(_ draft: FileOperationDraft) {
    guard !fileBusy else { return }
    fileBusy = true
    copiedBytes = 0
    fileOperationError = nil
    fileTask = Task {
      defer { fileBusy = false }
      do {
        let (_, receipt) = try await reader.performWithUndo(draft) { [weak self] bytes in
          Task { @MainActor [weak self] in self?.copiedBytes = bytes }
        }
        undoReceipt = receipt
        fileDraft = nil
        reload()
      } catch {
        fileOperationError =
          Task.isCancelled
          ? "Cancelled. The source was kept and no destination was committed."
          : "Nothing was replaced. Cross-volume moves require macOS Finder. "
            + error.localizedDescription
      }
    }
  }
  private(set) var favourites: [URL] = []
  @ObservationIgnored private var inspectionTask: Task<Void, Never>?
  var currentIsFavourite: Bool { favourites.contains(location) }
  func toggleFavourite() {
    if currentIsFavourite {
      favourites.removeAll { $0 == location }
    } else if favourites.count < 20 {
      favourites.append(location)
    } else {
      error = "Keep up to 20 favourite folders. Remove one before adding another."
    }
    defaults.set(favourites.map(\.path), forKey: "finder.favourites")
  }
  func inspectSelection(preview: Bool) {
    guard let entry = selectedEntry else { return }
    inspect(entry, preview: preview)
  }
  func inspect(_ entry: FileEntry, preview: Bool) {
    inspectionTask?.cancel()
    inspectionTask = Task {
      do {
        let result = try await reader.inspect(entry.url, preview: preview)
        guard !Task.isCancelled else { return }
        inspection = result
      } catch {
        if !Task.isCancelled {
          self.error = "Could not inspect file: " + error.localizedDescription
        }
      }
    }
  }
  private let reader = DirectoryReader()
  private var loadTask: Task<Void, Never>?
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    var seen = Set<String>()
    favourites = (defaults.stringArray(forKey: "finder.favourites") ?? []).filter {
      $0.hasPrefix("/") && seen.insert($0).inserted
    }.prefix(20).map { URL(fileURLWithPath: $0).standardizedFileURL }
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
