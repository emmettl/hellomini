import Foundation
import Observation

struct CalculationEntry: Identifiable, Codable, Equatable {
  var id = UUID()
  var expression: String
  var result: String
  var date = Date()
}
private struct CalculationHistoryDocument: Codable {
  var version = 1
  var entries: [CalculationEntry]
}

@MainActor @Observable final class CalculatorModel {
  var expression = "(2 + 3) * 4"
  var result = "20"
  var resultSource = "(2 + 3) * 4"
  var error: String?
  private(set) var history: [CalculationEntry] = []
  private(set) var historyWarning: String?
  @ObservationIgnored private let defaults: UserDefaults
  private static let key = "calculator.expression-history"
  private var writable = true
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    guard let data = defaults.data(forKey: Self.key) else { return }
    guard data.count <= 1_000_000,
      let document = try? JSONDecoder().decode(CalculationHistoryDocument.self, from: data),
      document.version == 1, document.entries.count <= 50,
      Set(document.entries.map(\.id)).count == document.entries.count,
      document.entries.allSatisfy({
        $0.expression.count <= 4096 && $0.result.count <= 4096
          && $0.date.timeIntervalSince1970.isFinite
      })
    else {
      writable = false
      historyWarning =
        "Saved history is unreadable or newer. It was left intact. Reset history to start a new list."
      return
    }
    history = document.entries
  }

  func calculate() throws -> String {
    guard expression.count <= 4096 else {
      throw CalculationError.invalid("Use an expression of up to 4,096 characters.")
    }
    guard !expression.lowercased().contains("x") else {
      throw CalculationError.invalid("Use x in the Plot pane.")
    }
    let output = String(format: "%.12g", try Expression.parse(expression).value())
    if writable {
      var next = [CalculationEntry(expression: expression, result: output)] + history
      next = Array(next.prefix(50))
      let data = try JSONEncoder().encode(CalculationHistoryDocument(entries: next))
      defaults.set(data, forKey: Self.key)
      history = next
    }
    resultSource = expression
    result = output
    return output
  }
  func reuse(_ entry: CalculationEntry) {
    resultSource = entry.expression
    expression = entry.expression
    result = entry.result
    error = nil
  }
  func resetHistory() {
    if let old = defaults.data(forKey: Self.key) {
      defaults.set(old, forKey: Self.key + ".previous")
    }
    defaults.removeObject(forKey: Self.key)
    history = []
    writable = true
    historyWarning = nil
  }
}
