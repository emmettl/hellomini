import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class ControlPanelApplication: MiniApplication {
  public let id = "control-panel"
  public let name = "Control Panel"
  public let icon = MiniApplicationIcon.settings
  public let defaultSize = CGSize(width: 556, height: 490)
  public let minimumSize = CGSize(width: 440, height: 200)
  private let settings: AppearanceSettings
  private let playfulness: PlayfulnessSettings
  private let themes: MiniThemeRegistry
  private let screensavers: ScreensaverSettings?

  public init(
    settings: AppearanceSettings, playfulness: PlayfulnessSettings,
    themes: MiniThemeRegistry = .builtIns, screensavers: ScreensaverSettings? = nil
  ) {
    precondition(
      settings.availableThemes == themes.metadata,
      "Settings and Control Panel must share a theme catalog")
    self.settings = settings
    self.playfulness = playfulness
    self.themes = themes
    self.screensavers = screensavers
  }
  public func content() -> AnyView {
    AnyView(
      ControlPanelView(
        settings: settings, playfulness: playfulness, themes: themes, screensavers: screensavers))
  }

  public var menus: [RetroMenu] {
    [
      RetroMenu(
        id: "appearance", title: "Appearance", width: 260,
        items:
          settings.availableThemes.map { theme in
            RetroMenuItem(
              id: "theme-\(theme.id)", title: theme.name, checked: settings.theme == theme
            ) {
              self.settings.selectTheme(id: theme.id)
            }
          } + [
            .separator("display-mode"),
            RetroMenuItem(
              id: "tiny-screen", title: "Tiny-screen Mode — 2×", checked: settings.tinyScreenMode
            ) {
              self.settings.setTinyScreenMode(!self.settings.tinyScreenMode)
            },
            RetroMenuItem(
              id: "purist", title: "Purist Mode — 512 × 384", checked: settings.puristMode
            ) {
              self.settings.setPuristMode(!self.settings.puristMode)
            },
          ]
      ),
      RetroMenu(
        id: "playfulness", title: "Playfulness", width: 280,
        items: [
          RetroMenuItem(
            id: "extra-silliness", title: "Extra Silliness", checked: playfulness.enabled
          ) {
            self.playfulness.setEnabled(!self.playfulness.enabled)
          },
          .separator("effects"),
        ]
          + playfulness.effects.map { effect in
            RetroMenuItem(
              id: effect.id, title: effect.name, enabled: playfulness.enabled,
              checked: playfulness.isSelected(effect.id)
            ) {
              self.playfulness.setSelected(!self.playfulness.isSelected(effect.id), for: effect.id)
            }
          }),
    ]
  }
}

private struct ControlPanelView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.miniDisplay) private var display
  let settings: AppearanceSettings
  let playfulness: PlayfulnessSettings
  let themes: MiniThemeRegistry
  let screensavers: ScreensaverSettings?
  @State private var pane = Pane.appearance

  private enum Pane: String, CaseIterable {
    case appearance = "Appearance"
    case playfulness = "Playfulness"
    case screensavers = "Screensavers"
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        ForEach(Pane.allCases, id: \.self) { choice in
          Button(pane == choice ? "✓ " + choice.rawValue : choice.rawValue) { pane = choice }
            .accessibilityLabel(choice.rawValue + " settings")
            .accessibilityAddTraits(pane == choice ? .isSelected : [])
        }
        Spacer()
      }
      .buttonStyle(RetroButtonStyle())
      .padding(10)
      Rectangle().frame(height: 1)
      ScrollView {
        if pane == .appearance {
          appearance
        } else if pane == .screensavers, let screensavers {
          ScreensaverSettingsView(settings: screensavers, playfulness: playfulness).padding(22)
        } else {
          PlayfulnessView(settings: playfulness).padding(22)
        }
      }
      Spacer(minLength: 0)
      Text("Changes apply immediately and are saved.")
        .font(theme.typography.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(display.tinyScreen ? 8 : 14)
    }
  }

  private var appearance: some View {
    VStack(alignment: .leading, spacing: display.tinyScreen ? 12 : 18) {
      if !display.tinyScreen {
        HStack(spacing: 14) {
          PixelIcon(symbol: .settings, scale: 2)
          VStack(alignment: .leading, spacing: 5) {
            Text("Appearance").font(theme.typography.display(21))
            Text("Choose a look for your desktop.").font(theme.typography.small)
          }
        }
      }
      Toggle(
        "Tiny-screen mode — 2×",
        isOn: Binding(
          get: { settings.tinyScreenMode }, set: { settings.setTinyScreenMode($0) })
      )
      .toggleStyle(.checkbox)
      .miniHelp("Make the whole interface twice as large. Turn it off here or in the View menu.")
      Text("Larger text and controls, with less on screen at once.")
        .font(theme.typography.small)
      Toggle(
        "Purist mode — 512 × 384",
        isOn: Binding(
          get: { settings.puristMode }, set: { settings.setPuristMode($0) })
      )
      .toggleStyle(.checkbox)
      .miniHelp("Use a fixed 512 × 384 desktop. Turn it off here or in the View menu.")
      Rectangle().frame(height: 1)
      AppearanceScrollView {
        HStack(alignment: .top, spacing: 14) {
          ForEach(themes.themes) { definition in
            Button {
              settings.selectTheme(id: definition.id)
            } label: {
              VStack(spacing: 10) {
                MiniThemePreview(definition)
                  .id(settings.theme.id)
                  .frame(height: 96)
                  .padding(5)
                  .overlay(
                    Rectangle().strokeBorder(
                      theme.ink, lineWidth: settings.theme.id == definition.id ? 3 : 1))
                HStack(spacing: 7) {
                  Circle().strokeBorder(theme.ink, lineWidth: 1)
                    .background {
                      if settings.theme.id == definition.id { Circle().fill(theme.ink).padding(3) }
                    }
                    .frame(width: 13, height: 13)
                  Text(definition.metadata.name).font(theme.typography.title)
                }
              }
              .frame(width: 160)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(definition.metadata.name) theme")
            .accessibilityValue(settings.theme.id == definition.id ? "Selected" : "Not selected")
            .accessibilityAddTraits(settings.theme.id == definition.id ? .isSelected : [])
          }
        }
        .padding(.bottom, 8)
        .environment(\.miniTheme, theme)
        .environment(\.colorScheme, theme.colorScheme)
      }
      DesktopPatternEditor(settings: settings)
      Text(settings.theme.description)
        .font(theme.typography.body)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)
    }
    .padding(display.tinyScreen ? 12 : 22)
  }
}
