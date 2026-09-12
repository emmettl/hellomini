import AppKit
import MiniAquaTheme
import MiniCore
import SwiftUI
import Testing

@testable import MiniUI

@MainActor private func bitmap<V: View>(_ view: V) throws -> NSBitmapImageRep {
  NSBitmapImageRep(cgImage: try #require(ImageRenderer(content: view).cgImage))
}

@Test @MainActor func aquaRegistersPersistsAndRendersItsOwnPreview() throws {
  let suite = "AquaTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let definition = AquaTheme.definition
  let registry = MiniThemeRegistry(MiniThemeRegistry.builtIns.themes + [definition])
  let settings = AppearanceSettings(defaults: defaults, themes: registry.metadata)
  #expect(settings.selectTheme(id: "aqua"))
  #expect(AppearanceSettings(defaults: defaults, themes: registry.metadata).theme.id == "aqua")
  #expect(AppearanceSettings(defaults: defaults).theme.id == "classic")
  #expect(AppearanceSettings(defaults: defaults, themes: registry.metadata).theme.id == "aqua")
  let preview = try bitmap(ThemePreviewScene(definition: definition).frame(width: 600, height: 384))
  let classic = try bitmap(ThemePreviewScene(definition: .classic).frame(width: 600, height: 384))
  #expect(
    preview.representation(using: .png, properties: [:])
      != classic.representation(using: .png, properties: [:]))
  let stripes = try bitmap(ThemeSurfaceView(definition.window.surface).frame(width: 20, height: 20))
  #expect(stripes.colorAt(x: 10, y: 0) != stripes.colorAt(x: 10, y: 2))
  #expect(stripes.colorAt(x: 10, y: 0) == stripes.colorAt(x: 10, y: 4))
  if let destination = ProcessInfo.processInfo.environment["MINI_AQUA_PREVIEW_PATH"] {
    try #require(preview.representation(using: .png, properties: [:])).write(
      to: URL(filePath: destination))
  }
}

@Test @MainActor func aquaControlsRenderActivePressedAndDisabledStates() throws {
  let theme = AquaTheme.definition
  let titleBar = try #require(theme.titleBar)
  let button = try #require(theme.button)
  let titles = try [true, false].map { active in
    try bitmap(
      titleBar(
        ThemeWindowState(
          title: "A very shiny window", active: active, close: {}, minimise: {}, zoom: {}), theme
      )
      .frame(width: 300, height: 30)
    ).representation(using: .png, properties: [:])
  }
  #expect(titles[0] != titles[1])
  let states = [
    ThemeControlState(pressed: false, enabled: true),
    ThemeControlState(pressed: true, enabled: true),
    ThemeControlState(pressed: false, enabled: false),
  ]
  let buttons = try states.map { state in
    try bitmap(button(AnyView(Text("Print")), state, theme).padding(4)).representation(
      using: .png, properties: [:])
  }
  #expect(Set(buttons).count == 3)
}

@Test @MainActor func aquaSemanticIconsAreDistinctColourfulAndSelectable() throws {
  let theme = AquaTheme.definition
  let draw = try #require(theme.icon)
  let symbols: [PixelSymbol] = [
    .computer, .disk, .folder, .document, .activity, .clock, .settings, .teapot, .aquarium,
    .scrapbook, .calculator, .puzzle, .chooser, .wastebasket, .printer,
  ]
  var images = Set<Data>()
  for symbol in symbols {
    let image = try bitmap(draw(symbol, 64, false, theme))
    let data = try #require(image.representation(using: .png, properties: [:]))
    images.insert(data)
    let selected = try bitmap(draw(symbol, 64, true, theme))
    #expect(data != selected.representation(using: .png, properties: [:]))
    let colors = (0..<64).flatMap { y in
      (0..<64).compactMap { x in image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) }
    }
    #expect(colors.filter { $0.alphaComponent > 0.8 }.count > 350)
    #expect(
      colors.contains { $0.alphaComponent > 0.8 && abs($0.redComponent - $0.blueComponent) > 0.1 })
  }
  #expect(images.count == symbols.count)
  if let destination = ProcessInfo.processInfo.environment["MINI_AQUA_ICONS_PATH"] {
    let gallery = LazyVGrid(columns: Array(repeating: GridItem(.fixed(90)), count: 5), spacing: 12)
    {
      ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
        draw(symbol, 80, false, theme)
      }
    }.padding(20).background(Color(white: 0.94)).frame(width: 540)
    let image = try bitmap(gallery)
    try #require(image.representation(using: .png, properties: [:])).write(
      to: URL(filePath: destination))
  }
}

@Test @MainActor func aquaTrafficLightsRenderInRedYellowGreenOrder() throws {
  let theme = AquaTheme.definition
  let draw = try #require(theme.titleBar)
  let bar = try bitmap(
    draw(
      ThemeWindowState(
        title: "Window", active: true, close: {}, minimise: {}, zoom: {}), theme
    ).frame(width: 320, height: 30))
  let red = try #require(bar.colorAt(x: 17, y: 18)?.usingColorSpace(.deviceRGB))
  let yellow = try #require(bar.colorAt(x: 41, y: 18)?.usingColorSpace(.deviceRGB))
  let green = try #require(bar.colorAt(x: 65, y: 18)?.usingColorSpace(.deviceRGB))
  #expect(red.redComponent > red.greenComponent + 0.3)
  #expect(yellow.redComponent > yellow.blueComponent + 0.3)
  #expect(yellow.greenComponent > yellow.blueComponent + 0.2)
  #expect(green.greenComponent > green.redComponent + 0.2)
  let disabled = try bitmap(
    draw(
      ThemeWindowState(
        title: "Window", active: true, close: {}), theme
    ).frame(width: 320, height: 30))
  let grey = try #require(disabled.colorAt(x: 41, y: 18)?.usingColorSpace(.deviceRGB))
  #expect(abs(grey.redComponent - grey.greenComponent) < 0.05)
}
