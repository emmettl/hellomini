import AppKit
import MiniAbout
import MiniActivityMonitor
import MiniClock
import MiniControlPanel
import MiniCore
import MiniDesktop
import MiniFinder
import MiniTeapot
import MiniUI
import SwiftUI

@main
struct HelloMiniApp: App {
  private static let themes = MiniThemeRegistry.builtIns
  @State private var settings = AppearanceSettings(themes: Self.themes.metadata)
  @State private var playfulness = PlayfulnessSettings(
    effects: [MiniStartup.effect, TeapotApplication.rotationEffect])
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Window("Hello Mini", id: "desktop") {
      StartupView(
        playfulness: playfulness, theme: Self.themes.definition(for: settings.theme.id)!
      ) {
        DesktopView(
          applications: [
            FinderApplication(), ActivityMonitorApplication(), ClockApplication(),
            ControlPanelApplication(
              settings: settings, playfulness: playfulness, themes: Self.themes),
            AboutApplication(),
            TeapotApplication(playfulness: playfulness),
          ], initiallyOpen: ["activity"], settings: settings, themes: Self.themes
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
