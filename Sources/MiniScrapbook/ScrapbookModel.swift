import AppKit
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class ScrapbookModel {
  private(set) var scraps: [Scrap] = []
  private(set) var ready = false
  private(set) var busy = false
  var query = ""
  var showArchive = false
  var selection: UUID?
  var draft: Scrap?
  var error: String?
  var notice = "An unreasonable amount of room for little things."
  @ObservationIgnored let store: ScrapbookStore
  @ObservationIgnored private let pasteboard: NSPasteboard

  init(directory: URL? = nil, pasteboard: NSPasteboard = .general) {
    self.pasteboard = pasteboard
    let root =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("HelloMini/Scrapbook", isDirectory: true)
    store = ScrapbookStore(directory: root)
  }

  var visible: [Scrap] {
    scraps.filter { $0.archived == showArchive && $0.matches(query) }
      .sorted {
        $0.modified == $1.modified ? $0.id.uuidString < $1.id.uuidString : $0.modified > $1.modified
      }
  }
  var selected: Scrap? { visible.first { $0.id == selection } }
  var canChange: Bool { ready && !busy }

  func load() async {
    guard !ready && !busy else { return }
    busy = true
    defer { busy = false }
    do {
      scraps = try await store.load()
      ready = true
      selection = visible.first?.id
      error = nil
    } catch { self.error = error.localizedDescription }
  }

  func newNote() {
    guard canChange else { return }
    error = nil
    draft = Scrap(kind: .note, title: "Untitled scrap", text: "")
  }

  func edit() {
    guard canChange, let selected else { return }
    error = nil
    draft = selected
  }

  func saveDraft(_ scrap: Scrap) {
    run {
      var updated = scrap
      updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
      updated.modified = .now
      var next = self.scraps.filter { $0.id != updated.id }
      next.append(updated)
      try await self.store.save(next)
      self.scraps = next
      self.query = ""
      self.showArchive = updated.archived
      self.selection = updated.id
      self.draft = nil
      self.notice = "Saved locally. The binding is holding up remarkably well."
    }
  }

  func archiveOrRestore() {
    guard let selected else { return }
    run {
      let next = self.scraps.map { entry in
        var entry = entry
        if entry.id == selected.id {
          entry.archived.toggle()
          entry.modified = .now
        }
        return entry
      }
      try await self.store.save(next)
      self.scraps = next
      self.selection = self.visible.first?.id
      self.notice =
        selected.archived ? "Restored to the shelf." : "Archived. You can restore it from Archive."
    }
  }

  func chooseFile() {
    guard canChange else { return }
    let panel = NSOpenPanel()
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.plainText, .sourceCode, .json, .png, .jpeg, .tiff, .heic, .gif]
    panel.prompt = "Add to Scrapbook"
    panel.message =
      "Text up to 1 MB. Images up to 25 MB are kept as PNG snapshots, up to 4096 pixels on the longest edge."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run { try await self.add(self.store.importFile(url)) }
  }

  func pasteAsNew() {
    guard canChange else { return }
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
      let url = urls.first
    {
      run { try await self.add(self.store.importFile(url)) }
    } else if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
      run { try await self.add(self.store.importImage(data)) }
    } else if let text = pasteboard.string(forType: .string) {
      guard text.utf8.count <= ScrapbookStore.textLimit else {
        error = ScrapbookError.tooLarge.localizedDescription
        return
      }
      let title = String(
        text.split(whereSeparator: \.isNewline).first?.prefix(80) ?? "Pasted scrap")
      let scrap = Scrap(
        kind: Scrap.webURL(text) == nil ? .note : .link,
        title: title.trimmingCharacters(in: .whitespaces).isEmpty ? "Pasted scrap" : title,
        text: text)
      run { try await self.add(ScrapImport(scrap: scrap)) }
    } else {
      error = "Copy some text, a web address, or an image, then choose Paste as New."
    }
  }

  private func add(_ item: ScrapImport) async throws {
    let next = scraps + [item.scrap]
    try await store.save(next, image: item)
    scraps = next
    showArchive = false
    query = ""
    selection = item.scrap.id
    notice = "Added to the scrapbook. No extra glue required."
  }

  func copySelected() {
    guard let selected else { return }
    run {
      if selected.kind == .image {
        let data = try await self.store.imageData(selected.id)
        self.pasteboard.clearContents()
        self.pasteboard.setData(data, forType: .png)
      } else {
        self.pasteboard.clearContents()
        self.pasteboard.setString(selected.text, forType: .string)
      }
      self.notice = "Copied."
    }
  }

  func openLink() {
    guard selected?.kind == .link, let url = selected?.link else { return }
    if !NSWorkspace.shared.open(url) { error = "macOS could not open this link." }
  }

  private func run(_ operation: @escaping @MainActor () async throws -> Void) {
    guard canChange else { return }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do { try await operation() } catch { self.error = error.localizedDescription }
    }
  }
}
