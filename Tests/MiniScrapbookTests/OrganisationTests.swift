import Foundation
import Testing

@testable import MiniScrapbook

@Test func legacyLibraryMigrationRetainsScrapsAndOriginalIndex() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ScrapMigration-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let id = UUID()
  // The exact pre-0.12 shape: no collection/favourite fields or collection list.
  let bytes = Data(
    "{\"version\":1,\"scraps\":[{\"id\":\"\(id.uuidString)\",\"kind\":\"note\",\"title\":\"Legacy\",\"text\":\"Keep me\",\"created\":0,\"modified\":0,\"archived\":false}]}"
      .utf8)
  let index = root.appendingPathComponent("scrapbook.json")
  try bytes.write(to: index)
  let store = ScrapbookStore(directory: root)
  var scraps = try await store.load()
  #expect(scraps.count == 1 && scraps[0].id == id && !scraps[0].isFavourite)
  scraps[0].collection = "Work"
  scraps[0].favourite = true
  try await store.save(scraps, collections: ["Empty", "Work"])
  #expect(try Data(contentsOf: root.appendingPathComponent("scrapbook.v1.json")) == bytes)
  let reopened = ScrapbookStore(directory: root)
  #expect(try await reopened.load() == scraps)
  #expect(await reopened.collections == ["Empty", "Work"])
  let subset = try await store.archive(scraps, includeEmptyCollections: false)
  let subsetPreview = try await store.previewArchive(subset, existing: [])
  #expect(subsetPreview.collections == ["Work"])
  let archive = try await store.archive(scraps)
  let target = ScrapbookStore(directory: root.appendingPathComponent("imported"))
  let preview = try await target.previewArchive(archive, existing: [])
  let imported = try await target.importArchive(preview, existing: [])
  #expect(imported == scraps)
  #expect(await target.collections == ["Empty", "Work"])
  // A future library cannot be loaded or replaced even by a direct save.
  let future = Data("{\"version\":99,\"scraps\":[]}".utf8)
  try future.write(to: index)
  await #expect(throws: (any Error).self) { try await store.load() }
  await #expect(throws: (any Error).self) { try await store.save([]) }
  #expect(try Data(contentsOf: index) == future)
}

@Test @MainActor func collectionFilteringSearchFavouritesAndRemovalPreserveScraps() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "ScrapCollections-\(UUID())")
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  let first = Scrap(
    kind: .note, title: "Alpha", text: "needle", collection: "Work", favourite: true)
  let second = Scrap(kind: .note, title: "Beta", text: "needle", collection: "Personal")
  try await store.save([first, second])
  let model = ScrapbookModel(directory: root)
  await model.load()
  model.collection = "Work"
  model.query = "needle"
  model.favouritesOnly = true
  #expect(model.visible.map(\.id) == [first.id])
  model.query = "missing"
  #expect(model.visible.isEmpty)
  model.query = ""
  model.collection = nil
  model.favouritesOnly = false
  model.sort = .title
  #expect(model.visible.map(\.title) == ["Alpha", "Beta"])
  model.removeCollection("Work")
  for _ in 0..<100 where model.busy { try await Task.sleep(for: .milliseconds(10)) }
  #expect(!model.busy)
  #expect(model.scraps.count == 2 && model.scraps.first?.collection == nil)
  #expect(model.scraps.first?.isFavourite == true)
}
