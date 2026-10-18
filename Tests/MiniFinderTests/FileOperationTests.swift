import Foundation
import Testing

@testable import MiniFinder

@Test func fileOperationsNeverReplaceAndCopyKeepsSourceAndLinks() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "FileOperations-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source.txt")
  try Data("original".utf8).write(to: source)
  let reader = DirectoryReader()
  let folder = try await reader.perform(
    .init(kind: .newFolder, source: nil, folder: root, name: "Copies"))
  let copied = try await reader.perform(
    .init(kind: .copy, source: source, folder: folder, name: "copy.txt"))
  #expect(try Data(contentsOf: copied) == Data(contentsOf: source))
  await #expect(throws: (any Error).self) {
    try await reader.perform(.init(kind: .copy, source: source, folder: folder, name: "copy.txt"))
  }
  await #expect(throws: (any Error).self) {
    try await reader.perform(.init(kind: .rename, source: source, folder: root, name: "Copies"))
  }
  #expect(try String(contentsOf: source, encoding: .utf8) == "original")
  let renamed = try await reader.perform(
    .init(kind: .rename, source: source, folder: root, name: "renamed.txt"))
  #expect(!FileManager.default.fileExists(atPath: source.path))
  let link = root.appendingPathComponent("link")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: renamed)
  let copiedLink = try await reader.perform(
    .init(kind: .copy, source: link, folder: folder, name: "link-copy"))
  #expect(
    try FileManager.default.destinationOfSymbolicLink(atPath: copiedLink.path) == renamed.path)
  await #expect(throws: (any Error).self) {
    try await reader.perform(.init(kind: .copy, source: root, folder: folder, name: "recursive"))
  }
  #expect(
    try FileManager.default.contentsOfDirectory(atPath: folder.path).allSatisfy {
      !$0.hasPrefix(".HelloMini-copy-")
    })
  for bad in ["", ".", "..", "../bad", "a:b", "a\nb", "x\0y"] {
    #expect(throws: (any Error).self) { try DirectoryReader.validatedName(bad) }
  }
}

@Test func moveIsExclusiveAndCopyCancellationCleansStaging() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("Transfer-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source")
  try Data(repeating: 65, count: 2 * 1024 * 1024).write(to: source)
  let reader = DirectoryReader()
  let destination = try await reader.perform(
    .init(kind: .newFolder, source: nil, folder: root, name: "dest"))
  let task = Task {
    try await reader.perform(
      .init(kind: .copy, source: source, folder: destination, name: "cancelled")
    ) { _ in
      withUnsafeCurrentTask { $0?.cancel() }
    }
  }
  await #expect(throws: (any Error).self) { try await task.value }
  #expect(FileManager.default.fileExists(atPath: source.path))
  #expect(try FileManager.default.contentsOfDirectory(atPath: destination.path).isEmpty)
  let moved = try await reader.perform(
    .init(kind: .move, source: source, folder: destination, name: "moved"))
  #expect(!FileManager.default.fileExists(atPath: source.path))
  #expect(try Data(contentsOf: moved).count == 2 * 1024 * 1024)
  try Data("keep".utf8).write(to: source)
  await #expect(throws: (any Error).self) {
    try await reader.perform(.init(kind: .move, source: source, folder: destination, name: "moved"))
  }
  #expect(try String(contentsOf: source, encoding: .utf8) == "keep")
}
