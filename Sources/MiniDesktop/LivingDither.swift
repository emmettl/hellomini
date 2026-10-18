import AppKit
import MiniCore
import MiniUI
import SwiftUI

/// A bounded, decorative field. No machine or document data enters the animation.
struct LivingDither: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var phase
  @State private var visible = true
  @State private var awake = true
  let windows: [CGRect]
  static func animates(reduceMotion: Bool, visible: Bool, awake: Bool, active: Bool) -> Bool {
    !reduceMotion && visible && awake && active
  }
  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: 1 / 12,
        paused: !Self.animates(
          reduceMotion: reduceMotion, visible: visible, awake: awake, active: phase == .active))
    ) { timeline in
      Canvas { context, size in
        let time =
          reduceMotion
          ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
        var dots = Path()
        for row in 0..<min(90, Int(size.height / 8)) {
          for column in 0..<min(160, Int(size.width / 8)) {
            let x = Double(column) * max(8, size.width / 160)
            let y = Double(row) * max(8, size.height / 90)
            let ripple = sin(x / 57 + time * 0.4) + cos(y / 43 - time * 0.3)
            let near = windows.contains {
              $0.insetBy(dx: -20, dy: -20).contains(CGPoint(x: x, y: y))
            }
            if ripple > (near ? 0.8 : 0.1) {
              dots.addRect(CGRect(x: x, y: y, width: 1, height: 1))
            }
          }
        }
        context.fill(dots, with: .color(theme.ink.opacity(0.24)))
      }
    }
    .allowsHitTesting(false).accessibilityHidden(true)
    .onReceive(
      NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)
    ) { note in
      if let window = note.object as? NSWindow,
        window.identifier?.rawValue == "desktop" || window.title == "Hello Mini"
      {
        visible = window.occlusionState.contains(.visible)
      }
    }
    .onReceive(
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
    ) { _ in awake = false }
    .onReceive(
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
    ) { _ in awake = true }
  }
}
