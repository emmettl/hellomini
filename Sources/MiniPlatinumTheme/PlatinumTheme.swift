import MiniCore
import MiniUI
import SwiftUI

/// A Mac OS 8-inspired Platinum desktop. Uses original artwork and system fonts.
public enum PlatinumTheme {
  static let platinum = Color(white: 0.87)
  static let shadow = Color(white: 0.52)
  static let highlight = Color(red: 0.2, green: 0.22, blue: 0.62)

  public static let definition: MiniThemeDefinition = {
    var theme = MiniThemeDefinition(
      metadata: MiniTheme(
        id: "platinum", name: "Platinum",
        description:
          "Bevelled grey everything, heavy condensed type, and windows that roll up like blinds."))
    theme.desktop = .custom { AnyView(PlatinumDesktop()) }
    theme.accent = highlight
    theme.selection = .solid(highlight)
    theme.typography.body = .system(size: 12, weight: .semibold)
    theme.typography.small = .system(size: 10.5, weight: .medium)
    theme.typography.title = .system(size: 13, weight: .heavy).width(.condensed)
    theme.typography.display = { .system(size: $0, weight: .black).width(.condensed) }
    theme.window = ThemeFrameStyle(surface: .solid(platinum), border: .black, shadow: .black)
    theme.window.borderWidth = 1
    theme.window.shadow = Color.black.opacity(0.55)
    theme.window.shadowOffset = CGSize(width: 2, height: 2)
    theme.inactiveWindow = theme.window
    theme.inactiveWindow.border = shadow
    theme.inactiveWindow.shadow = Color.black.opacity(0.25)
    theme.menu = ThemeFrameStyle(surface: .solid(platinum), border: .black, shadow: .black)
    theme.menu.borderWidth = 1
    theme.menu.shadow = Color.black.opacity(0.5)
    theme.menu.shadowOffset = CGSize(width: 2, height: 2)
    theme.menuBar = .custom { AnyView(Bevel(fill: platinum)) }
    theme.menuBarHeight = 26
    theme.menuBarBorderWidth = 1
    theme.menuRowHeight = 24
    theme.titleBarHeight = 24
    theme.windowShade = true
    theme.titleBar = { state, theme in AnyView(PlatinumTitleBar(state: state, theme: theme)) }
    theme.button = { label, state, theme in
      AnyView(PlatinumButton(label: label, state: state, theme: theme))
    }
    theme.icon = { symbol, size, selected, _ in
      AnyView(PlatinumIcon(symbol: symbol, selected: selected).frame(width: size, height: size))
    }
    return theme
  }()
}

