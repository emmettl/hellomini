import MiniCore
import MiniUI
import SwiftUI

/// A System 7-inspired colour desktop. Uses original artwork and system fonts.
public enum System7Theme {
  public static let definition: MiniThemeDefinition = {
    var theme = MiniThemeDefinition(
      metadata: MiniTheme(
        id: "system7", name: "System 7",
        description:
          "A little colour: lavender desktop, striped title bars, and familiar shaded icons."))
    let grey = Color(white: 0.88)
    let blue = Color(red: 0.18, green: 0.2, blue: 0.48)
    theme.desktop = .dots(
      background: Color(red: 0.58, green: 0.59, blue: 0.72),
      foreground: Color(red: 0.45, green: 0.46, blue: 0.60), spacing: 2)
    theme.accent = blue
    theme.selection = .solid(blue)
    theme.typography.body = .system(size: 13)
    theme.typography.small = .system(size: 11)
    theme.typography.title = .system(size: 14, weight: .bold)
    theme.typography.display = { .system(size: $0, weight: .bold) }
    theme.window = ThemeFrameStyle(surface: .solid(grey), border: .black, shadow: .black)
    theme.window.borderWidth = 1
    theme.window.shadowOffset = CGSize(width: 2, height: 2)
    theme.inactiveWindow = theme.window
    theme.inactiveWindow.shadow = Color.black.opacity(0.45)
    theme.menu.borderWidth = 1
    theme.menu.shadowOffset = CGSize(width: 2, height: 2)
    theme.menuBarHeight = 28
    theme.menuBarBorderWidth = 1
    theme.menuRowHeight = 26
    theme.titleBarHeight = 28
    theme.titleBar = { state, theme in AnyView(System7TitleBar(state: state, theme: theme)) }
    theme.button = { label, state, theme in
      AnyView(
        label.font(theme.typography.body)
          .padding(.horizontal, 12).padding(.vertical, 5)
          .foregroundStyle(state.pressed ? Color.white : Color.black)
          .background(state.pressed ? Color.black : Color.white)
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black, lineWidth: 1))
          .background {
            RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.35))
              .offset(x: state.pressed ? 0 : 1, y: state.pressed ? 0 : 1)
          }
          .opacity(state.enabled ? 1 : 0.4))
    }
    theme.icon = { symbol, size, selected, _ in
      AnyView(System7Icon(symbol: symbol, selected: selected).frame(width: size, height: size))
    }
    return theme
  }()
}

private struct System7TitleBar: View {
  let state: ThemeWindowState
  let theme: MiniThemeDefinition
  private var paper: Color { state.active ? Color(white: 0.88) : Color(white: 0.94) }
  var body: some View {
    ZStack {
      paper
      if state.active {
        VStack(spacing: 2) {
          ForEach(0..<6) { _ in
            Rectangle().fill(Color(white: 0.36)).frame(height: 1)
              .overlay(alignment: .bottom) { Rectangle().fill(.white).frame(height: 0.5) }
          }
        }.padding(.horizontal, 7).accessibilityHidden(true)
      }
      Text(state.title).font(theme.typography.title).lineLimit(1)
        .foregroundStyle(state.active ? .black : Color(white: 0.42))
        .padding(.horizontal, 7).background(paper).padding(.horizontal, 34)
      HStack {
        Button(action: state.close) {
          Rectangle().fill(paper).frame(width: 13, height: 13)
            .overlay(
              Rectangle().strokeBorder(state.active ? .black : Color(white: 0.55), lineWidth: 1)
            )
            .overlay(alignment: .top) {
              Rectangle().fill(.white).frame(height: 1).padding(.horizontal, 1).padding(.top, 1)
            }
            .padding(5).background(paper)
        }.buttonStyle(.plain).accessibilityLabel("Close \(state.title)")
        Spacer()
      }.padding(.horizontal, 7)
    }.overlay(alignment: .top) { Rectangle().fill(.white).frame(height: 1) }
  }
}

private struct System7Icon: View {
  let symbol: PixelSymbol
  let selected: Bool
  private var colour: Color {
    switch symbol {
    case .folder: Color(red: 0.97, green: 0.85, blue: 0.40)
    case .aquarium, .chooser: Color(red: 0.60, green: 0.80, blue: 0.96)
    case .activity: Color(red: 0.64, green: 0.85, blue: 0.55)
    case .teapot: Color(red: 0.93, green: 0.65, blue: 0.65)
    case .scrapbook, .puzzle: Color(red: 0.79, green: 0.69, blue: 0.90)
    case .clock: Color(red: 1, green: 0.94, blue: 0.73)
    default: Color(white: 0.82)
    }
  }
  var body: some View {
    Canvas { context, size in
      let scale = size.width / 16
      for (y, row) in symbol.rows.enumerated() {
        for (x, pixel) in row.enumerated() where pixel != " " {
          let rect = CGRect(
            x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale)
          let fill = pixel == "#" ? (selected ? Color.white : .black) : colour
          context.fill(Path(rect), with: .color(fill))
          if pixel != "#" {
            context.fill(
              Path(rect),
              with: .color(
                selected
                  ? Color.black.opacity(0.45)
                  : y < 5 ? Color.white.opacity(0.4) : y > 11 ? Color.black.opacity(0.15) : .clear))
          }
        }
      }
    }
  }
}
