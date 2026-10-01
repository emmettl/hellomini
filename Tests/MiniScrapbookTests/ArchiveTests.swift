import AppKit
import Testing

@testable import MiniScrapbook

private func archiveDirectory() throws -> URL {
  let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ScrapArchiveTests-\(UUID())")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}
private func imageBytes() throws -> Data {
  let bitmap = try #require(
    NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 32, bitsPerPixel: 32
    ))
  bitmap.bitmapData?.initialize(repeating: 255, count: 256)
  return try #require(bitmap.representation(using: .png, properties: [:]))
}
@Test func backupRoundTripsNotesImagesAndArchiveState() async throws {
  let source = try archiveDirectory()
  let target = try archiveDirectory()
  defer {
    try? FileManager.default.removeItem(at: source)
    try? FileManager.default.removeItem(at: target)
  }
  let store = ScrapbookStore(directory: source)
  let other = ScrapbookStore(directory: target)
  let image = try await store.importImage(imageBytes(), title: "Drawing")
  let note = Scrap(kind: .note, title: "Note", text: "Keep me", archived: true)
  try await store.save([note, image.scrap], image: image)
  let backup = source.appendingPathComponent("backup.json")
  try await store.writeArchive([note, image.scrap], to: backup)
  let preview = try await other.previewArchive(at: backup, existing: [])
  let imported = try await other.importArchive(preview, existing: [])
  #expect(imported.count == 2 && imported[0].archived)
  #expect(try await other.imageData(image.scrap.id) == image.image)
  #expect(try await other.load() == imported)
  let repeatPreview = try await other.previewArchive(at: backup, existing: imported)
  #expect(repeatPreview.entries.isEmpty && repeatPreview.skipped == 2)
}
@Test func duplicateContentIsSkippedAndConflictingIDsArePreservedSeparately() async throws {
  let dir = try archiveDirectory()
  defer { try? FileManager.default.removeItem(at: dir) }
  let store = ScrapbookStore(directory: dir)
  let original = Scrap(kind: .command, title: "Build", text: "swift build")
  var copy = original
  copy.id = UUID()
  copy.modified = .now.addingTimeInterval(10)
  var conflict = original
  conflict.text = "swift test"
  let archive = ScrapbookArchive(entries: [.init(scrap: copy), .init(scrap: conflict)])
  let preview = try await store.previewArchive(JSONEncoder().encode(archive), existing: [original])
  #expect(preview.skipped == 1 && preview.renamedIDs == 1)
  #expect(preview.entries.first?.scrap.id != original.id)
  let next = try await store.importArchive(preview, existing: [original])
  #expect(next.count == 2 && next[0] == original && next[1].text == "swift test")
}
@Test func invalidBackupsFailBeforeChangingLibrary() async throws {
  let dir = try archiveDirectory()
  defer { try? FileManager.default.removeItem(at: dir) }
  let store = ScrapbookStore(directory: dir)
  let original = Scrap(kind: .note, title: "Original", text: "Keep this")
  try await store.save([original])
  var future = ScrapbookArchive(entries: [])
  future.version = 2
  await #expect(throws: ScrapbookArchiveError.self) {
    try await store.previewArchive(JSONEncoder().encode(future), existing: [original])
  }
  let missingImage = ScrapbookArchive(entries: [
    .init(scrap: Scrap(kind: .image, title: "Broken", text: ""))
  ])
  await #expect(throws: ScrapbookArchiveError.self) {
    try await store.previewArchive(JSONEncoder().encode(missingImage), existing: [original])
  }
  #expect(try await store.load() == [original])
}
@Test func failedImportRollsBackOnlyNewImageFiles() async throws {
  let dir = try archiveDirectory()
  defer { try? FileManager.default.removeItem(at: dir) }
  let store = ScrapbookStore(directory: dir)
  let image = try await store.importImage(imageBytes(), title: "Drawing")
  let preview = ScrapbookImportPreview(
    entries: [.init(scrap: image.scrap, image: image.image)], skipped: 0, renamedIDs: 0)
  // A directory where the index should go forces the index write to fail after staging the PNG.
  try FileManager.default.createDirectory(
    at: dir.appendingPathComponent("scrapbook.json"), withIntermediateDirectories: true)
  await #expect(throws: (any Error).self) { try await store.importArchive(preview, existing: []) }
  #expect(
    !FileManager.default.fileExists(
      atPath: dir.appendingPathComponent(image.scrap.id.uuidString + ".png").path))
  #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("scrapbook.json").path))
}
