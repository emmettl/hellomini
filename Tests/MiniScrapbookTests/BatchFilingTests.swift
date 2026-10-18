import Foundation
import Testing

@testable import MiniScrapbook

@MainActor private func waitForFiling(_ model: ScrapbookModel) async throws {
  for _ in 0..<200 where model.busy { try await Task.sleep(for: .milliseconds(5)) }
  #expect(!model.busy)
  #expect(model.error == nil)
}
@Test @MainActor func batchFilingRenameArchiveAndUndoPreserveContents() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("Batch-\(UUID())")
  defer { try? FileManager.default.removeItem(at: root) }
  let first = Scrap(kind: .note, title: "A", text: "keep", collection: "Work")
  let second = Scrap(kind: .note, title: "B", text: "also keep", collection: "Work")
  let store = ScrapbookStore(directory: root)
  try await store.save([first, second], collections: ["Empty", "Work"])
  let model = ScrapbookModel(directory: root)
  await model.load()
  model.renameCollection("Work", to: "Projects")
  try await waitForFiling(model)
  #expect(model.scraps.allSatisfy { $0.collection == "Projects" })
  model.undoFiling()
  try await waitForFiling(model)
  #expect(model.collections == ["Empty", "Work"])
  model.selecting = true
  model.batchSelection = [first.id, second.id]
  model.favouriteSelection(true)
  try await waitForFiling(model)
  #expect(model.scraps.allSatisfy { $0.isFavourite })
  model.batchSelection = [first.id, second.id]
  model.archiveOrRestore()
  try await waitForFiling(model)
  #expect(model.visible.isEmpty && model.scraps.count == 2)
  model.undoFiling()
  try await waitForFiling(model)
  #expect(model.visible.count == 2 && model.scraps.allSatisfy { $0.isFavourite })
  model.removeCollection("Work")
  try await waitForFiling(model)
  // OCR/text changes are kept while organisation is restored.
  model.scraps[0].recognizedText = "new text"
  model.undoFiling()
  try await waitForFiling(model)
  #expect(model.scraps[0].recognizedText == "new text")
  #expect(model.scraps.map(\.text) == ["keep", "also keep"])
  #expect(try await store.load().allSatisfy { $0.collection == "Work" })
}
@Test @MainActor func batchActionsRespectVisibleScopeAndFailedSaveKeepsState() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("BatchFailure-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let store = ScrapbookStore(directory: root)
  let first = Scrap(kind: .note, title: "A", text: "visible")
  let hidden = Scrap(kind: .note, title: "B", text: "hidden", archived: true)
  try await store.save([first, hidden])
  let model = ScrapbookModel(directory: root)
  await model.load()
  model.selecting = true
  model.batchSelection = [first.id, hidden.id]
  model.favouriteSelection(true)
  try await waitForFiling(model)
  #expect(model.scraps[0].isFavourite && !model.scraps[1].isFavourite)
  let before = model.scraps
  let index = root.appendingPathComponent("scrapbook.json")
  try FileManager.default.removeItem(at: index)
  try FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
  model.renameCollection("missing", to: "ignored")
  try await waitForFiling(model)
  model.batchSelection = [first.id]
  model.archiveOrRestore()
  for _ in 0..<200 where model.busy { try await Task.sleep(for: .milliseconds(5)) }
  #expect(model.error != nil && model.scraps == before)
}
