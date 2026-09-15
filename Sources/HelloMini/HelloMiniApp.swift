import AppKit
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
import MiniDesktop
import MiniDiskFirstAid
import MiniFinder
import MiniMoose
import MiniPlatinumTheme
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
  @State private var displayWindowChromeHeight: CGFloat = 0
  private var settings: AppearanceSettings { system.settings }
  private var picture: DesktopPicture { system.picture }
  private var playfulness: PlayfulnessSettings { system.playfulness }
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Window("Hello Mini", id: "desktop") {
      MiniDisplayViewport(
        puristMode: settings.puristMode, tinyScreenMode: settings.tinyScreenMode,
        windowChromeChanged: { displayWindowChromeHeight = $0 }
      ) {
        StartupView(
          playfulness: playfulness, theme: Self.themes.definition(for: settings.theme.id)!
        ) {
          ScreensaverHost(
            settings: system.screensavers, playfulness: playfulness,
            definitions: system.saverDefinitions,
            theme: Self.themes.definition(for: settings.theme.id)!,
            displaySize: settings.puristMode ? CGSize(width: 512, height: 384) : nil
          ) {
            DesktopView(
              applications: system.applications, initiallyOpen: ["activity"], settings: settings,
              themes: Self.themes, picture: picture, playfulness: playfulness,
              commands: system.commands,
              captureDesktop: { image in await system.scrapbook.captureDesktop(image) }
            )
            .overlay {
              TalkingMooseOverlay(moose: system.moose)
                .environment(\.miniTheme, Self.themes.definition(for: settings.theme.id)!)
            }
          }
        }
      }
      .frame(
        width: settings.puristMode ? 512 : nil,
        height: settings.puristMode ? max(1, 384 - displayWindowChromeHeight) : nil
      )
      .frame(minWidth: settings.puristMode ? nil : 960, minHeight: settings.puristMode ? nil : 600)
      .ignoresSafeArea()
      .task {
        system.startupSound()
        while !Task.isCancelled {
          system.alarm.tick()
          system.sounds.stopIfDisabled()
          do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
      }
      .task {
        while !Task.isCancelled {
          await system.printMonitor.refreshInBackground()
          do { try await Task.sleep(for: .seconds(5)) } catch { return }
        }
      }
      .containerBackground(.black, for: .window)
    }
    .defaultSize(width: 1280, height: 720)
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .toolbar) {
        Toggle(
          "Tiny-screen Mode",
          isOn: Binding(
            get: { settings.tinyScreenMode }, set: { settings.setTinyScreenMode($0) }))
        Toggle(
          "Purist Mode — 512 × 384",
          isOn: Binding(
            get: { settings.puristMode }, set: { settings.setPuristMode($0) }))
      }
      CommandGroup(after: .windowArrangement) {
        Button("Enter / Exit Full Screen") {
          MiniDesktopWindowActions.toggleFullScreen()
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
    MiniThemeRegistry.builtIns.themes + [
      System7Theme.definition, PlatinumTheme.definition, AquaTheme.definition,
    ])
  let settings = AppearanceSettings(themes: MiniSystem.themes.metadata)
  let picture = DesktopPicture()
  let commands = DesktopCommands()
  let playfulness = PlayfulnessSettings(
    effects: [
      MiniStartup.effect, TeapotApplication.rotationEffect, CalculatorApplication.effect,
      WorldClockApplication.effect, PuzzleApplication.effect, PrintMonitorApplication.effect,
      FlyingToasters.effect, SystemSounds.effect, DesktopEffects.menuBlink,
      DesktopEffects.dockMagnification, DesktopEffects.dockLaunchBounce, DesktopEffects.genie,
      TalkingMoose.effect,
    ] + AquariumApplication.effects)
  let screensavers = ScreensaverSettings(savers: [
    AquariumApplication.screensaver, FlyingToasters.metadata, ScrapbookApplication.screensaver,
  ])
  let aquarium: AquariumApplication
  let sounds: SystemSounds
  let scrapbook = ScrapbookApplication()
  let alarm: AlarmClockApplication
  let printMonitor: PrintMonitorApplication
  let moose: TalkingMoose
  private var didChime = false
  func startupSound() {
    guard !didChime else { return }
    didChime = true
    sounds.play(.startup)
  }
  lazy var applications: [any MiniApplication] = [
    FinderApplication(findFile: { [commands] in commands.launch("find-file") }),
    FindFileApplication(), ActivityMonitorApplication(), ClockApplication(),
    ControlPanelApplication(
      settings: settings, playfulness: playfulness, themes: Self.themes, screensavers: screensavers),
    AboutApplication(), TeapotApplication(playfulness: playfulness), aquarium, scrapbook,
    CalculatorApplication(playfulness: playfulness),
    WorldClockApplication(playfulness: playfulness),
    PuzzleApplication(picture: picture, playfulness: playfulness), ChooserApplication(),
    DiskFirstAidApplication(),
    WastebasketApplication(onEmpty: { [sounds] in sounds.play(.wastebasket) }),
    printMonitor, ClipboardApplication(), KeyCapsApplication(), alarm,
  ]
  init() {
    let screensavers = screensavers
    let sounds = SystemSounds(settings: playfulness)
    self.sounds = sounds
    alarm = AlarmClockApplication { sounds.play(.alarm) }
    let aquarium = AquariumApplication(
      playfulness: playfulness,
      preview: {
        screensavers.preview(AquariumApplication.screensaver.id)
      }, onFeed: { sounds.play(.feed) })
    self.aquarium = aquarium
    let moose = TalkingMoose(settings: playfulness)
    self.moose = moose
    printMonitor = PrintMonitorApplication(
      playfulness: playfulness,
      onSuccessfulBuilds: { count in
        aquarium.feedFromSuccessfulBuilds(count)
        moose.react(to: .passed(count))
      },
      onFailedBuilds: { count in
        sounds.play(.jam)
        aquarium.recordFailedBuilds(count)
        moose.react(to: .failed(count))
      })
  }
  var saverDefinitions: [MiniScreensaverDefinition] {
    [
      MiniScreensaverDefinition(
        metadata: AquariumApplication.screensaver,
        presenting: aquarium.setScreensaverPresented, content: aquarium.screensaverContent),
      FlyingToasters.definition(playfulness: playfulness),
      MiniScreensaverDefinition(
        metadata: ScrapbookApplication.screensaver, content: scrapbook.screensaverContent),
    ]
  }
}
