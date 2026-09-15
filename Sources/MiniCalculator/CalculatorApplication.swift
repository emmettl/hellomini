import AppKit
import MiniCore
import MiniUI
import SwiftUI

@MainActor public final class CalculatorApplication: MiniApplication {
  public let id = "calculator"
  public let name = "Desk Calculator"
  public let icon = MiniApplicationIcon.calculator
  public let defaultSize = CGSize(width: 700, height: 480)
  public let minimumSize = CGSize(width: 440, height: 250)
  public static let effect = MiniPlayfulEffect(
    id: "calculator.mathematics", name: "Unreasonable mathematics",
    description: "Allow the calculator's animated Mandelbrot excursion.")
  private let playfulness: PlayfulnessSettings
  public init(playfulness: PlayfulnessSettings) { self.playfulness = playfulness }
  public func content() -> AnyView { AnyView(CalculatorView(playfulness: playfulness)) }
}

private struct CalculatorView: View {
  @Environment(\.miniTheme) private var theme
  let playfulness: PlayfulnessSettings
  @State private var pane = "Calculate"
  @State private var expression = "(2 + 3) * 4"
  @State private var result = "20"
  @State private var history: [String] = []
  @State private var error: String?
  @State private var a = "0xFF"
  @State private var b = "1"
  @State private var operation = "+"
  @State private var amount = "1"
  @State private var from = ConversionUnit.metres
  @State private var to = ConversionUnit.feet
  @State private var timestamp = "0"
  @State private var isoDate = "1970-01-01T00:00:00Z"
  @State private var plotExpression = "sin(x)"
  @State private var points: [CGPoint?] = []
  @State private var spectacle = false
  @State private var height: CGFloat = 480
  /// Short windows, including tiny-screen mode with a dock, move reference text into help.
  private var roomy: Bool { height >= 300 }

