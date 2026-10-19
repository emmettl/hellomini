import MiniCore
import MiniUI
import SwiftUI

struct DesktopSurface: View {
  let theme: MiniThemeDefinition
  let pattern: DesktopPattern?
  var body: some View {
    ZStack {
      ThemeSurfaceView(theme.desktop)
      if let pattern {
        Canvas { context, size in
          context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.paper))
          var dots = Path()
          for y in stride(from: 0, to: Int(ceil(size.height)), by: 8) {
            for x in stride(from: 0, to: Int(ceil(size.width)), by: 8) {
              for py in 0..<8 {
                for px in 0..<8 where pattern.contains(x: px, y: py) {
                  dots.addRect(CGRect(x: x + px, y: y + py, width: 1, height: 1))
                }
              }
            }
          }
          context.fill(dots, with: .color(theme.ink))
        }.allowsHitTesting(false).accessibilityHidden(true)
      }
    }
  }
}
