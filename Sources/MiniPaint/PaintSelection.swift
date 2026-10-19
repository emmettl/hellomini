import Foundation

struct PaintPoint: Equatable, Sendable {
  var x: Int
  var y: Int
}
struct PaintSelection: Equatable, Sendable {
  var x: Int
  var y: Int
  var width: Int
  var height: Int
  init(from a: PaintPoint, to b: PaintPoint) {
    x = min(a.x, b.x)
    y = min(a.y, b.y)
    width = abs(a.x - b.x) + 1
    height = abs(a.y - b.y) + 1
  }
  func contains(_ p: PaintPoint) -> Bool {
    (x..<(x + width)).contains(p.x) && (y..<(y + height)).contains(p.y)
  }
}
