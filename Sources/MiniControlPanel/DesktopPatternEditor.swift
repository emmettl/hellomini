import MiniCore
import MiniUI
import SwiftUI

struct DesktopPatternEditor: View {
  @Environment(\.miniTheme) private var theme
  let settings: AppearanceSettings
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Desktop Pattern").font(theme.typography.title)
      Toggle(
        "Use a custom 8 × 8 pattern",
        isOn: Binding(
          get: { settings.customPattern != nil }, set: { settings.setPattern($0 ? .initial : nil) })
      )
      if let pattern = settings.customPattern {
        HStack(spacing: 22) {
          VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { y in
              HStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { x in
                  Button {
                    var next = pattern
                    next.toggle(x: x, y: y)
                    settings.setPattern(next)
                  } label: {
                    Rectangle().fill(pattern.contains(x: x, y: y) ? theme.ink : theme.paper)
                      .frame(width: 18, height: 18).overlay(
                        Rectangle().strokeBorder(theme.ink.opacity(0.3)))
                  }.buttonStyle(.plain)
                    .accessibilityLabel("Pattern row \(y + 1), column \(x + 1)")
                    .accessibilityValue(pattern.contains(x: x, y: y) ? "Ink" : "Paper")
                }
              }
            }
          }
          VStack(alignment: .leading, spacing: 10) {
            Text("Click squares to draw. Each square becomes a desktop pixel.").font(
              theme.typography.small)
            Button("Clear") {
              settings.setPattern(DesktopPattern(rows: Array(repeating: 0, count: 8)))
            }
            Button("Reset to theme") { settings.setPattern(nil) }
          }.buttonStyle(RetroButtonStyle())
        }
      }
    }
  }
}
