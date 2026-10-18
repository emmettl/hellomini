import AppKit
import MiniCore
import MiniUI
import SwiftUI

struct CalculatorView: View {
  @Environment(\.miniTheme) var theme
  let playfulness: PlayfulnessSettings
  @Bindable var calculation: CalculatorModel
  let sendToScrapbook: @MainActor (String) async throws -> Void
  @State var sending = false
  @State var pane = "Calculate"
  @State var a = "0xFF"
  @State var b = "1"
  @State var operation = "+"
  @State var amount = "1"
  @State var from = ConversionUnit.metres
  @State var to = ConversionUnit.feet
  @State var timestamp = "0"
  @State var isoDate = "1970-01-01T00:00:00Z"
  @State var plotExpression = "sin(x)"
  @State var points: [CGPoint?] = []
  @State var spectacle = false
  @State var height: CGFloat = 480
  /// Short windows, including tiny-screen mode with a dock, move reference text into help.
  var roomy: Bool { height >= 300 }

  let panes = ["Calculate", "Programmer", "Convert", "Time", "Plot", "Glass"]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ViewThatFits(in: .horizontal) {
        HStack { paneButtons(panes) }
        // Narrow windows, including tiny-screen mode, split the panes over two rows.
        VStack(alignment: .leading, spacing: 6) {
          HStack { paneButtons(Array(panes.prefix(3))) }
          HStack { paneButtons(Array(panes.suffix(3))) }
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
  @ViewBuilder func paneButtons(_ names: [String]) -> some View {
    ForEach(names, id: \.self) { name in
      Button((pane == name ? "✓ " : "") + name) {
        pane = name
        calculation.error = nil
        spectacle = false
      }
    }
  }
  func details(scrolling: Bool) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      switch pane {
      case "Programmer": programmer
      case "Convert": conversions
      case "Time": timeConversions
      case "Plot": plot(minimumHeight: scrolling ? 160 : 0)
      case "Glass": glass
      default: arithmetic
      }
      if pane != "Plot" && pane != "Glass" {
        ScrollView(.horizontal) {
          Text(calculation.result).font(
            pane == "Programmer" ? theme.typography.body : theme.typography.display(23)
          )
          .textSelection(.enabled).fixedSize(horizontal: true, vertical: true)
          .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }.frame(height: pane == "Programmer" ? 72 : 34).padding(12)
          .overlay(Rectangle().strokeBorder(theme.ink, lineWidth: 2))
        Button("Copy result") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(calculation.result, forType: .string)
        }
        .buttonStyle(RetroButtonStyle())
        Button(sending ? "Sending…" : "Send result to Scrapbook") {
          let text =
            calculation.resultSource + " = "
            + calculation.result
          sending = true
          Task { @MainActor in
            defer { sending = false }
            do { try await sendToScrapbook(text) } catch {
              calculation.error = error.localizedDescription
            }
          }
        }.buttonStyle(RetroButtonStyle()).disabled(sending)
      }
      if let error = calculation.error { Text(error).font(theme.typography.small) }
      if !scrolling { Spacer(minLength: 0) }
      if roomy { Text("More digits than strictly necessary.").font(theme.typography.small) }
    }
  }
  func perform(_ action: () throws -> String) {
    do {
      calculation.result = try action()
      if pane != "Calculate" { calculation.resultSource = pane }
      calculation.error = nil
    } catch { calculation.error = error.localizedDescription }
  }
}