/// Light from the top left: white highlight, grey shadow, platinum face.
struct Bevel: View {
  let fill: Color
  var inset = false
  var body: some View {
    ZStack {
      fill
      VStack(spacing: 0) {
        Rectangle().fill(inset ? PlatinumTheme.shadow : .white).frame(height: 1)
        Spacer(minLength: 0)
        Rectangle().fill(inset ? .white : PlatinumTheme.shadow).frame(height: 1)
      }
      HStack(spacing: 0) {
        Rectangle().fill(inset ? PlatinumTheme.shadow : .white).frame(width: 1)
        Spacer(minLength: 0)
        Rectangle().fill(inset ? .white : PlatinumTheme.shadow).frame(width: 1)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct PlatinumDesktop: View {
  var body: some View {
    Canvas { context, size in
      let base = Color(red: 0.36, green: 0.39, blue: 0.62)
      context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
      var weave = Path()
      for y in stride(from: CGFloat.zero, to: size.height, by: 4) {
        let shift: CGFloat = Int(y / 4).isMultiple(of: 2) ? 0 : 2
        for x in stride(from: shift, to: size.width, by: 4) {
          weave.addRect(CGRect(x: x, y: y, width: 2, height: 1))
        }
      }
      context.fill(weave, with: .color(Color(red: 0.47, green: 0.5, blue: 0.74)))
    }
  }
}

private struct PlatinumTitleBar: View {
  let state: ThemeWindowState
  let theme: MiniThemeDefinition

  var body: some View {
    ZStack {
      Bevel(fill: PlatinumTheme.platinum)
      if state.active {
        VStack(spacing: 1) {
          ForEach(0..<6, id: \.self) { _ in
            VStack(spacing: 0) {
              Rectangle().fill(PlatinumTheme.shadow).frame(height: 1)
              Rectangle().fill(.white).frame(height: 1)
            }
          }
        }
        .padding(.horizontal, 26).padding(.vertical, 3).accessibilityHidden(true)
      }
      Text(state.title).font(theme.typography.title).lineLimit(1)
        .foregroundStyle(state.active ? .black : PlatinumTheme.shadow)
        .padding(.horizontal, 8).background(PlatinumTheme.platinum).padding(.horizontal, 60)
      HStack(spacing: 4) {
        box(.close, action: state.close, label: "Close")
        Spacer(minLength: 0)
        if let zoom = state.zoom {
          box(.zoom, action: zoom, label: state.zoomed ? "Restore size of" : "Zoom")
        }
        if let shade = state.shade {
          box(.collapse, action: shade, label: state.shaded ? "Expand" : "Collapse")
        }
      }
      .padding(.horizontal, 6)
      .opacity(state.active ? 1 : 0)
    }
  }

  private func box(_ kind: PlatinumBox.Kind, action: @escaping @MainActor () -> Void, label: String)
    -> some View
  {
    Button(action: action) { PlatinumBox(kind: kind) }
      .buttonStyle(.plain)
      .accessibilityLabel("\(label) \(state.title)")
      .miniHelp("\(label) \(state.title)")
  }
}

struct PlatinumBox: View {
  enum Kind { case close, zoom, collapse }
  let kind: Kind
  var body: some View {
    ZStack {
      Rectangle().fill(.black)
      Bevel(fill: PlatinumTheme.platinum).padding(1)
      switch kind {
      case .close: EmptyView()
      case .zoom:
        Rectangle().strokeBorder(.black, lineWidth: 1).frame(width: 6, height: 6)
          .offset(x: -1.5, y: -1.5)
      case .collapse:
        Rectangle().fill(.black).frame(width: 7, height: 1)
      }
    }
    .frame(width: 13, height: 13)
  }
}

private struct PlatinumButton: View {
  let label: AnyView
  let state: ThemeControlState
  let theme: MiniThemeDefinition
  var body: some View {
    label.font(theme.typography.body)
      .foregroundStyle(state.pressed ? Color.white : Color.black)
      .padding(.horizontal, 12).padding(.vertical, 5)
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: 3).fill(.black)
          if state.pressed {
            Bevel(fill: Color(white: 0.4), inset: true).clipShape(RoundedRectangle(cornerRadius: 2))
              .padding(1)
          } else {
            Bevel(fill: PlatinumTheme.platinum).clipShape(RoundedRectangle(cornerRadius: 2))
              .padding(1)
          }
        }
      }
      .opacity(state.enabled ? 1 : 0.45)
  }
}

private struct PlatinumIcon: View {
  let symbol: PixelSymbol
  let selected: Bool
  private var colour: Color {
    switch symbol {
    case .folder: Color(red: 0.55, green: 0.6, blue: 0.95)
    case .aquarium, .chooser: Color(red: 0.45, green: 0.78, blue: 0.9)
    case .activity: Color(red: 0.5, green: 0.8, blue: 0.5)
    case .teapot: Color(red: 0.92, green: 0.58, blue: 0.4)
    case .scrapbook, .puzzle: Color(red: 0.8, green: 0.62, blue: 0.9)
    case .clock: Color(red: 0.98, green: 0.88, blue: 0.5)
    default: Color(white: 0.8)
    }
  }
  var body: some View {
    Canvas { context, size in
      let scale = size.width / 16
      for (y, row) in symbol.rows.enumerated() {
        for (x, pixel) in row.enumerated() where pixel != " " {
          let rect = CGRect(
            x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale)
          if pixel == "#" {
            context.fill(Path(rect), with: .color(selected ? PlatinumTheme.highlight : .black))
          } else {
            // Platinum icons shade from a light top-left to a darker bottom-right.
            let light = 0.35 - Double(x + y) / 30 * 0.5
            context.fill(Path(rect), with: .color(colour))
            context.fill(
              Path(rect),
              with: .color(light > 0 ? Color.white.opacity(light) : Color.black.opacity(-light)))
            if selected {
              context.fill(Path(rect), with: .color(PlatinumTheme.highlight.opacity(0.45)))
            }
          }
        }
      }
    }
  }
}
