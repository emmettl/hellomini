import Foundation
import Testing

@testable import MiniFinder

@Test func undoRestoresRenameAndMoveWithoutReplacingAnOccupiedName() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("Undo-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("original")
  try Data("keep".utf8).write(to: source)
  let reader = DirectoryReader()
  let (renamed, receipt) = try await reader.performWithUndo(
    .init(kind: .rename, source: source, folder: root, name: "renamed"))
  try await reader.undo(#require(receipt))
  #expect(try Data(contentsOf: source) == Data("keep".utf8))
  #expect(!FileManager.default.fileExists(atPath: renamed.path))
  let destination = root.appendingPathComponent("destination")
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
  let (moved, moveReceipt) = try await reader.performWithUndo(
    .init(kind: .move, source: source, folder: destination, name: "moved"))
  try FileManager.default.createSymbolicLink(
    atPath: source.path, withDestinationPath: "/missing-undo-target")
  await #expect(throws: (any Error).self) { try await reader.undo(#require(moveReceipt)) }
  #expect(try Data(contentsOf: moved) == Data("keep".utf8))
  try FileManager.default.removeItem(at: source)
  try await reader.undo(#require(moveReceipt))
  #expect(try Data(contentsOf: source) == Data("keep".utf8))
}

@Test func undoRefusesEditedReplacedAndPopulatedItems() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("UndoChanges-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let reader = DirectoryReader()
  let (folder, folderReceipt) = try await reader.performWithUndo(
    .init(kind: .newFolder, source: nil, folder: root, name: "empty"))
  let child = folder.appendingPathComponent("added")
  try Data("new work".utf8).write(to: child)
  await #expect(throws: (any Error).self) { try await reader.undo(#require(folderReceipt)) }
  #expect(try Data(contentsOf: child) == Data("new work".utf8))
  let (_, renamedReceipt) = try await reader.performWithUndo(
    .init(kind: .rename, source: folder, folder: root, name: "renamed"))
  let edited = root.appendingPathComponent("renamed/added")
  try Data("edited work".utf8).write(to: edited)
  await #expect(throws: (any Error).self) { try await reader.undo(#require(renamedReceipt)) }
  #expect(try Data(contentsOf: edited) == Data("edited work".utf8))
  let (empty, receipt) = try await reader.performWithUndo(
    .init(kind: .newFolder, source: nil, folder: root, name: "undo-empty"))
  try await reader.undo(#require(receipt))
  #expect(!FileManager.default.fileExists(atPath: empty.path))
  let (replacement, replacedReceipt) = try await reader.performWithUndo(
    .init(kind: .newFolder, source: nil, folder: root, name: "replace"))
  try FileManager.default.moveItem(at: replacement, to: root.appendingPathComponent("keep-old"))
  try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: false)
  await #expect(throws: (any Error).self) { try await reader.undo(#require(replacedReceipt)) }
  #expect(FileManager.default.fileExists(atPath: replacement.path))
}

@Test func undoRefusesReplacedOriginalParentAndCopyDoesNotOfferUndo() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("UndoParent-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let parent = root.appendingPathComponent("parent")
  let destination = root.appendingPathComponent("destination")
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
  let source = parent.appendingPathComponent("source")
  try Data("keep".utf8).write(to: source)
  let reader = DirectoryReader()
  let (moved, receipt) = try await reader.performWithUndo(
    .init(kind: .move, source: source, folder: destination, name: "moved"))
  try FileManager.default.moveItem(at: parent, to: root.appendingPathComponent("old-parent"))
  try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
  await #expect(throws: (any Error).self) { try await reader.undo(#require(receipt)) }
  #expect(try Data(contentsOf: moved) == Data("keep".utf8))
  let (_, copiedReceipt) = try await reader.performWithUndo(
    .init(kind: .copy, source: moved, folder: parent, name: "copy"))
  #expect(copiedReceipt == nil)
}
