import SwiftUI

private struct BalloonHelpEnabledKey: EnvironmentKey {
  static let defaultValue = false
}
extension EnvironmentValues {
  public var miniBalloonHelp: Bool {
    get { self[BalloonHelpEnabledKey.self] }
    set { self[BalloonHelpEnabledKey.self] = newValue }
  }
}
public struct BalloonHelpEntry: Sendable {
  public let text: String
  public let anchor: Anchor<CGRect>
}
public struct BalloonHelpPreference: PreferenceKey {
  public static let defaultValue: [BalloonHelpEntry] = []
  public static func reduce(value: inout [BalloonHelpEntry], nextValue: () -> [BalloonHelpEntry]) {
    value += nextValue()
  }
}
private struct BalloonHelpModifier: ViewModifier {
  @Environment(\.miniBalloonHelp) private var enabled
  @State private var hovering = false
  @State private var showing = false
  let text: String
  func body(content: Content) -> some View {
    content
      .help(text)
      .accessibilityHint(text)
      .onHover { hovering = $0 }
      .task(id: hovering && enabled) {
        showing = false
        guard hovering && enabled else { return }
        do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
        showing = true
      }
      .anchorPreference(key: BalloonHelpPreference.self, value: .bounds) {
        showing && hovering && enabled ? [BalloonHelpEntry(text: text, anchor: $0)] : []
      }
  }
}
extension View {
  /// Native help and accessibility hints remain available with balloons disabled.
  public func miniHelp(_ text: String) -> some View { modifier(BalloonHelpModifier(text: text)) }
}

public struct BalloonHelpOverlay: View {
  @Environment(\.miniTheme) private var theme
  private let entries: [BalloonHelpEntry]
  public init(entries: [BalloonHelpEntry]) { self.entries = entries }
  public var body: some View {
    GeometryReader { geometry in
      if let entry = entries.last {
        let anchor = geometry[entry.anchor]
        let below = anchor.maxY < geometry.size.height - 125
        Text(entry.text).font(theme.typography.body)
          .foregroundStyle(theme.ink)
          .padding(12)
          .frame(width: min(260, geometry.size.width - 16), alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .background(theme.paper, in: RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.ink, lineWidth: 1.5))
          .shadow(color: theme.ink.opacity(0.3), radius: 0, x: 3, y: 3)
          .offset(
            x: max(8, min(anchor.midX - 130, geometry.size.width - 268)),
            y: below ? anchor.maxY + 10 : max(8, anchor.minY - 110))
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
