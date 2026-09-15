import CoreGraphics
import Foundation
import MiniAbout
import MiniAccessories
import MiniActivityMonitor
import MiniAquaTheme
import MiniAquarium
import MiniCalculator
import MiniChooser
import MiniClock
import MiniControlPanel
import MiniCore
import MiniDiskFirstAid
import MiniFinder
import MiniPlatinumTheme
import MiniPrintMonitor
import MiniPuzzle
import MiniScrapbook
import MiniSystem7Theme
import MiniTeapot
import MiniUI
import MiniWastebasket
import Testing

@testable import MiniDesktop

/// Minimum sizes larger than the desktop force the whole window to scroll, which hides toolbars.
@Test @MainActor func everyApplicationFitsTinyScreenAndPuristDesktopsInEveryTheme() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let themes = MiniThemeRegistry(
    MiniThemeRegistry.builtIns.themes + [
      System7Theme.definition, PlatinumTheme.definition, AquaTheme.definition,
    ])
  let settings = AppearanceSettings(defaults: defaults, themes: themes.metadata)
  let playfulness = PlayfulnessSettings(defaults: defaults, effects: [])
  let aquarium = AquariumApplication(playfulness: playfulness)
  let applications: [any MiniApplication] = [
    FinderApplication(defaults: defaults), FindFileApplication(), ActivityMonitorApplication(),
    ClockApplication(),
    ControlPanelApplication(settings: settings, playfulness: playfulness, themes: themes),
    AboutApplication(), TeapotApplication(playfulness: playfulness), aquarium,
    ScrapbookApplication(),
    CalculatorApplication(playfulness: playfulness),
    WorldClockApplication(playfulness: playfulness),
    PuzzleApplication(picture: DesktopPicture(), playfulness: playfulness), ChooserApplication(),
    DiskFirstAidApplication(), WastebasketApplication(),
    PrintMonitorApplication(
      playfulness: playfulness, onSuccessfulBuilds: aquarium.feedFromSuccessfulBuilds,
      onFailedBuilds: { _ in }),
    ClipboardApplication(), KeyCapsApplication(), AlarmClockApplication(),
  ]
  // A 1280 × 720 display at 2×, and Purist mode's fixed desktop.
  for desktop in [CGSize(width: 640, height: 360), CGSize(width: 512, height: 384)] {
    for theme in themes.themes {
      let area = DesktopDockLayout.windowArea(desktop: desktop, hasDock: theme.dock != nil)
      let maximum = CGSize(width: area.width - 16, height: area.height - theme.menuBarHeight - 18)
      for app in applications {
        #expect(
          app.minimumSize.width <= maximum.width && app.minimumSize.height <= maximum.height,
          "\(app.name) needs \(app.minimumSize); \(theme.metadata.name) allows \(maximum) on \(desktop)"
        )
      }
    }
  }
}
