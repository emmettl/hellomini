import Foundation

enum DesktopCoordinateSpace: Hashable { case windows }

struct WindowBounds {
  let desktopSize: CGSize
  let windowSize: CGSize
  let menuBarHeight: CGFloat

  func constrain(_ origin: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(8, origin.x), max(8, desktopSize.width - windowSize.width - 8)),
      y: min(
        max(menuBarHeight + 10, origin.y),
        max(menuBarHeight + 10, desktopSize.height - windowSize.height - 8)))
  }
}

/// Pointer locations are in the stationary desktop coordinate space, never in the moving window.
struct WindowDrag {
  let startOrigin: CGPoint
  let startLocation: CGPoint
  var location: CGPoint

  init(origin: CGPoint, startLocation: CGPoint, bounds: WindowBounds) {
    // A stored origin can be outside the visible bounds after a resize or at first launch.
    startOrigin = bounds.constrain(origin)
    self.startLocation = startLocation
    location = startLocation
  }

  func position(in bounds: WindowBounds) -> CGPoint {
    bounds.constrain(
      CGPoint(
        x: startOrigin.x + location.x - startLocation.x,
        y: startOrigin.y + location.y - startLocation.y))
  }
}
