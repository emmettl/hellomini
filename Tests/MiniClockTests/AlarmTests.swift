import Foundation
import Testing

@testable import MiniClock

@Test @MainActor func alarmsSurviveRelaunchAndFireOnceAfterSleep() throws {
  let suite = "AlarmTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let now = Date(timeIntervalSince1970: 1000)
  let first = AlarmModel(defaults: defaults)
  first.start(minutes: 25, label: "Focus", now: now)
  var rings = 0
  let restored = AlarmModel(defaults: defaults) { rings += 1 }
  #expect(restored.label == "Focus")
  restored.tick(now: now.addingTimeInterval(1499))
  #expect(rings == 0)
  restored.tick(now: now.addingTimeInterval(5000))
  restored.tick(now: now.addingTimeInterval(6000))
  #expect(rings == 1)
  #expect(restored.ringing && restored.deadline == nil)
  let ringing = AlarmModel(defaults: defaults) { rings += 1 }
  ringing.tick(now: now.addingTimeInterval(7000))
  #expect(rings == 1)
  #expect(ringing.ringing)
  ringing.dismiss()
  #expect(!AlarmModel(defaults: defaults).ringing)
}

@Test @MainActor func timerRejectsInvalidDurationsAndCancelRemovesDeadline() throws {
  let suite = "AlarmTests.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suite))
  defer { defaults.removePersistentDomain(forName: suite) }
  let timer = AlarmModel(defaults: defaults)
  timer.start(minutes: 0, label: "Invalid")
  timer.start(minutes: 1441, label: "Invalid")
  #expect(timer.deadline == nil)
  timer.start(minutes: 5, label: "Break")
  #expect(timer.deadline != nil)
  timer.cancel()
  #expect(AlarmModel(defaults: defaults).deadline == nil)
}
