import AppKit
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor @Observable final class ScrapbookModel {
  var scraps: [Scrap] = []
  var ready = false
  var busy = false {
    didSet { if !busy { recognizePending() } }
  }
  var recognitionSaveWarning: String?
  @ObservationIgnored var recognizedPending: [UUID: String] = [:]
  @ObservationIgnored var recognitionGeneration = UUID()
  @ObservationIgnored var recognitionPaused = false
  var openPaint: @MainActor (CGImage) throws -> Void = { _ in }
  var query = ""
  var collections: [String] = []
  var collection: String?
  var favouritesOnly = false
  var sort = ScrapSort.modified
  var showArchive = false
  var selecting = false
  var batchSelection: Set<UUID> = []
  var filingUndo: ScrapFilingUndo?
  var filingPulse = 0
  var selection: UUID?
  var archivePreview: ScrapbookImportPreview?
  var draft: Scrap?
  var error: String?
  var notice = "An unreasonable amount of room for little things."
  @ObservationIgnored let store: ScrapbookStore
  @ObservationIgnored let pasteboard: NSPasteboard
  @ObservationIgnored let recognizer: @Sendable (Data) async throws -> String
  @ObservationIgnored var recognitionTask: Task<Void, Never>?
  /// The image scrap whose text is being read, if any.
  var reading: UUID?

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

  func openLink() {
    guard selected?.kind == .link, let url = selected?.link else { return }
    if !NSWorkspace.shared.open(url) { error = "macOS could not open this link." }
  }

  func run(_ operation: @escaping @MainActor () async throws -> Void) {
    guard canChange else { return }
    busy = true
    error = nil
    Task {
      defer { busy = false }
      do { try await operation() } catch { self.error = error.localizedDescription }
    }
  }
}
