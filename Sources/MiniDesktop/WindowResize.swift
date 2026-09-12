import Foundation

struct WindowResize {
  let origin: CGPoint
  let startSize: CGSize
  let startLocation: CGPoint
  var location: CGPoint

  init(origin: CGPoint, size: CGSize, startLocation: CGPoint) {
    self.origin = origin
    startSize = size
    self.startLocation = startLocation
    location = startLocation
  }

  func size(minimum: CGSize, desktop: CGSize) -> CGSize {
    Self.constrain(
      CGSize(
        width: startSize.width + location.x - startLocation.x,
        height: startSize.height + location.y - startLocation.y),
      minimum: minimum,
      maximum: CGSize(width: desktop.width - origin.x - 8, height: desktop.height - origin.y - 8))
  }

  static func constrain(_ size: CGSize, minimum: CGSize, maximum: CGSize) -> CGSize {
    CGSize(
      width: min(max(size.width, minimum.width), max(1, maximum.width)),
      height: min(max(size.height, minimum.height), max(1, maximum.height)))
  }
}
