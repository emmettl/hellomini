import MiniUI
import SwiftUI

/// The number is a real sample; particles are decorative and never imply additional precision.
struct ImpossibleInstrument: View {
  @Environment(\.miniTheme) private var theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let cpu: Double?
  let running: Bool

  static func animates(running: Bool, reduceMotion: Bool, cpu: Double?) -> Bool {
    running && !reduceMotion && cpu?.isFinite == true
  }

  var body: some View {
    TimelineView(
      .animation(
        minimumInterval: 1 / 12,
        paused: !Self.animates(running: running, reduceMotion: reduceMotion, cpu: cpu))
    ) { timeline in
      Canvas { context, size in
        let value = min(100, max(0, cpu ?? 0)) / 100
        let time =
          reduceMotion || !running
          ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
        let center = CGPoint(x: size.width / 2, y: size.height * 0.85)
        let radius = min(size.width / 3, size.height * 0.78)
        var dial = Path()
        for tick in 0...20 {
          let angle = Double.pi + Double(tick) / 20 * Double.pi
          let inner = radius * (tick.isMultiple(of: 5) ? 0.76 : 0.89)
          dial.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
          dial.addLine(
            to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
        }
        let angle = Double.pi + value * Double.pi
        dial.move(to: center)
        dial.addLine(
          to: CGPoint(
            x: center.x + cos(angle) * radius * 0.72, y: center.y + sin(angle) * radius * 0.72))
        context.stroke(dial, with: .color(theme.ink), lineWidth: 2)
        var particles = Path()
        for index in 0..<80 {
          let seed = Double(index)
          let x = (seed * 37 + time * (4 + value * 30)).truncatingRemainder(
            dividingBy: max(1, size.width))
          let y = size.height / 2 + sin(seed * 1.7 + time * (0.3 + value)) * size.height * 0.36
          if abs(x - center.x) > radius + 8 {
            particles.addRect(CGRect(x: x, y: y, width: 2, height: 2))
          }
        }
        context.fill(particles, with: .color(theme.ink.opacity(0.6)))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Impossible CPU instrument. Particles are decorative.")
    .accessibilityValue(
      cpu.map { String(format: "%.1f percent busy", $0) } ?? "Waiting for a sample"
    )
    .allowsHitTesting(false)
  }
}
