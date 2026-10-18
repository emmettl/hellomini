import SwiftUI

/// Inactive windows have one activation target rather than a second set of keyboard controls.
struct WindowInteraction: ViewModifier {
  let active: Bool
  let title: String
  let activate: () -> Void

  func body(content: Content) -> some View {
    ZStack {
      content.disabled(!active)
        .accessibilityElement(children: active ? .contain : .ignore)
        .accessibilityHidden(!active)
      if !active {
        Button(action: activate) { Color.clear.contentShape(Rectangle()) }
          .buttonStyle(.plain)
          .accessibilityLabel("Activate \(title) window")
      }
    }
  }
}

enum PhysicalWindowMotion {
  static func allows(enabled: Bool, reduceMotion: Bool, active: Bool) -> Bool {
    enabled && !reduceMotion && active
  }

  static func impulse(translation: CGSize) -> CGFloat {
    guard translation.width.isFinite, translation.height.isFinite else { return 0 }
    return min(1, hypot(translation.width, translation.height) / 160)
  }
}
