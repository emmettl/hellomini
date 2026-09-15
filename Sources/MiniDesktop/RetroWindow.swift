import MiniUI
import SwiftUI

struct RetroWindow<Content: View>: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let title: String
  let minimumSize: CGSize
  let desktopSize: CGSize
  @Binding var placement: WindowPlacement
  let active: Bool
  let activate: () -> Void
  let close: @MainActor () -> Void
  let minimise: @MainActor () -> Void
  let zoom: @MainActor () -> Void
  let zoomed: Bool
  var shade: (@MainActor () -> Void)? = nil
  var shaded = false
  @ViewBuilder let content: () -> Content
  @GestureState private var drag: WindowDrag?
  @GestureState private var resize: WindowResize?

  private var size: CGSize {
    resize?.size(minimum: minimumSize, desktop: desktopSize)
      ?? WindowResize.constrain(
        placement.size, minimum: minimumSize,
        maximum: CGSize(
          width: desktopSize.width - 16, height: desktopSize.height - theme.menuBarHeight - 18))
  }

  private var bounds: WindowBounds {
    WindowBounds(desktopSize: desktopSize, windowSize: size, menuBarHeight: theme.menuBarHeight)
  }

  private var position: CGPoint {
    resize?.origin ?? drag?.position(in: bounds) ?? bounds.constrain(placement.origin)
  }

  var body: some View {
    VStack(spacing: 0) {
      ThemeWindowTitleBar(
        title: title, active: active, close: close, minimise: minimise, zoom: zoom, zoomed: zoomed,
        shade: shade, shaded: shaded
      )
      .contentShape(Rectangle())
      // Window shade: a double-clicked title bar rolls the window up, or back down.
      .simultaneousGesture(TapGesture(count: 2).onEnded { shade?() })
      .accessibilityActions {
        if let shade { Button(shaded ? "Expand window" : "Collapse window", action: shade) }
      }
      .gesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .named(DesktopCoordinateSpace.windows))
          .updating($drag) { value, state, transaction in
            transaction.disablesAnimations = true
            if state == nil {
              state = WindowDrag(
                origin: placement.origin, startLocation: value.startLocation, bounds: bounds)
            }
            state?.location = value.location
          }
          .onChanged { _ in if !active { activate() } }
          .onEnded { value in
            var completed =
              drag
              ?? WindowDrag(
                origin: placement.origin, startLocation: value.startLocation, bounds: bounds)
            completed.location = value.location
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
              placement = WindowPlacement(origin: completed.position(in: bounds), size: size)
            }
          }
      )
      Rectangle().fill(theme.ink).frame(height: theme.titleBarDivider)
      let viewport = WindowContentLayout(
        window: size, minimum: minimumSize,
        chromeHeight: theme.titleBarHeight + theme.titleBarDivider + 17)
      ScrollView(viewport.scrollAxes) {
        content().frame(width: viewport.content.width, height: viewport.content.height).clipped()
      }
      .scrollIndicators(.visible)
      .frame(width: viewport.visible.width, height: viewport.visible.height)
      Rectangle().fill(theme.ink).frame(height: 1)
      HStack(spacing: 0) {
        Spacer(minLength: 0)
        resizeGrip
      }
      .frame(height: 16)
      .background { Rectangle().fill(theme.paper) }
    }
    .frame(
      width: size.width,
      height: shaded ? theme.titleBarHeight + theme.titleBarDivider : size.height, alignment: .top
    )
    .themeFrame(active ? theme.window : theme.inactiveWindow)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: shaded)
    .offset(x: position.x, y: position.y)
    .simultaneousGesture(TapGesture().onEnded { activate() })
  }

  private var resizeGrip: some View {
    Path { path in
      for inset in stride(from: 3, through: 11, by: 4) {
        path.move(to: CGPoint(x: inset, y: 13))
        path.addLine(to: CGPoint(x: 13, y: inset))
      }
    }
    .stroke(theme.ink, lineWidth: 1)
    .frame(width: 16, height: 16)
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 1, coordinateSpace: .named(DesktopCoordinateSpace.windows))
        .updating($resize) { value, state, transaction in
          transaction.disablesAnimations = true
          if state == nil {
            state = WindowResize(origin: position, size: size, startLocation: value.startLocation)
          }
          state?.location = value.location
        }
        .onChanged { _ in if !active { activate() } }
        .onEnded { value in
          var completed =
            resize
            ?? WindowResize(origin: position, size: size, startLocation: value.startLocation)
          completed.location = value.location
          commitResize(completed)
        }
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Resize \(title)")
    .accessibilityValue("\(Int(size.width)) by \(Int(size.height)) points")
    .accessibilityAdjustableAction { direction in
      var change = WindowResize(origin: position, size: size, startLocation: .zero)
      switch direction {
      case .increment: change.location = CGPoint(x: 20, y: 20)
      case .decrement: change.location = CGPoint(x: -20, y: -20)
      @unknown default: return
      }
      activate()
      commitResize(change)
    }
    .miniHelp("Drag to resize this window.")
  }

  private func commitResize(_ resize: WindowResize) {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      placement = WindowPlacement(
        origin: resize.origin, size: resize.size(minimum: minimumSize, desktop: desktopSize))
    }
  }
}
