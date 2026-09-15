import AppKit
import MiniCore
import MiniPlatinumTheme
import MiniSystem7Theme
import SwiftUI
import Testing

@testable import MiniUI

@MainActor private func png(_ view: some View) throws -> Data {
  let image = try #require(ImageRenderer(content: view).cgImage)
  return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
}

@Test @MainActor func platinumRegistersPersistsAndRendersItsOwnChrome() throws {
  let suite = "PlatinumTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let definition = PlatinumTheme.definition
  let registry = MiniThemeRegistry(
    MiniThemeRegistry.builtIns.themes + [System7Theme.definition, definition])
  let settings = AppearanceSettings(defaults: defaults, themes: registry.metadata)
  #expect(settings.selectTheme(id: "platinum"))
  #expect(AppearanceSettings(defaults: defaults, themes: registry.metadata).theme.id == "platinum")
  #expect(definition.windowShade && !System7Theme.definition.windowShade)
  #expect(definition.dock == nil)

  let preview = { (theme: MiniThemeDefinition) in
    ThemePreviewScene(definition: theme).frame(width: 300, height: 192)
  }
  #expect(try png(preview(definition)) != png(preview(System7Theme.definition)))
  let titleBar = try #require(definition.titleBar)
  func title(active: Bool, shaded: Bool = false) throws -> Data {
    try png(
      titleBar(
        ThemeWindowState(
          title: "Window", active: active, close: {}, zoom: {}, shade: {}, shaded: shaded),
        definition
      )
      .frame(width: 280, height: definition.titleBarHeight))
  }
  #expect(try title(active: true) != title(active: false))
}

@Test @MainActor func platinumButtonsAndIconsShowTheirStates() throws {
  let definition = PlatinumTheme.definition
  let button = try #require(definition.button)
  func render(pressed: Bool, enabled: Bool = true) throws -> Data {
    try png(
      button(AnyView(Text("OK")), ThemeControlState(pressed: pressed, enabled: enabled), definition)
        .frame(width: 80, height: 28))
  }
  #expect(try render(pressed: false) != render(pressed: true))
  #expect(try render(pressed: false) != render(pressed: false, enabled: false))
  let icon = try #require(definition.icon)
  #expect(try png(icon(.folder, 48, false, definition)) != png(icon(.folder, 48, true, definition)))
}
