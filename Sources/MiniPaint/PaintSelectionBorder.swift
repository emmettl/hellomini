import AppKit
import MiniCore
import MiniUI
import SwiftUI

extension PaintApplication {
  public static let antsEffect = MiniPlayfulEffect(
    id: "paint.marching-ants", name: "Marching ants",
    description: "A tiny procession around MiniPaint selections. No actual insects.",
    enabledByDefault: false)
}
enum PaintAntsPolicy {
  static func animates(enabled: Bool, reduceMotion: Bool, visible: Bool, awake: Bool, active: Bool)
    -> Bool
  {
    enabled && !reduceMotion && visible && awake && active
  }
}
struct PaintSelectionBorder: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.miniWindowVisible) private var visible
  @Environment(\.miniWindowActive) private var active
  @Environment(\.miniDesktopSuspended) private var suspended
  @Environment(\.scenePhase) private var phase
  let enabled: Bool
  @State private var awake = true
  @State private var nativeVisible = true
  var body: some View {
    let moving = PaintAntsPolicy.animates(
      enabled: enabled, reduceMotion: reduceMotion,
      visible: visible && nativeVisible && !suspended, awake: awake,
      active: active && phase == .active)
    TimelineView(.animation(minimumInterval: 1 / 8, paused: !moving)) { timeline in
      let dash =
        moving
        ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 6 : 0
      Rectangle().stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [3, 3], dashPhase: dash))
        .background(Rectangle().stroke(.white, lineWidth: 3))
    }
    .onReceive(
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification)
    ) { _ in awake = false }
    .onReceive(
      NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)
    ) { _ in awake = true }
    .onReceive(
      NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)
    ) { note in
      guard let window = note.object as? NSWindow,
        window.identifier?.rawValue == "desktop" || window.title == "Hello Mini"
      else { return }
      nativeVisible = window.occlusionState.contains(.visible)
    }
  }
}
