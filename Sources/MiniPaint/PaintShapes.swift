import Foundation

extension PaintBitmap {
  enum Shape { case line, rectangle, ellipse }
  mutating func shape(
    _ shape: Shape, from a: PaintPoint, to b: PaintPoint, filled: Bool, pattern: PaintPattern
  ) {
    guard contains(a.x, a.y), contains(b.x, b.y) else { return }
    let rect = PaintSelection(from: a, to: b)
    switch shape {
    case .line:
      line(from: a, to: b, erase: false, pattern: pattern)
    case .rectangle:
      for y in rect.y..<(rect.y + rect.height) {
        for x in rect.x..<(rect.x + rect.width) {
          if filled || x == rect.x || x == rect.x + rect.width - 1 || y == rect.y
            || y == rect.y + rect.height - 1
          {
            self[x, y] = pattern.ink(x, y)
          }
        }
      }
    case .ellipse:
      // Pixel-centred scan lines give a bounded raster, including one-pixel/odd/even shapes.
      let rx = Double(rect.width) / 2
      let ry = Double(rect.height) / 2
      let cx = Double(rect.x) + rx - 0.5
      let cy = Double(rect.y) + ry - 0.5
      var spans: [(Int, Int)] = []
      for y in rect.y..<(rect.y + rect.height) {
        let dy = (Double(y) - cy) / ry
        let reach = rx * sqrt(max(0, 1 - dy * dy))
        let left = max(rect.x, Int(ceil(cx - reach)))
        let right = min(rect.x + rect.width - 1, Int(floor(cx + reach)))
        spans.append((left, max(left, right)))
      }
      for row in spans.indices {
        let (left, right) = spans[row]
        for x in left...right {
          let verticalEdge =
            row == 0 || row == spans.count - 1
            || x < spans[max(0, row - 1)].0 || x > spans[max(0, row - 1)].1
            || x < spans[min(spans.count - 1, row + 1)].0
            || x > spans[min(spans.count - 1, row + 1)].1
          if filled || x == left || x == right || verticalEdge {
            self[x, rect.y + row] = pattern.ink(x, rect.y + row)
          }
        }
      }
    }
  }
}
