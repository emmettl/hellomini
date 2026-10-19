import AppKit
import Testing

@testable import MiniScrapbook

@Test func completeLegacyLibraryAndImagesSurviveUpgradeAndBlockedMigration() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "UpgradeLibrary-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let bitmap = try #require(
    NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
      colorSpaceName: .deviceRGB, bytesPerRow: 32, bitsPerPixel: 32))
  bitmap.bitmapData?.initialize(repeating: 255, count: 256)
  let png = try #require(bitmap.representation(using: .png, properties: [:]))
  let picture = Scrap(
    kind: .image, title: "Archived picture", text: "caption", archived: true,
    recognizedText: "already read")
  let note = Scrap(kind: .note, title: "Note", text: "preserve contents")
  let legacy = try JSONEncoder().encode(ScrapbookDocument(version: 1, scraps: [note, picture]))
  let index = root.appendingPathComponent("scrapbook.json")
  try legacy.write(to: index)
  try png.write(to: root.appendingPathComponent(picture.id.uuidString + ".png"))
  let store = ScrapbookStore(directory: root)
  var scraps = try await store.load()
  scraps[0].collection = "Work"
  scraps[0].favourite = true
  let migration = root.appendingPathComponent("scrapbook.v1.json")
  try FileManager.default.createDirectory(at: migration, withIntermediateDirectories: true)
  await #expect(throws: (any Error).self) {
    try await store.save(scraps, collections: ["Empty", "Work"])
  }
  #expect(try Data(contentsOf: index) == legacy)
  #expect(try await store.imageData(picture.id) == png)
  try FileManager.default.removeItem(at: migration)
  try await store.save(scraps, collections: ["Empty", "Work"])
  #expect(try Data(contentsOf: migration) == legacy)
  let reopened = ScrapbookStore(directory: root)
  #expect(try await reopened.load() == scraps)
  let archive = try await reopened.archive(scraps)
  let target = ScrapbookStore(directory: root.appendingPathComponent("restored"))
  let preview = try await target.previewArchive(archive, existing: [])
  #expect(try await target.importArchive(preview, existing: []) == scraps)
  #expect(try await target.imageData(picture.id) == png)
  #expect(await target.collections == ["Empty", "Work"])
}

@Test func lateUnreadableIndexBlocksImageAndBackupReplacement() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("LateIndex-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  let note = Scrap(kind: .note, title: "Keep", text: "original")
  try await store.save([note])
  _ = try await store.load()
  let index = root.appendingPathComponent("scrapbook.json")
  let previous = root.appendingPathComponent("scrapbook.previous.json")
  let sentinel = Data("preserved backup".utf8)
  try sentinel.write(to: previous)
  for bytes in [Data("broken".utf8), Data(#"{"version":99,"scraps":[]}"#.utf8)] {
    try bytes.write(to: index)
    await #expect(throws: (any Error).self) { try await store.save([note]) }
    #expect(try Data(contentsOf: index) == bytes)
    #expect(try Data(contentsOf: previous) == sentinel)
  }
}
