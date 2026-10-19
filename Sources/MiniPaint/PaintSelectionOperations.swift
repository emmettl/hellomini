import Foundation

extension PaintBitmap {
  enum SelectionOperation: String, CaseIterable {
    case flipHorizontal = "Flip Horizontally"
    case flipVertical = "Flip Vertically"
    case invert = "Invert Ink"
    case duplicate = "Duplicate Selection"
  }
  /// Uses an immutable source so overlapping duplicates and flips cannot smear their input.
  mutating func transform(_ rect: PaintSelection, operation: SelectionOperation) -> PaintSelection {
    guard rect.isValid else { return rect }
    let original = self
    func offset(_ origin: Int, _ length: Int, _ limit: Int) -> Int {
      let forward = limit - origin - length
      if forward >= 8 { return 8 }
      if origin >= 8 { return -8 }
      if forward > 0 { return forward }
      return -min(8, origin)
    }
    let dx = operation == .duplicate ? offset(rect.x, rect.width, Self.width) : 0
    let dy = operation == .duplicate ? offset(rect.y, rect.height, Self.height) : 0
    var target = rect
    target.x += dx
    target.y += dy
    for y in 0..<rect.height {
      for x in 0..<rect.width {
        let sx = operation == .flipHorizontal ? rect.width - x - 1 : x
        let sy = operation == .flipVertical ? rect.height - y - 1 : y
        let value = original[rect.x + sx, rect.y + sy]
        self[target.x + x, target.y + y] = operation == .invert ? 255 - value : value
      }
    }
    return target
  }
}

extension PaintSelection {
  var isValid: Bool {
    x >= 0 && y >= 0 && width > 0 && height > 0
      && width <= PaintBitmap.width && height <= PaintBitmap.height
      && x <= PaintBitmap.width - width && y <= PaintBitmap.height - height
  }
}
