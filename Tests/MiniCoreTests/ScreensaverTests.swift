import Foundation
import Testing

@testable import MiniCore

private let fish = MiniScreensaver(id: "fish", name: "Fish", description: "Fish")
private let toast = MiniScreensaver(id: "toast", name: "Toast", description: "Toast")

@Test @MainActor func screensaverPreferencesAndPreviewHaveSeparateLifetimes() throws {
  let suite = "HelloMiniTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let settings = ScreensaverSettings(savers: [fish, toast], defaults: defaults)
  #expect(settings.idleMinutes == 0)
  settings.select(toast.id)
  settings.setIdleMinutes(5)
  settings.preview(fish.id)
  settings.setPresenting(true)
  #expect(settings.selectedID == toast.id)
  #expect(settings.previewID == fish.id && settings.previewRevision == 1)
  settings.preview("missing")
  settings.setIdleMinutes(-1)
  settings.select("missing")
  #expect(settings.previewRevision == 1 && settings.idleMinutes == 5)
  let restored = ScreensaverSettings(savers: [fish, toast], defaults: defaults)
  #expect(restored.selectedID == toast.id && restored.idleMinutes == 5)
  #expect(!restored.isPresenting && restored.previewRevision == 0 && restored.previewID == nil)
  // A temporarily missing module falls back without overwriting its saved selection.
  #expect(ScreensaverSettings(savers: [fish], defaults: defaults).selectedID == fish.id)
  #expect(ScreensaverSettings(savers: [fish, toast], defaults: defaults).selectedID == toast.id)
  defaults.set(999, forKey: "screensaver.idleMinutes")
  #expect(ScreensaverSettings(savers: [fish], defaults: defaults).idleMinutes == 0)
}

@Test func screensaverIdleRequiresAnUninterruptedEligibleInterval() {
  var clock = ScreensaverIdleClock()
  func check(now: TimeInterval, delay: TimeInterval, eligible: Bool, expected: Bool) {
    let triggered = clock.tick(now: now, delay: delay, eligible: eligible)
    #expect(triggered == expected)
  }
  check(now: 0, delay: 5, eligible: true, expected: false)
  for t in 1...4 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 5, delay: 5, eligible: true, expected: true)
  check(now: 6, delay: 5, eligible: true, expected: false)
  clock.reset(now: 7)  // Input restarts the entire interval.
  for t in 8...11 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 12, delay: 5, eligible: true, expected: true)
  check(now: 13, delay: 5, eligible: false, expected: false)
  for t in 14...17 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 18, delay: 5, eligible: true, expected: true)
}

@Test func screensaverIdleDoesNotAccumulateSleepOrDisabledTime() {
  var clock = ScreensaverIdleClock()
  func check(now: TimeInterval, delay: TimeInterval, eligible: Bool, expected: Bool) {
    let triggered = clock.tick(now: now, delay: delay, eligible: eligible)
    #expect(triggered == expected)
  }
  clock.reset(now: 0)
  for t in 1...4 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 1000, delay: 5, eligible: true, expected: false)
  for t in 1001...1004 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 1005, delay: 5, eligible: true, expected: true)
  for t in 1006...1015 { check(now: Double(t), delay: 0, eligible: true, expected: false) }
  for t in 1016...1019 { check(now: Double(t), delay: 5, eligible: true, expected: false) }
  check(now: 1020, delay: 5, eligible: true, expected: true)
  check(now: 0, delay: 5, eligible: true, expected: false)
}
