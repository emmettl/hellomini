import AppKit
import MiniAquaTheme
import MiniCore
import MiniFinder
import MiniNetwork
import MiniPaint
import MiniPlatinumTheme
import MiniSystem7Theme
import MiniUI
import SwiftUI
import Testing

/// Render real accessory content at supported minimum sizes in every theme. This complements
/// the geometry contract test; snapshots make text, controls and theme rendering regressions inspectable.
@Test @MainActor func accessoriesRenderAtMinimumSizesAcrossThemes() throws {
  let suite = "RenderedAccessories-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = PlayfulnessSettings(defaults: defaults, effects: [NetworkApplication.effect])
  let themes =
    MiniThemeRegistry.builtIns.themes + [
      System7Theme.definition, PlatinumTheme.definition, AquaTheme.definition,
    ]
  let apps: [any MiniApplication] = [
    NetworkApplication(playfulness: settings), FinderApplication(defaults: defaults),
    PaintApplication(),
  ]
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "HelloMini-0.7-layout-checks")
  try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
  for theme in themes {
    for app in apps {
      for size in [
        app.minimumSize, CGSize(width: 480, height: 260), CGSize(width: 720, height: 420),
      ] {
        let hosting = NSHostingView(
          rootView: app.content().environment(\.miniTheme, theme)
            .environment(\.colorScheme, theme.colorScheme).foregroundStyle(theme.ink).background(
              theme.paper
            )
            .frame(width: size.width, height: size.height))
        hosting.frame = CGRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let image = try #require(
          bitmap.cgImage, "\(app.name) failed to render in \(theme.metadata.name)")
        try #require(bitmap.representation(using: .png, properties: [:])).write(
          to:
            output.appendingPathComponent(
              "\(theme.id)-\(app.id)-\(Int(size.width))x\(Int(size.height)).png"))
        #expect(image.width >= Int(size.width) && image.height >= Int(size.height))
        #expect(
          abs(Double(image.width) / Double(image.height) - Double(size.width / size.height)) < 0.01)
      }
    }
  }
}
