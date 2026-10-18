import Foundation
import Testing

@testable import MiniFinder

@Test func redoRoundTripsAllSupportedOperationsAndCanUndoAgain() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("Redo-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let reader = DirectoryReader()
  let original = root.appendingPathComponent("original")
  let destination = root.appendingPathComponent("destination")
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
  for kind in [FileOperationDraft.Kind.newFolder, .rename, .move] {
    if kind != .newFolder { try Data("keep".utf8).write(to: original) }
    let (item, undo) = try await reader.performWithUndo(
      .init(
        kind: kind, source: kind == .newFolder ? nil : original,
        folder: kind == .move ? destination : root, name: "item"))
    let redo = try await reader.undoWithRedo(#require(undo))
    #expect(!FileManager.default.fileExists(atPath: item.path))
    let again = try await reader.redo(#require(redo))
    #expect(FileManager.default.fileExists(atPath: item.path))
    try await reader.undo(#require(again))
    if kind != .newFolder { #expect(try String(contentsOf: original, encoding: .utf8) == "keep") }
  }
}
@Test func redoRefusesChangedSourcesOccupiedDestinationsAndReplacedParents() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("RedoRefused-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("a")
  try Data("keep".utf8).write(to: source)
  let reader = DirectoryReader()
  let (_, undo) = try await reader.performWithUndo(
    .init(kind: .rename, source: source, folder: root, name: "b"))
  let redo = try await reader.undoWithRedo(#require(undo))
  let occupied = root.appendingPathComponent("b")
  try FileManager.default.createSymbolicLink(atPath: occupied.path, withDestinationPath: "/missing")
  await #expect(throws: (any Error).self) { try await reader.redo(#require(redo)) }
  try FileManager.default.removeItem(at: occupied)
  try Data("changed".utf8).write(to: source)
  await #expect(throws: (any Error).self) { try await reader.redo(#require(redo)) }
  #expect(try String(contentsOf: source, encoding: .utf8) == "changed")
  let parent = root.appendingPathComponent("parent")
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  let (_, folderUndo) = try await reader.performWithUndo(
    .init(kind: .newFolder, source: nil, folder: parent, name: "folder"))
  let folderRedo = try await reader.undoWithRedo(#require(folderUndo))
  try FileManager.default.moveItem(at: parent, to: root.appendingPathComponent("old-parent"))
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
  await #expect(throws: (any Error).self) { try await reader.redo(#require(folderRedo)) }
  #expect(!FileManager.default.fileExists(atPath: parent.appendingPathComponent("folder").path))
}
