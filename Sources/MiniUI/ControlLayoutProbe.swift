import SwiftUI

/// Optional geometry evidence for layout regression tests. No content or user data is collected.
public struct MiniControlFrames: PreferenceKey {
  public static var defaultValue: [String: CGRect] { [:] }
  public static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, next in next })
  }
}
extension View {
  public func miniControlBounds(_ id: String) -> some View {
    background {
      GeometryReader { geometry in
        Color.clear.preference(
          key: MiniControlFrames.self,
          value: [id: geometry.frame(in: .named("mini-control-layout"))])
      }.accessibilityHidden(true).allowsHitTesting(false)
    }
  }
}
