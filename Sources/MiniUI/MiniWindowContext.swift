import SwiftUI

extension EnvironmentValues {
  /// The desktop updates visibility after changes to window geometry or stacking order.
  @Entry public var miniDesktopSuspended = false
  @Entry public var miniWindowVisible = true
  @Entry public var miniWindowActive = true
}

/// A compact explanation that also works inside a small desk accessory.
public struct MiniEmptyState: View {
  @Environment(\.miniTheme) private var theme
  private let title: String
  private let message: String
  public init(_ title: String, message: String) {
    self.title = title
    self.message = message
  }
  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(theme.typography.title)
      Text(message).font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
  }
}
