import Foundation
import Testing

@testable import MiniFinder

@Test func inspectionBoundsTextAndDoesNotTraverseDirectoriesOrSymlinks() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(
    "FinderInspection-\(UUID())")
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let file = root.appendingPathComponent("large.txt")
  try Data(repeating: 65, count: 100_000).write(to: file)
  let reader = DirectoryReader()
  let info = try await reader.inspect(file, preview: false)
  #expect(info.text == nil && info.image == nil)
  #expect(info.details.contains("POSIX permissions:"))
  let preview = try await reader.inspect(file, preview: true)
  #expect(preview.text?.contains("limited to 64 KB") == true)
  #expect((preview.text?.utf8.count ?? 0) < 66_000)
  let folder = try await reader.inspect(root, preview: true)
  #expect(folder.details.contains("contents not counted"))
  let link = root.appendingPathComponent("link.txt")
  try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
  let linked = try await reader.inspect(link, preview: true)
  #expect(linked.text?.contains("regular text") == true)
}
@MainActor @Test func favouriteFoldersPersistAndCanBeRemoved() throws {
  let suite = "FinderFavourites-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set(["relative", "/tmp", "/tmp"], forKey: "finder.favourites")
  let model = FinderModel(defaults: defaults)
  #expect(model.favourites.count == 1)
  model.navigate(to: URL(fileURLWithPath: "/tmp"))
  #expect(model.currentIsFavourite)
  model.toggleFavourite()
  #expect(model.favourites.isEmpty)
  model.toggleFavourite()
  #expect(FinderModel(defaults: defaults).favourites == model.favourites)
}
