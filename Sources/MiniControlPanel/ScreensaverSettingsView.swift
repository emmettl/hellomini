import MiniCore
import MiniUI
import SwiftUI

struct ScreensaverSettingsView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let settings: ScreensaverSettings
  let playfulness: PlayfulnessSettings
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("While the desktop dreams.").font(theme.typography.display(21))
      ForEach(settings.savers) { saver in
        Button {
          settings.select(saver.id)
        } label: {
          HStack(alignment: .top, spacing: 10) {
            Text(settings.selectedID == saver.id ? "◉" : "○")
            VStack(alignment: .leading, spacing: 4) {
              Text(saver.name).font(theme.typography.title)
              Text(saver.description).font(theme.typography.small)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
          }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(saver.name + " screensaver")
        .accessibilityValue(settings.selectedID == saver.id ? "Selected" : "Not selected")
      }
      Rectangle().frame(height: 1)
      Picker(
        "Start after",
        selection: Binding(
          get: { settings.idleMinutes }, set: { settings.setIdleMinutes($0) })
      ) {
        ForEach(ScreensaverSettings.delays, id: \.self) { delay in
          Text(delay == 0 ? "Never" : "\(delay) \(delay == 1 ? "minute" : "minutes")")
            .tag(delay)
        }
      }
      Text("Starts while Hello Mini is active and idle. Move the mouse or press a key to return.")
        .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      Button("Preview screensaver") { settings.preview() }
        .buttonStyle(RetroButtonStyle()).disabled(!playfulness.enabled)
      if !playfulness.enabled {
        Text("Enable Extra silliness in Playfulness to use screensavers.")
          .font(theme.typography.small)
      } else if reduceMotion {
        Text("Reduce Motion is on. Previews are still pictures; automatic activation is paused.")
          .font(theme.typography.small)
      }
      Text("Covers this display. Your Mac's normal sleep and lock settings still apply.")
        .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
    }
  }
}
