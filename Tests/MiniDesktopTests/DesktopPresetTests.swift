import AppKit
import MiniCore
import SwiftUI
import Testing

@testable import MiniDesktop

@MainActor private final class PresetApp: MiniApplication {
  let id: String
  var name: String { id }
  let icon = MiniApplicationIcon.computer
  let defaultSize = CGSize(width: 400, height: 300)
  init(_ id: String) { self.id = id }
  func content() -> AnyView { AnyView(EmptyView()) }
}
@MainActor @Test func presetsRestoreAppearanceAndLayoutWithoutClosingOtherApps() throws {
  let name = "PresetTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let a = PresetApp("a")
  let b = PresetApp("b")
  let model = DesktopModel(applications: [a, b], initiallyOpen: ["a"], defaults: defaults)
  let settings = AppearanceSettings(defaults: defaults)
  settings.selectTheme(id: "midnight")
  settings.setTinyScreenMode(true)
  settings.setPattern(.initial)
  let placement = WindowPlacement(
    origin: CGPoint(x: 40, y: 50), size: CGSize(width: 420, height: 300))
  model.place(a, at: placement)
  let store = DesktopPresetStore(defaults: defaults)
  store.save(name: "Night desk", model: model, settings: settings)
  let preset = try #require(store.presets.first)
  model.launch(b)
  settings.selectTheme(id: "paper")
  settings.setPuristMode(true)
  settings.setPattern(nil)
  #expect(store.apply(preset, model: model, settings: settings))
  #expect(model.openIDs == ["b", "a"])
  #expect(model.minimisedIDs == ["b"])
  #expect(model.placement(for: a) == placement)
  #expect(settings.theme.id == "midnight" && settings.tinyScreenMode && !settings.puristMode)
  #expect(settings.customPattern == .initial)
  #expect(DesktopPresetStore(defaults: defaults).presets.first?.name == "Night desk")
}
@MainActor @Test func badAndUnavailablePresetsCannotMutateDesktop() throws {
  let name = "PresetTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let model = DesktopModel(applications: [PresetApp("a")], initiallyOpen: ["a"], defaults: defaults)
  let settings = AppearanceSettings(defaults: defaults)
  let store = DesktopPresetStore(defaults: defaults)
  store.save(name: "Desk", model: model, settings: settings)
  store.save(name: "desk", model: model, settings: settings)
  #expect(store.presets.count == 1 && store.error != nil)
  var unavailable = try #require(store.presets.first)
  unavailable.themeID = "missing"
  #expect(!store.apply(unavailable, model: model, settings: settings))
  #expect(settings.theme.id == "classic" && model.openIDs == ["a"])
  let bad = Data("invalid".utf8)
  defaults.set(bad, forKey: DesktopPresetStore.key)
  let broken = DesktopPresetStore(defaults: defaults)
  broken.save(name: "Replacement", model: model, settings: settings)
  #expect(!broken.readable && defaults.data(forKey: DesktopPresetStore.key) == bad)
}
@MainActor @Test func presetEmptyDesktopMinimisesAndUnknownAppsAreIgnored() {
  let name = "PresetTests.\(UUID())"
  let defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let model = DesktopModel(applications: [PresetApp("a")], initiallyOpen: ["a"], defaults: defaults)
  model.apply(DesktopSession(openIDs: ["uninstalled"], windows: [:]))
  #expect(model.openIDs == ["a"] && model.minimisedIDs == ["a"] && model.active == nil)
}
