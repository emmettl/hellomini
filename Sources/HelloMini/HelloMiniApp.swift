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
import MiniTeapot
import MiniUI
import MiniWastebasket
import SwiftUI

@main
struct HelloMiniApp: App {
  private static let themes = MiniThemeRegistry.builtIns
  @State private var settings = AppearanceSettings(themes: Self.themes.metadata)
  @State private var picture = DesktopPicture()
  @State private var playfulness = PlayfulnessSettings(
    effects: [
      MiniStartup.effect, TeapotApplication.rotationEffect, CalculatorApplication.effect,
      WorldClockApplication.effect, PuzzleApplication.effect, PrintMonitorApplication.effect,
    ]
      + AquariumApplication.effects)
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  private func applications() -> [any MiniApplication] {
    let aquarium = AquariumApplication(playfulness: playfulness)
    return [
      FinderApplication(), ActivityMonitorApplication(), ClockApplication(),
      ControlPanelApplication(
        settings: settings, playfulness: playfulness, themes: Self.themes),
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
        DesktopView(
          applications: applications(), initiallyOpen: ["activity"], settings: settings,
          themes: Self.themes, picture: picture
        )
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