  private let panes = ["Calculate", "Programmer", "Convert", "Time", "Plot"]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack { paneButtons(panes) }
        // Narrow windows, including tiny-screen mode, split the panes over two rows.
        VStack(alignment: .leading, spacing: 6) {
          HStack { paneButtons(Array(panes.prefix(3))) }
          HStack { paneButtons(Array(panes.suffix(2))) }
        }
      }.buttonStyle(RetroButtonStyle())
      Rectangle().frame(height: 1)
      ViewThatFits(in: .vertical) {
        details(scrolling: false)
        ScrollView { details(scrolling: true).padding(.trailing, 12) }
      }
    }.padding(roomy ? 16 : 10)
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        height = $0
      }
  }
  @ViewBuilder private func paneButtons(_ names: [String]) -> some View {
    ForEach(names, id: \.self) { name in
      Button((pane == name ? "✓ " : "") + name) {
        pane = name
        error = nil
        spectacle = false
      }
    }
  }
  private func details(scrolling: Bool) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      switch pane {
      case "Programmer": programmer
      case "Convert": conversions
      case "Time": timeConversions
      case "Plot": plot(minimumHeight: scrolling ? 160 : 0)
      default: arithmetic
      }
      if pane != "Plot" {
        ScrollView(.horizontal) {
          Text(result).font(
            pane == "Programmer" ? theme.typography.body : theme.typography.display(23)
          )
          .textSelection(.enabled).fixedSize(horizontal: true, vertical: true)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }.frame(height: pane == "Programmer" ? 72 : 34).padding(12)
          .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 2))
        Button("Copy result") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(result, forType: .string)
        }
        .buttonStyle(RetroButtonStyle())
      }
      if let error { Text(error).font(theme.typography.small) }
      if !scrolling { Spacer(minLength: 0) }
      if roomy { Text("More digits than strictly necessary.").font(theme.typography.small) }
    }
  }
  private func perform(_ action: () throws -> String) {
    do {
      result = try action()
      error = nil
    } catch { self.error = error.localizedDescription }
  }
  private var arithmetic: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Expression", text: $expression).accessibilityLabel("Calculator expression")
        .miniHelp(
          "+ − * / % ^ · parentheses · pi, e · sin, cos, tan, sqrt, abs, log, ln. Angles use radians."
        )
        .onSubmit(calculate)
      HStack {
        Button("Calculate", action: calculate)
        Button("Clear") {
          expression = ""
          result = "0"
          error = nil
        }
      }.buttonStyle(RetroButtonStyle())
      if roomy {
        Text(
          "+ − * / % ^ · parentheses · pi, e · sin, cos, tan, sqrt, abs, log, ln\nAngles use radians. General calculations use floating-point numbers."
        )
        .font(theme.typography.small).fixedSize(horizontal: false, vertical: true)
      }
      ScrollView {
        VStack(alignment: .leading) {
          ForEach(Array(history.enumerated()), id: \.offset) { _, line in
            Text(line).textSelection(.enabled)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }.frame(maxHeight: 90)
    }
  }
  private func calculate() {
    perform {
      guard !expression.lowercased().contains("x") else {
        throw CalculationError.invalid("Use x in the Plot pane.")
      }
      let value = try Expression.parse(expression).value()
      let output = String(format: "%.12g", value)
      history.insert(expression + " = " + output, at: 0)
      history = Array(history.prefix(12))
      return output
    }
  }
  private var programmer: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        TextField("Left operand", text: $a)
        Picker("Operation", selection: $operation) {
          ForEach(["+", "-", "*", "/", "%", "AND", "OR", "XOR", "<<", ">>"], id: \.self) {
            Text($0)
          }
        }.labelsHidden().frame(width: 90)
        TextField("Right operand", text: $b)
      }
      Button("Calculate exactly") {
        perform {
          let n = try ProgrammerMath.calculate(
            ProgrammerMath.integer(a), operation, ProgrammerMath.integer(b))
          return
            "\(n)\n0x\(String(UInt64(bitPattern: n), radix: 16).uppercased())\n0b\(String(UInt64(bitPattern: n), radix: 2))"
        }
      }.buttonStyle(RetroButtonStyle())
      Text(
        "Signed 64-bit arithmetic. Hex and binary describe bit patterns.\nArithmetic overflow is reported; shifts discard bits and right shifts preserve the sign."
      )
      .font(theme.typography.small)
    }
  }
  private var conversions: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Amount", text: $amount)
      HStack {
        Picker("From", selection: $from) {
          ForEach(ConversionUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        Picker("To", selection: $to) {
          ForEach(ConversionUnit.allCases.filter { $0.group == from.group }, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        }
      }
      .onChange(of: from) { _, unit in if to.group != unit.group { to = unit } }
      Button("Convert") {
        perform {
          guard let value = Double(amount), value.isFinite else {
            throw CalculationError.invalid("Enter a number.")
          }
          return String(format: "%.12g", try from.convert(value, to: to)) + " " + to.rawValue
        }
      }.buttonStyle(RetroButtonStyle())
    }
  }
  private var timeConversions: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Unix seconds", text: $timestamp).accessibilityLabel("Unix timestamp in seconds")
      HStack {
        Button("Seconds → UTC") {
          perform {
            guard let seconds = Double(timestamp), seconds.isFinite, abs(seconds) < 200_000_000_000
            else {
              throw CalculationError.invalid(
                "Enter Unix seconds within the supported calendar range.")
            }
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: seconds))
          }
        }
        Button("Now") { timestamp = String(Int64(Date().timeIntervalSince1970)) }
      }.buttonStyle(RetroButtonStyle())
      TextField("ISO 8601 date", text: $isoDate).accessibilityLabel("ISO 8601 date with timezone")
      Button("Date → seconds") {
        perform {
          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
          guard
            let date = formatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
          else {
            throw CalculationError.invalid(
              "Use an ISO 8601 date with timezone, such as 2026-01-01T12:00:00Z.")
          }
          return String(format: "%.3f", date.timeIntervalSince1970)
        }
      }.buttonStyle(RetroButtonStyle())
    }
  }
  private func plot(minimumHeight: CGFloat) -> some View {
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
            error = nil
          } catch { self.error = error.localizedDescription }
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
