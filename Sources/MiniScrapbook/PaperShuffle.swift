import MiniCore
import MiniUI
import SwiftUI

extension ScrapbookApplication {
  public static let filingEffect = MiniPlayfulEffect(
    id: "scrapbook.paper-shuffle", name: "Paper shuffle",
    description: "A brief rustle of paper when scraps are filed. No actual paper required.",
    enabledByDefault: false)
}
struct PaperShuffle: ViewModifier {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.miniWindowActive) private var active
  @Environment(\.miniDesktopSuspended) private var suspended
  let enabled: Bool
  let pulse: Int
  func body(content: Content) -> some View {
    let animates = enabled && !reduceMotion && active && !suspended
    return content.keyframeAnimator(initialValue: 0.0, trigger: pulse) { view, angle in
      view.rotationEffect(.degrees(animates ? angle : 0))
    } keyframes: { _ in
      CubicKeyframe(1.5, duration: 0.08)
      CubicKeyframe(-1, duration: 0.10)
      CubicKeyframe(0, duration: 0.15)
    }
  }
}
