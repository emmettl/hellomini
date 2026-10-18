import Foundation
import Testing

@testable import MiniCalculator

@Test @MainActor func expressionHistoryIsBoundedPersistentAndReusable() throws {
  let suite = "CalculatorHistory-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let model = CalculatorModel(defaults: defaults)
  for n in 0..<60 {
    model.expression = "\(n) + 1"
    _ = try model.calculate()
  }
  #expect(model.history.count == 50)
  let reopened = CalculatorModel(defaults: defaults)
  #expect(reopened.history == model.history)
  reopened.reuse(try #require(reopened.history.last))
  #expect(reopened.expression == "10 + 1" && reopened.result == "11")
  reopened.expression = "1 / 0"
  #expect(reopened.resultSource == "10 + 1")
  #expect(throws: (any Error).self) { try reopened.calculate() }
  #expect(reopened.history.count == 50)
}
@Test @MainActor func newerHistoryIsPreservedUntilExplicitReset() throws {
  let suite = "CalculatorHistoryFuture-\(UUID())"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let bytes = Data("{\"version\":99,\"entries\":[]}".utf8)
  defaults.set(bytes, forKey: "calculator.expression-history")
  let model = CalculatorModel(defaults: defaults)
  #expect(model.historyWarning != nil)
  _ = try model.calculate()
  #expect(defaults.data(forKey: "calculator.expression-history") == bytes)
  model.resetHistory()
  #expect(defaults.data(forKey: "calculator.expression-history.previous") == bytes)
  _ = try model.calculate()
  #expect(model.history.count == 1 && model.historyWarning == nil)
}
@Test func glassProjectionAndLifecycleRemainBounded() {
  for angle in [0.0, 1.0, 1000.0] {
    let p = GlassGeometry.project(
      x: 1.5, y: -1.5, z: 1.5, angle: angle, size: CGSize(width: 440, height: 150))
    #expect(p.x.isFinite && p.y.isFinite && p.x >= 0 && p.x <= 440 && p.y >= 0 && p.y <= 150)
  }
  #expect(GlassGeometry.animates(reduceMotion: false, visible: true, awake: true, active: true))
  #expect(!GlassGeometry.animates(reduceMotion: true, visible: true, awake: true, active: true))
  #expect(!GlassGeometry.animates(reduceMotion: false, visible: false, awake: true, active: true))
  #expect(!GlassGeometry.animates(reduceMotion: false, visible: true, awake: false, active: true))
  #expect(!GlassGeometry.animates(reduceMotion: false, visible: true, awake: true, active: false))
}
