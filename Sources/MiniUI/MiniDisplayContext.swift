import SwiftUI

/// Host presentation, independent of a theme. All layout and theme dimensions remain logical points.
public struct MiniDisplayContext: Equatable, Sendable {
  public let scale: CGFloat
  public let logicalSize: CGSize
  public var tinyScreen: Bool { scale > 1 }

  public init(scale: CGFloat = 1, logicalSize: CGSize = CGSize(width: 1280, height: 720)) {
    self.scale = scale.isFinite ? max(1, scale) : 1
    self.logicalSize = logicalSize
  }
}

extension EnvironmentValues {
  @Entry public var miniDisplay = MiniDisplayContext()
}
