import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PaintBitmap: Codable, Equatable, Sendable {
  static let width = 320
  static let height = 200
  var version = 1
  var pixels = Data(repeating: 255, count: width * height)
  var isValid: Bool {
    version == 1 && pixels.count == Self.width * Self.height
      && pixels.allSatisfy { $0 == 0 || $0 == 255 }
  }
  func contains(_ x: Int, _ y: Int) -> Bool {
    (0..<Self.width).contains(x) && (0..<Self.height).contains(y)
  }
  subscript(x: Int, y: Int) -> UInt8 {
    get { contains(x, y) ? pixels[y * Self.width + x] : 255 }
    set { if contains(x, y) { pixels[y * Self.width + x] = newValue } }
  }
  mutating func line(from a: PaintPoint, to b: PaintPoint, erase: Bool, pattern: PaintPattern) {
    var x = a.x
    var y = a.y
    let dx = abs(b.x - x)
    let dy = -abs(b.y - y)
    let sx = x < b.x ? 1 : -1
    let sy = y < b.y ? 1 : -1
    var error = dx + dy
    while true {
      if erase {
        for ox in -2...2 { for oy in -2...2 { self[x + ox, y + oy] = 255 } }
      } else {
        self[x, y] = pattern.ink(x, y)
      }
      if x == b.x && y == b.y { break }
      let twice = error * 2
      if twice >= dy {
        error += dy
        x += sx
      }
      if twice <= dx {
        error += dx
        y += sy
      }
    }
  }
  mutating func fill(at point: PaintPoint, pattern: PaintPattern) {
    guard contains(point.x, point.y) else { return }
    let original = self[point.x, point.y]
    var visited = Set<Int>()
    var queue = [point]
    while let p = queue.popLast() {
      guard contains(p.x, p.y) else { continue }
      let index = p.y * Self.width + p.x
      guard pixels[index] == original, visited.insert(index).inserted else { continue }
      self[p.x, p.y] = pattern.ink(p.x, p.y)
      queue += [
        .init(x: p.x - 1, y: p.y), .init(x: p.x + 1, y: p.y), .init(x: p.x, y: p.y - 1),
        .init(x: p.x, y: p.y + 1),
      ]
    }
  }
  mutating func clear(_ rect: PaintSelection) {
    for y in rect.y..<(rect.y + rect.height) {
      for x in rect.x..<(rect.x + rect.width) { self[x, y] = 255 }
    }
  }
  mutating func move(_ rect: PaintSelection, dx: Int, dy: Int) {
    let original = self
    clear(rect)
    for y in 0..<rect.height {
      for x in 0..<rect.width {
        self[rect.x + x + dx, rect.y + y + dy] = original[rect.x + x, rect.y + y]
      }
    }
  }
  func image() -> CGImage? {
    guard isValid, let provider = CGDataProvider(data: pixels as CFData) else { return nil }
    return CGImage(
      width: Self.width, height: Self.height, bitsPerComponent: 8, bitsPerPixel: 8,
      bytesPerRow: Self.width, space: CGColorSpaceCreateDeviceGray(),
      bitmapInfo: CGBitmapInfo(rawValue: 0),
      provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
  }
  func png() throws -> Data {
    let data = NSMutableData()
    guard let image = image(),
      let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, 1, nil)
    else { throw PaintError.invalid }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw PaintError.invalid }
    return data as Data
  }
}
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
enum PaintPattern: String, CaseIterable {
  case black = "Black"
  case dots = "Dots"
  case checks = "Checks"
  case stripes = "Stripes"
  case white = "White"
  func ink(_ x: Int, _ y: Int) -> UInt8 {
    switch self {
    case .black: 0
    case .white: 255
    case .dots: x % 4 == 0 && y % 4 == 0 ? 0 : 255
    case .checks: (x + y) % 2 == 0 ? 0 : 255
    case .stripes: (x + y) % 4 < 2 ? 0 : 255
    }
  }
}
enum PaintError: LocalizedError {
  case invalid
  var errorDescription: String? {
    "The drawing could not be read or written. Its saved file has been left intact."
  }
}
