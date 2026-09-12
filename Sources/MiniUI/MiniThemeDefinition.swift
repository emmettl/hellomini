import AppKit
import MiniCore
import SwiftUI

/// Surfaces can also be supplied by a module as a custom SwiftUI view.
public enum ThemeSurface: Sendable {
  case solid(Color)
  case gradient([Color])
  case dots(background: Color, foreground: Color, spacing: CGFloat)
  case pinstripes(background: Color, foreground: Color, spacing: CGFloat, lineWidth: CGFloat)
  case image(name: String, bundle: Bundle, tiled: Bool)
  case custom(@MainActor @Sendable () -> AnyView)
}

public struct ThemeSurfaceView: View {
  public let surface: ThemeSurface
  public init(_ surface: ThemeSurface) { self.surface = surface }

  public var body: some View {
    Group {
      switch surface {
      case .solid(let color): Rectangle().fill(color)
      case .gradient(let colors):
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
      case .dots(let background, let foreground, let spacing):
        Canvas { context, size in
          context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
          let step = max(1, spacing)
          var dots = Path()
          for row in 0..<Int(ceil(size.height / step)) {
            for x in stride(from: row.isMultiple(of: 2) ? 0 : step / 2, to: size.width, by: step) {
              dots.addRect(CGRect(x: x, y: CGFloat(row) * step, width: 1, height: 1))
            }
          }
          context.fill(dots, with: .color(foreground))
        }
      case .pinstripes(let background, let foreground, let spacing, let lineWidth):
        Canvas { context, size in
          context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
          var lines = Path()
          for y in stride(from: CGFloat.zero, to: size.height, by: max(1, spacing)) {
            lines.addRect(CGRect(x: 0, y: y, width: size.width, height: max(0, lineWidth)))
          }
          context.fill(lines, with: .color(foreground))
        }
      case .image(let name, let bundle, let tiled):
        if let url = bundle.url(forResource: name, withExtension: nil),
          let image = NSImage(contentsOf: url)
        {
          Image(nsImage: image).resizable(resizingMode: tiled ? .tile : .stretch)
        } else {
          Image(name, bundle: bundle).resizable(resizingMode: tiled ? .tile : .stretch)
        }
      case .custom(let render): render()
      }
    }
    .accessibilityHidden(true)
  }
}

public struct ThemeTypography: Sendable {
  public var body = Font.system(size: 13, weight: .medium, design: .monospaced)
  public var small = Font.system(size: 11, weight: .medium, design: .monospaced)
  public var title = Font.system(size: 14, weight: .bold, design: .monospaced)
  public var display: @Sendable (CGFloat) -> Font = {
    .system(size: $0, weight: .bold, design: .monospaced)
  }
  public init() {}
}

public struct ThemeFrameStyle: Sendable {
  public var surface: ThemeSurface
  public var border: Color
  public var borderWidth: CGFloat = 2
  public var cornerRadius: CGFloat = 0
  public var shadow: Color
  public var shadowRadius: CGFloat = 0
  public var shadowOffset = CGSize(width: 3, height: 3)
  public init(surface: ThemeSurface, border: Color, shadow: Color) {
    self.surface = surface
    self.border = border
    self.shadow = shadow
  }
}

public struct ThemeWindowState {
  public let title: String
  public let active: Bool
  public let close: @MainActor () -> Void
}

public struct ThemeControlState {
  public let pressed: Bool
  public let enabled: Bool
}

/// Value-based styling and optional renderers; application state never belongs to a theme.
public struct MiniThemeDefinition: Identifiable, Sendable {
  public let metadata: MiniTheme
  public var id: String { metadata.id }
  public var colorScheme: ColorScheme = .light
  public var ink: Color = .black
  public var paper: Color = .white
  public var selectionInk: Color = .white
  public var selection: ThemeSurface = .solid(.black)
  public var accent: Color = .black
  public var typography = ThemeTypography()
  public var desktop: ThemeSurface = .dots(background: .white, foreground: .black, spacing: 4)
  public var window = ThemeFrameStyle(surface: .solid(.white), border: .black, shadow: .black)
  public var inactiveWindow = ThemeFrameStyle(
    surface: .solid(.white), border: .black, shadow: .black)
  public var menu = ThemeFrameStyle(surface: .solid(.white), border: .black, shadow: .black)
  public var menuBar: ThemeSurface = .solid(.white)
  public var titleBarHeight: CGFloat = 30
  public var titleBarDivider: CGFloat = 1
  public var menuBarHeight: CGFloat = 30
  public var menuBarBorderWidth: CGFloat = 2
  public var menuRowHeight: CGFloat = 28
  public var buttonCornerRadius: CGFloat = 0
  public var buttonHorizontalPadding: CGFloat = 10
  public var buttonVerticalPadding: CGFloat = 5

  /// Renderers get semantic state. The shell still owns drag, focus, shortcuts, and commands.
  public var titleBar: (@MainActor @Sendable (ThemeWindowState, MiniThemeDefinition) -> AnyView)?
  public var button:
    (@MainActor @Sendable (AnyView, ThemeControlState, MiniThemeDefinition) -> AnyView)?
  public var icon:
    (@MainActor @Sendable (PixelSymbol, CGFloat, Bool, MiniThemeDefinition) -> AnyView)?

  public init(metadata: MiniTheme) { self.metadata = metadata }

  public static let classic = MiniThemeDefinition(metadata: .classic)
  public static let paper: MiniThemeDefinition = {
    var theme = MiniThemeDefinition(metadata: .paper)
    theme.desktop = .solid(.white)
    return theme
  }()
  public static let midnight: MiniThemeDefinition = {
    var theme = MiniThemeDefinition(metadata: .midnight)
    theme.colorScheme = .dark
    theme.ink = .white
    theme.paper = .black
    theme.selectionInk = .black
    theme.selection = .solid(.white)
    theme.accent = .white
    theme.desktop = .dots(background: .black, foreground: .white, spacing: 4)
    theme.window = ThemeFrameStyle(surface: .solid(.black), border: .white, shadow: .white)
    theme.inactiveWindow = theme.window
    theme.menu = theme.window
    theme.menuBar = .solid(.black)
    return theme
  }()
}

public struct MiniThemeRegistry: Sendable {
  public let themes: [MiniThemeDefinition]
  public var metadata: [MiniTheme] { themes.map(\.metadata) }
  public init(_ themes: [MiniThemeDefinition]) {
    precondition(!themes.isEmpty, "At least one theme is required")
    precondition(Set(themes.map(\.id)).count == themes.count, "Theme IDs must be unique")
    self.themes = themes
  }
  public func definition(for id: String) -> MiniThemeDefinition? { themes.first { $0.id == id } }
  public static let builtIns = MiniThemeRegistry([.classic, .paper, .midnight])
}

extension EnvironmentValues {
  @Entry public var miniTheme: MiniThemeDefinition = .classic
}

/// Shared by live windows, menu panels, and previews. Clips content to the themed frame.
private struct ThemeFrameModifier: ViewModifier {
  let style: ThemeFrameStyle
  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: style.cornerRadius)
    content
      .background { ThemeSurfaceView(style.surface) }
      .clipShape(shape)
      .overlay(shape.strokeBorder(style.border, lineWidth: style.borderWidth))
      .background {
        shape.fill(style.shadow)
          .blur(radius: style.shadowRadius)
          .offset(style.shadowOffset)
      }
  }
}

extension View {
  public func themeFrame(_ style: ThemeFrameStyle) -> some View {
    modifier(ThemeFrameModifier(style: style))
  }
}
