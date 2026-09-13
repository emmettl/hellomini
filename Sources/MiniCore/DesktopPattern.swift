import Foundation

public struct DesktopPattern: Equatable, Sendable {
  public private(set) var rows: [UInt8]
  public static let initial = DesktopPattern(rows: [0x88, 0, 0x22, 0, 0x88, 0, 0x22, 0])!
  public init?(rows: [UInt8]) {
    guard rows.count == 8 else { return nil }
    self.rows = rows
  }
  public func contains(x: Int, y: Int) -> Bool {
    guard (0..<8).contains(x), (0..<8).contains(y) else { return false }
    return rows[y] & (1 << x) != 0
  }
  public mutating func toggle(x: Int, y: Int) {
    guard (0..<8).contains(x), (0..<8).contains(y) else { return }
    rows[y] ^= 1 << x
  }
}
