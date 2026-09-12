import Foundation
import Testing

@testable import MiniCore

@Test @MainActor func themeSelectionSurvivesSettingsRecreation() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = AppearanceSettings(defaults: defaults)
  #expect(settings.theme == .classic)
  settings.selectTheme(id: MiniTheme.midnight.id)
  #expect(AppearanceSettings(defaults: defaults).theme == .midnight)
  settings.selectTheme(id: MiniTheme.paper.id)
  #expect(AppearanceSettings(defaults: defaults).theme == .paper)
  settings.selectTheme(id: MiniTheme.classic.id)
  #expect(AppearanceSettings(defaults: defaults).theme == .classic)
}

@Test @MainActor func unavailableSavedThemeFallsBackToClassic() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  defaults.set("future-theme", forKey: AppearanceSettings.themeKey)
  #expect(AppearanceSettings(defaults: defaults).theme == .classic)
}

@Test @MainActor func registeredThemePersistsAndUnknownSelectionIsIgnored() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let custom = MiniTheme(id: "org.example.color", name: "Color", description: "An external theme")
  let catalog = MiniTheme.builtIns + [custom]
  let settings = AppearanceSettings(defaults: defaults, themes: catalog)
  #expect(settings.selectTheme(id: custom.id))
  #expect(AppearanceSettings(defaults: defaults, themes: catalog).theme == custom)
  #expect(!settings.selectTheme(id: "unregistered"))
  #expect(settings.theme == custom)
  #expect(defaults.string(forKey: AppearanceSettings.themeKey) == custom.id)
  #expect(AppearanceSettings(defaults: defaults).theme == .classic)
  // An unavailable theme is not erased: reinstalling restores the user's preference.
  #expect(AppearanceSettings(defaults: defaults, themes: catalog).theme == custom)
  #expect(AppearanceSettings(defaults: defaults, themes: [.paper]).theme == .paper)
}

@Test @MainActor func puristModePersistsIndependentlyOfTheTheme() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = AppearanceSettings(defaults: defaults)
  #expect(!settings.puristMode)
  settings.setPuristMode(true)
  settings.selectTheme(id: MiniTheme.midnight.id)
  let restored = AppearanceSettings(defaults: defaults)
  #expect(restored.puristMode)
  #expect(restored.theme == .midnight)
  restored.setPuristMode(false)
  #expect(!AppearanceSettings(defaults: defaults).puristMode)
  #expect(AppearanceSettings(defaults: defaults).theme == .midnight)
}
