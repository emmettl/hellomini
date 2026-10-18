import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class ScrapbookModel {
  private(set) var scraps: [Scrap] = []
  private(set) var ready = false
  private(set) var busy = false {
    didSet { if !busy { recognizePending() } }
  }
  private(set) var recognitionSaveWarning: String?
  @ObservationIgnored private var recognizedPending: [UUID: String] = [:]
  @ObservationIgnored private var recognitionGeneration = UUID()
  @ObservationIgnored private var recognitionPaused = false
  var openPaint: @MainActor (CGImage) throws -> Void = { _ in }
  var query = ""
  private(set) var collections: [String] = []
  var collection: String?
  var favouritesOnly = false
  var sort = ScrapSort.modified
  var showArchive = false
  var selection: UUID?
  var archivePreview: ScrapbookImportPreview?
  var draft: Scrap?
  var error: String?
  var notice = "An unreasonable amount of room for little things."
  @ObservationIgnored let store: ScrapbookStore
  @ObservationIgnored private let pasteboard: NSPasteboard
  @ObservationIgnored private let recognizer: @Sendable (Data) async throws -> String
  @ObservationIgnored private var recognitionTask: Task<Void, Never>?
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
    scraps.filter {
      $0.archived == showArchive && $0.matches(query)
        && (collection == nil || $0.collection == collection) && (!favouritesOnly || $0.isFavourite)
    }
    .sorted { sort.precedes($0, $1) }
  }

  var selected: Scrap? { visible.first { $0.id == selection } }
  var canChange: Bool { ready && !busy }

  func load() async {
    guard !ready && !busy else { return }
    busy = true
    defer { busy = false }
    do {
      scraps = try await store.load()
      collections = await store.collections
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

  func addCalculation(_ text: String) async throws {
    if !ready { await load() }
    guard canChange else { throw CocoaError(.fileWriteUnknown) }
    busy = true
    defer { busy = false }
    try await add(ScrapImport(scrap: Scrap(kind: .note, title: "Desk Calculator", text: text)))
  }

  func addDrawing(_ image: CGImage) async throws {
    if !ready { await load() }
    guard canChange else {
      throw CocoaError(
        .fileWriteUnknown,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Scrapbook is busy or unavailable. Export the drawing as PNG or try again."
        ])
    }
    busy = true
    defer { busy = false }
    guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { throw ScrapbookError.invalidImage }
    let item = try await store.importImage(
      data, title: "MiniPaint — " + Date.now.formatted(date: .abbreviated, time: .standard))
    try await add(item)
  }

  func openSelectedInPaint() {
    guard let selected, selected.kind == .image else { return }
    run {
      let data = try await self.store.imageData(selected.id)
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else { throw ScrapbookError.invalidImage }
      try self.openPaint(image)
    }
  }
  func addExamples() {
    run {
      let examples: [(ScrapKind, String, String)] = [
        (
          .note, "A small creative department",
          "Draw in MiniPaint, send your picture here, then choose Open Picture in MiniPaint to keep tinkering. Select part of a drawing and use it as your desktop pattern."
        ),
        (.command, "Check a download", "shasum -a 256 -c Hello-Mini-0.6.0-macos-arm64.zip.sha256"),
        (
          .note, "Department of Encouragement",
          "Your work has been reviewed by the fish. They request more bubbles.\n\nRemember to save. The computer remembers everything except what you meant."
        ),
      ]
      for (kind, title, text) in examples
      where !self.scraps.contains(where: { $0.title == title && $0.text == text }) {
        try await self.add(ScrapImport(scrap: Scrap(kind: kind, title: title, text: text)))
      }
      let title = "An entirely original office fish"
      if !self.scraps.contains(where: { $0.title == title }) {
        let w = 160
        let h = 100
        var pixels = [UInt8](repeating: 255, count: w * h)
        for y in 0..<h {
          for x in 0..<w {
            let dx = Double(x - 75) / 40
            let dy = Double(y - 50) / 24
            let body = dx * dx + dy * dy < 1
            let tail = x >= 110 && x < 140 && abs(y - 50) < (x - 110) * 3 / 4
            if body || tail { pixels[y * w + x] = 0 }
            if (x - 55) * (x - 55) + (y - 44) * (y - 44) < 9 { pixels[y * w + x] = 255 }
          }
        }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData),
          let image = CGImage(
            width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: w, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { throw ScrapbookError.invalidImage }
        try await self.add(self.store.importImage(png, title: title))
      }
      self.notice = "Example scraps added. The fish is available for alterations."
    }
  }
  func newNote() {
    guard canChange else { return }
    error = nil
    draft = Scrap(kind: .note, title: "Untitled scrap", text: "", collection: collection)
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
      try await self.persist(next)
      self.scraps = next
      self.query = ""
      self.collection = updated.collection
      self.favouritesOnly = false
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
      try await self.persist(next)
      self.scraps = next
      self.selection = self.visible.first?.id
      self.notice =
        selected.archived ? "Restored to the shelf." : "Archived. You can restore it from Archive."
    }
  }

  func organiseSelected(collection name: String?, favourite: Bool) {
    guard let selected else { return }
    run {
      var next = self.scraps
      guard let index = next.firstIndex(where: { $0.id == selected.id }),
        name == nil || self.collections.contains(name!)
      else { return }
      next[index].collection = name
      next[index].favourite = favourite
      try await self.persist(next)
      self.scraps = next
      self.selection =
        self.visible.contains(where: { $0.id == selected.id })
        ? selected.id : self.visible.first?.id
    }
  }

  func createCollection(_ raw: String) {
    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    run {
      let names = try ScrapbookStore.validatedCollections(self.collections + [name])
      try await self.store.save(self.scraps, collections: names)
      self.collections = names
      self.collection = name
      self.selection = self.visible.first?.id
    }
  }

  func removeCollection(_ name: String) {
    run {
      var next = self.scraps
      for i in next.indices where next[i].collection == name { next[i].collection = nil }
      let names = self.collections.filter { $0 != name }
      try await self.store.save(next, collections: names)
      self.scraps = next
      self.collections = names
      self.collection = nil
      self.selection = self.visible.first?.id
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
    try await persist(next, image: item)
    scraps = next
    showArchive = false
    query = ""
    collection = nil
    favouritesOnly = false
    selection = item.scrap.id
    notice = "Added to the scrapbook. No extra glue required."
    if item.scrap.kind == .image { recognizePending() }
  }

  private func persist(_ entries: [Scrap], image: ScrapImport? = nil) async throws {
    try await store.save(entries, image: image)
    recognitionSaveWarning = nil
  }
  func resumeRecognition() {
    recognitionPaused = false
    recognizePending()
  }
  func stopRecognition() {
    recognitionPaused = true
    recognitionGeneration = UUID()
    recognitionTask?.cancel()
    recognitionTask = nil
    reading = nil
  }
  /// Completed results wait in memory until the current edit finishes; no polling or busy waiting.
  func recognizePending() {
    guard ready, !busy, !recognitionPaused, recognitionTask == nil,
      scraps.contains(where: { $0.awaitingRecognition })
    else { return }
    let generation = UUID()
    recognitionGeneration = generation
    recognitionTask = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled, self.recognitionGeneration == generation, !self.busy,
        let scrap = self.scraps.first(where: { $0.awaitingRecognition })
      {
        self.reading = scrap.id
        let text: String
        if let pending = self.recognizedPending.removeValue(forKey: scrap.id) {
          text = pending
        } else {
          do {
            let data = try await self.store.imageData(scrap.id)
            text = String(
              try await self.recognizer(data).trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(ScrapbookStore.recognitionLimit))
          } catch {
            guard !Task.isCancelled, self.recognitionGeneration == generation else { return }
            text = ""
          }
        }
        guard !Task.isCancelled, self.recognitionGeneration == generation else { return }
        self.reading = nil
        if self.busy {
          self.recognizedPending[scrap.id] = text
          break
        }
        guard
          let index = self.scraps.firstIndex(where: { $0.id == scrap.id && $0.awaitingRecognition })
        else { continue }
        var next = self.scraps
        next[index].recognizedText = text
        self.busy = true
        do { try await self.persist(next) } catch {
          self.recognitionSaveWarning =
            "Picture text is searchable in this session but could not be saved. The next successful library edit will save it."
        }
        self.scraps = next
        self.busy = false
      }
      guard self.recognitionGeneration == generation else { return }
      self.reading = nil
      self.recognitionTask = nil
      // An edit may have finished while the recognizer was returning.
      self.recognizePending()
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

  func exportSelected() {
    guard canChange, let selected else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = selected.kind == .image ? [.png] : [.plainText]
    panel.nameFieldStringValue = "Scrap." + (selected.kind == .image ? "png" : "txt")
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      try await self.store.exportScrap(selected, to: url)
      self.notice = "Exported this page. No scissors required."
    }
  }

  func exportArchive(all: Bool) {
    guard canChange else { return }
    let scraps = all ? self.scraps : visible
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.nameFieldStringValue = all ? "HelloMini-Scrapbook-Backup.json" : "HelloMini-Scraps.json"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      try await self.store.writeArchive(scraps, to: url, includeEmptyCollections: all)
      self.notice = "Exported \(scraps.count) scraps, including their pictures."
    }
  }

  func chooseArchive() {
    guard canChange else { return }
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.json]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run {
      self.archivePreview = try await self.store.previewArchive(at: url, existing: self.scraps)
    }
  }

  func confirmArchiveImport(_ preview: ScrapbookImportPreview) {
    run {
      self.scraps = try await self.store.importArchive(preview, existing: self.scraps)
      self.collections = await self.store.collections
      self.collection = nil
      self.favouritesOnly = false
      self.recognitionSaveWarning = nil
      self.archivePreview = nil
      self.query = ""
      self.showArchive = false
      self.selection = self.visible.first?.id
      self.notice =
        "Imported \(preview.entries.count) scraps; skipped \(preview.skipped) duplicates."
      self.recognizePending()
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
