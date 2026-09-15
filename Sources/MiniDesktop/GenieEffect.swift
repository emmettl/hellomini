import SwiftUI

/// The genie funnel: a window's rectangle poured toward a point in the dock.
enum GenieGeometry {
  /// Corners in top-left, top-right, bottom-right, bottom-left order.
  static func quad(window: CGRect, target: CGPoint, progress: CGFloat) -> [CGPoint] {
    let p = min(1, max(0, progress))
    func ease(from start: CGFloat, to end: CGFloat) -> CGFloat {
      let x = min(1, max(0, (p - start) / (end - start)))
      return x * x * (3 - 2 * x)
    }
    func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    // The bottom edge leads into the dock; the top edge follows, like sand through a funnel.
    let bottom = ease(from: 0, to: 0.65)
    let top = ease(from: 0.25, to: 1)
    let half: CGFloat = 3
    return [
      CGPoint(x: mix(window.minX, target.x - half, top), y: mix(window.minY, target.y - 3, top)),
      CGPoint(x: mix(window.maxX, target.x + half, top), y: mix(window.minY, target.y - 3, top)),
      CGPoint(
        x: mix(window.maxX, target.x + half, bottom), y: mix(window.maxY, target.y, bottom)),
      CGPoint(
        x: mix(window.minX, target.x - half, bottom), y: mix(window.maxY, target.y, bottom)),
    ]
  }

  /// The projective transform taking `window` onto `quad`, in the window's parent coordinates.
  static func transform(window: CGRect, quad: [CGPoint]) -> ProjectionTransform {
    guard quad.count == 4, window.width > 0, window.height > 0 else { return ProjectionTransform() }
    let x0: CGFloat = quad[0].x
    let y0: CGFloat = quad[0].y
    let x1: CGFloat = quad[1].x
    let y1: CGFloat = quad[1].y
    let x2: CGFloat = quad[2].x
    let y2: CGFloat = quad[2].y
    let x3: CGFloat = quad[3].x
    let y3: CGFloat = quad[3].y
    // Unit square to quadrilateral, after Heckbert's projective mapping.
    let dx1: CGFloat = x1 - x2
    let dx2: CGFloat = x3 - x2
    let dx3: CGFloat = x0 - x1 + x2 - x3
    let dy1: CGFloat = y1 - y2
    let dy2: CGFloat = y3 - y2
    let dy3: CGFloat = y0 - y1 + y2 - y3
    var g: CGFloat = 0
    var h: CGFloat = 0
    if abs(dx3) > 1e-9 || abs(dy3) > 1e-9 {
      let denominator: CGFloat = dx1 * dy2 - dx2 * dy1
      guard abs(denominator) > 1e-9 else { return ProjectionTransform() }
      g = (dx3 * dy2 - dx2 * dy3) / denominator
      h = (dx1 * dy3 - dx3 * dy1) / denominator
    }
    let a: CGFloat = x1 - x0 + g * x1
    let b: CGFloat = x3 - x0 + h * x3
    let d: CGFloat = y1 - y0 + g * y1
    let e: CGFloat = y3 - y0 + h * y3
    // Compose with the window-to-unit-square normalisation.
    let u: CGFloat = 1 / window.width
    let v: CGFloat = 1 / window.height
    let ou: CGFloat = -window.minX * u
    let ov: CGFloat = -window.minY * v
    var transform = ProjectionTransform()
    transform.m11 = a * u
    transform.m12 = d * u
    transform.m13 = g * u
    transform.m21 = b * v
    transform.m22 = e * v
    transform.m23 = h * v
    transform.m31 = a * ou + b * ov + x0
    transform.m32 = d * ou + e * ov + y0
    transform.m33 = g * ou + h * ov + 1
    return transform
  }
}

/// Animatable, and the identity at rest, so live windows keep their state and crisp rendering.
struct GenieEffect: GeometryEffect {
  var progress: CGFloat
  let window: CGRect
  let target: CGPoint
  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }
  func effectValue(size: CGSize) -> ProjectionTransform {
    guard progress > 0.0001 else { return ProjectionTransform() }
    return GenieGeometry.transform(
      window: window, quad: GenieGeometry.quad(window: window, target: target, progress: progress))
  }
}
