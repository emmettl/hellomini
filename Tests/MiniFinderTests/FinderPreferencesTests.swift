import Foundation
import Testing

@testable import MiniFinder

@Test @MainActor func finderRestoresLocationAndViewChoices() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let model = FinderModel(defaults: defaults)
  let folder = FileManager.default.temporaryDirectory.standardizedFileURL
  model.navigate(to: folder)
  model.showHidden = true
  model.listView = true
  let restored = FinderModel(defaults: defaults)
  #expect(restored.location == folder)
  #expect(restored.showHidden)
  #expect(restored.listView)
  #expect(!restored.history.canGoBack)
  model.goBack()
  #expect(
    FinderModel(defaults: defaults).location
      == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL)
}

@Test @MainActor func invalidFinderPreferenceFallsBackButMissingFolderRemainsRecoverable() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set("https://example.com", forKey: "finder.location")
  #expect(
    FinderModel(defaults: defaults).location
      == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL)
  let missing = "/tmp/HelloMiniMissing-\(UUID().uuidString)"
  defaults.set(missing, forKey: "finder.location")
  // Opening Finder will show the normal read error and folder chooser, retaining the user's location.
  #expect(FinderModel(defaults: defaults).location.path == missing)
}
