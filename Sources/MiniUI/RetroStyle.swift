import SwiftUI

/// Semantic icons can be replaced by a theme's own artwork at any requested size.
public struct PixelIcon: View {
  @Environment(\.miniTheme) private var theme
  let symbol: PixelSymbol
  let scale: CGFloat
  let selected: Bool

  public init(symbol: PixelSymbol, scale: CGFloat = 2, selected: Bool = false) {
    self.symbol = symbol
    self.scale = scale
    self.selected = selected
  }

  public var body: some View {
    Group {
      if let render = theme.icon {
        render(symbol, 16 * scale, selected, theme)
      } else {
        ZStack {
          pixels(ink: false).fill(selected ? .clear : theme.paper)
          pixels(ink: true).fill(selected ? theme.selectionInk : theme.ink)
        }
      }
    }
    .frame(width: 16 * scale, height: 16 * scale)
    .accessibilityHidden(true)
  }
  private func pixels(ink: Bool) -> Path {
    Path { path in
      for (y, row) in symbol.rows.enumerated() {
        for (x, pixel) in row.enumerated() where pixel != " " && (pixel == "#") == ink {
          path.addRect(
            CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale, width: scale, height: scale))
        }
      }
    }
  }

}

public struct RetroButtonStyle: ButtonStyle {
  @Environment(\.miniTheme) private var theme
  @Environment(\.isEnabled) private var enabled
  public init() {}
  public func makeBody(configuration: Configuration) -> some View {
    let state = ThemeControlState(pressed: configuration.isPressed, enabled: enabled)
    Group {
      if let render = theme.button {
        render(AnyView(configuration.label), state, theme)
      } else {
        configuration.label
          .font(theme.typography.body)
          .padding(.horizontal, theme.buttonHorizontalPadding)
          .padding(.vertical, theme.buttonVerticalPadding)
          .foregroundStyle(state.pressed ? theme.selectionInk : theme.ink)
          .background { ThemeSurfaceView(state.pressed ? theme.selection : .solid(theme.paper)) }
          .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius))
          .overlay(
            RoundedRectangle(cornerRadius: theme.buttonCornerRadius).strokeBorder(
              theme.ink, lineWidth: 1)
          )
          .offset(y: state.pressed ? 1 : 0)
          .opacity(state.enabled ? 1 : 0.4)
      }
    }
  }
}

public struct ThemeWindowTitleBar: View {
  @Environment(\.miniTheme) private var theme
  let state: ThemeWindowState
  public init(
    title: String, active: Bool, close: @escaping @MainActor () -> Void,
    minimise: (@MainActor () -> Void)? = nil, zoom: (@MainActor () -> Void)? = nil,
    zoomed: Bool = false, shade: (@MainActor () -> Void)? = nil, shaded: Bool = false
  ) {
    state = ThemeWindowState(
      title: title, active: active, close: close, minimise: minimise, zoom: zoom, zoomed: zoomed,
      shade: shade, shaded: shaded)
  }

  public var body: some View {
    Group {
      if let render = theme.titleBar {
        render(state, theme)
      } else {
        ZStack {
          VStack(spacing: 2) {
            ForEach(0..<6) { _ in Rectangle().frame(height: 1) }
          }
          .opacity(state.active ? 1 : 0)
          .frame(maxWidth: .infinity)
          .padding(.leading, 30)
          .accessibilityHidden(true)
          Text(state.title).font(theme.typography.title).lineLimit(1)
            .padding(.horizontal, 8).background { Rectangle().fill(theme.paper) }
            .padding(.horizontal, 30)
          HStack {
            Button(action: state.close) {
              Rectangle().fill(theme.paper)
                .frame(width: 12, height: 12)
                .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
                .padding(5).background { Rectangle().fill(theme.paper) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(state.title)")
            Spacer()
          }
        }
        .padding(.horizontal, 8)
        .background { Rectangle().fill(theme.paper) }
      }
    }
    .frame(height: theme.titleBarHeight)
    .foregroundStyle(theme.ink)
  }
}

/// Uses the same surfaces, chrome, controls, and icons as the desktop.
public struct MiniThemePreview: View {
  private let definition: MiniThemeDefinition
  @State private var image: CGImage?
  public init(_ definition: MiniThemeDefinition) { self.definition = definition }
  public var body: some View {
    Group {
      if let image {
        Image(decorative: image, scale: 2).renderingMode(.original).resizable()
      } else {
        Color.clear
      }
    }
    .task(id: definition.id) {
      // Render after layout, never recursively from a containing view's body or initializer.
      let renderer = ImageRenderer(
        content: ThemePreviewScene(definition: definition).frame(width: 300, height: 192))
      renderer.scale = 2
      image = renderer.cgImage
    }
    .accessibilityHidden(true)
  }
}

/// Snapshot only the preview, isolating its appearance from the containing selection button.
struct ThemePreviewScene: View {
  let definition: MiniThemeDefinition
  public var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        ThemeSurfaceView(definition.desktop)
        HStack {
          PixelIcon(symbol: .computer, scale: 1)
          Text("File   View").font(definition.typography.title)
          Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: definition.menuBarHeight)
        .background { ThemeSurfaceView(definition.menuBar) }
        VStack(spacing: 0) {
          ThemeWindowTitleBar(title: "Hello Mini", active: true, close: {}, minimise: {}, zoom: {})
          HStack {
            PixelIcon(symbol: .folder)
            Button("OK") {}.buttonStyle(RetroButtonStyle())
          }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 224, height: 120)
        .themeFrame(definition.window)
        .offset(x: 22, y: 50)
      }
      .frame(width: 300, height: 192)
      .scaleEffect(x: geometry.size.width / 300, y: geometry.size.height / 192, anchor: .topLeading)
    }
    .environment(\.miniTheme, definition)
    .environment(\.colorScheme, definition.colorScheme)
    .foregroundStyle(definition.ink)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
