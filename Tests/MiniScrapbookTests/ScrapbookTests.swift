import AppKit
import Testing

@testable import MiniScrapbook

private func temporaryLibrary() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ScrapbookTests-\(UUID())")
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

@Test @MainActor func pasteAndCopyRoundTripWithoutWatchingTheClipboard() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let board = NSPasteboard.withUniqueName()
  defer { board.releaseGlobally() }
  let model = ScrapbookModel(directory: root, pasteboard: board)
  await model.load()
  board.setString("https://example.com/hello-mini", forType: .string)
  #expect(model.scraps.isEmpty)
  model.pasteAsNew()
  try await finishWrite(model)
  #expect(model.selected?.kind == .link)
  board.clearContents()
  board.setString("Another clipboard item", forType: .string)
  #expect(model.scraps.count == 1)
  model.copySelected()
  try await finishWrite(model)
  #expect(board.string(forType: .string) == "https://example.com/hello-mini")
  board.clearContents()
  board.setString(String(repeating: "x", count: ScrapbookStore.textLimit + 1), forType: .string)
  model.pasteAsNew()
  #expect(model.error != nil && model.scraps.count == 1)
}

@MainActor private func finishWrite(_ model: ScrapbookModel) async throws {
  let deadline = ContinuousClock.now.advanced(by: .seconds(3))
  while model.busy && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
  try #require(!model.busy)
}

@Test func searchMatchesAllWordsAcrossTitleContentsAndKind() {
  let scrap = Scrap(kind: .command, title: "Café builds", text: "swift test --parallel")
  #expect(scrap.matches("CAFE parallel command"))
  #expect(scrap.matches("  swift   builds "))
  #expect(scrap.matches(""))
  #expect(!scrap.matches("swift deployment"))
  #expect(Scrap.webURL("https://example.com/a?q=fish") != nil)
  for value in [
    "javascript:alert(1)", "file:///tmp/file", "ssh://host", "https://",
    "https://example.com\nrun this",
  ] {
    #expect(Scrap.webURL(value) == nil)
  }
}

@Test func libraryRoundTripsArchivesAndKeepsThePreviousCompleteIndex() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  #expect(try await store.load().isEmpty)
  let original = Scrap(kind: .note, title: "A little note", text: "hello, again.")
  try await store.save([original])
  var archived = original
  archived.archived = true
  try await store.save([archived])
  #expect(try await ScrapbookStore(directory: root).load() == [archived])
  let backup = try JSONDecoder().decode(
    ScrapbookDocument.self,
    from: Data(contentsOf: root.appendingPathComponent("scrapbook.previous.json")))
  #expect(backup.scraps == [original])
  archived.archived = false
  try await store.save([archived])
  #expect(try await store.load() == [original])
}

@Test @MainActor func malformedAndFutureLibrariesRemainUntouchedAndReadOnly() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let path = root.appendingPathComponent("scrapbook.json")
  for data in [
    Data("not json".utf8), try JSONEncoder().encode(ScrapbookDocument(version: 99, scraps: [])),
  ] {
    try data.write(to: path)
    let model = ScrapbookModel(directory: root)
    await model.load()
    #expect(!model.ready && !model.canChange && model.error != nil)
    model.newNote()
    #expect(model.draft == nil)
    #expect(try Data(contentsOf: path) == data)
  }
}

@Test func invalidSaveDoesNotReplaceTheLibrary() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  let note = Scrap(kind: .note, title: "Keep me", text: "A perfectly good scrap.")
  try await store.save([note])
  await #expect(throws: ScrapbookError.self) {
    try await store.save([Scrap(kind: .link, title: "Bad link", text: "file:///tmp/example")])
  }
  #expect(try await store.load() == [note])
}

@Test @MainActor func importedImageIsOwnedByScrapbookAndTextImportPreservesCommands() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root.appendingPathComponent("library"))
  let bitmap = try #require(
    NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 16, pixelsHigh: 16, bitsPerSample: 8,
      samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 64, bitsPerPixel: 32))
  let pixels = try #require(bitmap.bitmapData)
  for y in 0..<16 {
    for x in 0..<16 {
      let offset = (y * 16 + x) * 4
      let value: UInt8 = (x + y).isMultiple(of: 2) ? 0 : 255
      pixels[offset] = value
      pixels[offset + 1] = value
      pixels[offset + 2] = value
      pixels[offset + 3] = 255
    }
  }
  let original = root.appendingPathComponent("checkers.png")
  try #require(bitmap.representation(using: .png, properties: [:])).write(to: original)
  let item = try await store.importFile(original)
  #expect(item.scrap.kind == .image && item.scrap.title == "checkers")
  try await store.save([item.scrap], image: item)
  try FileManager.default.removeItem(at: original)
  let copiedData = try await store.imageData(item.scrap.id)
  let image = try #require(NSBitmapImageRep(data: copiedData))
  #expect(image.pixelsWide == 16 && image.pixelsHigh == 16)
  #expect(image.colorAt(x: 0, y: 0) != image.colorAt(x: 1, y: 0))
  let commandFile = root.appendingPathComponent("build.sh")
  let text = "echo 'hello'\nswift test\n"
  try Data(text.utf8).write(to: commandFile)
  let command = try await store.importFile(commandFile)
  #expect(command.scrap.text == text)
  #expect(command.scrap.kind == .note)
}

@Test @MainActor func failedWriteKeepsDraftAndPreviouslyLoadedScraps() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let directory = root.appendingPathComponent("library")
  let store = ScrapbookStore(directory: directory)
  let existing = Scrap(kind: .note, title: "Existing", text: "Keep this")
  try await store.save([existing])
  let model = ScrapbookModel(directory: directory)
  await model.load()
  model.newNote()
  let draft = try #require(model.draft)
  try FileManager.default.moveItem(at: directory, to: root.appendingPathComponent("preserved"))
  try Data("blocks directory creation".utf8).write(to: directory)
  model.saveDraft(draft)
  let deadline = ContinuousClock.now.advanced(by: .seconds(3))
  while model.busy && ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
  #expect(!model.busy && model.error != nil)
  #expect(model.draft == draft)
  #expect(model.scraps == [existing])
}

@Test @MainActor func desktopCaptureLoadsLibraryAndPreservesClipboard() async throws {
  let root = try temporaryLibrary()
  defer { try? FileManager.default.removeItem(at: root) }
  let board = NSPasteboard.withUniqueName()
  defer { board.releaseGlobally() }
  board.setString("Keep my clipboard", forType: .string)
  let context = try #require(
    CGContext(
      data: nil, width: 32, height: 24, bitsPerComponent: 8,
      bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(NSColor.white.cgColor)
  context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
  let image = try #require(context.makeImage())
  let model = ScrapbookModel(directory: root, pasteboard: board)
  await model.captureDesktop(image)
  #expect(model.error == nil)
  #expect(model.selected?.kind == .image)
  #expect(model.selected?.title.hasPrefix("Desktop — ") == true)
  #expect(board.string(forType: .string) == "Keep my clipboard")
  let restored = ScrapbookModel(directory: root, pasteboard: board)
  await restored.load()
  #expect(restored.scraps.count == 1)
  let id = try #require(restored.selected?.id)
  #expect(try await restored.store.imageData(id).count > 0)
}
