import MiniCore
import MiniUI
import SwiftUI

/// Original vector artwork and system typography, inspired by the first Aqua desktops.
public enum AquaTheme {
  public static let definition: MiniThemeDefinition = {
    var theme = MiniThemeDefinition(
      metadata: MiniTheme(
        id: "aqua", name: "Aqua",
        description:
          "Pinstripes, blue gel, and far too much polish. A little turn-of-the-millennium optimism."
      ))
    theme.ink = Color(red: 0.08, green: 0.12, blue: 0.19)
    theme.paper = Color(white: 0.99)
    theme.accent = Color(red: 0.05, green: 0.34, blue: 0.8)
    theme.selection = .gradient([Color(red: 0.18, green: 0.44, blue: 0.8), theme.accent])
    theme.typography.body = .system(size: 13)
    theme.typography.small = .system(size: 11)
    theme.typography.title = .system(size: 14, weight: .semibold)
    theme.typography.display = { .system(size: $0, weight: .semibold) }
    theme.desktopInk = .white
    theme.desktopLabelSurface = .solid(.clear)
    theme.desktopTextShadow = .black.opacity(0.75)
    theme.desktop = .custom { AnyView(AquaDesktop()) }
    theme.window = ThemeFrameStyle(
      surface: pinstripes, border: Color(white: 0.48), shadow: .black.opacity(0.32))
    theme.window.borderWidth = 0.75
    theme.window.cornerRadius = 9
    theme.window.shadowRadius = 7
    theme.window.shadowOffset = CGSize(width: 0, height: 5)
    theme.inactiveWindow = theme.window
    theme.inactiveWindow.shadow = .black.opacity(0.18)
    theme.inactiveWindow.shadowRadius = 3
    theme.menu = ThemeFrameStyle(
      surface: pinstripes, border: Color(white: 0.5), shadow: .black.opacity(0.26))
    theme.menu.borderWidth = 0.75
    theme.menu.cornerRadius = 5
    theme.menu.shadowRadius = 5
    theme.menu.shadowOffset = CGSize(width: 0, height: 4)
    theme.menuBar = pinstripes
    theme.menuBarHeight = 28
    theme.menuBarBorderWidth = 0.5
    theme.menuRowHeight = 26
    theme.titleBarHeight = 30
    theme.titleBarDivider = 0.5
    theme.titleBar = { state, theme in AnyView(AquaTitleBar(state: state, theme: theme)) }
    theme.button = { label, state, theme in
      AnyView(AquaButton(label: label, state: state, theme: theme))
    }
    theme.icon = { symbol, size, selected, _ in
      AnyView(AquaIcon(symbol: symbol, selected: selected).frame(width: size, height: size))
    }
    return theme
  }()

  static let pinstripes: ThemeSurface = .pinstripes(
    background: Color(white: 0.98), foreground: Color(red: 0.88, green: 0.9, blue: 0.93),
    spacing: 4, lineWidth: 1)
}

private struct AquaDesktop: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        LinearGradient(
          colors: [
            Color(red: 0.09, green: 0.27, blue: 0.55), Color(red: 0.29, green: 0.59, blue: 0.84),
          ], startPoint: .topLeading, endPoint: .bottomTrailing)
        Canvas { context, size in
          for index in 0..<5 {
            let shift = CGFloat(index) * 0.13
            var wave = Path()
            wave.move(to: CGPoint(x: -size.width * 0.2, y: size.height * (0.3 + shift)))
            wave.addCurve(
              to: CGPoint(x: size.width * 1.2, y: size.height * (0.02 + shift)),
              control1: CGPoint(x: size.width * 0.18, y: size.height * (1.1 + shift)),
              control2: CGPoint(x: size.width * 0.65, y: -size.height * 0.25))
            context.stroke(
              wave, with: .color(.white.opacity(index == 2 ? 0.10 : 0.035)),
              lineWidth: max(1, size.height * 0.06))
          }
        }
      }.frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

private struct AquaTitleBar: View {
  let state: ThemeWindowState
  let theme: MiniThemeDefinition
  var body: some View {
    ZStack {
      ThemeSurfaceView(AquaTheme.pinstripes)
      LinearGradient(
        colors: [.white.opacity(0.72), .clear, .black.opacity(state.active ? 0.16 : 0.07)],
        startPoint: .top, endPoint: .bottom)
      Text(state.title).font(theme.typography.title).lineLimit(1)
        .foregroundStyle(state.active ? theme.ink : theme.ink.opacity(0.5))
        .shadow(color: .white, radius: 0, x: 0, y: 1).padding(.horizontal, 38)
      HStack {
        Button(action: state.close) {
          ZStack {
            Circle().fill(
              LinearGradient(
                colors: state.active
                  ? [
                    Color(red: 1, green: 0.75, blue: 0.68), .red,
                    Color(red: 0.6, green: 0.05, blue: 0.02),
                  ] : [Color(white: 0.96), Color(white: 0.64)], startPoint: .top, endPoint: .bottom)
            )
            Circle().strokeBorder(Color.black.opacity(0.38), lineWidth: 0.7)
            Ellipse().fill(.white.opacity(0.75)).frame(width: 8, height: 4).offset(y: -3)
          }.frame(width: 14, height: 14).padding(5).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("Close \(state.title)")
        Spacer()
      }.padding(.horizontal, 5)
    }.overlay(alignment: .top) { Color.white.opacity(0.9).frame(height: 1) }
  }
}

private struct AquaButton: View {
  let label: AnyView
  let state: ThemeControlState
  let theme: MiniThemeDefinition
  var body: some View {
    label.font(theme.typography.body).padding(.horizontal, 13).padding(.vertical, 5)
      .foregroundStyle(
        state.enabled
          ? (state.pressed ? .white : Color(red: 0.03, green: 0.1, blue: 0.25)) : Color(white: 0.46)
      )
      .background {
        Capsule().fill(
          LinearGradient(
            stops: [
              .init(
                color: state.enabled ? Color(red: 0.81, green: 0.92, blue: 1) : Color(white: 0.99),
                location: 0),
              .init(
                color: state.enabled
                  ? Color(red: 0.38, green: 0.67, blue: 0.97) : Color(white: 0.88), location: 0.48),
              .init(
                color: state.enabled ? Color(red: 0.17, green: 0.48, blue: 0.9) : Color(white: 0.8),
                location: 0.5),
              .init(
                color: state.enabled ? Color(red: 0.68, green: 0.88, blue: 1) : Color(white: 0.95),
                location: 1),
            ], startPoint: .top, endPoint: .bottom))
        Capsule().fill(
          state.pressed ? Color(red: 0.03, green: 0.16, blue: 0.45).opacity(0.65) : .clear)
        Capsule().strokeBorder(
          state.enabled ? theme.accent.opacity(0.7) : Color.gray.opacity(0.5), lineWidth: 0.75)
        Capsule().strokeBorder(.white.opacity(0.75), lineWidth: 0.6).padding(1.5)
      }
      .shadow(color: .black.opacity(state.enabled ? 0.16 : 0.07), radius: 1, x: 0, y: 1)
  }
}
