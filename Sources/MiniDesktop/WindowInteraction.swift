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

/// Keep the renderer independent of RetroWindow's application-specific generic content type.
struct PhysicalWindowSettling: ViewModifier {
  let amount: CGFloat
  let trigger: Int
  let rounded: Bool

  func body(content: Content) -> some View {
    content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) {
      [amount] view, progress in
      let deformation = progress * amount
      view.scaleEffect(x: 1 + deformation * 0.004, y: 1 - deformation * 0.006, anchor: .top)
    } keyframes: { [rounded] _ in
      LinearKeyframe(1, duration: 0.06)
      SpringKeyframe(0, duration: rounded ? 0.4 : 0.28, spring: rounded ? .bouncy : .smooth)
    }
  }
}
