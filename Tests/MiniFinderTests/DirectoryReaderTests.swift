import Foundation
import Testing

@testable import MiniFinder

@Test func directoryListingSortsFoldersFirstAndFiltersHiddenFiles() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  try FileManager.default.createDirectory(
    at: root.appendingPathComponent("Zebra"), withIntermediateDirectories: true)
  for name in ["file10.txt", "file2.txt", ".secret"] {
    try Data("hello".utf8).write(to: root.appendingPathComponent(name))
  }

  let reader = DirectoryReader()
  let entries = try await reader.entries(at: root)
  #expect(entries.map(\.name) == ["Zebra", "file2.txt", "file10.txt"])
  #expect(entries.first?.isBrowsable == true)
  #expect(entries.last?.byteCount == 5)
  let allEntries = try await reader.entries(at: root, showHidden: true)
  #expect(allEntries.count == 4)
  #expect(allEntries.contains { $0.name == ".secret" })
}

@Test func missingDirectoryThrowsInsteadOfAppearingEmpty() async {
  let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  await #expect(throws: (any Error).self) {
    try await DirectoryReader().entries(at: missing)
  }
}

@Test func navigationTracksBackHistoryWithoutDuplicateLocations() {
  let start = URL(fileURLWithPath: "/Users/example")
  var history = NavigationHistory(start: start)
  #expect(!history.canGoBack)
  history.visit(start)
  #expect(!history.canGoBack)
  history.visit(start.appendingPathComponent("Documents"))
  #expect(history.canGoBack)
  history.goBack()
  #expect(history.current == start)
  #expect(!history.canGoBack)
  history.goBack()
  #expect(history.current == start)
  history.visit(URL(fileURLWithPath: "/"))
  #expect(!history.canGoUp)
}
