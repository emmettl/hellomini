import MiniCore
import MiniUI
import SwiftUI

/// Saver modules supply content and optional lifecycle hooks. The shared host owns idle and input.
@MainActor public struct MiniScreensaverDefinition {
  public let metadata: MiniScreensaver
  let content: () -> AnyView
  let presenting: (Bool) -> Void
  public init(
    metadata: MiniScreensaver, presenting: @escaping (Bool) -> Void = { _ in },
    content: @escaping () -> AnyView
  ) {
    self.metadata = metadata
    self.content = content
    self.presenting = presenting
  }
}
