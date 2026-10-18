import MiniUI
import SwiftUI

extension CalculatorView {
  func plot(minimumHeight: CGFloat) -> some View {
    VStack(spacing: 10) {
      HStack {
        TextField("f(x)", text: $plotExpression).accessibilityLabel("Function to plot")
        Button("Plot") {
          do {
            let tree = try Expression.parse(plotExpression)
            points = (0...500).map { i in
              let x = Double(i) / 25 - 10
              return (try? tree.value(x: x)).flatMap { abs($0) <= 10 ? CGPoint(x: x, y: $0) : nil }
            }
            spectacle = false
            calculation.error = nil
          } catch { calculation.error = error.localizedDescription }
        }
        Button(spectacle ? "Back to graph" : "Unreasonable mathematics") { spectacle.toggle() }
          .disabled(!playfulness.allows(CalculatorApplication.effect.id))
      }.buttonStyle(RetroButtonStyle())
      if spectacle && playfulness.allows(CalculatorApplication.effect.id) {
        MiniMetalScene(.mathematics, animate: true).frame(minHeight: minimumHeight)
        Text("Mandelbrot excursion · unrelated to the calculated result").font(
          theme.typography.small)
      } else {
        Canvas { context, size in
          func position(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x + 10) / 20 * size.width, y: (10 - p.y) / 20 * size.height)
          }
          var axes = Path()
          axes.move(to: position(CGPoint(x: -10, y: 0)))
          axes.addLine(to: position(CGPoint(x: 10, y: 0)))
          axes.move(to: position(CGPoint(x: 0, y: -10)))
          axes.addLine(to: position(CGPoint(x: 0, y: 10)))
          context.stroke(axes, with: .color(theme.ink.opacity(0.3)), lineWidth: 1)
          var path = Path()
          var last: CGPoint?
          for point in points {
            if let point {
              if let last, abs(last.y - point.y) < 3 {
                path.addLine(to: position(point))
              } else {
                path.move(to: position(point))
              }
            }
            last = point
          }
          context.stroke(path, with: .color(theme.ink), lineWidth: 2)
        }.background(theme.paper).overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 1))
          .accessibilityLabel("Function plot, x and y from minus ten to ten")
          .frame(minHeight: minimumHeight)
        Text("x: −10…10 · y: −10…10 · undefined and out-of-range samples are omitted").font(
          theme.typography.small)
      }
    }
  }
}
