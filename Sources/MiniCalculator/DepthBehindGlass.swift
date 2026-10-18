import AppKit
import MiniCore
import MiniUI
import SwiftUI

extension CalculatorApplication {
  public static let depthEffect = MiniPlayfulEffect(
    id: "calculator.depth-behind-glass", name: "Depth behind glass",
    description:
      "A tiny perspective clockwork, drawn in the selected theme's ink. Entirely decorative.",
    enabledByDefault: false)
}
extension CalculatorView {
  var glass: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Department of Unnecessary Dimensions").font(theme.typography.title)
      if playfulness.allows(CalculatorApplication.depthEffect.id) {
        DepthBehindGlass().frame(minHeight: 130)
      } else {
        Text(
          "Enable Depth behind glass in Control Panel → Playfulness to open this little cabinet."
        )
        .font(theme.typography.body).frame(maxWidth: .infinity, minHeight: 130)
      }
      Text("Decorative clockwork. It does not represent a calculation or machine status.")
        .font(theme.typography.small)
    }
  }
}

enum GlassGeometry {
  static func animates(reduceMotion: Bool, visible: Bool, awake: Bool, active: Bool) -> Bool {
    !reduceMotion && visible && awake && active
  }
  static func project(x: Double, y: Double, z: Double, angle: Double, size: CGSize) -> CGPoint {
    let rx = x * cos(angle) - z * sin(angle)
    let rz = x * sin(angle) + z * cos(angle)
    let ry = y * cos(0.35) - rz * sin(0.35)
    let depth = max(2, 6 + y * sin(0.35) + rz * cos(0.35))
    let scale = min(size.width, size.height) * 0.9 / depth
    return CGPoint(x: size.width / 2 + rx * scale, y: size.height / 2 + ry * scale)
  }
}

struct DepthBehindGlass: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.miniWindowVisible) private var windowVisible
  @Environment(\.miniDesktopSuspended) private var suspended
  @Environment(\.scenePhase) private var phase
  @State private var awake = true
  @State private var visible = true
  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: 1 / 12,
        paused: !GlassGeometry.animates(
          reduceMotion: reduceMotion, visible: windowVisible && visible && !suspended,
          awake: awake, active: phase == .active))
    ) { timeline in
      Canvas { context, size in
        let angle =
          reduceMotion
          ? 0.4
          : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            * 0.22
        var lines = Path()
        for cabinet in 0..<3 {
          let radius = 0.45 + Double(cabinet) * 0.42
          let corners = (0..<8).map { index in
            GlassGeometry.project(
              x: (index & 1 == 0 ? -radius : radius),
              y: (index & 2 == 0 ? -radius : radius), z: (index & 4 == 0 ? -radius : radius),
              angle: angle * (cabinet.isMultiple(of: 2) ? 1 : -0.7), size: size)
          }
          for i in 0..<8 {
            for bit in [1, 2, 4] where i & bit == 0 {
              lines.move(to: corners[i])
              lines.addLine(to: corners[i | bit])
            }
          }
        }
        context.stroke(lines, with: .color(theme.ink), lineWidth: 1)
        var stipple = Path()
        for row in 0..<min(40, Int(size.height / 8)) {
          for col in 0..<min(80, Int(size.width / 8)) where (row + col).isMultiple(of: 3) {
            stipple.addRect(CGRect(x: col * 8, y: row * 8, width: 1, height: 1))
          }
        }
        context.fill(stipple, with: .color(theme.ink.opacity(0.15)))
      }
    }
    .background(theme.paper).overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 2))
    .allowsHitTesting(false).accessibilityElement(children: .ignore)
    .accessibilityLabel("Decorative perspective clockwork: three nested wireframe cubes")
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
