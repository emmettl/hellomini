import SwiftUI

/// Native sheets are outside the desktop's transform. Give their content the same presentation
/// scale, with scrolling when the form is larger than the logical display. Nested sheets each
/// apply the transform once, rather than inheriting a second transform from their parent.
private struct MiniSheetModifier: ViewModifier {
  @Environment(\.miniDisplay) private var display
  @Environment(\.miniTheme) private var theme
  @State private var contentHeight: CGFloat = 400
  let width: CGFloat

  func body(content: Content) -> some View {
    let visibleWidth = min(width, max(1, display.logicalSize.width - 24))
    let visibleHeight = min(contentHeight, max(1, display.logicalSize.height - 32))
    ScrollView([.horizontal, .vertical]) {
      content
        .frame(width: width)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          contentHeight = $0
        }
    }
    .scrollIndicators(.visible)
    .frame(width: visibleWidth, height: visibleHeight)
    .background(theme.paper)
    .scaleEffect(display.scale)
    .frame(width: visibleWidth * display.scale, height: visibleHeight * display.scale)
  }
}

extension View {
  public func miniSheet(width: CGFloat) -> some View {
    modifier(MiniSheetModifier(width: width))
  }
}
