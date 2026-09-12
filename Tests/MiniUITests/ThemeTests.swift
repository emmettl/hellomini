import AppKit
import MiniCore
import SwiftUI
import Testing

@testable import MiniUI

@MainActor private final class RenderCalls {
  var titleBar = false
  var button = false
  var icon = false
}

/// A deliberately non-monochrome theme proves the public extension points without shipping an era theme.
@Test @MainActor func customThemeRendersThroughSharedPreview() throws {
  let calls = RenderCalls()
  var theme = MiniThemeDefinition(
    metadata: MiniTheme(id: "test.color", name: "Color proof", description: "Test only"))
  theme.ink = .indigo
  theme.accent = .blue
  theme.selection = .gradient([.cyan, .blue])
  theme.desktop = .image(name: "Tile.png", bundle: .module, tiled: true)
  theme.typography.body = .system(size: 13)
  theme.typography.title = .system(size: 14, weight: .bold)
  theme.typography.display = { .system(size: $0, design: .rounded) }
  theme.window.surface = .pinstripes(
    background: .white, foreground: .gray.opacity(0.2), spacing: 4, lineWidth: 1)
  theme.window.cornerRadius = 10
  theme.window.borderWidth = 1
  theme.window.shadowRadius = 4
  theme.window.shadow = .black.opacity(0.3)
  theme.titleBarHeight = 36
  theme.titleBar = { state, theme in
    calls.titleBar = state.active && state.title == "Hello Mini"
    return AnyView(
      HStack {
        Button(action: state.close) { Circle().fill(.red).frame(width: 12, height: 12) }
          .accessibilityLabel("Close \(state.title)")
        Spacer()
        Text(state.title).font(theme.typography.title)
        Spacer()
      }.padding(.horizontal, 10).frame(maxHeight: .infinity)
        .background { ThemeSurfaceView(.gradient([.white, .gray.opacity(0.5)])) })
  }
  theme.button = { label, state, theme in
    calls.button = state.enabled && !state.pressed
    return AnyView(
      label.font(theme.typography.body).padding(8)
        .foregroundStyle(theme.selectionInk)
        .background { ThemeSurfaceView(theme.selection).clipShape(Capsule()) })
  }
  theme.icon = { _, size, _, _ in
    calls.icon = true
    return AnyView(
      ThemeSurfaceView(.image(name: "Tile.png", bundle: .module, tiled: false)).frame(
        width: size, height: size))
  }
  let registry = MiniThemeRegistry(MiniThemeRegistry.builtIns.themes + [theme])
  let definition = try #require(registry.definition(for: theme.id))
  #expect(registry.metadata.last == theme.metadata)
  #expect(registry.definition(for: "unknown") == nil)
  let image = try #require(
    ImageRenderer(content: ThemePreviewScene(definition: definition).frame(width: 600, height: 384))
      .cgImage)
  #expect(image.width == 600 && image.height == 384)
  #expect(calls.titleBar && calls.button && calls.icon)
  if let destination = ProcessInfo.processInfo.environment["MINI_THEME_PROOF_PATH"] {
    let bitmap = NSBitmapImageRep(cgImage: image)
    try #require(bitmap.representation(using: .png, properties: [:])).write(
      to: URL(filePath: destination))
  }
}

@Test @MainActor func patternedSurfacesAndBundledAssetsRenderDistinctPixels() throws {
  func colors(_ surface: ThemeSurface) throws -> Set<String> {
    let image = try #require(
      ImageRenderer(content: ThemeSurfaceView(surface).frame(width: 16, height: 16)).cgImage)
    let bitmap = NSBitmapImageRep(cgImage: image)
    return Set(
      (0..<16).flatMap { y in
        (0..<16).map { x in bitmap.colorAt(x: x, y: y)!.description }
      })
  }
  #expect(try colors(.dots(background: .white, foreground: .black, spacing: 4)).count == 2)
  #expect(
    try colors(.pinstripes(background: .white, foreground: .gray, spacing: 4, lineWidth: 1)).count
      == 2)
  #expect(try colors(.gradient([.white, .blue])).count > 2)
  #expect(try colors(.image(name: "Tile.png", bundle: .module, tiled: true)).count >= 2)
}

@Test @MainActor func previewUsesItsOwnThemeInsideDarkControls() throws {
  func render(_ scheme: ColorScheme) throws -> Data {
    let view = Button {
    } label: {
      ThemePreviewScene(definition: .classic).frame(width: 300, height: 192)
    }
    .buttonStyle(.plain)
    .environment(\.miniTheme, scheme == .dark ? .midnight : .classic)
    .environment(\.colorScheme, scheme)
    .foregroundStyle(scheme == .dark ? Color.white : .black)
    let image = try #require(ImageRenderer(content: view).cgImage)
    return try #require(
      NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
  }
  #expect(try render(.light) == render(.dark))
}
