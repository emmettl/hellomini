import MiniUI
import SwiftUI

/// Smooth, original counterparts to the shared semantic pixel icons.
struct AquaIcon: View {
  let symbol: PixelSymbol
  let selected: Bool
  var body: some View {
    Canvas { graphics, size in
      var context = graphics
      context.scaleBy(x: size.width / 100, y: size.height / 100)
      let blue = Color(red: 0.16, green: 0.53, blue: 0.88)
      let silver = Color(red: 0.66, green: 0.73, blue: 0.81)
      let dark = Color(red: 0.1, green: 0.18, blue: 0.28)
      if selected {
        context.fill(
          Path(roundedRect: CGRect(x: 1, y: 1, width: 98, height: 98), cornerRadius: 15),
          with: .color(.white.opacity(0.25)))
      }
      func panel(_ rect: CGRect, _ color: Color, _ radius: CGFloat = 6) {
        let path = Path(roundedRect: rect, cornerRadius: radius)
        context.fill(
          path,
          with: .linearGradient(
            Gradient(colors: [.white, color, color.opacity(0.85)]), startPoint: rect.origin,
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(path, with: .color(dark.opacity(0.8)), lineWidth: 1.5)
      }
      func oval(_ rect: CGRect, _ color: Color) {
        let path = Path(ellipseIn: rect)
        context.fill(
          path,
          with: .linearGradient(
            Gradient(colors: [.white, color, color]), startPoint: rect.origin,
            endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(path, with: .color(dark.opacity(0.7)), lineWidth: 1.5)
      }
      func line(
        _ points: [CGPoint], _ color: Color = Color(red: 0.1, green: 0.18, blue: 0.28),
        _ width: CGFloat = 2
      ) {
        var path = Path()
        path.addLines(points)
        context.stroke(
          path, with: .color(color),
          style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
      }
      func polygon(_ points: [CGPoint], _ color: Color) {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        context.fill(
          path,
          with: .linearGradient(
            Gradient(colors: [.white, color]), startPoint: CGPoint(x: 20, y: 10),
            endPoint: CGPoint(x: 65, y: 85)))
        context.stroke(path, with: .color(dark.opacity(0.8)), lineWidth: 1.5)
      }
      func paper(_ rect: CGRect) {
        panel(rect, .white, 1)
        for index in 0..<3 {
          let y = rect.minY + 8 + CGFloat(index) * 7
          line([CGPoint(x: rect.minX + 5, y: y), CGPoint(x: rect.maxX - 5, y: y)], silver, 2)
        }
      }
      switch symbol {
      case .folder:
        polygon(
          [
            CGPoint(x: 9, y: 22), CGPoint(x: 40, y: 22), CGPoint(x: 48, y: 31),
            CGPoint(x: 89, y: 31), CGPoint(x: 89, y: 83), CGPoint(x: 9, y: 83),
          ], blue)
        panel(CGRect(x: 7, y: 39, width: 86, height: 47), blue, 5)
        line([CGPoint(x: 13, y: 43), CGPoint(x: 86, y: 43)], .white.opacity(0.8), 2)
      case .document:
        polygon(
          [
            CGPoint(x: 22, y: 8), CGPoint(x: 62, y: 8), CGPoint(x: 80, y: 26),
            CGPoint(x: 80, y: 91), CGPoint(x: 22, y: 91),
          ], .white)
        polygon([CGPoint(x: 62, y: 8), CGPoint(x: 62, y: 27), CGPoint(x: 80, y: 27)], blue)
        for y in stride(from: 42, through: 75, by: 11) {
          line([CGPoint(x: 31, y: y), CGPoint(x: 68, y: y)], silver, 3)
        }
      case .disk:
        panel(CGRect(x: 12, y: 20, width: 76, height: 68), silver, 8)
        oval(CGRect(x: 23, y: 28, width: 54, height: 38), Color(white: 0.75))
        oval(CGRect(x: 44, y: 40, width: 12, height: 12), dark)
        line([CGPoint(x: 68, y: 64), CGPoint(x: 48, y: 45)], .white, 5)
        line([CGPoint(x: 24, y: 78), CGPoint(x: 64, y: 78)], dark, 4)
        oval(CGRect(x: 72, y: 75, width: 5, height: 5), .green)
      case .computer, .activity:
        panel(CGRect(x: 37, y: 72, width: 26, height: 15), silver, 2)
        panel(CGRect(x: 26, y: 85, width: 48, height: 5), silver, 2)
        panel(CGRect(x: 9, y: 12, width: 82, height: 64), symbol == .computer ? blue : silver, 12)
        panel(CGRect(x: 18, y: 21, width: 64, height: 43), dark, 4)
        if symbol == .activity {
          line(
            [
              CGPoint(x: 23, y: 48), CGPoint(x: 36, y: 48), CGPoint(x: 44, y: 30),
              CGPoint(x: 52, y: 57), CGPoint(x: 60, y: 42), CGPoint(x: 76, y: 42),
            ], .green, 3)
        } else {
          line([CGPoint(x: 36, y: 35), CGPoint(x: 36, y: 39)], .white, 3)
          line([CGPoint(x: 63, y: 35), CGPoint(x: 63, y: 39)], .white, 3)
          line(
            [
              CGPoint(x: 36, y: 49), CGPoint(x: 44, y: 53), CGPoint(x: 55, y: 53),
              CGPoint(x: 63, y: 49),
            ], .white, 2)
        }
      case .clock:
        oval(CGRect(x: 8, y: 8, width: 84, height: 84), silver)
        oval(CGRect(x: 15, y: 15, width: 70, height: 70), .white)
        for index in 0..<12 {
          let angle = Double(index) * .pi / 6
          line(
            [
              CGPoint(x: 50 + sin(angle) * 29, y: 50 + cos(angle) * 29),
              CGPoint(x: 50 + sin(angle) * 32, y: 50 + cos(angle) * 32),
            ], dark, 2)
        }
        line([CGPoint(x: 50, y: 28), CGPoint(x: 50, y: 50), CGPoint(x: 68, y: 57)], dark, 3)
        line([CGPoint(x: 50, y: 50), CGPoint(x: 32, y: 66)], .red, 1)
      case .settings:
        panel(CGRect(x: 10, y: 14, width: 80, height: 73), silver, 9)
        for (x, y) in [(29, 39), (50, 61), (71, 31)] {
          line([CGPoint(x: x, y: 26), CGPoint(x: x, y: 74)], dark, 4)
          panel(CGRect(x: x - 8, y: y, width: 16, height: 10), blue, 3)
        }
      case .teapot:
        oval(CGRect(x: 5, y: 34, width: 29, height: 36), .orange)
        oval(CGRect(x: 12, y: 40, width: 15, height: 22), .white)
        polygon(
          [
            CGPoint(x: 69, y: 43), CGPoint(x: 91, y: 29), CGPoint(x: 91, y: 40),
            CGPoint(x: 76, y: 65),
          ], .orange)
        oval(CGRect(x: 22, y: 27, width: 56, height: 56), .orange)
        oval(CGRect(x: 27, y: 22, width: 46, height: 12), .orange)
        oval(CGRect(x: 44, y: 14, width: 12, height: 11), .orange)
      case .aquarium:
        panel(CGRect(x: 8, y: 17, width: 84, height: 71), blue.opacity(0.65), 5)
        line([CGPoint(x: 12, y: 29), CGPoint(x: 88, y: 29)], .white, 2)
        for x in [21, 73] {
          line(
            [CGPoint(x: x, y: 79), CGPoint(x: x - 4, y: 66), CGPoint(x: x + 3, y: 57)], .green, 3)
        }
        polygon([CGPoint(x: 38, y: 49), CGPoint(x: 24, y: 41), CGPoint(x: 24, y: 62)], .orange)
        oval(CGRect(x: 35, y: 38, width: 36, height: 25), .orange)
        oval(CGRect(x: 60, y: 45, width: 3, height: 3), dark)
        oval(CGRect(x: 75, y: 33, width: 5, height: 5), .white)
        panel(CGRect(x: 7, y: 80, width: 86, height: 8), silver, 2)
      case .scrapbook:
        panel(
          CGRect(x: 20, y: 10, width: 65, height: 81), Color(red: 0.62, green: 0.27, blue: 0.16), 5)
        panel(
          CGRect(x: 15, y: 10, width: 12, height: 81), Color(red: 0.36, green: 0.16, blue: 0.1), 3)
        paper(CGRect(x: 34, y: 24, width: 36, height: 43))
        polygon(
          [
            CGPoint(x: 67, y: 8), CGPoint(x: 76, y: 8), CGPoint(x: 76, y: 43),
            CGPoint(x: 71, y: 37), CGPoint(x: 67, y: 43),
          ], .red)
      case .calculator:
        panel(CGRect(x: 18, y: 7, width: 64, height: 86), silver, 9)
        panel(
          CGRect(x: 25, y: 15, width: 50, height: 20), Color(red: 0.66, green: 0.8, blue: 0.6), 3)
        for y in 0..<4 {
          for x in 0..<3 {
            panel(
              CGRect(x: 26 + x * 17, y: 42 + y * 11, width: 12, height: 7), x == 2 ? blue : .white,
              2)
          }
        }
      case .puzzle:
        let colors: [Color] = [blue, .orange, .green, .purple]
        for index in 0..<8 {
          panel(
            CGRect(x: 10 + (index % 3) * 27, y: 10 + (index / 3) * 27, width: 25, height: 25),
            colors[index % 4], 4)
        }
      case .chooser:
        oval(CGRect(x: 19, y: 12, width: 62, height: 62), blue)
        context.stroke(
          Path(ellipseIn: CGRect(x: 34, y: 13, width: 32, height: 60)),
          with: .color(.white.opacity(0.75)), lineWidth: 2)
        line([CGPoint(x: 21, y: 43), CGPoint(x: 79, y: 43)], .white, 2)
        line(
          [
            CGPoint(x: 50, y: 74), CGPoint(x: 50, y: 85), CGPoint(x: 17, y: 85),
            CGPoint(x: 83, y: 85),
          ], silver, 4)
        for x in [10, 43, 76] { panel(CGRect(x: x, y: 80, width: 14, height: 12), blue, 3) }
      case .wastebasket:
        paper(CGRect(x: 30, y: 11, width: 32, height: 46))
        polygon(
          [
            CGPoint(x: 18, y: 33), CGPoint(x: 82, y: 33), CGPoint(x: 72, y: 89),
            CGPoint(x: 28, y: 89),
          ], silver.opacity(0.65))
        for x in stride(from: 26, through: 74, by: 8) {
          line(
            [CGPoint(x: x, y: 35), CGPoint(x: 50 + (x - 50) * 3 / 4, y: 85)], dark.opacity(0.55),
            1.2)
        }
        for y in stride(from: 43, through: 80, by: 9) {
          line([CGPoint(x: 22, y: y), CGPoint(x: 78, y: y)], .white.opacity(0.8), 1)
        }
        oval(CGRect(x: 17, y: 27, width: 66, height: 13), silver)
      case .printer:
        paper(CGRect(x: 29, y: 7, width: 44, height: 39))
        panel(CGRect(x: 8, y: 32, width: 84, height: 43), silver, 10)
        line([CGPoint(x: 24, y: 61), CGPoint(x: 77, y: 61)], dark, 5)
        paper(CGRect(x: 29, y: 61, width: 44, height: 31))
        oval(CGRect(x: 78, y: 42, width: 5, height: 5), .green)
      }
    }
  }
}
