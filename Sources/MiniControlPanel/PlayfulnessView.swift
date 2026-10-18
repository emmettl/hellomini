import MiniCore
import MiniUI
import SwiftUI

struct PlayfulnessView: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let settings: PlayfulnessSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("A little ahead of its time.").font(theme.typography.display(21))
      Toggle(isOn: Binding(get: { settings.enabled }, set: { settings.setEnabled($0) })) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Extra silliness").font(theme.typography.title)
          Text("Allow playful effects. Switching off keeps your individual choices.")
            .font(theme.typography.small)
        }
      }
      .accessibilityLabel("Extra silliness")
      Rectangle().frame(height: 1)
      ForEach(settings.effects) { effect in
        Toggle(
          isOn: Binding(
            get: { settings.isSelected(effect.id) },
            set: { settings.setSelected($0, for: effect.id) })
        ) {
          VStack(alignment: .leading, spacing: 4) {
            Text(effect.name).font(theme.typography.title)
            Text(effect.description).font(theme.typography.small)
          }
        }
        .accessibilityLabel(effect.name)
        .disabled(!settings.enabled)
      }
      if reduceMotion {
        Text("macOS Reduce Motion is on. Automatic motion stays paused.")
          .font(theme.typography.small)
      }

    }
    .toggleStyle(PlayfulnessToggleStyle())
  }

}

private struct PlayfulnessToggleStyle: ToggleStyle {
  @Environment(\.miniTheme) private var theme
  @Environment(\.isEnabled) private var enabled

  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(alignment: .top, spacing: 10) {
        ZStack {
          Rectangle().strokeBorder(theme.ink, lineWidth: 1)
          if configuration.isOn {
            Text("✓").font(.system(size: 14, weight: .bold))
          }
        }
        .frame(width: 17, height: 17)
        configuration.label.frame(maxWidth: .infinity, alignment: .leading)
      }
      .contentShape(Rectangle())
      .opacity(enabled ? 1 : 0.45)
    }
    .buttonStyle(.plain)
    .accessibilityValue(configuration.isOn ? "On" : "Off")
  }
}
