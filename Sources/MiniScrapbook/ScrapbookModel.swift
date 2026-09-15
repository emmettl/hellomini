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
  @ObservationIgnored private let recognizer: @Sendable (Data) async throws -> String
  @ObservationIgnored private var recognitionTask: Task<Void, Never>?
  @ObservationIgnored private var recognitionRequested = false
  /// The image scrap whose text is being read, if any.
  private(set) var reading: UUID?

  init(
    directory: URL? = nil, pasteboard: NSPasteboard = .general,
    recognizer: @escaping @Sendable (Data) async throws -> String = {
      try await ScrapTextRecognizer.recognize($0)
    }
  ) {
    self.pasteboard = pasteboard
    self.recognizer = recognizer
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
      recognizePending()
    } catch { self.error = error.localizedDescription }
  }

  func captureDesktop(_ image: CGImage) async {
    if !ready { await load() }
    guard canChange else {
      if error == nil { error = "Scrapbook is busy. Try capturing the desktop again." }
      return
    }
    busy = true
    defer { busy = false }
    do {
      guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
      else {
        throw ScrapbookError.invalidImage
      }
      var item = try await store.importImage(data)
      item.scrap.title = "Desktop — " + Date.now.formatted(date: .abbreviated, time: .standard)
      try await add(item)
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
    if item.scrap.kind == .image { recognizePending() }
  }

  /// Reads text from image scraps one at a time, on this Mac, between the user's own edits.
  func recognizePending() {
    guard ready else { return }
    recognitionRequested = true
    guard recognitionTask == nil else { return }
    recognitionTask = Task { [weak self] in
      while let self, self.recognitionRequested {
        self.recognitionRequested = false
        await self.drainRecognition()
      }
      self?.recognitionTask = nil
    }
  }

  private func drainRecognition() async {
    var attempted = Set<UUID>()
    while let scrap = scraps.first(where: { $0.awaitingRecognition && !attempted.contains($0.id) })
    {
      attempted.insert(scrap.id)
      reading = scrap.id
      let text: String
      do {
        let data = try await store.imageData(scrap.id)
        text = try await recognizer(data).trimmingCharacters(in: .whitespacesAndNewlines)
      } catch {
        // An unreadable picture is recorded as having no text rather than retried on every launch.
        text = ""
      }
      reading = nil
      while busy { try? await Task.sleep(for: .milliseconds(40)) }
      guard let index = scraps.firstIndex(where: { $0.id == scrap.id }),
        scraps[index].awaitingRecognition
      else { continue }
      var next = scraps
      next[index].recognizedText = String(text.prefix(ScrapbookStore.recognitionLimit))
      busy = true
      // A failed write still helps search now; the text is saved with the next successful change.
      try? await store.save(next)
      scraps = next
      busy = false
    }
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
