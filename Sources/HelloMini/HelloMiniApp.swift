import AppKit
import MiniAbout
import MiniActivityMonitor
import MiniAquarium
import MiniCalculator
import MiniChooser
import MiniClock
import MiniControlPanel
import MiniCore
import MiniDesktop
import MiniDiskFirstAid
import MiniFinder
import MiniPrintMonitor
import MiniPuzzle
import MiniScrapbook
import MiniScreensaver
import MiniSystem7Theme
import MiniTeapot
import MiniToasters
import MiniUI
import MiniWastebasket
import SwiftUI

@main
struct HelloMiniApp: App {
  private static let themes = MiniSystem.themes
  @State private var system = MiniSystem()
  private var settings: AppearanceSettings { system.settings }
  private var picture: DesktopPicture { system.picture }
  private var playfulness: PlayfulnessSettings { system.playfulness }
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  private func applications() -> [any MiniApplication] {
    let aquarium = system.aquarium
    return [
      FinderApplication(), ActivityMonitorApplication(), ClockApplication(),
      ControlPanelApplication(
        settings: settings, playfulness: playfulness, themes: Self.themes,
        screensavers: system.screensavers),
      AboutApplication(),
      TeapotApplication(playfulness: playfulness),
      aquarium,
      ScrapbookApplication(),
      CalculatorApplication(playfulness: playfulness),
      WorldClockApplication(playfulness: playfulness),
      PuzzleApplication(picture: picture, playfulness: playfulness),
      ChooserApplication(), DiskFirstAidApplication(), WastebasketApplication(),
      PrintMonitorApplication(
        playfulness: playfulness, onSuccessfulBuilds: aquarium.feedFromSuccessfulBuilds),
    ]
  }

  var body: some Scene {
    Window("Hello Mini", id: "desktop") {
      StartupView(
        playfulness: playfulness, theme: Self.themes.definition(for: settings.theme.id)!
      ) {
        ScreensaverHost(
          settings: system.screensavers, playfulness: playfulness,
          definitions: system.saverDefinitions,
          theme: Self.themes.definition(for: settings.theme.id)!
        ) {
          DesktopView(
            applications: applications(), initiallyOpen: ["activity"], settings: settings,
            themes: Self.themes, picture: picture
          )
        }
      }
      .frame(minWidth: 960, minHeight: 600)
    }
    .defaultSize(width: 1280, height: 720)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .windowArrangement) {
        Button("Enter / Exit Full Screen") {
          NSApp.keyWindow?.toggleFullScreen(nil)
        }
        .keyboardShortcut("f", modifiers: [.control, .command])
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

/// Owns shared app instances so Aquarium's desk and screensaver views use the same fish and meals.
@MainActor private final class MiniSystem {
  static let themes = MiniThemeRegistry(
    MiniThemeRegistry.builtIns.themes + [System7Theme.definition])
  let settings = AppearanceSettings(themes: MiniSystem.themes.metadata)
  let picture = DesktopPicture()
  let playfulness = PlayfulnessSettings(
    effects: [
      MiniStartup.effect, TeapotApplication.rotationEffect, CalculatorApplication.effect,
      WorldClockApplication.effect, PuzzleApplication.effect, PrintMonitorApplication.effect,
      FlyingToasters.effect,
    ] + AquariumApplication.effects)
  let screensavers = ScreensaverSettings(savers: [
    AquariumApplication.screensaver, FlyingToasters.metadata,
  ])
  let aquarium: AquariumApplication
  init() {
    let screensavers = screensavers
    aquarium = AquariumApplication(playfulness: playfulness) {
      screensavers.preview(AquariumApplication.screensaver.id)
    }
  }
  var saverDefinitions: [MiniScreensaverDefinition] {
    [
      MiniScreensaverDefinition(
        metadata: AquariumApplication.screensaver,
        presenting: aquarium.setScreensaverPresented, content: aquarium.screensaverContent),
      FlyingToasters.definition(playfulness: playfulness),
    ]
  }
}
