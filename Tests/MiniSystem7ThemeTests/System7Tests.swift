import AppKit
import MiniCore
import MiniSystem7Theme
import SwiftUI
import Testing

@testable import MiniUI

@Test @MainActor func system7RegistersPersistsAndRendersDistinctChrome() throws {
  let suite = "System7Tests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let definition = System7Theme.definition
  let registry = MiniThemeRegistry(MiniThemeRegistry.builtIns.themes + [definition])
  let settings = AppearanceSettings(defaults: defaults, themes: registry.metadata)
  #expect(settings.selectTheme(id: definition.id))
  #expect(AppearanceSettings(defaults: defaults, themes: registry.metadata).theme.id == "system7")
  #expect(AppearanceSettings(defaults: defaults).theme.id == "classic")
  #expect(AppearanceSettings(defaults: defaults, themes: registry.metadata).theme.id == "system7")

  func render(_ theme: MiniThemeDefinition) throws -> Data {
    let renderer = ImageRenderer(
      content: ThemePreviewScene(definition: theme).frame(width: 300, height: 192))
    let image = try #require(renderer.cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
  }
  #expect(try render(definition) != render(.classic))
  let titleBar = try #require(definition.titleBar)
  func title(active: Bool) throws -> Data {
    let image = try #require(
      ImageRenderer(
        content:
          titleBar(ThemeWindowState(title: "Window", active: active, close: {}), definition)
          .frame(width: 280, height: definition.titleBarHeight)
      ).cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
  }
  #expect(try title(active: true) != title(active: false))
}

@Test @MainActor func system7IconsKeepTheirColourAndSelectedState() throws {
  let definition = System7Theme.definition
  func icon(selected: Bool) throws -> NSBitmapImageRep {
    let render = try #require(definition.icon)
    let image = try #require(
      ImageRenderer(content: render(.folder, 64, selected, definition)).cgImage)
    return NSBitmapImageRep(cgImage: image)
  }
  let normal = try icon(selected: false)
  let selected = try icon(selected: true)
  #expect(
    normal.representation(using: .png, properties: [:])
      != selected.representation(using: .png, properties: [:]))
  let colours = (0..<64).flatMap { y in
    (0..<64).compactMap { x in normal.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) }
  }
  #expect(colours.contains { $0.alphaComponent > 0.9 && $0.redComponent > $0.blueComponent + 0.2 })
}
