import CoreGraphics
import SwiftUI
import Testing

@testable import MiniDesktop

private func apply(_ t: ProjectionTransform, _ p: CGPoint) -> CGPoint {
  let w = p.x * t.m13 + p.y * t.m23 + t.m33
  return CGPoint(
    x: (p.x * t.m11 + p.y * t.m21 + t.m31) / w, y: (p.x * t.m12 + p.y * t.m22 + t.m32) / w)
}

@Test func genieFunnelsTheWindowCornersTowardTheDock() {
  let window = CGRect(x: 100, y: 80, width: 300, height: 200)
  let target = CGPoint(x: 520, y: 690)
  let corners = [
    CGPoint(x: window.minX, y: window.minY), CGPoint(x: window.maxX, y: window.minY),
    CGPoint(x: window.maxX, y: window.maxY), CGPoint(x: window.minX, y: window.maxY),
  ]
  #expect(GenieGeometry.quad(window: window, target: target, progress: 0) == corners)
  for progress in [0.2, 0.5, 0.8, 1.0] as [CGFloat] {
    let quad = GenieGeometry.quad(window: window, target: target, progress: progress)
    let transform = GenieGeometry.transform(window: window, quad: quad)
    for (corner, expected) in zip(corners, quad) {
      let mapped = apply(transform, corner)
      #expect(abs(mapped.x - expected.x) < 0.01 && abs(mapped.y - expected.y) < 0.01)
    }
  }
  let middle = GenieGeometry.quad(window: window, target: target, progress: 0.5)
  #expect(middle[2].y - window.maxY > middle[0].y - window.minY)
  #expect(middle[2].x - middle[3].x < middle[1].x - middle[0].x)
  let end = GenieGeometry.quad(window: window, target: target, progress: 1)
  #expect(end.allSatisfy { abs($0.x - target.x) <= 3 && abs($0.y - target.y) <= 3 })
  #expect(
    GenieEffect(progress: 0, window: window, target: target).effectValue(size: window.size)
      == ProjectionTransform())
}
