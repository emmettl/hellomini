import AppKit
import MiniUI
import SwiftUI

extension CalculatorView {
  var arithmetic: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Expression", text: $calculation.expression).accessibilityLabel(
        "Calculator expression"
      )
      .miniHelp(
        "+ − * / % ^ · parentheses · pi, e · sin, cos, tan, sqrt, abs, log, ln. Angles use radians."
      )
      .onSubmit(calculate)
      HStack {
        Button("Calculate", action: calculate)
        Button("Clear") {
          calculation.expression = ""
          calculation.result = "0"
          calculation.resultSource = "Cleared"
          calculation.error = nil
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
          ForEach(calculation.history) { entry in
            Button(entry.expression + " = " + entry.result) { calculation.reuse(entry) }
              .buttonStyle(.plain).accessibilityLabel("Reuse " + entry.expression)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.frame(maxHeight: 90)
      if let warning = calculation.historyWarning { Text(warning).font(theme.typography.small) }
      Button("Reset expression history", action: calculation.resetHistory)
    }
  }
  func calculate() { perform { try calculation.calculate() } }
}
